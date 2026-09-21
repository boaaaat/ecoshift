-- Run in Studio Server/Edit through execute_luau or Command Bar after source sync.
-- Optional module table allows the same checks against freshly compiled source.
-- Creates unparented models only; never changes the active world or player inventory.
local overrides=... or {}
local shared=game.ReplicatedStorage.Shared
local Biomes=overrides.Biomes or require(shared.OverhaulBiomes)
local Catalog=require(shared.OverhaulCatalog)
local Items=require(shared.Items.ItemDatabase)
local Environment=overrides.Environment or require(game.ServerScriptService.Art.ExpeditionEnvironment)
local Armor=overrides.Armor or require(game.ServerScriptService.Art.ExpeditionArmor)
local failures,unique,regions,pairsChecked,plans,armorCount={}, {},0,0,0,0
local function check(condition,message) if not condition then table.insert(failures,message) end end
local function bounds(model)
 local low,high=math.huge,-math.huge
 for _,p in ipairs(model:GetDescendants()) do
  if p:IsA("BasePart") and p.Transparency<1 then
   for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
    local point=p.CFrame:PointToWorldSpace(p.Size*Vector3.new(x,y,z)*.5)
    low,high=math.min(low,point.Y),math.max(high,point.Y)
   end end end
  end
 end
 return low,high
end
for _,biomeId in ipairs(Biomes.Order) do
 local biome=Biomes.Biomes[biomeId]
 local resources={}
 for _,region in ipairs(biome.Regions) do
  regions+=1
  for _,id in ipairs(region.Resources) do resources[id]=true;unique[id]=true end
 end
 resources.Stone=true
 for id in pairs(resources) do
  pairsChecked+=1
  check(Items:Get(id)~=nil,biomeId.." missing item "..id)
  check(Catalog.ResourceDefinitions[id]~=nil,biomeId.." missing resource profile "..id)
  local ok,err=pcall(function()
   local model=Environment.CreateResource(id,biomeId,{Pine=biome.Landform=="Alpine",Snow=biomeId=="FrozenTundra"})
   local low,high=bounds(model)
   check(model.PrimaryPart~=nil,id.." has no pivot")
   check(low>-1.25 and high>.3,id.." invalid ground/visibility bounds "..low..","..high)
   local delta=Vector3.new(121,39,-83)
   model:PivotTo(CFrame.new(delta)*model:GetPivot())
   local movedLow,movedHigh=bounds(model)
   check(math.abs(movedLow-low-delta.Y)<.002 and math.abs(movedHigh-high-delta.Y)<.002,id.." pivot changes grounded geometry")
   if id=="Resin" or id=="DeepResin" then
    local sap=model:FindFirstChild("AmberSapRun")
    check(sap~=nil and sap.Position.Y-delta.Y>2,id.." sap hidden in ground cover")
    if sap then
     local offset=sap.Position-delta
     check(Vector2.new(offset.X,offset.Z).Magnitude>1.1 and sap.Size.Z>=.3,id.." sap buried in bark")
     local shape=sap:FindFirstChildOfClass("SpecialMesh")
     check(shape and shape.MeshType==Enum.MeshType.Sphere,id.." sap does not render as an elongated mesh")
    end
   end
   if id:find("Ore") then
    local veins=0
    for _,p in ipairs(model:GetChildren()) do
     if p.Name=="ExposedMineral" then
     veins+=1;local localPos=p.Position-delta
      check(Vector2.new(localPos.X,localPos.Z).Magnitude>1.75,id.." mineral embedded inside host")
      local shape=p:FindFirstChildOfClass("SpecialMesh")
      check(shape and shape.MeshType==Enum.MeshType.Sphere,id.." mineral seam is a flat slab")
     end
    end
    check(veins==4,id.." missing readable ore faces")
   end
   model:Destroy()
  end)
  check(ok,biomeId.."/"..id..": "..tostring(err))
 end
 for tier=1,8 do for visits=0,4 do for seed=1,100 do
  local eligible=Biomes.EligibleRegions(biomeId,tier,visits)
  local count=6+seed%4
  local plan=Biomes.PlanRegionTypes(biomeId,tier,visits,count,Random.new(seed))
  local found,allowed={},{}
  for _,region in ipairs(eligible) do allowed[region.Id]=true end
  check(#plan==count,biomeId.." unexpected region count")
  for _,region in ipairs(plan) do found[region.Id]=true;check(allowed[region.Id],biomeId.." exposed locked region") end
  for _,region in ipairs(eligible) do check(found[region.Id],biomeId.." dropped eligible region "..region.Id) end
  plans+=1
 end end end
end
for id,definition in pairs(Catalog.Gear) do
 if definition.Kind=="Armor" then
  armorCount+=1
  local ok,err=pcall(function()
   local display=Armor.CreateDisplay(id,definition)
   check(display and display.PrimaryPart,id.." missing pickup art")
   if display then
    local low,high=bounds(display)
    check(math.abs(low)<.01 and high>.1,id.." pickup not grounded")
    for _,object in ipairs(display:GetDescendants()) do
     if object:IsA("WeldConstraint") then check(object.Part0:IsDescendantOf(display) and object.Part1:IsDescendantOf(display),id.." retains temporary mannequin weld") end
    end
    display:Destroy()
   end
  end)
  check(ok,id..": "..tostring(err))
 end
end
local ids={};for id in pairs(unique) do table.insert(ids,id) end;table.sort(ids)
local report={biomes=#Biomes.Order,regions=regions,resourceIds=#ids,resourceModels=pairsChecked,regionPlans=plans,armorPickups=armorCount,failures=failures,ids=ids}
print(game:GetService("HttpService"):JSONEncode(report))
assert(#failures==0,"Resource/art coverage failed: "..table.concat(failures,"; "))
return report
