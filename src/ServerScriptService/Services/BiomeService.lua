-- Server-owned shift schedule; forecasts and controls share this single state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local BiomeConfig = require(ReplicatedStorage.Shared.BiomeConfig)
local SurvivalConfig = require(ReplicatedStorage.Shared.SurvivalConfig)
local OverhaulBiomes = require(ReplicatedStorage.Shared.OverhaulBiomes)
local Players = game:GetService("Players")
local Util = require(ReplicatedStorage.Shared.Util)
local BiomeService = { _started = false, _shiftCount = 0, _version = 0 }

local function weatherEligible(weather, elapsed)
 local tier=ReplicatedStorage:GetAttribute("CampaignTier") or 1
 local visits=BiomeService._shiftCount or 0
 return (elapsed or 0)>=(weather.MinElapsed or 0) and tier>=(weather.MinTier or 1) and visits>=(weather.MinVisits or 0)
end
local function weatherFor(biome, elapsed)
	local eligible = {}
	for _, weather in ipairs(SurvivalConfig.WEATHER_BY_BIOME[biome] or {}) do
		if weatherEligible(weather, elapsed) then table.insert(eligible, weather) end
	end
	local pick = Util.ChooseWeighted(eligible, "Weight")
	return pick or { Id = "Clear", Name = "Clear skies", Temp = 0, Toxin = 0, Wet = 0 }
end
function BiomeService:GetElapsed()
	return math.max(0, (self._pausedAt or os.clock()) - (self._startTime or os.clock()))
end
function BiomeService:GetEligibleBiomes()
 local pool={};local tier=ReplicatedStorage:GetAttribute("CampaignTier") or 1
 for id,data in pairs(OverhaulBiomes.Biomes) do if tier>=data.UnlockTier then table.insert(pool,id) end end
 table.sort(pool);return pool
end
function BiomeService:_pickNext()
 local pool={};local newest=math.min(4,ReplicatedStorage:GetAttribute("CampaignTier") or 1)
 local uniform=ReplicatedStorage:GetAttribute("MainBiomesUniform")==true
 for _,id in ipairs(self:GetEligibleBiomes()) do
  if id~=self._current then table.insert(pool,{Id=id,Weight=not uniform and OverhaulBiomes.Biomes[id].UnlockTier==newest and 2 or 1}) end
 end
 local pick=Util.ChooseWeighted(pool,"Weight");return pick and pick.Id or self._current
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
	do
		self._visits = self._visits or {}
		self._encounters = self._encounters or {}
		self._encounters[name] = (self._encounters[name] or 0) + 1
		self._previousVisits = self._visits[name] or 0
		self._arrivalTier = ReplicatedStorage:GetAttribute("CampaignTier") or 1
		self._visitActive, self._visitCredited = 0, false
		ReplicatedStorage:SetAttribute("CurrentBiome",name)
		ReplicatedStorage:SetAttribute("BiomeVisitQualified",false)
	end
	self._weather = forecast or weatherFor(name, self:GetElapsed())
	self._lastChangedAt = os.clock()
	self._nextWeatherChange = self._data.WeatherCycle and (os.clock() + (self._data.WeatherCycleSeconds or 60)) or nil
	if wasStarted then self._shiftCount += 1 end
 ReplicatedStorage:SetAttribute("BiomeVisitSerial",self._shiftCount)
	self:_scheduleNext()
	self:_broadcast()
	for _, cb in ipairs((_G.Ecoshift or {}).BiomeChangedCallbacks or {}) do
		local ok, err = pcall(cb, name, self._data, reason)
		if not ok then warn("[BiomeService] Shift callback failed:", err) end
	end
	return true
end
function BiomeService:CanControl(action, target, version)
 if self._pausedAt then return false,"The expedition has ended." end
 if ReplicatedStorage:GetAttribute("WorldShifting") or ReplicatedStorage:GetAttribute("WorldRestoring") then return false,"Wait for the world to finish loading." end
 if version~=self._version then return false,"The shift schedule changed. Propose a new vote." end
 local remaining=self:GetTiming().Remaining
 if remaining<=15 then return false,"The shift is already imminent." end
 if action=="Delay" then
  if self._delayed then return false,"This visit has already been stabilized." end
  if self._duration+60>600 then return false,"All extensions share a 600-second visit limit." end
 elseif action=="Advance" then
  if os.clock()-self._lastChangedAt<60 then return false,"Spend at least one active minute in this biome first." end
 elseif action=="Select" or action=="Anchor" then
  local biome=type(target)=="table" and target.Biome or target
  if type(biome)~="string" or not table.find(self:GetEligibleBiomes(),biome) then return false,"Choose an eligible main biome." end
  if biome==self._current then return false,"Choose a different main biome." end
  if self._selected then return false,"A destination is already locked for this visit." end
  if action=="Select" and (self:GetVisits()[biome] or 0)<1 then return false,"The World Dial requires a previously visited biome." end
  if action=="Anchor" then
   if type(target)~="table" or type(target.Extend)~="boolean" then return false,"Choose an anchor destination and extension option." end
   local valid=false
   for _,weather in ipairs(SurvivalConfig.WEATHER_BY_BIOME[biome] or {}) do
    if weather.Id==target.Weather and (weather.MinTier or 1)<=(ReplicatedStorage:GetAttribute("CampaignTier") or 1) then valid=true;break end
   end
   if not valid then return false,"Choose eligible base weather for this destination." end
  end
 else return false,"Unknown world control." end
 return true
end
function BiomeService:ApplyControl(action,target,version)
 local ok,message=self:CanControl(action,target,version);if not ok then return false,message end
 if action=="Delay" then self._nextShift+=60;self._duration+=60;self._delayed=true
 elseif action=="Advance" then self._nextShift=os.clock()+15
 else
  local biome=type(target)=="table" and target.Biome or target
  self._upcomingBiome,self._selected=biome,true
  if action=="Anchor" then
   for _,weather in ipairs(SurvivalConfig.WEATHER_BY_BIOME[biome] or {}) do if weather.Id==target.Weather then self._upcomingWeather=Util.DeepCopy(weather);break end end
   if target.Extend then self._nextShift+=math.max(0,600-self._duration);self._duration=600 end
  else self._upcomingWeather=weatherFor(biome,self:GetElapsed()+self:GetTiming().Remaining) end
 end
 self._version+=1;return true
end
function BiomeService:Pause()
	self._pausedAt = self._pausedAt or os.clock()
end

function BiomeService:SetCreativeWeather(id)
	if workspace:GetAttribute("WorldType") ~= "Creative" or self._pausedAt then return false, "Creative weather is unavailable." end
	for _, weather in ipairs(SurvivalConfig.WEATHER_BY_BIOME[self:GetCurrent()] or {}) do
		if weather.Id == id then
			self._weather = Util.DeepCopy(weather)
			self._nextWeatherChange = self._data.WeatherCycle and os.clock() + (self._data.WeatherCycleSeconds or 60) or nil
			self:_broadcast()
			require(script.Parent.GameStateService):Broadcast()
			return true, "Weather changed to " .. weather.Name .. "."
		end
	end
	return false, "Choose weather available in the current biome."
end

function BiomeService:SetCreativeShiftTimer(seconds)
	if workspace:GetAttribute("WorldType") ~= "Creative" or self._pausedAt then return false, "Creative timing is unavailable." end
	if type(seconds) ~= "number" or seconds ~= seconds or seconds < 5 or seconds > 3600 or seconds % 1 ~= 0 then return false, "Choose 5 to 3600 seconds." end
	self:GetCurrent()
	self._nextShift = os.clock() + seconds
	self._duration = math.max(self._duration, seconds)
	self._version += 1
	require(script.Parent.GameStateService):Broadcast()
	return true, "Next biome shift in " .. seconds .. " seconds."
end

function BiomeService:CaptureWorldState()
	local timing, now = self:GetTiming(), self._pausedAt or os.clock()
	return { ArrivalTier=self._arrivalTier or 1, Visits = Util.DeepCopy(self._visits or {}), Encounters = Util.DeepCopy(self._encounters or {}), PreviousVisits = self._previousVisits or 0, VisitActive = self._visitActive or 0, VisitCredited = self._visitCredited == true, Biome = self._current, Weather = Util.DeepCopy(self._weather), Elapsed = self:GetElapsed(), Remaining = timing.Remaining,
		Duration = self._duration, ShiftCount = self._shiftCount, Version = self._version, UpcomingBiome = self._upcomingBiome,
		UpcomingWeather = Util.DeepCopy(self._upcomingWeather), Delayed = self._delayed, Selected = self._selected,
		SinceChange = math.max(0, now - self._lastChangedAt), WeatherRemaining = self._nextWeatherChange and math.max(0, self._nextWeatherChange - now) or false }
end

function BiomeService:RestoreWorldState(state)
	local Codec = require(script.Parent.WorldSnapshotCodec)
	assert(BiomeConfig.BIOMES[state.Biome] and BiomeConfig.BIOMES[state.UpcomingBiome], "Saved biome is unavailable")
	local now = os.clock()
 self._arrivalTier = Codec.Number(state.ArrivalTier or 1,1,8)
	self._visits = Codec.Copy(state.Visits or {})
	self._encounters = Codec.Copy(state.Encounters or state.Visits or {})
	if (self._encounters[state.Biome] or 0) < 1 then self._encounters[state.Biome] = 1 end
 self._previousVisits = Codec.Number(state.PreviousVisits or 0,0,1e8)
 self._visitActive = Codec.Number(state.VisitActive or 0,0,120)
 self._visitCredited = state.VisitCredited == true
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
 ReplicatedStorage:SetAttribute("CurrentBiome",self._current)
 ReplicatedStorage:SetAttribute("BiomeVisitSerial",self._shiftCount)
 ReplicatedStorage:SetAttribute("BiomeVisitQualified",self._visitCredited)
 ReplicatedStorage:SetAttribute("BiomeMaturity",self:GetMaturity())
end

function BiomeService:GetPreviousVisits() return self._previousVisits or 0 end
function BiomeService:GetVisitSerial() return self._shiftCount or 0 end
function BiomeService:GetVisits() return table.clone(self._visits or {}) end
function BiomeService:GetEncounters() return table.clone(self._encounters or {}) end
function BiomeService:GetMaturity()
 local tier = self._arrivalTier or 1
 local cap = tier <= 2 and .65 or tier <= 4 and .8 or 1
 return math.min(cap, .35 + .15 * math.min(4,self:GetPreviousVisits()))
end
function BiomeService:_activeVisitStep(dt)
 local active, participating = false, false
 local rewards = require(script.Parent.ExpeditionRewardsService)
 for _, player in ipairs(Players:GetPlayers()) do
  local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
  if hum and hum.Health>0 and not player:GetAttribute("IsDead") and not player:GetAttribute("WorldPlayerLoading") and not player:GetAttribute("WorldPlayerRestoring") then
   active = true
   local activity = (rewards._activity or {})[player]
   if not player:GetAttribute("InteriorId") and activity and os.clock() - (activity.LastAction or 0) < 120 then participating = true end
  end
 end
 if ReplicatedStorage:GetAttribute("WorldShifting") or ReplicatedStorage:GetAttribute("WorldRestoring") then active, participating = false, false end
 if not active then
  self._startTime += dt; self._nextShift += dt; self._lastChangedAt += dt
  if self._nextWeatherChange then self._nextWeatherChange += dt end
 elseif participating and not self._visitCredited then
  self._visitActive = math.min(120,(self._visitActive or 0)+dt)
  if self._visitActive >= 120 then
   self._visits = self._visits or {}
   self._visits[self._current] = (self._visits[self._current] or 0)+1
   self._visitCredited = true
   ReplicatedStorage:SetAttribute("BiomeVisitQualified",true)
  end
 end
 ReplicatedStorage:SetAttribute("BiomeMaturity",self:GetMaturity())
 return active
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
		local last = os.clock()
  while not self._pausedAt do
   local now = os.clock(); local dt = math.min(1,now-last); last = now
   if not self:_activeVisitStep(dt) then task.wait(.25); continue end
			if ReplicatedStorage:GetAttribute("WorldRestoring") then task.wait(0.25); continue end
			if os.clock() >= self._nextShift then self:SetCurrent(self._upcomingBiome, "Timer") end
			if self._nextWeatherChange and os.clock() >= self._nextWeatherChange then
				local cycle = self._data.WeatherCycle
				local index = table.find(cycle, self._weather.Id) or 0
				local nextId = cycle[index % #cycle + 1]
				for _, weather in ipairs(SurvivalConfig.WEATHER_BY_BIOME[self._current] or {}) do
					if weather.Id == nextId and weatherEligible(weather, self:GetElapsed()) then self._weather = weather; break end
				end
				self._nextWeatherChange = os.clock() + (self._data.WeatherCycleSeconds or 60)
			end
			task.wait(0.25)
		end
	end)
end
return BiomeService
