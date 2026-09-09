local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
if require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end
local Theme = require(ReplicatedStorage.Shared.UI.UITheme)
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "MobileActionUI", false, 10
gui.Parent = playerGui
local action = Instance.new("TextButton")
action.Name, action.Size = "HeldToolAction", UDim2.fromOffset(44, 44)
action.AnchorPoint, action.Position = Vector2.new(1, 1), UDim2.new(1, -16, 1, -170)
action.Text, action.TextSize, action.Font = "", 14, Enum.Font.GothamBold
action.Visible, action.Parent = false, gui
Theme.Button(action, true)
action.BackgroundTransparency = .48
local glyphs = {}
for _, name in ipairs({"Attack", "Harvest", "Bow", "Shield"}) do
	local glyph = Theme.Icon(action, name, 26)
	glyph.Name = name .. "Glyph"
	glyph.Visible = false
	glyphs[name] = glyph
end
local heldGlow = Instance.new("UIStroke")
heldGlow.Name, heldGlow.Color, heldGlow.Thickness = "HeldGlow", Theme.Colors.Amber, 2
heldGlow.Enabled, heldGlow.Parent = false, action
Theme.BindResponsive(action, function(_, available)
	action.Position = available.X >= available.Y
		and UDim2.new(1, -16, 1, -170) or UDim2.new(1, -16, 1, -192)
end)

-- A separate viewport GUI keeps the reticle exactly on the ray used by the tools.
local aimGui = Instance.new("ScreenGui")
aimGui.Name, aimGui.ResetOnSpawn, aimGui.IgnoreGuiInset = "MobileAimReticle", false, true
aimGui.ScreenInsets = Enum.ScreenInsets.None
aimGui.DisplayOrder, aimGui.Parent = 9, playerGui
local reticle = Instance.new("Frame")
reticle.Name, reticle.Size = "CenterReticle", UDim2.fromOffset(18, 18)
reticle.AnchorPoint, reticle.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
reticle.BackgroundTransparency, reticle.Visible, reticle.Parent = 1, false, aimGui
for _, shape in ipairs({{2, 6, 8, 0}, {2, 6, 8, 12}, {6, 2, 0, 8}, {6, 2, 12, 8}}) do
	local line = Instance.new("Frame")
	line.Size, line.Position = UDim2.fromOffset(shape[1], shape[2]), UDim2.fromOffset(shape[3], shape[4])
	line.BorderSizePixel, line.BackgroundColor3, line.Parent = 0, Color3.new(1, 1, 1), reticle
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.Parent = Color3.fromRGB(20, 25, 20), 1, line
end

local heldInput, heldTool
local focused = true
local originalManual = setmetatable({}, { __mode = "k" })
local characterConnections = {}
local function equippedTool()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Tool")
end
local function blocked()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return not Theme.IsMobile() or not focused or not humanoid or humanoid.Health <= 0
		or player:GetAttribute("IsDead") == true
		or playerGui:GetAttribute("MenuCursorOpen") == true
		or playerGui:GetAttribute("BuildPlacementActive") == true
		or UserInputService:GetFocusedTextBox() ~= nil
end
local function release(cancelled)
	local tool = heldTool
	heldInput, heldTool = nil, nil
	heldGlow.Enabled = false
	if tool and tool.Parent then
		tool:SetAttribute("CancelMobileRelease", cancelled and true or nil)
		tool:Deactivate()
	end
end
local function toolValue(tool, name)
	local attribute = tool:GetAttribute(name)
	if attribute ~= nil then return tostring(attribute) end
	local child = tool:FindFirstChild(name)
	return child and child:IsA("ValueBase") and tostring(child.Value) or ""
end
local function update()
	local tool = equippedTool()
	local available = tool ~= nil and not blocked()
	if heldInput and (not available or tool ~= heldTool) then release(true) end
	action.Visible, reticle.Visible = available, available
	if available and not heldInput then
		local kind = string.lower(toolValue(tool, "WeaponType"))
		local icon = (kind == "shield" or kind == "shields") and "Shield"
			or (kind == "bow" or kind == "bows") and "Bow"
			or (kind ~= "" and "Attack") or (toolValue(tool, "ToolType") ~= "" and "Harvest") or "Attack"
		for name, glyph in pairs(glyphs) do glyph.Visible = name == icon end
	end
end
local function registerTool(tool)
	if not tool:IsA("Tool") then return end
	if originalManual[tool] == nil then originalManual[tool] = tool.ManualActivationOnly end
	tool.ManualActivationOnly = Theme.IsMobile() or originalManual[tool]
end

action.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.Touch or heldInput or blocked() then return end
	local tool = equippedTool()
	if not tool or not tool.Enabled then return end
	heldInput, heldTool = input, tool
	tool:SetAttribute("CancelMobileRelease", nil)
	heldGlow.Enabled = true
	tool:Activate()
end)
UserInputService.InputEnded:Connect(function(input)
	if input == heldInput then release(input.UserInputState == Enum.UserInputState.Cancel); update() end
end)
UserInputService.WindowFocusReleased:Connect(function() focused = false; release(true); update() end)
UserInputService.WindowFocused:Connect(function() focused = true; update() end)
UserInputService.TextBoxFocused:Connect(update)
UserInputService.TextBoxFocusReleased:Connect(function() task.defer(update) end)
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
	release(true)
	for tool, original in pairs(originalManual) do
		if tool.Parent then tool.ManualActivationOnly = Theme.IsMobile() or original end
	end
	update()
end)
for _, attribute in ipairs({"MenuCursorOpen", "BuildPlacementActive"}) do
	playerGui:GetAttributeChangedSignal(attribute):Connect(update)
end
player:GetAttributeChangedSignal("IsDead"):Connect(update)

local function bindCharacter(character)
	release(true)
	for _, connection in ipairs(characterConnections) do connection:Disconnect() end
	table.clear(characterConnections)
	local backpack = player:WaitForChild("Backpack")
	for _, container in ipairs({backpack, character}) do
		for _, child in ipairs(container:GetChildren()) do registerTool(child) end
		table.insert(characterConnections, container.ChildAdded:Connect(function(child) registerTool(child); update() end))
		table.insert(characterConnections, container.ChildRemoved:Connect(update))
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid then table.insert(characterConnections, humanoid.Died:Connect(function() release(true); update() end)) end
	update()
end
player.CharacterAdded:Connect(bindCharacter)
player.CharacterRemoving:Connect(function() release(true); action.Visible = false; reticle.Visible = false end)
if player.Character then bindCharacter(player.Character) end
