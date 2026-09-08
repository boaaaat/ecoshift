-- EventService.lua
-- Data-driven event engine with per-biome pools and override system.
-- Public API:
--   EventService:TriggerEvent(eventId, biomeName, overrides?)
--   EventService:SelectEvent(biomeName, poolType) -> id, overrides
--   EventService:ResolveEvent(eventId, biomeName, overrides?) -> resolved
--   EventService:EndEvent(evType)
--   EventService:GetActive(evType) -> active data or nil

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local EventsConfig = require(ReplicatedStorage.Shared.EventsConfig)
local ThreatService = require(script.Parent.ThreatService)
local BiomeService = require(script.Parent.BiomeService)
local GameStateService = require(script.Parent.GameStateService)

local ItemDropService = nil
local function getItemDropService()
	if not ItemDropService then
		ItemDropService = require(script.Parent.ItemDropService)
	end
	return ItemDropService
end

local EventService = {}
EventService._remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
EventService._remote = Util.GetRemote(EventService._remotesFolder, Config.RemoteNames.EventBroadcast)

EventService._active = { Minor = nil, Major = nil }
EventService._nextMinor = 0
EventService._nextMajor = 0
EventService._tickInterval = 0.25
EventService._started = false
EventService._requestConn = nil

---------------------------------------------------------------------------
-- _G callback registry (backward compat)
---------------------------------------------------------------------------
_G.Ecoshift = _G.Ecoshift or {}
_G.Ecoshift.EventCallbacks = _G.Ecoshift.EventCallbacks or { Start = {}, End = {} }
_G.Ecoshift.OnEventStartAdd = function(cb)
	if type(cb) == "function" then table.insert(_G.Ecoshift.EventCallbacks.Start, cb) end
end
_G.Ecoshift.OnEventEndAdd = function(cb)
	if type(cb) == "function" then table.insert(_G.Ecoshift.EventCallbacks.End, cb) end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function scheduleWindow(range)
	return os.clock() + math.random(range[1], range[2])
end
local function paused() return ReplicatedStorage:GetAttribute("WorldRestoring") == true end
local function nonnegative(value)
	return type(value) == "number" and value == value and value >= 0 and value < math.huge
end
local function plain(value, depth, budget)
	local kind = type(value)
	if kind == "number" then return value == value and math.abs(value) < math.huge end
	if kind == "string" or kind == "boolean" or kind == "nil" then return true end
	if kind ~= "table" or depth > 10 then return false end
	for key, child in pairs(value) do
		budget[1] += 1
		if budget[1] > 5000 or (type(key) ~= "string" and type(key) ~= "number") or not plain(key, depth + 1, budget) or not plain(child, depth + 1, budget) then return false end
	end
	return true
end

local function safeFire(remote, evType, id, payload)
	if remote and remote.FireAllClients then
		remote:FireAllClients(evType, id, payload or {})
	end
end

local function hook(kind, ...)
	local list = _G.Ecoshift and _G.Ecoshift.EventCallbacks and _G.Ecoshift.EventCallbacks[kind]
	if type(list) == "table" then
		for _, cb in ipairs(list) do
			if type(cb) == "function" then pcall(cb, ...) end
		end
	end
end

local function resolveCount(countDef)
	if type(countDef) == "table" then
		return math.random(countDef.min or 1, countDef.max or 1)
	end
	return tonumber(countDef) or 1
end

local function getRandomPlayerPosition()
	local players = Players:GetPlayers()
	if #players == 0 then return nil end
	local plr = players[math.random(1, #players)]
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local offset = Vector3.new(math.random(-20, 20), 3, math.random(-20, 20))
	return root.Position + offset
end

---------------------------------------------------------------------------
-- Core API
---------------------------------------------------------------------------

function EventService:ResolveEvent(eventId, biomeName, overrides)
	local baseDef = EventsConfig.Definitions[eventId]
	if not baseDef then
		warn("[EventService] Unknown event definition: " .. tostring(eventId))
		return nil
	end

	local resolved = Util.DeepCopy(baseDef)

	-- Apply biome pool overrides (if this event appears in the biome pool with Overrides)
	if biomeName then
		local biomePool = EventsConfig.BiomePools[biomeName]
		if biomePool then
			for _, poolType in ipairs({"Minor", "Major"}) do
				local pool = biomePool[poolType]
				if pool then
					for _, entry in ipairs(pool) do
						if entry.Id == eventId and entry.Overrides then
							resolved = Util.DeepMerge(resolved, entry.Overrides)
							break
						end
					end
				end
			end
		end
	end

	-- Apply caller overrides on top
	if overrides then
		resolved = Util.DeepMerge(resolved, overrides)
	end

	return resolved
end

function EventService:SelectEvent(biomeName, poolType)
	-- Build combined pool: Global + biome-specific, biome entries override Global by Id
	local globalPool = EventsConfig.BiomePools.Global and EventsConfig.BiomePools.Global[poolType] or {}
	local biomePool = biomeName and EventsConfig.BiomePools[biomeName] and EventsConfig.BiomePools[biomeName][poolType] or {}

	-- Index biome entries by Id for dedup
	local biomeIds = {}
	for _, entry in ipairs(biomePool) do
		biomeIds[entry.Id] = true
	end

	-- Combined: biome entries first, then Global entries not overridden
	local combined = {}
	for _, entry in ipairs(biomePool) do
		table.insert(combined, entry)
	end
	for _, entry in ipairs(globalPool) do
		if not biomeIds[entry.Id] then
			table.insert(combined, entry)
		end
	end

	if #combined == 0 then return nil, nil end

	local chosen = Util.ChooseWeighted(combined, "Weight")
	return chosen.Id, chosen.Overrides
end

function EventService:TriggerEvent(eventId, biomeName, optionalOverrides)
	if GameStateService:IsGameOver() or paused() then
		return nil
	end
	local resolved = self:ResolveEvent(eventId, biomeName, optionalOverrides)
	if not resolved then return nil end

	local evType = resolved.Type or "Minor"
	if evType ~= "Minor" and evType ~= "Major" then return nil end
	if self._active[evType] then self:EndEvent(evType) end

	-- Compute duration
	local dur = resolved.Duration
	local duration = (type(dur) == "table") and math.random(dur.min or 45, dur.max or 75) or (tonumber(dur) or 60)

	-- Build payload
	local payload = {
		InstanceId = HttpService:GenerateGUID(false),
		Biome = biomeName or BiomeService:GetCurrent(),
		Threat = ThreatService:Get(),
		Duration = duration,
		StartedAt = os.clock(),
		Type = evType,
		EventId = eventId,
		Resolved = resolved,
	}

	-- Store active
	local active = { Id = eventId, Data = payload, OneShotConsumed = false }
	local dropInterval = tonumber(resolved.DropInterval) or 0
	if resolved.Drops and #resolved.Drops > 0 and dropInterval > 0 then active.NextDropAt = os.clock() end
	self._active[evType] = active

	-- Fire remote to clients
	safeFire(self._remote, evType .. "_Start", eventId, payload)

	-- Fire _G hooks (backward compat)
	hook("Start", evType, eventId, payload)

	return resolved
end

function EventService:EndEvent(evType)
	local active = self._active[evType]
	if not active then return end

	self._active[evType] = nil
	safeFire(self._remote, evType .. "_End", active.Id, active.Data)
	hook("End", evType, active.Id, active.Data)
end

function EventService:EndAll()
	self:EndEvent("Minor")
	self:EndEvent("Major")
end

function EventService:GetActive(evType)
	return self._active[evType]
end

function EventService:CaptureState()
	if self._pendingRestore then return Util.DeepCopy(self._pendingRestore) end
	local stamp, active = os.clock(), {}
	for evType, entry in pairs(self._active) do
		local elapsed = math.max(0, stamp - entry.Data.StartedAt)
		local payload = Util.DeepCopy(entry.Data)
		payload.StartedAt = nil
		active[evType] = {
			Id = entry.Id, Data = payload, Elapsed = elapsed,
			Remaining = math.max(0, entry.Data.Duration - elapsed), OneShotConsumed = entry.OneShotConsumed == true,
			NextDropRemaining = entry.NextDropAt and math.max(0, entry.NextDropAt - stamp) or nil,
		}
	end
	return { SchemaVersion = 1, NextMinorRemaining = math.max(0, self._nextMinor - stamp), NextMajorRemaining = math.max(0, self._nextMajor - stamp), Active = active }
end

function EventService:RestoreState(state)
	if type(state) ~= "table" or state.SchemaVersion ~= 1 or type(state.Active) ~= "table"
		or not nonnegative(state.NextMinorRemaining) or not nonnegative(state.NextMajorRemaining) then return false, "InvalidEventSnapshot" end
	local active = {}
	for evType, entry in pairs(state.Active) do
		if (evType ~= "Minor" and evType ~= "Major") or type(entry) ~= "table" or type(entry.Id) ~= "string" or not EventsConfig.Definitions[entry.Id]
			or not nonnegative(entry.Elapsed) or not nonnegative(entry.Remaining) or not nonnegative(entry.Elapsed + entry.Remaining)
			or (entry.NextDropRemaining ~= nil and not nonnegative(entry.NextDropRemaining)) or type(entry.OneShotConsumed) ~= "boolean"
			or type(entry.Data) ~= "table" or not plain(entry.Data, 0, { 0 }) then return false, "InvalidEventSnapshot" end
		local payload = entry.Data
		if type(payload.InstanceId) ~= "string" or #payload.InstanceId < 1 or #payload.InstanceId > 80
			or payload.Type ~= evType or payload.EventId ~= entry.Id or type(payload.Biome) ~= "string" or not nonnegative(payload.Duration)
			or type(payload.Resolved) ~= "table" then return false, "InvalidEventSnapshot" end
		local interval = payload.Resolved.DropInterval or 0
		if not nonnegative(interval) or (interval > 0 and type(payload.Resolved.Drops) == "table" and #payload.Resolved.Drops > 0 and entry.NextDropRemaining == nil) then return false, "InvalidEventSnapshot" end
		if entry.NextDropRemaining ~= nil and (interval <= 0 or type(payload.Resolved.Drops) ~= "table" or #payload.Resolved.Drops == 0) then return false, "InvalidEventSnapshot" end
		if payload.Resolved.Drops ~= nil and type(payload.Resolved.Drops) ~= "table" then return false, "InvalidEventSnapshot" end
		for _, drop in ipairs(payload.Resolved.Drops or {}) do
			if type(drop) ~= "table" or type(drop.ItemId) ~= "string" or not nonnegative(drop.Chance or 0) or (drop.Chance or 0) > 1 then return false, "InvalidEventSnapshot" end
			local count = drop.Count or 1
			local minimum = type(count) == "table" and (count.min or 1) or count
			local maximum = type(count) == "table" and (count.max or 1) or count
			if not nonnegative(minimum) or not nonnegative(maximum) or minimum % 1 ~= 0 or maximum % 1 ~= 0 or minimum > maximum then return false, "InvalidEventSnapshot" end
		end
		active[evType] = {
			Id = entry.Id, Data = Util.DeepCopy(payload), Elapsed = entry.Elapsed, Remaining = entry.Remaining,
			OneShotConsumed = entry.OneShotConsumed, NextDropRemaining = entry.NextDropRemaining,
		}
	end
	self._pendingRestore = { SchemaVersion = 1, NextMinorRemaining = state.NextMinorRemaining, NextMajorRemaining = state.NextMajorRemaining, Active = active }
	if not paused() then return self:CompleteWorldRestore() end
	return true
end

function EventService:CompleteWorldRestore()
	local saved = self._pendingRestore
	if not saved then return true end
	self._pendingRestore = nil
	for _, active in pairs(self._active) do active.Data.CancelledForRestore = true end
	self:EndAll()
	local stamp = os.clock()
	self._nextMinor, self._nextMajor = stamp + saved.NextMinorRemaining, stamp + saved.NextMajorRemaining
	for evType, entry in pairs(saved.Active) do
		local payload = Util.DeepCopy(entry.Data)
		payload.StartedAt, payload.Duration, payload.Restored = stamp - entry.Elapsed, entry.Elapsed + entry.Remaining, true
		self._active[evType] = {
			Id = entry.Id, Data = payload, OneShotConsumed = entry.OneShotConsumed,
			NextDropAt = entry.NextDropRemaining and stamp + entry.NextDropRemaining or nil,
		}
		-- Reapply modifiers; the saved consumed flag prevents replaying one-shot loot.
		safeFire(self._remote, evType .. "_Start", entry.Id, payload)
		hook("Start", evType, entry.Id, payload)
		payload.Restored = nil
	end
	return true
end

function EventService:SendActiveToPlayer(plr)
	if not plr or not self._remote then return end
	for _, evType in ipairs({ "Minor", "Major" }) do
		local active = self._active[evType]
		if active and active.Id then
			self._remote:FireClient(plr, evType .. "_Start", active.Id, active.Data)
		end
	end
end

---------------------------------------------------------------------------
-- Drop spawning
---------------------------------------------------------------------------
function EventService:_spawnEventDrops(drops, active)
	local service = getItemDropService()
	if paused() or GameStateService:IsGameOver() or (active and self._active[active.Data.Type] ~= active) then return end
	for _, entry in ipairs(drops) do
		if math.random() <= (entry.Chance or 0) then
			local pos = getRandomPlayerPosition()
			if pos then
				local count = resolveCount(entry.Count)
				pcall(function()
					if paused() or (active and self._active[active.Data.Type] ~= active) then return end
					service:SpawnDrop(entry.ItemId, count, pos)
				end)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Tick loop
---------------------------------------------------------------------------
function EventService:_tick()
	if GameStateService:IsGameOver() or paused() then
		return
	end
	local cadence = EventsConfig.Cadence
	local currentBiome = BiomeService:GetCurrent()

	-- Check active events for expiry / biome change
	for evType, active in pairs(self._active) do
		if active then
			local expired = os.clock() - active.Data.StartedAt >= active.Data.Duration
			local biomeChanged = active.Data.Resolved
				and active.Data.Resolved.EndOnBiomeChange
				and active.Data.Biome ~= currentBiome
			if expired or biomeChanged then
				self:EndEvent(evType)
			elseif active.NextDropAt and os.clock() >= active.NextDropAt then
				active.NextDropAt = os.clock() + active.Data.Resolved.DropInterval
				self:_spawnEventDrops(active.Data.Resolved.Drops, active)
			elseif not active.NextDropAt and not active.OneShotConsumed then
				active.OneShotConsumed = true
				if active.Data.Resolved.Drops and #active.Data.Resolved.Drops > 0 then self:_spawnEventDrops(active.Data.Resolved.Drops, active) end
			end
		end
	end

	-- Schedule minor events
	if os.clock() >= (self._nextMinor or 0) and not self._active.Minor then
		local id, overrides = self:SelectEvent(currentBiome, "Minor")
		if id then
			self:TriggerEvent(id, currentBiome, overrides)
		end
		self._nextMinor = scheduleWindow(cadence.MinorCadence)
	end

	-- Schedule major events
	if os.clock() >= (self._nextMajor or 0) and not self._active.Major then
		local id, overrides = self:SelectEvent(currentBiome, "Major")
		if id then
			self:TriggerEvent(id, currentBiome, overrides)
		end
		self._nextMajor = scheduleWindow(cadence.MajorCadence)
	end
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------
function EventService:Init()
	if self._started then return end
	self._started = true
	if self._remote and not self._requestConn then
		self._requestConn = self._remote.OnServerEvent:Connect(function(plr, action)
			if action == "RequestActive" then
				self:SendActiveToPlayer(plr)
			end
		end)
	end

	local cadence = EventsConfig.Cadence
	self._nextMinor = scheduleWindow(cadence.MinorCadence)
	self._nextMajor = scheduleWindow(cadence.MajorCadence)

	task.spawn(function()
		while self._started do
			pcall(function()
				self:_tick()
			end)
			task.wait(self._tickInterval)
		end
	end)
end

return EventService
