-- CombatService.lua (expanded)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")


local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local StatsService = require(script.Parent.StatsService)
local GameStateService = require(script.Parent.GameStateService)

local Instances=require(ReplicatedStorage.Shared.ItemInstance)
local CombatService = {}
local acceptedCast=setmetatable({}, {__mode="k"})
local enchantRuntime=setmetatable({}, {__mode="k"})
local function enchantState(player)
 local current=enchantRuntime[player]
 if not current then current={Targets=setmetatable({}, {__mode="k"}),Cooldowns=setmetatable({}, {__mode="k"})};enchantRuntime[player]=current end
 return current
end
local function enchantRank(entry,id)
 local value=entry and entry.Enchantments and entry.Enchantments[id]
 return math.max(0,math.floor(tonumber(type(value)=="table" and (value.Level or value.Rank) or value) or 0))
end
local function enchantValue(entry,id,key)
 local definition=require(ReplicatedStorage.Shared.OverhaulCatalog).Enchantments[id]
 local level=enchantRank(entry,id)
 return definition and (definition[key or "Values"] or {})[level] or 0
end
local function isBoss(model)
 return model and (model:GetAttribute("IsBoss")==true or model:GetAttribute("Boss")==true or CollectionService:HasTag(model,"Boss"))
end
-- OPTIMIZED: Lazy-load remotes instead of blocking at module load
CombatService._remotesFolder = nil
CombatService._remoteDamage = nil
CombatService._remoteAction = nil
CombatService._remoteFeedback = nil

CombatService._lastUse = setmetatable({}, { __mode = "k" }) -- [tool] = time
CombatService._chargeStart = setmetatable({}, { __mode = "k" }) -- [player] = { Tool, Started }
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

local function interiorOf(actor)
 if typeof(actor)~="Instance" then return nil end
 local player=actor:IsA("Player") and actor or actor:IsA("Model") and Players:GetPlayerFromCharacter(actor)
 return player and player:GetAttribute("InteriorId") or actor:GetAttribute("InteriorId")
end
function CombatService:ApplyDamage(attacker, target, amount, dmgType)
 local attackerInterior,targetInterior=interiorOf(attacker),interiorOf(target)
 if attackerInterior~=targetInterior then return end
 if GameStateService:IsGameOver() or (ReplicatedStorage:GetAttribute("WorldShifting") and not attackerInterior) then
		return
	end
	amount = tonumber(amount) or 0
	if amount ~= amount or amount <= 0 or amount > 100000 then return end
	if typeof(target) ~= "Instance" or not target:IsA("Model") or not target:IsDescendantOf(Workspace) then return end

	-- attacker can be Player or Model
	local attackerPlayer = attacker
	if typeof(attacker) == "Instance" and attacker:IsA("Model") then
		attackerPlayer = Players:GetPlayerFromCharacter(attacker)
	end
	if attackerPlayer then
		local hum = attackerPlayer.Character and attackerPlayer.Character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 or attackerPlayer:GetAttribute("IsDead") then return end
		local castKind = acceptedCast[attackerPlayer]
		if dmgType ~= "ClassTurret" and not castKind and not canHit(attackerPlayer) then return end
		-- BowProjectile is set only inside the authoritative server projectile
		-- collision callback. Its travelled path is the range/line-of-sight proof,
		-- so the ordinary 175-stud anti-spoof check must not discard long shots.
		if dmgType ~= "ClassTurret" and castKind ~= "BowProjectile" and not distanceOK(attackerPlayer, target, 175) then return end
		local combatMult = (tonumber(attackerPlayer:GetAttribute("Role_Combat")) or 1.0) * (1+(attackerPlayer:GetAttribute("Gear_MonsterDamageBonus") or 0))
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
		local targetRoot=target.PrimaryPart or target:FindFirstChild("HumanoidRootPart")
		local attackerRoot=attackerPlayer.Character and attackerPlayer.Character:FindFirstChild("HumanoidRootPart")
		if targetRoot and attackerRoot then
			local approach=attackerRoot.Position-targetRoot.Position
			if approach.Magnitude>0 and approach.Unit:Dot(targetRoot.CFrame.LookVector)>.2 then amount*=target:GetAttribute("BossArmored") and .25 or 1-(target:GetAttribute("FrontalReduction") or 0) end
		end
		if dmgType == "Melee" or dmgType == "Gun" or dmgType == "Bow" or dmgType == "Throwable" then
			amount *= 1 + (attackerPlayer:GetAttribute("Food_MonsterDamageBonus") or 0)
		end
		local bonus = require(script.Parent.ClassAbilityService):GetMarkedBonus(target)
		amount *= 1 + bonus
		if (tonumber(target:GetAttribute("GearExposeUntil")) or 0)>Workspace:GetServerTimeNow() then
			amount*=1+math.clamp(tonumber(target:GetAttribute("GearExposeValue")) or 0,0,.25)
		end
		target:SetAttribute("LastAttackerUserId", attackerPlayer.UserId)
		if dmgType~="ClassTurret" then require(script.Parent.ExpeditionRewardsService):RecordActivity(attackerPlayer) end
	elseif tgtPlr and typeof(attacker)=="Instance" and attacker:IsA("Model") and game:GetService("CollectionService"):HasTag(attacker,"Monster") then
		amount=require(script.Parent.GearService):BeforeMonsterDamage(tgtPlr,attacker,amount)
		if amount<=0 then return end
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

	if tgtPlr then require(script.Parent.GearService):AfterMonsterDamage(tgtPlr) end
	if attackerPlayer and not tgtPlr and CollectionService:HasTag(target, "Monster")
		and not target:GetAttribute("DefeatRecorded") then
		local remaining = healthValue:IsA("Humanoid") and healthValue.Health or healthValue.Value
		if remaining <= 0 then
			target:SetAttribute("DefeatRecorded", true)
			require(script.Parent.DeathService):RecordMonsterDefeat(attackerPlayer)
		end
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
				local feedback = {
					Node = target,
					Position = pos,
					Damage = math.floor(amount),
					Health = newHealth,
					MaxHealth = maxHealth,
					Destroyed = newHealth <= 0,
				}
				fireCombatFeedbackNear(pos, self._remoteFeedback, feedback)
				-- Nearby observers receive the normal shared feedback. A bow user can be
				-- much farther away, so always confirm their own distant hit as well.
				if attackerPlayer then
					local attackerRoot = attackerPlayer.Character
						and attackerPlayer.Character:FindFirstChild("HumanoidRootPart")
					if not attackerRoot or (attackerRoot.Position - pos).Magnitude > COMBAT_FEEDBACK_RANGE then
						self._remoteFeedback:FireClient(attackerPlayer, feedback)
					end
				end
			end
		end
	end
end

function CombatService:OnDamageRequest(attacker, target, amount, dmgType)
	if not attacker or not attacker.Character then return end
	self:ApplyDamage(attacker, target, amount, dmgType)
end

local function getRoot(model)
 return model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart"))
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
local function getValidatedAimPoint(data, origin)
	local point = data and (data.AimPoint or data.HitPos)
	if typeof(point) ~= "Vector3" or typeof(origin) ~= "Vector3" then return nil end
	if point.X ~= point.X or point.Y ~= point.Y or point.Z ~= point.Z
		or math.abs(point.X) == math.huge or math.abs(point.Y) == math.huge or math.abs(point.Z) == math.huge then
		return nil
	end
	local delta = point - origin
	if delta.Magnitude < 0.001 then return nil end
	-- The point only chooses direction. Bounding it prevents arbitrary remote
	-- coordinates while retaining third-person camera offsets and ranged aim.
	if delta.Magnitude > 1024 then point = origin + delta.Unit * 1024 end
	return point
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

local function viableTargets(player,direction,range,width,radial,origin,piercing)
 local root=getRoot(player.Character)
 if not root then return {} end
 local basis=CFrame.lookAt(origin or root.Position,(origin or root.Position)+direction)
 local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Exclude;overlap.FilterDescendantsInstances={player.Character}
 local parts=radial and Workspace:GetPartBoundsInRadius(origin,radial,overlap) or Workspace:GetPartBoundsInBox(basis*CFrame.new(0,0,-range/2),Vector3.new(width*2,8,range),overlap)
 local results,seen={},{}
 local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Exclude;local ignored={player.Character}
 if piercing then for _,monster in ipairs(CollectionService:GetTagged("Monster")) do ignored[#ignored+1]=monster end end
 ray.FilterDescendantsInstances=ignored;ray.RespectCanCollide=true
 for _,part in ipairs(parts) do
  local model=part
  while model and model~=Workspace and not (model:IsA("Model") and isTaggedCombatTarget(model)) do model=model.Parent end
  if not model or model==Workspace or seen[model] then continue end
  seen[model]=true
  local targetRoot=getRoot(model);local health=getHumanoidOrHealth(model,false)
  if not targetRoot or not health or (health:IsA("Humanoid") and health.Health or health.Value)<=0 then continue end
  local localPoint=basis:PointToObjectSpace(targetRoot.Position)
  if not radial and (-localPoint.Z<0 or -localPoint.Z>range or math.abs(localPoint.X)>width or math.abs(localPoint.Y)>4) then continue end
  if radial and (targetRoot.Position-origin).Magnitude>radial then continue end
  local delta=targetRoot.Position-root.Position
  local obstruction=Workspace:Raycast(root.Position,delta,ray)
  if obstruction and not obstruction.Instance:IsDescendantOf(model) then continue end
  results[#results+1]={Model=model,Distance=delta.Magnitude}
 end
 table.sort(results,function(a,b)return a.Distance<b.Distance end)
 return results
end
local function healthRemaining(model)
 local health=getHumanoidOrHealth(model,false)
 return health and (health:IsA("Humanoid") and health.Health or health.Value) or 0
end
local function visibleNearby(player,center,radius,excluded)
 local root=getRoot(player.Character);if not root then return {} end
 local result={};local filters={player.Character};if excluded then table.insert(filters,excluded) end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances=filters;params.RespectCanCollide=true
 for _,model in ipairs(CollectionService:GetTagged("Monster")) do
  local targetRoot=getRoot(model)
  if model~=excluded and targetRoot and healthRemaining(model)>0 and (targetRoot.Position-center).Magnitude<=radius then
   local hit=Workspace:Raycast(center,targetRoot.Position-center,params)
   if not hit or hit.Instance:IsDescendantOf(model) then table.insert(result,{Model=model,Distance=(targetRoot.Position-center).Magnitude}) end
  end
 end
 table.sort(result,function(a,b)return a.Distance<b.Distance end)
 return result
end
local function applySlow(model,factor,seconds)
 if not model or not model.Parent then return end
 local now=Workspace:GetServerTimeNow();local currentUntil=tonumber(model:GetAttribute("GearSlowUntil")) or 0
 local currentFactor=currentUntil>now and (tonumber(model:GetAttribute("GearSlowFactor")) or 1) or 1
 model:SetAttribute("GearSlowFactor",math.min(currentFactor,math.clamp(factor,.1,1)))
 model:SetAttribute("GearSlowUntil",math.max(currentUntil,now+math.max(0,seconds or 0)))
end
local function applyStrongestTimed(model,prefix,value,seconds)
 local now=Workspace:GetServerTimeNow();local untilAt=tonumber(model:GetAttribute(prefix.."Until")) or 0
 local current=untilAt>now and (tonumber(model:GetAttribute(prefix.."Value")) or 0) or 0
 model:SetAttribute(prefix.."Value",math.max(current,value or 0))
 model:SetAttribute(prefix.."Until",math.max(untilAt,now+math.max(0,seconds or 0)))
end
local function revealMonster(model,seconds,color)
 if not model or not model.Parent then return end
 local now=Workspace:GetServerTimeNow();local untilAt=math.max(tonumber(model:GetAttribute("GearRevealUntil")) or 0,now+seconds)
 model:SetAttribute("GearRevealUntil",untilAt)
 local highlight=model:FindFirstChild("BeaconEchoReveal")
 if not highlight then
  highlight=Instance.new("Highlight");highlight.Name="BeaconEchoReveal";highlight.Adornee=model;highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop;highlight.FillTransparency=.82;highlight.OutlineTransparency=.15;highlight.Parent=model
 end
 highlight.FillColor=color;highlight.OutlineColor=color;highlight.Enabled=true
 task.delay(seconds,function()if highlight.Parent and (tonumber(model:GetAttribute("GearRevealUntil")) or 0)<=Workspace:GetServerTimeNow() then highlight.Enabled=false end end)
end
local function moveMonster(model,toward,distance,ignore)
 if not model or isBoss(model) then return end
 local root=getRoot(model);if not root then return end
 local delta=Vector3.new(toward.X-root.Position.X,0,toward.Z-root.Position.Z)
 if delta.Magnitude<.1 then return end
 local movement=delta.Unit*math.min(math.max(0,distance or 0),delta.Magnitude)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={model,ignore};params.RespectCanCollide=true
 if not Workspace:Blockcast(root.CFrame,Vector3.new(2,3,2),movement,params) then model:PivotTo(model:GetPivot()+movement) end
end
local function effectPulse(position,color,radius,duration)
 local part=Instance.new("Part");part.Name="EnchantPulse";part.Shape=Enum.PartType.Ball;part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part.Material=Enum.Material.Neon;part.Color=color;part.Transparency=.55;part.Size=Vector3.one*math.max(1,radius*.35);part.Position=position;part.Parent=Workspace
 local light=Instance.new("PointLight");light.Color=color;light.Range=radius;light.Brightness=1.6;light.Parent=part
 task.spawn(function()
  local elapsed=0
  while part.Parent and elapsed<duration do local dt=RunService.Heartbeat:Wait();elapsed+=dt;local alpha=math.clamp(elapsed/duration,0,1);part.Size=Vector3.one*math.max(1,radius*(.35+.65*alpha));part.Transparency=.55+.4*alpha end
  if part.Parent then part:Destroy() end
 end)
end

local BowVisuals = require(ReplicatedStorage.Shared.Weapons.BowVisuals)
local function projectileFolder()
 local existing=Workspace:FindFirstChild("CombatProjectiles")
 if existing then return existing end
 local created=Instance.new("Folder");created.Name="CombatProjectiles";created.Parent=Workspace
 return created
end
local function broadcastBowEffect(kind,id,grade,special,position,normal)
 local remotes=ReplicatedStorage:FindFirstChild("Remotes")
 local remote=remotes and remotes:FindFirstChild("BowEffect")
 if not remote then return end
 for _,viewer in ipairs(Players:GetPlayers()) do
  local root=viewer.Character and viewer.Character:FindFirstChild("HumanoidRootPart")
  if root and (root.Position-position).Magnitude<=320 then
   remote:FireClient(viewer,kind,id,grade,special,position,normal)
  end
 end
end
local function impactEffect(position,normal,id,grade,special)
 broadcastBowEffect("Impact",id,grade,special,position,normal)
end
local function projectileTarget(instance)
 local candidate=instance
 while candidate and candidate~=Workspace do
  if candidate:IsA("Model") and isTaggedCombatTarget(candidate) then return candidate end
  candidate=candidate.Parent
 end
 return nil
end
local function arrowSource(player,tool)
 for _,name in ipairs(TOOL_ORIGIN_NAMES) do
  local source=tool:FindFirstChild(name,true)
  if source then
   if source:IsA("Attachment") then return source.WorldPosition,.6 end
   if source:IsA("BasePart") then return source.Position,1.5 end
  end
 end
 local head=player.Character and player.Character:FindFirstChild("Head")
 local handle=tool:FindFirstChild("Handle")
 return (handle and handle.Position) or (head and head.Position) or getRoot(player.Character).Position,1.7
end
local function ballisticDirection(origin,target,speed,gravity)
 local delta=target-origin
 local flat=Vector3.new(delta.X,0,delta.Z);local distance=flat.Magnitude
 if distance<.001 or gravity<=.001 then return delta.Magnitude>.001 and delta.Unit or nil end
 local speedSquared=speed*speed
 local determinant=speedSquared*speedSquared-gravity*(gravity*distance*distance+2*delta.Y*speedSquared)
 if determinant<0 then return delta.Unit end
 local tangent=(speedSquared-math.sqrt(determinant))/(gravity*distance)
 local cosine=1/math.sqrt(1+tangent*tangent)
 return flat.Unit*cosine+Vector3.yAxis*(tangent*cosine)
end
function CombatService:_launchArrow(player,tool,entry,def,direction,aimPoint,chargeRatio,special,touch,onHit)
 local grade=math.clamp(math.floor(tonumber(entry.Grade or def.Grade) or 1),1,8)
 -- Draw strength controls real projectile velocity. Weak shots travel at about
 -- half speed and therefore arc much more sharply under the same gravity.
 local speed=(165+grade*11)*(.35+.65*math.clamp(chargeRatio or 1,.25,1))
 -- Use a visible ballistic arc while preserving enough full-draw velocity for
 -- skilled long shots. Weak draws drop sharply because speed scales by charge.
 local gravity=Vector3.new(0,-Workspace.Gravity*.12,0)
 local heldBreath=enchantRank(entry,"HeldBreath")
 if heldBreath>0 and (chargeRatio or 0)>=.9 then
  speed*=1+enchantValue(entry,"HeldBreath")
  gravity*=1-enchantValue(entry,"HeldBreath","GravityValues")
 end
 local source,forwardOffset=arrowSource(player,tool)
 if aimPoint and (aimPoint-source).Magnitude>.001 then direction=(aimPoint-source).Unit end
 local origin=source+direction*forwardOffset
 if aimPoint then
  direction=ballisticDirection(origin,aimPoint,speed,-gravity.Y) or direction
  origin=source+direction*forwardOffset
  direction=ballisticDirection(origin,aimPoint,speed,-gravity.Y) or direction
 end
 local arrow=BowVisuals.CreateArrow(entry.Id,grade,special,origin,direction)
 arrow.Parent=projectileFolder()
 local velocity=direction*speed
 local range=tonumber(def.Reach) or 120
 local radius=touch and 1.65 or 1.2
 local maximumHits=special and (entry.Id=="StormBow" and 1 or math.max(1,math.floor(def.SpecialTargets or 2))) or 1
 local ignored={arrow,player.Character}
 for _,other in ipairs(Players:GetPlayers()) do if other~=player and other.Character then ignored[#ignored+1]=other.Character end end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances=ignored;params.RespectCanCollide=false
 local position,travelled,hits=origin,0,0
 local finished=false
 local connection
 local function finish(positionAtImpact,normal,showImpact)
  if finished then return end;finished=true
  arrow:SetAttribute("BowInFlight",false)
  if connection then connection:Disconnect() end
  if not arrow.Parent then return end
  if positionAtImpact then
   local facing=velocity.Magnitude>.01 and velocity.Unit or direction
   arrow:PivotTo(CFrame.lookAt(positionAtImpact-facing*.55,positionAtImpact+facing))
   if showImpact then impactEffect(positionAtImpact,normal or -facing,entry.Id,grade,special) end
  end
  -- Embedded arrows are scenery only: their parts cannot collide, touch or be
  -- queried, and the model has no prompt/tool behavior, so it cannot be picked up.
  Debris:AddItem(arrow,showImpact and 10 or .3)
 end
 local function castSegment(cframe,size,displacement)
  for _=1,10 do
   params.FilterDescendantsInstances=ignored
   local result=Workspace:Blockcast(cframe,size,displacement,params)
   if not result then return nil,nil end
   local target=projectileTarget(result.Instance)
   if target then return result,target end
   -- Resource foliage is often non-collidable. It may still be the exact object
   -- selected by the crosshair, so stop there instead of visibly landing behind it.
   if aimPoint and (result.Position-aimPoint).Magnitude<=math.max(2,radius*2) then return result,nil end
   if result.Instance==Workspace.Terrain or not result.Instance:IsA("BasePart") or result.Instance.CanCollide then return result,nil end
   ignored[#ignored+1]=result.Instance
  end
  return nil,nil
 end
 connection=RunService.Heartbeat:Connect(function(dt)
  if finished then return end
  if not arrow.Parent then finished=true;if connection then connection:Disconnect() end;return end
  if not player.Parent or not player.Character or player:GetAttribute("IsDead") or GameStateService:IsGameOver()
   or (ReplicatedStorage:GetAttribute("WorldShifting") and not player:GetAttribute("InteriorId")) then finish(position,nil,false);return end
  dt=math.min(dt,.05)
  local nextVelocity=velocity+gravity*dt
  local displacement=(velocity+nextVelocity)*.5*dt
  local remaining=range-travelled
  if remaining<=0 then finish(position,nil,false);return end
  if displacement.Magnitude>remaining then displacement=displacement.Unit*remaining end
  local facing=displacement.Magnitude>.001 and displacement.Unit or direction
  local result,target=castSegment(CFrame.lookAt(position,position+facing),Vector3.one*(radius*2),displacement)
  travelled+=result and result.Distance or displacement.Magnitude;velocity=nextVelocity
  if result then
   position=result.Position
   arrow:PivotTo(CFrame.lookAt(position-facing*.55,position+facing))
   if target then
    hits+=1;impactEffect(position,result.Normal,entry.Id,grade,special);onHit(target,hits)
    ignored[#ignored+1]=target
    if hits>=maximumHits then finish(position,result.Normal,false);return end
    position+=facing*.8
   else finish(position,result.Normal,true);return end
  else
   position+=displacement
   arrow:PivotTo(CFrame.lookAt(position,position+velocity.Unit))
  end
  if travelled>=range then finish(position,nil,false) end
 end)
 -- Keep flight cleanup later than a possible final impact so an embedded arrow
 -- always receives its full ten-second display lifetime.
 Debris:AddItem(arrow,math.max(12,range/math.max(speed,1)+11))
 -- Cosmetic delivery happens after movement and cleanup have been registered.
 broadcastBowEffect("Release",entry.Id,grade,special,origin,direction)
end
function CombatService:_overhaul(player,action,data)
 local gear=require(script.Parent.GearService)
 local entry,def,tool=gear:GetHeld(player)
 if not entry or not def or not tool or (entry.Durability or 1)<=0 then return end
 if player:GetAttribute("WorldPlayerLoading") or player:GetAttribute("WorldPlayerRestoring") or ReplicatedStorage:GetAttribute("WorldRestoring") then return end
 local root=getRoot(player.Character);if not root then return end
 local family=def.WeaponFamily
 if def.Kind=="Tool" and entry.Id~="Harvester" then return end
 local special=action=="Special"
 if action=="ChargeStart" and family=="Bow" then
  self._chargeStart[player]={Tool=tool,Started=os.clock()}
  tool:SetAttribute("BowDrawStarted",Workspace:GetServerTimeNow())
  return
 end
 if not special and action~="Attack" and action~="Fire" and action~="ChargeRelease" then return end
 local reach=def.Reach or 8
 local aimPoint=getValidatedAimPoint(data,root.Position)
 local direction=getValidatedAimDirection(data) or root.CFrame.LookVector
 if aimPoint and (aimPoint-root.Position).Magnitude>.001 then direction=(aimPoint-root.Position).Unit end
 if direction.Magnitude<.01 then return end
 local touch=data and data.Touch==true
 local width=2.5*(touch and 1.15 or 1)
 if family~="Bow" and family~="Staff" then reach+=touch and .75 or 0;direction=Vector3.new(direction.X,0,direction.Z);if direction.Magnitude<.01 then return end;direction=direction.Unit end
 local now=os.clock()
 local runtime=enchantState(player)
 if not special and family=="Sword" and runtime.SwordPrimed and runtime.SwordTool==entry.Uid and now-(runtime.SwordAt or 0)<=2.5 then width*=1.15 end
 local modifiers=gear:GetModifiers(player)
 if special and (def.Kind~="Weapon" or gear:GetSpecialRemaining(player)>0) then return end
 local damage=def.Damage or 6
 local base=def.StandardDamage or damage
 local chargeRatio=1
 local function deal(target,amount,damageType,castKind)
  if not target or not target.Parent or amount<=0 then return end
  acceptedCast[player]=castKind or true
  local ok,err=pcall(function() self:ApplyDamage(player,target,amount,damageType) end)
  acceptedCast[player]=nil
  if not ok then warn("[CombatService] Enchantment damage failed:",err) end
 end
 if family=="Bow" and not special then
  local charge=self._chargeStart[player];self._chargeStart[player]=nil
  if not charge or charge.Tool~=tool or now-charge.Started<.15 then return end
  chargeRatio=math.clamp((now-charge.Started)/1.3,.25,1)
  damage=base*1.2*chargeRatio
 end
 if family=="Bow" then
  if not special and not self:_canUseTool(tool,def.AttackCycle or 1.3,true) then return end
  local cost=special and 20*(1-(modifiers.SpecialCostReduction or 0))*(1-(player:GetAttribute("Food_SpecialDrainReduction") or 0)) or 0
  local stamina=StatsService:GetBase(player,"Stamina") or 0
  if stamina<cost then return end
  if not require(script.Parent.InventoryService):Consume(player,"Arrow",1) then return end
  if cost>0 then StatsService:SetBase(player,"Stamina",stamina-cost) end
  if special then
   gear:StartSpecialCooldown(player,8*(1-(modifiers.SpecialCooldownReduction or 0)))
   damage=def.SpecialDamage or base*(def.SpecialFactor or 1.5)
  end
  local bowDamageMultiplier=1+gear:GetHeldEnchantValue(player,"DrawForce")
  local fullyDrawn=not special and chargeRatio>=.9
  local function hitArrow(target,index)
   if not target or not target.Parent then return end
   local vanillaAmount=special and entry.Id=="StormBow" and base*1.2 or damage
   local enchantmentBonus=vanillaAmount*(bowDamageMultiplier-1)
   if special then
     local extra=index==1 and gear:OnSpecialHit(player,target,base) or 0
     enchantmentBonus+=extra
    elseif index==1 then enchantmentBonus+=gear:BasicHitBonus(player,target,base) end
    local amount=vanillaAmount+enchantmentBonus
   deal(target,amount,"Bow","BowProjectile")
   local center=getRoot(target) and getRoot(target).Position or target:GetPivot().Position
   if fullyDrawn and index==1 then
    local splitLevel=enchantRank(entry,"SplitFlight")
    if splitLevel>0 then
     local count=require(ReplicatedStorage.Shared.OverhaulCatalog).Enchantments.SplitFlight.TargetValues[splitLevel]
     local radius=require(ReplicatedStorage.Shared.OverhaulCatalog).Enchantments.SplitFlight.RadiusValues[splitLevel]
     local factor=enchantValue(entry,"SplitFlight")
     for i,neighbor in ipairs(visibleNearby(player,center,radius,target)) do if i>count then break end;deal(neighbor.Model,amount*factor,"BowFragment","BowProjectile") end
     effectPulse(center,Color3.fromRGB(172,225,255),radius,.28)
    end
    local pinLevel=entry.Id=="IronwoodBow" and enchantRank(entry,"RootPin") or 0
    if pinLevel>0 then
     local targetState=runtime.Cooldowns[target] or {};runtime.Cooldowns[target]=targetState
      if now>=(targetState.RootPinAt or 0) then
       targetState.RootPinAt=now+6
       if isBoss(target) then applySlow(target,1-({.15,.25})[pinLevel],1.5)
       else target:SetAttribute("GearStaggerUntil",math.max(tonumber(target:GetAttribute("GearStaggerUntil")) or 0,Workspace:GetServerTimeNow()+enchantValue(entry,"RootPin"))) end
       effectPulse(center,Color3.fromRGB(98,178,99),3,.25)
     end
    end
    if entry.Id=="StarBow" and enchantRank(entry,"StarfallTrace")>0 and now>=(runtime.StarfallAt or 0) then
     runtime.StarfallAt=now+4
     local pulseDamage=amount*enchantValue(entry,"StarfallTrace")
     task.delay(.6,function()
      if not player.Parent then return end
      effectPulse(center,Color3.fromRGB(232,211,112),6,.45)
      for _,neighbor in ipairs(visibleNearby(player,center,6,nil)) do deal(neighbor.Model,pulseDamage,"Starfall","BowProjectile") end
     end)
    end
   end
   if special and entry.Id=="StormBow" and index==1 then
    local forkLevel=enchantRank(entry,"ForkedCurrent")
    local chainCount=forkLevel>0 and require(ReplicatedStorage.Shared.OverhaulCatalog).Enchantments.ForkedCurrent.TargetValues[forkLevel] or 1
    local chainFactor=forkLevel>0 and enchantValue(entry,"ForkedCurrent") or .4
    for i,neighbor in ipairs(visibleNearby(player,center,12,target)) do
     if i>chainCount then break end
     deal(neighbor.Model,base*chainFactor*bowDamageMultiplier,"BowChain","BowProjectile")
     broadcastBowEffect("Chain",entry.Id,entry.Grade or def.Grade,true,center,neighbor.Model:GetPivot().Position)
    end
   end
  end
  self:_launchArrow(player,tool,entry,def,direction,aimPoint,chargeRatio,special,touch,hitArrow)
  gear:WearHeld(player,1)
  return
 end

 local specialRadius=family=="Hammer" and 10 or family=="Staff" and 7 or nil
 if special and family=="Staff" and runtime.FocusReady and now<(runtime.FocusExpires or 0) then
  specialRadius*=1+enchantValue(entry,"FocusLine");runtime.FocusReady=nil;runtime.FocusExpires=nil
 end
 local targets
 if family=="Staff" then
  local rayParams=RaycastParams.new();rayParams.FilterType=Enum.RaycastFilterType.Exclude;rayParams.FilterDescendantsInstances={player.Character}
  local ray=Workspace:Raycast(root.Position,direction*reach,rayParams)
  local at=ray and ray.Position or root.Position+direction*reach
  targets=special and viableTargets(player,direction,reach,width,specialRadius,at) or viableTargets(player,direction,reach,touch and 1.15 or 1)
 else targets=viableTargets(player,direction,special and family=="Hammer" and specialRadius or reach,special and family=="Hammer" and specialRadius or width) end
 if not special and #targets==0 then
  if family=="Sword" then runtime.SwordPrimed=nil;runtime.SwordTool=nil;runtime.SwordAt=nil end
  if family=="Staff" then runtime.StaffTarget=nil;runtime.StaffHits=0;runtime.StaffAt=nil end
 end
 local canCastEmpty=special and ((family=="Sword" and enchantRank(entry,"GuardReturn")>0) or (family=="Hammer" and (enchantRank(entry,"HeavyEcho")>0 or enchantRank(entry,"GroundClaim")>0)))
 if special and #targets==0 and not canCastEmpty then if self._remoteFeedback then self._remoteFeedback:FireClient(player,{Type="Message",Message="No visible target in special range."}) end;return end
 if not special and not self:_canUseTool(tool,def.AttackCycle or .6,true) then return end
 local tailwindReduction=special and family=="Spear" and gear:GetTailwindCostReduction(player) or 0
 local cost=special and 20*(1-(modifiers.SpecialCostReduction or 0))*(1-tailwindReduction)*(1-(player:GetAttribute("Food_SpecialDrainReduction") or 0)) or family=="Staff" and 3 or 0
 local stamina=StatsService:GetBase(player,"Stamina") or 0
 if stamina<cost then return end
 if special and family=="Spear" and tailwindReduction>0 then gear:ConsumeTailwindCost(player) end
 if cost>0 then StatsService:SetBase(player,"Stamina",stamina-cost) end
 local specialCooldown=8*(1-(modifiers.SpecialCooldownReduction or 0))
 if special then
  gear:StartSpecialCooldown(player,specialCooldown);damage=def.SpecialDamage or base*(def.SpecialFactor or 1.5)
  if family=="Sword" and enchantRank(entry,"GuardReturn")>0 then gear:BeginSwordGuard(player) end
 end
 local maximum=special and (def.SpecialTargets or 1) or 1
 if special and family=="Staff" then maximum=8 end
 local drivingLevel=special and family=="Spear" and enchantRank(entry,"DrivingLine") or 0
 if drivingLevel>0 then maximum+=require(ReplicatedStorage.Shared.OverhaulCatalog).Enchantments.DrivingLine.TargetValues[drivingLevel] end
 if not special and ((family=="Sword" and enchantRank(entry,"WideCut")>0) or (family=="Axe" and enchantRank(entry,"SplitArc")>0)) then maximum=2 end
 local extra=special and targets[1] and gear:OnSpecialHit(player,targets[1].Model,base) or 0
 local primaryCenter=targets[1] and getRoot(targets[1].Model) and getRoot(targets[1].Model).Position or root.Position+direction*4
 local fellRefunded=false
 local phaseTargets={}
 for i,target in ipairs(targets) do
  if i>maximum then break end
  local monster=target.Model
  local targetState=runtime.Targets[monster] or {};runtime.Targets[monster]=targetState
  local amount=damage
  if special and entry.Id=="EmberAxe" then amount=base*1.2
  elseif special and entry.Id=="ThornBlade" then amount=base*.8 end
  if i==1 then amount+=extra end
  if special and family=="Spear" and i>1 and drivingLevel>0 then amount=damage*enchantValue(entry,"DrivingLine") end
  if not special and family=="Sword" then
   local measured=enchantRank(entry,"MeasuredEdge")
   if i==1 and measured>0 then
    if runtime.SwordTool==entry.Uid and now-(runtime.SwordAt or 0)<=2.5 and runtime.SwordPrimed then amount+=base*enchantValue(entry,"MeasuredEdge");runtime.SwordPrimed=nil
    else runtime.SwordTool=entry.Uid;runtime.SwordAt=now;runtime.SwordPrimed=true end
   end
   if i==2 and enchantRank(entry,"WideCut")>0 then amount=damage*enchantValue(entry,"WideCut") end
  elseif not special and family=="Spear" then
   local setPoint=enchantRank(entry,"SetPoint")
   if setPoint>0 and target.Distance>=8 then
    amount+=base*enchantValue(entry,"SetPoint")
    local slow=enchantValue(entry,"SetPoint","SlowValues")*(isBoss(monster) and .5 or 1);applySlow(monster,1-slow,1.5)
    local tailwind=enchantRank(entry,"TailwindLine")
    if entry.Id=="SkySpear" and tailwind>0 then gear:GrantEnchantMove(player,enchantValue(entry,"TailwindLine"),3);gear:PrimeTailwind(player,enchantValue(entry,"TailwindLine","CostValues"));effectPulse(root.Position,Color3.fromRGB(183,229,240),3,.18) end
   end
   local brace=enchantRank(entry,"Brace")
   if brace>0 and gear:IsBraced(player) and not isBoss(monster) and now>=(targetState.BraceAt or 0) then gear:ConsumeBrace(player);targetState.BraceAt=now+8;monster:SetAttribute("GearStaggerUntil",Workspace:GetServerTimeNow()+enchantValue(entry,"Brace")) end
  elseif not special and family=="Axe" then
   if i==2 and enchantRank(entry,"SplitArc")>0 then amount=damage*enchantValue(entry,"SplitArc") end
   local bite=enchantRank(entry,"DeepBite")
   if bite>0 then targetState.Wounds=math.min(enchantValue(entry,"DeepBite"),(targetState.WoundAt or 0)>now and (targetState.Wounds or 0)+1 or 1);targetState.WoundAt=now+4 end
  elseif not special and family=="Dagger" then
   local blind=enchantRank(entry,"Blindside");local targetRoot=getRoot(monster)
   if blind>0 and targetRoot then local toPlayer=root.Position-targetRoot.Position;if toPlayer.Magnitude>0 and targetRoot.CFrame.LookVector:Dot(toPlayer.Unit)<-.25 then amount+=base*enchantValue(entry,"Blindside")*(isBoss(monster) and .5 or 1) end end
   if i==1 and enchantRank(entry,"SlipCut")>0 and gear:ConsumeSlipCut(player) then amount+=base*enchantValue(entry,"SlipCut") end
  elseif not special and family=="Staff" then
   if runtime.StaffTarget==monster and now-(runtime.StaffAt or 0)<=4 then runtime.StaffHits=(runtime.StaffHits or 0)+1 else runtime.StaffTarget=monster;runtime.StaffHits=1 end
   runtime.StaffAt=now
   if runtime.StaffHits>=3 and enchantRank(entry,"FocusLine")>0 then runtime.StaffHits=0;runtime.FocusReady=true;runtime.FocusExpires=now+6 end
  end
  if not special and i==1 then amount+=gear:BasicHitBonus(player,monster,base) end
  if special and family=="Axe" then
   local wounds=(targetState.WoundAt or 0)>now and (targetState.Wounds or 0) or 0
   if wounds>0 and enchantRank(entry,"DeepBite")>0 then
    targetState.Wounds=0;targetState.WoundAt=0
    local tickDamage=base*enchantValue(entry,"DeepBite","DamageValues")*wounds/3
    task.spawn(function() for _=1,3 do task.wait(1);if not monster.Parent then return end;deal(monster,tickDamage,"EnchantWound") end end)
   end
  end
  if special and entry.Id=="ThornBlade" and enchantRank(entry,"BriarDebt")>0 and i==1 then local debt=gear:ConsumeBriarDebt(player);amount+=debt;if debt>0 then effectPulse(getRoot(monster).Position,Color3.fromRGB(181,75,132),3,.22) end end
  local wasAlive=healthRemaining(monster)>0
  deal(monster,amount,family=="Staff" and "Gun" or "Melee")
  if wasAlive and healthRemaining(monster)<=0 then
   if family=="Dagger" and enchantRank(entry,"QuickExit")>0 then gear:GrantEnchantMove(player,enchantValue(entry,"QuickExit"),3) end
   if special and family=="Axe" and enchantRank(entry,"FellThrough")>0 and not fellRefunded then fellRefunded=true;gear:AdjustSpecialCooldown(player,specialCooldown*enchantValue(entry,"FellThrough")) end
  end
  if entry.Id=="DeepsteelSword" and enchantRank(entry,"PressureCut")>0 then
   local pressure=enchantRank(entry,"PressureCut");targetState.PressureHits=(targetState.PressureAt or 0)>now and (targetState.PressureHits or 0)+1 or 1;targetState.PressureAt=now+4
    if targetState.PressureHits>=require(ReplicatedStorage.Shared.OverhaulCatalog).Enchantments.PressureCut.HitValues[pressure] then targetState.PressureHits=0;applyStrongestTimed(monster,"GearExpose",enchantValue(entry,"PressureCut"),4);effectPulse(getRoot(monster).Position,Color3.fromRGB(91,151,169),3,.2) end
   end
   if family=="Hammer" and enchantRank(entry,"Crumple")>0 then
    applyStrongestTimed(monster,"GearCrumple",enchantValue(entry,"Crumple"),4)
  end
   if entry.Id=="RootStaff" and (tonumber(monster:GetAttribute("RootNetworkUntil")) or 0)>Workspace:GetServerTimeNow() and monster:GetAttribute("RootNetworkOwner")==player.UserId then
    local linked=visibleNearby(player,getRoot(monster).Position,10,monster)[1]
    if linked then deal(linked.Model,amount*(tonumber(monster:GetAttribute("RootNetworkFactor")) or 0),"RootNetwork");effectPulse(linked.Model:GetPivot().Position,Color3.fromRGB(94,170,94),2.5,.18) end
  end
  if special then
   if entry.Id=="EmberAxe" or entry.Id=="ThornBlade" then
    local seconds=entry.Id=="EmberAxe" and 4 or 3;local generation=(monster:GetAttribute("GearDotSerial") or 0)+1;monster:SetAttribute("GearDotSerial",generation)
    task.spawn(function() for _=1,seconds do task.wait(1);if not monster.Parent or monster:GetAttribute("GearDotSerial")~=generation then return end;deal(monster,base*.1,"GearDamageOverTime") end end)
   end
   if entry.Id=="RootStaff" then
    applySlow(monster,.8,3)
    local network=enchantRank(entry,"RootNetwork")
    if network>0 then local serverNow=Workspace:GetServerTimeNow();local current=(tonumber(monster:GetAttribute("RootNetworkUntil")) or 0)>serverNow and (tonumber(monster:GetAttribute("RootNetworkFactor")) or 0) or 0;local value=enchantValue(entry,"RootNetwork");if value>=current then monster:SetAttribute("RootNetworkOwner",player.UserId);monster:SetAttribute("RootNetworkFactor",value) end;monster:SetAttribute("RootNetworkUntil",math.max(tonumber(monster:GetAttribute("RootNetworkUntil")) or 0,serverNow+3)) end
   elseif family=="Dagger" or entry.Id=="FrostSpear" then applySlow(monster,.8,3) end
   if (family=="Axe" or family=="Hammer") and not isBoss(monster) then
    local stagger=(family=="Hammer" and .7 or .5)*(1+((tonumber(monster:GetAttribute("GearCrumpleUntil")) or 0)>Workspace:GetServerTimeNow() and (tonumber(monster:GetAttribute("GearCrumpleValue")) or 0) or 0))
    monster:SetAttribute("GearStaggerUntil",Workspace:GetServerTimeNow()+stagger)
   end
    if entry.Id=="TideSpear" and enchantRank(entry,"Undertow")>0 then moveMonster(monster,primaryCenter,enchantValue(entry,"Undertow"),player.Character);effectPulse(getRoot(monster).Position,Color3.fromRGB(76,176,212),3,.2) end
    if entry.Id=="GravityHammer" and enchantRank(entry,"OrbitBreak")>0 then if isBoss(monster) then applySlow(monster,.85,1.5) else moveMonster(monster,primaryCenter,3,player.Character) end end
   if entry.Id=="Moonblade" and enchantRank(entry,"PhaseReturn")>0 then table.insert(phaseTargets,{Model=monster,Amount=amount*enchantValue(entry,"PhaseReturn")}) end
  end
 end
 if special and family=="Hammer" then
  if entry.Id=="GravityHammer" and enchantRank(entry,"OrbitBreak")>0 then effectPulse(primaryCenter,Color3.fromRGB(158,121,222),6,.25) end
  local rolling=enchantRank(entry,"RollingCharge")
  if entry.Id=="ThunderHammer" and rolling>0 and targets[1] then
   local center=getRoot(targets[1].Model).Position;local count=require(ReplicatedStorage.Shared.OverhaulCatalog).Enchantments.RollingCharge.TargetValues[rolling]
   for i,neighbor in ipairs(visibleNearby(player,center,10,targets[1].Model)) do if i>count then break end;deal(neighbor.Model,base*enchantValue(entry,"RollingCharge"),"RollingCharge") end
   effectPulse(center,Color3.fromRGB(108,211,255),10,.35)
  end
  local echo=enchantRank(entry,"HeavyEcho")
  if echo>0 then local center=primaryCenter;task.delay(.65,function()if not player.Parent then return end;effectPulse(center,Color3.fromRGB(231,174,87),7,.4);for _,neighbor in ipairs(visibleNearby(player,center,7,nil)) do deal(neighbor.Model,damage*enchantValue(entry,"HeavyEcho"),"HeavyEcho") end end) end
  local claim=enchantRank(entry,"GroundClaim")
  if claim>0 then
    local center=primaryCenter;local duration=require(ReplicatedStorage.Shared.OverhaulCatalog).Enchantments.GroundClaim.DurationValues[claim];effectPulse(center,Color3.fromRGB(112,171,92),10,.5)
    if runtime.GroundClaimPart and runtime.GroundClaimPart.Parent then runtime.GroundClaimPart:Destroy() end
    local zone=Instance.new("Part");zone.Name="GroundClaimZone";zone.Shape=Enum.PartType.Cylinder;zone.Anchored=true;zone.CanCollide=false;zone.CanQuery=false;zone.CanTouch=false;zone.Material=Enum.Material.Neon;zone.Color=Color3.fromRGB(112,171,92);zone.Transparency=.82;zone.Size=Vector3.new(.15,20,20);zone.CFrame=CFrame.new(center+Vector3.new(0,.12,0))*CFrame.Angles(0,0,math.rad(90));zone.Parent=Workspace;runtime.GroundClaimPart=zone;Debris:AddItem(zone,duration)
    runtime.GroundClaimSerial=(runtime.GroundClaimSerial or 0)+1;local serial=runtime.GroundClaimSerial
    task.spawn(function()local expires=os.clock()+duration;while player.Parent and runtime.GroundClaimSerial==serial and os.clock()<expires do for _,neighbor in ipairs(visibleNearby(player,center,10,nil)) do if not isBoss(neighbor.Model) then applySlow(neighbor.Model,1-enchantValue(entry,"GroundClaim"),.5) end end;task.wait(.25) end end)
  end
 end
 if special and family=="Staff" and #targets>0 then
  local echo=enchantRank(entry,"EchoCast")
  if echo>0 then local center=primaryCenter;task.delay(.7,function()if not player.Parent then return end;effectPulse(center,Color3.fromRGB(155,129,225),specialRadius*.6,.4);for _,neighbor in ipairs(visibleNearby(player,center,specialRadius*.6,nil)) do deal(neighbor.Model,damage*enchantValue(entry,"EchoCast"),"EchoCast") end end) end
  local conduit=enchantRank(entry,"Conduit")
  if conduit>0 then for _,other in ipairs(Players:GetPlayers()) do local otherRoot=getRoot(other.Character);local hum=other.Character and other.Character:FindFirstChildOfClass("Humanoid");if otherRoot and hum and hum.Health>0 and (otherRoot.Position-primaryCenter).Magnitude<=12 then StatsService:SetBase(other,"Stamina",math.min(StatsService:GetStat(other,"MaxStamina") or 100,(StatsService:GetBase(other,"Stamina") or 0)+enchantValue(entry,"Conduit"))) end end end
  local beacon=enchantRank(entry,"BeaconEcho")
  if entry.Id=="LanternStaff" and beacon>0 then
   local duration=require(ReplicatedStorage.Shared.OverhaulCatalog).Enchantments.BeaconEcho.DurationValues[beacon];local field=Instance.new("Part");field.Name="BeaconEchoField";field.Shape=Enum.PartType.Ball;field.Anchored=true;field.CanCollide=false;field.CanQuery=false;field.CanTouch=false;field.Material=Enum.Material.Neon;field.Color=Color3.fromRGB(224,239,156);field.Transparency=.82;field.Size=Vector3.one*16;field.Position=primaryCenter;field.Parent=Workspace;local light=Instance.new("PointLight");light.Range=18;light.Brightness=2;light.Color=field.Color;light.Parent=field;Debris:AddItem(field,duration)
    if runtime.BeaconField and runtime.BeaconField.Parent then runtime.BeaconField:Destroy() end;runtime.BeaconField=field
    task.spawn(function()for _=1,duration do task.wait(1);if not field.Parent then return end;for _,other in ipairs(Players:GetPlayers()) do local otherRoot=getRoot(other.Character);local otherHum=other.Character and other.Character:FindFirstChildOfClass("Humanoid");if otherRoot and otherHum and otherHum.Health>0 and (otherRoot.Position-primaryCenter).Magnitude<=10 then gear:RestoreExposure(other,enchantValue(entry,"BeaconEcho")) end end;for _,neighbor in ipairs(visibleNearby(player,primaryCenter,10,nil)) do revealMonster(neighbor.Model,1.25,field.Color) end end end)
  elseif entry.Id=="LanternStaff" then local point=Instance.new("Part");point.Name="LanternBurst";point.Anchored=true;point.CanCollide=false;point.CanQuery=false;point.Transparency=1;point.Position=primaryCenter;point.Parent=Workspace;local light=Instance.new("PointLight");light.Range=20;light.Brightness=2;light.Color=Color3.fromRGB(220,239,167);light.Parent=point;Debris:AddItem(point,8) end
 end
 if #phaseTargets>0 then task.delay(.5,function()if not player.Parent then return end;effectPulse(primaryCenter,Color3.fromRGB(195,177,255),7,.35);for _,record in ipairs(phaseTargets) do if record.Model.Parent then deal(record.Model,record.Amount,"PhaseReturn") end end end) end
 if #targets>0 or family=="Staff" or canCastEmpty then gear:WearHeld(player,1) end
 if special and family=="Spear" and entry.Id~="FrostSpear" then
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={player.Character};params.RespectCanCollide=true
  local hit=Workspace:Blockcast(root.CFrame,Vector3.new(2,3,2),direction*3,params);root.CFrame+=direction*(hit and math.max(0,hit.Distance-.5) or 3)
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
			if action == "ChargeCancel" or action == "ChargeRelease" or action == "Special" then
				local draw=self._chargeStart[plr]
				if draw and draw.Tool then draw.Tool:SetAttribute("BowDrawStarted",nil) end
			end
			if action == "ChargeCancel" then
				self._chargeStart[plr] = nil
				return
			end
			if GameStateService:IsGameOver() or (ReplicatedStorage:GetAttribute("WorldShifting") and not plr:GetAttribute("InteriorId")) then
				return
			end
			local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 or plr:GetAttribute("IsDead") then return end
			self:_overhaul(plr,action,data)
		end)
	end

	_G.Ecoshift = _G.Ecoshift or {}
	_G.Ecoshift.ApplyDamage = function(attacker, target, amount, dmgType)
		CombatService:ApplyDamage(attacker, target, amount, dmgType)
	end
end

return CombatService
