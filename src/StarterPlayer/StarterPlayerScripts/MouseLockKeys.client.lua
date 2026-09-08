-- Preserve Roblox's camera controller while moving its toggle away from sprint.
-- MouseLockController observes this StringValue and rebinds automatically.
local player = game:GetService("Players").LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local playerModule = scripts:WaitForChild("PlayerModule", 30)
local cameraModule = playerModule and playerModule:WaitForChild("CameraModule", 10)
local controller = cameraModule and cameraModule:WaitForChild("MouseLockController", 10)
if not controller then warn("[MouseLockKeys] Roblox mouse-lock controller is unavailable."); return end
local boundKeys = controller:FindFirstChild("BoundKeys")
if boundKeys and not boundKeys:IsA("StringValue") then
	warn("[MouseLockKeys] Unexpected mouse-lock key configuration."); return
end
if not boundKeys then
	boundKeys = Instance.new("StringValue"); boundKeys.Name = "BoundKeys"
	boundKeys.Value = "LeftControl,RightControl"; boundKeys.Parent = controller
else
	boundKeys.Value = "LeftControl,RightControl"
end
