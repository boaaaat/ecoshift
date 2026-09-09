if require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end
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
local scale = Instance.new("UIScale")
scale.Parent = panel
local heading = Theme.Label(panel, "SURVIVAL / VITALS", UDim2.fromOffset(195, 16), UDim2.fromOffset(14, 10), 10, C.Amber, true)
local meters = {}
local function meter(name, y, color)
	local label = Theme.Label(panel, name, UDim2.fromOffset(62, 16), UDim2.fromOffset(14, y), 9, C.Sage, true)
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
	local result = { Fill = fill, Value = value, Label = label, Track = track, Y = y }
	table.insert(meters, result)
	return result
end
local health = meter("HEALTH", 34, C.Sage)
local stamina = meter("ENERGY", 56, C.Cold)
local hunger = meter("FOOD", 78, C.Amber)
local temperature = meter("EXPOSURE", 100, C.Sage)
local armor = meter("ARMOR", 122, C.Paper)
local function updatePlacementVisibility()
	panel.Visible = not (Theme.IsMobile() and gui.Parent:GetAttribute("BuildPlacementActive"))
end
gui.Parent:GetAttributeChangedSignal("BuildPlacementActive"):Connect(updatePlacementVisibility)
local function layout(_, available)
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(900, 610)
	local mobile = Theme.IsMobile()
	local compactPortrait = mobile and available.X < available.Y and available.Y < 680
	updatePlacementVisibility()
	local mobileWidth = math.min(190, (available.X - 24) * .55)
	if available.X > available.Y and available.X < 700 then mobileWidth = math.min(mobileWidth, 160) end
	scale.Scale = mobile and mobileWidth / 190 or math.min(math.clamp(math.min(viewport.X / 1440, viewport.Y / 900), 1, 2.5), (viewport.X - 40) / 900, (viewport.Y - 90) / 610)
	panel.AnchorPoint = Vector2.new(0, mobile and 0 or 1)
	panel.Position = mobile and UDim2.fromOffset(8, available.X < available.Y and 46 or 6) or UDim2.new(0, 18 * scale.Scale, 1, -18 * scale.Scale)
	panel.Size = mobile and UDim2.fromOffset(190, compactPortrait and 132 or 140) or UDim2.fromOffset(232, 154)
	heading.Visible = not mobile
	for index, bar in ipairs(meters) do
		local y = mobile and (10 + (index - 1) * (compactPortrait and 23 or 25)) or bar.Y
		bar.Label.Position = UDim2.fromOffset(mobile and 10 or 14, y)
		bar.Label.Size = UDim2.fromOffset(mobile and 78 or 62, 18)
		bar.Label.TextSize = mobile and 12 or 9
		bar.Value.Position = UDim2.fromOffset(mobile and 136 or 167, y)
		bar.Value.Size = UDim2.fromOffset(mobile and 44 or 49, 18)
		bar.Value.TextSize = mobile and 14 or 10
		bar.Track.Position = UDim2.fromOffset(mobile and 90 or 79, y + 7)
		bar.Track.Size = UDim2.fromOffset(mobile and 42 or 84, mobile and 6 or 5)
	end
end
Theme.BindResponsive(panel, layout)
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
