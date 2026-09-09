if require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Settings = require(ReplicatedStorage.Shared.ClientSettings)
local Theme = require(ReplicatedStorage.Shared.UI.UITheme)

local remotesFolder = Util.GetDescendant(Config.Paths.Remotes) or Util.WaitForDescendant(Config.Paths.Remotes, 5)
local rSprint = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.SprintToggle)
if not rSprint then
	return
end

local held, requested = {}, false
local sprintButton, touchInput
local function isSprintKey(keyCode)
	return keyCode == Settings.Key("Sprint")
end
local function request(enabled)
	if requested == enabled then return end
	requested = enabled; rSprint:FireServer(enabled)
	if sprintButton then sprintButton.Text = enabled and "RUNNING" or "SPRINT" end
end
local function release()
	touchInput = nil
	table.clear(held); request(false)
end

local touchGui = Instance.new("ScreenGui")
touchGui.Name = "SprintTouchUI"
touchGui.ResetOnSpawn = false
touchGui.DisplayOrder = 9
touchGui.Parent = player:WaitForChild("PlayerGui")
sprintButton = Instance.new("TextButton")
sprintButton.Name = "HoldSprint"
sprintButton.AnchorPoint = Vector2.new(1, 1)
sprintButton.Position = UDim2.new(1, -100, 1, -94)
sprintButton.Size = UDim2.fromOffset(90, 48)
sprintButton.Text = "SPRINT"
sprintButton.TextSize = 15
sprintButton.Font = Enum.Font.GothamBold
sprintButton.Parent = touchGui
Theme.Button(sprintButton, true)
local function updateTouchVisibility()
	sprintButton.Visible = Theme.IsMobile() and not player:GetAttribute("IsDead") and not touchGui.Parent:GetAttribute("MenuCursorOpen") and not touchGui.Parent:GetAttribute("BuildPlacementActive")
	if not sprintButton.Visible then release() end
end
sprintButton.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.Touch or touchInput then return end
	if not Settings.CanInput() or player:GetAttribute("IsDead") then return end
	touchInput = input
	request(true)
end)
UserInputService.InputEnded:Connect(function(input)
	if input == touchInput then touchInput = nil; request(next(held) ~= nil) end
end)
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(updateTouchVisibility)
player:GetAttributeChangedSignal("IsDead"):Connect(updateTouchVisibility)
touchGui.Parent:GetAttributeChangedSignal("MenuCursorOpen"):Connect(updateTouchVisibility)
touchGui.Parent:GetAttributeChangedSignal("BuildPlacementActive"):Connect(updateTouchVisibility)
Theme.BindResponsive(sprintButton, function(_, available)
	sprintButton.Position = UDim2.new(1, -100, 1, available.X < available.Y and -192 or -94)
end)
updateTouchVisibility()

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not Settings.CanInput() then return end
	if UserInputService:GetFocusedTextBox() or player:GetAttribute("IsDead") then return end
	if isSprintKey(input.KeyCode) then
		if Settings.Get("SprintMode") == "Toggle" then request(not requested)
		else held[input.KeyCode] = true; request(true) end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	-- Release even after a menu or text field consumed the input.
	if held[input.KeyCode] then
		held[input.KeyCode] = nil; request(next(held) ~= nil)
	end
end)

UserInputService.WindowFocusReleased:Connect(release)
Settings.Changed:Connect(release)
UserInputService.TextBoxFocused:Connect(release)
GuiService.MenuOpened:Connect(release)
player:GetAttributeChangedSignal("IsDead"):Connect(function() if player:GetAttribute("IsDead") then release() end end)
player.CharacterRemoving:Connect(release)
local function bindCharacter(character)
	release()
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and player.Character == character then humanoid.Died:Connect(release) end
end
player.CharacterAdded:Connect(bindCharacter)
if player.Character then task.spawn(bindCharacter, player.Character) end
