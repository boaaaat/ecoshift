-- CombatService.lua (expanded)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local CombatService = {}
-- OPTIMIZED: Lazy-load remotes instead of blocking at module load
CombatService._remotesFolder = nil
CombatService._remoteDamage = nil

local function ensureRemotes(self)
	if self._remoteDamage then return end
	self._remotesFolder = Util.GetDescendant(Config.Paths.Remotes) 
		or Util.WaitForDescendant(Config.Paths.Remotes, 5)
	if self._remotesFolder then
		self._remoteDamage = Util.GetRemote(self._remotesFolder, Config.RemoteNames.Damage)
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

function CombatService:OnDamageRequest(attacker, target, amount, dmgType)
	amount = tonumber(amount) or 0
	if amount <= 0 or amount > 2000 then return end
	if not attacker or not attacker.Character then return end
	if not target or not target.Parent then return end
	if not canHit(attacker) then return end
	if not distanceOK(attacker, target, 175) then return end

	local combatMult = tonumber(attacker:GetAttribute("Role_Combat")) or 1.0
	amount = amount * combatMult

	-- Team/FF logic hook (optional): prevent friendly fire
	local atkTeam = attacker.Team
	local tgtPlr = Players:GetPlayerFromCharacter(target)
	if tgtPlr and atkTeam and tgtPlr.Team == atkTeam then
		return
	end

	-- Health component contract:
	--  - Either a NumberValue "Health" under the target Model
	--  - Or a Humanoid if target is a character
	local healthValue = nil
	if target:FindFirstChild("Health") and target.Health:IsA("NumberValue") then
		healthValue = target.Health
	elseif target:FindFirstChildWhichIsA("Humanoid") then
		healthValue = target:FindFirstChildWhichIsA("Humanoid")
	end
	if not healthValue then return end

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
		-- Humanoid
		healthValue:TakeDamage(amount)
	end
end

function CombatService:Bind()
	ensureRemotes(self)
	if not self._remoteDamage then return end
	self._remoteDamage.OnServerEvent:Connect(function(plr, target, amount, dmgType)
		local ok = pcall(function()
			CombatService:OnDamageRequest(plr, target, amount, dmgType)
		end)
		if not ok then end
	end)
end

return CombatService
