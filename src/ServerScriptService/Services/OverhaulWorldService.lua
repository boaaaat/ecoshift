-- Deterministic, streamed version-2 geography. Surface-only ownership protects interiors.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local Collection = game:GetService("CollectionService")
local Biomes = require(RS.Shared.OverhaulBiomes)
local Rules = require(RS.Shared.GameRules)
local Codec = require(script.Parent.WorldSnapshotCodec)
local Service = {_seed=require(RS.Shared.BiomeConfig).seed,_serial=-1,_chunks={},_loading={},_terrain={},_terrainFootprints={},_records={},_regions={},_landmarks={},_nodes={},_generation=0}
local CELL, CHUNK, RADIUS, CAMP = 12,240,1500,200
local CAMP_HEIGHT, CAMP_BLEND = 12, 104
local function hash(text,seed)
 local n=seed or 5381
 for i=1,#text do n=(n*33+string.byte(text,i))%2147483647 end
 return n
end
local function folder(parent,name)
 local f=parent:FindFirstChild(name)
 if not f then f=Instance.new("Folder");f.Name=name;f.Parent=parent end
 return f
end
local function part(parent,name,size,cf,color,material)
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color
 p.Material=material or Enum.Material.SmoothPlastic;p.Anchored=true;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent
 return p
end
local function makeTree(model,height,color,rng,style)
 style=style or {};local pine=style.Pine==true
 local trunkColor=style.Ironwood and Color3.fromRGB(79,64,59) or style.Heartwood and Color3.fromRGB(111,69,50) or Color3.fromRGB(111,84,57)
 if style.Birch then trunkColor=Color3.fromRGB(225,222,202) end
 local trunkHeight=height*(pine and .78 or .7)
 local trunkWidth=math.clamp(height*.11,1.25,2.25)
 local trunk=part(model,"Trunk",Vector3.new(trunkWidth,trunkHeight,trunkWidth),CFrame.new(0,trunkHeight*.5,0),trunkColor,Enum.Material.Wood)
 model.PrimaryPart=trunk
 local leafColor=color:Lerp(style.Heartwood and Color3.fromRGB(119,83,54) or Color3.fromRGB(65,128,68),.42)
 local clusters
 if pine then
  clusters={
   {Vector3.new(0,height*.54,0),Vector3.new(height*.52,height*.27,height*.52)},
   {Vector3.new(0,height*.7,0),Vector3.new(height*.4,height*.25,height*.4)},
   {Vector3.new(0,height*.84,0),Vector3.new(height*.27,height*.22,height*.27)},
  }
 else
  local lean=rng:NextNumber(-1,1)*height*.035
  clusters={
   {Vector3.new(-height*.15,height*.7,lean),Vector3.new(height*.4,height*.3,height*.4)},
   {Vector3.new(height*.15,height*.72,-lean),Vector3.new(height*.4,height*.31,height*.4)},
   {Vector3.new(0,height*.86,0),Vector3.new(height*.43,height*.3,height*.43)},
  }
 end
 for index,cluster in ipairs(clusters) do
  local leaves=part(model,"Leaves",cluster[2],CFrame.new(cluster[1]),leafColor:Lerp(Color3.new(1,1,1),(index-2)*.045),Enum.Material.LeafyGrass)
  leaves.Shape=Enum.PartType.Ball;leaves.CanCollide=false;leaves.CanTouch=false;leaves.CastShadow=false
 end
 return trunk
end
local function smooth(n) n=math.clamp(n,0,1);return n*n*(3-2*n) end
function Service:GetRegions() return self._regions end
function Service:GetLandmarks() return self._landmarks end
function Service:GetSeed() return self._visitSeed or self._seed end
function Service:MetadataAt(position)
 local best,score
 for _,r in ipairs(self._regions) do
  local d=(Vector2.new(position.X,position.Z)-Vector2.new(r.Center.X,r.Center.Z)).Magnitude
  if not score or d<score then best,score=r,d end
 end
 return best
end
function Service:_baseHeight(x,z)
 local b=Biomes.Biomes[self._biome]; if not b then return 0 end
 local seed=self._visitSeed*.00001
 local n=math.noise(x*.0017,z*.0017,seed)
 local detail=math.noise(x*.008,z*.008,seed+9)
 local ridge=1-math.abs(math.noise(x*.0028,z*.0028,seed+4))*2
 local f=b.Landform;local h=24+n*90+detail*8
 if f=="Dunes" then h=18+math.sin(x*.009+math.noise(x*.001,z*.001,seed)*5)*24+n*40
 elseif f=="Wetland" then h=-7+n*22+detail*3
 elseif f=="Alpine" or f=="Highlands" then h=15+ridge*120+n*60
 elseif f=="Canyon" or f=="Crystal" then h=math.floor((n*100+50)/20)*20+detail*4
 elseif f=="Crater" or f=="Moon" or f=="Volcanic" then
  local r=math.sqrt((x-520*math.sin(seed))^2+(z-520*math.cos(seed))^2)
  h=30+n*40+60*math.exp(-((r-450)/110)^2)-70*math.exp(-(r/320)^2)
 elseif f=="Coast" then h=x*.065+n*40-18
 elseif f=="Ruins" then h=math.floor((n*55)/12)*12-6
 elseif f=="Cavern" then h=-30+n*55+detail*3
 elseif f=="Canopy" then h=30+n*100+detail*8
 elseif f=="Mushroom" then h=8+n*65+detail*5 end
 -- Broad spokes are connected walking approaches, even through steep formations.
 local angle=math.atan2(z,x);local road=math.abs(math.sin(angle*4+self._roadAngle))*math.sqrt(x*x+z*z)
 local routeHeight=math.clamp(n*35,-18,55)
 h=routeHeight+(h-routeHeight)*smooth((road-12)/45)
 return math.clamp(h,-120,240)
end
local riverBiomes={Forest=true,Swamp=true,FrozenTundra=true,AuroraVale=true,CanopySea=true,StormspireHighlands=true,MyceliumHollow=true,SunkenArchive=true}
function Service:_riverLine(z)
 local seed=(self._visitSeed or self._seed)*.00001
 return (math.sin(seed)>0 and 1 or -1)*(420+math.sin(z*.002+seed)*115)
end
function Service:_flow(x,z)
 if not riverBiomes[self._biome] or x*x+z*z<270^2 then return nil end
 local distance=math.abs(x-self:_riverLine(z))
 -- Keep the surface below the ordinary land band and let the channel carve
 -- down to it. The stepped grade creates occasional small drops downstream.
 local level=4-z*.01-math.floor((z+1440)/480)*4
 return level,distance
end
function Service:_pool(x,z)
 local r=self:MetadataAt(Vector3.new(x,0,z))
 if r and (r.Name:find("Pool") or r.Name:find("Lake") or r.Name:find("Spring")) then
  return self:_baseHeight(r.Center.X,r.Center.Z)-14,Vector2.new(x-r.Center.X,z-r.Center.Z).Magnitude,r
 end
 return nil
end
function Service:GetTemperatureAt(position)
 local r=self:MetadataAt(position);if not r then return 0 end
 local temperature=Biomes.Biomes[r.Biome].Temp
 if r.Name=="Hot Spring Valley" then
  local _,distance=self:_pool(position.X,position.Z)
  temperature=distance and distance<100 and 12 or -20
 elseif r.Name:find("Lava") or r.Name:find("Furnace") or r.Name=="Glass Dunes" then temperature=32
 elseif r.Name:find("Glacier") or r.Name:find("Ice Cave") then temperature=-30 end
 return temperature
end
function Service:_rawHeight(x,z)
 local h=self:_baseHeight(x,z)
 local r=self:MetadataAt(Vector3.new(x,0,z))
 if r then
  local dx,dz=x-r.Center.X,z-r.Center.Z
  local distance=math.sqrt(dx*dx+dz*dz)
  local blend=1-smooth(distance/510)
  local name=r.Name
  if name:find("Canyon") or name:find("Chasm") or name:find("Fault") then
   local channel=math.abs(math.sin(dz*.012+(self._visitSeed or 1)*.00001)*55-dx)
   h+=blend*(channel<35 and -42 or 35)
  elseif name:find("Ridge") or name:find("Peak") or name:find("Spire") then h+=blend*math.max(0,65-math.abs(dx)*.22)
  elseif name:find("Basin") or name:find("Crater") or name:find("Well") then h-=blend*35
  elseif name:find("Flats") or name:find("Meadow") or name:find("Courtyard") then h=h*(1-blend*.65)+self:_baseHeight(r.Center.X,r.Center.Z)*blend*.65
  elseif name:find("Canopy") or name:find("Gardens") then h+=blend*(r.Depth-1)*12 end
 end
 local pool,poolDistance=self:_pool(x,z)
 if pool and poolDistance<140 then h=(pool-6)+(h-(pool-6))*smooth((poolDistance-76)/64) end
 local water,distance=self:_flow(x,z)
 if water then
  if distance<34 then
   -- A submerged, curved bed instead of terrain ending at the water surface.
   local t=distance/34
   h=water-9+7*t*t
  elseif distance<44 then
   -- Short visible bank rising from the waterline.
   h=(water-2)+6*smooth((distance-34)/10)
  elseif distance<82 then
   -- Blend the raised bank back into the surrounding generated terrain.
   local t=smooth((distance-44)/38)
   h=(water+4)+(h-(water+4))*t
  end
 end
 -- River crossings retain a broad, gently graded dry route.
 local radius=math.sqrt(x*x+z*z);local road=math.abs(math.sin(math.atan2(z,x)*4+self._roadAngle))*radius
 if road<57 then local approach=self:_baseHeight(x,z);h=approach+(h-approach)*smooth((road-12)/45) end
 if road<22 and water and distance<60 then h=math.max(h,water+3) end
 return math.clamp(h,-120,240)
end
function Service:GetMapLayer(position)
 if Vector2.new(position.X,position.Z).Magnitude<=CAMP then return "Surface" end
 local region=self:MetadataAt(position)
 return (self._biome=="UmbralDepths" or (region and (region.Name:find("Cave") or region.Name:find("Tunnel")))) and "Cave" or "Surface"
end
function Service:GetHeight(x,z)
 local r=math.sqrt(x*x+z*z)
 if r<=CAMP then return CAMP_HEIGHT end
 local raw=self:_rawHeight(x,z)
 local h=CAMP_HEIGHT+(raw-CAMP_HEIGHT)*smooth((r-CAMP)/CAMP_BLEND)
 for _,landmark in ipairs(self._landmarks) do
  local distance=Vector2.new(x-landmark.Position.X,z-landmark.Position.Z).Magnitude
  local radius=landmark.FoundationRadius or 40
  if distance<radius then h=landmark.Position.Y+(h-landmark.Position.Y)*smooth((distance-(radius-14))/14) end
 end
 return h
end
function Service:GetWaterLevel(x,z)
 if x*x+z*z<240^2 then return nil end
 local b=Biomes.Biomes[self._biome];if not b then return nil end
 for _,landmark in ipairs(self._landmarks) do if Vector2.new(x-landmark.Position.X,z-landmark.Position.Z).Magnitude<(landmark.FoundationRadius or 40) then return nil end end
 local river,distance=self:_flow(x,z)
	if river and distance<34 then
	 local road=math.abs(math.sin(math.atan2(z,x)*4+self._roadAngle))*math.sqrt(x*x+z*z)
	 if road>=24 then return river end
 end
 local pool,poolDistance=self:_pool(x,z)
 if pool and poolDistance<80 then return pool end
 local f=b.Landform
 if f=="Coast" then return -4 end
 if f=="Wetland" or f=="Ruins" then return -8 end
 local r=self:MetadataAt(Vector3.new(x,0,z))
 if r and (r.Name:find("Lake") or r.Name:find("Pool") or r.Name:find("Spring")) then return -12 end
 return nil
end
function Service:IsSafe(position,footprint)
 if Vector2.new(position.X,position.Z).Magnitude>RADIUS-24 then return false end
 local y=self:GetHeight(position.X,position.Z);local water=self:GetWaterLevel(position.X,position.Z)
 if water and y<water+.5 then return false end
 local span=footprint or 6;local low,high=y,y
 for _,p in ipairs({Vector2.new(span,span),Vector2.new(-span,span),Vector2.new(span,-span),Vector2.new(-span,-span)}) do
  local h=self:GetHeight(position.X+p.X,position.Z+p.Y);low=math.min(low,h);high=math.max(high,h)
 end
 return high-low<math.max(2,span*.8)
end
function Service:SafePosition(position,terrainOnly)
 for ring=0,terrainOnly and 28 or 12 do
  local count=ring==0 and 1 or 16
  for i=1,count do
   local a=i/count*math.pi*2;local p=position+Vector3.new(math.cos(a)*ring*12,0,math.sin(a)*ring*12)
   if self:IsSafe(p) and (not terrainOnly or Vector2.new(p.X,p.Z).Magnitude>=270) then
    local y=self:GetHeight(p.X,p.Z)
    if terrainOnly then return Vector3.new(p.X,y+5,p.Z) end
    local params=OverlapParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={}
    local occupied=false
    for _,hit in ipairs(workspace:GetPartBoundsInBox(CFrame.new(p.X,y+4,p.Z),Vector3.new(5,7,5),params)) do
     if hit.CanCollide and not hit:IsDescendantOf(workspace.Terrain) then occupied=true;break end
    end
    if not occupied then return Vector3.new(p.X,y+5,p.Z) end
   end
  end
 end
 return terrainOnly and Vector3.new(position.X,self:GetHeight(position.X,position.Z)+5,position.Z) or Vector3.new(math.random(-30,30),CAMP_HEIGHT+5,math.random(-30,30))
end
local function bounds(instance)
 if instance:IsA("Model") then return instance:GetBoundingBox() end
 return instance.CFrame,instance.Size
end
local function arrivalExclusions()
 local result={}
 for _,player in ipairs(Players:GetPlayers()) do if player.Character then table.insert(result,player.Character) end end
 for _,name in ipairs({"GeneratedWorld","Enemies","ClassDeployments"}) do local item=workspace:FindFirstChild(name);if item then table.insert(result,item) end end
 return result
end
local function clearArrival(position,floorPart,excluded,reserved)
 for _,used in ipairs(reserved) do if (Vector2.new(position.X,position.Z)-Vector2.new(used.X,used.Z)).Magnitude<7 then return false end end
 local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Exclude;overlap.FilterDescendantsInstances=excluded
 for _,hit in ipairs(workspace:GetPartBoundsInBox(CFrame.new(position+Vector3.new(0,.25,0)),Vector3.new(4.5,6,4.5),overlap)) do
  if hit.CanCollide and hit~=floorPart and not hit:IsA("SpawnLocation") then return false end
 end
 return true
end
function Service:GetCampArrivalPositions(count,ignoreInstances)
 count=math.max(0,math.floor(tonumber(count) or 0));local result={};if count==0 then return result end
 local excluded=arrivalExclusions();for _,instance in ipairs(ignoreInstances or {}) do if typeof(instance)=="Instance" then table.insert(excluded,instance) end end;local candidates={}
 -- A roof gives us an authored interior. Cast from its underside to find the
 -- highest floor below it, then verify full character clearance around that spot.
 for _,roof in ipairs(Collection:GetTagged("Structure")) do
  if roof:IsDescendantOf(workspace) and roof:GetAttribute("BuildType")=="Roof" then
   local cf,size=bounds(roof);local center=cf.Position
   if Vector2.new(center.X,center.Z).Magnitude<=CAMP-8 then
    for _,offset in ipairs({Vector3.zero,Vector3.new(1.6,0,1.6),Vector3.new(-1.6,0,-1.6)}) do
     local point=(cf*CFrame.new(offset)).Position
     local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Exclude;ray.FilterDescendantsInstances={roof,table.unpack(excluded)};ray.RespectCanCollide=true
     local floor=workspace:Raycast(Vector3.new(point.X,center.Y-size.Y*.5-.2,point.Z),Vector3.new(0,-24,0),ray)
     local floorType=floor and floor.Instance:GetAttribute("BuildType")
     if floor and floor.Normal.Y>.65 and (floor.Instance==workspace.Terrain or floorType=="Floor") then
      local height=(center.Y-size.Y*.5)-floor.Position.Y
      local arrival=Vector3.new(point.X,floor.Position.Y+3.2,point.Z)
      if height>=6.5 and height<=18 and clearArrival(arrival,floor.Instance,excluded,result) then table.insert(candidates,{Position=arrival,Floor=floor.Instance}) end
     end
    end
   end
  end
 end
 table.sort(candidates,function(a,b)return Vector2.new(a.Position.X,a.Position.Z).Magnitude<Vector2.new(b.Position.X,b.Position.Z).Magnitude end)
 for _,candidate in ipairs(candidates) do if #result>=count then break end;if clearArrival(candidate.Position,candidate.Floor,excluded,result) then table.insert(result,candidate.Position) end end
 -- Fill remaining slots in a compact spiral on the permanent camp plateau.
 for radius=6,156,6 do
  local slots=math.max(6,math.floor(radius*.75))
  for i=1,slots do
   if #result>=count then return result end
   local angle=(i-1)*math.pi*2/slots+radius*.17
   local arrival=Vector3.new(math.cos(angle)*radius,CAMP_HEIGHT+3.2,math.sin(angle)*radius)
   if clearArrival(arrival,nil,excluded,result) then table.insert(result,arrival) end
  end
 end
 while #result<count do table.insert(result,Vector3.new((#result-count*.5)*8,CAMP_HEIGHT+10,0)) end
 return result
end
function Service:_plan()
 local rng=Random.new(self._visitSeed);self._regions={};self._landmarks={};self._roadAngle=rng:NextNumber(0,math.pi)
 local tier=RS:GetAttribute("CampaignTier") or 1
 local candidates=Biomes.EligibleRegions(self._biome,tier,self._previousVisits or 0)
 local count=rng:NextInteger(6,9);local phase=rng:NextNumber(0,math.pi*2)
 for i=1,count do
  local selected=candidates[1]
  if i==2 and self._biome=="Swamp" and tier==2 then selected=candidates[2]
  elseif i>1 then
   local total=0;for _,c in ipairs(candidates) do total+=({3,3,2,1.5,1})[c.Depth] end
   local roll=rng:NextNumber()*total
   for _,c in ipairs(candidates) do roll-=({3,3,2,1.5,1})[c.Depth];if roll<=0 then selected=c;break end end
  end
  local angle=phase+(i-1)*math.pi*2/count
  local radius=i==1 and 400 or rng:NextNumber(600,1050)
  local r=table.clone(selected);r.Id=selected.Id..":"..i;r.TypeId=selected.Id;r.Biome=self._biome;r.Tier=math.max(tier,({1,1,4,6,8})[r.Depth]);r.Radius=570
  r.Center=Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)
  table.insert(self._regions,r)
 end
 for _,r in ipairs(self._regions) do
  r.Center=Vector3.new(r.Center.X,self:GetHeight(r.Center.X,r.Center.Z),r.Center.Z)
  local p=self:SafePosition(r.Center,true)
  local id=r.TypeId.."Landmark"
  table.insert(self._landmarks,{Id=id,Position=p-Vector3.new(0,5,0),RegionId=r.Id,Name=r.Name,Biome=self._biome,Depth=r.Depth,FoundationRadius=(Biomes.Biomes[self._biome].Landform=="Forest" or Biomes.Biomes[self._biome].Landform=="Canopy") and 90 or 40})
 end
end
function Service:_clearSurface()
 -- Terrain is not parented to GeneratedWorld: deleting chunk models does not
 -- remove its grass, water or cave roofs. Track even partial/unloaded chunks.
 if not self._surfaceInitialized then
  -- Also remove surface geometry already present in the place on server start.
  -- This slab ends at Y=416; separately generated interiors live at Y=3000.
  for cx=-7,6 do
   workspace.Terrain:FillBlock(CFrame.new((cx+.5)*CHUNK,128,0),Vector3.new(CHUNK,576,14*CHUNK),Enum.Material.Air)
   task.wait()
  end
  self._surfaceInitialized=true
 else
  for key,cell in pairs(self._terrainFootprints) do
   workspace.Terrain:FillBlock(CFrame.new((cell.X+.5)*CHUNK,128,(cell.Z+.5)*CHUNK),Vector3.new(CHUNK,576,CHUNK),Enum.Material.Air)
   self._terrainFootprints[key]=nil
   task.wait()
  end
 end
 self._terrainFootprints={};self._terrain={};self._campMade=false
end
function Service:_paint(cx,cz,token)
 local key=cx..","..cz;if self._terrain[key] then return end
 if token~=self._generation then return end
 self._terrainFootprints[key]={X=cx,Z=cz}
 local b=Biomes.Biomes[self._biome];local material=Enum.Material[b.Material] or Enum.Material.Grass
 for ix=0,CHUNK/CELL-1 do
  for iz=0,CHUNK/CELL-1 do
   if token~=self._generation then return end
   local x,z=cx*CHUNK+(ix+.5)*CELL,cz*CHUNK+(iz+.5)*CELL
   if x*x+z*z<(RADIUS+CELL)^2 then
    local campCell=x*x+z*z<=(CAMP+CELL*.7072)^2
    local h=campCell and CAMP_HEIGHT or self:GetHeight(x,z)
    local region=self:MetadataAt(Vector3.new(x,h,z))
    local surface=material
    if region then
     local name=region.Name
     if name:find("Canyon") or name:find("Red") then surface=Enum.Material.Sandstone
     elseif name:find("Ice") or name:find("Frozen") or name:find("Glacier") then surface=Enum.Material.Glacier
     elseif name:find("Ruins") or name:find("City") or name:find("Village") or name:find("Archive") then surface=Enum.Material.Cobblestone
     elseif name:find("Ash") or name:find("Lava") or name:find("Furnace") then surface=Enum.Material.Basalt
     elseif name:find("Crystal") or name:find("Glass") then surface=Enum.Material.Slate
     elseif name:find("Meadow") or name:find("Gardens") then surface=Enum.Material.Grass end
    end
    -- The raised camp plateau never changes elevation. Smaller columns soften slopes.
    if not campCell or not self._campMade then
     workspace.Terrain:FillBlock(CFrame.new(x,128,z),Vector3.new(CELL,576,CELL),Enum.Material.Air)
     workspace.Terrain:FillBlock(CFrame.new(x,(h-160)/2,z),Vector3.new(CELL,h+160,CELL),campCell and Enum.Material.Ground or surface)
     local water=self:GetWaterLevel(x,z)
     if water and water>h then workspace.Terrain:FillBlock(CFrame.new(x,(water+h)/2,z),Vector3.new(CELL,water-h,CELL),Enum.Material.Water) end
     local region=self:MetadataAt(Vector3.new(x,h,z))
     local cavern=b.Landform=="Cavern" or region and (region.Name:find("Cave") or region.Name:find("Tunnel"))
     if cavern and x*x+z*z>270^2 and math.noise(x*.01,z*.01,self._visitSeed*.00002) < .24 then
      workspace.Terrain:FillBlock(CFrame.new(x,h+62,z),Vector3.new(CELL,16,CELL),Enum.Material.Rock)
     end
    end
   end
  end
  if ix%2==0 then task.wait() end
 end
 if token==self._generation then self._terrain[key]=true end
end
function Service:GroundPoint(position)
 local height=self:GetHeight(position.X,position.Z)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={workspace.Terrain};params.IgnoreWater=true
 -- Cast below cave ceilings, and only against already painted native ground.
 local hit=workspace:Raycast(Vector3.new(position.X,height+16,position.Z),Vector3.new(0,-48,0),params)
 return hit and hit.Position or Vector3.new(position.X,height,position.Z)
end
function Service:_resource(id,key,position,parent,rng)
 if id=="Water" or id=="DirtyWater" then return nil end
 local Items=require(RS.Shared.Items.ItemDatabase);local item=Items:Get(id);if not item then return nil end
 local Loot=require(RS.Shared.ExpeditionLootConfig)
 local profile=require(RS.Shared.OverhaulCatalog).ResourceDefinitions[id] or Loot.ResourceProfile(item,id)
 local state=self._records[key];if state and state.Gone then return nil end
 position=self:GroundPoint(position)
 local model=Instance.new("Model");model.Name=id
 local biome=Biomes.Biomes[self._biome];local color=biome.Color
 local isTree=id=="Wood" or id=="Ironwood" or id=="Heartwood"
 local kind=profile.Kind or require(RS.Shared.ClassConfig).ResourceKind(id)
 local large=isTree and rng:NextNumber()<.3
 local region=self:MetadataAt(position)
 local birch=region and region.Name=="Birch Woods"
 if isTree then
  local h=large and 18 or 12
  makeTree(model,h,color,rng,{Birch=birch,Pine=self._biome=="FrozenTundra" or self._biome=="AuroraVale" or biome.Landform=="Alpine" or biome.Landform=="Highlands",Ironwood=id=="Ironwood",Heartwood=id=="Heartwood"})
 elseif id=="Cactus" then
  local stem=part(model,"CactusStem",Vector3.new(2,7,2),CFrame.new(0,3.5,0),Color3.fromRGB(92,130,65));model.PrimaryPart=stem
  for side=-1,1,2 do part(model,"Arm",Vector3.new(3,1.5,1.5),CFrame.new(side*1.7,4,0),stem.Color);part(model,"Tip",Vector3.new(1.5,3,1.5),CFrame.new(side*3,5,0),stem.Color) end
 elseif (profile.Duration or 0)>0 then
  local root=part(model,"Root",Vector3.new(1,1,1),CFrame.new(0,.5,0),Color3.fromRGB(67,110,53));model.PrimaryPart=root
  for n=1,4 do local a=n*1.57;local leaf=part(model,"Leaf",Vector3.new(.8,2.2,.25),CFrame.new(math.cos(a)*.6,1.4,math.sin(a)*.6)*CFrame.Angles(.35,a,.5),color:Lerp(Color3.new(.45,.7,.3),.5));leaf.CanCollide=false end
  local cap=part(model,"Bloom",Vector3.new(1.8,.8,1.8),CFrame.new(0,2.3,0),id:find("Mushroom") and Color3.fromRGB(147,100,72) or Color3.fromHSV(rng:NextNumber(),.45,.85));cap.Shape=Enum.PartType.Ball;cap.CanCollide=false
 else
  local root=part(model,"Rock",Vector3.new(4,3,4),CFrame.new(0,1.5,0)*CFrame.Angles(0,rng:NextNumber()*6,.15),color:Lerp(Color3.new(.35,.35,.4),.5),Enum.Material.Rock);model.PrimaryPart=root
  for n=1,3 do part(model,"Seam",Vector3.new(.9,2,.9),CFrame.new(n-2,2.5,0)*CFrame.Angles(0,n,.3),Color3.fromHSV((hash(id)%100)/100,.5,.8),id:find("Crystal") and Enum.Material.Neon or Enum.Material.Slate) end
 end
 local hp=profile.Health or 200;if isTree and large then hp=profile.LargeHealth or hp*1.75 end
 model:SetAttribute("DropItemId",id);model:SetAttribute("DropMin",profile.Min or 2);model:SetAttribute("DropMax",profile.Max or 4)
 model:SetAttribute("Health",state and state.Health or hp);model:SetAttribute("CurrentHealth",state and state.Health or hp);model:SetAttribute("MaxHealth",hp)
 model:SetAttribute("Duration",profile.Duration or 0);model:SetAttribute("MiningGrade",profile.MiningGrade or 1);model:SetAttribute("ResourceGrade",profile.Grade or 1);model:SetAttribute("ResourceKind",kind)
 model:SetAttribute("SnapshotKey",key);model:SetAttribute("OverhaulNode",true);model:SetAttribute("ContactDamage",id=="Cactus" and 4 or nil)
 model:PivotTo(CFrame.new(position)*model:GetPivot());model.Parent=parent
 self._nodes[key]={Instance=model,Id=id,Position=position,Kind=kind,Profile=profile}
 model:GetAttributeChangedSignal("Health"):Connect(function() self._records[key]=self._records[key] or {};self._records[key].Health=model:GetAttribute("Health") end)
 model.Destroying:Connect(function()
  if not model:GetAttribute("Unloading") then self._records[key]=self._records[key] or {};self._records[key].Gone=true end
  self._nodes[key]=nil
 end)
 return model
end
function Service:_candidates(cx,cz)
 local result={};local rng=Random.new(hash(cx..","..cz,self._visitSeed))
 for i=1,30 do
  local x,z=cx*CHUNK+((i-1)%6+.5)*40+rng:NextNumber(-8,8),cz*CHUNK+(math.floor((i-1)/6)+.5)*48+rng:NextNumber(-8,8)
  local p=Vector3.new(x,self:GetHeight(x,z),z);local region=self:MetadataAt(p)
  if region and x*x+z*z>240^2 and x*x+z*z<(RADIUS-16)^2 and self:IsSafe(p,3) then
   local blocked=false
   for _,landmark in ipairs(self._landmarks) do if (p-landmark.Position).Magnitude<(landmark.FoundationRadius or 40)+8 then blocked=true;break end end
   if blocked then continue end
   local pool=region.Resources;local id=pool[rng:NextInteger(1,#pool)]
    if i%8==0 then id="Stone" end
   table.insert(result,{Id=id,Key=cx..","..cz..":"..i,Position=p,Seed=rng:NextInteger(1,2147483646),Region=region})
  end
 end
 return result
end
function Service:_decorate(parent,cx,cz)
 if riverBiomes[self._biome] then
  for z=-1440,1440,32 do
   local riverX=self:_riverLine(z);local water=self:GetWaterLevel(riverX,z)
   for _,side in ipairs({-1,1}) do
    local x=riverX+side*30
    if water and math.floor(x/CHUNK)==cx and math.floor(z/CHUNK)==cz and Vector2.new(x,z).Magnitude>270 then
    local source=part(parent,"RiverWaterSource",Vector3.new(10,1,10),CFrame.new(x,self:GetHeight(x,z)+1,z),Color3.new(1,1,1));source.Transparency=1;source.CanCollide=false;source.CanTouch=false;source:SetAttribute("Decoration",true)
    local prompt=Instance.new("ProximityPrompt");prompt.ActionText="Collect water";prompt.ObjectText="River";prompt.KeyboardKeyCode=Enum.KeyCode.F;prompt.HoldDuration=1.4;prompt.MaxActivationDistance=10;prompt.RequiresLineOfSight=false;prompt.Parent=source
    prompt.Triggered:Connect(function(player)
     local character=player.Character;local humanoid=character and character:FindFirstChildOfClass("Humanoid");local root=character and character:FindFirstChild("HumanoidRootPart")
     if not root or not humanoid or humanoid.Health<=0 or player:GetAttribute("IsDead") or (root.Position-source.Position).Magnitude>12 then return end
     local held=character:FindFirstChildOfClass("Tool");local itemId=held and held:GetAttribute("InventoryItemId")
     local gear=require(script.Parent.GearService);local inventory=require(script.Parent.InventoryService);local success,message=false,"Hold a Water Flask or Bucket to collect water."
     if itemId=="WaterFlask" then
      local stored=gear:StoreWater(player,5);success=stored>0;message=success and ("Filled "..stored.." flask use"..(stored==1 and "" or "s")..".") or "That flask is already full."
     elseif itemId=="Bucket" then
      local stored=gear:StoreWater(player,3);local added=inventory:Give(player,"Water",3-stored,true)
      success=stored+added>0;message=success and ("Collected "..(stored+added).." Water.") or "Your flasks and inventory are full."
     end
     if success then require(script.Parent.ExpeditionRewardsService):RecordActivity(player) end
     if gear.Remote then gear.Remote:FireClient(player,"Result",{Success=success,Message=message}) end
    end)
    end
   end
  end
  for z=-960,960,480 do
   local x=self:_riverLine(z)
   if math.floor(x/CHUNK)==cx and math.floor(z/CHUNK)==cz and Vector2.new(x,z).Magnitude>270 then
    local top=self:_flow(x,z-.1);local bottom=self:_flow(x,z+.1)
    if top and bottom and top>bottom then
     local flow=part(parent,"Waterfall",Vector3.new(36,top-bottom+3,2),CFrame.new(x,(top+bottom)*.5,z),Color3.fromRGB(123,183,197),Enum.Material.Glass)
     flow.Transparency=.45;flow.CanCollide=false;flow.CanTouch=false
     local spray=Instance.new("ParticleEmitter");spray.Texture="rbxasset://textures/particles/smoke_main.dds";spray.Rate=5;spray.Lifetime=NumberRange.new(.6,1);spray.Speed=NumberRange.new(1,3);spray.Transparency=NumberSequence.new(.75,1);spray.Size=NumberSequence.new(2,5);spray.Parent=flow
     flow:SetAttribute("Decoration",true)
    end
   end
  end
 end
 local biome=Biomes.Biomes[self._biome];local rng=Random.new(hash("props"..cx..","..cz,self._visitSeed))
 for i=1,7 do
  local x,z=cx*CHUNK+rng:NextNumber(10,230),cz*CHUNK+rng:NextNumber(10,230)
  if x*x+z*z<240^2 or x*x+z*z>RADIUS^2 then continue end
  local p=self:GroundPoint(Vector3.new(x,0,z));local f=biome.Landform;local r=self:MetadataAt(p)
  local blocked=false
  for _,entry in ipairs(self:_candidates(cx,cz)) do if (entry.Position-p).Magnitude<28 then blocked=true;break end end
  for _,landmark in ipairs(self._landmarks) do if (landmark.Position-p).Magnitude<(landmark.FoundationRadius or 40)+15 then blocked=true;break end end
  if blocked then continue end
  local model=Instance.new("Model");model.Name=r.Name.."Scenery";model:SetAttribute("Decoration",true)
  if f=="Cavern" or r.Name:find("Cave") or r.Name:find("Tunnel") then
   part(model,"Column",Vector3.new(9,40,9),CFrame.new(p+Vector3.new(-18,20,0)),biome.Color,Enum.Material.Rock)
   part(model,"Column",Vector3.new(9,40,9),CFrame.new(p+Vector3.new(18,20,0)),biome.Color,Enum.Material.Rock)
   part(model,"Vault",Vector3.new(48,7,26),CFrame.new(p+Vector3.new(0,42,0)),biome.Color,Enum.Material.Rock)
  elseif f=="Canopy" or f=="Forest" then
   local h=f=="Canopy" and 26 or 15
   makeTree(model,h,biome.Color,rng,{Birch=r.Name=="Birch Woods",Pine=self._biome=="FrozenTundra" or self._biome=="AuroraVale" or f=="Alpine" or f=="Highlands"})
   model:PivotTo(CFrame.new(p)*CFrame.Angles(0,rng:NextNumber(0,math.pi*2),0)*model:GetPivot())
   if f=="Canopy" then part(model,"RootRamp",Vector3.new(12,3,60),CFrame.new(p+Vector3.new(0,10,22))*CFrame.Angles(-.3,0,0),Color3.fromRGB(104,80,59),Enum.Material.Wood) end
  elseif f=="Mushroom" then
   part(model,"Stem",Vector3.new(4,18,4),CFrame.new(p+Vector3.new(0,9,0)),Color3.fromRGB(162,151,129))
   local cap=part(model,"GiantCap",Vector3.new(30,6,30),CFrame.new(p+Vector3.new(0,20,0)),Color3.fromRGB(104,133,163));cap.Shape=Enum.PartType.Ball
  elseif f=="Ruins" or r.Name:find("Ruins") or r.Name:find("City") or r.Name:find("Village") then
   part(model,"Walkway",Vector3.new(30,2,12),CFrame.new(p+Vector3.new(0,1,0)),biome.Color,Enum.Material.Slate)
   for side=-1,1,2 do part(model,"BrokenPillar",Vector3.new(4,16,4),CFrame.new(p+Vector3.new(side*12,8,0)),biome.Color,Enum.Material.Slate) end
  else
   local h=f=="Crystal" and 22 or f=="Highlands" and 14 or 8
   local rock=part(model,"Outcrop",Vector3.new(9,h,11),CFrame.new(p+Vector3.new(0,h/2,0))*CFrame.Angles(.18,rng:NextNumber()*6,.1),biome.Color,Enum.Material.Rock)
   if f=="Crystal" then rock.Material=Enum.Material.Glass;rock.Color=Color3.fromRGB(144,124,201) end
  end
  model.Parent=parent
  if f=="Cavern" or f=="Crystal" or f=="Mushroom" then
   local anchor=model:FindFirstChildWhichIsA("BasePart")
   if anchor then local light=Instance.new("PointLight");light.Color=biome.Color;light.Range=30;light.Brightness=.7;light.Parent=anchor end
  end
 end
end
function Service:_chunkWork(cx,cz,token)
 if token~=self._generation then return end
 local key=cx..","..cz;if self._chunks[key] then self._chunks[key].Last=os.clock();return end
 self:_paint(cx,cz,token);if token~=self._generation then return end
 local f=folder(self._folder,key);local resources=folder(f,"Resources");local props=folder(f,"Props")
 local regions={}
 local center=Vector3.new((cx+.5)*CHUNK,0,(cz+.5)*CHUNK)
 for _,r in ipairs(self._regions) do
  local near=Vector2.new(math.clamp(r.Center.X,cx*CHUNK,(cx+1)*CHUNK),math.clamp(r.Center.Z,cz*CHUNK,(cz+1)*CHUNK))
  if (near-Vector2.new(r.Center.X,r.Center.Z)).Magnitude<=r.Radius then table.insert(regions,{name=r.Name,x=r.Center.X,z=r.Center.Z,sx=r.Radius*1.4,sz=r.Radius*1.4,temp=self:GetTemperatureAt(center),height=self:GetHeight(center.X,center.Z),water=(self:GetWaterLevel(center.X,center.Z) or -1000)>self:GetHeight(center.X,center.Z),layer=self:GetMapLayer(center)}) end
 end
 f:SetAttribute("MapChunkX",cx);f:SetAttribute("MapChunkZ",cz);f:SetAttribute("MapBiome",self._biome);f:SetAttribute("MapRegionsJson",Http:JSONEncode(regions))
 self._chunks[key]={Folder=f,Last=os.clock(),X=cx,Z=cz}
 require(script.Parent.TeamExplorationService):RecordChunk(f,self._serial)
 for _,entry in ipairs(self:_candidates(cx,cz)) do self:_resource(entry.Id,entry.Key,entry.Position,resources,Random.new(entry.Seed)) end
 self:_decorate(props,cx,cz)
 require(script.Parent.ResourceNodeService):BindFolder(resources)
 self:_materializeLandmarks(f,cx,cz)
end
function Service:_chunk(cx,cz,token)
 local key=cx..","..cz
 while self._loading[key] do
  if token~=self._generation then return end
  task.wait()
 end
 if token~=self._generation then return end
 if self._chunks[key] then self._chunks[key].Last=os.clock();return end
 self._loading[key]=true
 local ok,err=pcall(self._chunkWork,self,cx,cz,token)
 self._loading[key]=nil
 if token~=self._generation then return end
 if not ok then
  local partial=self._folder and self._folder:FindFirstChild(key)
  if partial then for _,n in ipairs(partial:GetDescendants()) do if n:GetAttribute("OverhaulNode") then n:SetAttribute("Unloading",true) end end;partial:Destroy() end
  self._chunks[key]=nil
  error(err)
 end
end
function Service:_materializeLandmarks(parent,cx,cz)
 for _,entry in ipairs(self._landmarks) do
  local p=self:GroundPoint(entry.Position)
  if math.floor(p.X/CHUNK)~=cx or math.floor(p.Z/CHUNK)~=cz then continue end
  local m=Instance.new("Model");m.Name=entry.Name.." Landmark";m:SetAttribute("LandmarkId",entry.Id);m:SetAttribute("RegionId",entry.RegionId);m:SetAttribute("BiomeId",entry.Biome);m:SetAttribute("RegionDepth",entry.Depth)
  local base=part(m,"Foundation",Vector3.new(18,2,18),CFrame.new(p+Vector3.new(0,1,0)),Color3.fromRGB(109,112,102),Enum.Material.Slate);m.PrimaryPart=base
  for side=-1,1,2 do part(m,"Post",Vector3.new(2,10,2),CFrame.new(p+Vector3.new(side*7,6,0)),Color3.fromRGB(87,74,59),Enum.Material.Wood) end
  part(m,"Beacon",Vector3.new(3,3,3),CFrame.new(p+Vector3.new(0,9,0)),Color3.fromRGB(223,183,85),Enum.Material.Neon)
  local name=entry.Name;local biome=Biomes.Biomes[entry.Biome];local family=biome.Landform
  m:SetAttribute("MapMarkerType","Structure");m:SetAttribute("MapMarkerLabel",name)
  if name:find("Cave") or name:find("Tunnel") or family=="Cavern" then
   m:SetAttribute("MapMarkerLabel",name.." / cave entrance");m:SetAttribute("LinkedMapLayer","Cave")
   for _,side in ipairs({-1,1}) do part(m,"CaveButtress",Vector3.new(8,25,22),CFrame.new(p+Vector3.new(side*17,12.5,0)),biome.Color,Enum.Material.Rock) end
   part(m,"EntranceArch",Vector3.new(44,8,25),CFrame.new(p+Vector3.new(0,27,0)),biome.Color,Enum.Material.Rock)
  elseif family=="Forest" or family=="Canopy" then
   local height=entry.Depth>=3 and 20 or 8
   for _,side in ipairs({-1,1}) do part(m,"LivingSupport",Vector3.new(5,height,5),CFrame.new(p+Vector3.new(side*11,height/2,-7)),Color3.fromRGB(92,72,47),Enum.Material.Wood) end
   part(m,"RangerPlatform",Vector3.new(28,2,18),CFrame.new(p+Vector3.new(0,height,-7)),Color3.fromRGB(121,94,58),Enum.Material.WoodPlanks)
   local length=height*3;part(m,"RootApproach",Vector3.new(10,2,length),CFrame.new(p+Vector3.new(0,height*.5,length*.5-7))*CFrame.Angles(math.atan(height/length),0,0),Color3.fromRGB(115,88,55),Enum.Material.Wood)
  elseif family=="Ruins" or name:find("City") or name:find("Village") or name:find("Fortress") or name:find("Observatory") or name:find("Furnace") then
   part(m,"BackWall",Vector3.new(27,13,3),CFrame.new(p+Vector3.new(0,7,-12)),biome.Color,Enum.Material.Slate)
   for _,side in ipairs({-1,1}) do part(m,"DoorJamb",Vector3.new(7,13,3),CFrame.new(p+Vector3.new(side*10,7,12)),biome.Color,Enum.Material.Slate) end
   part(m,"Roof",Vector3.new(28,2,28),CFrame.new(p+Vector3.new(0,15,0)),biome.Color,Enum.Material.Slate)
  elseif family=="Crystal" or family=="Crater" or family=="Moon" then
   for i=1,5 do local a=i*math.pi*2/5;local height=8+i*3
    local shard=part(m,"SurveySpire",Vector3.new(4,height,4),CFrame.new(p+Vector3.new(math.cos(a)*16,height/2,math.sin(a)*16))*CFrame.Angles(.12,a,.1),biome.Color:Lerp(Color3.new(1,1,1),.2),Enum.Material.Glass)
    local light=Instance.new("PointLight");light.Range=18;light.Brightness=.4;light.Color=shard.Color;light.Parent=shard
   end
  elseif family=="Coast" or family=="Wetland" then
   part(m,"RaisedWalkway",Vector3.new(10,2,54),CFrame.new(p+Vector3.new(0,3,18)),Color3.fromRGB(133,112,77),Enum.Material.WoodPlanks)
   for i=0,4 do part(m,"DockStair",Vector3.new(10,1,3),CFrame.new(p+Vector3.new(0,.5+i*.5,47-i*3)),Color3.fromRGB(133,112,77),Enum.Material.WoodPlanks) end
  elseif family=="Mushroom" then
   for _,side in ipairs({-1,1}) do
    part(m,"FungalStem",Vector3.new(5,20,5),CFrame.new(p+Vector3.new(side*15,10,0)),Color3.fromRGB(191,177,153))
    local cap=part(m,"FungalRoof",Vector3.new(35,6,24),CFrame.new(p+Vector3.new(side*15,22,0)),biome.Color);cap.Shape=Enum.PartType.Ball
   end
  end
  m.Parent=parent
  local callback=(_G.Ecoshift or {}).OnOverhaulLandmark
  if callback then callback(m,entry) end
 end
end
function Service:EnsureArea(position)
 local token=self._generation
 if self._clearingSurface then return end
 local cx,cz=math.floor(position.X/CHUNK),math.floor(position.Z/CHUNK)
 for dx=-1,1 do for dz=-1,1 do
  if token~=self._generation then return end
  self:_chunk(cx+dx,cz+dz,token)
 end end
end
function Service:GetClassScanMarkers(position,radius,mineralsOnly)
 local result={};local Loot=require(RS.Shared.ExpeditionLootConfig);local Items=require(RS.Shared.Items.ItemDatabase)
 for cx=math.floor((position.X-radius)/CHUNK),math.floor((position.X+radius)/CHUNK) do
  for cz=math.floor((position.Z-radius)/CHUNK),math.floor((position.Z+radius)/CHUNK) do
   for _,e in ipairs(self:_candidates(cx,cz)) do
    local item=Items:Get(e.Id);local profile=item and (require(RS.Shared.OverhaulCatalog).ResourceDefinitions[e.Id] or Loot.ResourceProfile(item,e.Id))
    if (e.Position-position).Magnitude<=radius and not (self._records[e.Key] or {}).Gone and (not mineralsOnly or profile and profile.Kind=="Mineral") then
     table.insert(result,{Id=e.Key,ResourceId=e.Id,Kind="Resource",Name=item and item.Name or e.Id,Label=item and item.Name or e.Id,Position=e.Position})
    end
   end
  end
 end
 if not mineralsOnly then for _,l in ipairs(self._landmarks) do if (l.Position-position).Magnitude<=radius then table.insert(result,{Id=l.Id,Kind="Structure",Name=l.Name,Label=l.Name,Position=l.Position}) end end end
 return result
end
function Service:RegrowPlants(position,radius,limit)
 local candidates={}
 for cx=math.floor((position.X-radius)/CHUNK),math.floor((position.X+radius)/CHUNK) do for cz=math.floor((position.Z-radius)/CHUNK),math.floor((position.Z+radius)/CHUNK) do
  for _,e in ipairs(self:_candidates(cx,cz)) do
   local state=self._records[e.Key];local kind=require(RS.Shared.ClassConfig).ResourceKind(e.Id)
   if state and state.Gone and not state.Regrown and kind=="Plant" and (e.Position-position).Magnitude<=radius then table.insert(candidates,e) end
  end
 end end
 table.sort(candidates,function(a,b)return(a.Position-position).Magnitude<(b.Position-position).Magnitude end)
 local count=0
 for _,e in ipairs(candidates) do
  if count>=limit then break end
  self._records[e.Key]={Regrown=true};count+=1
  local key=math.floor(e.Position.X/CHUNK)..","..math.floor(e.Position.Z/CHUNK);local chunk=self._chunks[key]
  if chunk then self:_resource(e.Id,e.Key,e.Position,folder(chunk.Folder,"Resources"),Random.new(e.Seed)) end
 end
 return count
end
function Service:Generate(biome)
 local BiomeService=require(script.Parent.BiomeService);local serial=BiomeService:GetVisitSerial()
 self._generation+=1;self._busy=true
 self._clearingSurface=true
 for _,node in pairs(self._nodes) do if node.Instance.Parent then node.Instance:SetAttribute("Unloading",true) end end
 self._folder=folder(workspace,"GeneratedWorld");self._folder:SetAttribute("Generated",false);self._folder:ClearAllChildren();self._chunks={};self._nodes={}
 self:_clearSurface()
 if self._serial~=serial or self._biome~=biome then self._records={};self._encounters={} end
 self._serial,self._biome=serial,biome;self._previousVisits=BiomeService:GetPreviousVisits()
 self._visitSeed=hash(biome..":"..serial,self._seed);self:_plan()
 self._clearingSurface=false
 local exploration=require(script.Parent.TeamExplorationService);exploration:BeginBiome(biome,serial)
 -- Publish full coarse metadata without creating distant content.
 for cx=-7,6 do for cz=-7,6 do
  local center=Vector3.new((cx+.5)*CHUNK,0,(cz+.5)*CHUNK)
  if Vector2.new(center.X,center.Z).Magnitude<=RADIUS then
   local r=self:MetadataAt(center);exploration:RecordMetadata(cx,cz,biome,{{name=r.Name,x=r.Center.X,z=r.Center.Z,sx=r.Radius*1.4,sz=r.Radius*1.4,temp=self:GetTemperatureAt(center),height=self:GetHeight(center.X,center.Z),water=(self:GetWaterLevel(center.X,center.Z) or -1000)>self:GetHeight(center.X,center.Z),layer=self:GetMapLayer(center)}},serial)
  end
 end end
 self:EnsureArea(Vector3.zero)
 local spawn=workspace:FindFirstChildWhichIsA("SpawnLocation",true)
 if spawn and Vector2.new(spawn.Position.X,spawn.Position.Z).Magnitude<=CAMP then spawn.Position=Vector3.new(spawn.Position.X,CAMP_HEIGHT+spawn.Size.Y*.5+.15,spawn.Position.Z) end
 for _,player in ipairs(Players:GetPlayers()) do
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if root and not player:GetAttribute("InteriorId") then self:EnsureArea(self:SafePosition(root.Position)) end
 end
 self._campMade=true;self._busy=false
 self._folder:SetAttribute("Generated",true)
 if not self._loop then
  self._loop=true
  task.spawn(function()
   while true do
    if Rules.IsOverhaul() and not self._busy and not RS:GetAttribute("WorldRestoring") then
     local token=self._generation
     for _,player in ipairs(Players:GetPlayers()) do
      if token~=self._generation or self._busy then break end
      local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
      if root and not player:GetAttribute("InteriorId") then
       local ok,err=pcall(self.EnsureArea,self,root.Position)
       if token~=self._generation or self._busy then break end
       if not ok then warn("[SurfaceStreaming]",err) else exploration:RevealFromPlayer(player,root.Position) end
       local region=self:MetadataAt(root.Position)
       if region then player:SetAttribute("RegionId",region.TypeId);player:SetAttribute("RegionDepth",region.Depth);player:SetAttribute("RegionName",region.Name) end
      end
     end
     for key,c in pairs(self._chunks) do
      if token~=self._generation or self._busy then break end
      if os.clock()-c.Last>25 then
       for _,n in ipairs(c.Folder:GetDescendants()) do if n:GetAttribute("OverhaulNode") then n:SetAttribute("Unloading",true) end end
       c.Folder:Destroy();self._chunks[key]=nil
      end
     end
    end
    task.wait(.5)
   end
  end)
 end
end
function Service:CaptureWorldState()
 return {GeneratorVersion=2,Seed=self._seed,Epoch=self._serial,Biome=self._biome,Objects=Codec.Copy(self._records),Encounters=Codec.Copy(self._encounters or {})}
end
function Service:RestoreWorldState(state)
 assert(state.GeneratorVersion==2,"Unsupported terrain generator")
 self._seed=Codec.Number(state.Seed,1,2147483647);self._serial=Codec.Number(state.Epoch,0,1e8);self._biome=state.Biome
 Codec.BoundedCount(state.Objects,60000);self._records=Codec.Copy(state.Objects);self._encounters=Codec.Copy(state.Encounters or {})
end
return Service
