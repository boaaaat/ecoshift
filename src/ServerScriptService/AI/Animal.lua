-- Animal.lua
-- Friendly animal AI (wander, flee when players get close).
local Players = game:GetService("Players")
local EntityBase = require(script.Parent.EntityBase)

local Animal = {}
Animal.__index = Animal
setmetatable(Animal, EntityBase)

function Animal.new(model, config)
	local self = EntityBase.new(model, config)
	setmetatable(self, Animal)
	self.HomePos = self.Root and self.Root.Position or Vector3.zero
	self.NextWander = 0
	self.WanderTarget = nil
	return self
end

function Animal:FindThreat()
	local closest, closestDist = nil, math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if char and char.Parent then
			local canSee, dist = self:CanDetectTarget(char)
			if canSee and dist < closestDist then
				closestDist = dist
				closest = plr
			end
		end
	end
	return closest, closestDist
end

function Animal:PickWanderTarget()
	local radius = tonumber(self.Config.WanderRadius) or 30
	local angle = math.random() * math.pi * 2
	local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	self.WanderTarget = (self.HomePos or (self.Root and self.Root.Position) or Vector3.zero) + offset
	self.NextWander = os.clock() + (tonumber(self.Config.WanderInterval) or 3)
end

function Animal:Step(dt)
	if not self:IsAlive() or not self.Root then return end

	local threat, dist = self:FindThreat()
	local fleeRadius = tonumber(self.Config.FleeDistance) or 20
	if threat and dist <= fleeRadius then
		local hrp = threat.Character and threat.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local dir = (self.Root.Position - hrp.Position)
			if dir.Magnitude < 1 then
				dir = Vector3.new(1, 0, 0)
			end
			local fleePos = self.Root.Position + dir.Unit * fleeRadius
			self:SetSpeed(self.Config.FleeSpeed or self.Config.Speed)
			self:UpdatePath(fleePos)
			self:FollowPath()
			return
		end
	end

	-- Wander
	self:SetSpeed(self.Config.Speed)
	local now = os.clock()
	if not self.WanderTarget or now >= self.NextWander then
		self:PickWanderTarget()
	end
	if self.WanderTarget then
		self:UpdatePath(self.WanderTarget)
		self:FollowPath()
		if (self.WanderTarget - self.Root.Position).Magnitude <= 2 then
			self.WanderTarget = nil
		end
	end
end

return Animal
