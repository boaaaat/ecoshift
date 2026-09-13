-- Server-owned camp utilities; all work, supplies, and door states survive world saves.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Collection=game:GetService("CollectionService")
local TweenService=game:GetService("TweenService")
local Catalog=require(RS.Shared.OverhaulCatalog)
local Inventory=require(script.Parent.InventoryService)
local Codec=require(script.Parent.WorldSnapshotCodec)
local Stats=require(script.Parent.StatsService)
local S={_states={},_viewers={},_cooldowns={}}
local kinds={RainCollector=true,WaterFilter=true,Bedroll=true,SpikeTrap=true,Door=true,Gate=true,CampMarker=true,TrailBeacon=true}
local function alive(p)
 local h=p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
 return p and p.Parent==Players and h and h.Health>0 and not p:GetAttribute("IsDead") and not p:GetAttribute("WorldPlayerLoading") and not p:GetAttribute("WorldPlayerRestoring")
end
local function near(p,m)
 local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
 return alive(p) and root and m and m.Parent and (root.Position-m:GetPivot().Position).Magnitude<=9
end
local function paused()
 if RS:GetAttribute("WorldRestoring") or RS:GetAttribute("WorldShifting") or require(script.Parent.GameStateService):IsGameOver() then return true end
 for _,p in ipairs(Players:GetPlayers()) do if not p:GetAttribute("WorldPlayerLoading") and not p:GetAttribute("WorldPlayerRestoring") then return false end end
 return true
end
local function output(p,id,n)
 if n<=0 then return false,"Nothing ready yet" end
 if Inventory:Give(p,id,n,true,true)~=n then return false,"Make room in your inventory" end
 Inventory:Sync(p);return true,"Collected "..n.." "..id
end
function S:_door(m,state,open,instant)
 local leaf=m:FindFirstChild("DoorLeaf");local width=m:GetAttribute("DoorWidth") or 4
 if not leaf then return false end
 if not open and not instant then
  local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Exclude;overlap.FilterDescendantsInstances={m}
  for _,part in ipairs(workspace:GetPartBoundsInBox(m:GetPivot()*CFrame.new(0,4,0),Vector3.new(width,7.8,.8),overlap)) do
   local character=part:FindFirstAncestorOfClass("Model")
   if character and character:FindFirstChildOfClass("Humanoid") then return false end
  end
 end
 local target=m:GetPivot()*CFrame.new(-width/2,4,0)*CFrame.Angles(0,open and math.pi/2 or 0,0)*CFrame.new(width/2,0,0)
 if instant then leaf:PivotTo(target) else
  local from=leaf:GetPivot();local progress=Instance.new("NumberValue")
  local conn=progress.Changed:Connect(function(v)if leaf.Parent then leaf:PivotTo(from:Lerp(target,v)) end end)
  local tween=TweenService:Create(progress,TweenInfo.new(.25,Enum.EasingStyle.Quad),{Value=1});tween:Play()
  tween.Completed:Once(function()conn:Disconnect();progress:Destroy() end)
 end
 state.DoorOpen=open;m:SetAttribute("DoorOpen",open);return true
end
function S:Bind(m)
 if self._states[m] then return end
 local id=m:GetAttribute("BuildType");if not kinds[id] then return end
 if not m:GetAttribute("UtilityId") then m:SetAttribute("UtilityId",game:GetService("HttpService"):GenerateGUID(false)) end
 local state={Version=1,Type=id,Water=0,Input=0,FuelUses=0,Work=0,Started=false,Ammo=0,Cooldown=0,DoorOpen=false,Lifetime=id=="TrailBeacon" and 900 or false}
 self._states[m]=state
 local part=m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart",true);if not part then return end
 local prompt=Instance.new("ProximityPrompt");prompt.Name="UtilityPrompt";prompt.ActionText=(id=="Door" or id=="Gate") and "Open / close" or id=="Bedroll" and "Rest" or "Manage"
 prompt.ObjectText=Catalog.Items[id].Name;prompt.KeyboardKeyCode=Enum.KeyCode.F;prompt.GamepadKeyCode=Enum.KeyCode.ButtonX;prompt.RequiresLineOfSight=false;prompt.MaxActivationDistance=8;prompt.HoldDuration=.1;prompt.Parent=part
 prompt.Triggered:Connect(function(p)
  if not near(p,m) or paused() then return end
  local state=self._states[m];if not state then return end
  if id=="Door" or id=="Gate" then
   if state.Cooldown>0 then return end
   if self:_door(m,state,not state.DoorOpen) then state.Cooldown=.3 end
  else self._viewers[p]=m;self:_send(p,m,"Ready") end
 end)
 if id=="Door" or id=="Gate" then self:_door(m,state,false,true) end
 if id=="CampMarker" or id=="TrailBeacon" then m:SetAttribute("MapMarker",true);m:SetAttribute("MarkerName",Catalog.Items[id].Name) end
end
function S:GetShelter(position,character)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances=character and {character} or {}
 local hit=workspace:Raycast(position,Vector3.new(0,35,0),params)
 if not hit then return nil end
 local model=hit.Instance:FindFirstAncestorOfClass("Model")
 if model and Collection:HasTag(model,"Structure") then
  local id=model:GetAttribute("BuildType")
  if id=="Roof" or id=="Floor" or id=="Watchtower" then return model end
 end
 return nil
end
function S:Capture(m)local state=self._states[m];return state and Codec.Copy(state) end
function S:Restore(m,saved)
 if not saved then return end
 assert(type(saved)=="table" and saved.Version==1,"Invalid utility snapshot")
 self:Bind(m);self._states[m]=Codec.Copy(saved)
 if saved.Name then m:SetAttribute("MarkerName",saved.Name) end
 if saved.Type=="Door" or saved.Type=="Gate" then self:_door(m,self._states[m],saved.DoorOpen,true) end
end
function S:Remove(m)self._states[m]=nil end
function S:CanSalvage(m)
 local s=self._states[m];if not s then return true end
 if s.Water>0 or s.Input>0 or s.Started then return false,"Collect water and withdraw inputs before salvaging" end
 return true
end
function S:_send(p,m,message)
 local state=self._states[m];if state and self._remote then self._remote:FireClient(p,"State",{Model=m,State=Codec.Copy(state),Grade=m:GetAttribute("StationGrade") or m:GetAttribute("Grade") or Catalog.Placeables[state.Type].Grade,Message=message}) end
end
function S:Handle(p,action,data)
 if action=="Close" then self._viewers[p]=nil;return end
 local m=data.Model;local state=self._states[m]
 if not state or not near(p,m) or paused() then return false,"Move closer to that utility" end
 self._viewers[p]=m
 if action=="Open" then return true,"Ready"
 elseif action=="Collect" and (state.Type=="RainCollector" or state.Type=="WaterFilter") then
  local ok,why=output(p,"Water",state.Water);if ok then state.Water=0 end;return ok,why
 elseif action=="Input" and state.Type=="WaterFilter" then
  local n=data.Quantity or 1
  if type(n)~="number" or n%1~=0 or n<1 or n>20 or state.Input+n>20 then return false,"Filter holds 20 dirty water" end
  if not Inventory:PayCost(p,{{Id="DirtyWater",N=n}},true) then return false,"Need Dirty Water" end
  state.Input+=n;Inventory:Sync(p);return true,"Water queued for filtering"
 elseif action=="Withdraw" and state.Type=="WaterFilter" then
  -- A partly filtered serving returns dirty water; spent fuel stays spent.
  local n=state.Input+(state.Started and 1 or 0)
  local ok,why=output(p,"DirtyWater",n)
  if ok then state.Input=0;state.Work=0;state.Started=false end;return ok,why
 elseif action=="Fuel" and state.Type=="WaterFilter" then
  if state.FuelUses>190 then return false,"Filter fuel is full" end
  if not Inventory:PayCost(p,{{Id="Coal",N=1}},true) then return false,"Need Coal ×1" end
  state.FuelUses+=10;Inventory:Sync(p);return true,"Coal loaded: 10 filter batches"
 elseif action=="Ammo" and state.Type=="SpikeTrap" then
  if state.Ammo>190 then return false,"Trap supply is full" end
  if not Inventory:PayCost(p,{{Id="Bone",N=1}},true) then return false,"Need Bone ×1" end
  state.Ammo+=10;Inventory:Sync(p);return true,"Bone loaded: 10 triggers"
 elseif action=="Upgrade" and state.Type=="SpikeTrap" then
  local g=m:GetAttribute("StationGrade") or Catalog.Placeables.SpikeTrap.Grade
  if g>=8 then return false,"Trap fully upgraded" end
  if g>=(workspace:GetAttribute("CampaignTier") or 1) then return false,"Next campaign certification required" end
  if not Inventory:PayCost(p,Catalog.GetStationUpgradeCost(g+1),true) then return false,"Missing upgrade materials" end
  m:SetAttribute("StationGrade",g+1);Inventory:Sync(p);return true,"Trap upgraded"
 elseif action=="Rest" and state.Type=="Bedroll" then
  p:SetAttribute("RestingAtBedroll",p:GetAttribute("RestingAtBedroll")~=m:GetAttribute("UtilityId") and m:GetAttribute("UtilityId") or nil)
  return true,"Stand near the bedroll to recover stamina and exposure. Moving ends rest."
 elseif action=="Name" and (state.Type=="CampMarker" or state.Type=="TrailBeacon") then
  if type(data.Name)~="string" or #data.Name<1 or #data.Name>32 then return false,"Use a 1–32 character name" end
  local ok,result=pcall(function()return game:GetService("TextService"):FilterStringAsync(data.Name,p.UserId):GetNonChatStringForBroadcastAsync() end)
  if not ok then return false,"Name filtering unavailable; try again" end
  if not near(p,m) then return false,"Move closer" end
  state.Name=result;m:SetAttribute("MarkerName",result);return true,"Marker named"
 end
 return false,"Action unavailable"
end
function S:Init()
 if self._initialized then return end;self._initialized=true
 local folder=RS:WaitForChild("Remotes");local r=folder:FindFirstChild("UtilityBuild") or Instance.new("RemoteEvent");r.Name="UtilityBuild";r.Parent=folder;self._remote=r
 r.OnServerEvent:Connect(function(p,action,data)
  if type(action)~="string" or type(data)~="table" then return end
  local now=os.clock();if now-(self._cooldowns[p] or 0)<.15 then return end;self._cooldowns[p]=now
  local ok,msg=self:Handle(p,action,data)
  if self._viewers[p] then self:_send(p,self._viewers[p],msg) end
 end)
 local function bind(m)
  if not m:GetAttribute("UtilityId") then m:SetAttribute("UtilityId",game:GetService("HttpService"):GenerateGUID(false)) end
  self:Bind(m)
 end
 Collection:GetInstanceAddedSignal("Structure"):Connect(bind)
 for _,m in ipairs(Collection:GetTagged("Structure")) do bind(m) end
 Players.PlayerRemoving:Connect(function(p)self._viewers[p]=nil;self._cooldowns[p]=nil end)
 local elapsed=0
 RunService.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.25 then return end;local step=math.min(elapsed,.5);elapsed=0
  if paused() then return end
  local weather=require(script.Parent.BiomeService):GetWeather() or {}
  local raining=(tonumber(weather.Wet) or 0)>0 or tostring(weather.Id):lower():find("rain",1,true)~=nil or tostring(weather.Id):lower():find("storm",1,true)~=nil
  local monsters=Collection:GetTagged("Monster")
  for m,state in pairs(self._states) do
   if not m.Parent then self._states[m]=nil;continue end
   state.Cooldown=math.max(0,state.Cooldown-step)
   if state.Lifetime then
    state.Lifetime-=step
    if state.Lifetime<=0 then self._states[m]=nil;m:Destroy();continue end
   end
   if state.Type=="RainCollector" and raining and state.Water<10 then
    local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Exclude;ray.FilterDescendantsInstances={m}
    if not workspace:Raycast(m:GetPivot().Position+Vector3.new(0,4,0),Vector3.new(0,300,0),ray) then
     state.Work+=step;if state.Work>=60 then state.Work-=60;state.Water+=1 end
    end
   elseif state.Type=="WaterFilter" and state.Water<10 then
    if not state.Started and state.Input>0 and state.FuelUses>0 then state.Input-=1;state.FuelUses-=1;state.Started=true;state.Work=0 end
    if state.Started then state.Work+=step;if state.Work>=10 then state.Work=0;state.Started=false;state.Water+=1 end end
   elseif state.Type=="SpikeTrap" and state.Ammo>0 and state.Cooldown<=0 then
    for _,monster in ipairs(monsters) do
     local root=monster:IsA("Model") and (monster.PrimaryPart or monster:FindFirstChild("HumanoidRootPart"));local hum=monster:FindFirstChildOfClass("Humanoid")
     if root and hum and hum.Health>0 then
      local offset=m:GetPivot():PointToObjectSpace(root.Position)
      if math.abs(offset.X)<=2.8 and math.abs(offset.Z)<=2.8 and offset.Y>=0 and offset.Y<=6 then
       local g=math.clamp(m:GetAttribute("StationGrade") or 2,1,8)
       state.Ammo-=1;state.Cooldown=3
       require(script.Parent.CombatService):ApplyDamage(nil,monster,Catalog.StandardDamage[g]*.8,"Trap")
       break
      end
     end
    end
   elseif state.Type=="Bedroll" then
    for _,p in ipairs(Players:GetPlayers()) do
     if p:GetAttribute("RestingAtBedroll")==m:GetAttribute("UtilityId") then
      local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
      if not near(p,m) or not root or Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude>1 then p:SetAttribute("RestingAtBedroll",nil)
      else
       local energy=Stats:GetBase(p,"Stamina") or 0;local temp=Stats:GetBase(p,"Temperature") or 0
       Stats:SetBaseStats(p,{Stamina=math.min(Stats:GetStat(p,"MaxStamina") or 100,energy+step),Temperature=math.sign(temp)*math.max(0,math.abs(temp)-.2*step)})
      end
     end
    end
   end
  end
  for p,m in pairs(self._viewers) do if near(p,m) then self:_send(p,m) else self._viewers[p]=nil;r:FireClient(p,"Close",{}) end end
 end)
end
return S
