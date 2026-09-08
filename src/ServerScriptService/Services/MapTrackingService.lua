-- Player attributes remain replicated when distant characters stream out.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Service = {}

function Service:UpdatePlayer(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local available = root and humanoid and humanoid.Health > 0
		and not player:GetAttribute("IsDead")
		and not player:GetAttribute("WorldPlayerLoading")
		and not player:GetAttribute("WorldPlayerRestoring")
		and not ReplicatedStorage:GetAttribute("WorldRestoring")
	local position = available and root.Position or nil
	local look = available and root.CFrame.LookVector or nil
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
