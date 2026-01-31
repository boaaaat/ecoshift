-- DayNightService.lua
-- Manages the day/night cycle with gameplay effects
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local DayNightService = {}
DayNightService._remotesFolder = nil
DayNightService._remote = nil
DayNightService._currentTime = 6 -- Start at 6 AM (sunrise)
DayNightService._paused = false
DayNightService._callbacks = {}

-- Time phases
local PHASES = {
	Dawn = { start = 5, finish = 7 },
	Day = { start = 7, finish = 17 },
	Dusk = { start = 17, finish = 19 },
	Night = { start = 19, finish = 5 },
}

local function getConfig()
	return Config.DAY_NIGHT or {
		CycleDurationSeconds = 600, -- 10 real minutes = 1 full day
		EnemyNightMultiplier = 1.5,
		ResourceNightMultiplier = 0.7,
		NightVisionRequired = true,
	}
end

local function hook(kind, ...)
	local list = _G.Ecoshift and _G.Ecoshift.DayNightCallbacks and _G.Ecoshift.DayNightCallbacks[kind]
	if type(list) == "table" then
		for _, cb in ipairs(list) do
			if type(cb) == "function" then
				pcall(cb, ...)
			end
		end
	end
	-- Internal callbacks
	for _, cb in ipairs(DayNightService._callbacks) do
		if type(cb) == "function" then
			pcall(cb, kind, ...)
		end
	end
end

function DayNightService:GetPhase()
	local t = self._currentTime
	if t >= PHASES.Dawn.start and t < PHASES.Dawn.finish then
		return "Dawn"
	elseif t >= PHASES.Day.start and t < PHASES.Day.finish then
		return "Day"
	elseif t >= PHASES.Dusk.start and t < PHASES.Dusk.finish then
		return "Dusk"
	else
		return "Night"
	end
end

function DayNightService:IsNight()
	local phase = self:GetPhase()
	return phase == "Night" or phase == "Dusk"
end

function DayNightService:GetTime()
	return self._currentTime
end

function DayNightService:GetTimeFormatted()
	local hours = math.floor(self._currentTime)
	local minutes = math.floor((self._currentTime - hours) * 60)
	local period = hours >= 12 and "PM" or "AM"
	local displayHours = hours % 12
	if displayHours == 0 then displayHours = 12 end
	return string.format("%d:%02d %s", displayHours, minutes, period)
end

function DayNightService:SetTime(newTime)
	local oldPhase = self:GetPhase()
	self._currentTime = newTime % 24
	Lighting.ClockTime = self._currentTime
	local newPhase = self:GetPhase()
	
	if oldPhase ~= newPhase then
		hook("PhaseChanged", newPhase, oldPhase)
	end
	
	self:_broadcast()
end

function DayNightService:Pause()
	self._paused = true
end

function DayNightService:Resume()
	self._paused = false
end

function DayNightService:GetEnemyMultiplier()
	local cfg = getConfig()
	if self:IsNight() then
		return cfg.EnemyNightMultiplier or 1.5
	end
	return 1.0
end

function DayNightService:GetResourceMultiplier()
	local cfg = getConfig()
	if self:IsNight() then
		return cfg.ResourceNightMultiplier or 0.7
	end
	return 1.0
end

function DayNightService:OnChange(callback)
	table.insert(self._callbacks, callback)
end

function DayNightService:_ensureRemote()
	if self._remote then return end
	-- OPTIMIZED: Try immediate lookup first
	self._remotesFolder = Util.GetDescendant(Config.Paths.Remotes)
	if not self._remotesFolder then
		self._remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 5)
	end
	if self._remotesFolder then
		self._remote = self._remotesFolder:FindFirstChild(Config.RemoteNames.TimeUpdate)
		if not self._remote then
			local remote = Instance.new("RemoteEvent")
			remote.Name = Config.RemoteNames.TimeUpdate or "TimeUpdate"
			remote.Parent = self._remotesFolder
			self._remote = remote
		end
	end
end

function DayNightService:_broadcast()
	self:_ensureRemote()
	if self._remote and self._remote.FireAllClients then
		self._remote:FireAllClients({
			Time = self._currentTime,
			Phase = self:GetPhase(),
			Formatted = self:GetTimeFormatted(),
		})
	end
end

function DayNightService:SendToPlayer(plr)
	self:_ensureRemote()
	if self._remote and self._remote.FireClient then
		self._remote:FireClient(plr, {
			Time = self._currentTime,
			Phase = self:GetPhase(),
			Formatted = self:GetTimeFormatted(),
		})
	end
end

function DayNightService:_updateLighting()
	local t = self._currentTime
	local phase = self:GetPhase()
	
	-- Set ClockTime for natural sun position
	Lighting.ClockTime = t
	
	-- Adjust ambient and other lighting properties based on phase
	if phase == "Day" then
		Lighting.Ambient = Color3.fromRGB(150, 150, 150)
		Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)
		Lighting.Brightness = 2
		Lighting.ExposureCompensation = 0
	elseif phase == "Dawn" then
		local progress = (t - PHASES.Dawn.start) / (PHASES.Dawn.finish - PHASES.Dawn.start)
		Lighting.Ambient = Color3.fromRGB(
			math.floor(80 + 70 * progress),
			math.floor(70 + 80 * progress),
			math.floor(100 + 50 * progress)
		)
		Lighting.OutdoorAmbient = Lighting.Ambient
		Lighting.Brightness = 1 + progress
		Lighting.ExposureCompensation = -0.5 + 0.5 * progress
	elseif phase == "Dusk" then
		local progress = (t - PHASES.Dusk.start) / (PHASES.Dusk.finish - PHASES.Dusk.start)
		Lighting.Ambient = Color3.fromRGB(
			math.floor(150 - 100 * progress),
			math.floor(150 - 120 * progress),
			math.floor(150 - 100 * progress)
		)
		Lighting.OutdoorAmbient = Lighting.Ambient
		Lighting.Brightness = 2 - 1.5 * progress
		Lighting.ExposureCompensation = -0.5 * progress
	else -- Night
		Lighting.Ambient = Color3.fromRGB(50, 50, 70)
		Lighting.OutdoorAmbient = Color3.fromRGB(30, 30, 50)
		Lighting.Brightness = 0.5
		Lighting.ExposureCompensation = -0.5
	end
end

function DayNightService:_tick(dt)
	if self._paused then return end
	
	local cfg = getConfig()
	local cycleDuration = cfg.CycleDurationSeconds or 600
	
	-- Hours per second: 24 hours / cycleDuration seconds
	local hoursPerSecond = 24 / cycleDuration
	local oldPhase = self:GetPhase()
	
	self._currentTime = (self._currentTime + hoursPerSecond * dt) % 24
	self:_updateLighting()
	
	local newPhase = self:GetPhase()
	if oldPhase ~= newPhase then
		hook("PhaseChanged", newPhase, oldPhase)
		self:_broadcast()
	end
end

function DayNightService:Init()
	self:_ensureRemote()
	
	-- Set initial time and lighting
	self._currentTime = getConfig().StartTime or 6
	self:_updateLighting()
	
	-- OPTIMIZED: Use task.spawn with controlled loop instead of Heartbeat
	-- This reduces per-frame overhead while maintaining smooth updates
	task.spawn(function()
		local lastTime = os.clock()
		local lastBroadcast = 0
		
		while true do
			local now = os.clock()
			local dt = now - lastTime
			lastTime = now
			
			self:_tick(dt)
			
			-- Broadcast time update every 1 second for smooth display
			lastBroadcast = lastBroadcast + dt
			if lastBroadcast >= 1 then
				lastBroadcast = 0
				self:_broadcast()
			end
			
			-- OPTIMIZED: Update less frequently (30 fps is plenty for day/night)
			task.wait(1/30)
		end
	end)
	
	-- Send time to new players
	Players.PlayerAdded:Connect(function(plr)
		task.defer(function()
			task.wait(0.5) -- Shorter wait
			self:SendToPlayer(plr)
		end)
	end)
	
	-- Expose to global
	_G.Ecoshift = _G.Ecoshift or {}
	_G.Ecoshift.DayNightService = self
	_G.Ecoshift.IsNight = function() return self:IsNight() end
	_G.Ecoshift.GetTimePhase = function() return self:GetPhase() end
	_G.Ecoshift.GetEnemyMultiplier = function() return self:GetEnemyMultiplier() end
	
	print("[DayNightService] Initialized - Starting at", self:GetTimeFormatted())
end

return DayNightService
