-- Compact expedition shortcuts share Roblox's available topbar safe area.
-- https://create.roblox.com/docs/reference/engine/classes/GuiService#TopbarInset
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.UITheme)
local Topbar = {}
local WIDTH, HEIGHT, GAP = 126, 44, 8
local gui = Instance.new("ScreenGui")
gui.Name = "ExpeditionTopbar"
gui.ResetOnSpawn = false
gui.DisplayOrder = 55
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
Theme.TrackRoot(gui)
local deviceGui = Instance.new("ScreenGui")
deviceGui.Name = "ExpeditionTopbarOverflow"
deviceGui.ResetOnSpawn = false
deviceGui.DisplayOrder = 55
deviceGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
deviceGui.Parent = gui.Parent
Theme.TrackRoot(deviceGui)

local row = Instance.new("Frame")
row.Name = "Controls"
row.BackgroundTransparency = 1
row.Size = UDim2.fromOffset(WIDTH, HEIGHT)
row.Parent = gui

local slots = {}
for _, entry in ipairs({ { "Crew", 0, 74 }, { "Settings", 82, 44 }, {"Time", 134, 90} }) do
	local slot = Instance.new("Frame")
	slot.Name = entry[1] .. "Slot"
	slot.BackgroundTransparency = 1
	slot.Position = UDim2.fromOffset(entry[2], 0)
	slot.Size = UDim2.fromOffset(entry[3], HEIGHT)
	slot.Parent = row
	slots[entry[1]] = slot
end

local function layout()
	local available = GuiService.TopbarInset
	local mobile = Theme.IsMobile()
	local visible = not mobile or not gui.Parent:GetAttribute("MenuCursorOpen")
	gui.Enabled,deviceGui.Enabled=visible,visible
	local shortcutWidth = mobile and 92 or WIDTH
	-- The 106px mobile minimap owns the top-right corner even in portrait.
	local usableWidth = available.Width - (mobile and 112 or 0)
	local fits = usableWidth >= shortcutWidth + GAP * 2 and available.Height >= HEIGHT
	gui.Parent:SetAttribute("MobileTopbarFallback", mobile and not fits)
	-- ScreenInsets applies the native safe rectangle; do not add its offset again.
	gui.ScreenInsets = fits and Enum.ScreenInsets.TopbarSafeInsets or Enum.ScreenInsets.CoreUISafeInsets
	row.AnchorPoint = Vector2.new(0, fits and .5 or 0)
	row.Position = UDim2.new(0, GAP, fits and .5 or 0, fits and 0 or GAP)
	row.Size = UDim2.fromOffset(shortcutWidth, HEIGHT)
	slots.Crew.Size = UDim2.fromOffset(mobile and 44 or 74, HEIGHT)
	slots.Settings.Position = UDim2.fromOffset(mobile and 48 or 82, 0)
	slots.Time.Visible = mobile
	local inlineTime = not fits or usableWidth >= shortcutWidth + 104
	slots.Time.Parent = inlineTime and row or deviceGui
	slots.Time.AnchorPoint = Vector2.new(inlineTime and 0 or 1, 0)
	slots.Time.Position = inlineTime and UDim2.fromOffset(shortcutWidth + 8, 10) or UDim2.new(1, -12, 0, 114)
	slots.Time.Size = UDim2.fromOffset(90, 24)
	local crew = slots.Crew:FindFirstChild("OpenCrew")
	for _,slot in ipairs({slots.Crew,slots.Settings}) do
		local button=slot:FindFirstChildWhichIsA("GuiButton")
		if button then button.BackgroundTransparency=mobile and .48 or 0 end
	end
	if crew then
		crew.Text = mobile and "" or "CREW"
		local icon = crew:FindFirstChild("CrewIcon")
		if icon then icon.Visible = mobile end
	end
end
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layout)
gui.Parent:GetAttributeChangedSignal("MenuCursorOpen"):Connect(layout)
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(layout)
local viewportConnection
local function bindCamera()
	if viewportConnection then viewportConnection:Disconnect() end
	if Workspace.CurrentCamera then
		viewportConnection = Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
	layout()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()

function Topbar.Mount(button, slotName)
	local slot = assert(slots[slotName], "Unknown expedition shortcut")
	button.Name = slotName == "Time" and "TimeDisplay" or (slotName == "Crew" and "OpenCrew" or "OpenSettings")
	button.AnchorPoint = Vector2.zero
	button.Position = UDim2.new()
	button.Size = UDim2.fromScale(1, 1)
	button.Parent = slot
	if slotName == "Crew" and Theme.Icon then
		local icon = Theme.TouchIcon(button, "Crew", 24)
		icon.Name = "CrewIcon"
	end
	layout()
	return button
end

return Topbar
