-- Persistent region encounters. Rolls belong to a visit/cell, never a load request.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local SS=game:GetService("ServerStorage")
local Tags=game:GetService("CollectionService")
local Catalog=require(RS.Shared.OverhaulBiomes)
local Codec=require(script.Parent.WorldSnapshotCodec)
local Art=require(script.Parent.Parent.Art.OverhaulCreatures)
local Service={_actors={},_started=false}
local hpRole={L=2.5,O=4,H=8,S=1.25,N=2.5}
local damageRole={L=.75,O=1,H=1.25,S=.375,N=0}
local capRole={L=4,O=3,H=1,S=5,N=3}
local function hash(text,seed) local n=seed or 7919;for i=1,#text do n=(n*33+string.byte(text,i))%2147483647 end;return n end
local function folder(parent,name) local f=parent:FindFirstChild(name);if not f then f=Instance.new("Folder");f.Name=name;f.Parent=parent end;return f end
function Service:EnsurePrefabs()
 if self._prefabsReady then return end
 self._prefabsReady=true
 local root=folder(SS,"EnemyPrefabs")
 root:ClearAllChildren()
 for id in pairs(Catalog.Creatures) do if not root:FindFirstChild(id,true) then local model=Art.Create(id);model.Parent=root end end
end
function Service:_track(model,memberId)
 if not memberId then return end
 self._actors[memberId]=model
 local hum=model:FindFirstChildOfClass("Humanoid")
 hum.Died:Connect(function()
  local world=require(script.Parent.OverhaulWorldService);local record=world._encounters and world._encounters[memberId]
  if record then record.Cleared=true;record.Actor=nil end
 end)
 model.Destroying:Connect(function() if self._actors[memberId]==model then self._actors[memberId]=nil end end)
end
function Service:BindRestored(model,state)
 local definition=Catalog.Creatures[model:GetAttribute("EntityId")]
 if definition then Tags:AddTag(model,definition.Role=="N" and "Animal" or "Monster") end
 if state and state.EncounterMemberId then model:SetAttribute("EncounterMemberId",state.EncounterMemberId) end
 self:_track(model,model:GetAttribute("EncounterMemberId"))
 require(script.Parent.EntityAIService):BindEntity(model)
 return model
end
function Service:Spawn(id,position,tier,pressure,memberId,state,interior)
 local def=Catalog.Creatures[id];if not def then return nil end
 local model=Art.Create(id);tier=math.clamp(math.floor(tier or 1),1,8);pressure=math.clamp(pressure or 0,0,1)
 local hp=18*2^(tier-1)*hpRole[def.Role]*(1+pressure*.25)
 local damage=({8,12,18,27,41,62,93,140})[tier]*damageRole[def.Role]*(1+pressure*.15)
 model:SetAttribute("Level",1+5*(tier-1)+math.floor(pressure*4));model:SetAttribute("CampaignTier",tier);model:SetAttribute("SpawnPressure",pressure)
 model:SetAttribute("Damage",damage);model:SetAttribute("LevelHealthApplied",true);model:SetAttribute("OverhaulCreature",true);model:SetAttribute("EncounterMemberId",memberId);model:SetAttribute("InteriorId",interior)
 local region=require(script.Parent.OverhaulWorldService):MetadataAt(position);model:SetAttribute("RegionDepth",region and region.Depth or 1)
 local hum=model:FindFirstChildOfClass("Humanoid");hum.MaxHealth=hp;hum.Health=hp
 model:PivotTo(CFrame.new(position+Vector3.new(0,4,0)))
 if state then Codec.ApplyActor(model,state) end
 self:_track(model,memberId)
 model.Parent=folder(workspace,"Enemies");Tags:AddTag(model,def.Role=="N" and "Animal" or "Monster")
 require(script.Parent.EntityAIService):BindEntity(model)
 model.PrimaryPart:SetNetworkOwner(nil)
 return model
end
function Service:_population()
 local alive=0;for _,p in ipairs(Players:GetPlayers()) do if not p:GetAttribute("IsDead") and not p:GetAttribute("InteriorId") and not p:GetAttribute("WorldPlayerLoading") then alive+=1 end end
 local hostile,neutral=0,0
 for _,m in ipairs((workspace:FindFirstChild("Enemies") or folder(workspace,"Enemies")):GetChildren()) do
  local h=m:FindFirstChildOfClass("Humanoid")
  if h and h.Health>0 and not m:GetAttribute("InteriorId") then if m:GetAttribute("CreatureRole")=="N" then neutral+=1 else hostile+=1 end end
 end
 return math.min(24,math.max(4,alive*4))-hostile,math.min(12,alive*3)-neutral,alive
end
local function habitat(world,id,p)
 local water=world:GetWaterLevel(p.X,p.Z);local underwater=water and world:GetHeight(p.X,p.Z)<water
 if id=="ReefEel" or id=="LanternEel" or id=="Silverfish" then return underwater end
 return not underwater and world:IsSafe(p,4)
end
function Service:Tick()
 if RS:GetAttribute("WorldRestoring") or RS:GetAttribute("WorldShifting") or require(script.Parent.GameStateService):IsGameOver() then return end
 local world=require(script.Parent.OverhaulWorldService);if not world._visitSeed then return end
 local hostileRoom,neutralRoom,crew=self:_population();if crew==0 then return end
 local elapsed=require(script.Parent.BiomeService):GetElapsed();local tier=RS:GetAttribute("CampaignThreatTier") or 1;local pressure=RS:GetAttribute("CampaignPressure") or 0
 world._encounters=world._encounters or {}
 -- Park distant actors with exact health/state rather than allowing reload rerolls.
 for id,m in pairs(self._actors) do
  if m.Parent and not m:GetAttribute("InteriorId") then
   local nearest=math.huge
   for _,p in ipairs(Players:GetPlayers()) do local r=p.Character and p.Character:FindFirstChild("HumanoidRootPart");if r and not p:GetAttribute("InteriorId") then nearest=math.min(nearest,(r.Position-m:GetPivot().Position).Magnitude) end end
   if nearest>550 then local record=world._encounters[id];if record then record.Actor=Codec.Actor(m) end;m:SetAttribute("Unloading",true);m:Destroy() end
  end
 end
 for _,p in ipairs(Players:GetPlayers()) do
  local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
  if not root or p:GetAttribute("IsDead") or p:GetAttribute("InteriorId") or p:GetAttribute("WorldPlayerLoading") then continue end
  local cx,cz=math.floor(root.Position.X/240),math.floor(root.Position.Z/240)
  for dx=-1,1 do for dz=-1,1 do
   local key="encounter:"..(cx+dx)..","..(cz+dz);local rng=Random.new(hash(key,world:GetSeed()))
   local x,z=(cx+dx)*240+rng:NextNumber(45,195),(cz+dz)*240+rng:NextNumber(45,195)
   local position=Vector3.new(x,world:GetHeight(x,z),z);local distance=(position-root.Position).Magnitude
   if distance<65 or distance>300 or Vector2.new(x,z).Magnitude<240 or Vector2.new(x,z).Magnitude>1470 then continue end
   local region=world:MetadataAt(position);if not region then continue end
   local records=world._encounters;local encounter=records[key]
   if not encounter then
    local biome=Catalog.Biomes[region.Biome];local pool={};local total=0
    for i,id in ipairs(biome.Creatures) do if habitat(world,id,position) then total+=region.Weights[i];table.insert(pool,{Id=id,Weight=region.Weights[i]}) end end
    if total<=0 then continue end
    local ids={};local pairIndex=(region.Biome=="AuroraVale" or region.Biome=="SaltglassCoast") and 2 or 3
    if rng:NextNumber()<region.Mixed and habitat(world,biome.Creatures[1],position) and habitat(world,biome.Creatures[pairIndex],position) then ids={biome.Creatures[1],biome.Creatures[pairIndex]}
    else
     local roll=rng:NextNumber()*total;local id=pool[#pool].Id
     for _,entry in ipairs(pool) do roll-=entry.Weight;if roll<=0 then id=entry.Id;break end end
     local role=Catalog.Creatures[id].Role;local cap=capRole[role]
     if role~="N" then cap=math.min(cap,tier==1 and 2 or tier<=4 and 3 or role=="S" and 5 or 4) end
     local count=rng:NextInteger(math.min(cap,region.GroupMin),math.min(cap,region.GroupMax))
     for _=1,count do table.insert(ids,id) end
    end
    encounter={Ids=ids,Tier=tier,Pressure=pressure};records[key]=encounter
   end
   for index,id in ipairs(encounter.Ids or {}) do
    local memberId=key..":"..index;local member=records[memberId]
    if not member then member={Id=id};records[memberId]=member end
    if member.Cleared or self._actors[memberId] then continue end
    local role=Catalog.Creatures[id].Role
    if role=="N" and neutralRoom<=0 or role~="N" and (hostileRoom<=0 or elapsed<90) then continue end
    local offset=Vector3.new((index-1)*7,0,0);local spot=position+offset
    if not habitat(world,id,spot) then continue end
    if role=="N" then neutralRoom-=1 else hostileRoom-=1 end
    self:Spawn(id,Vector3.new(spot.X,world:GetHeight(spot.X,spot.Z),spot.Z),encounter.Tier,encounter.Pressure,memberId,member.Actor)
   end
  end end
 end
end
function Service:SpawnProjectDefense(position,count,tier,encounterId)
 local world=require(script.Parent.OverhaulWorldService);local result={};local room=self:_population()
 for index=1,math.min(count,math.max(0,room)) do
  local angle=index/math.max(1,count)*math.pi*2;local spot=position+Vector3.new(math.cos(angle)*70,0,math.sin(angle)*70)
  if Vector2.new(spot.X,spot.Z).Magnitude<240 then spot=Vector3.new(math.cos(angle)*250,0,math.sin(angle)*250) end
  spot=world:SafePosition(spot)-Vector3.new(0,5,0);world:EnsureArea(spot)
  local region=world:MetadataAt(spot);local species=Catalog.Biomes[region.Biome].Creatures[1]
  if Catalog.Creatures[species].Role=="N" then species="Wolf" end
  local model=self:Spawn(species,spot,tier,0,"project:"..encounterId..":"..index)
  if model then model:SetAttribute("ProjectDefense",encounterId);model:SetAttribute("ProjectGoal",position);table.insert(result,model) end
 end
 return result
end
function Service:SpawnCreative(id,position,level)
 if workspace:GetAttribute("WorldType")~="Creative" or not Catalog.Creatures[id] then return nil end
 local count=0
 for _,model in ipairs(folder(workspace,"Enemies"):GetChildren()) do
  local hum=model:FindFirstChildOfClass("Humanoid")
  if hum and hum.Health>0 then count+=1 end
 end
 if count>=24 then return nil end
 level=math.clamp(math.floor(level),1,40)
 return self:Spawn(id,position,1+math.floor((level-1)/5),((level-1)%5)/4)
end
function Service:Init()
 if self._started then return end;self._started=true;self:EnsurePrefabs()
 _G.Ecoshift=_G.Ecoshift or {};_G.Ecoshift.SpawnEnemyById=function(id,position) return self:Spawn(id,typeof(position)=="Vector3" and position or position.Position,RS:GetAttribute("CampaignThreatTier") or 1,RS:GetAttribute("CampaignPressure") or 0) end
end
return Service
