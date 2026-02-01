-- CombatService.lua (expanded)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local WeaponFactory = require(ReplicatedStorage.Shared.Weapons.WeaponFactory)
local WeaponUtil = require(ReplicatedStorage.Shared.Weapons.WeaponUtil)

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

CombatService._lastUse = setmetatable({}, { __mode = "k" }) -- [tool] = time
CombatService._chargeStart = setmetatable({}, { __mode = "k" }) -- [player] = time
CombatService._blocking = setmetatable({}, { __mode = "k" }) -- [player] = tool

local function ensureRemotes(self)
	if self._remoteDamage and self._remoteAction then return end
	self._remotesFolder = Util.GetDescendant(Config.Paths.Remotes) 
		or Util.WaitForDescendant(Config.Paths.Remotes, 5)
	if self._remotesFolder then
		self._remoteDamage = Util.GetRemote(self._remotesFolder, Config.RemoteNames.Damage)
		self._remoteAction = Util.GetRemote(self._remotesFolder, Config.RemoteNames.CombatAction)
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

local function distanceOK(plr, target, maxDist)
	maxDist = maxDist or 150
	local hrp = plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	local tp = target and target:IsA("Model") and target.PrimaryPart or target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildWhichIsA("BasePart")
	if not hrp or not tp then return false end
	return (hrp.Position - tp.Position).Magnitude <= maxDist
end

local function getHumanoidOrHealth(target)
	if not target or not target.Parent then return nil end
	if target:FindFirstChild("Health") and target.Health:IsA("NumberValue") then
		return target.Health
	end
	local hum = target:FindFirstChildWhichIsA("Humanoid")
	if hum then return hum end
	return nil
end

function CombatService:ApplyDamage(attacker, target, amount, dmgType)
	amount = tonumber(amount) or 0
	if amount <= 0 or amount > 2000 then return end
	if not target or not target.Parent then return end

	-- attacker can be Player or Model
	local attackerPlayer = attacker
	if typeof(attacker) == "Instance" and attacker:IsA("Model") then
		attackerPlayer = Players:GetPlayerFromCharacter(attacker)
	end
	if attackerPlayer then
		if not canHit(attackerPlayer) then return end
		if not distanceOK(attackerPlayer, target, 175) then return end
		local combatMult = tonumber(attackerPlayer:GetAttribute("Role_Combat")) or 1.0
		amount = amount * combatMult
	end

	-- Team/FF logic hook (optional): prevent friendly fire
	local atkTeam = attackerPlayer and attackerPlayer.Team or nil
	local tgtPlr = Players:GetPlayerFromCharacter(target)
	if tgtPlr and atkTeam and tgtPlr.Team == atkTeam then
		return
	end

	-- Health component contract:
	--  - Either a NumberValue "Health" under the target Model
	--  - Or a Humanoid if target is a character
	local healthValue = getHumanoidOrHealth(target)
	if not healthValue then return end

	-- Shield block check for player targets
	if tgtPlr and self._blocking[tgtPlr] then
		local shieldTool = self._blocking[tgtPlr]
		if shieldTool and shieldTool.Parent and shieldTool.Parent:IsDescendantOf(tgtPlr.Character) then
			local blockPercent = WeaponUtil.GetNumber(shieldTool, "BlockPercent", 0)
			local durability = WeaponUtil.GetNumber(shieldTool, "Durability", 0)
			blockPercent = math.clamp(blockPercent, 0, 0.95)
			if blockPercent > 0 and durability > 0 then
				local blocked = amount * blockPercent
				amount = math.max(0, amount - blocked)
				-- reduce durability by blocked amount
				local child = shieldTool:FindFirstChild("Durability")
				if child and child:IsA("ValueBase") then
					child.Value = math.max(0, child.Value - blocked)
					if child.Value <= 0 then
						self._blocking[tgtPlr] = nil
					end
				end
			end
		else
			self._blocking[tgtPlr] = nil
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
	if healthValue:IsA("NumberValue") then
		healthValue.Value = math.max(0, healthValue.Value - amount)
	else
		-- Humanoid - DeathService hooks HealthChanged and handles death automatically
		healthValue:TakeDamage(amount)
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

local function getRoot(model)
	if not model then return nil end
	return model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
end

local function raycastFromPlayer(plr, origin, dir, maxRange)
	local char = plr.Character
	if not char then return nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, Workspace.Terrain }
	local direction = dir.Unit * maxRange
	local res = Workspace:Raycast(origin, direction, params)
	return res
end

function CombatService:_canUseTool(tool, cooldown)
	if not tool then return false end
	local now = os.clock()
	local last = self._lastUse[tool] or 0
	if now - last < cooldown then return false end
	self._lastUse[tool] = now
	return true
end

function CombatService:_handleSword(plr, tool, weapon, data)
	local range = weapon:GetRange()
	local dmg = weapon:GetDamage()
	local cooldown = weapon:GetCooldown()
	if not self:_canUseTool(tool, cooldown) then return end
	local target = data and data.Target
	if not target or not target.Parent then return end
	if not distanceOK(plr, target, range + 2) then return end
	self:ApplyDamage(plr, target, dmg, "Melee")
end

function CombatService:_handleGun(plr, tool, weapon, data)
	local cooldown = weapon:GetCooldown()
	if not self:_canUseTool(tool, cooldown) then return end
	local ammoVal = tool:FindFirstChild("Ammo")
	local ammo = weapon:GetAmmo()
	if ammo <= 0 then return end
	if ammoVal and ammoVal:IsA("ValueBase") then
		ammoVal.Value = math.max(0, ammoVal.Value - 1)
	end
	local maxRange = weapon:GetNumber("Range", 200)
	local origin = data and data.Origin
	local dir = data and data.Dir
	if not origin or not dir then return end
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
	local start = self._chargeStart[plr]
	self._chargeStart[plr] = nil
	if not start then return end
	local chargeTime = weapon:GetChargeTime()
	local ratio = math.clamp((now - start) / math.max(chargeTime, 0.1), 0, 1)
	local cooldown = math.max(chargeTime * 0.2, 0.2)
	if not self:_canUseTool(tool, cooldown) then return end

	local maxRange = weapon:GetRange()
	local origin = data and data.Origin
	local dir = data and data.Dir
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
	local origin = data and data.Origin
	local dir = data and data.Dir
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
	ensureRemotes(self)
	if self._remoteDamage then
		self._remoteDamage.OnServerEvent:Connect(function(plr, target, amount, dmgType)
			local ok = pcall(function()
				CombatService:OnDamageRequest(plr, target, amount, dmgType)
			end)
			if not ok then end
		end)
	end

	if self._remoteAction then
		self._remoteAction.OnServerEvent:Connect(function(plr, action, data)
			local tool = getEquippedTool(plr)
			if not tool then return end
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
					self._chargeStart[plr] = os.clock()
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
