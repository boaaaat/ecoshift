if require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end
-- Expedition instruments and local field-kit navigation.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(ReplicatedStorage.Shared.UI.UITheme)
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Settings = require(ReplicatedStorage.Shared.ClientSettings)
local C = Theme.Colors
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "EcoshiftHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.Name = "ExpeditionCard"
card.Size = UDim2.fromOffset(272, 188)
card.Position = UDim2.fromOffset(18, 14)
card.Parent = gui
Theme.Panel(card, true)
local cardScale = Instance.new("UIScale")
cardScale.Parent = card
Theme.Label(card, "ECO / SHIFT", UDim2.fromOffset(165, 26), UDim2.fromOffset(16, 12), 21, C.Paper, true)
Theme.Label(card, "EXPEDITION RECORD", UDim2.fromOffset(230, 14), UDim2.fromOffset(16, 40), 9, C.Sage, true)
local runLabel = Theme.Label(card, "00:00", UDim2.fromOffset(72, 18), UDim2.fromOffset(182, 16), 12, C.Amber, true)
runLabel.TextXAlignment = Enum.TextXAlignment.Right
local biomeLabel = Theme.Label(card, "Surveying world...", UDim2.fromOffset(242, 29), UDim2.fromOffset(16, 66), 20, C.Paper, true)
local weatherLabel = Theme.Label(card, "Awaiting conditions", UDim2.fromOffset(240, 17), UDim2.fromOffset(16, 96), 11, C.Sage)
-- Whole text rows are tap targets; keep labels so state updates stay simple.
for _, entry in ipairs({ { biomeLabel, "Biome", 66, 29 }, { weatherLabel, "Conditions", 96, 25 } }) do
	entry[1].Size = UDim2.fromOffset(220, entry[4])
	local hit = Instance.new("TextButton")
	hit.Name, hit.Text = "Inspect" .. entry[2], ""
	hit.Size, hit.Position = UDim2.fromOffset(244, entry[4]), UDim2.fromOffset(14, entry[3])
	hit.BackgroundTransparency, hit.Parent = 1, card
	local arrow = Theme.Label(hit, ">", UDim2.fromOffset(16, 18), UDim2.new(1, -16, .5, -9), 14, C.Amber, true)
	arrow.TextXAlignment = Enum.TextXAlignment.Center
	hit.Activated:Connect(function()
		if os.clock() - (gui.Parent:GetAttribute("MobileHUDSwipeAt") or -1) < .3 then return end
		local attribute = "FieldGuide" .. entry[2]
		player:SetAttribute(attribute, (player:GetAttribute(attribute) or 0) + 1)
	end)
end
local shiftLabel = Theme.Label(card, "SHIFT TIME UNKNOWN", UDim2.fromOffset(152, 18), UDim2.fromOffset(16, 127), 10, C.Sage, true)
local countdown = Theme.Label(card, "--:--", UDim2.fromOffset(90, 22), UDim2.fromOffset(166, 124), 19, C.Amber, true)
countdown.TextXAlignment = Enum.TextXAlignment.Right
local track = Instance.new("Frame")
track.Name = "ShiftTrack"
track.Size = UDim2.new(1, -32, 0, 5)
track.Position = UDim2.fromOffset(16, 155)
track.BackgroundColor3 = C.Moss
track.BorderSizePixel = 0
track.Parent = card
Theme.Corner(track, 3)
local fill = Instance.new("Frame")
fill.Name = "ShiftFill"
fill.Size = UDim2.fromScale(1, 1)
fill.BackgroundColor3 = C.Amber
fill.BorderSizePixel = 0
fill.Parent = track
Theme.Corner(fill, 3)
local cycleLabel = Theme.Label(card, "SHIFT 00  /  THREAT 1", UDim2.fromOffset(238, 14), UDim2.fromOffset(16, 166), 9, C.Sage, true)

local notes = Instance.new("Frame")
notes.Name = "FieldNotes"
notes.Size = UDim2.fromOffset(272, 100)
notes.Position = UDim2.fromOffset(0, 200)
notes.Parent = card
Theme.Panel(notes, true)
Theme.Label(notes, "FIELD NOTES", UDim2.fromOffset(170, 16), UDim2.fromOffset(16, 12), 10, C.Amber, true)
local objectiveLabel = Theme.Label(notes, "Gather supplies. Keep your team alive.", UDim2.fromOffset(240, 34), UDim2.fromOffset(16, 33), 11, C.Paper)
objectiveLabel.TextWrapped = true
objectiveLabel.TextYAlignment = Enum.TextYAlignment.Top
objectiveLabel.TextTruncate = Enum.TextTruncate.None
local eventLabel = Theme.Label(notes, "No active anomalies", UDim2.fromOffset(240, 17), UDim2.fromOffset(16, 73), 10, C.Sage)

local roleButton = Instance.new("TextButton")
roleButton.Name = "RoleButton"
roleButton.Size = UDim2.fromOffset(272, 28)
roleButton.Position = UDim2.fromOffset(0, 308)
roleButton.Text = "FIELD ROLE  /  Select role"
roleButton.Font = Enum.Font.GothamBold
roleButton.TextSize = 10
roleButton.Parent = card
Theme.Button(roleButton, true)

local kit = Instance.new("Frame")
kit.Name = "FieldKitNavigation"
kit.Size = UDim2.fromOffset(376, 32)
kit.AnchorPoint = Vector2.new(0.5, 1)
kit.Position = UDim2.new(0.5, 0, 1, -94)
kit.BackgroundTransparency = 1
kit.Parent = gui
local kitScale = Instance.new("UIScale")
kitScale.Parent = kit
local navigationButtons = {}
for index, entry in ipairs({ { "Pack", "E" }, { "Craft", "C" }, { "Build", "B" }, { "Map", "M" }, { "Survey", "V" } }) do
	local button = Instance.new("TextButton")
	button.Name = entry[1]
	button.Size = UDim2.fromOffset(70, 28)
	button.Position = UDim2.fromOffset((index - 1) * 76, 0)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 10
	local function updateHint() button.Text = Theme.IsMobile() and "" or Settings.Key(entry[1]).Name .. "  " .. string.upper(entry[1]) end
	Settings.Changed:Connect(updateHint)
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(updateHint)
	updateHint()
	button.Parent = kit
	Theme.Button(button, true)
	Theme.TouchIcon(button,entry[1],24)
	updateHint()
	table.insert(navigationButtons, button)
	button.Activated:Connect(function()
		local attribute = "FieldKit" .. entry[1]
		player:SetAttribute(attribute, (player:GetAttribute(attribute) or 0) + 1)
	end)
end
local vitalsPages=player.PlayerGui:WaitForChild("PlayerVitalsUI"):WaitForChild("VitalsContainer"):WaitForChild("SwipePages")
local biomeTween
local function slideBiome()
	if not Theme.IsMobile() then return end
	if biomeTween then biomeTween:Cancel() end
	biomeTween=Theme.Tween(card,{Position=UDim2.fromScale(gui.Parent:GetAttribute("MobileBiomePage") and 0 or 1,0)},.24)
end
gui.Parent:GetAttributeChangedSignal("MobileBiomePage"):Connect(slideBiome)

local mobileDetails = false
local detailsButton = Instance.new("TextButton")
detailsButton.Name = "MobileFieldDetails"
detailsButton.Size = UDim2.fromOffset(84, 36)
detailsButton.Position = UDim2.new(1, -84, 1, 6)
detailsButton.Font = Enum.Font.GothamBold
detailsButton.TextSize = 12
detailsButton.Text = "DETAILS"
detailsButton.Parent = card
Theme.Button(detailsButton, true)
local cardDefaults = {}
for _, child in ipairs(card:GetChildren()) do
	if child:IsA("GuiObject") then
		cardDefaults[child] = {Position = child.Position, Size = child.Size, Visible = child.Visible,
			TextSize = child:IsA("TextLabel") and child.TextSize or nil}
	end
end
local function updateHUDPreferences()
	local mobile = Theme.IsMobile()
	local placing = mobile and gui.Parent:GetAttribute("BuildPlacementActive") == true
	card.Visible = not placing
	notes.Visible = Settings.Get("ShowFieldNotes") and not mobile
	roleButton.Visible = not mobile
	roleButton.Position = UDim2.fromOffset(0, mobile and (notes.Visible and 222 or 112) or (notes.Visible and 308 or 200))
	kit.Visible = Settings.Get("ShowNavigation") and not placing and not (mobile and gui.Parent:GetAttribute("MenuCursorOpen"))
end
detailsButton.Activated:Connect(function()
	mobileDetails = not mobileDetails
	detailsButton.Text = mobileDetails and "LESS" or "DETAILS"
	updateHUDPreferences()
end)
local function layout(_, available)
	local mobile = Theme.IsMobile()
	local compactPortrait = mobile and available.X < available.Y and available.Y < 680
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(900, 610)
	local desktopScale = math.min(math.clamp(math.min(viewport.X / 1440, viewport.Y / 900), 1, 2.5), (viewport.X - 40) / 730, (viewport.Y - 90) / 610)
	cardScale.Scale = mobile and (available.X > available.Y and math.min(1, (available.X - 348) / 272) or 1) or desktopScale
	kitScale.Scale = mobile and 1 or desktopScale
	card.AnchorPoint = Vector2.new(mobile and .5 or 0, 0)
	card.Position = mobile and UDim2.new(.5, 0, 0, available.X < available.Y and (compactPortrait and 186 or 224) or 44) or UDim2.fromOffset(18 * desktopScale, 14 * desktopScale)
	card.Size = UDim2.fromOffset(272, mobile and 106 or 188)
	for child, defaults in pairs(cardDefaults) do
		child.Position, child.Size, child.Visible = defaults.Position, defaults.Size, defaults.Visible
		if defaults.TextSize then child.TextSize = defaults.TextSize end
	end
	detailsButton.Visible = mobile
	if mobile then
		for _, child in ipairs(card:GetChildren()) do
			if child:IsA("TextLabel") then child.Visible = false end
		end
		for _, entry in ipairs({{biomeLabel, 8, 20}, {weatherLabel, 34, 13}, {shiftLabel, 61, 11}, {countdown, 58, 18}, {cycleLabel, 84, 11}}) do
			entry[1].Visible = true
			entry[1].Position = UDim2.fromOffset(entry[1].Position.X.Offset, entry[2])
			entry[1].TextSize = entry[3]
		end
		card.InspectBiome.Position = UDim2.fromOffset(14, 6)
		card.InspectConditions.Position = UDim2.fromOffset(14, 33)
		cycleLabel.Size = UDim2.fromOffset(174, 14)
		detailsButton.Size = UDim2.fromOffset(70, 32)
		detailsButton.Position = UDim2.fromOffset(198, 74)
		track.Visible = false
		notes.Position = UDim2.fromOffset(0, 112)
		roleButton.Size = UDim2.fromOffset(272, 44)
	end
	card.Parent=mobile and vitalsPages or gui
	card.BackgroundTransparency=mobile and 1 or .04
	local stroke=card:FindFirstChildOfClass('UIStroke');if stroke then stroke.Enabled=not mobile end
	for _,hit in ipairs({card.InspectBiome,card.InspectConditions}) do
		for _,child in ipairs(hit:GetChildren()) do if child:IsA('TextLabel') then child.Visible=not mobile end end
	end
	if mobile then
		cardScale.Scale=1;card.AnchorPoint=Vector2.zero;card.Size=UDim2.fromOffset(184,90)
		card.Position=UDim2.fromScale(gui.Parent:GetAttribute('MobileBiomePage') and 0 or 1,0)
		biomeLabel.Position=UDim2.fromOffset(8,4);biomeLabel.Size=UDim2.fromOffset(170,22);biomeLabel.TextSize=16
		weatherLabel.Position=UDim2.fromOffset(8,27);weatherLabel.Size=UDim2.fromOffset(170,17);weatherLabel.TextSize=11
		shiftLabel.Position=UDim2.fromOffset(8,46);shiftLabel.Size=UDim2.fromOffset(126,15);shiftLabel.TextSize=9
		countdown.Position=UDim2.fromOffset(132,43);countdown.Size=UDim2.fromOffset(46,20);countdown.TextSize=12
		cycleLabel.Position=UDim2.fromOffset(8,62);cycleLabel.Size=UDim2.fromOffset(170,14);cycleLabel.TextSize=9
		card.InspectBiome.Position=UDim2.fromOffset(0,0);card.InspectBiome.Size=UDim2.fromOffset(184,26)
		card.InspectConditions.Position=UDim2.fromOffset(0,26);card.InspectConditions.Size=UDim2.fromOffset(184,20)
		for _,hit in ipairs({card.InspectBiome,card.InspectConditions}) do for _,child in ipairs(hit:GetChildren()) do if child:IsA('TextLabel') then child.Visible=false end end end
		detailsButton.Visible=false
	end
	local count=0;local portrait=mobile and available.X<available.Y
	for _,button in ipairs(navigationButtons) do
		button.Visible=not(mobile and button.Name=='Map')
		button.Glyph.Visible=mobile;button.BackgroundTransparency=mobile and .48 or 0
		if button.Visible then
			button.Size=UDim2.fromOffset(mobile and 44 or 70,mobile and 44 or 28)
			button.Position=portrait and UDim2.fromOffset((count%2)*48,math.floor(count/2)*48) or UDim2.fromOffset(count*(mobile and 48 or 76),0)
			count+=1
		end
	end
	kit.Size=portrait and UDim2.fromOffset(92,92) or UDim2.fromOffset(mobile and 188 or 376,mobile and 44 or 32)
	kit.AnchorPoint=Vector2.new(portrait and 0 or .5,1)
	kit.Position=portrait and UDim2.new(0,8,1,-176) or UDim2.new(.5,mobile and -36 or 0,1,mobile and -64 or -94*desktopScale)

	updateHUDPreferences()
end
Theme.BindResponsive(card, layout)
Settings.Changed:Connect(updateHUDPreferences)
gui.Parent:GetAttributeChangedSignal("BuildPlacementActive"):Connect(updateHUDPreferences)
gui.Parent:GetAttributeChangedSignal("MenuCursorOpen"):Connect(updateHUDPreferences)
updateHUDPreferences()

local remotes = Util.GetDescendant(Config.Paths.Remotes) or Util.WaitForDescendant(Config.Paths.Remotes, 15)
local function remote(name) return remotes and Util.GetRemote(remotes, Config.RemoteNames[name]) end
local rProfile, rRole, rRoleSelect = remote("ProfileUpdate"), remote("RoleUpdate"), remote("RoleSelect")
local rGame, rEvent, rObjective = remote("GameStateUpdate"), remote("EventBroadcast"), remote("ObjectiveUpdate")
local profile = { Level = 1 }
local roles, roleIndex = {}, 1
for roleId in pairs(Config.ROLES.Definitions or {}) do table.insert(roles, roleId) end
table.sort(roles)
local function readable(value)
	-- gsub also returns a replacement count; callers need only the label.
	return (tostring(value):gsub("_", " "):gsub("(%l)(%u)", "%1 %2"))
end
local function updateRole()
	for index, id in ipairs(roles) do if id == profile.Role then roleIndex = index end end
	roleButton.Text = string.format("%s  /  LV %d  /  CHANGE", string.upper(readable(profile.Role or "FIELD ROLE")), profile.Level or 1)
end
if rProfile then rProfile.OnClientEvent:Connect(function(data)
	if type(data) == "table" then profile = data; updateRole() end
end) end
if rRole then rRole.OnClientEvent:Connect(function(id)
	if type(id) == "string" then profile.Role = id; updateRole() end
end) end
roleButton.Activated:Connect(function()
	if not rRoleSelect or #roles == 0 then return end
	roleIndex = roleIndex % #roles + 1
	rRoleSelect:FireServer(roles[roleIndex])
end)

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end
local deadline, shiftDuration, elapsed, receivedAt = nil, 300, 0, os.clock()
if rGame then rGame.OnClientEvent:Connect(function(state)
	if type(state) ~= "table" then return end
	if state.Biome then biomeLabel.Text = state.BiomeDisplayName or readable(state.Biome) end
	if type(state.Elapsed) == "number" then elapsed = state.Elapsed; receivedAt = os.clock() end
	if state.HasFieldClock == false then
		deadline = nil
		countdown.Text = "--:--"
		shiftLabel.Text = "FIELD CLOCK REQUIRED"
		fill.Size = UDim2.fromScale(0, 1)
	elseif type(state.ShiftRemaining) == "number" then
		deadline = os.clock() + state.ShiftRemaining
	end
	if type(state.ShiftDuration) == "number" then shiftDuration = math.max(1, state.ShiftDuration) end
	local weather = type(state.Weather) == "table" and (state.Weather.Name or state.Weather.Id) or state.Weather
	if weather then
		weatherLabel.Text = readable(weather) .. (state.UpcomingWeather and "  >  " .. readable(state.UpcomingWeather) or "  /  CONDITIONS")
	end
	cycleLabel.Text = string.format("SHIFT %02d  /  THREAT %s", tonumber(state.ShiftCount) or 0, tostring(state.Difficulty or 1))
end) end
local lastTick = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastTick < 0.1 then return end
	lastTick = now
	runLabel.Text = clock(elapsed + now - receivedAt)
	if deadline then
		local remaining = math.max(0, deadline - now)
		countdown.Text = clock(math.ceil(remaining))
		local urgent = remaining <= 15
		countdown.TextColor3 = urgent and Color3.fromRGB(241, 139, 101) or C.Amber
		fill.BackgroundColor3 = countdown.TextColor3
		Theme.Tween(fill, { Size = UDim2.fromScale(math.clamp(remaining / shiftDuration, 0, 1), 1) }, 0.15)
		shiftLabel.Text = urgent and "SHIFT IMMINENT" or "NEXT SHIFT"
	end
end)

local events, objectives = {}, {}
if rEvent then rEvent.OnClientEvent:Connect(function(kind, id)
	if kind == "Minor_Start" or kind == "Major_Start" then events[id] = true
	elseif kind == "Minor_End" or kind == "Major_End" then events[id] = nil end
	local names = {}
	for eventId in pairs(events) do table.insert(names, readable(eventId)) end
	table.sort(names)
	eventLabel.Text = #names > 0 and table.concat(names, " / ") or "No active anomalies"
	eventLabel.TextColor3 = #names > 0 and C.Amber or C.Sage
end) end
if rObjective then rObjective.OnClientEvent:Connect(function(kind, id, data)
	if kind == "Start" then objectives[id] = 0
	elseif kind == "Progress" then objectives[id] = tonumber(data) or 0
	elseif kind == "End" then objectives[id] = nil end
	local names = {}
	for objectiveId, progress in pairs(objectives) do
		table.insert(names, string.format("%s  %d%%", readable(objectiveId), math.floor(progress * 100)))
	end
	table.sort(names)
	objectiveLabel.Text = #names > 0 and (names[1] .. (#names > 1 and "\n+" .. tostring(#names - 1) .. " active objectives" or "")) or "Gather supplies. Keep your team alive."
end) end

task.defer(function()
	for _, request in ipairs({ {rProfile, "RequestProfile"}, {rRole, "RequestRole"}, {rGame, "RequestState"}, {rEvent, "RequestActive"}, {rObjective, "RequestActive"} }) do
		if request[1] then request[1]:FireServer(request[2]) end
	end
end)
