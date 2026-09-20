-- Opt-in depth-E fights own their health and single reward independently of streaming.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Tags=game:GetService("CollectionService")
local RunService=game:GetService("RunService")
local Catalog=require(RS.Shared.OverhaulCatalog)
local Biomes=require(RS.Shared.OverhaulBiomes)
local Codec=require(script.Parent.WorldSnapshotCodec)
local Loot=require(script.Parent.LootService)
local Art=require(RS.Shared.Art.OverhaulBuildModels)
local ServerUtil=require(script.Parent.ServerUtil)
local Service={_serial=nil,_records={},_sites={},_actors={},_chests={}}
local order={"Forest","Desert","Swamp","FrozenTundra","Volcanic","CrystalWastes","AuroraVale","StarfallCrater","SaltglassCoast","StormspireHighlands","MyceliumHollow","IronrootBadlands","CanopySea","SunkenArchive","UmbralDepths","ShattermoonExpanse"}
local trophyFor={};for i,id in ipairs(order) do trophyFor[id]=Catalog.Trophies[i] end
local function alive(player)
 return ServerUtil.IsLiving(player,{ExcludeInterior=true})
end
local function active()
 return not RS:GetAttribute("WorldRestoring") and not RS:GetAttribute("WorldShifting") and not require(script.Parent.GameStateService):IsGameOver()
end
local function decoration(parent,name,position,size,color)
 return ServerUtil.Part(parent,name,size,position,{CanCollide=false,CanTouch=false,Color=color,Material=Enum.Material.Neon})
end
function Service:_visit()
 local serial=require(script.Parent.BiomeService):GetVisitSerial()
 if self._serial~=serial then
  self._serial=serial
  local actors,chests=self._actors,self._chests
  self._records={};self._sites={};self._actors={};self._chests={}
  for _,model in pairs(actors) do if model.Parent then model:Destroy() end end
  for _,chest in pairs(chests) do if chest.Parent then chest:Destroy() end end
 end
 return serial
end
function Service:_record(biome)
 if not self._records[biome] then
  local source=Biomes.Biomes[biome];local selected=source.Creatures[1]
  for _,id in ipairs(source.Creatures) do if Biomes.Creatures[id].Role=="H" then selected=id;break end end
  self._records[biome]={Creature=selected,Started=false,Completed=false,Participants={},Health=16*Catalog.StandardDamage[8],MaxHealth=16*Catalog.StandardDamage[8]}
 end
 self._records[biome].Participants=self._records[biome].Participants or {}
 return self._records[biome]
end
function Service:_participants(biome,model)
 local state=self:_record(biome)
 if state.Completed or not state.Started or not model or not model.Parent then return end
 local position=model:GetPivot().Position
 for _,player in ipairs(Players:GetPlayers()) do
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if root and alive(player) and (root.Position-position).Magnitude<=80 then state.Participants[tostring(player.UserId)]=true end
 end
end
function Service:_labels(biome)
 local state=self:_record(biome)
 for _,site in pairs(self._sites[biome] or {}) do
  if site.Prompt.Parent then
   site.Prompt.Enabled=not state.Started and not state.Completed
   site.Prompt.ActionText="Challenge elite · shared "..Catalog.Items[trophyFor[biome]].Name
   site.Label.Text=state.Completed and "ELITE DEFEATED · REWARD CACHE" or state.Started and "ELITE CHALLENGE ACTIVE" or "OPTIONAL ELITE · HOLD F TO BEGIN"
  end
 end
end
function Service:_reward(biome,site)
 local state=self:_record(biome)
 if not state.Completed or self._chests[biome] or not site.Model.Parent then return end
 if not state.Reward then
  local slots={};for i=1,24 do slots[i]=false end
  local count=0;for _ in pairs(state.Participants) do count+=1 end
  slots[1]={Id=trophyFor[biome],N=3+count}
  state.Reward={Tier=2,Table="EliteClaim",SlotCount=24,Slots=slots}
 end
 local serial=self._serial
 local chest=Art.Create("Chest");chest.Name="Elite reward";chest:SetAttribute("BuildType",nil)
 chest:SetAttribute("EliteEncounterId",biome);chest:SetAttribute("SlotCount",24);chest:SetAttribute("MapLabel","Elite reward")
 chest:PivotTo(CFrame.new(site.Metadata.Position+Vector3.new(-4,2,4)))
 chest.Destroying:Connect(function()
  if self._serial==serial and self._chests[biome]==chest then
   state.Reward=Loot:CaptureChestState(chest);self._chests[biome]=nil
  end
 end)
 Loot:RestoreChestState(chest,Codec.Copy(state.Reward))
 chest.Parent=site.Model;self._chests[biome]=chest;Tags:AddTag(chest,"Rare_Chest")
end
function Service:_spawnPosition(site)
 local world=require(script.Parent.OverhaulWorldService)
 local center=site.Metadata.Position
 for radius=20,56,12 do
  for i=1,12 do
   local angle=i*math.pi/6;local p=center+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)
   if world:IsSafe(p,5) then
    local y=world:GetHeight(p.X,p.Z)
    local overlaps=OverlapParams.new();overlaps.FilterType=Enum.RaycastFilterType.Exclude;overlaps.FilterDescendantsInstances={site.Model}
    local occupied=false
    for _,part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(p.X,y+4,p.Z),Vector3.new(7,7,7),overlaps)) do if part.CanCollide then occupied=true;break end end
    if not occupied then return Vector3.new(p.X,y,p.Z) end
   end
  end
 end
end
function Service:_spawn(biome,site,position)
 local state=self:_record(biome)
 if state.Completed or self._actors[biome] then return false end
 position=position or (state.Actor and (Codec.ReadCFrame(state.Actor.Transform).Position-Vector3.new(0,4,0))) or self:_spawnPosition(site)
 if not position then return false end
 local serial=self._serial
 local model=require(script.Parent.EnemySpawner):Spawn(state.Creature,position,8,0,nil,state.Actor)
 if not model then return false end
 -- Spawn's loot listener also checks this flag at death; no default creature drops.
 model:SetAttribute("NoLoot",true);model:SetAttribute("EliteEncounterId",biome);model:SetAttribute("RegionDepth",5)
 model:SetAttribute("DisplayName",Biomes.Biomes[biome].DisplayName.." Elite · "..Biomes.Creatures[state.Creature].Name)
 model:SetAttribute("MapLabel","Elite challenge")
 local hum=model:FindFirstChildOfClass("Humanoid")
 hum.MaxHealth=state.MaxHealth;hum.Health=math.max(.001,state.Health)
 local glow=Instance.new("Highlight");glow.FillColor=Color3.fromRGB(226,172,68);glow.OutlineColor=Color3.fromRGB(255,227,147);glow.FillTransparency=.88;glow.OutlineTransparency=.2;glow.DepthMode=Enum.HighlightDepthMode.Occluded;glow.Parent=model
 local light=Instance.new("PointLight");light.Color=glow.OutlineColor;light.Range=9;light.Brightness=.65;light.Parent=model.PrimaryPart
 self._actors[biome]=model;model.Parent=site.Model
 hum.HealthChanged:Connect(function(hp) if self._serial==serial then state.Health=math.max(0,hp) end end)
 hum.Died:Connect(function()
  if self._serial~=serial or state.Completed then return end
  self:_participants(biome,model)
  state.Completed=true;state.Health=0;state.Actor=nil;self._actors[biome]=nil
  self:_reward(biome,site);self:_labels(biome)
  model:Destroy()
 end)
 model.Destroying:Connect(function()
  if self._serial==serial and self._actors[biome]==model then
   state.Actor=Codec.Actor(model);state.Health=hum.Health;self._actors[biome]=nil
  end
 end)
 self:_labels(biome)
 return true
end
function Service:Bind(landmark,metadata)
 if tonumber(metadata.Depth)~=5 or not trophyFor[metadata.Biome] then return end
 self:_visit()
 local biome=metadata.Biome;local state=self:_record(biome)
 self._sites[biome]=self._sites[biome] or {}
 local altar=decoration(landmark,"EliteChallenge",metadata.Position+Vector3.new(-4,3,-4),Vector3.new(2,2,2),Color3.fromRGB(212,156,52))
 local prompt=Instance.new("ProximityPrompt");prompt.ObjectText=Biomes.Biomes[biome].DisplayName.." elite";prompt.KeyboardKeyCode=Enum.KeyCode.F;prompt.RequiresLineOfSight=false;prompt.HoldDuration=1.5;prompt.MaxActivationDistance=8;prompt.Parent=altar
 local billboard=Instance.new("BillboardGui");billboard.Size=UDim2.fromOffset(290,48);billboard.StudsOffset=Vector3.new(0,3,0);billboard.MaxDistance=45;billboard.Parent=altar
 local label=Instance.new("TextLabel");label.Size=UDim2.fromScale(1,1);label.TextScaled=true;label.TextWrapped=true;label.Font=Enum.Font.GothamBold;label.TextColor3=Color3.fromRGB(255,225,144);label.TextStrokeTransparency=.35;label.BackgroundTransparency=1;label.Parent=billboard
 local site={Model=landmark,Metadata=metadata,Prompt=prompt,Label=label};self._sites[biome][metadata.RegionId]=site
 prompt.Triggered:Connect(function(player)
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if not active() or not alive(player) or not root or (root.Position-altar.Position).Magnitude>10 or (RS:GetAttribute("CampaignTier") or 1)<8 then return end
  if state.Started or state.Completed or self._actors[biome] then return end
  local position=self:_spawnPosition(site)
  if not position then label.Text="CLEAR SPACE NEAR THIS SITE TO BEGIN";return end
  state.Started=true;state.SiteId=metadata.RegionId
  if not self:_spawn(biome,site,position) then state.Started=false;state.SiteId=nil
  else state.Participants[tostring(player.UserId)]=true;self:_participants(biome,self._actors[biome]) end
 end)
 landmark.Destroying:Connect(function()
  if self._sites[biome] and self._sites[biome][metadata.RegionId]==site then self._sites[biome][metadata.RegionId]=nil end
 end)
 if state.SiteId==metadata.RegionId then
  if state.Completed then self:_reward(biome,site)
  elseif state.Started then self:_spawn(biome,site) end
 end
 self:_labels(biome)
end
function Service:CaptureWorldState()
 for biome,model in pairs(self._actors) do
  if model.Parent then self:_participants(biome,model);local state=self:_record(biome);state.Actor=Codec.Actor(model);state.Health=model:FindFirstChildOfClass("Humanoid").Health end
 end
 for biome,chest in pairs(self._chests) do if chest.Parent then self:_record(biome).Reward=Loot:CaptureChestState(chest) end end
 return {Version=1,Serial=self._serial,Records=Codec.Copy(self._records)}
end
function Service:RestoreWorldState(raw)
 self._serial=nil;self._records={};self._sites={};self._actors={};self._chests={}
 if not raw then return end
 assert(type(raw)=="table" and raw.Version==1 and type(raw.Records)=="table","Invalid elite ledger")
 Codec.BoundedCount(raw.Records,16)
 for biome,state in pairs(raw.Records) do
  assert(trophyFor[biome] and type(state)=="table" and Biomes.Creatures[state.Creature] and Biomes.Creatures[state.Creature].Biome==biome,"Unknown elite")
  assert(state.MaxHealth==16*Catalog.StandardDamage[8] and type(state.Health)=="number" and state.Health>=0 and state.Health<=state.MaxHealth,"Invalid elite health")
  if state.Participants then
   Codec.BoundedCount(state.Participants,6)
   for userId,joined in pairs(state.Participants) do assert(type(userId)=="string" and tonumber(userId) and joined==true,"Invalid elite participant") end
  end
  if state.Actor then Codec.ReadCFrame(state.Actor.Transform) end
  if state.Reward then assert(state.Completed and state.Reward.SlotCount==24 and #state.Reward.Slots==24,"Invalid elite reward") end
 end
 self._serial=raw.Serial;self._records=Codec.Copy(raw.Records)
end
function Service:Init()
 if self._initialized then return end;self._initialized=true
 _G.Ecoshift=_G.Ecoshift or {};local previous=_G.Ecoshift.OnOverhaulLandmark
 _G.Ecoshift.OnOverhaulLandmark=function(model,metadata) if previous then previous(model,metadata) end;self:Bind(model,metadata) end
 local elapsed=0
 RunService.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<1 then return end;elapsed=0
  if not RS:GetAttribute("WorldRestoring") then
   self:_visit()
   if active() then
    for biome,state in pairs(self._records) do
     self:_participants(biome,self._actors[biome])
     local site=state.SiteId and self._sites[biome] and self._sites[biome][state.SiteId]
     if site and state.Started and not state.Completed and not self._actors[biome] then self:_spawn(biome,site) end
    end
   end
  end
 end)
end
return Service
