-- Player attributes remain replicated when distant characters stream out.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DeathService = require(script.Parent.DeathService)
local Service = {}

function Service:UpdatePlayer(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local available = not player:GetAttribute("WorldPlayerLoading")
		and not player:GetAttribute("WorldPlayerRestoring")
		and not ReplicatedStorage:GetAttribute("WorldRestoring")
	local position, look
	if available then
		if player:GetAttribute("IsDead") then
			-- The character may be removed or hidden after death. The body's
			-- authoritative pose remains available even when it streams out.
			position = DeathService:GetDeathPosition(player)
			local ragdoll = DeathService:GetRagdoll(player)
			if position then
				look = ragdoll and ragdoll.Parent and ragdoll:GetPivot().LookVector or Vector3.new(0, 0, -1)
			end
		elseif root and humanoid and humanoid.Health > 0 then
			position, look = root.Position, root.CFrame.LookVector
		end
	end
	if player:GetAttribute("MapPosition") ~= position then player:SetAttribute("MapPosition", position) end
	if player:GetAttribute("MapLookVector") ~= look then player:SetAttribute("MapLookVector", look) end
end

function Service:Init()
	if self._connection then return end
	local elapsed = 0
	self._connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < .1 then return end
		elapsed = 0
		for _, player in ipairs(Players:GetPlayers()) do self:UpdatePlayer(player) end
	end)
end

return Service
