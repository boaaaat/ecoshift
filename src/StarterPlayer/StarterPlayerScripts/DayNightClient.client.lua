-- DayNightClient.client.lua
-- Handles smooth client-side lighting transitions and UI
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DayNightClient = {}
DayNightClient._currentPhase = "Day"
DayNightClient._currentTime = 6
DayNightClient._ui = nil

-- Lighting presets for smooth transitions
local LIGHTING_PRESETS = {
	Day = {
		Ambient = Color3.fromRGB(150, 150, 150),
		OutdoorAmbient = Color3.fromRGB(150, 150, 150),
		Brightness = 2,
		ExposureCompensation = 0,
		FogEnd = 100000,
		FogColor = Color3.fromRGB(192, 192, 192),
	},
	Dawn = {
		Ambient = Color3.fromRGB(120, 100, 130),
		OutdoorAmbient = Color3.fromRGB(120, 100, 130),
		Brightness = 1.5,
		ExposureCompensation = -0.25,
		FogEnd = 80000,
		FogColor = Color3.fromRGB(255, 180, 120),
	},
	Dusk = {
		Ambient = Color3.fromRGB(130, 90, 100),
		OutdoorAmbient = Color3.fromRGB(130, 90, 100),
		Brightness = 1.2,
		ExposureCompensation = -0.3,
		FogEnd = 70000,
		FogColor = Color3.fromRGB(255, 140, 100),
	},
	Night = {
		Ambient = Color3.fromRGB(50, 50, 70),
		OutdoorAmbient = Color3.fromRGB(30, 30, 50),
		Brightness = 0.5,
		ExposureCompensation = -0.5,
		FogEnd = 50000,
		FogColor = Color3.fromRGB(20, 20, 40),
	},
}

local function createTimeUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DayNightUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	
	local frame = Instance.new("Frame")
	frame.Name = "TimeDisplay"
	frame.Size = UDim2.new(0, 140, 0, 60)
	frame.Position = UDim2.new(0.5, -70, 0, 10)
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.BackgroundTransparency = 0.4
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = false
	frame.Parent = screenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 24, 0, 24)
	icon.Position = UDim2.new(0.5, 0, 0, 6)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.BackgroundTransparency = 1
	icon.Image = "rbxassetid://6031079158" -- Sun icon
	icon.ImageColor3 = Color3.fromRGB(255, 220, 100)
	icon.Parent = frame
	
	local timeLabel = Instance.new("TextLabel")
	timeLabel.Name = "TimeLabel"
	timeLabel.Size = UDim2.new(1, -10, 0, 18)
	timeLabel.Position = UDim2.new(0.5, 0, 0, 32)
	timeLabel.AnchorPoint = Vector2.new(0.5, 0)
	timeLabel.BackgroundTransparency = 1
	timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	timeLabel.TextSize = 14
	timeLabel.Font = Enum.Font.GothamBold
	timeLabel.Text = "6:00 AM"
	timeLabel.TextXAlignment = Enum.TextXAlignment.Center
	timeLabel.Parent = frame
	
	local phaseLabel = Instance.new("TextLabel")
	phaseLabel.Name = "PhaseLabel"
	phaseLabel.Size = UDim2.new(1, -10, 0, 12)
	phaseLabel.Position = UDim2.new(0.5, 0, 0, 46)
	phaseLabel.AnchorPoint = Vector2.new(0.5, 0)
	phaseLabel.BackgroundTransparency = 1
	phaseLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	phaseLabel.TextSize = 10
	phaseLabel.Font = Enum.Font.Gotham
	phaseLabel.Text = "Day"
	phaseLabel.TextXAlignment = Enum.TextXAlignment.Center
	phaseLabel.Parent = frame
	
	screenGui.Parent = playerGui
	
	return {
		Frame = frame,
		Icon = icon,
		TimeLabel = timeLabel,
		PhaseLabel = phaseLabel,
	}
end

local function updateIcon(ui, phase)
	if phase == "Night" then
		ui.Icon.Image = "rbxassetid://6031079983" -- Moon icon
		ui.Icon.ImageColor3 = Color3.fromRGB(200, 200, 255)
	elseif phase == "Dawn" then
		ui.Icon.Image = "rbxassetid://6031079158" -- Sun icon
		ui.Icon.ImageColor3 = Color3.fromRGB(255, 180, 100)
	elseif phase == "Dusk" then
		ui.Icon.Image = "rbxassetid://6031079158" -- Sun icon
		ui.Icon.ImageColor3 = Color3.fromRGB(255, 140, 80)
	else -- Day
		ui.Icon.Image = "rbxassetid://6031079158" -- Sun icon
		ui.Icon.ImageColor3 = Color3.fromRGB(255, 220, 100)
	end
end

local function tweenLighting(preset, duration)
	duration = duration or 2
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	
	local tween = TweenService:Create(Lighting, tweenInfo, preset)
	tween:Play()
end

function DayNightClient:OnTimeUpdate(data)
	if not data then return end
	
	self._currentTime = data.Time or self._currentTime
	local newPhase = data.Phase or "Day"
	local formatted = data.Formatted or "6:00 AM"
	
	-- Update UI
	if self._ui then
		self._ui.TimeLabel.Text = formatted
		self._ui.PhaseLabel.Text = newPhase
		updateIcon(self._ui, newPhase)
	end
	
	-- Sync clock time
	Lighting.ClockTime = self._currentTime
	
	-- Smooth lighting transition on phase change
	if newPhase ~= self._currentPhase then
		self._currentPhase = newPhase
		local preset = LIGHTING_PRESETS[newPhase]
		if preset then
			tweenLighting(preset, 3)
		end
		
		-- Phase change notification
		self:ShowPhaseNotification(newPhase)
	end
end

function DayNightClient:ShowPhaseNotification(phase)
	local messages = {
		Dawn = "☀️ Dawn breaks...",
		Day = "🌞 A new day begins!",
		Dusk = "🌅 Dusk approaches...",
		Night = "🌙 Night falls. Beware!",
	}
	
	local message = messages[phase]
	if not message then return end
	
	-- Create notification
	local notification = Instance.new("ScreenGui")
	notification.Name = "PhaseNotification"
	notification.ResetOnSpawn = false
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 300, 0, 50)
	label.Position = UDim2.new(0.5, -150, 0, 100)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	label.BackgroundTransparency = 0.3
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 24
	label.Font = Enum.Font.GothamBold
	label.Text = message
	label.TextTransparency = 1
	label.Parent = notification
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label
	
	notification.Parent = playerGui
	
	-- Fade in
	local fadeIn = TweenService:Create(label, TweenInfo.new(0.5), {TextTransparency = 0, BackgroundTransparency = 0.3})
	fadeIn:Play()
	
	-- Fade out after delay
	task.delay(3, function()
		local fadeOut = TweenService:Create(label, TweenInfo.new(0.5), {TextTransparency = 1, BackgroundTransparency = 1})
		fadeOut:Play()
		fadeOut.Completed:Wait()
		notification:Destroy()
	end)
end

function DayNightClient:Init()
	-- Create UI
	self._ui = createTimeUI()
	
	-- Connect to remote
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	if remotesFolder then
		local remote = remotesFolder:WaitForChild("TimeUpdate", 10)
		if remote then
			remote.OnClientEvent:Connect(function(data)
				self:OnTimeUpdate(data)
			end)
		end
	end
	
	-- Apply initial lighting
	local preset = LIGHTING_PRESETS[self._currentPhase]
	if preset then
		for prop, value in pairs(preset) do
			Lighting[prop] = value
		end
	end
	
	print("[DayNightClient] Initialized")
end

-- Initialize
DayNightClient:Init()

return DayNightClient
