-- PlayerVitalsUI.client.lua
-- Displays stamina, hunger, temperature, and armor bars
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "PlayerVitalsUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "VitalsContainer"
container.Size = UDim2.new(0, 250, 0, 74)
container.Position = UDim2.new(0, 20, 1, -160)
container.BackgroundTransparency = 1
container.Parent = gui

local function makeBar(name, y, color)
	local barBg = Instance.new("Frame")
	barBg.Name = name .. "Bg"
	barBg.Size = UDim2.new(0, 200, 0, 14)
	barBg.Position = UDim2.new(0, 50, 0, y)
	barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	barBg.BorderSizePixel = 0
	barBg.Parent = container

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 6)
	bgCorner.Parent = barBg

	local fill = Instance.new("Frame")
	fill.Name = name .. "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = barBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	local label = Instance.new("TextLabel")
	label.Name = name .. "Label"
	label.Size = UDim2.new(0, 44, 0, 14)
	label.Position = UDim2.new(0, 0, 0, y)
	label.BackgroundTransparency = 1
	label.Text = string.upper(name)
	label.TextColor3 = Color3.fromRGB(200, 200, 210)
	label.TextSize = 10
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container

	return barBg, fill, label
end

local staminaBg, staminaFill, staminaLabel = makeBar("Stamina", 0, Color3.fromRGB(120, 200, 255))
local hungerBg, hungerFill, hungerLabel = makeBar("Hunger", 20, Color3.fromRGB(255, 200, 100))
local tempBg, tempFill, tempLabel = makeBar("Temp", 40, Color3.fromRGB(120, 180, 255))
local armorBg, armorFill, armorLabel = makeBar("Armor", 60, Color3.fromRGB(200, 200, 220))

tempBg.Visible = false
tempLabel.Visible = false
armorBg.Visible = false
armorLabel.Visible = false

local function tweenBar(fill, percent, color)
	percent = math.clamp(percent, 0, 1)
	local props = { Size = UDim2.new(percent, 0, 1, 0) }
	if color then props.BackgroundColor3 = color end
	TweenService:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function tempColor(temp)
	if temp >= 0 then
		return Color3.fromRGB(255, 170, 80)
	end
	return Color3.fromRGB(120, 180, 255)
end

local function updateVitals()
	local stamina = player:GetAttribute("Stat_Stamina") or 0
	local maxStamina = player:GetAttribute("Stat_MaxStamina") or 100
	local hunger = player:GetAttribute("Stat_Hunger") or 0
	local maxHunger = player:GetAttribute("Stat_MaxHunger") or 100
	local temp = player:GetAttribute("Stat_Temperature") or 0
	local armor = player:GetAttribute("Stat_Armor") or 0

	tweenBar(staminaFill, maxStamina > 0 and stamina / maxStamina or 0)
	tweenBar(hungerFill, maxHunger > 0 and hunger / maxHunger or 0)

	local tempVisible = math.abs(temp) >= 1
	tempBg.Visible = tempVisible
	tempLabel.Visible = tempVisible
	if tempVisible then
		local pct = (math.clamp(temp, -100, 100) + 100) / 200
		tweenBar(tempFill, pct, tempColor(temp))
	end

	local armorVisible = (tonumber(armor) or 0) > 0
	armorBg.Visible = armorVisible
	armorLabel.Visible = armorVisible
	if armorVisible then
		tweenBar(armorFill, math.clamp((armor or 0) / 100, 0, 1))
	end
end

local watched = {
	"Stat_Stamina",
	"Stat_MaxStamina",
	"Stat_Hunger",
	"Stat_MaxHunger",
	"Stat_Temperature",
	"Stat_Armor",
}
for _, attr in ipairs(watched) do
	player:GetAttributeChangedSignal(attr):Connect(updateVitals)
end

updateVitals()

print("[PlayerVitalsUI] Initialized")
