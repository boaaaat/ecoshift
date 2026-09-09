-- Compact expedition shortcuts share Roblox's available topbar safe area.
-- https://create.roblox.com/docs/reference/engine/classes/GuiService#TopbarInset
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
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

local row = Instance.new("Frame")
row.Name = "Controls"
row.BackgroundTransparency = 1
row.Size = UDim2.fromOffset(WIDTH, HEIGHT)
row.Parent = gui

local slots = {}
for _, entry in ipairs({ { "Crew", 0, 74 }, { "Settings", 82, 44 } }) do
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
	local fits = available.Width >= WIDTH + GAP * 2 and available.Height >= HEIGHT
	-- ScreenInsets applies the native safe rectangle; do not add its offset again.
	gui.ScreenInsets = fits and Enum.ScreenInsets.TopbarSafeInsets or Enum.ScreenInsets.CoreUISafeInsets
	row.AnchorPoint = Vector2.new(0, fits and .5 or 0)
	row.Position = UDim2.new(0, GAP, fits and .5 or 0, fits and 0 or GAP)
end
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layout)
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
	button.Name = slotName == "Crew" and "OpenCrew" or "OpenSettings"
	button.AnchorPoint = Vector2.zero
	button.Position = UDim2.new()
	button.Size = UDim2.fromScale(1, 1)
	button.Parent = slot
	return button
end

return Topbar
