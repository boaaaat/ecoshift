local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
if require(Shared:WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Pose = require(Shared.Art.ItemPose)
local Theme = require(Shared.UI.UITheme)
local Settings = require(Shared.ClientSettings)
local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()
local states, elapsed = {}, 0

local function clear(player)
	if states[player] then states[player]:Destroy(); states[player] = nil end
end
Players.PlayerRemoving:Connect(clear)

local function reconcile()
	local camera = workspace.CurrentCamera
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local tool = humanoid and humanoid.Health > 0 and char:FindFirstChildOfClass("Tool")
		local visible = root and (player == localPlayer or not camera or (root.Position - camera.CFrame.Position).Magnitude < 180)
		if not visible or not tool or tool.Parent ~= char then clear(player)
		elseif not states[player] or states[player].Tool ~= tool then
			clear(player)
			states[player] = Pose.Bind(char, tool)
		end
	end
end

-- Restore before Animator evaluates, then apply after it. This avoids fighting the
-- stock Animate script or accumulating arm offsets over successive frames.
Run.PreAnimation:Connect(function()
	for _, state in pairs(states) do state:Restore() end
end)
Run.PreSimulation:Connect(function(dt)
	elapsed += dt
	if elapsed >= .1 then elapsed = 0; reconcile() end
	local now = workspace:GetServerTimeNow()
	for player, state in pairs(states) do
		local tool = state.Tool
		local char = player.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if not tool.Parent or tool.Parent ~= char or not humanoid or humanoid.Health <= 0 then clear(player)
		else
			local started = tool:GetAttribute("BowDrawStarted")
			local action = tool:GetAttribute("ItemActionStarted")
			local kind = tool:GetAttribute("ItemActionKind")
			local aim = tool:GetAttribute("ItemAimDirection")
			if player == localPlayer then
				local localDraw = localPlayer:GetAttribute("BowChargeStarted")
				-- Local input predicts draw/cancel immediately, independent of network latency.
				started = localDraw and now - (os.clock() - localDraw) or nil
				local localAction = tool:GetAttribute("LocalItemActionStarted")
				if localAction and (not action or localAction > action - .2) then
					action, kind = localAction, tool:GetAttribute("LocalItemActionKind")
				end
				local camera = workspace.CurrentCamera
				if camera then
					local centered = Theme.IsMobile() or UIS.PreferredInput == Enum.PreferredInput.Gamepad
					aim = centered and camera.CFrame.LookVector or mouse.UnitRay.Direction
				end
			end
			if player:GetAttribute("IsDead") or (RS:GetAttribute("WorldShifting") and not player:GetAttribute("InteriorId")) then started = nil end
			state:Update(dt, now, started, action, kind, aim, Settings.Get("ReducedMotion") == true)
		end
	end
end)
