local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Collection=game:GetService("CollectionService")
local Http=game:GetService("HttpService")
local Catalog=require(RS.Shared.OverhaulCatalog)
local Inventory=require(script.Parent.InventoryService)
local Gear=require(script.Parent.GearService)
local Instances=require(RS.Shared.ItemInstance)
local Service={_known={},_choices={},_sources={},_seen={},_rate={},_choiceRanks={}}
local function creative(player)
 return workspace:GetAttribute("WorldType")=="Creative" and player:GetAttribute("CreativeMode")==true
end
local function live(player)
 local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 return hum and hum.Health>0 and not player:GetAttribute("IsDead") and not player:GetAttribute("WorldPlayerLoading")
  and not player:GetAttribute("WorldPlayerRestoring") and not RS:GetAttribute("WorldRestoring") and not require(script.Parent.GameStateService):IsGameOver()
end
local function stationOK(player,station,grade)
 if typeof(station)~="Instance" or not station:IsDescendantOf(workspace) or not Collection:HasTag(station,"Structure")
  or station:GetAttribute("BuildType")~="EnchantingTable" then return false end
 return require(script.Parent.StationService):Validate(player,station,grade)
end
local function level(entry,id)
 local value=entry.Enchantments and entry.Enchantments[id]
 return tonumber(type(value)=="table" and (value.Level or value.Rank) or value) or 0
end
function Service:GetState(player,station)
 local gear,pages,scrolls={},{},{}
 local known=Instances.Copy(self._known)
 local isCreative=creative(player)
 if isCreative then
  known={}
  for id,enchantment in pairs(Catalog.Enchantments) do
   known[id]={}
   for rank in ipairs(enchantment.Grades) do known[id][tostring(rank)]=true end
  end
 end
 local inv=Inventory:GetAll(player)
 for _,kind in ipairs({"Hotbar","Storage","Equipment","Accessory"}) do
  for _,entry in pairs(inv[kind] or {}) do
   if entry then
    local definition=Catalog.Items[entry.Id]
    if Catalog.Gear[entry.Id] then table.insert(gear,Instances.Copy(entry))
    elseif definition and definition.Schematic then table.insert(pages,entry.Id)
    elseif definition and definition.Scroll then table.insert(scrolls,entry.Id) end
   end
  end
 end
 table.sort(gear,function(a,b)return a.Id==b.Id and a.Uid<b.Uid or a.Id<b.Id end)
 return {Station=station,Known=known,Choices=isCreative and {} or Instances.Copy(self._choices),ChoiceRanks=Instances.Copy(self._choiceRanks),Gear=gear,
  Pages=isCreative and {} or pages,Scrolls=isCreative and {} or scrolls,Creative=isCreative,Tier=require(script.Parent.CampaignService):GetTier()}
end
function Service:Discover(id,rank)
 local e=Catalog.Enchantments[id]
 if not e or e.Hidden or not e.Grades[rank] then return false end
 self._known[id]=self._known[id] or {}
 if self._known[id][tostring(rank)] then return false end
 self._known[id][tostring(rank)]=true
 return true
end
function Service:GrantChoice(source,options,rank)
 if self._sources[source] then return false end
 for _,id in ipairs(options) do assert(Catalog.Enchantments[id],"Unknown schematic choice") end
 self._sources[source]=true;self._choices[source]=table.clone(options);self._choiceRanks[source]=rank or 1
 if source=="FirstForge" then
  -- Tier-3 introduction cannot depend on the tier-4 Crystal Basin C dust node.
  local camp=workspace:GetAttribute("CampCenter") or Vector3.zero
  require(script.Parent.ItemDropService):SpawnDrop("DarkDust",4,camp+Vector3.new(0,4,0))
 end
 return true
end
local function compatible(entry,id,rank,allowExisting,isCreative)
 local def=Instances.Copy(Catalog.Gear[entry.Id]);if not def then return false,"Choose gear." end
 def.Grade=entry.Grade
 if not Catalog.Enchantments[id].Grades[rank] then return false,"That enchantment rank is unavailable." end
 if not Catalog.CanUseEnchantment(def,id) then return false,"That enchantment cannot be used on this item." end
 if not isCreative and not Catalog.CanEnchant(def,id,rank) then return false,"This enchantment requires a higher gear grade." end
 local current=level(entry,id)
 if current>0 and not allowExisting then return false,"This item already has that enchantment." end
 local count=0;for _ in pairs(entry.Enchantments or {}) do count+=1 end
 if not isCreative and current==0 and count>=Catalog.EnchantmentSlots(def.Kind,entry.Grade) then return false,"No free enchantment slot." end
 local requested=Catalog.Enchantments[id]
 local groups=table.clone(requested.ConflictGroups or {})
 if requested.Family and requested.Family~="" then table.insert(groups,requested.Family) end
 if not isCreative and #groups>0 then
  for other in pairs(entry.Enchantments or {}) do
   local otherDef=other~=id and Catalog.Enchantments[other]
   if otherDef then
    local otherGroups=table.clone(otherDef.ConflictGroups or {})
    if otherDef.Family and otherDef.Family~="" then table.insert(otherGroups,otherDef.Family) end
    for _,group in ipairs(groups) do
     if table.find(otherGroups,group) then return false,"Conflicts with "..otherDef.Name.."." end
    end
   end
  end
 end
 return true
end
local function costs(entry,id,rank,transfer)
 local e=Catalog.Enchantments[id];local required=e.Grades[rank];local budget=Catalog.EnchantingCosts[required]
 local list={}
 if not transfer then table.insert(list,{Id="EnchantingDust",N=budget.Dust}) end
 table.insert(list,{Id=Catalog.GetMaterial(entry.Grade),N=transfer and math.ceil(budget.Material/2) or budget.Material})
 local theme=e.Theme
 if id=="OpenSeam" and rank>=2 then theme="DeepResin" end
 table.insert(list,{Id=theme,N=transfer and math.ceil(budget.Theme/2) or budget.Theme})
 if not transfer and rank==e.MaxLevel and e.Trophy and e.Trophy~="" then
  if e.Trophy=="AnyTrophy" then
   local picked
   for _,trophy in ipairs(Catalog.Trophies) do if Inventory:Has(entry._owner,trophy,1) then picked=trophy;break end end
   if not picked then return nil end
   table.insert(list,{Id=picked,N=1})
  else table.insert(list,{Id=e.Trophy,N=1}) end
 end
 return list
end
function Service:Request(player,action,payload)
 if type(action)~="string" or type(payload)~="table" or not live(player) then return false,"Unavailable." end
 local station=payload.Station
 if not stationOK(player,station,3) then return false,"Move near an Enchanting Table." end
 if action=="Open" then return true end
 if action=="Choose" then
  local options=type(payload.Source)=="string" and self._choices[payload.Source]
  if not options or not table.find(options,payload.Enchantment) then return false,"Choice already claimed or unavailable." end
  local rank=self._choiceRanks[payload.Source] or 1
  if rank=="Maximum" then rank=Catalog.Enchantments[payload.Enchantment].MaxLevel end
  self:Discover(payload.Enchantment,rank);self._choices[payload.Source]=nil;self._choiceRanks[payload.Source]=nil;return true,"Schematic learned by the whole crew."
 elseif action=="Read" then
  local item=type(payload.ItemId)=="string" and Catalog.Items[payload.ItemId]
  if not item or not item.Schematic then return false,"Choose a schematic page." end
  if not Inventory:Consume(player,payload.ItemId,1,true) then return false,"Page is no longer in your pack." end
  local learned=self:Discover(item.Schematic.Id,item.Schematic.Rank)
  if not learned then
   local n=Inventory:Give(player,"EnchantingDust",4,false,true)
   if n<4 then require(script.Parent.ItemDropService):SpawnDrop("EnchantingDust",4-n,station:GetPivot().Position+Vector3.new(0,3,0)) end
  end
  Inventory:Sync(player);return true,learned and "Schematic learned for the crew." or "Duplicate page converted to 4 Enchanting Dust."
 end
 local entry=Gear:GetItemByUid(player,payload.Uid)
 local id=payload.Enchantment;local enchant=type(id)=="string" and Catalog.Enchantments[id]
 local isCreative=creative(player)
 if not entry or not enchant then return false,"Select gear and an enchantment." end
 if action=="Remove" then
  if level(entry,id)==0 then return false,"That enchantment is not on this item." end
  entry.Enchantments[id]=nil;Gear:Touch(player);return true,"Enchantment removed."
 elseif action=="Extract" then
  local rank=level(entry,id);if rank==0 then return false,"That enchantment is not on this item." end
  local output=id.."Scroll"..rank;local budget=Catalog.EnchantingCosts[enchant.Grades[rank]]
  local cost={{Id="EnchantingDust",N=math.ceil(budget.Dust/2)},{Id="Glass",N=1}}
  if not stationOK(player,station,enchant.Grades[rank]) then return false,"Upgrade this station first." end
  if not Inventory:CanFit(player,output,1) then return false,"Make room for the scroll first." end
  if not Inventory:CanAfford(player,cost) then return false,"Need half the dust cost, rounded up, and 1 Glass." end
  local scroll={Id=output,N=1,Uid=Http:GenerateGUID(false),Scroll={Id=id,Rank=rank}}
  if Inventory:GiveEntry(player,scroll,true,true)~=1 then return false,"Make room for the scroll." end
  assert(Inventory:PayCost(player,cost,true),"Validated extraction debit changed")
  entry.Enchantments[id]=nil;Gear:Touch(player);return true,"Extracted a shareable scroll. Stored effect charges are not transferred."
 elseif action=="ApplyScroll" or action=="Enchant" then
  local scroll=action=="ApplyScroll" and type(payload.ItemId)=="string" and Catalog.Items[payload.ItemId]
  local rank=isCreative and action=="Enchant" and enchant.MaxLevel or (scroll and scroll.Scroll and scroll.Scroll.Id==id and scroll.Scroll.Rank or level(entry,id)+1)
  if action=="ApplyScroll" and (not scroll or not scroll.Scroll or scroll.Scroll.Id~=id) then return false,"Choose a matching scroll." end
  local ok,reason=compatible(entry,id,rank,action=="Enchant",isCreative)
  if not ok then return false,reason end
  if not isCreative then
   if not stationOK(player,station,enchant.Grades[rank]) then return false,"Upgrade this station first." end
   if require(script.Parent.CampaignService):GetTier()<enchant.Grades[rank] then return false,"Campaign tier is too low." end
   if action=="Enchant" and not (self._known[id] and self._known[id][tostring(rank)]) then return false,"Discover this rank's schematic first." end
   -- Costs use the item's actual grade. Never trust preview numbers supplied by a client.
   local copy=Instances.Copy(entry);copy._owner=player
   local cost=costs(copy,id,rank,action=="ApplyScroll")
   if not cost then return false,"A deep-region trophy is required." end
   if scroll then table.insert(cost,{Id=payload.ItemId,N=1}) end
   if not Inventory:PayCost(player,cost,true) then return false,"Missing materials." end
  end
  entry.Enchantments=entry.Enchantments or {};entry.Enchantments[id]=rank
  Gear:Touch(player)
  if not isCreative then require(script.Parent.ExpeditionRewardsService):RecordActivity(player) end
  return true,isCreative and "Maximum-rank enchantment applied for free." or (action=="Enchant" and "Enchantment applied." or "Scroll transferred.")
 end
 return false,"Unknown action."
end
function Service:CaptureWorldState() return {Version=1,Known=Instances.Copy(self._known),Choices=Instances.Copy(self._choices),Sources=Instances.Copy(self._sources),ChoiceRanks=Instances.Copy(self._choiceRanks)} end
function Service:RestoreWorldState(state)
 self._known={};self._choices={};self._sources={};self._choiceRanks={}
 if not state then return end
 assert(type(state)=="table" and state.Version==1 and type(state.Known)=="table" and type(state.Choices)=="table" and type(state.Sources)=="table","Invalid enchantment discovery state")
 for id,ranks in pairs(state.Known) do
  assert(Catalog.Enchantments[id] and type(ranks)=="table","Unknown saved enchantment")
  for rank,value in pairs(ranks) do assert(value==true and Catalog.Enchantments[id].Grades[tonumber(rank)],"Unknown saved enchantment rank") end
 end
 self._known=Instances.Copy(state.Known);self._choices=Instances.Copy(state.Choices);self._sources=Instances.Copy(state.Sources);self._choiceRanks=Instances.Copy(state.ChoiceRanks or {})
end
function Service:Init()
 if self._initialized then return end;self._initialized=true
 self._remote=Instance.new("RemoteEvent");self._remote.Name="Enchanting";self._remote.Parent=RS.Remotes
 self._remote.OnServerEvent:Connect(function(player,action,payload)
  if type(payload)~="table" then return end
  if os.clock()-(self._rate[player] or -math.huge)<.2 then return end;self._rate[player]=os.clock()
  if action~="Open" then
   if type(payload.RequestId)~="string" or #payload.RequestId>80 then return end
   local seen=self._seen[player] or {Order={}};self._seen[player]=seen
   if seen[payload.RequestId] then self._remote:FireClient(player,"Result",false,"Action already handled.");return end
   seen[payload.RequestId]=true;table.insert(seen.Order,payload.RequestId)
   if #seen.Order>256 then seen[table.remove(seen.Order,1)]=nil end
  end
  local ok,reason=self:Request(player,action,payload)
  self._remote:FireClient(player,"Result",ok,reason)
  if stationOK(player,payload.Station,3) then self._remote:FireClient(player,action=="Open" and "Open" or "State",self:GetState(player,payload.Station)) end
 end)
 Players.PlayerRemoving:Connect(function(player) self._seen[player]=nil;self._rate[player]=nil end)
end
return Service
