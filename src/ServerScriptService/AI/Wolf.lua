-- Wolf.lua
-- Pack-hunting monster with mild wandering when idle.
local Workspace = game:GetService("Workspace")
local Monster = require(script.Parent.Monster)

local Wolf = {}
Wolf.__index = Wolf
setmetatable(Wolf, Monster)

function Wolf.new(model, config)
	local self = Monster.new(model, config)
	setmetatable(self, Wolf)
	self.HomePos = self.Root and self.Root.Position or Vector3.zero
	self.NextWander = 0
	self.WanderTarget = nil
	self.PackCount = 0
	return self
end

function Wolf:_countPack()
	local packRadius = tonumber(self.Config.PackRadius) or 30
	local enemiesFolder = Workspace:FindFirstChild("Enemies")
	if not enemiesFolder or not self.Root then return 0 end
	local count = 0
	for _, other in ipairs(enemiesFolder:GetChildren()) do
		if other ~= self.Model and other:IsA("Model") then
			if other:GetAttribute("EntityId") == (self.Config.EntityId or "Wolf") then
				local root = other.PrimaryPart or other:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - self.Root.Position).Magnitude <= packRadius then
					count += 1
				end
			end
		end
	end
	return count
end

function Wolf:_pickWanderTarget()
	local radius = tonumber(self.Config.WanderRadius) or 25
	local angle = math.random() * math.pi * 2
	local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	self.WanderTarget = (self.HomePos or (self.Root and self.Root.Position) or Vector3.zero) + offset
	self.NextWander = os.clock() + (tonumber(self.Config.WanderInterval) or 2.5)
end

function Wolf:AttackTarget()
	local now = os.clock()
	local baseCd = tonumber(self.Config.AttackCooldown) or 1.1
	local packBoost = tonumber(self.Config.PackAttackBoost) or 0
	local cd = baseCd
	if self.PackCount > 0 then
		cd = math.max(0.2, baseCd * (1 - packBoost))
	end
	if now < (self.NextAttack or 0) then return end
	self.NextAttack = now + cd

	local dmg = math.max(0, tonumber(self.Config.Damage) or 0)
	if dmg <= 0 then return end
	self:DealDamageToCurrentTarget(dmg, "Melee")
end

function Wolf:GetMoveSpeed()
	local baseSpeed = tonumber(self.Config.Speed) or 12
	local packSpeedBoost = tonumber(self.Config.PackSpeedBoost) or 0
	if self.PackCount > 0 then
		return baseSpeed * (1 + packSpeedBoost)
	end
	return baseSpeed
end

function Wolf:Step(dt)
	if not self:IsAlive() or not self.Root then return end

	self.PackCount = self:_countPack()

	if not self:IsTargetValid() then
		self:AcquireTarget()
	end

	if not self.Target then
		local now = os.clock()
		if not self.WanderTarget or now >= self.NextWander then
			self:_pickWanderTarget()
		end
		if self.WanderTarget then
			self:UpdatePath(self.WanderTarget)
			self:FollowPath()
			if (self.WanderTarget - self.Root.Position).Magnitude <= 2 then
				self.WanderTarget = nil
			end
		end
		return
	end

	Monster.Step(self, dt)
end

return Wolf
