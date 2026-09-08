-- Shared by the lobby and expedition. Theme changes do not rebuild other panels.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("UITheme"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
Theme.TrackRoot(playerGui)
Theme.SetMode(player:GetAttribute("UITheme"))
player:GetAttributeChangedSignal("UITheme"):Connect(function()
	Theme.SetMode(player:GetAttribute("UITheme"))
end)

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
local shortcut = Instance.new("Frame")
shortcut.Name = "SettingsShortcut"
shortcut.BackgroundTransparency = 1
shortcut.Size, shortcut.Position, shortcut.AnchorPoint = open.Size, open.Position, open.AnchorPoint
shortcut.Parent = gui
open.Parent = shortcut
open.Position, open.AnchorPoint = UDim2.new(), Vector2.zero
Theme.Fit(shortcut, 900, 610, nil, true)

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

local panel = Instance.new("Frame")
panel.Name = "FieldSettings"
panel.Size = UDim2.fromOffset(464, 320)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.ZIndex = 6
panel.Visible = false
panel.Parent = gui
Theme.Panel(panel)
Theme.Fit(panel, 464, 320)
Theme.AnimatePanel(panel)

Theme.Label(panel, "ECOSHIFT  /  PERSONAL FIELD KIT", UDim2.fromOffset(390, 18), UDim2.fromOffset(22, 16), 10, Theme.Colors.TextMuted, true)
Theme.Label(panel, "Make camp your own.", UDim2.fromOffset(390, 32), UDim2.fromOffset(22, 38), 24, nil, true)
Theme.Label(panel, "APPEARANCE", UDim2.fromOffset(320, 18), UDim2.fromOffset(22, 85), 10, Theme.Colors.TextMuted, true)

local close = Instance.new("TextButton")
close.Name = "CloseSettings"
close.Size = UDim2.fromOffset(30, 30)
close.Position = UDim2.new(1, -46, 0, 16)
close.Text = "×"
close.Font = Enum.Font.Gotham
close.TextSize = 21
close.ZIndex = 8
close.Parent = panel
Theme.Button(close, false)

local choices = {}
for index, option in ipairs({ { "Dark", "NIGHT WATCH", "Charcoal & moss" }, { "Light", "FIELD PAPER", "Warm expedition notes" } }) do
	local mode, title, subtitle = option[1], option[2], option[3]
	local card = Instance.new("TextButton")
	card.Name = mode .. "Theme"
	card.Size = UDim2.fromOffset(202, 137)
	card.Position = UDim2.fromOffset(22 + (index - 1) * 218, 110)
	card.Text = ""
	card.ZIndex = 7
	card.Parent = panel
	Theme.Button(card, false)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "SelectionOutline"
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card

	-- Illustrations show both choices faithfully even when the active theme changes.
	local previewPalette = Theme.Palette(mode)
	local preview = Instance.new("Frame")
	preview.Name = "PalettePreview"
	preview:SetAttribute("ThemeFixed", true)
	preview.Size = UDim2.fromOffset(178, 64)
	preview.Position = UDim2.fromOffset(12, 12)
	preview.BackgroundColor3 = previewPalette.Panel
	preview.BorderSizePixel = 0
	preview.ZIndex = 8
	preview.Parent = card
	Theme.Corner(preview, 5)
	local ribbon = Instance.new("Frame")
	ribbon.Size = UDim2.new(0, 4, 1, -20)
	ribbon.Position = UDim2.fromOffset(10, 10)
	ribbon.BackgroundColor3 = previewPalette.Amber
	ribbon.BorderSizePixel = 0
	ribbon.ZIndex = 9
	ribbon.Parent = preview
	for line = 1, 3 do
		local mark = Instance.new("Frame")
		mark.Size = UDim2.fromOffset(line == 1 and 109 or (line == 2 and 135 or 82), line == 1 and 6 or 4)
		mark.Position = UDim2.fromOffset(25, 11 + (line - 1) * 16)
		mark.BackgroundColor3 = line == 1 and previewPalette.Text or previewPalette.TextMuted
		mark.BackgroundTransparency = line == 1 and 0 or 0.35
		mark.BorderSizePixel = 0
		mark.ZIndex = 9
		mark.Parent = preview
		Theme.Corner(mark, 2)
	end
	Theme.Label(card, title, UDim2.fromOffset(164, 20), UDim2.fromOffset(12, 84), 11, nil, true)
	Theme.Label(card, subtitle, UDim2.fromOffset(180, 18), UDim2.fromOffset(12, 108), 10, Theme.Colors.TextMuted)
	local selected = Theme.Label(card, "✓", UDim2.fromOffset(20, 20), UDim2.fromOffset(172, 84), 14, Theme.Colors.Text, true)
	selected.Name = "Selected"
	choices[mode] = { Button = card, Outline = stroke, Selected = selected }
end

local status = Theme.Label(panel, "Applies across your field kit, map and crafting menus.", UDim2.new(1, -44, 0, 36), UDim2.fromOffset(22, 265), 11, Theme.Colors.TextMuted)
status.Name = "PreferenceStatus"
status.TextWrapped = true
status.TextTruncate = Enum.TextTruncate.None

local function renderSelection()
	for mode, choice in pairs(choices) do
		local selected = Theme.Mode == mode
		Theme.Bind(choice.Button, "BackgroundColor3", selected and "SlotSelected" or "SlotEmpty")
		Theme.Bind(choice.Outline, "Color", selected and "Amber" or "Border")
		choice.Outline.Transparency = selected and 0 or 0.55
		choice.Selected.Visible = selected
	end
end
Theme.Changed:Connect(renderSelection)
renderSelection()

local preferenceRemote, requestedTheme
for mode, choice in pairs(choices) do
	choice.Button.Activated:Connect(function()
		requestedTheme = mode
		player:SetAttribute("UITheme", mode)
		Theme.SetMode(mode)
		if preferenceRemote then
			status.Text = "Saving your appearance preference..."
			preferenceRemote:FireServer("SetTheme", mode)
		else
			status.Text = "Appearance applied. Waiting for your expedition profile..."
		end
	end)
end

task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
	preferenceRemote = remotes and remotes:WaitForChild("ProfilePreference", 30)
	if not preferenceRemote then
		if requestedTheme then status.Text = "Appearance applied for this session." end
		return
	end
	preferenceRemote.OnClientEvent:Connect(function(action, result)
		if action ~= "Result" or type(result) ~= "table" then return end
		if result.RequestedTheme and result.RequestedTheme ~= requestedTheme then return end
		if result.Success then
			status.Text = "Appearance preference updated."
		else
			status.Text = "Appearance applied. Your preference could not be saved yet."
		end
	end)
	if requestedTheme then preferenceRemote:FireServer("SetTheme", requestedTheme) end
end)

local function setOpen(visible)
	backdrop.Visible, panel.Visible = visible, visible
	open.Visible = not visible
end
open.Activated:Connect(function() setOpen(true) end)
close.Activated:Connect(function() setOpen(false) end)
backdrop.Activated:Connect(function() setOpen(false) end)
player:GetAttributeChangedSignal("FieldKitSettings"):Connect(function() setOpen(not panel.Visible) end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.F4 then setOpen(not panel.Visible) end
end)
