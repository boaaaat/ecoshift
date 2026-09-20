-- Lock both the observatory and expedition to a phone-friendly landscape view.
-- ReplicatedFirst applies this before the rest of the UI is cloned after a teleport.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

if not UserInputService.TouchEnabled then return end

local landscape = Enum.ScreenOrientation.LandscapeSensor

local function enforce(container)
	local ok = pcall(function() container.ScreenOrientation = landscape end)
	if not ok then return end
	pcall(function()
		container:GetPropertyChangedSignal("ScreenOrientation"):Connect(function()
			if container.ScreenOrientation ~= landscape then
				container.ScreenOrientation = landscape
			end
		end)
	end)
end

enforce(StarterGui)
enforce(Players.LocalPlayer:WaitForChild("PlayerGui"))
