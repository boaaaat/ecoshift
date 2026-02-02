-- BiomeService.lua
-- Tracks current biome and schedules periodic shifts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local BiomeService = {}
BiomeService._current = nil
BiomeService._data = nil
BiomeService._nextShift = 0
BiomeService._started = false
BiomeService._remotesFolder = nil
BiomeService._remote = nil
BiomeService._lastChangedAt = 0

local function buildPool(startTime)
	local pool = {}
	for name, data in pairs(Config.BIOMES or {}) do
		local weight = data.Weight or data.weight or 1
		local scaled = data.TimeScaledWeight or data.timeScaledWeight or 0
		if scaled ~= 0 then
			local elapsed = os.clock() - (startTime or os.clock())
			local denom = (Config.BIOME_SHIFT and Config.BIOME_SHIFT.TimeScaleSeconds) or 900
			weight = weight + (scaled * (elapsed / math.max(denom, 1)))
		end
		table.insert(pool, { Id = name, Weight = weight })
	end
	return pool
end

local function pickDefault()
	if Config.BIOME_DEFAULT and Config.BIOMES[Config.BIOME_DEFAULT] then
		return Config.BIOME_DEFAULT
	end
	for name in pairs(Config.BIOMES or {}) do
		return name
	end
	return "Unknown"
end

function BiomeService:_ensureRemote()
	if self._remote then return end
	self._remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	self._remote = Util.GetRemote(self._remotesFolder, Config.RemoteNames.BiomeChanged)
end

function BiomeService:_broadcast()
	self:_ensureRemote()
	if self._remote and self._remote.FireAllClients then
		self._remote:FireAllClients(self._current, self._data)
	end
end

function BiomeService:SendToPlayer(plr)
	self:_ensureRemote()
	if self._remote and self._remote.FireClient then
		self._remote:FireClient(plr, self._current, self._data)
	end
end

function BiomeService:GetCurrent()
	if not self._current then
		self:SetCurrent(pickDefault(), "Init")
	end
	return self._current
end

function BiomeService:GetData()
	if not self._data then
		self:SetCurrent(self:GetCurrent(), "Init")
	end
	return self._data
end

function BiomeService:SetCurrent(name, reason)
	if not name or not Config.BIOMES[name] then
		return false
	end
	self._current = name
	self._data = Config.BIOMES[name]
	self._lastChangedAt = os.clock()
	self:_broadcast()
	_G.Ecoshift = _G.Ecoshift or {}
	local list = _G.Ecoshift.BiomeChangedCallbacks
	if type(list) == "table" then
		for _, cb in ipairs(list) do
			if type(cb) == "function" then
				pcall(cb, name, self._data, reason)
			end
		end
	end
	return true
end

function BiomeService:_scheduleNext()
	local window = Config.BIOME_SHIFT or {}
	local minS = tonumber(window.MinSeconds) or 300
	local maxS = tonumber(window.MaxSeconds) or 480
	if maxS < minS then maxS = minS end
	self._nextShift = os.clock() + math.random(minS, maxS)
end

function BiomeService:_pickNext()
	local pool = buildPool(self._startTime)
	if #pool == 0 then return self._current end
	if #pool == 1 then
		return pool[1].Id or self._current
	end
	-- Never pick the current biome if there's more than one choice
	local filtered = {}
	for _, entry in ipairs(pool) do
		if entry.Id ~= self._current then
			table.insert(filtered, entry)
		end
	end
	if #filtered == 0 then
		return self._current
	end
	local pick = Util.ChooseWeighted(filtered, "Weight")
	return (pick and pick.Id) or self._current
end

function BiomeService:Init()
	if self._started then return end
	self._started = true
	self._startTime = os.clock()
	self:SetCurrent(pickDefault(), "Init")
	self:_scheduleNext()
	_G.Ecoshift = _G.Ecoshift or {}
	_G.Ecoshift.BiomeChangedCallbacks = _G.Ecoshift.BiomeChangedCallbacks or {}
	_G.Ecoshift.OnBiomeChangedAdd = function(cb)
		if type(cb) == "function" then
			table.insert(_G.Ecoshift.BiomeChangedCallbacks, cb)
		end
	end
	-- OPTIMIZED: Use task.spawn with sleep instead of Heartbeat to reduce per-frame overhead
	task.spawn(function()
		while true do
			if os.clock() >= self._nextShift then
				local nextBiome = self:_pickNext()
				self:SetCurrent(nextBiome, "Timer")
				self:_scheduleNext()
			end
			task.wait(1) -- Check once per second instead of every frame
		end
	end)
end

return BiomeService
