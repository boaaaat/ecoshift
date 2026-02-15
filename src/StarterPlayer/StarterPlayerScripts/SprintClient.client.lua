-- SprintClient.client.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local remotesFolder = Util.GetDescendant(Config.Paths.Remotes) or Util.WaitForDescendant(Config.Paths.Remotes, 5)
local rSprint = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.SprintToggle)
if not rSprint then
	return
end

local function isSprintKey(keyCode)
	return keyCode == Enum.KeyCode.LeftControl or keyCode == Enum.KeyCode.RightControl
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if UserInputService:GetFocusedTextBox() then return end
	if isSprintKey(input.KeyCode) then
		rSprint:FireServer(true)
	end
end)

UserInputService.InputEnded:Connect(function(input, processed)
	if processed then return end
	if UserInputService:GetFocusedTextBox() then return end
	if isSprintKey(input.KeyCode) then
		rSprint:FireServer(false)
	end
end)

print("[SprintClient] Initialized")
