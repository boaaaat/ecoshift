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
local pages=Instance.new("Frame")
pages.Name="SwipePages";pages.Size=UDim2.fromScale(1,1);pages.BackgroundTransparency=1;pages.ClipsDescendants=true;pages.Parent=panel
local healthPage=Instance.new("Frame")
healthPage.Name="HealthPage";healthPage.Size=UDim2.fromScale(1,1);healthPage.BackgroundTransparency=1;healthPage.Parent=pages
for index,bar in ipairs(meters) do
	bar.Icon=Theme.Icon(healthPage,({"Health","Energy","Food","Exposure","Armor"})[index],16)
	bar.Icon.Name="VitalIcon"..index
end
local pager=Instance.new("TextButton")
pager.Name="SwipeHint";pager.BackgroundTransparency=1;pager.Text="•  ○  ›";pager.TextColor3=C.Amber;pager.TextSize=13
pager.Size=UDim2.new(1,0,0,16);pager.Position=UDim2.new(0,0,1,-16);pager.ZIndex=10;pager.Parent=panel
pager.Activated:Connect(function()
	if os.clock() - (gui.Parent:GetAttribute("MobileHUDSwipeAt") or -1) < .3 then return end
	gui.Parent:SetAttribute("MobileBiomePage",not gui.Parent:GetAttribute("MobileBiomePage"))
end)
local pageTween
local function updatePage()
	if pageTween then pageTween:Cancel() end
	local biome=gui.Parent:GetAttribute("MobileBiomePage")==true
	pageTween=Theme.Tween(healthPage,{Position=UDim2.fromScale(biome and -1 or 0,0)},.24)
	pager.Text=biome and "‹  ○  •" or "•  ○  ›"
end
gui.Parent:GetAttributeChangedSignal("MobileBiomePage"):Connect(updatePage)
local touch,startPosition
local inputService=game:GetService("UserInputService")
inputService.InputBegan:Connect(function(input)
	if input.UserInputType~=Enum.UserInputType.Touch or not Theme.IsMobile() or not panel.Visible or gui.Parent:GetAttribute("MenuCursorOpen") then return end
	local p=input.Position;local a,s=panel.AbsolutePosition,panel.AbsoluteSize
	if p.X>=a.X and p.X<=a.X+s.X and p.Y>=a.Y and p.Y<=a.Y+s.Y then touch=input;startPosition=p end
end)
inputService.InputChanged:Connect(function(input)
	if input == touch and math.abs(input.Position.X - startPosition.X) > 28 then
		gui.Parent:SetAttribute("MobileHUDSwipeAt", os.clock())
	end
end)
inputService.InputEnded:Connect(function(input)
	if input~=touch then return end
	touch=nil;local delta=input.Position-startPosition
	if input.UserInputState~=Enum.UserInputState.Cancel and math.abs(delta.X)>28 and math.abs(delta.X)>math.abs(delta.Y)*1.25 then
		gui.Parent:SetAttribute("MobileBiomePage",delta.X<0)
		gui.Parent:SetAttribute("MobileHUDSwipeAt", os.clock())
	end
end)
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
	pages.Visible=mobile;pager.Visible=mobile
	panel.Active=mobile
	panel.BackgroundTransparency=mobile and .4 or .04
	if mobile then
		scale.Scale=1;panel.Size=UDim2.fromOffset(184,90)
		panel.Position=UDim2.fromOffset(8,gui.Parent:GetAttribute("MobileTopbarFallback") and 54 or 6)
	end
	for i,bar in ipairs(meters) do
		bar.Label.Visible=not mobile;bar.Icon.Visible=mobile
		bar.Track.Parent=mobile and healthPage or panel;bar.Value.Parent=mobile and healthPage or panel
		if mobile then
			local x=i==1 and 8 or (i%2==0 and 8 or 96)
			local y=i==1 and 5 or (i<=3 and 29 or 52)
			bar.Icon.Position=UDim2.fromOffset(x+8,y+8)
			bar.Value.Position=UDim2.fromOffset(i==1 and 138 or x+39,y-1)
			bar.Value.Size=UDim2.fromOffset(i==1 and 36 or 40,18);bar.Value.TextSize=12
			bar.Track.Position=UDim2.fromOffset(x+24,y+7);bar.Track.Size=UDim2.fromOffset(i==1 and 98 or 13,4)
		end
	end
end
Theme.BindResponsive(panel, layout)
gui.Parent:GetAttributeChangedSignal("MobileTopbarFallback"):Connect(function() layout(nil,gui.AbsoluteSize) end)
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
