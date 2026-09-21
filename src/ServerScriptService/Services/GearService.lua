-- Functional gear is evaluated from server-owned item instances, never client stats.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Collection = game:GetService("CollectionService")
local Instances = require(RS.Shared.ItemInstance)
local WeaponSpecialCooldown = require(RS.Shared.Weapons.WeaponSpecialCooldown)
local Inventory = require(script.Parent.InventoryService)
local Stats = require(script.Parent.StatsService)
local ServerUtil = require(script.Parent.ServerUtil)
local Gear = {}
local runtime = setmetatable({}, {__mode="k"})
local function catalog() return require(RS.Shared.OverhaulCatalog) end
local function active() return Instances.IsOverhaul() end
local function state(player)
 if not runtime[player] then runtime[player] = {Timers={},Visit=0,LastThreadVisit=-1,Survey={},LastHitAge=999} end
 return runtime[player]
end
local function alive(player)
 return ServerUtil.IsLiving(player) and not RS:GetAttribute("WorldRestoring") and (not RS:GetAttribute("WorldShifting") or player:GetAttribute("InteriorId"))
end
local function visit() return RS:GetAttribute("BiomeVisitSerial") or workspace:GetAttribute("BiomeVisitSerial") or 0 end
local function nearCamp(player)
 local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local center = workspace:GetAttribute("CampCenter") or RS:GetAttribute("CampCenter") or Vector3.zero
 return root and Vector2.new(root.Position.X-center.X,root.Position.Z-center.Z).Magnitude <= 200
end
local function entries(player, includeStorage)
 local inv, result = Inventory:GetAll(player), {}
 for _, kind in ipairs(includeStorage and {"Hotbar","Storage","Equipment","Accessory"} or {"Equipment","Accessory"}) do
  for _,entry in pairs(inv[kind] or {}) do if type(entry)=="table" then result[#result+1]=entry end end
 end
 return result
end
function Gear:GetDefinition(entry) return active() and catalog().Gear[type(entry)=="table" and entry.Id or entry] or nil end
function Gear:GetItemByUid(player, uid)
 if type(uid) ~= "string" then return nil end
 for _,entry in ipairs(entries(player,true)) do if entry.Uid == uid then return entry end end
end
function Gear:GetHeld(player)
 if not active() then return nil end
 local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
 if not tool then return nil end
 local uid = tool:GetAttribute("GearUid")
 for _,entry in pairs(Inventory:GetAll(player).Hotbar) do
  if entry and ((uid and entry.Uid == uid) or (not uid and entry.Id==tool.Name)) then return entry,self:GetDefinition(entry),tool end
 end
end
local function functional(entry) return entry and (tonumber(entry.Durability) or 1)>0 end
local function rank(entry,id)
 local v = entry and entry.Enchantments and entry.Enchantments[id]
 return functional(entry) and math.max(0, math.floor(tonumber(type(v)=="table" and (v.Level or v.Rank) or v) or 0)) or 0
end
function Gear:GetEnchantLevel(player,id)
 if not active() then return 0 end
 local maximum=0
 for _,entry in ipairs(entries(player,false)) do maximum=math.max(maximum,rank(entry,id)) end
 local held=self:GetHeld(player); return math.max(maximum,rank(held,id))
end
function Gear:EnchantValue(player,id)
 local level=self:GetEnchantLevel(player,id)
 local definition=active() and catalog().Enchantments[id]
 return definition and (definition.Values or {})[level] or 0
end
function Gear:GetHeldEnchantValue(player,id)
 if not active() then return 0 end
 local entry=self:GetHeld(player)
 local level=rank(entry,id)
 local definition=catalog().Enchantments[id]
 return definition and (definition.Values or {})[level] or 0
end
function Gear:GetHeldEnchantLevel(player,id)
 if not active() then return 0 end
 return rank(self:GetHeld(player),id)
end
local function merge(result, additions, scale)
 for key,value in pairs(additions or {}) do
  if type(value)=="number" then result[key]=(result[key] or 0)+value*((string.find(key,"Cooldown") or string.find(key,"Seconds") or string.find(key,"Threshold")) and 1 or (scale or 1))
  elseif value then result[key]=value end
 end
end
function Gear:GetModifiers(player)
 if not active() then return {} end
 local result,sets,awakened,accessoryFamilies = {},{},{},{}
 local inv=Inventory:GetAll(player)
 for _,entry in pairs(inv.Equipment or {}) do
  local definition=self:GetDefinition(entry)
  if definition and functional(entry) then
   merge(result,definition.Modifiers)
   if definition.Set then sets[definition.Set]=(sets[definition.Set] or 0)+1; if entry.Awakened then awakened[definition.Set]=(awakened[definition.Set] or 0)+1 end end
  end
 end
 for _,entry in pairs(inv.Accessory or {}) do
  local definition=self:GetDefinition(entry)
  if definition and functional(entry) and not accessoryFamilies[definition.Family or entry.Id] then
   accessoryFamilies[definition.Family or entry.Id]=true; merge(result,definition.Modifiers)
  end
 end
 for set,count in pairs(sets) do
  local definition=catalog().ArmorFamilies[set]
  local bonuses=definition and (definition.SetBonuses or definition.Bonuses or definition)
  if bonuses and count>=2 then merge(result,bonuses.Two) end
  if bonuses and count>=4 then merge(result,bonuses.Four,awakened[set]==4 and 1.5 or 1) end
 end
 local current=state(player)
 if (current.Timers.DrinkMove or 0)>0 then result.WalkSpeedBonus=(result.WalkSpeedBonus or 0)+.1 end
 if (current.Timers.EnchantMove or 0)>0 then result.WalkSpeedBonus=(result.WalkSpeedBonus or 0)+(current.EnchantMoveBonus or 0) end
 if (current.Timers.AuroraRecovery or 0)>0 then result.ExposureRecovery=(result.ExposureRecovery or 0)+.15 end
 return result
end
function Gear:GetDefense(player)
 if not active() then return nil end
 local defense,resist,accessoryRes=0,{Heat=0,Cold=0,Toxin=0,Wet=0},{Heat=0,Cold=0,Toxin=0,Wet=0}
 local inv=Inventory:GetAll(player)
 local tiers={.08,.18,.30,.42,.54,.64,.73,.80}
 for _,entry in pairs(inv.Equipment or {}) do
  local def=self:GetDefinition(entry)
  if def and functional(entry) then
   local amount=def.Defense or 0
   if amount>1 then amount/=100 end
   if def.Set and (entry.Grade or def.Grade)>def.Grade then amount*=tiers[entry.Grade]/tiers[def.Grade] end
   defense+=amount
   for key,value in pairs(def.Resistance or {}) do resist[key]=(resist[key] or 0)+(value>1 and value/100 or value) end
  end
 end
 local scarf=false
 for _,entry in pairs(inv.Accessory or {}) do
  local def=self:GetDefinition(entry)
  if def and functional(entry) then
   if entry.Id=="WarmScarf" then scarf=true end
   for key in pairs(accessoryRes) do
    local value=(def.Resistance or {})[key] or (def.Modifiers or {})[key.."Resistance"] or 0
    accessoryRes[key]+=value>1 and value/100 or value
   end
  end
 end
 for key in pairs(resist) do resist[key]=math.min(.90,resist[key]+math.min(key=="Cold" and scarf and .30 or .15,accessoryRes[key])) end
 return math.min(.85,defense),resist
end
function Gear:Touch(player) Inventory:Sync(player) end
function Gear:Refresh(player)
 if not active() then return end
 local defense,resistance=self:GetDefense(player)
 Stats:RemoveModifier(player,"Armor","ArmorEquip")
 Stats:RemoveModifier(player,"TemperatureResistance","TempResEquip")
 Stats:AddModifier(player,"Armor",defense*100,"Add",nil,"OverhaulArmor")
 local char=player.Character
 if char then for key,value in pairs(resistance) do char:SetAttribute("GearRes_"..key,value) end end
 local modifiers=self:GetModifiers(player)
 local old=state(player).Published or {}
 for key in pairs(old) do if modifiers[key]==nil then player:SetAttribute("Gear_"..key,nil) end end
 for key,value in pairs(modifiers) do if type(value)=="number" or type(value)=="boolean" then player:SetAttribute("Gear_"..key,value) end end
 state(player).Published=modifiers
 Inventory:RefreshCapacity(player)
 -- A small hands-free lamp follows the torso and uses normal world lighting.
 if char then
  local root=char:FindFirstChild("HumanoidRootPart")
  if root then
   local light=root:FindFirstChild("GearLantern")
   if modifiers.LightRadius then
    if not light then light=Instance.new("PointLight");light.Name="GearLantern";light.Parent=root end
    light.Range=math.min(60,(modifiers.LightRadius or 24)*(1+(modifiers.LightRadiusBonus or 0)));light.Brightness=1.4;light.Color=Color3.fromRGB(255,220,155)
   elseif light then light:Destroy() end
  end
 end
end
function Gear:Wear(player,entry,amount)
 if not active() or not entry then return end
 local definition=self:GetDefinition(entry)
 if not definition or definition.Kind=="Accessory" or not entry.Durability then return end
 local current=state(player)
 local modifiers=self:GetModifiers(player)
 amount*=1-(definition.Kind=="Armor" and (modifiers.ArmorWearReduction or 0) or (modifiers.WeaponWearReduction or 0))
 entry.State=entry.State or {}
 if (entry.State.ThreadRemaining or 0)>0 then return end
 if entry.Durability>0 and entry.Durability-amount<=0 and rank(entry,"LastThread")>0 and current.LastThreadVisit~=visit() then
  entry.Durability=1;entry.State.ThreadRemaining=8;current.LastThreadVisit=visit()
 else entry.Durability=math.max(0,entry.Durability-amount) end
 self:Touch(player)
end
function Gear:WearHeld(player,amount) local entry=self:GetHeld(player);self:Wear(player,entry,amount) end
function Gear:Repair(player,uid,fraction)
 local entry=self:GetItemByUid(player,uid)
 if not entry or not entry.MaxDurability or entry.Durability>=entry.MaxDurability then return false end
 entry.Durability=math.min(entry.MaxDurability,entry.Durability+entry.MaxDurability*math.clamp(fraction,0,1))
 if entry.State then entry.State.ThreadRemaining=nil end
 self:Touch(player);return true
end
function Gear:HarvestPower(player,node,basePower)
 if not active() then return basePower end
 local entry=self:GetHeld(player)
 if entry and not functional(entry) then return 0 end
 local current=state(player)
 local now=os.clock()
 local target=node and (node:GetAttribute("EntityId") or node:GetAttribute("NodeId") or tostring(node))
 current.HarvestChain=(current.HarvestTarget==target and now-(current.HarvestAt or 0)<4) and (current.HarvestChain or 0)+1 or 1
 current.HarvestTarget,current.HarvestAt=target,now
 local bonus=0
 local level=rank(entry,"OpenSeam")
 if level>0 and current.HarvestChain%3==0 then bonus=({.15,.25,.35,.45})[level] or 0;node:SetAttribute("OpenSeamUntil",workspace:GetServerTimeNow()+.4) end
 local class= (player:GetAttribute("Class_GatherPower") or 0)+(player:GetAttribute("ClassHarvestPower") or 0)+(player:GetAttribute("Food_ResourcePowerBonus") or 0)
 if node and node:GetAttribute("ResourceKind")=="Mineral" then class+=(player:GetAttribute("Class_MineralPower") or 0)+(player:GetAttribute("ClassMineralPower") or 0) end
 return basePower*(1+math.clamp(class+bonus,0,.75))
end
function Gear:GetGatherReduction(player,isPlant)
 if isPlant==false then return 0 end
 if not active() then return 0 end
 local entry,definition=self:GetHeld(player)
 if not functional(entry) then return 0 end
 local reduction=definition and ((definition.Modifiers or {}).HandGatherReduction or definition.HandGatherReduction or definition.GatherReduction or 0) or 0
 if (state(player).Timers.CleanCut or 0)>0 then reduction+=({.1,.15,.2})[rank(entry,"CleanCut")] or 0 end
 return reduction
end
function Gear:OnGatherStarted(player,isPlant)
 if isPlant then state(player).Timers.CleanCut=nil end
end
function Gear:OnHarvestComplete(player,node,drops)
 if not active() then return end
 local entry=self:GetHeld(player)
 if rank(entry,"CleanCut")>0 and node:GetAttribute("ResourceKind")=="Plant" then state(player).Timers.CleanCut=5 end
 local level=rank(entry,"QuickStow")
 if level>0 and type(drops)=="table" then
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if root and (node:GetPivot().Position-root.Position).Magnitude<=({6,10})[level] then
   local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={player.Character,node}
   if not workspace:Raycast(root.Position,node:GetPivot().Position-root.Position,params) then
    for _,drop in ipairs(drops) do if not drop.Rare and not drop.Secondary then local added=Inventory:GiveEntry(player,drop,false);drop.N-=added end end
   end
  end
 end
end
function Gear:BasicHitBonus(player,target,baseDamage)
 if not active() then return 0 end
 local entry=self:GetHeld(player);local current=state(player)
 local definition=self:GetDefinition(entry)
 local bonus=0
 if (current.Timers.ReturnShot or 0)>0 then
  if definition and definition.WeaponFamily=="Bow" then bonus+=baseDamage*(({.10,.15,.20,.25})[rank(entry,"ReturnShot")] or 0);current.Timers.ReturnShot=0 end
 end
 if (current.Timers.GuardReturnStrike or 0)>0 and definition and definition.WeaponFamily=="Sword" then
  bonus+=baseDamage*(({.12,.18,.25})[rank(entry,"GuardReturn")] or 0);current.Timers.GuardReturnStrike=nil
 end
 return bonus
end
function Gear:OnSpecialHit(player,target,baseDamage)
 if not active() then return 0 end
 local entry=self:GetHeld(player);local current=state(player);local extra=0
 local level=rank(entry,"VentStrike")
 if level>0 and math.abs(Stats:GetBase(player,"Temperature") or 0)>=25 then self:RestoreExposure(player,({4,7,10})[level] or 0) end
 if (current.Timers.StormCharge or 0)>0 then extra=baseDamage*(({.12,.20})[rank(entry,"StormLatch")] or 0);current.Timers.StormCharge=0 end
 return extra
end
function Gear:RestoreExposure(player,amount)
 local value=Stats:GetBase(player,"Temperature") or 0
 Stats:SetBase(player,"Temperature",value>0 and math.max(0,value-amount) or math.min(0,value+amount))
end
function Gear:OnConsumable(player,oldTemperature,hungerOverflow,drink)
 if not active() then return end
 local current=state(player);local entry=(Inventory:GetAll(player).Equipment or {})[2]
 local level=rank(entry,"HeatStore")
 if level>0 and math.abs(oldTemperature)-math.abs(Stats:GetBase(player,"Temperature") or 0)>=20 then current.HeatBuffer=({8,12})[level];current.HeatDirection=oldTemperature>0 and 1 or -1;current.Timers.HeatBuffer=90 end
 local saved=self:GetEnchantLevel(player,"SavedMeal")
 if saved>0 then current.SavedHunger=math.min(saved==1 and 10 or 20,(current.SavedHunger or 0)+math.max(0,hungerOverflow or 0)) end
 if drink and (self:GetModifiers(player).DrinkMoveBonus or 0)>0 and not current.Timers.DrinkCooldown then current.Timers.DrinkMove=5;current.Timers.DrinkCooldown=20 end
end
function Gear:OnRevive(player)
 if not active() then return end
 local current=state(player)
 if self:GetEnchantLevel(player,"RescueReserve")>0 and not current.Timers.Rescue then
  Stats:SetBase(player,"Stamina",math.min(Stats:GetStat(player,"MaxStamina") or 100,(Stats:GetBase(player,"Stamina") or 0)+15));self:RestoreExposure(player,15);current.Timers.Rescue=60
 end
end
function Gear:AdjustExposure(player,delta)
 if not active() then return delta end
 local current=state(player)
 if self:GetEnchantLevel(player,"HeatStore")>0 and current.HeatBuffer and (current.Timers.HeatBuffer or 0)>0 and delta*current.HeatDirection>0 then
  local absorbed=math.min(math.abs(delta),current.HeatBuffer);current.HeatBuffer-=absorbed;delta-=absorbed*current.HeatDirection
 end
 delta*=self:GetChannelMultiplier(player,delta>=0 and "Heat" or "Cold")
 return delta
end
function Gear:GetChannelMultiplier(player,channel)
 local current=state(player)
 return self:GetEnchantLevel(player,"WeatherMemory")>0 and (current.Timers.WeatherMemory or 0)>0 and current.MemoryChannel==channel and .85 or 1
end
function Gear:BeforeMonsterDamage(player,attacker,damage)
 if not active() then return damage end
 local current=state(player)
 if (current.Timers.DodgeInvulnerability or 0)>0 then
  local held,definition=self:GetHeld(player)
  if definition and definition.WeaponFamily=="Bow" and not current.Timers.ReturnShotCooldown and rank(held,"ReturnShot")>0 then current.Timers.ReturnShot=3;current.Timers.ReturnShotCooldown=8 end
  if definition and definition.WeaponFamily=="Dagger" and not current.Timers.SlipCutCooldown and rank(held,"SlipCut")>0 then current.Timers.SlipCut=2;current.Timers.SlipCutCooldown=6 end
  return 0
 end
 local held,definition=self:GetHeld(player)
 local guardLevel=definition and definition.WeaponFamily=="Sword" and rank(held,"GuardReturn") or 0
 if guardLevel>0 and (current.Timers.SwordGuard or 0)>0 then
  damage*=1-(({.25,.35,.45})[guardLevel] or 0)
  current.Timers.SwordGuard=nil;current.Timers.GuardReturnStrike=4
 end
 local briarLevel=held and held.Id=="ThornBlade" and rank(held,"BriarDebt") or 0
 if briarLevel>0 then
  local normal=definition and definition.Damage or 0
  local cap=normal*(({.25,.45})[briarLevel] or 0)
  current.BriarDebt=math.min(cap,(current.BriarDebt or 0)+damage*(({.10,.18})[briarLevel] or 0))
 end
 local modifiers=self:GetModifiers(player)
 if current.LastHitAge>=20 and modifiers.FirstHitReduction then damage*=1-modifiers.FirstHitReduction end
 current.LastHitAge=0
 local worn={}
 for _,entry in pairs(Inventory:GetAll(player).Equipment or {}) do if functional(entry) then worn[#worn+1]=entry end end
 if #worn>0 then self:Wear(player,worn[math.random(#worn)],1) end
 local warning=self:GetEnchantLevel(player,"PackWarning")
 if warning>0 and not current.Timers.PackWarning then
  current.Timers.PackWarning=20
  local markers={};local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  for _,monster in ipairs(Collection:GetTagged("Monster")) do
   if root and monster.Name==attacker.Name and (monster:GetPivot().Position-root.Position).Magnitude<=40 and #markers<(warning==1 and 3 or 5) then markers[#markers+1]={Position=monster:GetPivot().Position,Name=monster.Name,Expires=8} end
  end
  if Gear.Remote then Gear.Remote:FireClient(player,"Warnings",markers) end
 end
 return damage*(1-(player:GetAttribute("Food_MonsterDamageReduction") or 0))
end
function Gear:AfterMonsterDamage(player)
 if not active() then return end
 local current=state(player);local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 if hum and hum.Health>0 and hum.Health<25 and self:GetModifiers(player).SurvivorHeal and not current.Timers.Survivor then current.Timers.Survivor=180;current.Timers.SurvivorHeal=5 end
end
function Gear:CapturePlayer(player)
 local current=state(player)
 local result={Burn=require(script.Parent.StatusService):CapturePlayer(player),ToxinStacks=player.Character and player.Character:GetAttribute("ToxinStacks") or 0,Medical=Instances.Copy(current.Medical),MedicalCooldown=current.MedicalCooldown,Timers=Instances.Copy(current.Timers),Visit=current.Visit,LastThreadVisit=current.LastThreadVisit,Survey=Instances.Copy(current.Survey),LastHitAge=current.LastHitAge,HeatBuffer=current.HeatBuffer,HeatDirection=current.HeatDirection,SavedHunger=current.SavedHunger,Air=current.Air,AirReserveSpent=current.AirReserveSpent,MemoryChannel=current.MemoryChannel,QualifiedSeen=current.QualifiedSeen}
 return result
end
function Gear:RestorePlayer(player,saved)
 if type(saved)~="table" then return end
 local entry=Instances.Copy(saved);entry.Timers=entry.Timers or {};entry.Survey=entry.Survey or {};entry.LastHitAge=entry.LastHitAge or 999
 for key,value in pairs(entry.Timers) do if type(value)~="number" or value~=value then entry.Timers[key]=nil else entry.Timers[key]=math.clamp(value,0,86400) end end
 runtime[player]=entry
 player:SetAttribute("MedicalItemCooldown",math.max(0,tonumber(entry.MedicalCooldown) or 0))
 require(script.Parent.StatusService):RestorePlayer(player,entry.Burn)
 if player.Character then player.Character:SetAttribute("ToxinStacks",math.clamp(tonumber(entry.ToxinStacks) or 0,0,100)) end
end
function Gear:GetSpecialRemaining(player,itemId)
 local key=WeaponSpecialCooldown.TimerKey(itemId)
 return key and (state(player).Timers[key] or 0) or 0
end
function Gear:StartSpecialCooldown(player,itemId,seconds)
 local key=WeaponSpecialCooldown.TimerKey(itemId);local attribute=WeaponSpecialCooldown.Attribute(itemId)
 if not key or not attribute then return end
 seconds=math.max(0,tonumber(seconds) or 0);state(player).Timers[key]=seconds>0 and seconds or nil
 player:SetAttribute(attribute,workspace:GetServerTimeNow()+seconds)
end
function Gear:AdjustSpecialCooldown(player,itemId,seconds)
 local key=WeaponSpecialCooldown.TimerKey(itemId);local attribute=WeaponSpecialCooldown.Attribute(itemId)
 if not key or not attribute then return end
 local current=state(player);current.Timers[key]=math.max(0,(current.Timers[key] or 0)-math.max(0,seconds or 0))
 player:SetAttribute(attribute,workspace:GetServerTimeNow()+(current.Timers[key] or 0))
end
function Gear:BeginSwordGuard(player) state(player).Timers.SwordGuard=.5 end
function Gear:ConsumeSlipCut(player)
 local current=state(player)
 if (current.Timers.SlipCut or 0)<=0 then return false end
 current.Timers.SlipCut=nil;return true
end
function Gear:GrantEnchantMove(player,bonus,seconds)
 local current=state(player);current.EnchantMoveBonus=current.Timers.EnchantMove and math.max(current.EnchantMoveBonus or 0,bonus or 0) or (bonus or 0);current.Timers.EnchantMove=math.max(current.Timers.EnchantMove or 0,seconds or 0)
end
function Gear:PrimeTailwind(player,reduction)
 local current=state(player);current.TailwindCostReduction=math.max(current.TailwindCostReduction or 0,reduction or 0);current.Timers.TailwindCost=4
end
function Gear:GetTailwindCostReduction(player)
 local current=state(player)
 return (current.Timers.TailwindCost or 0)>0 and (current.TailwindCostReduction or 0) or 0
end
function Gear:ConsumeTailwindCost(player)
 local current=state(player)
 if (current.Timers.TailwindCost or 0)<=0 then return 0 end
 current.Timers.TailwindCost=nil;local value=current.TailwindCostReduction or 0;current.TailwindCostReduction=nil;return value
end
function Gear:IsBraced(player)
 return (state(player).BraceStill or 0)>=.6
end
function Gear:ConsumeBrace(player)
 state(player).BraceStill=0
end
function Gear:ConsumeBriarDebt(player)
 local current=state(player);local value=current.BriarDebt or 0;current.BriarDebt=0;return value
end
function Gear:TryDodge(player,direction)
 if not active() or not alive(player) or typeof(direction)~="Vector3" or direction.Magnitude~=direction.Magnitude then return false,"Cannot dodge." end
 local current=state(player);local root=player.Character:FindFirstChild("HumanoidRootPart")
 if not root or current.Timers.Dodge then return false,"Dodge is recovering." end
 direction=Vector3.new(direction.X,0,direction.Z)
 if direction.Magnitude<.1 then return false,"Move in a direction to dodge." end
 direction=direction.Unit
 local cost=math.max(1,25-(self:GetModifiers(player).DodgeCostReduction or 0))*(1-(player:GetAttribute("Food_DodgeDrainReduction") or 0))
 local stamina=Stats:GetBase(player,"Stamina") or 0
 if stamina<cost then return false,"Not enough stamina." end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={player.Character}
 local hit=workspace:Blockcast(root.CFrame,Vector3.new(2,3,2),direction*9,params)
 local distance=hit and math.max(0,hit.Distance-.5) or 9
 if distance<1 then return false,"The path is blocked." end
 Stats:SetBase(player,"Stamina",stamina-cost)
 current.Timers.Dodge=2;current.Timers.DodgeInvulnerability=.18
 local elapsed=0;local connection
 local ok=pcall(function() root:SetNetworkOwner(nil) end)
 connection=RunService.Heartbeat:Connect(function(dt)
  elapsed+=dt
  if not root.Parent or elapsed>=.4 or not alive(player) then connection:Disconnect();if root.Parent and ok then pcall(function() root:SetNetworkOwnershipAuto() end) end;return end
  local frameDistance=math.min(distance/0.4*dt,distance)
  local obstacle=workspace:Blockcast(root.CFrame,Vector3.new(2,3,2),direction*frameDistance,params)
  if not obstacle then root.CFrame+=direction*frameDistance end
 end)
 return true
end
function Gear:UseMedical(player,kind,index,callback)
 local source=Inventory:PeekSlot(player,kind,index)
 local definition=source and catalog().Consumables[source.Id]
 if not definition or definition.Revive then return false,"Use a Revival Kit on a fallen teammate." end
 local current=state(player)
 if current.PendingMedical or (current.MedicalCooldown or 0)>0 then return false,"Finish your current treatment first." end
 local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 if not alive(player) then return false,"You cannot use this right now." end
 if definition.Health and hum.Health>=hum.MaxHealth then return false,"Health is full." end
 local target
 if definition.RepairFraction then
  for _,entry in ipairs(entries(player,true)) do
   local def=self:GetDefinition(entry)
   if def and entry.MaxDurability and entry.Durability<entry.MaxDurability and (entry.Grade or def.Grade)<=definition.Grade and ((definition.Kind=="Armor" and def.Kind=="Armor") or (definition.Kind=="ToolWeapon" and (def.Kind=="Tool" or def.Kind=="Weapon"))) then
    if not target or entry.Durability/entry.MaxDurability<target.Durability/target.MaxDurability then target=entry end
   end
  end
  if not target then return false,"No damaged gear fits this kit's grade." end
 end
 local modifiers=self:GetModifiers(player)
 current.PendingMedical={Kind=kind,Index=index,Id=source.Id,Target=target and target.Uid,Remaining=(definition.RepairFraction and 3 or definition.UseTime or 1)*(1-(self:GetModifiers(player).MedicalUseTimeReduction or 0)),Callback=callback,Character=player.Character}
 current.PendingMedical.Total=current.PendingMedical.Remaining
 if current.PendingMedical.Remaining==0 then self:_finishMedical(player) end
 return true,definition.RepairFraction and "Repairing the most damaged compatible item (3s)…" or "Applying treatment..."
end
function Gear:_finishMedical(player)
 local current=state(player);local pending=current.PendingMedical
 if not pending then return end
 current.PendingMedical=nil
 if not alive(player) or player.Character~=pending.Character then return end
 local def=catalog().Consumables[pending.Id]
 local target=pending.Target and self:GetItemByUid(player,pending.Target)
 if pending.Target and (not target or target.Durability>=target.MaxDurability) then return end
 if not Inventory:TakeFromSlot(player,pending.Kind,pending.Index,1,{ExpectedId=pending.Id}) then return end
 local modifiers=self:GetModifiers(player)
 current.MedicalCooldown=5;player:SetAttribute("MedicalItemCooldown",5)
 if def.RepairFraction then self:Repair(player,target.Uid,def.RepairFraction*(1+(modifiers.FieldRepairBonus or 0)))
 elseif def.Health then current.Medical={Id=pending.Id,Remaining=def.Duration,Rate=def.Health/def.Duration*(1+(player:GetAttribute("Class_HealBonus") or 0))*(1+(modifiers.MedicalHealingBonus or 0))*(1+(modifiers.MedicalHotBonus or 0))}
 elseif def.ClearPoison then
  player.Character:SetAttribute("PoisonStacks",0);player.Character:SetAttribute("ToxinStacks",0);player.Character:SetAttribute("PoisonUntil",nil);current.Timers.Antidote=120
 elseif def.ClearWetness then player.Character:SetAttribute("WetStacks",0);current.Timers.DryingSalve=120
 elseif def.ExposureRelief then self:RestoreExposure(player,def.ExposureRelief);current.Timers.RecoveryTonic=60 end
 require(script.Parent.ExpeditionRewardsService):RecordActivity(player)
 if pending.Callback then pending.Callback(true,"Treatment complete.") end
end
function Gear:_tickTraversal(player,dt)
 local current=state(player);local char=player.Character;local root=char and char:FindFirstChild("HumanoidRootPart");local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not root or not hum then return end
 local modifiers=self:GetModifiers(player)
 local moving=hum.MoveDirection.Magnitude>.1 or Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude>.75
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={char};params.RespectCanCollide=true
 local shelter=require(script.Parent.UtilityBuildService):GetShelter(root.Position,player.Character)
 local roof=shelter and {Instance=shelter} or nil
 local weather=tostring(RS:GetAttribute("CurrentWeather") or workspace:GetAttribute("Weather") or "")
 local rain=string.find(string.lower(weather),"rain") or string.find(string.lower(weather),"storm")
 local wet=rain and not player:GetAttribute("InteriorId") and not roof
 local swimming=hum:GetState()==Enum.HumanoidStateType.Swimming
 player:SetAttribute("GearRoofShelter",roof~=nil)
 if self:GetEnchantLevel(player,"DryStep")>0 then
  if current.WasWet and not wet and not swimming and roof then current.Timers.DryStep=10 end
  if wet or swimming then current.Timers.DryStep=nil end
  player:SetAttribute("Gear_DryStepRecovery",current.Timers.DryStep and (({.2,.35,.5})[self:GetEnchantLevel(player,"DryStep")] or 0) or 0)
 end
 current.WasWet=wet or swimming
 local held=self:GetHeld(player)
 if rank(held,"StormLatch")>0 and wet and not current.Timers.StormCharge then
  current.StormExposure=(current.StormExposure or 0)+dt
  if current.StormExposure>=30 then current.StormExposure=0;current.Timers.StormCharge=60 end
 elseif not wet then current.StormExposure=0 end
 local temperature=Stats:GetBase(player,"Temperature") or 0
 local direction=temperature>0 and 1 or temperature<0 and -1 or 0
 if modifiers.TemperatureTransitionRecoveryBonus and direction~=0 and current.TemperatureDirection and current.TemperatureDirection~=direction and not current.Timers.Aurora then current.Timers.AuroraRecovery=8;current.Timers.Aurora=30 end
 if direction~=0 then current.TemperatureDirection=direction end
 local shelterBonus=0
 if roof then
  for _,other in ipairs(Players:GetPlayers()) do
   local otherRoot=other.Character and other.Character:FindFirstChild("HumanoidRootPart")
   if other~=player and alive(other) and otherRoot and (otherRoot.Position-root.Position).Magnitude<=10 then
    local otherParams=RaycastParams.new();otherParams.FilterType=Enum.RaycastFilterType.Exclude;otherParams.FilterDescendantsInstances={char,other.Character};otherParams.RespectCanCollide=true
    local otherRoof=workspace:Raycast(otherRoot.Position,Vector3.new(0,60,0),otherParams)
    local wall=workspace:Raycast(root.Position,otherRoot.Position-root.Position,otherParams)
    if otherRoof and otherRoof.Instance:IsDescendantOf(roof.Instance) and not wall then shelterBonus=math.max(shelterBonus,({.08,.12})[math.max(self:GetEnchantLevel(player,"SharedCover"),self:GetEnchantLevel(other,"SharedCover"))] or 0) end
   end
  end
 end
 player:SetAttribute("Gear_SharedCover",shelterBonus)
 local stamina=Stats:GetBase(player,"Stamina") or 0
 local cost=0
 if swimming and moving then cost+=4*(1-(modifiers.SwimDrainReduction or 0)) end
 if (hum:GetState()==Enum.HumanoidStateType.Climbing or current.Traversing) and moving and stamina>0 then
  local surface=workspace:Raycast(root.Position,root.CFrame.LookVector*4,params)
  if modifiers.Climb and surface and (surface.Instance:GetAttribute("Climbable") or Collection:HasTag(surface.Instance,"Climbable")) then
   cost+=8*(1-(modifiers.ClimbDrainReduction or 0));current.Gliding=false
   root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,12,root.AssemblyLinearVelocity.Z)
  end
 end
 if current.Gliding and modifiers.Glide and stamina>0 and hum.FloorMaterial==Enum.Material.Air and not swimming then
  local velocity=root.AssemblyLinearVelocity
  if velocity.Y<0 then
   local horizontal=Vector3.new(velocity.X,0,velocity.Z);local desired=hum.MoveDirection.Magnitude>.1 and hum.MoveDirection*math.max(20,horizontal.Magnitude) or horizontal
   horizontal=horizontal:Lerp(desired,math.clamp(dt*2*(1+(modifiers.GlideTurnBonus or 0)),0,1))
   root.AssemblyLinearVelocity=Vector3.new(horizontal.X,math.max(-10,velocity.Y),horizontal.Z);cost+=(modifiers.GlideDrain or 6)*(1-(modifiers.GlideDrainReduction or 0)) else current.Gliding=false end
 elseif current.Gliding then current.Gliding=false end
 player:SetAttribute("GearGliding",current.Gliding==true)
 local onIce=hum.FloorMaterial==Enum.Material.Ice
 local feet={char:FindFirstChild("LeftFoot"),char:FindFirstChild("RightFoot"),char:FindFirstChild("Left Leg"),char:FindFirstChild("Right Leg")}
 current.FootPhysics=current.FootPhysics or {}
 for _,foot in pairs(feet) do
  if foot then
   if onIce and modifiers.IceGrip then
    if current.FootPhysics[foot]==nil then current.FootPhysics[foot]=foot.CustomPhysicalProperties or false end
    foot.CustomPhysicalProperties=PhysicalProperties.new(.7,1,0,100,1)
   elseif current.FootPhysics[foot]~=nil then local original=current.FootPhysics[foot];foot.CustomPhysicalProperties=original or nil;current.FootPhysics[foot]=nil end
  end
 end
 if root:FindFirstChild("WorldEventLift") and (modifiers.LowGravityControlBonus or 0)>0 then
  local v=root.AssemblyLinearVelocity;local flat=Vector3.new(v.X,0,v.Z);local desired=hum.MoveDirection*hum.WalkSpeed
  flat=flat:Lerp(desired,math.clamp(dt*3*modifiers.LowGravityControlBonus,0,1));root.AssemblyLinearVelocity=Vector3.new(flat.X,v.Y,flat.Z)
 end
 player:SetAttribute("GearTraversalStaminaActive",cost>0)
 if cost>0 then Stats:SetBase(player,"Stamina",math.max(0,stamina-cost*dt)) end
 -- Tanks are item-owned finite reservoirs: surfacing refills lungs, never tanks.
 local tank
 for _,entry in pairs(Inventory:GetAll(player).Accessory or {}) do local def=self:GetDefinition(entry);if def and (def.Modifiers or {}).AirSeconds then tank=entry;entry.State=entry.State or {};if entry.State.Air==nil then entry.State.Air=def.Modifiers.AirSeconds end end end
 current.Air=current.Air or 30
 local submerged=swimming
 if swimming then
  local head=char:FindFirstChild("Head")
  if head then
   local grid=Vector3.new(math.floor(head.Position.X/4)*4,math.floor(head.Position.Y/4)*4,math.floor(head.Position.Z/4)*4)
   local materials,occupancies=workspace.Terrain:ReadVoxels(Region3.new(grid,grid+Vector3.new(4,4,4)),4)
   submerged=materials[1][1][1]==Enum.Material.Water and occupancies[1][1][1]>.5
  end
 end
 if submerged then
  local drain=dt*(1-(modifiers.AirDrainReduction or 0))*(1-(player:GetAttribute("Food_AirDrainReduction") or 0))
  if player:GetAttribute("PressureZone") then drain*=2*(1-(modifiers.PressureAirReduction or 0)) end
  current.Air=math.max(0,current.Air-drain)
  if current.Air<=0 and tank and (tank.State.Air or 0)>0 then local amount=math.min(tank.State.Air,drain);tank.State.Air-=amount;current.Air=amount end
  local level=self:GetEnchantLevel(player,"AirPocket")
  local total=30+(tank and (self:GetDefinition(tank).Modifiers.AirSeconds or 0) or 0)
  if level>0 and not current.AirReserveSpent and current.Air+(tank and tank.State.Air or 0)<total*.25 then current.Air+=({15,25,35})[level] or 0;current.AirReserveSpent=true end
  if current.Air<=0 then hum:TakeDamage(8*dt) end
 else current.Air=math.min(30,current.Air+10*dt) end
 player:SetAttribute("GearAirSeconds",math.ceil(current.Air+(tank and tank.State.Air or 0)))
 -- Landing damage reads the actual fall, without changing ordinary jump height.
 if hum.FloorMaterial==Enum.Material.Air and not swimming then current.FallTop=math.max(current.FallTop or root.Position.Y,root.Position.Y)
 elseif current.FallTop then
  local fall=current.FallTop-root.Position.Y;current.FallTop=nil
  if fall>24 and not current.Gliding then current.Timers.Landing=(.35*(1-(modifiers.LandingRecoveryReduction or 0)));hum:TakeDamage((fall-24)*1.5*(1-math.clamp(modifiers.FallDamageReduction or 0,0,.8))) end
 end
 player:SetAttribute("GearLandingSlow",current.Timers.Landing~=nil)
 local world=script.Parent:FindFirstChild("OverhaulWorldService")
 local map=script.Parent:FindFirstChild("TeamExplorationService")
 if world and map and self:GetEnchantLevel(player,"SurveyLink")>0 then
  local metadata=require(world):MetadataAt(root.Position)
  if metadata and metadata.Id and not current.Survey[metadata.Id] then
   current.Survey[metadata.Id]=true
   local mapService=require(map)
   if mapService.RevealRadius then mapService:RevealRadius(root.Position,self:GetEnchantLevel(player,"SurveyLink")==1 and 12 or 20) end
  end
 end
end
local function nearbyStation(player,types,grade)
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if not root then return nil end
 for _,station in ipairs(Collection:GetTagged("Structure")) do
  if station:IsDescendantOf(workspace) and (station:IsA("Model") or station:IsA("BasePart")) then
   local kind=station:GetAttribute("StationType") or station:GetAttribute("BuildType") or station.Name
   if table.find(types,kind) and (tonumber(station:GetAttribute("StationGrade")) or tonumber(station:GetAttribute("Grade")) or 1)>=grade and (station:GetPivot().Position-root.Position).Magnitude<=12 then return station end
  end
 end
end
function Gear:StoreWater(player,amount)
 local remaining=amount
 local inventory=Inventory:GetAll(player)
 for _,container in ipairs({inventory.Accessory or {},inventory.Hotbar or {}}) do
  for _,entry in pairs(container) do
   local def=self:GetDefinition(entry)
   if def and (def.Modifiers or {}).WaterUses then
    entry.State=entry.State or {};local stored=entry.State.Water or 0
    local add=math.min(remaining,math.max(0,def.Modifiers.WaterUses-stored));entry.State.Water=stored+add;remaining-=add
   end
  end
 end
 if remaining<amount then self:Touch(player) end
 return amount-remaining
end
function Gear:DrinkFlask(player)
 local current=state(player)
 if current.Timers.Flask then return false,"Wait before drinking again." end
 local temperature=Stats:GetBase(player,"Temperature") or 0
 if temperature<=0 then return false,"You have no heat exposure to cool." end
 local inventory=Inventory:GetAll(player)
 for _,container in ipairs({inventory.Accessory or {},inventory.Hotbar or {}}) do
  for _,entry in pairs(container) do
   if entry.Id=="WaterFlask" and (entry.State or {}).Water and entry.State.Water>0 then
    entry.State.Water-=1;current.Timers.Flask=3
    self:RestoreExposure(player,30+(self:GetModifiers(player).WaterExposureBonus or 0));self:OnConsumable(player,temperature,0,true);self:Touch(player)
    return true,"Drank from flask · "..entry.State.Water.."/5 uses left."
   end
  end
 end
 return false,"Equip your flask and gather water to fill it."
end
function Gear:RequestMaintenance(player,uid,action,grade)
 local current=state(player);local entry=self:GetItemByUid(player,uid);local def=entry and self:GetDefinition(entry)
 if current.Maintenance then return false,"Finish current maintenance first." end
 if not def or not nearCamp(player) then return false,"Bring your gear to camp." end
 local stations=def.Kind=="Armor" and {"Loom","RepairBench"} or {"Anvil","RepairBench"}
 if action=="Reforge" or action=="Awaken" then local family=def.Set and catalog().ArmorFamilies[def.Set]; if family then stations={family.Station or "Loom"} end end
 local requiredGrade=entry.Grade or def.Grade
 if action=="Refill" then stations={"Workbench","RepairBench"};requiredGrade=1
 elseif action=="CampStitch" then stations={"Loom","Anvil","RepairBench"} end
 local station=nearbyStation(player,stations,requiredGrade)
 if not station then return false,"Requires nearby "..stations[1].." grade "..requiredGrade.."." end
 local costs,work,result={},5,{}
 if action=="Refill" and ((def.Modifiers or {}).AirSeconds or rank(entry,"AirPocket")>0) then costs={{Id="Water",N=1},{Id="Coal",N=1}};work=10;result.Refill=true;result.Air=(def.Modifiers or {}).AirSeconds
 elseif action=="CampStitch" then
  local level=rank(entry,"CampStitch")
  if level==0 or (entry.State or {}).CampStitchVisit==visit() or not entry.MaxDurability or entry.Durability>=entry.MaxDurability then return false,"Camp Stitch is not available for this item." end
  costs={{Id="Resin",N=1}};work=10;result.Stitch=({.04,.07,.10})[level]
 elseif action=="Reforge" then
  local tier=tonumber(RS:GetAttribute("CampaignTier")) or 1
  grade=math.floor(tonumber(grade) or requiredGrade+1)
  if def.Kind~="Armor" or not def.Set or grade<=requiredGrade or grade>tier or grade>8 then return false,"Choose a higher unlocked armor grade." end
  station=nearbyStation(player,stations,grade);if not station then return false,"Requires a grade "..grade.." station." end
  costs={{Id=catalog().MaterialByTier[grade],N=math.ceil((def.MaterialCost or 2)*.75)},{Id=catalog().ClothByTier[grade],N=math.ceil((def.ClothCost or 2)*.75)}};work=15;result.Grade=grade
 elseif action=="Awaken" then
  local family=def.Set and catalog().ArmorFamilies[def.Set]
  if not family or requiredGrade~=8 or entry.Awakened then return false,"Requires an unawakened grade 8 armor piece." end
  costs={{Id=family.Trophy,N=1}};work=15;result.Awaken=true
 else
  if not entry.MaxDurability or entry.Durability>=entry.MaxDurability then return false,"This item needs no repair." end
  local fraction=(entry.MaxDurability-entry.Durability)/entry.MaxDurability
  local materialCost=def.MaterialCost or (def.Kind=="Tool" and 3 or def.WeaponFamily=="Bow" and 2 or 4)
  costs={{Id=catalog().MaterialByTier[requiredGrade],N=math.max(1,math.ceil(.2*fraction*materialCost))}}
  if def.Kind=="Armor" then costs[#costs+1]={Id=catalog().ClothByTier[requiredGrade],N=math.max(1,math.ceil(.2*fraction*(def.ClothCost or 2)))} end
  result.Repair=true
 end
 if not Inventory:CanAfford(player,costs) then return false,"Missing maintenance materials." end
 -- Materials remain in inventory until completion, so disconnects and cancellations need no refund or duplicate escrow.
 current.Maintenance={Uid=uid,Station=station,Costs=costs,Work=work,Progress=0,Result=result,Visit=visit(),Character=player.Character}
 return true,"Maintenance started; materials are consumed when it finishes."
end
function Gear:_tickMaintenance(player,dt)
 local current=state(player);local job=current.Maintenance
 if not job then player:SetAttribute("GearMaintenanceProgress",nil);return end
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local entry=self:GetItemByUid(player,job.Uid)
 if not entry or not root or player.Character~=job.Character or not job.Station.Parent or (job.Station:GetPivot().Position-root.Position).Magnitude>12 then current.Maintenance=nil;return end
 local rate=math.min(2,1+(player:GetAttribute("Class_CraftSpeed") or 0)+(player:GetAttribute("Class_CraftRate") or 0))
 job.Progress+=dt*rate;player:SetAttribute("GearMaintenanceProgress",math.min(1,job.Progress/job.Work))
 if job.Progress<job.Work then return end
 current.Maintenance=nil
 if not Inventory:PayCost(player,job.Costs,true) then if self.Remote then self.Remote:FireClient(player,"Result",{Success=false,Message="Materials moved; maintenance cancelled."}) end;return end
 entry.State=entry.State or {}
 if job.Result.Refill then if job.Result.Air then entry.State.Air=job.Result.Air end;current.Air=30;current.AirReserveSpent=false
 elseif job.Result.Stitch then entry.Durability=math.min(entry.MaxDurability,entry.Durability+entry.MaxDurability*job.Result.Stitch);entry.State.CampStitchVisit=job.Visit
 elseif job.Result.Grade then entry.Grade=job.Result.Grade;entry.MaxDurability=180+25*(entry.Grade-1);entry.Durability=entry.MaxDurability
 elseif job.Result.Awaken then entry.Awakened=true
 elseif job.Result.Repair then entry.Durability=entry.MaxDurability end
 entry.State.ThreadRemaining=nil
 self:Touch(player)
 if self.Remote then self.Remote:FireClient(player,"Result",{Success=true,Message="Maintenance complete."}) end
end
function Gear:Init()
 if self.Initialized then return end
 self.Initialized=true
 local remotes=RS:WaitForChild("Remotes")
 local remote=remotes:FindFirstChild("GearAction") or Instance.new("RemoteEvent")
 remote.Name,remote.Parent="GearAction",remotes;self.Remote=remote
 remote.OnServerEvent:Connect(function(player,action,payload)
  if not active() or not alive(player) then return end
  if action=="Glide" then local current=state(player);current.Traversing=not current.Traversing;current.Gliding=current.Traversing;return end
  if action=="DrinkFlask" then local ok,message=self:DrinkFlask(player);remote:FireClient(player,"Result",{Success=ok,Message=message});return end
  if (action=="Refill" or action=="RepairStation" or action=="CampStitch" or action=="Reforge" or action=="Awaken") and type(payload)=="table" then local ok,message=self:RequestMaintenance(player,payload.Uid,action,payload.Grade);remote:FireClient(player,"Result",{Success=ok,Message=message});return end
  if action=="Dodge" then local ok,message=self:TryDodge(player,type(payload)=="table" and payload.Direction);remote:FireClient(player,"Result",{Success=ok,Message=message}) end
 end)
 Inventory:OnChanged(function(player) self:Refresh(player) end)
 local accumulator=0
 RunService.Heartbeat:Connect(function(dt)
  if not active() then return end
  accumulator+=dt;if accumulator<.1 then return end;dt=math.min(accumulator,.5);accumulator=0
  for _,player in ipairs(Players:GetPlayers()) do
   if not alive(player) then local stopped=state(player);stopped.PendingMedical=nil;stopped.Maintenance=nil;if player:GetAttribute("IsDead") then stopped.Medical=nil;stopped.Gliding=nil end;continue end
   local current=state(player);current.LastHitAge+=dt
   local held,heldDefinition=self:GetHeld(player)
   local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
   local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
   if heldDefinition and heldDefinition.WeaponFamily=="Spear" and rank(held,"Brace")>0 and root and hum then
    local horizontal=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude
    current.BraceStill=horizontal<1 and hum.MoveDirection.Magnitude<.05 and math.min(1,(current.BraceStill or 0)+dt) or 0
   else current.BraceStill=0 end
   if current.PendingMedical then current.PendingMedical.Remaining-=dt;player:SetAttribute("GearTreatmentProgress",1-current.PendingMedical.Remaining/current.PendingMedical.Total);if current.PendingMedical.Remaining<=0 then self:_finishMedical(player) end else player:SetAttribute("GearTreatmentProgress",nil) end
   current.MedicalCooldown=math.max(0,(current.MedicalCooldown or 0)-dt)
   player:SetAttribute("MedicalItemCooldown",current.MedicalCooldown)
   if current.Medical then
    local hum=player.Character:FindFirstChildOfClass("Humanoid");local treatment=current.Medical;local amount=math.min(dt,treatment.Remaining)*treatment.Rate
    hum.Health=math.min(hum.MaxHealth,hum.Health+amount);treatment.Remaining-=dt;if treatment.Remaining<=0 then current.Medical=nil end
   end
   player:SetAttribute("Gear_ToxinTonic",current.Timers.Antidote and .35 or 0)
   player:SetAttribute("Gear_WetTonic",current.Timers.DryingSalve and .25 or 0)
   player:SetAttribute("Gear_TonicRecovery",current.Timers.RecoveryTonic and .5 or 0)
   for key,remaining in pairs(current.Timers) do
    local nextRemaining=remaining>dt and remaining-dt or nil
    current.Timers[key]=nextRemaining
    local itemId=WeaponSpecialCooldown.ItemId(key)
    if itemId then player:SetAttribute(WeaponSpecialCooldown.Attribute(itemId),workspace:GetServerTimeNow()+(nextRemaining or 0)) end
   end
   player:SetAttribute("DodgeCooldown",current.Timers.Dodge or 0)
   player:SetAttribute("Gear_GatherTimeReduction",self:GetGatherReduction(player,true))
   for _,entry in ipairs(entries(player,true)) do
    if entry.State and entry.State.ThreadRemaining then
     entry.State.ThreadRemaining-=dt
     if entry.State.ThreadRemaining<=0 then entry.State.ThreadRemaining=nil;entry.Durability=0;self:Touch(player) end
    end
   end
   if self:GetEnchantLevel(player,"SavedMeal")>0 and current.SavedHunger and current.SavedHunger>0 and (Stats:GetBase(player,"Hunger") or 0)<50 then local amount=math.min(dt,current.SavedHunger);current.SavedHunger-=amount;Stats:SetBase(player,"Hunger",(Stats:GetBase(player,"Hunger") or 0)+amount) end
   local hum=player.Character:FindFirstChildOfClass("Humanoid")
   if current.Timers.SurvivorHeal and hum then hum.Health=math.min(hum.MaxHealth,hum.Health+2*dt) end
   local biome=RS:GetAttribute("CurrentBiome")
   if current.Visit~=visit() then
    current.Visit=visit();current.QualifiedSeen=false;current.Survey={};current.Timers.StormCharge=nil;current.StormExposure=0
    local head=(Inventory:GetAll(player).Equipment or {})[1]
    if head and head.State and (head.State.WeatherMemories or {})[biome] then current.Timers.WeatherMemory=({30,45,60})[rank(head,"WeatherMemory")];current.MemoryChannel=head.State.WeatherMemories[biome] end
   end
   local head=(Inventory:GetAll(player).Equipment or {})[1]
   if not player:GetAttribute("InteriorId") and not current.QualifiedSeen and RS:GetAttribute("BiomeVisitQualified") then current.QualifiedSeen=true; if head and rank(head,"WeatherMemory")>0 then head.State=head.State or {};head.State.WeatherMemories=head.State.WeatherMemories or {};if biome then local ambient=require(script.Parent.ChunkStreamingService):GetRegionTempAtPosition(player.Character.HumanoidRootPart.Position)
     local weather=require(script.Parent.BiomeService):GetWeather()
     head.State.WeatherMemories[biome]=ambient>0 and "Heat" or ambient<0 and "Cold" or (biome=="Swamp" or biome=="MyceliumHollow" or (weather.Toxin or 0)>(weather.Wet or 0)) and "Toxin" or "Wet" end end end
   self:_tickMaintenance(player,dt)
   self:_tickTraversal(player,dt)
  end
 end)
 Players.PlayerRemoving:Connect(function(player)
  -- Preserve timers and gear runtime until the departure snapshot completes.
  task.defer(function() runtime[player]=nil end)
 end)
end
return Gear
