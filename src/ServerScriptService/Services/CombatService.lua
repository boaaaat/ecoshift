-- CombatService.lua (expanded)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local WeaponFactory = require(ReplicatedStorage.Shared.Weapons.WeaponFactory)
local WeaponUtil = require(ReplicatedStorage.Shared.Weapons.WeaponUtil)
local StatsService = require(script.Parent.StatsService)
local GameStateService = require(script.Parent.GameStateService)

-- Lazy-loaded to avoid circular dependency
local DeathService = nil
local function getDeathService()
	if not DeathService then
		local success, result = pcall(function()
			return require(script.Parent.DeathService)
		end)
		if success then
			DeathService = result
		end
	end
	return DeathService
end

local CombatService = {}
-- OPTIMIZED: Lazy-load remotes instead of blocking at module load
CombatService._remotesFolder = nil
CombatService._remoteDamage = nil
CombatService._remoteAction = nil
CombatService._remoteFeedback = nil

CombatService._lastUse = setmetatable({}, { __mode = "k" }) -- [tool] = time
CombatService._chargeStart = setmetatable({}, { __mode = "k" }) -- [player] = { Tool, Started }
CombatService._blocking = setmetatable({}, { __mode = "k" }) -- [player] = tool
local COMBAT_FEEDBACK_RANGE = 180
local TOOL_ORIGIN_NAMES = { "MuzzleAttachment", "Muzzle", "Barrel", "Tip" }

local function ensureRemotes(self)
	if self._remoteDamage and self._remoteAction and self._remoteFeedback then return end
	self._remotesFolder = Util.GetDescendant(Config.Paths.Remotes) 
		or Util.WaitForDescendant(Config.Paths.Remotes, 5)
	if self._remotesFolder then
		self._remoteDamage = Util.GetRemote(self._remotesFolder, Config.RemoteNames.Damage)
		self._remoteAction = Util.GetRemote(self._remotesFolder, Config.RemoteNames.CombatAction)
		self._remoteFeedback = Util.GetRemote(self._remotesFolder, Config.RemoteNames.HarvestFeedback)
		if not self._remoteFeedback then
			self._remoteFeedback = Instance.new("RemoteEvent")
			self._remoteFeedback.Name = Config.RemoteNames.HarvestFeedback
			self._remoteFeedback.Parent = self._remotesFolder
		end
	end
end

-- rate limit per attacker (id -> lastTime)
local _lastHit = setmetatable({}, {__mode="k"}) -- weak keys by player instance

local function canHit(plr)
	local now = os.clock()
	local last = _lastHit[plr] or 0
	if now - last < 0.06 then return false end -- ~16/s cap
	_lastHit[plr] = now
	return true
end

local function fireCombatFeedbackNear(position, remote, payload)
	if not remote or typeof(position) ~= "Vector3" then
		return
	end
	local maxDistSq = COMBAT_FEEDBACK_RANGE * COMBAT_FEEDBACK_RANGE
	for _, plr in ipairs(Players:GetPlayers()) do
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local delta = root.Position - position
			if delta:Dot(delta) <= maxDistSq then
				remote:FireClient(plr, payload)
			end
		end
	end
end

local function distanceOK(plr, target, maxDist)
	maxDist = maxDist or 150
	if typeof(target) ~= "Instance" or not target:IsA("Model") then return false end
	local hrp = plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	local tp = target.PrimaryPart or target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildWhichIsA("BasePart")
	if not hrp or not tp then return false end
	return (hrp.Position - tp.Position).Magnitude <= maxDist
end

local function getHealthValue(target)
	if not target or not target.Parent then return nil end
	local health = target:FindFirstChild("Health", true)
	if health and health:IsA("ValueBase") and typeof(health.Value) == "number" then
		return health
	end
	return nil
end

local function isTaggedCombatTarget(target)
	if not target or not target.Parent then return false end
	return CollectionService:HasTag(target, "Monster") or CollectionService:HasTag(target, "Animal")
end

local function getHumanoidOrHealth(target, isPlayerTarget)
	if not target or not target.Parent then return nil end
	local hum = target:FindFirstChildWhichIsA("Humanoid")
	if hum and (isPlayerTarget or isTaggedCombatTarget(target)) then
		return hum
	end
	local health = getHealthValue(target)
	if health and isTaggedCombatTarget(target) then return health end
	if hum then return hum end
	return nil
end

local function getTargetPosition(target)
	if not target then return nil end
	if target:IsA("BasePart") then
		return target.Position
	end
	if target:IsA("Model") then
		local root = target.PrimaryPart or target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildWhichIsA("BasePart")
		if root then return root.Position end
		return target:GetPivot().Position
	end
	return nil
end

local function getMaxHealthFromTarget(target, fallback)
	if not target or not target:IsA("Model") then
		return fallback
	end
	local maxAttr = target:GetAttribute("MaxHealth") or target:GetAttribute("_MaxHealth")
	if typeof(maxAttr) == "number" then return maxAttr end
	local child = target:FindFirstChild("MaxHealth") or target:FindFirstChild("_MaxHealth")
	if child and child:IsA("ValueBase") and typeof(child.Value) == "number" then
		return child.Value
	end
	return fallback
end

function CombatService:ApplyDamage(attacker, target, amount, dmgType)
	if GameStateService:IsGameOver() then
		return
	end
	amount = tonumber(amount) or 0
	if amount ~= amount or amount <= 0 or amount > 2000 then return end
	if typeof(target) ~= "Instance" or not target:IsA("Model") or not target:IsDescendantOf(Workspace) then return end

	-- attacker can be Player or Model
	local attackerPlayer = attacker
	if typeof(attacker) == "Instance" and attacker:IsA("Model") then
		attackerPlayer = Players:GetPlayerFromCharacter(attacker)
	end
	if attackerPlayer then
		local hum = attackerPlayer.Character and attackerPlayer.Character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 or attackerPlayer:GetAttribute("IsDead") then return end
		if dmgType ~= "ClassTurret" and not canHit(attackerPlayer) then return end
		if dmgType ~= "ClassTurret" and not distanceOK(attackerPlayer, target, 175) then return end
		local combatMult = tonumber(attackerPlayer:GetAttribute("Role_Combat")) or 1.0
		amount = amount * combatMult
	end

	-- Team/FF logic hook (optional): prevent friendly fire
	local atkTeam = attackerPlayer and attackerPlayer.Team or nil
	local tgtPlr = Players:GetPlayerFromCharacter(target)
	if tgtPlr and workspace:GetAttribute("WorldType") == "Creative" and tgtPlr:GetAttribute("CreativeMode")
		and tgtPlr:GetAttribute("CreativeInvincible") then return end
	if tgtPlr and atkTeam and tgtPlr.Team == atkTeam then
		return
	end

	if attackerPlayer and not tgtPlr then
		local bonus = require(script.Parent.ClassAbilityService):GetMarkedBonus(target)
		amount *= 1 + bonus
		target:SetAttribute("LastAttackerUserId", attackerPlayer.UserId)
		if dmgType~="ClassTurret" then require(script.Parent.ExpeditionRewardsService):RecordActivity(attackerPlayer) end
	elseif tgtPlr and typeof(attacker)=="Instance" and attacker:IsA("Model") and game:GetService("CollectionService"):HasTag(attacker,"Monster") then
		amount *= 1 - require(script.Parent.ClassAbilityService):GetMonsterReduction(tgtPlr)
	end

	-- Health component contract:
	--  - Either a NumberValue "Health" under the target Model
	--  - Or a Humanoid if target is a character
	local healthValue = getHumanoidOrHealth(target, tgtPlr ~= nil)
	if not healthValue then return end
	local oldHealth = nil
	if healthValue:IsA("Humanoid") then
		oldHealth = healthValue.Health
	elseif healthValue:IsA("ValueBase") then
		oldHealth = healthValue.Value
	end
	if typeof(oldHealth) ~= "number" then return end

	-- Shield block check for player targets
	if tgtPlr and self._blocking[tgtPlr] then
		local shieldTool = self._blocking[tgtPlr]
		if shieldTool and tgtPlr.Character and shieldTool.Parent == tgtPlr.Character then
			local blockPercent = WeaponUtil.GetNumber(shieldTool, "BlockPercent", 0)
			local durability = WeaponUtil.GetNumber(shieldTool, "Durability", 0)
			blockPercent = math.clamp(blockPercent, 0, 0.95)
			if blockPercent > 0 and durability > 0 then
				local blocked = amount * blockPercent
				amount = math.max(0, amount - blocked)
				-- reduce durability by blocked amount
				local remaining = math.max(0, durability - blocked)
				if shieldTool:GetAttribute("Durability") ~= nil then
					shieldTool:SetAttribute("Durability", remaining)
				end
				local child = shieldTool:FindFirstChild("Durability")
				if child and (child:IsA("NumberValue") or child:IsA("IntValue")) then
					child.Value = remaining
				elseif child and child:IsA("StringValue") then
					child.Value = tostring(remaining)
				end
				if remaining <= 0 then
					self._blocking[tgtPlr] = nil
				end
			end
		else
			self._blocking[tgtPlr] = nil
		end
	end

	-- Armor reduction (percent) for player targets
	if tgtPlr then
		local armor = StatsService and StatsService.GetStat and StatsService:GetStat(tgtPlr, "Armor") or 0
		if armor and armor > 0 then
			local pct = math.clamp(tonumber(armor) or 0, 0, 100) / 100
			amount = math.max(0, amount * (1 - pct))
		end
	end

	-- Optional type-based resistances via attributes (Res_Pierce, Res_Fire...)
	if typeof(healthValue) == "Instance" then
		local host = target
		local resAttr = ("Res_%s"):format(tostring(dmgType or ""))
		local resist = tonumber(host:GetAttribute(resAttr)) or 0
		if resist ~= 0 then
			amount = math.max(0, amount * (1 - math.clamp(resist, -0.9, 0.9)))
		end
	end

	-- apply damage
	if healthValue:IsA("Humanoid") then
		-- Humanoid - DeathService hooks HealthChanged and handles death automatically
		healthValue:TakeDamage(amount)
	elseif healthValue:IsA("ValueBase") then
		healthValue.Value = math.max(0, healthValue.Value - amount)
	else
		return
	end

	-- Combat feedback (damage numbers + health bar) for non-player targets
	if not tgtPlr then
		ensureRemotes(self)
		if self._remoteFeedback then
			local pos = getTargetPosition(target)
			if pos then
				local newHealth = nil
				local maxHealth = nil
				if healthValue:IsA("Humanoid") then
					newHealth = healthValue.Health
					maxHealth = healthValue.MaxHealth or math.max(oldHealth, newHealth)
				elseif healthValue:IsA("ValueBase") then
					newHealth = healthValue.Value
					maxHealth = getMaxHealthFromTarget(target, math.max(oldHealth, newHealth))
				end
				if typeof(newHealth) ~= "number" then return end
				if typeof(maxHealth) ~= "number" then maxHealth = math.max(oldHealth, newHealth) end
				fireCombatFeedbackNear(pos, self._remoteFeedback, {
					Node = target,
					Position = pos,
					Damage = math.floor(amount),
					Health = newHealth,
					MaxHealth = maxHealth,
					Destroyed = newHealth <= 0,
				})
			end
		end
	end
end

function CombatService:OnDamageRequest(attacker, target, amount, dmgType)
	if not attacker or not attacker.Character then return end
	self:ApplyDamage(attacker, target, amount, dmgType)
end

local function getEquippedTool(plr)
	if not plr or not plr.Character then return nil end
	for _, child in ipairs(plr.Character:GetChildren()) do
		if child:IsA("Tool") then return child end
	end
	return nil
end

local function hasToolType(tool)
	if not tool or not tool:IsA("Tool") then return false end
	local weaponType = WeaponUtil.GetType(tool)
	if weaponType and weaponType ~= "" then
		return false
	end
	local attr = tool:GetAttribute("ToolType")
	if typeof(attr) == "string" and attr ~= "" then
		return true
	end
	local child = tool:FindFirstChild("ToolType")
	if child and child:IsA("ValueBase") then
		if typeof(child.Value) == "string" then
			return child.Value ~= ""
		end
		return tostring(child.Value) ~= ""
	end
	return false
end

local function getRoot(model)
	if not model then return nil end
	return model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
end

local function getToolOrigin(plr, tool)
	local char = plr and plr.Character
	if tool then
		for _, name in ipairs(TOOL_ORIGIN_NAMES) do
			local node = tool:FindFirstChild(name, true)
			if node then
				if node:IsA("Attachment") then
					return node.WorldPosition
				end
				if node:IsA("BasePart") then
					return node.Position
				end
			end
		end
		local handle = tool:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			return handle.Position
		end
	end
	if char then
		local head = char:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			return head.Position
		end
		local root = getRoot(char)
		if root then
			return root.Position
		end
	end
	return nil
end

local function getValidatedAimDirection(data)
	local dir = data and data.Dir
	if typeof(dir) ~= "Vector3" then
		return nil
	end
	if dir.X ~= dir.X or dir.Y ~= dir.Y or dir.Z ~= dir.Z
		or dir.Magnitude == math.huge or dir.Magnitude < 0.001 then
		return nil
	end
	return dir.Unit
end

local function setToolAmmo(tool, value)
	if not tool or not tool:IsA("Tool") then return end
	local clamped = math.max(0, math.floor(tonumber(value) or 0))

	if tool:GetAttribute("Ammo") ~= nil then
		tool:SetAttribute("Ammo", clamped)
	end

	local ammoObj = tool:FindFirstChild("Ammo")
	if ammoObj and ammoObj:IsA("ValueBase") then
		if typeof(ammoObj.Value) == "number" then
			ammoObj.Value = clamped
		elseif ammoObj:IsA("StringValue") then
			ammoObj.Value = tostring(clamped)
		end
	end
end

local function consumeToolAmmo(tool, amount)
	local current = WeaponUtil.GetNumber(tool, "Ammo", 0)
	local delta = tonumber(amount) or 0
	setToolAmmo(tool, current - delta)
end

local function raycastFromPlayer(plr, origin, dir, maxRange)
	local char = plr.Character
	if not char or typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" then return nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local direction = dir * maxRange
	local res = Workspace:Raycast(origin, direction, params)
	return res
end

function CombatService:_canUseTool(tool, cooldown, tolerateJitter)
	if not tool then return false end
	local now = os.clock()
	local last = self._lastUse[tool] or 0
	local tolerance = tolerateJitter and math.min(0.05, cooldown * 0.1) or 0
	if now - last < cooldown - tolerance then return false end
	-- Keep the scheduled cooldown when accepting an early packet, so tolerance
	-- cannot increase sustained attack speed by sending requests faster.
	self._lastUse[tool] = math.max(now, last + cooldown)
	return true
end

function CombatService:_handleSword(plr, tool, weapon, data)
	if not self:_canUseTool(tool, weapon:GetCooldown(), true) then return end
	local body = getRoot(plr.Character)
	if not body then return end
	-- Touch is an untrusted aim-assist hint, never a client-selected radius.
	-- Even a spoofed hint is restricted to these same small server bounds.
	local touch = data and data.Touch == true
	local reach = math.clamp(weapon:GetRange() + 3.5 + (touch and 0.75 or 0), 4, 14)
	local halfWidth = touch and 3.25 or 2.5
	local aim = getValidatedAimDirection(data) or body.CFrame.LookVector
	local flatAim = Vector3.new(aim.X, 0, aim.Z)
	if flatAim.Magnitude < 0.1 then
		local facing = body.CFrame.LookVector
		flatAim = Vector3.new(facing.X, 0, facing.Z)
	end
	if flatAim.Magnitude < 0.001 then return end
	local swing = CFrame.lookAt(body.Position, body.Position + flatAim.Unit)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { plr.Character }
	local parts = Workspace:GetPartBoundsInBox(swing * CFrame.new(0, 0, -reach * 0.5), Vector3.new(halfWidth * 2, 9, reach), params)
	local seen, bestTarget, bestScore = {}, nil, math.huge
	local obstructionParams = RaycastParams.new()
	obstructionParams.FilterType = Enum.RaycastFilterType.Exclude
	obstructionParams.FilterDescendantsInstances = { plr.Character }
	-- Decorative leaves and noncolliding weapon art are not physical cover.
	obstructionParams.RespectCanCollide = true
	for _, part in ipairs(parts) do
		local target = part
		while target and target ~= Workspace do
			if target:IsA("Model") and isTaggedCombatTarget(target) then break end
			target = target.Parent
		end
		if not target or target == Workspace or seen[target] then continue end
		seen[target] = true
		local health = getHumanoidOrHealth(target, false)
		local targetRoot = getRoot(target)
		if not health or not targetRoot then continue end
		local hp = health:IsA("Humanoid") and health.Health or health.Value
		if hp <= 0 then continue end
		local relative = swing:PointToObjectSpace(targetRoot.Position)
		local forward = -relative.Z
		local flatDistance = Vector2.new(relative.X, relative.Z).Magnitude
		if forward < 0 or flatDistance > reach or math.abs(relative.X) > halfWidth or math.abs(relative.Y) > 4.5 then continue end
		local delta = targetRoot.Position - body.Position
		local obstruction = delta.Magnitude > 0 and Workspace:Raycast(body.Position, delta, obstructionParams)
		if obstruction and not obstruction.Instance:IsDescendantOf(target) then continue end
		-- Prefer a directly aimed target, otherwise the nearest target in the swing.
		local score = flatDistance + math.abs(relative.X) * 0.5
		if data and data.Target == target then score -= 2 end
		if score < bestScore then bestTarget, bestScore = target, score end
	end
	if bestTarget then self:ApplyDamage(plr, bestTarget, weapon:GetDamage(), "Melee") end
end

function CombatService:_handleGun(plr, tool, weapon, data)
	local cooldown = weapon:GetCooldown()
	if not self:_canUseTool(tool, cooldown) then return end
	local ammo = weapon:GetAmmo()
	if ammo <= 0 then return end
	local origin = getToolOrigin(plr, tool)
	local dir = getValidatedAimDirection(data)
	if not origin or not dir then return end
	consumeToolAmmo(tool, 1)
	local maxRange = weapon:GetNumber("Range", 200)
	local hit = raycastFromPlayer(plr, origin, dir, maxRange)
	if hit and hit.Instance then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if model then
			self:ApplyDamage(plr, model, weapon:GetDamage(), "Gun")
		end
	end
end

function CombatService:_handleBow(plr, tool, weapon, data)
	local now = os.clock()
	local charge = self._chargeStart[plr]
	self._chargeStart[plr] = nil
	if not charge or charge.Tool ~= tool then return end
	local chargeTime = weapon:GetChargeTime()
	local ratio = math.clamp((now - charge.Started) / math.max(chargeTime, 0.1), 0, 1)
	local cooldown = math.max(chargeTime * 0.2, 0.2)
	if not self:_canUseTool(tool, cooldown) then return end

	local maxRange = weapon:GetRange()
	local origin = getToolOrigin(plr, tool)
	local dir = getValidatedAimDirection(data)
	if not origin or not dir then return end
	local hit = raycastFromPlayer(plr, origin, dir, maxRange)
	if hit and hit.Instance then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if model then
			self:ApplyDamage(plr, model, weapon:ComputeDamage(ratio), "Bow")
		end
	end
end

function CombatService:_handleThrowable(plr, tool, weapon, data)
	local cooldown = math.max(weapon:GetThrowTime(), 0.2)
	if not self:_canUseTool(tool, cooldown) then return end
	local origin = getToolOrigin(plr, tool)
	local dir = getValidatedAimDirection(data)
	if not origin or not dir then return end
	local maxRange = weapon:GetRange()
	local damage = weapon:GetDamage()
	local throwTime = weapon:GetThrowTime()
	task.delay(throwTime, function()
		local hit = raycastFromPlayer(plr, origin, dir, maxRange)
		if hit and hit.Instance then
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			if model then
				self:ApplyDamage(plr, model, damage, "Throwable")
			end
		end
	end)
end

function CombatService:_handleBlock(plr, tool, weapon, isBlocking)
	if isBlocking then
		self._blocking[plr] = tool
	else
		self._blocking[plr] = nil
	end
end

function CombatService:Bind()
	if self._bound then return end
	ensureRemotes(self)
	-- Security: client-authoritative damage requests are intentionally disabled.
	-- Damage must flow through validated CombatAction requests or server systems.

	if self._remoteAction then
		self._bound = true
		self._remoteAction.OnServerEvent:Connect(function(plr, action, data)
			if type(action) ~= "string" or (data ~= nil and type(data) ~= "table") then return end
			if action == "ChargeCancel" then
				self._chargeStart[plr] = nil
				return
			end
			if GameStateService:IsGameOver() then
				return
			end
			local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 or plr:GetAttribute("IsDead") then return end
			if action == "BlockEnd" then
				self._blocking[plr] = nil
				return
			end
			local tool = getEquippedTool(plr)
			if not tool then return end
			if hasToolType(tool) then
				-- Harvesting damage must never become combat damage. Only tools with
				-- an explicit server-authored combat profile can use this melee path.
				local damage = WeaponUtil.GetNumber(tool, "CombatDamage", 0)
				if action ~= "Attack" or damage <= 0 then return end
				if ReplicatedStorage:GetAttribute("WorldRestoring") or plr:GetAttribute("WorldPlayerRestoring")
					or plr:GetAttribute("WorldPlayerLoading") then return end
				local harvestWeapon = {
					GetDamage = function() return damage end,
					GetRange = function() return WeaponUtil.GetNumber(tool, "CombatRange", 6) end,
					GetCooldown = function() return math.max(0.1, WeaponUtil.GetNumber(tool, "CombatCooldown", 0.6)) end,
				}
				self:_handleSword(plr, tool, harvestWeapon, data)
				return
			end
			local weapon = WeaponFactory.Create(tool, plr)
			if not weapon then return end
			local wtype = weapon:GetType():lower()
			if wtype == "sword" or wtype == "swords" then
				if action == "Attack" then
					self:_handleSword(plr, tool, weapon, data)
				end
			elseif wtype == "gun" or wtype == "guns" then
				if action == "Fire" then
					self:_handleGun(plr, tool, weapon, data)
				end
			elseif wtype == "bow" or wtype == "bows" then
				if action == "ChargeStart" then
					local charge = self._chargeStart[plr]
					if not charge or charge.Tool ~= tool then
						self._chargeStart[plr] = { Tool = tool, Started = os.clock() }
					end
				elseif action == "ChargeRelease" then
					self:_handleBow(plr, tool, weapon, data)
				end
			elseif wtype == "throwable" or wtype == "throwables" then
				if action == "Throw" then
					self:_handleThrowable(plr, tool, weapon, data)
				end
			elseif wtype == "shield" or wtype == "shields" then
				if action == "BlockStart" then
					self:_handleBlock(plr, tool, weapon, true)
				elseif action == "BlockEnd" then
					self:_handleBlock(plr, tool, weapon, false)
				end
			end
		end)
	end

	_G.Ecoshift = _G.Ecoshift or {}
	_G.Ecoshift.ApplyDamage = function(attacker, target, amount, dmgType)
		CombatService:ApplyDamage(attacker, target, amount, dmgType)
	end
end

return CombatService
