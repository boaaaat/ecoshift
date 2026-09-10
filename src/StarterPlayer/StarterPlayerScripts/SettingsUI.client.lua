-- Shared by the lobby and expedition. Theme changes do not rebuild other panels.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("UITheme"))
local isExpedition = require(ReplicatedStorage.Shared.SessionConfig).GetMode() == "Expedition"
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
Theme.TrackRoot(playerGui)

local gui = Instance.new("ScreenGui")
gui.Name = "SettingsUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 130
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local open = Instance.new("TextButton")
open.Name = "OpenSettings"
open.Size = UDim2.fromOffset(44, 44)
open.Position = UDim2.new(1, -18, 0, 12)
open.AnchorPoint = Vector2.new(1, 0)
open.Text = ""
open.Font = Enum.Font.GothamBold
open.TextSize = 14
open.Parent = gui
Theme.Button(open, true)
-- Draw the gear locally so the shortcut never waits for an image to load.
local gear = Instance.new("Frame")
gear.Name = "GearIcon"
gear.BackgroundTransparency = 1
gear.Size = UDim2.fromOffset(26, 26)
gear.AnchorPoint = Vector2.new(.5, .5)
gear.Position = UDim2.fromScale(.5, .5)
gear.Parent = open
for index = 0, 7 do
	local angle = math.rad(index * 45)
	local tooth = Instance.new("Frame")
	tooth.BorderSizePixel = 0
	tooth.Size = UDim2.fromOffset(5, 7)
	tooth.AnchorPoint = Vector2.new(.5, .5)
	tooth.Position = UDim2.fromOffset(13 + math.sin(angle) * 10, 13 - math.cos(angle) * 10)
	tooth.Rotation = index * 45
	tooth.Parent = gear
	Theme.Bind(tooth, "BackgroundColor3", "Paper")
end
local ring = Instance.new("Frame")
ring.Name = "Ring"
ring.BackgroundTransparency = 1
ring.Size = UDim2.fromOffset(14, 14)
ring.AnchorPoint = Vector2.new(.5, .5)
ring.Position = UDim2.fromScale(.5, .5)
ring.Parent = gear
Theme.Corner(ring, 20)
local outline = Instance.new("UIStroke")
outline.Thickness = 4
outline.Parent = ring
Theme.Bind(outline, "Color", "Paper")
if isExpedition then
	require(ReplicatedStorage.Shared.UI:WaitForChild("ExpeditionTopbar")).Mount(open, "Settings")
else
	local shortcut = Instance.new("Frame")
	shortcut.Name = "SettingsShortcut"
	shortcut.BackgroundTransparency = 1
	shortcut.Size, shortcut.Position, shortcut.AnchorPoint = open.Size, open.Position, open.AnchorPoint
	shortcut.Parent = gui
	open.Parent = shortcut
	open.Position, open.AnchorPoint = UDim2.new(), Vector2.zero
	Theme.Fit(shortcut, 900, 610, nil, true)
end

local backdrop = Instance.new("TextButton")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Theme.Colors.Night
backdrop.BackgroundTransparency = 0.3
backdrop.BorderSizePixel = 0
backdrop.AutoButtonColor = false
backdrop.Text = ""
backdrop.Visible = false
backdrop.ZIndex = 5
backdrop.Parent = gui

local Settings = require(ReplicatedStorage.Shared.ClientSettings)
local Schema = require(ReplicatedStorage.Shared.SettingsConfig)
local panel = Instance.new("Frame")
panel.Name = "FieldSettings"
panel.Size = UDim2.fromOffset(580, 560)
panel.Position, panel.AnchorPoint = UDim2.fromScale(.5, .5), Vector2.new(.5, .5)
panel.ZIndex, panel.Visible, panel.Parent = 6, false, gui
Theme.Panel(panel)
Theme.CaptureCursor(panel); Theme.AnimatePanel(panel)
Theme.Label(panel, "PERSONAL FIELD KIT", UDim2.fromOffset(440, 18), UDim2.fromOffset(22, 16), 10, Theme.Colors.TextMuted, true)
Theme.Label(panel, "Settings", UDim2.fromOffset(420, 32), UDim2.fromOffset(22, 36), 25, nil, true)
local function button(parent, name, text, x, y, w, h)
	local b = Instance.new("TextButton")
	b.Name, b.Text, b.Size, b.Position = name, text, UDim2.fromOffset(w, h), UDim2.fromOffset(x, y)
	b.Font, b.TextSize, b.ZIndex, b.Parent = Enum.Font.GothamBold, Theme.IsMobile() and 15 or 12, 8, parent
	Theme.Button(b, false)
	return b
end
local close = button(panel, "CloseSettings", "X", 530, 16, 30, 30)
local tabs, currentTab = {}, "Gameplay"
local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Preferences"
scroll.Size, scroll.Position = UDim2.fromOffset(536, 320), UDim2.fromOffset(22, 118)
scroll.BackgroundTransparency, scroll.BorderSizePixel, scroll.ScrollBarThickness = 1, 0, 5
scroll.AutomaticCanvasSize, scroll.CanvasSize = Enum.AutomaticSize.Y, UDim2.new()
scroll.ZIndex, scroll.Parent = 7, panel
local layout = Instance.new("UIListLayout")
layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0, 8), Enum.SortOrder.LayoutOrder, scroll
local mobilePreferences = Instance.new("Frame")
mobilePreferences.Name, mobilePreferences.BackgroundTransparency = "MobilePreferences", 1
mobilePreferences.Position, mobilePreferences.ZIndex = UDim2.fromOffset(16, 134), 7
mobilePreferences.Visible, mobilePreferences.Parent = false, panel
local status = Theme.Label(panel, "", UDim2.fromOffset(536, 46), UDim2.fromOffset(22, 446), 11, Theme.Colors.TextMuted)
status.TextWrapped, status.TextTruncate = true, Enum.TextTruncate.None
local save = button(panel, "SavePreferences", "Save preferences", 354, 506, 204, 34)
local reset = button(panel, "ResetPreferences", "Reset defaults", 22, 506, 150, 34)
local replay = button(panel, "ReplayTutorial", "Replay tutorial", 182, 506, 162, 34)
replay.Visible = isExpedition
local rows, capture = {}, nil
local updateMobileContent
local function cancelCapture()
	capture = nil; Settings.Capturing = false
end
local function render()
	Theme.SetMode(Settings.Get("UITheme"))
	status.Text = capture and "Press a key. Esc cancels. Movement, E, Q, X, number keys and chat are reserved." or Settings.Status
	for key, row in pairs(rows) do
		row.Frame.Visible = Schema.Definitions[key].Section == currentTab
		local value = Settings.Get(key)
		row.Button.Text = capture == key and "Press a key..." or (type(value) == "boolean" and (value and "On" or "Off") or tostring(value))
	end
	for name, tab in pairs(tabs) do Theme.Bind(tab, "BackgroundColor3", currentTab == name and "SlotSelected" or "SlotEmpty") end
	if updateMobileContent then updateMobileContent() end
end
for index, section in ipairs({ "Gameplay", "Graphics", "Keybinds" }) do
	local tab = button(panel, section .. "Tab", section, 22 + (index - 1) * 182, 78, 172, 30)
	tabs[section] = tab
	tab.Activated:Connect(function() cancelCapture(); currentTab = section; scroll.CanvasPosition = Vector2.zero; render() end)
end
for index, key in ipairs(Schema.Order) do
	local def = Schema.Definitions[key]
	local row = Instance.new("Frame")
	row.Name, row.Size, row.BackgroundTransparency = key, UDim2.new(1, -10, 0, 44), 1
	row.LayoutOrder, row.Parent = index, scroll
	Theme.Label(row, def.Label, UDim2.fromOffset(330, 38), UDim2.fromOffset(0, 3), 12)
	local choice = button(row, "Value", "", 340, 3, 172, 36)
	rows[key] = { Frame = row, Button = choice }
	choice.Activated:Connect(function()
		cancelCapture()
		if def.Section == "Keybinds" then capture = key; Settings.Capturing = true
		elseif def.Values then
			local indexNow = table.find(def.Values, Settings.Get(key)) or 1
			Settings.Set(key, def.Values[indexNow % #def.Values + 1])
		else Settings.Set(key, not Settings.Get(key)) end
		render()
	end)
end
Settings.Changed:Connect(render)
local function setOpen(visible)
	cancelCapture()
	backdrop.Visible, panel.Visible, open.Visible = visible, visible, not visible
	render()
end
open.Activated:Connect(function() setOpen(true) end)
close.Activated:Connect(function() setOpen(false) end)
backdrop.Activated:Connect(function() setOpen(false) end)
save.Activated:Connect(function() cancelCapture(); Settings.Save() end)
reset.Activated:Connect(function() cancelCapture(); Settings.Reset() end)
replay.Activated:Connect(function()
	setOpen(false)
	player:SetAttribute("ReplaySurvivalTutorial", (player:GetAttribute("ReplaySurvivalTutorial") or 0) + 1)
end)
player:GetAttributeChangedSignal("FieldKitSettings"):Connect(function() setOpen(not panel.Visible) end)
UserInputService.InputBegan:Connect(function(input, processed)
	if capture then
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if input.KeyCode == Enum.KeyCode.Escape then cancelCapture(); render(); return end
		if not Settings.Set(capture, input.KeyCode.Name) then
			status.Text = "That key is reserved or already bound. Choose another key, or press Esc."
			return
		end
		-- Keep gameplay suppressed through the current input dispatch.
		task.defer(function() cancelCapture(); render() end)
		return
	end
	if processed or not Settings.CanInput() then return end
	if Settings.Matches(input, "Settings") then setOpen(not panel.Visible)
	elseif input.KeyCode == Enum.KeyCode.Escape and panel.Visible then setOpen(false) end
end)
render()

updateMobileContent = function()
	if not Theme.IsMobile() or not panel.Parent:IsA("ScrollingFrame") then return end
	local count = 0
	for key in pairs(rows) do if Schema.Definitions[key].Section == currentTab then count += 1 end end
	local contentHeight = math.max(1, count * 76 - 8)
	scroll.CanvasPosition = Vector2.zero
	mobilePreferences.Size = UDim2.new(1, -32, 0, contentHeight)
	local footerY = 134 + contentHeight + 12
	status.Position = UDim2.fromOffset(16, footerY)
	reset.Position = UDim2.fromOffset(16, footerY + 68)
	replay.Position = UDim2.new(.5, 8, 0, footerY + 68)
	save.Position = UDim2.fromOffset(16, footerY + 126)
	local height = footerY + 190
	panel.Size = UDim2.fromOffset(panel.Size.X.Offset, height)
	local scale = panel:FindFirstChild("ViewportScale")
	local factor = scale and (scale:GetAttribute("TargetScale") or scale.Scale) or 1
	panel.Parent.CanvasSize = UDim2.fromOffset(0, height * factor)
end

Theme.FitMenu(panel, 580, 560, {OnClose = function() setOpen(false) end, MobileWidth = 360, MobileHeight = 630, OnResize = function(width, _, mobile)
	close.Visible = not mobile
	scroll.Visible, mobilePreferences.Visible = not mobile, mobile
	local rowsParent = mobile and mobilePreferences or scroll
	layout.Parent = rowsParent
	for _, row in pairs(rows) do row.Frame.Parent = rowsParent end
	if not mobile then return end
	close.Position = UDim2.new(1, -58, 0, 16); close.Size = UDim2.fromOffset(44, 44)
	for _, child in ipairs(panel:GetChildren()) do
		if child:IsA("TextLabel") and child ~= status then child.Size = UDim2.new(1, -92, 0, child.Size.Y.Offset) end
	end
	for index, name in ipairs({"Gameplay", "Graphics", "Keybinds"}) do
		local tab = tabs[name]
		tab.Position = UDim2.new((index-1)/3, 16, 0, 78)
		tab.Size = UDim2.new(1/3, -24, 0, 44)
	end
	scroll.Position = UDim2.fromOffset(16, 134); scroll.Size = UDim2.new(1, -32, 0, 290)
	for _, row in pairs(rows) do
		row.Frame.Size = UDim2.new(1, -10, 0, 68)
		local caption = row.Frame:FindFirstChildWhichIsA("TextLabel")
		if caption then caption.Size = UDim2.new(.55, -8, 1, -8); caption.TextSize = 15; caption.TextWrapped = true end
		row.Button.Position = UDim2.new(.55, 0, 0, 8); row.Button.Size = UDim2.new(.45, -4, 0, 48)
	end
	status.Position = UDim2.fromOffset(16, 434); status.Size = UDim2.new(1, -32, 0, 56); status.TextSize = 14
	reset.Position = UDim2.fromOffset(16, 502); reset.Size = UDim2.new(.5, -24, 0, 44)
	replay.Position = UDim2.new(.5, 8, 0, 502); replay.Size = UDim2.new(.5, -24, 0, 44)
	save.Position = UDim2.fromOffset(16, 560); save.Size = UDim2.new(1, -32, 0, 48)
	updateMobileContent()
end})
Theme.BindResponsive(panel, updateMobileContent)
