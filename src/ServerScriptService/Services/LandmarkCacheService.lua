-- Landmark cache ownership is independent of streamed physical models.
local RS=game:GetService("ReplicatedStorage")
local Collection=game:GetService("CollectionService")
local Loot=require(script.Parent.LootService)
local Config=require(RS.Shared.ExpeditionLootConfig)
local Art=require(RS.Shared.Art.OverhaulBuildModels)
local Codec=require(script.Parent.WorldSnapshotCodec)
local Service={_serial=nil,_records={},_live={}}
function Service:_visit()
 local serial=require(script.Parent.BiomeService):GetVisitSerial()
 if self._serial~=serial then self._serial=serial;self._records={};self._live={} end
 return serial
end
function Service:Bind(landmark,metadata)
 if not landmark.Parent then return end
 local serial=self:_visit()
 local key=tostring(serial)..":"..metadata.RegionId
 if self._live[key] and self._live[key].Parent then return end
 local record=self._records[key]
 if not record then
  local tier=RS:GetAttribute("CampaignTier") or 1
  local drops=Config.RollCache(metadata.Biome,metadata.Depth,tier,Random.new())
  local slots={};for i=1,24 do slots[i]=false end
  for i,entry in ipairs(drops) do slots[i]=entry end
  record={Tier=2,Table="LandmarkCache",SlotCount=24,Slots=slots}
  -- Commit rolls before exposing any prompt. Reloading cannot reroll an unopened chest.
  self._records[key]=record
 end
 local chest=Art.Create("Chest");chest.Name="Field cache"
 chest:SetAttribute("WorldObjectKey",key);chest:SetAttribute("LandmarkCache",true)
 chest:SetAttribute("SlotCount",24);chest:SetAttribute("ChestTier",2)
 chest:SetAttribute("BiomeId",metadata.Biome);chest:SetAttribute("RegionDepth",metadata.Depth)
 chest:SetAttribute("MapLabel","Field cache")
 chest:PivotTo(CFrame.new(metadata.Position+Vector3.new(4,2,-4)))
 -- This listener precedes LootService's cleanup listener attached by the chest tag.
 chest.Destroying:Connect(function()
  if self._serial==serial and self._live[key]==chest then
   self._records[key]=Loot:CaptureChestState(chest);self._live[key]=nil
  end
 end)
 Loot:RestoreChestState(chest,Codec.Copy(record))
 chest.Parent=landmark;self._live[key]=chest
 Collection:AddTag(chest,"Rare_Chest")
end
function Service:CaptureWorldState()
 for key,chest in pairs(self._live) do if chest.Parent then self._records[key]=Loot:CaptureChestState(chest) end end
 return {Version=1,Serial=self._serial,Records=Codec.Copy(self._records)}
end
function Service:RestoreWorldState(raw)
 self._serial=nil;self._records={};self._live={}
 if not raw then return end
 assert(type(raw)=="table" and raw.Version==1 and type(raw.Records)=="table","Invalid landmark cache ledger")
 Codec.BoundedCount(raw.Records,100)
 for key,state in pairs(raw.Records) do
  assert(type(key)=="string" and type(state)=="table" and state.SlotCount==24 and type(state.Slots)=="table" and #state.Slots==24,"Invalid landmark cache")
 end
 self._serial=raw.Serial;self._records=Codec.Copy(raw.Records)
end
function Service:Init()
 if self._initialized then return end;self._initialized=true
 _G.Ecoshift=_G.Ecoshift or {}
 local previous=_G.Ecoshift.OnOverhaulLandmark
 _G.Ecoshift.OnOverhaulLandmark=function(landmark,metadata)
  if previous then previous(landmark,metadata) end
  self:Bind(landmark,metadata)
 end
end
return Service
