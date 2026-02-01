-- PlayerHealthUI.client.lua
-- Shows player health bar and handles damage feedback
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create the health bar UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlayerHealthUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Main container (bottom left)
local container = Instance.new("Frame")
container.Name = "HealthContainer"
container.Size = UDim2.new(0, 250, 0, 60)
container.Position = UDim2.new(0, 20, 1, -80)
container.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
container.BackgroundTransparency = 0.3
container.BorderSizePixel = 0
container.Parent = screenGui

local containerCorner = Instance.new("UICorner")
containerCorner.CornerRadius = UDim.new(0, 10)
containerCorner.Parent = container

-- Health icon
local healthIcon = Instance.new("ImageLabel")
healthIcon.Name = "HealthIcon"
healthIcon.Size = UDim2.new(0, 40, 0, 40)
healthIcon.Position = UDim2.new(0, 10, 0.5, -20)
healthIcon.BackgroundTransparency = 1
healthIcon.Image = "rbxassetid://7072718362" -- Heart icon
healthIcon.ImageColor3 = Color3.fromRGB(255, 80, 80)
healthIcon.Parent = container

-- Health bar background
local healthBarBg = Instance.new("Frame")
healthBarBg.Name = "HealthBarBg"
healthBarBg.Size = UDim2.new(0, 180, 0, 20)
healthBarBg.Position = UDim2.new(0, 58, 0, 10)
healthBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
healthBarBg.BorderSizePixel = 0
healthBarBg.Parent = container

local healthBarBgCorner = Instance.new("UICorner")
healthBarBgCorner.CornerRadius = UDim.new(0, 6)
healthBarBgCorner.Parent = healthBarBg

-- Health bar fill
local healthBarFill = Instance.new("Frame")
healthBarFill.Name = "HealthBarFill"
healthBarFill.Size = UDim2.new(1, 0, 1, 0)
healthBarFill.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
healthBarFill.BorderSizePixel = 0
healthBarFill.Parent = healthBarBg

local healthBarFillCorner = Instance.new("UICorner")
healthBarFillCorner.CornerRadius = UDim.new(0, 6)
healthBarFillCorner.Parent = healthBarFill

-- Damage flash overlay (red when taking damage)
local damageFlash = Instance.new("Frame")
damageFlash.Name = "DamageFlash"
damageFlash.Size = UDim2.new(1, 0, 1, 0)
damageFlash.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
damageFlash.BackgroundTransparency = 1
damageFlash.BorderSizePixel = 0
damageFlash.ZIndex = 2
damageFlash.Parent = healthBarBg

local damageFlashCorner = Instance.new("UICorner")
damageFlashCorner.CornerRadius = UDim.new(0, 6)
damageFlashCorner.Parent = damageFlash

-- Health text
local healthText = Instance.new("TextLabel")
healthText.Name = "HealthText"
healthText.Size = UDim2.new(0, 180, 0, 20)
healthText.Position = UDim2.new(0, 58, 0, 32)
healthText.BackgroundTransparency = 1
healthText.Text = "100 / 100"
healthText.TextColor3 = Color3.fromRGB(220, 220, 220)
healthText.TextSize = 14
healthText.Font = Enum.Font.GothamMedium
healthText.TextXAlignment = Enum.TextXAlignment.Left
healthText.Parent = container

-- Low health warning effect
local lowHealthWarning = Instance.new("Frame")
lowHealthWarning.Name = "LowHealthWarning"
lowHealthWarning.Size = UDim2.new(1, 0, 1, 0)
lowHealthWarning.Position = UDim2.new(0, 0, 0, 0)
lowHealthWarning.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
lowHealthWarning.BackgroundTransparency = 1
lowHealthWarning.BorderSizePixel = 0
lowHealthWarning.ZIndex = 100
lowHealthWarning.Parent = screenGui

-- Variables
local currentHumanoid = nil
local lastHealth = 100
local lowHealthPulse = nil

-- Color gradient based on health percentage
local function getHealthColor(percent)
	if percent > 0.6 then
		return Color3.fromRGB(80, 200, 120) -- Green
	elseif percent > 0.3 then
		return Color3.fromRGB(255, 200, 80) -- Yellow
	else
		return Color3.fromRGB(255, 80, 80) -- Red
	end
end

-- Flash effect when taking damage
local function flashDamage()
	damageFlash.BackgroundTransparency = 0.3
	TweenService:Create(damageFlash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1
	}):Play()
	
	-- Screen vignette flash
	lowHealthWarning.BackgroundTransparency = 0.85
	TweenService:Create(lowHealthWarning, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1
	}):Play()
end

-- Start low health pulsing effect
local function startLowHealthPulse()
	if lowHealthPulse then return end
	lowHealthPulse = task.spawn(function()
		while lowHealthPulse do
			lowHealthWarning.BackgroundTransparency = 0.9
			TweenService:Create(lowHealthWarning, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				BackgroundTransparency = 0.95
			}):Play()
			task.wait(0.5)
			TweenService:Create(lowHealthWarning, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				BackgroundTransparency = 0.9
			}):Play()
			task.wait(0.5)
		end
	end)
end

-- Stop low health pulsing
local function stopLowHealthPulse()
	if lowHealthPulse then
		task.cancel(lowHealthPulse)
		lowHealthPulse = nil
		lowHealthWarning.BackgroundTransparency = 1
	end
end

-- Update health bar
local function updateHealthBar()
	if not currentHumanoid then return end
	
	local health = currentHumanoid.Health
	local maxHealth = currentHumanoid.MaxHealth
	local percent = maxHealth > 0 and (health / maxHealth) or 0
	percent = math.clamp(percent, 0, 1)
	
	-- Animate health bar
	TweenService:Create(healthBarFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(percent, 0, 1, 0),
		BackgroundColor3 = getHealthColor(percent)
	}):Play()
	
	-- Update text
	healthText.Text = string.format("%d / %d", math.floor(health), math.floor(maxHealth))
	
	-- Damage flash if health decreased
	if health < lastHealth then
		flashDamage()
	end
	
	-- Low health warning
	if percent <= 0.25 and health > 0 then
		startLowHealthPulse()
	else
		stopLowHealthPulse()
	end
	
	lastHealth = health
end

-- Connect to humanoid
local function connectHumanoid(humanoid)
	currentHumanoid = humanoid
	lastHealth = humanoid.Health
	
	humanoid.HealthChanged:Connect(function()
		updateHealthBar()
	end)
	
	updateHealthBar()
end

-- Setup for character
local function onCharacter(char)
	stopLowHealthPulse()
	
	local humanoid = char:WaitForChild("Humanoid", 10)
	if humanoid then
		connectHumanoid(humanoid)
	end
end

-- Initialize
if player.Character then
	onCharacter(player.Character)
end
player.CharacterAdded:Connect(onCharacter)

print("[PlayerHealthUI] Initialized")
