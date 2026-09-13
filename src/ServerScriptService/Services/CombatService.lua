-- CombatService.lua (expanded)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local StatsService = require(script.Parent.StatsService)
local GameStateService = require(script.Parent.GameStateService)

local Instances=require(ReplicatedStorage.Shared.ItemInstance)
local CombatService = {}
local acceptedCast=setmetatable({}, {__mode="k"})
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
		if dmgType ~= "ClassTurret" and not acceptedCast[attackerPlayer] and not canHit(attackerPlayer) then return end
		if dmgType ~= "ClassTurret" and not distanceOK(attackerPlayer, target, 175) then return end
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
function CombatService:_overhaul(player,action,data)
 local gear=require(script.Parent.GearService)
 local entry,def,tool=gear:GetHeld(player)
 if not entry or not def or not tool or (entry.Durability or 1)<=0 then return end
 if player:GetAttribute("WorldPlayerLoading") or player:GetAttribute("WorldPlayerRestoring") or ReplicatedStorage:GetAttribute("WorldRestoring") then return end
 local root=getRoot(player.Character);if not root then return end
 local family=def.WeaponFamily
 if def.Kind=="Tool" and entry.Id~="Harvester" then return end
 local special=action=="Special"
 if action=="ChargeStart" and family=="Bow" then self._chargeStart[player]={Tool=tool,Started=os.clock()};return end
 if not special and action~="Attack" and action~="Fire" and action~="ChargeRelease" then return end
 local direction=getValidatedAimDirection(data) or root.CFrame.LookVector
 if direction.Magnitude<.01 then return end
 local touch=data and data.Touch==true
 local width=2.5*(touch and 1.15 or 1)
 local reach=def.Reach or 8
 if family~="Bow" and family~="Staff" then reach+=touch and .75 or 0;direction=Vector3.new(direction.X,0,direction.Z);if direction.Magnitude<.01 then return end;direction=direction.Unit end
 local now=os.clock()
 local modifiers=gear:GetModifiers(player)
 if special and (def.Kind~="Weapon" or gear:GetSpecialRemaining(player)>0) then return end
 local damage=def.Damage or 6
 local base=def.StandardDamage or damage
 if family=="Bow" and not special then
  local charge=self._chargeStart[player];self._chargeStart[player]=nil
  if not charge or charge.Tool~=tool or now-charge.Started<.15 then return end
  damage=base*1.2*math.clamp((now-charge.Started)/1.3,.25,1)
 end
 local targets
 if family=="Staff" then
  local rayParams=RaycastParams.new();rayParams.FilterType=Enum.RaycastFilterType.Exclude;rayParams.FilterDescendantsInstances={player.Character}
  local ray=Workspace:Raycast(root.Position,direction*reach,rayParams)
  local at=ray and ray.Position or root.Position+direction*reach
  targets=special and viableTargets(player,direction,reach,width,7,at) or viableTargets(player,direction,reach,touch and 1.15 or 1)
 else targets=viableTargets(player,direction,special and family=="Hammer" and 10 or reach,special and family=="Hammer" and 10 or width,nil,nil,special and family=="Bow") end
 if special and #targets==0 then if self._remoteFeedback then self._remoteFeedback:FireClient(player,{Type="Message",Message="No visible target in special range."}) end;return end
 if not special and not self:_canUseTool(tool,def.AttackCycle or .6,true) then return end
 local cost=special and 20*(1-(modifiers.SpecialCostReduction or 0))*(1-(player:GetAttribute("Food_SpecialDrainReduction") or 0)) or family=="Staff" and 3 or 0
 local stamina=StatsService:GetBase(player,"Stamina") or 0
 if stamina<cost then return end
 if family=="Bow" and not require(script.Parent.InventoryService):Consume(player,"Arrow",1) then return end
 if cost>0 then StatsService:SetBase(player,"Stamina",stamina-cost) end
 if special then gear:StartSpecialCooldown(player,8*(1-(modifiers.SpecialCooldownReduction or 0)));damage=def.SpecialDamage or base*(def.SpecialFactor or 1.5) end
 local maximum=special and (def.SpecialTargets or 1) or 1
 if special and entry.Id=="StormBow" then maximum=1 end
 if special and family=="Staff" then maximum=8 end
 acceptedCast[player]=true
 local extra=special and gear:OnSpecialHit(player,targets[1].Model,base) or 0
 for i,target in ipairs(targets) do
  if i>maximum then break end
  local amount=damage+(i==1 and extra or 0)
  if special and entry.Id=="EmberAxe" then amount=base*1.2+(i==1 and extra or 0)
  elseif special and entry.Id=="ThornBlade" then amount=base*.8+(i==1 and extra or 0)
  elseif special and entry.Id=="StormBow" then amount=base*1.2+extra end
  if not special then amount+=gear:BasicHitBonus(player,target.Model,base) end
  self:ApplyDamage(player,target.Model,amount,family=="Bow" and "Bow" or family=="Staff" and "Gun" or "Melee")
  if special then
   local monster=target.Model
   if entry.Id=="EmberAxe" or entry.Id=="ThornBlade" then
    local seconds=entry.Id=="EmberAxe" and 4 or 3
    local generation=(monster:GetAttribute("GearDotSerial") or 0)+1;monster:SetAttribute("GearDotSerial",generation)
    task.spawn(function()
     for _=1,seconds do
      task.wait(1)
      if not monster.Parent or monster:GetAttribute("GearDotSerial")~=generation then return end
      acceptedCast[player]=true;self:ApplyDamage(player,monster,base*.1,"GearDamageOverTime");acceptedCast[player]=nil
     end
    end)
   elseif entry.Id=="LanternStaff" then
    local point=Instance.new("Part");point.Name="LanternBurst";point.Anchored=true;point.CanCollide=false;point.CanQuery=false;point.Transparency=1;point.Position=monster:GetPivot().Position;point.Parent=workspace
    local light=Instance.new("PointLight");light.Range=20;light.Brightness=2;light.Color=Color3.fromRGB(220,239,167);light.Parent=point;game:GetService("Debris"):AddItem(point,8)
   elseif entry.Id=="GravityHammer" and not monster:GetAttribute("IsBoss") then
    local targetRoot=getRoot(monster);local toward=targetRoot and root.Position-targetRoot.Position
    if toward and toward.Magnitude>2 then
     local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={monster,player.Character};params.RespectCanCollide=true
     local movement=Vector3.new(toward.X,0,toward.Z).Unit*2
     if not workspace:Blockcast(targetRoot.CFrame,Vector3.new(2,3,2),movement,params) then monster:PivotTo(monster:GetPivot()+movement) end
    end
   end
   if family=="Dagger" or entry.Id=="FrostSpear" or entry.Id=="RootStaff" then monster:SetAttribute("GearSlowFactor",.8);monster:SetAttribute("GearSlowUntil",Workspace:GetServerTimeNow()+3) end
   if (family=="Axe" or family=="Hammer") and not monster:GetAttribute("IsBoss") then monster:SetAttribute("GearStaggerUntil",Workspace:GetServerTimeNow()+(family=="Hammer" and .7 or .5)) end
  end
 end
 if special and entry.Id=="StormBow" and targets[1] then
  local center=targets[1].Model:GetPivot().Position
  for _,neighbor in ipairs(viableTargets(player,direction,reach,width,10,center)) do
   if neighbor.Model~=targets[1].Model then self:ApplyDamage(player,neighbor.Model,base*.4,"Bow");break end
  end
 end
 acceptedCast[player]=nil
 if #targets>0 or family=="Bow" or family=="Staff" then gear:WearHeld(player,1) end
 if special and family=="Spear" and entry.Id~="FrostSpear" then
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={player.Character};params.RespectCanCollide=true
  local hit=Workspace:Blockcast(root.CFrame,Vector3.new(2,3,2),direction*3,params)
  root.CFrame+=direction*(hit and math.max(0,hit.Distance-.5) or 3)
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
