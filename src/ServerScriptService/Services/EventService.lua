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

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local EventsConfig = require(ReplicatedStorage.Shared.EventsConfig)
local ThreatService = require(script.Parent.ThreatService)
local BiomeService = require(script.Parent.BiomeService)

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
EventService._dropThreads = {}

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
	local resolved = self:ResolveEvent(eventId, biomeName, optionalOverrides)
	if not resolved then return nil end

	local evType = resolved.Type or "Minor"

	-- Compute duration
	local dur = resolved.Duration
	local duration = (type(dur) == "table") and math.random(dur.min or 45, dur.max or 75) or (tonumber(dur) or 60)

	-- Build payload
	local payload = {
		Biome = biomeName or BiomeService:GetCurrent(),
		Threat = ThreatService:Get(),
		Duration = duration,
		StartedAt = os.clock(),
		Type = evType,
		EventId = eventId,
		Resolved = resolved,
	}

	-- Store active
	self._active[evType] = { Id = eventId, Data = payload }

	-- Fire remote to clients
	safeFire(self._remote, evType .. "_Start", eventId, payload)

	-- Fire _G hooks (backward compat)
	hook("Start", evType, eventId, payload)

	-- Handle drops
	if resolved.Drops and #resolved.Drops > 0 then
		local dropInterval = tonumber(resolved.DropInterval) or 0
		if dropInterval > 0 then
			-- Recurring drop loop
			local threadKey = evType .. "_drop"
			self._dropThreads[threadKey] = true
			task.spawn(function()
				while self._dropThreads[threadKey] and self._active[evType] and self._active[evType].Id == eventId do
					self:_spawnEventDrops(resolved.Drops)
					task.wait(dropInterval)
				end
				self._dropThreads[threadKey] = nil
			end)
		else
			-- One-shot drops
			self:_spawnEventDrops(resolved.Drops)
		end
	end

	return resolved
end

function EventService:EndEvent(evType)
	local active = self._active[evType]
	if not active then return end

	-- Kill drop thread
	self._dropThreads[evType .. "_drop"] = nil

	safeFire(self._remote, evType .. "_End", active.Id, active.Data)
	hook("End", evType, active.Id, active.Data)
	self._active[evType] = nil
end

function EventService:GetActive(evType)
	return self._active[evType]
end

---------------------------------------------------------------------------
-- Drop spawning
---------------------------------------------------------------------------
function EventService:_spawnEventDrops(drops)
	for _, entry in ipairs(drops) do
		if math.random() <= (entry.Chance or 0) then
			local pos = getRandomPlayerPosition()
			if pos then
				local count = resolveCount(entry.Count)
				pcall(function()
					getItemDropService():SpawnDrop(entry.ItemId, count, pos)
				end)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Tick loop
---------------------------------------------------------------------------
function EventService:_tick()
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
