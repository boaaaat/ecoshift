-- One compact field instrument for health, energy and environmental protection.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.UI.UITheme)
local C = Theme.Colors
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "PlayerVitalsUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame")
panel.Name = "VitalsContainer"
panel.Size = UDim2.fromOffset(232, 154)
panel.AnchorPoint = Vector2.new(0, 1)
panel.Position = UDim2.new(0, 18, 1, -18)
panel.Parent = gui
Theme.Panel(panel, true)
Theme.Fit(panel, 900, 610)
Theme.Label(panel, "SURVIVAL / VITALS", UDim2.fromOffset(195, 16), UDim2.fromOffset(14, 10), 10, C.Amber, true)
local function meter(name, y, color)
	Theme.Label(panel, name, UDim2.fromOffset(62, 16), UDim2.fromOffset(14, y), 9, C.Sage, true)
	local value = Theme.Label(panel, "--", UDim2.fromOffset(49, 16), UDim2.fromOffset(167, y), 10, C.Paper, true)
	value.TextXAlignment = Enum.TextXAlignment.Right
	local track = Instance.new("Frame")
	track.Name = name .. "Track"
	track.Size = UDim2.fromOffset(84, 5)
	track.Position = UDim2.fromOffset(79, y + 6)
	track.BorderSizePixel = 0
	track.BackgroundColor3 = C.Moss
	track.Parent = panel
	Theme.Corner(track, 3)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = color
	fill.Parent = track
	Theme.Corner(fill, 3)
	return { Fill = fill, Value = value }
end
local health = meter("HEALTH", 34, C.Sage)
local stamina = meter("ENERGY", 56, C.Cold)
local hunger = meter("FOOD", 78, C.Amber)
local temperature = meter("EXPOSURE", 100, C.Sage)
local armor = meter("ARMOR", 122, C.Paper)
local function updateMeter(bar, percent, value, color)
	bar.Value.Text = value
	local props = { Size = UDim2.fromScale(math.clamp(percent, 0, 1), 1) }
	if color then props.BackgroundColor3 = color end
	Theme.Tween(bar.Fill, props, 0.22)
end
local function updateVitals()
	local energy = player:GetAttribute("Stat_Stamina") or 100
	local food = player:GetAttribute("Stat_Hunger") or 100
	local temp = player:GetAttribute("Stat_Temperature") or 0
	local protection = player:GetAttribute("Stat_Armor") or 0
	updateMeter(stamina, energy / math.max(1, player:GetAttribute("Stat_MaxStamina") or 100), tostring(math.floor(energy)))
	updateMeter(hunger, food / math.max(1, player:GetAttribute("Stat_MaxHunger") or 100), tostring(math.floor(food)))
	local tempColor = temp < -10 and C.Cold or (temp > 10 and C.Amber or C.Sage)
	updateMeter(temperature, math.abs(temp) / 100, math.abs(temp) < 1 and "OK" or string.format("%+d", math.floor(temp)), tempColor)
	temperature.Value.TextColor3 = tempColor
	updateMeter(armor, protection / 100, tostring(math.floor(protection)))
end
for _, attribute in ipairs({ "Stat_Stamina", "Stat_MaxStamina", "Stat_Hunger", "Stat_MaxHunger", "Stat_Temperature", "Stat_Armor" }) do
	player:GetAttributeChangedSignal(attribute):Connect(updateVitals)
end
local healthConnection, maxHealthConnection
local function bindCharacter(character)
	if healthConnection then healthConnection:Disconnect() end
	if maxHealthConnection then maxHealthConnection:Disconnect() end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	local function updateHealth()
		local hp = player:GetAttribute("IsDead") and 0 or math.max(0, humanoid.Health)
		local pct = hp / math.max(1, humanoid.MaxHealth)
		updateMeter(health, pct, tostring(math.ceil(hp)), pct <= 0.25 and Color3.fromRGB(227, 119, 85) or C.Sage)
	end
	healthConnection = humanoid.HealthChanged:Connect(updateHealth)
	maxHealthConnection = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateHealth)
	updateHealth()
end
player.CharacterAdded:Connect(bindCharacter)
player:GetAttributeChangedSignal("IsDead"):Connect(function()
	if player:GetAttribute("IsDead") then
		updateMeter(health, 0, "DOWN", C.Danger)
	end
end)
if player.Character then task.spawn(bindCharacter, player.Character) end
updateVitals()
