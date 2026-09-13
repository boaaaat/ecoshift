-- Separate generation domain: surface shifts never own these rooms or their durable ledgers.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Collection=game:GetService("CollectionService")
local RunService=game:GetService("RunService")
local Config=require(RS.Shared.CampaignConfig)
local Util=require(RS.Shared.Util)
local Service={_saved={},_live={}}
local ORDER={BogKing=1,FallenStar=2,Ironback=3,DeepArchive=4,MoonWarden=5,BogKingEnhanced=6}
local function isBogKing(id) return id=="BogKing" or id=="BogKingEnhanced" end
local function service(name) return require(script.Parent[name]) end
local function living(player)
 local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 return player.Parent==Players and not player:GetAttribute("IsDead") and h and h.Health>0 and not player:GetAttribute("WorldPlayerLoading") and not player:GetAttribute("WorldPlayerRestoring")
end
local function part(parent,name,size,position,color)
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.Position=position;p.Anchored=true;p.Material=Enum.Material.Slate;p.Color=color or Color3.fromRGB(70,83,79);p.Parent=parent;return p
end
local function prompt(parent,action,fn)
 local p=Instance.new("ProximityPrompt");p.ActionText=action;p.ObjectText="Expedition interior";p.KeyboardKeyCode=Enum.KeyCode.F;p.RequiresLineOfSight=false;p.MaxActivationDistance=10;p.HoldDuration=1;p.Parent=parent
 p.Triggered:Connect(function(player)
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if living(player) and root and (root.Position-parent.Position).Magnitude<=12 and not RS:GetAttribute("WorldRestoring") then fn(player) end
 end)
 return p
end
function Service:_state(id)
 if not self._saved[id] then self._saved[id]={Id=id,Participants={},Rooms={},Phase=1,Health=0,MaxHealth=0,Completed=false,LootClaimed=false,Records={},Exposed=0,AttackRemaining=3,AttackIndex=0,RewardRemaining=0} end
 return self._saved[id]
end
function Service:_crew(id)
 local crew={}
 for _,p in ipairs(Players:GetPlayers()) do if p:GetAttribute("InteriorId")==id and living(p) then table.insert(crew,p) end end
 return crew
end
function Service:_participant(id,player)
 local state=self:_state(id)
 if state.Completed then return end
 local key=tostring(player.UserId)
 if state.Participants[key] then return end
 local n=0;for _ in pairs(state.Participants) do n+=1 end
 state.Participants[key]=true
 local boss=Config.Bosses[id]
 if boss then
  local extra=180*Config.Damage[boss.Tier]*(n==0 and 1 or .65)
  state.MaxHealth+=extra;state.Health+=extra
  local live=self._live[id]
  if live and live.Boss then local h=live.Boss:FindFirstChildOfClass("Humanoid");h.MaxHealth=state.MaxHealth;h.Health=state.Health end
 end
end
function Service:_actor(id,name,position,hp,color,boss)
 local model=Instance.new("Model");model.Name=name
 local root=part(model,"HumanoidRootPart",boss and Vector3.new(8,7,8) or Vector3.new(3,3,4),position,color)
 model.PrimaryPart=root
 local h=Instance.new("Humanoid");h.RequiresNeck=false;h.BreakJointsOnDeath=false;h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None;h.MaxHealth=hp;h.Health=hp;h.Parent=model
 local eye=part(model,"Eye",Vector3.new(1,.6,.3),position+Vector3.new(0,1.5,-(root.Size.Z/2+.1)),Color3.fromRGB(231,195,94));eye.Material=Enum.Material.Neon
 model:SetAttribute("NoAI",true);model:SetAttribute("NoLoot",true);model:SetAttribute("InteriorId",id);model:SetAttribute("IsBoss",boss==true);model:SetAttribute("EntityId",name);model:SetAttribute("EntityType","Monster")
 model:SetAttribute("Level",1+5*((Config.Bosses[id] and Config.Bosses[id].Tier or 7)-1));model:SetAttribute("DisplayName",Config.Bosses[id] and boss and Config.Bosses[id].Name or "Den leech")
 model.Parent=self._live[id].Folder;Collection:AddTag(model,"Monster")
 return model
end
function Service:_guard(id,room,index,position)
 local s=self:_state(id);local key=tostring(room)..":"..index
 if s.Rooms[key]==0 then return end
 local max=Config.Damage[Config.Bosses[id].Tier]*2.5
 local actor=self:_actor(id,"DenLeech",position,max,Color3.fromRGB(80,100,61),false)
 local hum=actor:FindFirstChildOfClass("Humanoid");hum.Health=s.Rooms[key] or max
 self._live[id].Guards[key]={Model=actor,Attack=1}
 hum.HealthChanged:Connect(function(hp) s.Rooms[key]=math.max(0,hp) end)
 hum.Died:Connect(function() actor:Destroy();self._live[id].Guards[key]=nil;self:_doors(id) end)
end
function Service:_doors(id)
 local live,s=self._live[id],self:_state(id)
 if not live then return end
 local clear=true
 for room=1,2 do
  for i=1,2 do if s.Rooms[tostring(room)..":"..i]~=0 then clear=false end end
  local door=live.Doors[room];if door then door.CanCollide=not clear;door.Transparency=clear and 1 or .15 end
 end
 live.RoomsCleared=clear
end
function Service:_ensure(id)
 if self._live[id] then return self._live[id] end
 assert(ORDER[id],"Unknown interior")
 local s=self:_state(id)
 local origin=Vector3.new(ORDER[id]*1100,3000,0)
 local folder=Instance.new("Folder");folder.Name=id;folder.Parent=self._folder or workspace:FindFirstChild("ExpeditionInteriors")
 local live={Folder=folder,Origin=origin,Guards={},Doors={},EmptySeconds=0,Warnings={}}
 folder:SetAttribute("InteriorId",id);folder:SetAttribute("MapOrigin",origin);folder:SetAttribute("MapExtent",Vector2.new(150,190))
 self._live[id]=live
 part(folder,"Floor",Vector3.new(150,4,190),origin)
 part(folder,"NorthWall",Vector3.new(150,24,4),origin+Vector3.new(0,12,-94))
 part(folder,"SouthWall",Vector3.new(150,24,4),origin+Vector3.new(0,12,94))
 for _,side in ipairs({-1,1}) do part(folder,"SideWall",Vector3.new(4,24,190),origin+Vector3.new(side*74,12,0)) end
 local exit=part(folder,"ReturnToCamp",Vector3.new(8,7,2),origin+Vector3.new(0,5,87),Color3.fromRGB(168,151,95))
 prompt(exit,"Return to current camp",function(p) if p:GetAttribute("InteriorId")==id then self:Exit(p) end end)
 if isBogKing(id) then
  for index=1,3 do if s.Rooms["3:"..index] and s.Rooms["3:"..index]>0 then self:_guard(id,3,index,origin+Vector3.new(index*7-14,5,-35)) end end
  for room=1,2 do
   local z=70-room*35
   for _,side in ipairs({-1,1}) do part(folder,"RoomWall",Vector3.new(65,18,3),origin+Vector3.new(side*42,10,z)) end
   live.Doors[room]=part(folder,"RoomDoor",Vector3.new(19,18,3),origin+Vector3.new(0,10,z),Color3.fromRGB(82,92,53))
   for i=1,2 do self:_guard(id,room,i,origin+Vector3.new(i==1 and -14 or 14,5,z+15)) end
  end
  self:_doors(id)
 elseif id=="DeepArchive" then
  live.WaterBasins={}
  -- Short optional dives share a dry central route and frequent air pockets.
  -- These terrain volumes belong to this interior, outside surface generation bounds.
  for index=1,3 do
   -- Raised dry walkways and air pockets allow the mandatory route without accessories.
   local x=index%2==1 and -35 or 35;local z=65-index*38
   local waterFrame=CFrame.new(origin+Vector3.new(x<0 and -46 or 46,8,z))
   local waterSize=Vector3.new(44,12,32)
   if not s.Completed then
    workspace.Terrain:FillBlock(waterFrame,waterSize,Enum.Material.Water)
    table.insert(live.WaterBasins,{Frame=waterFrame,Size=waterSize})
   end
   part(folder,"ArchiveWalkway",Vector3.new(75,3,10),origin+Vector3.new(x*.4,4,z+8))
   local record=part(folder,"Record"..index,Vector3.new(3,4,3),origin+Vector3.new(x,7,z),Color3.fromRGB(96,165,169))
   prompt(record,"Recover archive record "..index,function(p)
    if p:GetAttribute("InteriorId")~=id or s.Records[tostring(index)] then return end
    s.Records[tostring(index)]=true;record.Transparency=.7
    service("CampaignService"):RecordFact("ArchiveRecord"..index)
    service("ExpeditionRewardsService"):RecordActivity(p)
   end)
  end
  part(folder,"DryCentralAisle",Vector3.new(18,3,160),origin+Vector3.new(0,4,0),Color3.fromRGB(112,139,139))
  local air=part(folder,"AirSystem",Vector3.new(8,8,5),origin+Vector3.new(0,7,-65),Color3.fromRGB(87,142,153))
  live.AirSystem=air
  live.AirPrompt=prompt(air,s.Completed and "Air system restored" or "Repair air system / project materials",function(p)
   if p:GetAttribute("InteriorId")==id and not s.Completed then service("CampaignService"):OpenAt(p,air) end
  end)
 else
  for _,x in ipairs({-45,45}) do
   local machinery=part(folder,"ArenaMachinery",Vector3.new(6,5,6),origin+Vector3.new(x,5,-20),Color3.fromRGB(158,126,57))
   if id=="Ironback" then prompt(machinery,"Expose Ironback's weak side",function(p)
    if p:GetAttribute("InteriorId")==id then s.Exposed=14;service("ExpeditionRewardsService"):RecordActivity(p) end
   end) end
  end
  if id=="MoonWarden" then
   for i=1,5 do part(folder,"LowGravityRoute",Vector3.new(15,2,15),origin+Vector3.new((i-3)*20,3+(i%2)*3,-30),Color3.fromRGB(113,126,145)) end
  end
 end
 if Config.Bosses[id] and not s.Completed and s.Health>0 then
  local b=Config.Bosses[id]
  live.Boss=self:_actor(id,id,origin+Vector3.new(0,6,-56),s.MaxHealth,b.Color,true)
  local hum=live.Boss:FindFirstChildOfClass("Humanoid");hum.Health=s.Health
  hum.HealthChanged:Connect(function(hp) s.Health=math.max(0,hp);s.Phase=math.clamp(4-math.ceil(3*hp/math.max(1,s.MaxHealth)),1,3) end)
  hum.Died:Connect(function() self:_complete(id) end)
 end
 if s.Completed then self:_rewardChest(id) end
 return live
end
function Service:OpenEntrance(player,id)
 local campaign=service("CampaignService")
 if campaign:GetMilestone().Id~=id then return false,"This encounter is not the current project." end
 return self:Enter(player,id)
end
function Service:Enter(player,id)
 if not ORDER[id] or not living(player) or RS:GetAttribute("WorldRestoring") then return false,"Cannot enter now." end
 local state=self:_state(id)
 self:_participant(id,player)
 local live=self:_ensure(id)
 player:SetAttribute("InteriorId",id);player:SetAttribute("MapLayer","Interior")
 player.Character:PivotTo(CFrame.new(live.Origin+Vector3.new(0,8,75)))
 return true,"Entered "..(Config.Bosses[id] and Config.Bosses[id].Name or "Deep Archive")..". The camp return remains available."
end
function Service:Exit(player)
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if root then local force=root:FindFirstChild("MoonGravity");if force then force:Destroy() end end
 player:SetAttribute("InteriorId",nil);player:SetAttribute("MapLayer","Surface")
 if player.Character then
  local spawn=workspace:FindFirstChildWhichIsA("SpawnLocation",true)
  local safe=service("OverhaulWorldService"):SafePosition(spawn and spawn.Position or Vector3.zero)
  player.Character:PivotTo(CFrame.new(safe+Vector3.new(0,4,0)))
 end
end
function Service:RestorePlayer(player,id)
 if id and ORDER[id] then
  self:_ensure(id);player:SetAttribute("InteriorId",id);player:SetAttribute("MapLayer","Interior")
 else player:SetAttribute("InteriorId",nil);player:SetAttribute("MapLayer","Surface") end
end
function Service:_complete(id)
 local s,live=self:_state(id),self._live[id]
 if s.Completed then return end;s.Completed=true;s.Health=0
 service("CampaignService"):Complete(id)
 if id=="BogKingEnhanced" then service("EnchantingService"):GrantChoice("DeepBogKing",{"RescueReserve","SharedCover"},2) end
 if not s.RewardCreated then
  s.RewardCreated=true
  local n=0;for _ in pairs(s.Participants) do n+=1 end
  s.RewardRemaining=3+n;s.LootClaimed=false
 end
 self:_rewardChest(id)
 if live.Boss then live.Boss:Destroy();live.Boss=nil end
end
function Service:_rewardChest(id)
 local s,live=self:_state(id),self._live[id]
 if not live or live.RewardChest or (s.RewardRemaining or 0)<=0 then return end
 local chest=part(live.Folder,"EncounterReward",Vector3.new(5,3,3),live.Origin+Vector3.new(0,4,-40),Color3.fromRGB(184,145,63));live.RewardChest=chest
 prompt(chest,"Collect shared trophies",function(player)
  if player:GetAttribute("InteriorId")~=id or s.RewardRemaining<=0 then return end
  local added=service("InventoryService"):Give(player,Config.Bosses[id].Trophy,s.RewardRemaining,false,true)
  s.RewardRemaining-=added;s.LootClaimed=s.RewardRemaining<=0
  service("InventoryService"):Sync(player)
  if s.LootClaimed then chest:Destroy() end
 end)
end
local function visible(a,b,exclude)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances=exclude
 local hit=workspace:Raycast(a,b-a,params)
 return hit==nil
end
function Service:_strike(actor,player,damage)
 if not living(player) or not actor.Parent then return end
 local root=player.Character:FindFirstChild("HumanoidRootPart")
 if root and visible(actor.PrimaryPart.Position,root.Position,{actor,player.Character}) then service("CombatService"):ApplyDamage(actor,player.Character,damage,"Melee") end
end
function Service:_telegraph(live,position,radius,duration,callback)
 local ring=part(live.Folder,"AttackWarning",Vector3.new(radius*2,.12,radius*2),Vector3.new(position.X,live.Origin.Y+2.2,position.Z),Color3.fromRGB(235,163,67))
 ring.Transparency=.45;ring.Material=Enum.Material.Neon;ring.CanCollide=false;ring.CanQuery=false
 table.insert(live.Warnings,{Part=ring,Remaining=duration,Callback=callback})
end
function Service:_attack(id,target)
 local live,s=self._live[id],self:_state(id);local boss=live.Boss
 if not boss or not target.Character then return end
 local root=target.Character:FindFirstChild("HumanoidRootPart");if not root then return end
 local damage=Config.MonsterDamage[Config.Bosses[id].Tier]*1.5
 s.AttackIndex+=1;s.AttackRemaining=id=="MoonWarden" and 3.2 or 4
 local center=Vector3.new(root.Position.X,live.Origin.Y+3,root.Position.Z)
 if isBogKing(id) and s.AttackIndex%3==0 then
  self:_telegraph(live,live.Origin+Vector3.new(0,3,-35),7,1.5,function()
   for index=1,3 do
    local key="3:"..index
    if s.Rooms[key]==nil then self:_guard(id,3,index,live.Origin+Vector3.new(index*7-14,5,-35)) end
   end
  end)
 elseif isBogKing(id) and s.AttackIndex%3==1 then
  local from=boss.PrimaryPart.Position;local direction=(root.Position-from)*Vector3.new(1,0,1)
  if direction.Magnitude<.1 then return end;direction=direction.Unit
  self:_telegraph(live,center,5,1.1,function()
   for _,p in ipairs(self:_crew(id)) do
    local pr=p.Character.HumanoidRootPart;local offset=pr.Position-from;local along=offset:Dot(direction)
    if along>0 and along<60 and (offset-direction*along).Magnitude<5 then
     self:_strike(boss,p,damage*.6)
     if visible(pr.Position,from,{boss,p.Character}) then pr.AssemblyLinearVelocity=-direction*22+Vector3.new(0,6,0) end
    end
   end
  end)
 elseif (id=="FallenStar" and s.AttackIndex%3==2) or (id=="MoonWarden" and s.Phase>=2 and s.AttackIndex%2==0) then
  for _,x in ipairs({-44,0,44}) do
   local lane=live.Origin+Vector3.new(x,3,-10)
   self:_telegraph(live,lane,12,1.4,function()
    for _,p in ipairs(self:_crew(id)) do local pos=p.Character.HumanoidRootPart.Position;if math.abs(pos.X-lane.X)<12 then self:_strike(boss,p,damage) end end
   end)
  end
 else
  local radius=id=="Ironback" and 13 or 10
  self:_telegraph(live,center,radius,1.2,function()
   if isBogKing(id) then live.Leap={From=boss:GetPivot().Position,To=center+Vector3.new(0,4,0),Elapsed=0} end
   for _,p in ipairs(self:_crew(id)) do
    local offset=(p.Character.HumanoidRootPart.Position-center)*Vector3.new(1,0,1)
    if offset.Magnitude<=radius then self:_strike(boss,p,damage) end
   end
   if id=="FallenStar" then s.Exposed=7 end
  end)
 end
end
function Service:_tick(dt)
 if RS:GetAttribute("WorldRestoring") or service("GameStateService"):IsGameOver() then return end
 for id,live in pairs(self._live) do
  local crew=self:_crew(id);local s=self:_state(id)
  if id=="DeepArchive" and RS:GetAttribute("CampaignCompleted_DeepArchive") then
   s.Completed=true
   for _,basin in ipairs(live.WaterBasins or {}) do workspace.Terrain:FillBlock(basin.Frame,basin.Size,Enum.Material.Air) end
   live.WaterBasins={}
   if live.AirSystem then live.AirSystem.Color=Color3.fromRGB(145,188,128);live.AirSystem:SetAttribute("AirSystemOnline",true) end
   if live.AirPrompt then live.AirPrompt.ActionText="Air system restored" end
  end
  -- Disconnection/death pauses encounter progress and removes unclaimed telegraphs.
  if #crew==0 then
   local occupied=false
   for _,p in ipairs(Players:GetPlayers()) do if p:GetAttribute("InteriorId")==id then occupied=true;break end end
   if occupied then live.EmptySeconds=0;continue end
   live.EmptySeconds+=dt
   if live.EmptySeconds>=20 then
    if live.Boss then s.Health=live.Boss:FindFirstChildOfClass("Humanoid").Health end
    for _,basin in ipairs(live.WaterBasins or {}) do workspace.Terrain:FillBlock(basin.Frame,basin.Size,Enum.Material.Air) end
    live.Folder:Destroy();self._live[id]=nil
   end
   continue
  end
  live.EmptySeconds=0
  for _,p in ipairs(crew) do
   local root=p.Character:FindFirstChild("HumanoidRootPart")
   local force=root and root:FindFirstChild("MoonGravity")
   if root and id=="MoonWarden" and s.Phase==2 and not s.Completed then
    if not force then
     local attachment=root:FindFirstChild("MoonGravityAttachment") or Instance.new("Attachment");attachment.Name="MoonGravityAttachment";attachment.Parent=root
     force=Instance.new("VectorForce");force.Name="MoonGravity";force.Attachment0=attachment;force.RelativeTo=Enum.ActuatorRelativeTo.World;force.ApplyAtCenterOfMass=true;force.Parent=root
    end
    force.Force=Vector3.new(0,workspace.Gravity*root.AssemblyMass*.35,0)
   elseif force then force:Destroy() end
  end
  if live.Leap and live.Boss then
   local leap=live.Leap;leap.Elapsed+=dt;local t=math.clamp(leap.Elapsed/.7,0,1)
   live.Boss:PivotTo(CFrame.new(leap.From:Lerp(leap.To,t)+Vector3.new(0,math.sin(t*math.pi)*7,0)))
   if t>=1 then live.Leap=nil end
  end
  for i=#live.Warnings,1,-1 do
   local warning=live.Warnings[i];warning.Remaining-=dt
   if warning.Remaining<=0 then warning.Part:Destroy();table.remove(live.Warnings,i);warning.Callback() end
  end
  for _,guard in pairs(live.Guards) do
   local model=guard.Model;local closest,distance
   for _,p in ipairs(crew) do local d=(p.Character.HumanoidRootPart.Position-model.PrimaryPart.Position).Magnitude;if not distance or d<distance then closest,distance=p,d end end
   if closest and visible(model.PrimaryPart.Position,closest.Character.HumanoidRootPart.Position,{model,closest.Character}) then
    guard.Attack-=dt
    if distance<7 and guard.Attack<=0 then guard.Attack=2;self:_strike(model,closest,Config.MonsterDamage[Config.Bosses[id].Tier]*.75)
    elseif distance>5 and distance<24 then
     local target=closest.Character.HumanoidRootPart.Position;local move=(target-model.PrimaryPart.Position)*Vector3.new(1,0,1)
     if move.Magnitude>.1 then model:PivotTo(CFrame.lookAt(model.PrimaryPart.Position+move.Unit*math.min(distance-5,8*dt),Vector3.new(target.X,model.PrimaryPart.Position.Y,target.Z))) end
    end
   end
  end
  if live.Boss and live.Boss.Parent and (not isBogKing(id) or live.RoomsCleared) then
   local boss=live.Boss;s.Exposed=math.max(0,s.Exposed-dt)
   boss:SetAttribute("BossArmored",(id=="Ironback" or id=="FallenStar") and s.Exposed<=0)
   boss:SetAttribute("BossPhase",s.Phase)
   local nearest,dist
   for _,p in ipairs(crew) do local d=(p.Character.HumanoidRootPart.Position-boss.PrimaryPart.Position).Magnitude;if not dist or d<dist then nearest,dist=p,d end end
   if nearest then
    local target=nearest.Character.HumanoidRootPart.Position
    if not live.Leap and dist>15 and visible(boss.PrimaryPart.Position,target,{boss,nearest.Character}) then
     local delta=(target-boss.PrimaryPart.Position)*Vector3.new(1,0,1)
     if delta.Magnitude>.1 then
      local speed=(boss:GetAttribute("GearStaggerUntil") or 0)>workspace:GetServerTimeNow() and 0 or 8
      if (boss:GetAttribute("GearSlowUntil") or 0)>workspace:GetServerTimeNow() then speed*=boss:GetAttribute("GearSlowFactor") or 1 end
      boss:PivotTo(CFrame.lookAt(boss.PrimaryPart.Position+delta.Unit*math.min(dist-15,speed*dt),Vector3.new(target.X,boss.PrimaryPart.Position.Y,target.Z)))
     end
    end
    s.AttackRemaining-=dt
    if s.AttackRemaining<=0 then self:_attack(id,nearest) end
   end
  end
 end
end
function Service:CaptureWorldState()
 for id,live in pairs(self._live) do if live.Boss then self:_state(id).Health=live.Boss:FindFirstChildOfClass("Humanoid").Health end end
 return {SchemaVersion=1,Encounters=Util.DeepCopy(self._saved)}
end
function Service:RestoreWorldState(raw)
 self._saved={}
 if not raw then return end
 assert(type(raw)=="table" and raw.SchemaVersion==1 and type(raw.Encounters)=="table","Invalid interiors snapshot")
 for id,s in pairs(raw.Encounters) do
  assert(ORDER[id] and type(s)=="table" and s.Id==id and type(s.Participants)=="table" and type(s.Rooms)=="table" and type(s.Records)=="table","Invalid interior state")
  for _,key in ipairs({"Health","MaxHealth","AttackRemaining","AttackIndex","Exposed","Phase"}) do assert(type(s[key])=="number" and s[key]==s[key] and s[key]>=0 and s[key]<1e9,"Invalid encounter counter") end
  self._saved[id]=Util.DeepCopy(s)
 end
end
function Service:_campRoutes()
 if RS:GetAttribute("WorldRestoring") or RS:GetAttribute("WorldShifting") then return end
 self._routes=self._routes or {}
 local center=workspace:GetAttribute("CampCenter") or Vector3.zero
 local world=service("OverhaulWorldService")
 for id in pairs(self._saved) do
  if not self._routes[id] or not self._routes[id].Parent then
   local x,z=center.X-25,center.Z+ORDER[id]*10
   local portal=part(self._folder,"CampRoute_"..id,Vector3.new(4,5,2),Vector3.new(x,world:GetHeight(x,z)+2.5,z),Config.Bosses[id] and Config.Bosses[id].Color or Color3.fromRGB(87,142,153))
   portal:SetAttribute("MapMarkerType","Objective");portal:SetAttribute("MapMarkerLabel",(Config.Bosses[id] and Config.Bosses[id].Name or "Deep Archive").." entrance")
   self._routes[id]=portal
   prompt(portal,"Enter "..(Config.Bosses[id] and Config.Bosses[id].Name or "Deep Archive"),function(p) self:Enter(p,id) end)
  end
 end
end
function Service:Init()
 if self._initialized then return end;self._initialized=true
 self._folder=Instance.new("Folder");self._folder.Name="ExpeditionInteriors";self._folder.Parent=workspace
 _G.Ecoshift=_G.Ecoshift or {};local previous=_G.Ecoshift.OnOverhaulLandmark
 _G.Ecoshift.OnOverhaulLandmark=function(model,metadata)
  if previous then previous(model,metadata) end
  if metadata.Biome=="Swamp" and metadata.Depth==3 then
   local entrance=part(model,"DeepBogEntrance",Vector3.new(4,6,3),metadata.Position+Vector3.new(8,3,0),Config.Bosses.BogKingEnhanced.Color)
   entrance:SetAttribute("MapMarkerType","Objective");entrance:SetAttribute("MapMarkerLabel","Deep Bog King · optional den")
   prompt(entrance,"Enter optional Deep Bog King den",function(player)
    if (RS:GetAttribute("CampaignTier") or 1)>=4 and not player:GetAttribute("InteriorId") then self:Enter(player,"BogKingEnhanced") end
   end)
  end
 end
 local routes=0
 RunService.Heartbeat:Connect(function(dt) self:_tick(math.min(dt,.25));routes+=dt;if routes>=3 then routes=0;self:_campRoutes() end end)
end
return Service
