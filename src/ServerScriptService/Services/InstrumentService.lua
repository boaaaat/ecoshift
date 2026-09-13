-- Personalized instruments never reveal unearned forecasts or unexplored sites.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Collection=game:GetService("CollectionService")
local Http=game:GetService("HttpService")
local TextService=game:GetService("TextService")
local Catalog=require(RS.Shared.OverhaulCatalog)
local Biomes=require(RS.Shared.OverhaulBiomes)
local Instances=require(RS.Shared.ItemInstance)
local Inventory=require(script.Parent.InventoryService)
local S={_beacons={},_known={},_selection={},_requests={}}
local modules={"FieldClock","ThreatGauge","ResourceCompass","WeatherScanner","BiomePredictor","WeatherPredictor","EventDetector"}
local function contents(player)
 local result={};local inv=Inventory:GetAll(player)
 for _,kind in ipairs({"Hotbar","Storage"}) do for index,entry in pairs(inv[kind] or {}) do if entry then table.insert(result,{Entry=entry,Kind=kind,Index=index}) end end end
 return result
end
local function rootOf(player)
 local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 return h and h.Health>0 and not player:GetAttribute("IsDead") and not player:GetAttribute("WorldPlayerLoading") and not player:GetAttribute("WorldPlayerRestoring") and player.Character:FindFirstChild("HumanoidRootPart")
end
local function explored(position)
 local size=require(RS.Shared.BiomeConfig).chunk_size or 240
 local cells=require(script.Parent.TeamExplorationService)._cells
 return cells and cells[tostring(math.floor(position.X/size))..","..tostring(math.floor(position.Z/size))]~=nil
end
function S:GetCapabilities(player)
 local result={}
 if not player then return result end
 for _,slot in ipairs(contents(player)) do
  local entry=slot.Entry
  if Catalog.Instruments[entry.Id] then result[entry.Id]=true end
  if entry.Id=="FieldJournal" then for id,installed in pairs(entry.InstalledModules or {}) do if installed and table.find(modules,id) then result[id]=true end end end
 end
 if result.WeatherPredictor then result.BiomePredictor=true;result.WeatherScanner=true end
 if result.BiomePredictor then result.FieldClock=true end
 return result
end
function S:_knownResources(player)
 local key=tostring(player.UserId);local known=self._known[key] or {};self._known[key]=known
 for _,slot in ipairs(contents(player)) do if Catalog.Resources[slot.Entry.Id] then known[slot.Entry.Id]=true end end
 local r=rootOf(player)
 if r then
  for _,marker in ipairs(require(script.Parent.OverhaulWorldService):GetClassScanMarkers(r.Position,300,false)) do
   if marker.Kind=="Resource" and explored(marker.Position) then
    local id=marker.ResourceId
    if not id then for candidate in pairs(Catalog.Resources) do if Catalog.Items[candidate].Name==marker.Name then id=candidate;break end end end
    if id then known[id]=true end
   end
  end
 end
 return known
end
-- The journal's progression guide is public; instrument forecasts remain gated separately.
function S:GetJourney()
 local campaign=require(script.Parent.CampaignService);local state=campaign:GetState()
 local biome=require(script.Parent.BiomeService);local current=biome:GetCurrent();local definition=Biomes.Biomes[current]
 local journey={Tier=state.Tier,Milestone=state.Milestone.Name,Complete=RS:GetAttribute("CampaignComplete")==true,Maturity=biome:GetMaturity(),PreviousVisits=biome:GetPreviousVisits(),KnownDepths={},KnownRegions={}}
 local discovered={}
 for _,cell in pairs(require(script.Parent.TeamExplorationService)._cells or {}) do
  if cell.Biome==current then for _,region in ipairs(cell.Regions or {}) do discovered[region.name]=true end end
 end
 local depths={}
 for _,region in ipairs(definition.Regions) do
  if discovered[region.Name] then
   depths[region.Depth]=true;table.insert(journey.KnownRegions,{Name=region.Name,Depth=region.Depth})
  end
 end
 for depth in pairs(depths) do table.insert(journey.KnownDepths,depth) end;table.sort(journey.KnownDepths)
 local built={}
 for _,station in ipairs(Collection:GetTagged("Structure")) do
  if station:IsDescendantOf(workspace) then local id=station:GetAttribute("BuildType") or station:GetAttribute("StationType");if id then built[id]=math.max(built[id] or 0,station:GetAttribute("StationGrade") or station:GetAttribute("Grade") or 1) end end
 end
 local order={"Workbench","Campfire","Furnace","Loom","Anvil","Stove","MedicineTable","SurveyDesk","EnchantingTable","Oven","RepairBench"}
 for _,id in ipairs(order) do
  local station=Catalog.Stations[id]
  if station and station.Tier<=state.Tier and not built[id] then journey.NextStation={Id=id,Name=station.Name,Grade=station.Grade,Action="Build"};break end
 end
 if not journey.NextStation then
  for _,id in ipairs({"Workbench","Furnace","Loom","Anvil","MedicineTable","SurveyDesk","EnchantingTable"}) do
   if built[id] and built[id]<state.Tier then journey.NextStation={Id=id,Name=Catalog.Stations[id].Name,Grade=state.Tier,Action="Upgrade"};break end
  end
 end
 journey.Advice=journey.Complete and "Campaign complete. Explore deep regions, awaken equipment, and prepare for endurance expeditions." or "Prepare equipment, medical supplies, and weather protection before pushing into deeper regions."
 for _,clue in ipairs(require(RS.Shared.CampaignConfig).Clues) do
  if clue.Tier==state.Tier and not (state.Facts or {})[clue.Id] and not journey.Complete then journey.Advice=clue.Name..". Carry supplies and gear suited to this tier.";break end
 end
 if state.Ready and not journey.Complete then journey.Advice="Your crew has prepared this milestone. Return to its project site and begin the encounter when everyone is ready." end
 return journey
end
function S:GetSnapshot(player)
 local caps=self:GetCapabilities(player);local result={Journey=self:GetJourney(),Capabilities=caps,KnownResources={},Modules={},Journals={},Beacons={}}
 local r=rootOf(player);local known=self:_knownResources(player)
 for id in pairs(known) do table.insert(result.KnownResources,{Id=id,Name=Catalog.Items[id].Name}) end
 table.sort(result.KnownResources,function(a,b)return a.Name<b.Name end)
 for _,slot in ipairs(contents(player)) do
  local entry=slot.Entry
  if table.find(modules,entry.Id) then result.Modules[entry.Id]=true end
  if entry.Id=="FieldJournal" then table.insert(result.Journals,{Uid=entry.Uid,InstalledModules=Instances.Copy(entry.InstalledModules or {})}) end
 end
 if not r then return result end
 local biome=require(script.Parent.BiomeService);local world=require(script.Parent.OverhaulWorldService)
 local region=world:MetadataAt(r.Position)
 if caps.ThreatGauge then result.Threat={Tier=RS:GetAttribute("CampaignTier") or 1,Pressure=RS:GetAttribute("CampaignPressure") or 0,Depth=region and region.Depth or 1,Region=region and region.Name or "Camp"} end
 if caps.WeatherScanner then
  local stats=require(script.Parent.StatsService);local temp=player:GetAttribute("InteriorId") and 0 or require(script.Parent.ChunkStreamingService):GetRegionTempAtPosition(r.Position)
  result.Hazards={Temperature=temp or 0,Exposure=stats:GetBase(player,"Temperature") or 0,Toxin=player.Character:GetAttribute("ToxinStacks") or 0,Wet=(player.Character:GetAttribute("WetStacks") or 0)>0}
  result.Advice=(temp or 0)>0 and "Heat: drink cooling water, find roof shade, and return to camp to recover." or (temp or 0)<0 and "Cold: wear warm pieces and recover beside a campfire or stove." or "Mild temperature. Exposure recovers naturally; avoid local hazard warnings."
 end
 if caps.ResourceCompass then
  local selected=self._selection[player];result.SelectedResource=selected
  if selected and known[selected] then
   local best,distance
   for _,marker in ipairs(world:GetClassScanMarkers(r.Position,300,false)) do
    if marker.Kind=="Resource" and (marker.ResourceId==selected or marker.Name==Catalog.Items[selected].Name) and explored(marker.Position) then
     local d=(marker.Position-r.Position).Magnitude;if not distance or d<distance then best,distance=marker,d end
    end
   end
   if best then result.ResourceTarget={Id=selected,Name=best.Name,Position=best.Position,Distance=distance};result.ResourceStatus="Known nearby source"
   else
    local def=Catalog.Resources[selected];local current=biome:GetCurrent();local actualName=Biomes.Biomes[current].DisplayName
    if def.Biome~="Common" and def.Biome~=actualName and def.Biome~=current then result.ResourceStatus="Absent this visit · found in "..def.Biome
    else
     local minimum=string.byte(def.Depth or "A")-64;local unlocked=1
     for _,candidate in ipairs(Biomes.EligibleRegions(current,RS:GetAttribute("CampaignTier") or 1,biome:GetPreviousVisits())) do unlocked=math.max(unlocked,candidate.Depth) end
     result.ResourceStatus=minimum>unlocked and "Locked region depth · progress the campaign and revisit this biome" or "No discovered matching source within 300 studs"
    end
   end
  else result.ResourceStatus="Undiscovered · collect or discover a resource before tracking it" end
 end
 if caps.EventDetector then
  local event=require(script.Parent.EventService):GetActive("Major");local data=event and event.Data
  if data and data.Elapsed<(data.Warning or 0) then
   local p=Vector3.new(table.unpack(data.Position));result.Event={Id=data.InstanceId,Name=data.Name,StartsIn=math.ceil(data.Warning-data.Elapsed),Position=explored(p) and p or nil}
  end
 end
 for _,beacon in ipairs(self._beacons) do table.insert(result.Beacons,{Id=beacon.Id,Name=beacon.Name,Position=Vector3.new(table.unpack(beacon.Position)),Remaining=beacon.Remaining}) end
 return result
end
function S:_install(player,payload)
 if type(payload)~="table" or not table.find(modules,payload.Module) or type(payload.Uid)~="string" then return false,"Choose a carried instrument module." end
 local root=rootOf(player);if not root then return false,"You must be alive to install a module." end
 local nearby=false
 for _,station in ipairs(Collection:GetTagged("Structure")) do if station:GetAttribute("BuildType")=="SurveyDesk" and (station:GetAttribute("StationGrade") or 1)>=5 and (station:GetPivot().Position-root.Position).Magnitude<=12 then nearby=true;break end end
 if not nearby then return false,"Requires a nearby grade 5 Survey Desk." end
 local journal
 for _,slot in ipairs(contents(player)) do if slot.Entry.Id=="FieldJournal" and slot.Entry.Uid==payload.Uid then journal=slot.Entry;break end end
 if not journal then return false,"Carry the selected Field Journal." end
 journal.InstalledModules=journal.InstalledModules or {}
 if journal.InstalledModules[payload.Module] then return false,"That module is already installed." end
 if not Inventory:TakeCost(player,{{Id=payload.Module,N=1}},true) then return false,"Carry the actual instrument to install it." end
 journal.InstalledModules[payload.Module]=true;Inventory:Sync(player)
 require(script.Parent.GameStateService):SendToPlayer(player)
 return true,"Module installed. Its information now comes from your journal."
end
function S:_placeBeacon(player,name)
 local root=rootOf(player);if not root then return false,"A living explorer must place the beacon." end
 if not Inventory:Has(player,"TrailBeacon",1) then return false,"Carry a Trail Beacon." end
 if #self._beacons>=36 then return false,"The crew already has 36 active beacons." end
 name=type(name)=="string" and string.sub(name,1,40) or "Return point"
 local ok,filtered=pcall(function()return TextService:FilterStringAsync(name,player.UserId):GetNonChatStringForBroadcastAsync() end)
 if not ok then return false,"The marker name could not be filtered. Try again." end
 root=rootOf(player);if not root or RS:GetAttribute("WorldShifting") then return false,"Placement cancelled while the world changes." end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={player.Character}
 local ground=workspace:Raycast(root.Position,Vector3.new(0,-12,0),params)
 if not ground or ground.Normal.Y<.7 then return false,"Stand on supported ground." end
 if not Inventory:TakeCost(player,{{Id="TrailBeacon",N=1}},true) then return false,"The beacon is no longer carried." end
 local position=ground.Position
 table.insert(self._beacons,{Id=Http:GenerateGUID(false),Name=filtered,Position={position.X,position.Y,position.Z},Remaining=900,Owner=player.UserId})
 Inventory:Sync(player);return true,"Return marker placed for 15 minutes."
end
function S:_renderBeacons()
 local folder=workspace:FindFirstChild("TrailBeacons") or Instance.new("Folder");folder.Name="TrailBeacons";folder.Parent=workspace
 local alive={}
 for _,beacon in ipairs(self._beacons) do
  alive[beacon.Id]=true;local pole=folder:FindFirstChild(beacon.Id)
  if not pole then
   pole=Instance.new("Part");pole.Name=beacon.Id;pole.Size=Vector3.new(.25,4,.25);pole.Anchored=true;pole.CanCollide=false;pole.CanQuery=false;pole.Color=Color3.fromRGB(200,167,88);pole.Position=Vector3.new(table.unpack(beacon.Position))+Vector3.new(0,2,0);pole.Parent=folder
   local gui=Instance.new("BillboardGui");gui.Size=UDim2.fromOffset(180,50);gui.StudsOffset=Vector3.new(0,3,0);gui.MaxDistance=80;gui.Adornee=pole;gui.Parent=pole
   local label=Instance.new("TextLabel");label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=.2;label.BackgroundColor3=Color3.fromRGB(34,43,37);label.TextColor3=Color3.fromRGB(242,229,192);label.TextSize=16;label.TextWrapped=true;label.Text=beacon.Name;label.Parent=gui
  end
 end
 for _,pole in ipairs(folder:GetChildren()) do if not alive[pole.Name] then pole:Destroy() end end
end
function S:CaptureWorldState() return {Beacons=Instances.Copy(self._beacons),Known=Instances.Copy(self._known)} end
function S:RestoreWorldState(saved) self._beacons=Instances.Copy(saved and saved.Beacons or {});self._known=Instances.Copy(saved and saved.Known or {}) end
function S:Init()
 if self._remote then return end
 local remote=RS.Remotes:FindFirstChild("InstrumentAction") or Instance.new("RemoteEvent");remote.Name="InstrumentAction";remote.Parent=RS.Remotes;self._remote=remote
 remote.OnServerEvent:Connect(function(player,action,payload)
  if os.clock()-(self._requests[player] or 0)<.2 then return end;self._requests[player]=os.clock()
  if action=="SelectResource" and type(payload)=="string" and self:_knownResources(player)[payload] then self._selection[player]=payload
  elseif action=="InstallModule" then local ok,msg=self:_install(player,payload);remote:FireClient(player,"Feedback",{Success=ok,Message=msg})
  elseif action=="PlaceBeacon" then local ok,msg=self:_placeBeacon(player,payload);remote:FireClient(player,"Feedback",{Success=ok,Message=msg})
  elseif action~="RequestSnapshot" then return end
  remote:FireClient(player,"Snapshot",self:GetSnapshot(player))
 end)
 Players.PlayerRemoving:Connect(function(player)self._requests[player]=nil;self._selection[player]=nil end)
 task.spawn(function()while true do
  task.wait(1)
  if RS:GetAttribute("WorldRestoring") or RS:GetAttribute("WorldShifting") then continue end
  local living=false;for _,p in ipairs(Players:GetPlayers()) do if rootOf(p) then living=true;break end end
  if living then for i=#self._beacons,1,-1 do local b=self._beacons[i];b.Remaining-=1;if b.Remaining<=0 then table.remove(self._beacons,i) end end end
  self:_renderBeacons()
  for _,p in ipairs(Players:GetPlayers()) do if rootOf(p) then remote:FireClient(p,"Snapshot",self:GetSnapshot(p)) end end
 end end)
end
return S
