-- World-owned progression. All interactions are revalidated at their server-created site.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(RS.Shared.CampaignConfig)
local Util = require(RS.Shared.Util)
local ServerUtil = require(script.Parent.ServerUtil)
local Service = {_sites={},_lastRequests={}}
local function service(id) return require(script.Parent[id]) end
local function fresh() return {SchemaVersion=1,Tier=1,Elapsed=0,TierSeconds=0,Transition=0,Facts={},Paid={},Completed={},Defense=0,Instruments={},Endurance=false} end
Service._state = fresh()
local function alive(player)
 return ServerUtil.IsLiving(player)
end
local function active()
 if RS:GetAttribute("WorldRestoring") or RS:GetAttribute("WorldShifting")
  or service("GameStateService"):IsGameOver() or service("RoundService"):IsEnded() then return false end
 for _,p in ipairs(Players:GetPlayers()) do if alive(p) then return true end end
 return false
end
local function near(player,part,range)
 return ServerUtil.IsNear(player,part,range)
end
function Service:GetTier() return self._state.Tier end
function Service:GetElapsed() return self._state.Elapsed end
function Service:GetThreatTier() return self._state.Transition>0 and math.max(1,self._state.Tier-1) or self._state.Tier end
function Service:GetPressure() return math.clamp(self._state.TierSeconds/5400,0,1) end
function Service:GetEnduranceHours() return self._state.Endurance and math.max(0,(self._state.Elapsed-(self._state.CompleteAt or self._state.Elapsed))/3600) or 0 end
function Service:GetMilestone() return Config.Milestones[self:GetTier()] end
function Service:_publish()
 local s=self._state
 RS:SetAttribute("CampaignTier",s.Tier)
 workspace:SetAttribute("CampaignTier",s.Tier)
 RS:SetAttribute("CampaignTierActiveSeconds",s.TierSeconds)
 RS:SetAttribute("MainBiomesUniform",s.AllBiomesAt~=nil and s.Elapsed-s.AllBiomesAt>=3600)
 RS:SetAttribute("CampaignPressure",self:GetPressure())
 RS:SetAttribute("CampaignThreatTier",self:GetThreatTier())
 RS:SetAttribute("CampaignTransitionRemaining",math.ceil(s.Transition))
 RS:SetAttribute("CampaignElapsed",s.Elapsed)
 RS:SetAttribute("CampaignComplete",s.CompleteAt~=nil)
 for _,milestone in ipairs(Config.Milestones) do RS:SetAttribute("CampaignCompleted_"..milestone.Id,s.Completed[milestone.Id]==true) end
 RS:SetAttribute("CampaignMilestone",self:GetMilestone().Name)
 if self._remote then self._remote:FireAllClients("State",self:GetState()) end
end
function Service:GetState()
 local s=Util.DeepCopy(self._state)
 s.Cost=self:GetCost();s.Milestone=self:GetMilestone();s.Ready=self:IsPrepared()
 s.CreativeWorld=workspace:GetAttribute("WorldType")=="Creative"
 return s
end
function Service:GetCost()
 -- Freeze the roster size once the world is initialized, including local worlds.
 if not self._state.CrewSize then self._state.CrewSize=math.clamp(RS:GetAttribute("OriginalCrewSize") or #Players:GetPlayers(),1,6) end
 local factor=1+0.35*(self._state.CrewSize-1)
 local cost={}
 for id,n in pairs(self:GetMilestone().Cost or {}) do cost[id]=math.ceil(n*factor) end
 return cost
end
function Service:IsPrepared()
 local m,s=self:GetMilestone(),self._state
 for fact in pairs(m.Facts or {}) do if not s.Facts[fact] then return false end end
 if m.Instruments then local n=0;for _ in pairs(s.Instruments) do n+=1 end;if n<m.Instruments then return false end end
 for id,n in pairs(self:GetCost()) do if (s.Paid[id] or 0)<n then return false end end
 return true
end
function Service:RecordFact(id,source)
 -- No remote calls this directly. Physical prompts/interior progression supply known IDs.
 if type(id)~="string" then return false end
 local s=self._state
 if id=="CalibratedInstrument" then
  if s.Tier~=5 or type(source)~="string" or s.Instruments[source] then return false end
  s.Instruments[source]=true
 elseif not s.Facts[id] then s.Facts[id]=true else return false end
 if s.Tier==3 and (id=="Cooling" or id=="Focus") and not s.EnchantChoice then
  s.EnchantChoice=true
  local module=script.Parent:FindFirstChild("EnchantingService")
  if module then require(module):GrantChoice("FirstForge",{"MeasuredEdge","SetPoint","SplitArc","Blindside","HeavyEcho","EchoCast","DrawForce","OpenSeam","CampStitch"}) end
 end
 self:_publish()
 return true
end
function Service:OpenAt(player,station)
 if not near(player,station) then return false end
 self._access=self._access or {};self._access[player]=station
 self._remote:FireClient(player,"Open",self:GetState())
 return true
end
function Service:Contribute(player)
 if not near(player,self._camp) and not near(player,self._access and self._access[player]) then return false,"Visit the project desk or air system." end
 if self._state.Started then return false,"Visit the project desk in camp." end
 local inv=service("InventoryService")
 local cost={}
 for id,n in pairs(self:GetCost()) do
  local amount=math.min(math.max(0,n-(self._state.Paid[id] or 0)),inv:TotalCount(player,id))
  if amount>0 then table.insert(cost,{Id=id,N=amount}) end
 end
 if #cost==0 then return false,"No required materials in your pack." end
 if not inv:PayCost(player,cost,true) then return false,"Materials changed. Try again." end
 for _,entry in ipairs(cost) do self._state.Paid[entry.Id]=(self._state.Paid[entry.Id] or 0)+entry.N end
 inv:Sync(player);service("ExpeditionRewardsService"):RecordActivity(player);self:_publish()
 return true,"Materials contributed to the shared project."
end
function Service:CreativePrepare(player)
 if workspace:GetAttribute("WorldType")~="Creative" then return false,"This shortcut is only available in creative worlds." end
 if not near(player,self._camp) and not near(player,self._access and self._access[player]) then return false,"Visit the expedition project." end
 local s,m=self._state,self:GetMilestone()
 if s.CompleteAt then return false,"The expedition project is already complete." end
 if s.Started then return false,"Finish the active encounter or defense first." end
 for fact in pairs(m.Facts or {}) do s.Facts[fact]=true end
 if m.Instruments then
  for index=1,m.Instruments do s.Instruments["CreativeRegion"..index]=true end
 end
 for id,amount in pairs(self:GetCost()) do s.Paid[id]=amount end
 if s.Tier==3 and (s.Facts.Cooling or s.Facts.Focus) and not s.EnchantChoice then
  s.EnchantChoice=true
  local module=script.Parent:FindFirstChild("EnchantingService")
  if module then require(module):GrantChoice("FirstForge",{"MeasuredEdge","SetPoint","SplitArc","Blindside","HeavyEcho","EchoCast","DrawForce","OpenSeam","CampStitch"}) end
 end
 self:_publish()
 return true,"Creative preparation completed: discoveries and project materials are ready."
end
function Service:Begin(player)
 if not near(player,self._camp) then return false,"Visit the project desk in camp." end
 local s,m=self._state,self:GetMilestone()
 if s.CompleteAt then return false,"Campaign complete. Endurance is available." end
 -- The Archive is entered before its records are recovered; costs are repaired inside.
 if m.Interior and s.Facts.ArchiveRoute then return service("InteriorService"):Enter(player,m.Interior) end
 if not self:IsPrepared() then return false,"Recover the listed clues and contribute the required materials." end
 if m.Boss then
  s.Started=true
  return service("InteriorService"):Enter(player,m.Boss)
 end
 if not s.Started then s.Started=true;s.Defense=0;self._waveAt=0 end
 self:_publish();return true,"Defend the project. Progress pauses when nobody is nearby."
end
function Service:Complete(id)
 local s,m=self._state,self:GetMilestone()
 if m.Id~=id or s.Completed[id] then return false end
 local previousTier=s.Tier
 s.Completed[id]=true
 service("ExpeditionRewardsService"):AwardCampaign(id)
 if id=="BogKing" then service("EnchantingService"):GrantChoice("BogKing",{"DeepBite","SlipCut","GroundClaim","SplitFlight","RescueReserve"})
 elseif id=="WeatherTower" then service("EnchantingService"):GrantChoice("WeatherTower",{"SurveyLink","SharedCover"})
 elseif id=="MoonWarden" then service("EnchantingService"):GrantChoice("MoonWarden",{"MeasuredEdge","SetPoint","SplitArc","Blindside","HeavyEcho","EchoCast","DrawForce","OpenSeam","WeatherMemory","ReturnShot"},"Maximum") end
 if s.Tier<8 then
  s.Tier+=1;if s.Tier==4 then s.AllBiomesAt=s.Elapsed end;s.TierSeconds=0;s.Transition=120;s.Paid={};s.Started=false;s.Defense=0
 else s.CompleteAt=s.Elapsed;s.Started=false end
 self:_publish()
 if s.Tier>previousTier then service("BiomeService"):OnCampaignTierAdvanced(previousTier,s.Tier) end
 self._siteRevision=nil
 return true
end
function Service:CaptureWorldState() return Util.DeepCopy(self._state) end
function Service:RestoreWorldState(raw)
 local s=fresh()
 if raw then
  assert(type(raw)=="table" and raw.SchemaVersion==1,"Unsupported campaign snapshot")
  for _,key in ipairs({"Tier","Elapsed","TierSeconds","Transition","Defense"}) do
   local n=raw[key];assert(type(n)=="number" and n==n and n>=0 and n<1e9,"Invalid campaign "..key);s[key]=n
  end
  assert(s.Tier>=1 and s.Tier<=8 and s.Tier%1==0,"Invalid campaign tier")
  if raw.CrewSize then assert(type(raw.CrewSize)=="number" and raw.CrewSize%1==0 and raw.CrewSize>=1 and raw.CrewSize<=6,"Invalid campaign crew");s.CrewSize=raw.CrewSize end
  for _,key in ipairs({"Facts","Paid","Completed","Instruments"}) do assert(type(raw[key])=="table","Missing campaign ledger");s[key]=Util.DeepCopy(raw[key]) end
  if raw.AllBiomesAt~=nil then assert(type(raw.AllBiomesAt)=="number" and raw.AllBiomesAt>=0 and raw.AllBiomesAt<=s.Elapsed,"Invalid biome-unlock time");s.AllBiomesAt=raw.AllBiomesAt end
  s.Started=raw.Started==true;s.Endurance=raw.Endurance==true;s.EnchantChoice=raw.EnchantChoice==true
  if raw.CompleteAt then assert(type(raw.CompleteAt)=="number" and raw.CompleteAt>=0 and raw.CompleteAt<=s.Elapsed,"Invalid campaign finish");s.CompleteAt=raw.CompleteAt end
 end
 self._state=s;self:_publish()
end
local function sitePart(name,position,parent,color)
 local p=Instance.new("Part");p.Name=name;p.Anchored=true;p.Size=Vector3.new(3,3,3);p.Position=position+Vector3.new(0,1.5,0)
 p.Material=Enum.Material.Wood;p.Color=color or Color3.fromRGB(170,135,65);p.Parent=parent
 return p
end
function Service:_prompt(part,text,callback)
 local p=Instance.new("ProximityPrompt");p.ActionText=text;p.ObjectText="Expedition project";p.KeyboardKeyCode=Enum.KeyCode.F
 p.MaxActivationDistance=10;p.RequiresLineOfSight=false;p.HoldDuration=.5;p.Parent=part
 p.Triggered:Connect(function(player) if active() and near(player,part) then callback(player) end end)
end
function Service:_refreshSites()
 local world=service("OverhaulWorldService")
 if not self._camp or not self._camp.Parent then
  local spawn=workspace:FindFirstChildWhichIsA("SpawnLocation",true)
  local pos=spawn and spawn.Position or Vector3.new(0,world:GetHeight(0,0),0)
  self._camp=sitePart("CampaignDesk",Vector3.new(pos.X+18,world:GetHeight(pos.X+18,pos.Z+12),pos.Z+12),self._folder)
  self._camp:SetAttribute("MapLabel","Campaign desk")
  self:_prompt(self._camp,"Open campaign",function(player) self._remote:FireClient(player,"Open",self:GetState()) end)
 end
 local biome=service("BiomeService")
 local revision=tostring(biome:GetVisitSerial())..":"..self:GetTier()
 if revision==self._siteRevision then return end
 for _,p in pairs(self._sites) do p:Destroy() end;self._sites={}
 self._siteRevision=revision
 local marks=world:GetLandmarks()
 for _,clue in ipairs(Config.Clues) do
  if clue.Tier==self:GetTier() then
   for _,mark in ipairs(marks) do
    local depth=type(mark.Depth)=="string" and (string.byte(mark.Depth)-64) or mark.Depth
    if depth==clue.Depth and (not clue.Biomes or clue.Biomes[mark.Biome]) then
     local part=sitePart(clue.Id,mark.Position,self._folder)
     part:SetAttribute("MapLabel",clue.Name);part:SetAttribute("CampaignClue",clue.Id)
     table.insert(self._sites,part)
     self:_prompt(part,clue.Name,function(player)
      local changed=self:RecordFact(clue.Id,mark.Biome)
      if changed then service("ExpeditionRewardsService"):RecordActivity(player) end
      self._remote:FireClient(player,"Result",changed,changed and "Recovered for the whole crew." or "Already recovered.")
     end)
     break
    end
   end
  end
 end
end
function Service:_tick(dt)
 if not active() then return end
 local s=self._state
 s.Elapsed+=dt;s.TierSeconds+=dt;s.Transition=math.max(0,s.Transition-dt)
 local m=self:GetMilestone()
 if s.Started and m.Defense and self._camp then
  local nearby=0
  for _,p in ipairs(Players:GetPlayers()) do if near(p,self._camp,70) then nearby+=1 end end
  if nearby>0 then
   s.Defense=math.min(m.Defense,s.Defense+dt)
   if s.Elapsed>=(self._waveAt or 0) then
    self._waveAt=s.Elapsed+15
    service("EnemySpawner"):SpawnProjectDefense(self._camp.Position,math.clamp(nearby,1,3),s.Tier,"project:"..m.Id..":"..math.floor(s.Defense/15))
   end
   if s.Defense>=m.Defense then self:Complete(m.Id) end
  end
 end
 if s.Tier==7 and self:IsPrepared() then self:Complete("DeepArchive") end
 self:_publish()
end
function Service:Init()
 if self._initialized then return end;self._initialized=true
 self._remote=RS.Remotes:FindFirstChild("Campaign") or Instance.new("RemoteEvent")
 self._remote.Name="Campaign";self._remote.Parent=RS.Remotes
 self._folder=Instance.new("Folder");self._folder.Name="CampaignSites";self._folder.Parent=workspace
 self._remote.OnServerEvent:Connect(function(player,action)
  if type(action)~="string" or not alive(player) or not active() then return end
  if os.clock()-(self._lastRequests[player] or -math.huge)<0.25 then return end;self._lastRequests[player]=os.clock()
  local ok,reason
  if action=="State" then self._remote:FireClient(player,"State",self:GetState());return
  elseif action=="Contribute" then ok,reason=self:Contribute(player)
  elseif action=="CreativePrepare" then ok,reason=self:CreativePrepare(player)
  elseif action=="Begin" then ok,reason=self:Begin(player)
  elseif action=="Endurance" and near(player,self._camp) and self._state.CompleteAt then self._state.Endurance=true;ok=true;reason="Endurance enabled. The crew can keep exploring."
  else return end
  self._remote:FireClient(player,"Result",ok,reason);self:_publish()
 end)
 Players.PlayerRemoving:Connect(function(p) self._lastRequests[p]=nil end)
 local tick,sites=0,0
 RunService.Heartbeat:Connect(function(dt)
  tick+=math.min(dt,1);sites+=dt
  if tick>=1 then self:_tick(tick);tick=0 end
  if sites>=3 and not RS:GetAttribute("WorldRestoring") and not RS:GetAttribute("WorldShifting") then sites=0;self:_refreshSites() end
 end)
 self:_publish()
end
return Service
