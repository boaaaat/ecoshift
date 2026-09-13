-- Reusable recover, repair, escort, defend, clear, survey and puzzle activities.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Tags=game:GetService("CollectionService")
local Debris=game:GetService("Debris")
local Definitions=require(RS.Shared.EventsConfig)
local Codec=require(script.Parent.WorldSnapshotCodec)
local Service={_scenes={}}
local function vector(a) return Vector3.new(a[1],a[2],a[3]) end
local function part(parent,name,p,size,color)
 local object=Instance.new("Part");object.Name=name;object.Size=size or Vector3.new(4,4,4);object.CFrame=CFrame.new(p);object.Color=color or Color3.fromRGB(171,155,106);object.Anchored=true;object.Material=Enum.Material.SmoothPlastic;object.Parent=parent;return object
end
local function living(player)
 local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 return h and h.Health>0 and not player:GetAttribute("IsDead") and not player:GetAttribute("InteriorId") and not player:GetAttribute("WorldPlayerLoading") and not RS:GetAttribute("WorldRestoring") and not RS:GetAttribute("WorldShifting")
end
local function close(player,p,distance)
 local r=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 return living(player) and r and (r.Position-p).Magnitude<=(distance or 12)
end
local function prompt(scene,anchor,label,callback)
 local p=Instance.new("ProximityPrompt");p.ActionText=label;p.ObjectText=scene.Def.Name;p.HoldDuration=1;p.MaxActivationDistance=9;p.RequiresLineOfSight=false;p.KeyboardKeyCode=Enum.KeyCode.F;p.Parent=anchor
 local holds={}
 p.PromptButtonHoldBegan:Connect(function(player) if close(player,anchor.Position) then holds[player]=os.clock() end end)
 p.Triggered:Connect(function(player)
  local begin=holds[player];holds[player]=nil
  if not scene.Closed and not scene.State.Completed and scene.Entry.Data.Elapsed>=scene.Entry.Data.Warning and close(player,anchor.Position) and begin and os.clock()-begin>=.9 and os.clock()-begin<4 then
   callback(player,p);require(script.Parent.ExpeditionRewardsService):RecordActivity(player)
  end
 end)
 return p
end
function Service:_advance(scene,index)
 if scene.Closed or scene.State.Claims[tostring(index)] then return false end
 scene.State.Claims[tostring(index)]=true
 local total=0;for _ in pairs(scene.State.Claims) do total+=1 end
 scene.State.Progress=math.min(1,total/(scene.Required or 3))
 local objective=require(script.Parent.ObjectiveService)
 local active=objective._active[scene.Entry.Id]
 if active then objective:Advance(scene.Entry.Id,math.max(0,scene.State.Progress-(active.Data.Progress or 0))) end
 if scene.State.Progress>=1 then scene.State.Completed=true end
 return true
end
function Service:_finish(scene)
 if scene.State.Completed then return end
 scene.State.Completed=true;scene.State.Progress=1
 require(script.Parent.ObjectiveService):Complete(scene.Entry.Id)
end
function Service:_node(scene,index,id,offset,breakable)
 if scene.State.Claims[tostring(index)] then return end
 local world=require(script.Parent.OverhaulWorldService)
 scene.State.NodePositions=scene.State.NodePositions or {}
 local savedPosition=scene.State.NodePositions[tostring(index)]
 local position=savedPosition and vector(savedPosition) or world:SafePosition(scene.Origin+offset)-Vector3.new(0,5,0)
 scene.State.NodePositions[tostring(index)]={position.X,position.Y,position.Z}
 local resources=scene.Folder:FindFirstChild("Resources") or Instance.new("Folder");resources.Name="Resources";resources.Parent=scene.Folder
 local node=world:_resource(id,"event:"..scene.Entry.Data.InstanceId..":"..index,position,resources,Random.new(index*573+89))
 if not node then return end
 node:SetAttribute("ObjectiveId",scene.Entry.Id)
 node:SetAttribute("ObjectiveInstanceId",scene.Entry.Data.InstanceId)
 if breakable then node:SetAttribute("Duration",0) end
 node.Destroying:Connect(function()if not scene.Closed and not node:GetAttribute("Unloading") then self:_advance(scene,index) end end)
 require(script.Parent.ResourceNodeService):BindFolder(resources)
 table.insert(scene.Nodes,node)
end
function Service:_actors(scene,count,elite,wildlife)
 scene.Actors=scene.Actors or {};scene.State.Actors=scene.State.Actors or {}
 scene.State.ActorSpec=scene.State.ActorSpec or {Count=count,Elite=elite==true,Wildlife=wildlife==true,Tier=RS:GetAttribute("CampaignThreatTier") or 1}
 local spec=scene.State.ActorSpec;count=spec.Count;elite=spec.Elite;wildlife=spec.Wildlife
 local hostileRoom,neutralRoom=require(script.Parent.EnemySpawner):_population()
 local room=math.max(0,wildlife and neutralRoom or hostileRoom)
 if scene.Def.Template=="Clear" or scene.Def.Template=="Defend" then scene.Required=count end
 for i=1,count do
  local key=tostring(i);local saved=scene.State.Actors[key]
  if saved==false or scene.Actors[key] and scene.Actors[key].Parent then continue end
  if room<=0 then break end
  local world=require(script.Parent.OverhaulWorldService);local region=world:MetadataAt(scene.Origin)
  local species=require(RS.Shared.OverhaulBiomes).Biomes[region.Biome].Creatures
  local id=wildlife and species[4] or species[1]
  if not wildlife and require(RS.Shared.OverhaulBiomes).Creatures[id].Role=="N" then id=species[3] end
  local position=world:SafePosition(scene.Origin+Vector3.new(i*8,0,20))-Vector3.new(0,5,0)
  local model=require(script.Parent.EnemySpawner):Spawn(id,position,spec.Tier,0,nil,type(saved)=="table" and saved or nil)
  if model then
   room-=1
   model:SetAttribute("EventInstanceId",scene.Entry.Data.InstanceId);model:SetAttribute("EventIndex",i)
   if scene.Entry.Id=="CampWarning" then model:SetAttribute("ProjectDefense","CampWarning");model:SetAttribute("ProjectGoal",Vector3.zero) end
   if elite and not saved then
    local tier=spec.Tier;local h=model:FindFirstChildOfClass("Humanoid");h.MaxHealth=16*18*2^(tier-1);h.Health=h.MaxHealth;model:SetAttribute("Elite",true)
    -- Rebind damage from immutable spawn values; no level-derived movement changes.
    model:SetAttribute("Damage",({8,12,18,27,41,62,93,140})[tier]*1.5)
   end
   scene.Actors[key]=model
   model:FindFirstChildOfClass("Humanoid").Died:Connect(function()
    scene.State.Actors[key]=false
    if not scene.Closed and not wildlife and (scene.Def.Template=="Clear" or scene.Def.Template=="Defend") then self:_advance(scene,"enemy"..key) end
   end)
  end
 end
end
function Service:Start(entry,restored)
 local data=entry.Data;local definition=Definitions.Definitions[entry.Id]
 local f=Instance.new("Folder");f.Name=data.InstanceId;f.Parent=workspace:FindFirstChild("WorldEvents") or workspace
 local scene={Entry=entry,Def=definition,State=data.State,Origin=vector(data.Position),Folder=f,Nodes={},Actors={},Required=3}
 self._scenes[data.InstanceId]=scene;scene.State.Claims=scene.State.Claims or {}
 local world=require(script.Parent.OverhaulWorldService);world:EnsureArea(scene.Origin)
 local marker=part(f,definition.Name.." signal",scene.Origin+Vector3.new(0,7,0),Vector3.new(2,12,2),Color3.fromRGB(225,176,79));marker.Material=Enum.Material.Neon;marker.CanCollide=false
 marker:SetAttribute("ObjectiveId",entry.Id);marker:SetAttribute("ObjectiveInstanceId",data.InstanceId);marker:SetAttribute("MapLabel",definition.Name);marker.Transparency=1
 scene.Signal=marker
 if not scene.State.Completed then
  local rewards={};local catalog=require(RS.Shared.OverhaulCatalog)
  for _,reward in ipairs(definition.Rewards or {}) do
   local resource=catalog.Resources[reward.Id]
   local allowed=not resource or (not resource.Biome or resource.Biome=="Common" or resource.Biome==require(RS.Shared.OverhaulBiomes).Biomes[data.Biome].DisplayName)
   local depth=resource and (type(resource.Depth)=="string" and string.byte(resource.Depth)-64 or resource.Depth) or 1
   if allowed and (not depth or depth<=data.Depth) then table.insert(rewards,reward) end
  end
  if #rewards==0 then rewards={{Id="Bandage",N=1},{Id="Water",N=2}} end
  scene.Objective={InstanceId=data.InstanceId,Biome=data.Biome,State="Active",Data={Progress=scene.State.Progress or 0},Rewards=rewards,Schematic=definition.Schematic}
 end
 if data.Elapsed>=data.Warning then self:_activate(scene) end
end
function Service:_activate(scene)
 if scene.Activated or scene.Closed then return end;scene.Activated=true
 if scene.State.Completed then
  if scene.Def.Template=="Repair" and scene.State.Repaired then part(scene.Folder,"Repaired crossing",scene.Origin+Vector3.new(0,1,0),Vector3.new(12,2,36)) end
  return
 end
 local kind=scene.Def.Template;local origin=scene.Origin;local f=scene.Folder;local state=scene.State
 if scene.Objective then require(script.Parent.ObjectiveService):Start(scene.Entry.Id,scene.Objective) end
 if kind=="Gather" then for i,id in ipairs({"Mushroom","HealingHerb","Fiber"}) do self:_node(scene,i,id,Vector3.new((i-2)*14,0,8),false) end
 elseif kind=="Break" then
  local id=scene.Entry.Id=="RootOutbreak" and "LivingRoot" or scene.Entry.Id=="DeepRumbling" and "LightOre" or "Stone"
  for i=1,3 do self:_node(scene,i,id,Vector3.new((i-2)*12,0,8),true) end
 elseif kind=="Recover" then
  scene.Required=1;local cache=part(f,"Signal cache",origin+Vector3.new(0,2,0),Vector3.new(6,4,4))
  prompt(scene,cache,"Recover supplies",function(_,p)if self:_advance(scene,1) then p.Enabled=false;cache.Transparency=.7 end end)
 elseif kind=="Repair" then
  scene.Required=1;local bridge=part(f,"Broken crossing",origin+Vector3.new(0,1,0),Vector3.new(12,2,36));bridge.Transparency=.65;bridge.CanCollide=false
  local anchor=part(f,"Repair brace",origin+Vector3.new(10,2,0),Vector3.new(2,4,2))
  prompt(scene,anchor,"Repair: 6 Wood + 4 Cord",function(player,p)
   if state.Repaired then return end
   local paid=require(script.Parent.InventoryService):TakeCost(player,scene.Def.Cost)
   if not paid then p.ActionText="Need 6 Wood + 4 Cord";return end
   state.Repaired=true;bridge.Transparency=0;bridge.CanCollide=true;p.Enabled=false;self:_advance(scene,1)
  end)
 elseif kind=="Puzzle" then
  state.Sequence=state.Sequence or {math.random(1,3),math.random(1,3),math.random(1,3)};state.SequenceStep=state.SequenceStep or 1;scene.Required=3
  for i=1,3 do
   local crystal=part(f,"Crystal "..i,origin+Vector3.new((i-2)*7,3,0),Vector3.new(2,6,2),({Color3.fromRGB(104,176,223),Color3.fromRGB(217,170,91),Color3.fromRGB(157,115,211)})[i]);crystal.Material=Enum.Material.Neon
   prompt(scene,crystal,"Sequence: "..table.concat(state.Sequence," - "),function(_,p)
    if state.Sequence[state.SequenceStep]==i then self:_advance(scene,state.SequenceStep);state.SequenceStep+=1;crystal.Transparency=.5
    else state.SequenceStep=1;state.Claims={};state.Progress=0;local o=require(script.Parent.ObjectiveService)._active[scene.Entry.Id];if o then o.Data.Progress=0 end;p.ActionText="Try: "..table.concat(state.Sequence," - ") end
   end)
  end
 elseif kind=="Escort" then
  local p=state.EscortPosition and vector(state.EscortPosition) or origin+Vector3.new(0,3,0)
  local npc=part(f,"Injured explorer",p,Vector3.new(2,6,2),Color3.fromRGB(109,137,89));scene.NPC=npc
  prompt(scene,npc,"Escort to camp",function(player,promptObject)state.Escorting=true;state.EscortLeader=player.UserId;promptObject.Enabled=false end)
 elseif kind=="Survey" then
  for i=1,3 do
   if not state.Claims[tostring(i)] then
    local p=require(script.Parent.OverhaulWorldService):SafePosition(origin+Vector3.new(math.cos(i*2.1)*45,0,math.sin(i*2.1)*45))
    local marker=part(f,"Survey point "..i,p,Vector3.new(2,3,2),Color3.fromRGB(106,166,180));marker.Material=Enum.Material.Neon
    prompt(scene,marker,"Record observation",function(_,promptObject) if self:_advance(scene,i) then promptObject.Enabled=false;marker.Transparency=.7 end end)
   end
  end
  if scene.Def.Wildlife then self:_actors(scene,2,false,true) end
 elseif kind=="Clear" then scene.Required=2;self:_actors(scene,2,scene.Def.Elite,false)
 elseif kind=="Defend" then
  scene.Required=3;self:_actors(scene,3,false,false)
 elseif kind=="Disable" then
  scene.Required=1;self:_actors(scene,2,false,false)
  local terminal=part(f,"Alarm terminal",origin+Vector3.new(0,2,0),Vector3.new(4,4,3),Color3.fromRGB(160,112,87))
  prompt(scene,terminal,"Shut down patrol alarm",function(_,p) if self:_advance(scene,1) then p.Enabled=false;terminal.Color=Color3.fromRGB(104,163,108) end end)
 elseif kind=="Vents" or kind=="Drain" then
  for i=1,3 do
   if not state.Claims[tostring(i)] then
    local pos=require(script.Parent.OverhaulWorldService):SafePosition(origin+Vector3.new((i-2)*18,0,14))
    local vent=part(f,kind=="Vents" and "Spore vent" or "Drain wheel",pos,Vector3.new(4,3,4),Color3.fromRGB(121,157,110))
    prompt(scene,vent,kind=="Vents" and "Close vent" or "Open drain",function(_,p)if self:_advance(scene,i) then p.Enabled=false;vent.Color=Color3.fromRGB(85,91,84) end end)
   end
  end
  if kind=="Drain" then
   local water=part(f,"Rising water",origin+Vector3.new(0,.6,0),Vector3.new(80,1,80),Color3.fromRGB(76,130,152));water.Transparency=.6;water.CanCollide=false;water.Material=Enum.Material.Glass
   scene.Water=water
   for side=-1,1,2 do part(f,"Raised safe walkway",origin+Vector3.new(side*34,3,0),Vector3.new(10,2,86),Color3.fromRGB(109,100,77)) end
  end
 elseif kind=="Shelter" or kind=="Thermal" then
  for i=1,3 do
   if not state.Claims[tostring(i)] then
    local p=require(script.Parent.OverhaulWorldService):SafePosition(origin+Vector3.new(math.cos(i*2.1)*30,0,math.sin(i*2.1)*30))-Vector3.new(0,5,0)
    for side=-1,1,2 do part(f,"Windbreak",p+Vector3.new(side*5,5,0),Vector3.new(1,10,12),Color3.fromRGB(100,106,103)) end
    part(f,"Shelter roof",p+Vector3.new(0,11,0),Vector3.new(12,2,14),Color3.fromRGB(115,122,110))
    local supply=part(f,"Shelter supplies",p+Vector3.new(0,2,0),Vector3.new(3,3,3));prompt(scene,supply,"Recover sheltered supplies",function(_,pr)if self:_advance(scene,i) then pr.Enabled=false end end)
   end
  end
 elseif kind=="Impact" or kind=="Lightning" then
  scene.Required=3;state.Strikes=state.Strikes or 0;state.StrikeAt=state.StrikeAt or scene.Entry.Data.Elapsed+4
  for i=1,state.Strikes do
   if not state.Claims[tostring(i)] and not (state.PendingStrike and state.PendingStrike.Index==i) then
    self:_node(scene,i,kind=="Impact" and "MeteorOre" or "StormOre",Vector3.new((i-2)*20,0,20),true)
   end
  end
 end
end
function Service:_strike(scene)
 local state=scene.State;local i=state.Strikes+1;if i>3 then return end
 state.Strikes=i
 local origin=require(script.Parent.OverhaulWorldService):SafePosition(scene.Origin+Vector3.new((i-2)*20,0,20))-Vector3.new(0,5,0)
 local warning=part(scene.Folder,"Incoming strike",origin+Vector3.new(0,.2,0),Vector3.new(12,.2,12),Color3.fromRGB(238,143,72));warning.Material=Enum.Material.Neon;warning.Transparency=.45;warning.CanCollide=false
 state.PendingStrike={Index=i,Position={origin.X,origin.Y,origin.Z},At=scene.Entry.Data.Elapsed+3}
end
function Service:_impact(scene)
 local pending=scene.State.PendingStrike;if not pending then return end;local position=vector(pending.Position)
 for _,player in ipairs(Players:GetPlayers()) do if close(player,position,7) then require(script.Parent.CombatService):ApplyDamage(nil,player.Character,12,"Environment") end end
 local flash=part(scene.Folder,"Strike",position+Vector3.new(0,12,0),Vector3.new(2,24,2),Color3.fromRGB(234,211,116));flash.Material=Enum.Material.Neon;flash.CanCollide=false;Debris:AddItem(flash,.5)
 self:_node(scene,pending.Index,scene.Def.Template=="Impact" and "MeteorOre" or "StormOre",position-scene.Origin,true)
 scene.State.PendingStrike=nil
end
function Service:Step(entry,dt)
 local scene=self._scenes[entry.Data.InstanceId];if not scene or scene.Closed then return end
 local publicAt=math.max(0,entry.Data.Warning-(scene.Def.Warning or 0))
 if entry.Data.Elapsed>=publicAt and scene.Signal and not scene.Public then scene.Public=true;scene.Signal.Transparency=0;Tags:AddTag(scene.Signal,"Objective") end
 if entry.Data.Elapsed<entry.Data.Warning then return end
 self:_activate(scene)
 local state=scene.State;local kind=scene.Def.Template
 if state.ActorSpec and not state.Completed then self:_actors(scene,state.ActorSpec.Count,state.ActorSpec.Elite,state.ActorSpec.Wildlife) end
 if kind=="Escort" and state.Escorting and scene.NPC and not state.Completed then
  local leader=Players:GetPlayerByUserId(state.EscortLeader or 0)
  if not leader or not close(leader,scene.NPC.Position,35) then
   for _,p in ipairs(Players:GetPlayers()) do if close(p,scene.NPC.Position,25) then leader=p;state.EscortLeader=p.UserId;break end end
  end
  if leader and close(leader,scene.NPC.Position,35) then
   local target=leader.Character.HumanoidRootPart.Position;local delta=target-scene.NPC.Position
   if delta.Magnitude>6 then
    local p=scene.NPC.Position+delta.Unit*math.min(10*dt,delta.Magnitude-5);local world=require(script.Parent.OverhaulWorldService)
    if world:IsSafe(p,2) then scene.NPC.Position=Vector3.new(p.X,world:GetHeight(p.X,p.Z)+3,p.Z);state.EscortPosition={scene.NPC.Position.X,scene.NPC.Position.Y,scene.NPC.Position.Z} end
   end
   if Vector2.new(scene.NPC.Position.X,scene.NPC.Position.Z).Magnitude<190 then self:_finish(scene) end
  end
 elseif kind=="Impact" or kind=="Lightning" then
  if state.PendingStrike and entry.Data.Elapsed>=state.PendingStrike.At then self:_impact(scene) end
  if not state.Completed and entry.Data.Elapsed>=(state.StrikeAt or 0) and (state.Strikes or 0)<3 then state.StrikeAt=entry.Data.Elapsed+15;self:_strike(scene) end
 elseif kind=="Drain" and scene.Water then scene.Water.Transparency=state.Completed and 1 or .6 end
end
function Service:CaptureActors()
 for _,scene in pairs(self._scenes) do
  scene.State.Actors=scene.State.Actors or {}
  for key,m in pairs(scene.Actors) do if m.Parent then scene.State.Actors[key]=Codec.Actor(m) or false end end
 end
end
function Service:End(id)
 local scene=self._scenes[id];if not scene then return end
 scene.Closed=true;self._scenes[id]=nil
 for _,node in ipairs(scene.Nodes) do if node.Parent then node:SetAttribute("Unloading",true) end end
 for _,m in pairs(scene.Actors) do if m.Parent then m:Destroy() end end
 scene.Folder:Destroy()
end
function Service:ClearAllPrompts() local ids={};for id in pairs(self._scenes) do table.insert(ids,id) end;for _,id in ipairs(ids) do self:End(id) end end
function Service:Init()
 if not workspace:FindFirstChild("WorldEvents") then local f=Instance.new("Folder");f.Name="WorldEvents";f.Parent=workspace end
end
return Service
