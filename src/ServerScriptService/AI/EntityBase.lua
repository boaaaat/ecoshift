-- EntityBase.lua
-- Base class for AI-controlled entities (monsters/animals).
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")

local EntityBase = {}
EntityBase.__index = EntityBase

local function findRoot(model)
	if model.PrimaryPart then return model.PrimaryPart end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp then return hrp end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			return d
		end
	end
	return nil
end

local function findHumanoid(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then return hum end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Humanoid") then
			return d
		end
	end
	return nil
end

function EntityBase.new(model, config)
	local self = setmetatable({}, EntityBase)
	self.Model = model
	self.Config = config or {}
	self.Humanoid = findHumanoid(model)
	self.Root = findRoot(model)
	self.Target = nil
	self.NextAttack = 0
	self.NextRepath = 0
	self.Waypoints = nil
	self.WaypointIndex = 0
	self.LastHealth = self.Humanoid and self.Humanoid.Health or nil
	self.LastPos = self.Root and self.Root.Position or nil
	self.StuckTime = 0
	self._moveConn = nil
	self._lastMovePos = nil
	self._lastMoveTime = 0
	self._lastDirectPos = nil
	self._lastDirectTime = 0
	self._lastPathTarget = nil
	self._lastPos = self.Root and self.Root.Position or nil
	self._stuckTime = 0
	self:SetSpeed(self.Config.Speed)
	return self
end

function EntityBase:IsAlive()
	if not self.Model or not self.Model.Parent then return false end
	if self.Humanoid then
		return self.Humanoid.Health > 0
	end
	return true
end

function EntityBase:SetSpeed(speed)
	if self.Humanoid and speed and speed > 0 then
		self.Humanoid.WalkSpeed = speed
	end
end

function EntityBase:GetMoveSpeed()
	return tonumber(self.Config.Speed) or 0
end

function EntityBase:GetDetection()
	return self.Config.DetectionAngle or 120,
		self.Config.DetectionDistance or 80,
		self.Config.AutoDetectRadius or 10
end

function EntityBase:CanDetectTarget(targetChar)
	if not self.Root or not targetChar then return false end
	local hrp = targetChar:FindFirstChild("HumanoidRootPart")
	local hum = targetChar:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return false end
	local angle, distMax, autoRadius = self:GetDetection()
	angle = math.clamp(tonumber(angle) or 0, 0, 360)
	distMax = math.max(0, tonumber(distMax) or 0)
	autoRadius = math.max(0, tonumber(autoRadius) or 0)
	local dir = hrp.Position - self.Root.Position
	local dist = dir.Magnitude
	if dist <= autoRadius then
		return true, dist
	end
	if distMax > 0 and dist <= distMax then
		if dist == 0 then
			return true, dist
		end
		if angle >= 360 then
			return true, dist
		end
		local look = self.Root.CFrame.LookVector
		local dot = look:Dot(dir.Unit)
		local deg = math.deg(math.acos(math.clamp(dot, -1, 1)))
		if deg <= angle * 0.5 then
			return true, dist
		end
	end
	return false, dist
end

function EntityBase:DealDamageToCurrentTarget(amount, dmgType)
	local dmg = math.max(0, tonumber(amount) or 0)
	if dmg <= 0 then
		return false
	end
	local targetChar = self.Target and self.Target.Character
	local hum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return false
	end
	-- Recheck at damage time; attack subclasses must never strike through a
	-- shelter door that closed after targeting or an earlier attack animation.
	if not self:HasLineOfSight(targetChar) then return false end
	if _G.Ecoshift and type(_G.Ecoshift.ApplyDamage) == "function" then
		_G.Ecoshift.ApplyDamage(self.Model, targetChar, dmg, dmgType or "Melee")
	else
		require(script.Parent.Parent.Services.CombatService):ApplyDamage(self.Model, targetChar, dmg, dmgType or "Melee")
	end
	return true
end

function EntityBase:HasLineOfSight(targetChar)
	if not self.Root or not targetChar then return false end
	local hrp = targetChar:FindFirstChild("HumanoidRootPart")
	local hum = targetChar:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return false end
	local origin = self.Root.Position + Vector3.new(0, 1.5, 0)
	local dir = hrp.Position - origin
	if dir.Magnitude <= 0 then return true end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.Model }
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(origin, dir, params)
	if not hit then
		return true
	end
	return hit.Instance and hit.Instance:IsDescendantOf(targetChar)
end

function EntityBase:_directJumpCheck(targetChar)
	if not self.Root or not self.Humanoid then return end
	local dist = tonumber(self.Config.DirectJumpCheckDistance) or 3
	if dist <= 0 then return end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.Model }
	local dir = self.Root.CFrame.LookVector * dist

	local function hitObstacle(origin)
		local hit = Workspace:Raycast(origin, dir, params)
		if not hit then return false end
		if targetChar and hit.Instance and hit.Instance:IsDescendantOf(targetChar) then
			return false
		end
		return true
	end

	local originLow = self.Root.Position + Vector3.new(0, 0.5, 0)
	local originMid = self.Root.Position + Vector3.new(0, 1.5, 0)
	if hitObstacle(originLow) or hitObstacle(originMid) then
		self.Humanoid.Jump = true
	end
end

local function weaponPower(plr)
	if not plr or not plr.Character then return 0 end
	local tool = plr.Character:FindFirstChildOfClass("Tool")
	if not tool then
		local backpack = plr:FindFirstChildOfClass("Backpack")
		tool = backpack and backpack:FindFirstChildOfClass("Tool") or nil
	end
	if not tool then return 0 end
	local dmg = tool:GetAttribute("Damage") or tool:GetAttribute("HarvestDamage")
	if typeof(dmg) == "number" then return dmg end
	local child = tool:FindFirstChild("Damage") or tool:FindFirstChild("HarvestDamage")
	if child and child:IsA("ValueBase") and typeof(child.Value) == "number" then
		return child.Value
	end
	return 0
end

function EntityBase:ScoreTarget(plr, dist)
	local priority = self.Config.PlayerPriority or "LowHealth"
	if type(priority) ~= "string" then priority = "LowHealth" end
	local role = plr:GetAttribute("Role")
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	local hpPct = (hum and hum.MaxHealth > 0) and (hum.Health / hum.MaxHealth) or 1

	local base = 0
	local priorityLower = string.lower(priority)
	if priorityLower == "lowhealth" then
		base = 1 - hpPct
	elseif priorityLower == "highhealth" then
		base = hpPct
	elseif priorityLower == "strongestweapon" then
		base = weaponPower(plr)
	elseif priorityLower == "weakestweapon" then
		base = -weaponPower(plr)
	elseif priorityLower == "closest" then
		base = 0
	elseif string.find(priorityLower, "role") then
		local roleName = self.Config.TargetRole or priority:match("[Rr]ole:?%s*(.+)")
		if roleName and role == roleName then
			base = 1
		else
			base = 0
		end
	else
		-- Treat unknown strings as role names
		if role and role == priority then
			base = 1
		end
	end

	local score = base * 1000 - (dist or 0)
	return score
end

function EntityBase:AcquireTarget()
	local best, bestScore = nil, -1e9
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if char and char.Parent then
			local canSee, dist = self:CanDetectTarget(char)
			if canSee then
				local score = self:ScoreTarget(plr, dist)
				if score > bestScore then
					bestScore = score
					best = plr
				end
			end
		end
	end
	self.Target = best
	return best
end

function EntityBase:IsTargetValid()
	local plr = self.Target
	if not plr or not plr.Character then return false end
	local hum = plr.Character:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0
end

function EntityBase:InAttackRange()
	if not self.Target or not self.Root then return false end
	local hrp = self.Target.Character and self.Target.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	local range = self.Config.AttackRange or 4
	return (hrp.Position - self.Root.Position).Magnitude <= range
end

function EntityBase:AttackTarget()
	if not self:InAttackRange() or not self:HasLineOfSight(self.Target and self.Target.Character) then return end
	local now = os.clock()
	if now < (self.NextAttack or 0) then return end
	self.NextAttack = now + (self.Config.AttackCooldown or 1.2)
	local dmg = math.max(0, tonumber(self.Config.Damage) or 0)
	if dmg <= 0 then return end
	self:DealDamageToCurrentTarget(dmg, "Melee")
end

function EntityBase:MoveTo(position)
	if not self.Humanoid or not self.Root then return end
	self.Humanoid:MoveTo(position)
end

function EntityBase:_ensureMoveConn()
	if self._moveConn or not self.Humanoid then return end
	self._moveConn = self.Humanoid.MoveToFinished:Connect(function(reached)
		if not self.Waypoints or not self.Humanoid then return end
		if reached then
			self.WaypointIndex += 1
			if not self.Waypoints[self.WaypointIndex] then
				self.Waypoints = nil
				self.WaypointIndex = 0
				self._lastMovePos = nil
				return
			end
		end
		self:_stepToWaypoint(true)
	end)
end

function EntityBase:_stepToWaypoint(force)
	if not self.Waypoints or not self.Humanoid then return end
	local wp = self.Waypoints[self.WaypointIndex]
	if not wp then return end
	if wp.Action == Enum.PathWaypointAction.Jump then
		self.Humanoid.Jump = true
	end
	local now = os.clock()
	local shouldMove = force == true
	if not shouldMove then
		local last = self._lastMovePos
		if not last then
			shouldMove = true
		elseif (wp.Position - last).Magnitude > 1 then
			shouldMove = true
		elseif now - (self._lastMoveTime or 0) > 0.4 then
			shouldMove = true
		end
	end
	if shouldMove then
		self._lastMovePos = wp.Position
		self._lastMoveTime = now
		self.Humanoid:MoveTo(wp.Position)
	end
end

function EntityBase:_directMove(targetPos)
	if not self.Humanoid then return end
	local now = os.clock()
	if self._lastDirectPos then
		if (targetPos - self._lastDirectPos).Magnitude < 2 and now - (self._lastDirectTime or 0) < 0.5 then
			return
		end
	end
	self._lastDirectPos = targetPos
	self._lastDirectTime = now
	self.Humanoid:MoveTo(targetPos)
end

function EntityBase:UpdatePath(targetPos)
	if not self.Root or not self.Humanoid then return end
	local now = os.clock()
	local repathInterval = self.Config.RepathInterval or 1.0
	local repathDistance = self.Config.RepathDistance or 8
	local usePath = self.Config.UsePathfinding
	if usePath == nil then usePath = true end
	if not usePath then
		self:_directMove(targetPos)
		return
	end
	local targetMoved = false
	if self._lastPathTarget then
		targetMoved = (targetPos - self._lastPathTarget).Magnitude >= repathDistance
	end
	if not targetMoved and self.Waypoints and self.WaypointIndex > 0 then
		return
	end
	if targetMoved and now < (self.NextRepath or 0) and self.Waypoints and self.WaypointIndex > 0 then
		return
	end
	if now < (self.NextRepath or 0) then
		if not self.Waypoints then self:_directMove(targetPos) end
		return
	end
	self.NextRepath = now + repathInterval
	local path = PathfindingService:CreatePath({
		AgentRadius = self.Config.AgentRadius or 2,
		AgentHeight = self.Config.AgentHeight or 5,
		AgentCanJump = self.Config.AgentCanJump ~= false,
	})
	local ok = pcall(function()
		path:ComputeAsync(self.Root.Position, targetPos)
	end)
	if not self:IsAlive() then return end
	if not ok or path.Status ~= Enum.PathStatus.Success then
		self.Waypoints = nil
		self.WaypointIndex = 0
		self:_directMove(targetPos)
		return
	end
	self.Waypoints = path:GetWaypoints()
	self._lastPathTarget = targetPos
	self.WaypointIndex = 1
	if self.Waypoints[1] and self.Waypoints[1].Action ~= Enum.PathWaypointAction.Jump and self.Waypoints[2] then
		self.WaypointIndex = 2
	end
	self._lastMovePos = nil
	self:_ensureMoveConn()
	self:_stepToWaypoint(true)
end

function EntityBase:FollowPath()
	if not self.Waypoints or not self.Root or not self.Humanoid then return end
	self:_stepToWaypoint(false)
end

function EntityBase:Step(dt)
	if not self:IsAlive() then return end
	if not self.Root then return end
	self:SetSpeed(self:GetMoveSpeed())

	-- Stuck detection (works for direct + path movement)
	if self._lastPos and self:IsTargetValid() and not self:InAttackRange() then
		local moved = (self.Root.Position - self._lastPos).Magnitude
		local minMove = tonumber(self.Config.StuckMinMove) or 0.08
		local stuckThreshold = tonumber(self.Config.StuckJumpTime) or 0.1
		if moved <= minMove then
			self._stuckTime += dt
			if self._stuckTime >= stuckThreshold then
				if self.Humanoid then
					self.Humanoid.Jump = true
				end
				self._stuckTime = 0
			end
		else
			self._stuckTime = 0
		end
	else
		self._stuckTime = 0
	end
	self._lastPos = self.Root.Position

	if not self:IsTargetValid() then
		self:AcquireTarget()
	end

	if self.Target and self.Target.Character then
		local targetPos = self.Target.Character:FindFirstChild("HumanoidRootPart") and self.Target.Character.HumanoidRootPart.Position
		if targetPos then
			if self:InAttackRange() and self:HasLineOfSight(self.Target.Character) then
				self:AttackTarget()
			else
				if self:HasLineOfSight(self.Target.Character) then
					self.Waypoints = nil
					self.WaypointIndex = 0
					self:_directMove(targetPos)
					self:_directJumpCheck(self.Target.Character)
				else
					self:UpdatePath(targetPos)
					self:FollowPath()
				end
			end
		end
	end
end

return EntityBase
