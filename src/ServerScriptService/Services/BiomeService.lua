-- Server-owned shift schedule; forecasts and controls share this single state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local BiomeConfig = require(ReplicatedStorage.Shared.BiomeConfig)
local SurvivalConfig = require(ReplicatedStorage.Shared.SurvivalConfig)
local Util = require(ReplicatedStorage.Shared.Util)
local BiomeService = { _started = false, _shiftCount = 0, _version = 0 }

local function weatherFor(biome, elapsed)
	local eligible = {}
	for _, weather in ipairs(SurvivalConfig.WEATHER_BY_BIOME[biome] or {}) do
		if (elapsed or 0) >= (weather.MinElapsed or 0) then table.insert(eligible, weather) end
	end
	local pick = Util.ChooseWeighted(eligible, "Weight")
	return pick or { Id = "Clear", Name = "Clear skies", Temp = 0, Toxin = 0, Wet = 0 }
end
function BiomeService:GetElapsed()
	return math.max(0, (self._pausedAt or os.clock()) - (self._startTime or os.clock()))
end
function BiomeService:GetEligibleBiomes(elapsed)
	local pool = {}
	for name, data in pairs(BiomeConfig.BIOMES) do
		local enabled = (data.Weight or data.weight or 1) > 0 or (data.TimeScaledWeight or data.timeScaledWeight or 0) > 0
		if enabled and (elapsed or self:GetElapsed()) >= (data.MinElapsed or data.minElapsed or 0) then
			table.insert(pool, name)
		end
	end
	table.sort(pool)
	return pool
end
function BiomeService:_pickNext(elapsed)
	local pool = {}
	for _, name in ipairs(self:GetEligibleBiomes(elapsed)) do
		local data = BiomeConfig.BIOMES[name]
		local weight = (data.Weight or data.weight or 1) +
			(data.TimeScaledWeight or data.timeScaledWeight or 0) * elapsed /
			math.max(1, (BiomeConfig.BIOME_SHIFT or {}).TimeScaleSeconds or 900)
		if name ~= self._current then
			table.insert(pool, { Id = name, Weight = math.max((BiomeConfig.BIOME_SHIFT or {}).MinimumWeight or 0.4, weight) })
		end
	end
	local pick = Util.ChooseWeighted(pool, "Weight")
	return pick and pick.Id or self._current
end
function BiomeService:_ensureRemote()
	self._remote = self._remote or ReplicatedStorage.Remotes:FindFirstChild(Config.RemoteNames.BiomeChanged)
end
function BiomeService:_broadcast()
	self:_ensureRemote()
	if self._remote then self._remote:FireAllClients(self._current, self._data) end
end
function BiomeService:SendToPlayer(player)
	self:_ensureRemote()
	if self._remote then self._remote:FireClient(player, self:GetCurrent(), self:GetData()) end
end
function BiomeService:GetCurrent()
	if not self._current then self:SetCurrent(BiomeConfig.BIOME_DEFAULT or "Forest", "Init") end
	return self._current
end
function BiomeService:GetData()
	self:GetCurrent()
	return self._data
end
function BiomeService:GetWeather()
	self:GetCurrent()
	return self._weather
end
function BiomeService:GetTiming()
	self:GetCurrent()
	return {
		Remaining = math.max(0, self._nextShift - (self._pausedAt or os.clock())),
		Duration = self._duration, ShiftCount = self._shiftCount, Version = self._version,
		UpcomingBiome = self._upcomingBiome, UpcomingWeather = self._upcomingWeather,
	}
end
function BiomeService:_scheduleNext()
	local window = BiomeConfig.BIOME_SHIFT or {}
	local min = math.max(15, math.floor(window.MinSeconds or 300))
	local max = math.max(min, math.floor(window.MaxSeconds or min))
	self._duration = math.random(min, max)
	self._nextShift = os.clock() + self._duration
	self._upcomingBiome = self:_pickNext(self:GetElapsed() + self._duration)
	self._upcomingWeather = weatherFor(self._upcomingBiome, self:GetElapsed() + self._duration)
	self._delayed, self._selected = false, false
	self._version += 1
end
function BiomeService:SetCurrent(name, reason)
	if not BiomeConfig.BIOMES[name] or self._pausedAt then return false end
	local wasStarted = self._current ~= nil
	local forecast = name == self._upcomingBiome and self._upcomingWeather or nil
	self._current, self._data = name, BiomeConfig.BIOMES[name]
	self._weather = forecast or weatherFor(name, self:GetElapsed())
	self._lastChangedAt = os.clock()
	self._nextWeatherChange = self._data.WeatherCycle and (os.clock() + (self._data.WeatherCycleSeconds or 60)) or nil
	if wasStarted then self._shiftCount += 1 end
	self:_scheduleNext()
	self:_broadcast()
	for _, cb in ipairs((_G.Ecoshift or {}).BiomeChangedCallbacks or {}) do
		local ok, err = pcall(cb, name, self._data, reason)
		if not ok then warn("[BiomeService] Shift callback failed:", err) end
	end
	return true
end
function BiomeService:CanControl(action, biome, version)
	if self._pausedAt then return false, "The expedition has ended." end
	if version ~= self._version then return false, "The shift schedule changed. Propose a new vote." end
	local remaining = self:GetTiming().Remaining
	if action == "Delay" then
		if self._delayed then return false, "This shift has already been stabilized." end
		if remaining <= 15 then return false, "The shift is already imminent." end
	elseif action == "Advance" then
		if os.clock() - self._lastChangedAt < 60 then return false, "Spend at least a minute in this biome first." end
		if remaining <= 15 then return false, "The shift is already imminent." end
		if not table.find(self:GetEligibleBiomes(self:GetElapsed() + 15), self._upcomingBiome) then
			return false, "The next transition is not available early yet. Its forecast is unchanged."
		end
	elseif action == "Select" then
		if self._selected then return false, "A destination is already locked for this shift." end
		if remaining <= 15 then return false, "The shift is already imminent." end
		if biome == self._current or not table.find(self:GetEligibleBiomes(), biome) then
			return false, "Choose another biome that is unlocked in this run."
		end
	else return false, "Unknown world control." end
	return true
end
function BiomeService:ApplyControl(action, biome, version)
	local ok, message = self:CanControl(action, biome, version)
	if not ok then return false, message end
	if action == "Delay" then
		self._nextShift += 60; self._duration += 60; self._delayed = true
	elseif action == "Advance" then
		self._nextShift = os.clock() + 15
	elseif action == "Select" then
		self._upcomingBiome, self._selected = biome, true
		self._upcomingWeather = weatherFor(biome, self:GetElapsed() + remaining)
	end
	self._version += 1
	return true
end
function BiomeService:Pause()
	self._pausedAt = self._pausedAt or os.clock()
end

function BiomeService:CaptureWorldState()
	local timing, now = self:GetTiming(), self._pausedAt or os.clock()
	return { Biome = self._current, Weather = Util.DeepCopy(self._weather), Elapsed = self:GetElapsed(), Remaining = timing.Remaining,
		Duration = self._duration, ShiftCount = self._shiftCount, Version = self._version, UpcomingBiome = self._upcomingBiome,
		UpcomingWeather = Util.DeepCopy(self._upcomingWeather), Delayed = self._delayed, Selected = self._selected,
		SinceChange = math.max(0, now - self._lastChangedAt), WeatherRemaining = self._nextWeatherChange and math.max(0, self._nextWeatherChange - now) or false }
end

function BiomeService:RestoreWorldState(state)
	local Codec = require(script.Parent.WorldSnapshotCodec)
	assert(BiomeConfig.BIOMES[state.Biome] and BiomeConfig.BIOMES[state.UpcomingBiome], "Saved biome is unavailable")
	local now = os.clock()
	self._startTime = now - Codec.Number(state.Elapsed, 0, 1e9)
	self._current, self._data = state.Biome, BiomeConfig.BIOMES[state.Biome]
	self._weather, self._upcomingWeather = Codec.Copy(state.Weather), Codec.Copy(state.UpcomingWeather)
	self._upcomingBiome = state.UpcomingBiome
	self._duration = Codec.Number(state.Duration, 1, 86400)
	self._nextShift = now + Codec.Number(state.Remaining, 0, 86400)
	self._shiftCount, self._version = Codec.Number(state.ShiftCount, 0, 1e8), Codec.Number(state.Version, 0, 1e9)
	self._delayed, self._selected = state.Delayed == true, state.Selected == true
	self._lastChangedAt = now - Codec.Number(state.SinceChange, 0, 1e9)
	self._nextWeatherChange = state.WeatherRemaining ~= false and now + Codec.Number(state.WeatherRemaining, 0, 86400) or nil
	self._pausedAt = nil
	self._restored = true
end

function BiomeService:Init()
	if self._started then return end
	self._started, self._startTime = true, self._startTime or os.clock()
	_G.Ecoshift = _G.Ecoshift or {}
	_G.Ecoshift.BiomeChangedCallbacks = _G.Ecoshift.BiomeChangedCallbacks or {}
	_G.Ecoshift.OnBiomeChangedAdd = function(cb)
		if type(cb) == "function" then table.insert(_G.Ecoshift.BiomeChangedCallbacks, cb) end
	end
	if self._restored then self:_broadcast() else self:SetCurrent(BiomeConfig.BIOME_DEFAULT or "Forest", "Init") end
	task.spawn(function()
		while not self._pausedAt do
			if ReplicatedStorage:GetAttribute("WorldRestoring") then task.wait(0.25); continue end
			if os.clock() >= self._nextShift then self:SetCurrent(self._upcomingBiome, "Timer") end
			if self._nextWeatherChange and os.clock() >= self._nextWeatherChange then
				local cycle = self._data.WeatherCycle
				local index = table.find(cycle, self._weather.Id) or 0
				local nextId = cycle[index % #cycle + 1]
				for _, weather in ipairs(SurvivalConfig.WEATHER_BY_BIOME[self._current] or {}) do
					if weather.Id == nextId and self:GetElapsed() >= (weather.MinElapsed or 0) then self._weather = weather; break end
				end
				self._nextWeatherChange = os.clock() + (self._data.WeatherCycleSeconds or 60)
			end
			task.wait(0.25)
		end
	end)
end
return BiomeService
