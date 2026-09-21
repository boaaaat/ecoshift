-- Server-owned zones and meteor collisions; their choreography is client-owned.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Tags = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Specials = require(RS.Shared.Weapons.BowSpecials)
local BowVisuals = require(RS.Shared.Weapons.BowVisuals)
local GameState = require(script.Parent.GameStateService)
local Service = {}

local function folder(name)
 local result=workspace:FindFirstChild(name)
 if not result then result=Instance.new("Folder");result.Name=name;result.Parent=workspace end
 return result
end
local function root(model)
 return model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
end
local function living(model)
 local hum=model and model:FindFirstChildOfClass("Humanoid")
 return model and model.Parent and hum and hum.Health>0
end
local function boss(model)
 return model:GetAttribute("IsBoss")==true or model:GetAttribute("Boss")==true or Tags:HasTag(model,"Boss")
end
local function geometryParams()
 local ignored={folder("CombatProjectiles"),folder("BowSpecialEffects")}
 for _,tag in ipairs({"Monster","Animal"}) do
  for _,model in ipairs(Tags:GetTagged(tag)) do table.insert(ignored,model) end
 end
 for _,player in ipairs(Players:GetPlayers()) do
  if player.Character then table.insert(ignored,player.Character) end
 end
 local params=RaycastParams.new()
 params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances=ignored
 params.RespectCanCollide=true
 return params
end
local function grounded(position,params)
 local hit=workspace:Raycast(position+Vector3.yAxis*2,-Vector3.yAxis*48,params)
 return hit and hit.Position+Vector3.yAxis*.15 or position
end
local function targets(context,center,radius)
 local result={};local params=geometryParams()
 for _,model in ipairs(Tags:GetTagged("Monster")) do
  local part=root(model)
  if living(model) and part and model:GetAttribute("InteriorId")==context.Interior then
   local delta=part.Position-center
   if delta.Magnitude<=radius then
    local blocked=delta.Magnitude>.01 and workspace:Raycast(center,delta,params)
    if not blocked then table.insert(result,{Model=model,Root=part,Distance=delta.Magnitude}) end
   end
  end
 end
 table.sort(result,function(a,b)return a.Distance<b.Distance end)
 return result
end
local function slow(model,amount,duration)
 local now=workspace:GetServerTimeNow()
 local current=(model:GetAttribute("GearSlowUntil") or 0)>now and (model:GetAttribute("GearSlowFactor") or 1) or 1
 model:SetAttribute("GearSlowFactor",math.min(current,1-amount))
 model:SetAttribute("GearSlowUntil",math.max(model:GetAttribute("GearSlowUntil") or 0,now+duration))
end
local function stagger(model,duration)
 model:SetAttribute("GearStaggerUntil",math.max(model:GetAttribute("GearStaggerUntil") or 0,workspace:GetServerTimeNow()+duration))
end
local function emit(context,kind,position,extra)
 local remote=RS.Remotes:FindFirstChild("BowEffect")
 if not remote then return end
 local packet={Kind=kind,BowId=context.Id,Position=position,Started=workspace:GetServerTimeNow()}
 for key,value in pairs(extra or {}) do packet[key]=value end
 for _,viewer in ipairs(Players:GetPlayers()) do
  local part=root(viewer.Character)
  if viewer==context.Player or (part and (part.Position-position).Magnitude<=320) then remote:FireClient(viewer,"Special",packet) end
 end
end
local function valid(context)
 local player=context.Player
 return player.Parent and player.Character==context.Character and living(context.Character)
  and not player:GetAttribute("IsDead") and not GameState:IsGameOver()
  and not RS:GetAttribute("WorldRestoring") and player:GetAttribute("InteriorId")==context.Interior
  and (context.Interior or (not RS:GetAttribute("WorldShifting") and RS:GetAttribute("BiomeVisitSerial")==context.Visit))
end

-- Position data is captured before direct damage can destroy the struck model.
function Service:Impact(context,position,direction,target,arrow)
 local def=Specials[context.Id]
 if not def or def.Id=="PiercingShot" or not valid(context) then return end
 local flat=Vector3.new(direction.X,0,direction.Z)
 flat=flat.Magnitude>.01 and flat.Unit or Vector3.zAxis
 local follows=def.Id=="FlareArrow" or def.Id=="LightningRod"
 local center=follows and position or grounded(position,geometryParams())
 local model=Instance.new("Model");model.Name=def.Id;model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
 local anchor=Instance.new("Part");anchor.Name="Anchor";anchor.Size=Vector3.one*.1
 anchor.Anchored=true;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false
 anchor.Transparency=1;anchor.CFrame=CFrame.lookAt(center,center+flat);anchor.Parent=model;model.PrimaryPart=anchor
 local duration=def.Duration or (def.Id=="FlareArrow" and def.Delay+.6)
  or (def.FormationTime+def.RainDuration+def.FlightTime+def.FinaleDelay+.8)
 model:SetAttribute("BowId",context.Id);model:SetAttribute("Started",workspace:GetServerTimeNow())
 model:SetAttribute("Duration",duration);model:SetAttribute("OwnerUserId",context.Player.UserId)
 if def.Id=="StarBarrage" then
  local params=geometryParams()
  for i=1,def.Stars do
   local origin=center+Vector3.new(math.cos(i*math.pi/4)*13,26+(i%2)*4,math.sin(i*math.pi/4)*13)
   local ceiling=workspace:Raycast(center+Vector3.yAxis*2,origin-(center+Vector3.yAxis*2),params)
   if ceiling then origin=ceiling.Position+ceiling.Normal*.6 end
   model:SetAttribute("StarOrigin"..i,origin)
  end
 elseif def.Id=="VineTrap" then
  local params=geometryParams()
  for i=0,12 do
   local sample=anchor.CFrame:PointToWorldSpace(Vector3.new(0,2,(i/12-.5)*def.Length))
   model:SetAttribute("Ground"..i,anchor.CFrame:PointToObjectSpace(grounded(sample,params)).Y)
  end
 end
 model.Parent=folder("BowSpecialEffects")
 local followRoot=follows and root(target)
 local followOffset=followRoot and followRoot.CFrame:PointToObjectSpace(position)
 local arrowOffset=followRoot and arrow and followRoot.CFrame:ToObjectSpace(arrow:GetPivot())
 local started=os.clock();local lastTick=0;local tickCount=0;local trapped={};local meteors={}
 local starHits,assigned={},{};local launched=0;local finishedStars=0;local finaleAt
 local connection
 local function cleanup()
  if connection then connection:Disconnect();connection=nil end
  for _,meteor in ipairs(meteors) do if meteor.Arrow.Parent then meteor.Arrow:Destroy() end end
  model:Destroy()
 end
 local function damage(enemy,factor)
  if living(enemy) then context.Deal(enemy,context.Damage*factor,"Bow","BowProjectile") end
 end
 local function shootStar(index)
  local from=model:GetAttribute("StarOrigin"..index)
  model:SetAttribute("StarLaunched",index)
  local chosen
  for _,record in ipairs(targets(context,center+Vector3.yAxis*2,def.Radius)) do
   if (assigned[record.Model] or 0)<def.StarsPerTarget then chosen=record;break end
  end
  local destination
  if chosen then
   assigned[chosen.Model]=(assigned[chosen.Model] or 0)+1;destination=chosen.Root.Position
  else
   destination=grounded(center+Vector3.new(math.cos(index*2.4)*11,2,math.sin(index*2.4)*11),geometryParams())
  end
  local delta=destination-from
  if delta.Magnitude<.01 then delta=-Vector3.yAxis end
  local arrow=BowVisuals.CreateArrow(context.Id,8,true,from,delta.Unit)
  arrow:SetAttribute("BowMeteor",true);arrow.Parent=folder("CombatProjectiles")
  table.insert(meteors,{Arrow=arrow,Position=from,Velocity=delta/def.FlightTime,
   Elapsed=0,Index=index,Target=chosen and chosen.Model,Destination=destination})
 end
 local function updateMeteors(dt)
  for i=#meteors,1,-1 do
   local meteor=meteors[i]
   local step=math.min(dt,math.max(0,def.FlightTime-meteor.Elapsed))
   local displacement=meteor.Velocity*step
   local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
   local ignored={folder("CombatProjectiles"),folder("BowSpecialEffects")}
   for _,p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(ignored,p.Character) end end
   for enemy,n in pairs(starHits) do if n>=def.StarsPerTarget then table.insert(ignored,enemy) end end
   params.FilterDescendantsInstances=ignored
   local hit=displacement.Magnitude>.001 and workspace:Raycast(meteor.Position,displacement,params)
   meteor.Elapsed+=step
   meteor.Position=hit and hit.Position or meteor.Position+displacement
   meteor.Arrow:PivotTo(CFrame.lookAt(meteor.Position,meteor.Position+meteor.Velocity))
   if hit or meteor.Elapsed>=def.FlightTime-.001 then
    local enemy=hit and hit.Instance
    while enemy and enemy~=workspace and not Tags:HasTag(enemy,"Monster") do enemy=enemy.Parent end
    if enemy and enemy~=workspace and enemy:GetAttribute("InteriorId")==context.Interior and (starHits[enemy] or 0)<def.StarsPerTarget then
     starHits[enemy]=(starHits[enemy] or 0)+1;damage(enemy,def.StarDamage)
    end
    local shard=grounded(meteor.Position,geometryParams())
    model:SetAttribute("Shard"..meteor.Index,shard)
    emit(context,"StarHit",meteor.Position)
    meteor.Arrow:SetAttribute("BowInFlight",false);Debris:AddItem(meteor.Arrow,.4)
    table.remove(meteors,i);finishedStars+=1
    if finishedStars==def.Stars then finaleAt=os.clock()+def.FinaleDelay end
   end
  end
 end
 connection=RunService.Heartbeat:Connect(function(dt)
  if not model.Parent or not valid(context) then cleanup();return end
  local age=os.clock()-started
  -- Give the final damage tick its remaining fraction before expiring.
  if age>=duration+.05 then
   if def.Id=="SporeArrow" and lastTick<def.Duration then
    for _,record in ipairs(targets(context,center+Vector3.yAxis*2,def.Radius)) do damage(record.Model,def.TickDamage*(def.Duration-lastTick)) end
   end
   cleanup();return
  end
  if followRoot and followRoot.Parent then
   center=followRoot.CFrame:PointToWorldSpace(followOffset)
   model:PivotTo(CFrame.lookAt(center,center+flat))
   if arrow and arrow.Parent and arrowOffset then arrow:PivotTo(followRoot.CFrame*arrowOffset) end
  end
  if def.Id=="SporeArrow" then
   if age-lastTick>=.25 then
    local elapsed=math.max(0,math.min(age,def.Duration)-lastTick);lastTick=math.min(age,def.Duration)
    for _,record in ipairs(targets(context,center+Vector3.yAxis*2,def.Radius)) do
     slow(record.Model,def.Slow*(boss(record.Model) and .5 or 1),.4)
     damage(record.Model,def.TickDamage*elapsed)
    end
   end
  elseif def.Id=="FlareArrow" then
   if tickCount==0 and age>=def.Delay then
    tickCount=1;emit(context,"FlareBurst",center,{Radius=def.Radius})
    for _,record in ipairs(targets(context,center,def.Radius)) do
     context.Reveal(record.Model,def.Reveal,Color3.fromRGB(255,210,107))
     if record.Distance<=def.StaggerRadius and not boss(record.Model) then stagger(record.Model,def.Stagger) end
     damage(record.Model,def.Blast)
    end
   end
  elseif def.Id=="LightningRod" then
   if tickCount<def.Pulses and age>=tickCount*(def.Duration/def.Pulses)+.1 then
    tickCount+=1
    local extra=context.ForkTargets or 0;local factor=def.PulseDamage*(1+(context.ForkBonus or 0))
    emit(context,"StormPulse",center,{Radius=def.Radius})
    for i,record in ipairs(targets(context,center,def.Radius)) do
     if i>def.Targets+extra then break end
     emit(context,"Lightning",center,{To=record.Root.Position})
     damage(record.Model,factor)
    end
   end
  elseif def.Id=="VineTrap" then
   if age-lastTick>=.1 then
    lastTick=age
    for _,record in ipairs(targets(context,center+Vector3.yAxis*2,def.Length*.75)) do
     local point=anchor.CFrame:PointToObjectSpace(record.Root.Position)
     local sample=math.clamp(math.floor((point.Z/def.Length+.5)*12+.5),0,12)
     local ground=model:GetAttribute("Ground"..sample) or 0
     if math.abs(point.X)<=def.Width*.5 and math.abs(point.Z)<=def.Length*.5 and math.abs(point.Y-ground)<=6 and not trapped[record.Model] then
      trapped[record.Model]=true
      if boss(record.Model) then slow(record.Model,def.BossSlow,def.Root) else stagger(record.Model,def.Root) end
      emit(context,"VineCatch",record.Root.Position,{Duration=def.Root})
      damage(record.Model,def.TrapDamage)
     end
    end
   end
  elseif def.Id=="StarBarrage" then
   updateMeteors(dt)
   if launched<def.Stars and age>=def.FormationTime+launched*def.RainDuration/(def.Stars-1) then
    launched+=1;shootStar(launched)
   end
   if finaleAt and os.clock()>=finaleAt and tickCount==0 then
    tickCount=1;emit(context,"StarFinale",center,{Radius=def.Radius})
    model:SetAttribute("Detonated",true)
    for _,record in ipairs(targets(context,center+Vector3.yAxis*2,def.Radius)) do
     if boss(record.Model) then slow(record.Model,def.BossSlow,def.SlowDuration)
     elseif not record.Root.Anchored then
      local obstruction=workspace:Raycast(record.Root.Position,Vector3.yAxis*(def.Lift+2),geometryParams())
      local height=obstruction and math.max(0,obstruction.Distance-2) or def.Lift
      local v=record.Root.AssemblyLinearVelocity
      record.Root.AssemblyLinearVelocity=Vector3.new(v.X,math.max(v.Y,math.sqrt(2*workspace.Gravity*height)),v.Z)
      stagger(record.Model,.4)
     end
     damage(record.Model,record.Distance<=def.InnerRadius and def.Blast or def.OuterBlast)
    end
   end
  end
 end)
 Debris:AddItem(model,duration+1)
end

function Service:Context(player,id,damage,deal,reveal,forkTargets,forkBonus)
 return {Player=player,Character=player.Character,Interior=player:GetAttribute("InteriorId"),
  Visit=RS:GetAttribute("BiomeVisitSerial"),Id=id,Damage=damage,Deal=deal,Reveal=reveal,
  ForkTargets=forkTargets,ForkBonus=forkBonus}
end
return Service
