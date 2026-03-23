-- ObjectiveService.lua (updated with _G hooks)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local BiomeService = require(script.Parent.BiomeService)
local ThreatService = require(script.Parent.ThreatService)
local GameStateService = require(script.Parent.GameStateService)

local ObjectiveService = {}
ObjectiveService._remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
ObjectiveService._remote = Util.GetRemote(ObjectiveService._remotesFolder, Config.RemoteNames.ObjectiveUpdate)
ObjectiveService._active = {} -- [id] = {StartedAt, EndsAt, State, Biome, Data}
ObjectiveService._tickInterval = 0.25
ObjectiveService._started = false

local function now() return os.clock() end
local function withinWindow(range)
	local min = tonumber(range and range[1]) or 60
	local max = tonumber(range and range[2]) or min
	if max < min then max = min end
	return math.random(min, max)
end
local function hook(kind, ...)
	local list = _G.Ecoshift and _G.Ecoshift.ObjectiveCallbacks and _G.Ecoshift.ObjectiveCallbacks[kind]
	if type(list) == "table" then
		for _, cb in ipairs(list) do
			if type(cb) == "function" then
				pcall(cb, ...)
			end
		end
	end
end

function ObjectiveService:_eligiblePool(minute)
	local pool = {}
	for _,entry in ipairs(Config.OBJECTIVES.Pool) do
		if (entry.MinMinute or 0) <= minute then table.insert(pool, entry.Id) end
	end
	return pool
end

function ObjectiveService:_start(id)
	if GameStateService:IsGameOver() then
		return
	end
	local dur = withinWindow(Config.OBJECTIVES.DurationSeconds)
	self._active[id] = {
		State = "Active",
		StartedAt = now(),
		EndsAt = now() + dur,
		Biome = BiomeService:GetCurrent(),
		Data = {Progress=0}
	}
	if self._remote and self._remote.FireAllClients then self._remote:FireAllClients("Start", id, self._active[id]) end
	hook("Start", id, self._active[id])
end

function ObjectiveService:_end(id, state, opts)
	local entry = self._active[id]
	if not entry then return end
	entry.State = state
	if self._remote and self._remote.FireAllClients then self._remote:FireAllClients("End", id, entry) end
	if state == "Failed" and not (opts and opts.SuppressThreat) then
		ThreatService:OnObjectiveFailed()
	end
	hook("End", id, entry)
	self._active[id] = nil
end

function ObjectiveService:Advance(id, progressDelta)
	if GameStateService:IsGameOver() then
		return false, "GameOver"
	end
	local entry = self._active[id]; if not entry or entry.State ~= "Active" then return end
	entry.Data.Progress = math.clamp((entry.Data.Progress or 0) + (progressDelta or 0), 0, 1)
	if self._remote and self._remote.FireAllClients then self._remote:FireAllClients("Progress", id, entry.Data.Progress) end
	hook("Progress", id, entry.Data.Progress)
	if entry.Data.Progress >= 1 then self:_end(id, "Completed") end
end

function ObjectiveService:EndAll(state, opts)
	local ids = {}
	for id in pairs(self._active) do
		ids[#ids + 1] = id
	end
	for _, id in ipairs(ids) do
		self:_end(id, state or "Failed", opts)
	end
end

function ObjectiveService:_tick()
	if GameStateService:IsGameOver() then
		return
	end
	local minute = math.floor((now() - (self._t0 or now())) / 60)
	local need = Config.OBJECTIVES.MaxConcurrent - (function() local c=0 for _ in pairs(self._active) do c+=1 end return c end)()
	if need > 0 then
		local pool = self:_eligiblePool(minute)
		for _=1,need do
			if #pool == 0 then break end
			local pickIdx = math.random(1, #pool)
			local id = table.remove(pool, pickIdx)
			if not self._active[id] then self:_start(id) end
		end
	end
	for id,entry in pairs(self._active) do
		if entry.State == "Active" then
			if now() >= entry.EndsAt or entry.Biome ~= BiomeService:GetCurrent() then
				self:_end(id, "Failed")
			end
		end
	end
end

function ObjectiveService:Init()
	if self._started then return end
	self._started = true
	self._t0 = now()
	_G.Ecoshift = _G.Ecoshift or {}
	_G.Ecoshift.ObjectiveCallbacks = _G.Ecoshift.ObjectiveCallbacks or { Start = {}, End = {}, Progress = {} }
	_G.Ecoshift.OnObjectiveStartAdd = function(cb) if type(cb) == "function" then table.insert(_G.Ecoshift.ObjectiveCallbacks.Start, cb) end end
	_G.Ecoshift.OnObjectiveEndAdd = function(cb) if type(cb) == "function" then table.insert(_G.Ecoshift.ObjectiveCallbacks.End, cb) end end
	_G.Ecoshift.OnObjectiveProgressAdd = function(cb) if type(cb) == "function" then table.insert(_G.Ecoshift.ObjectiveCallbacks.Progress, cb) end end
	task.spawn(function()
		while self._started do
			pcall(function()
				self:_tick()
			end)
			task.wait(self._tickInterval)
		end
	end)
end

return ObjectiveService
