if require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local remotesFolder = Util.GetDescendant(Config.Paths.Remotes) or Util.WaitForDescendant(Config.Paths.Remotes, 5)
local rSprint = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.SprintToggle)
if not rSprint then
	return
end

local held, requested = {}, false
local function isSprintKey(keyCode)
	return keyCode == Enum.KeyCode.LeftShift or keyCode == Enum.KeyCode.RightShift
end
local function request(enabled)
	if requested == enabled then return end
	requested = enabled; rSprint:FireServer(enabled)
end
local function release()
	table.clear(held); request(false)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if UserInputService:GetFocusedTextBox() or player:GetAttribute("IsDead") then return end
	if isSprintKey(input.KeyCode) then
		held[input.KeyCode] = true; request(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	-- Release even after a menu or text field consumed the input.
	if isSprintKey(input.KeyCode) then
		held[input.KeyCode] = nil; request(next(held) ~= nil)
	end
end)

UserInputService.WindowFocusReleased:Connect(release)
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
