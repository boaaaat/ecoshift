-- Original low-poly expedition constructions, authored with their base on y=0.
local Catalog=require(script.Parent.Parent.OverhaulCatalog)
local Art={}
local wood=Color3.fromRGB(121,91,51)
local green=Color3.fromRGB(79,102,68)
local metal=Color3.fromRGB(74,81,77)
local stone=Color3.fromRGB(116,115,103)
local amber=Color3.fromRGB(233,181,77)
local function part(m,name,size,pos,color,class)
 local p=Instance.new(class or "Part");p.Name=name;p.Size=size;p.CFrame=typeof(pos)=="CFrame" and pos or CFrame.new(pos)
 p.Color=color or wood;p.Material=Enum.Material.SmoothPlastic;p.Anchored=true;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=m
 return p
end
local function light(p,range)
 p.Material=Enum.Material.Neon;local l=Instance.new("PointLight");l.Color=amber;l.Range=range;l.Brightness=1.6;l.Shadows=true;l.Parent=p
end
local function legs(m,width,depth,height)
 for x=-1,1,2 do for z=-1,1,2 do part(m,"Leg",Vector3.new(.3,height,.3),Vector3.new(x*(width/2-.2),height/2,z*(depth/2-.2)),wood) end end
end
local function ladder(m,x,z,height)
 local truss=part(m,"ClimbableLadder",Vector3.new(2,height,1),Vector3.new(x,height/2,z),metal,"TrussPart");truss:SetAttribute("Climbable",true)
end
function Art.Create(id)
 if not Catalog.Placeables[id] then return nil end
 local m=Instance.new("Model");m.Name=id;m:SetAttribute("BuildType",id);m:SetAttribute("ArtVersion",2)
 local root=part(m,"GroundAnchor",Vector3.new(.1,.1,.1),Vector3.new(0,.05,0),wood);root.Transparency=1;root.CanCollide=false;root.CanQuery=false;root.CanTouch=false;m.PrimaryPart=root
 local V=Vector3.new
 if id=="Floor" or id=="Roof" then
  for i=0,7 do part(m,"Plank",V(.96,.5,8),V(-3.5+i,.25,0),i%2==0 and wood or green) end
 elseif id=="Wall" then
  for i=0,7 do part(m,"WallPlank",V(.98,8,.35),V(-3.5+i,4,0),wood) end
  part(m,"Brace",V(8,.3,.65),V(0,2,0),green);part(m,"Brace",V(8,.3,.65),V(0,6,0),green)
 elseif id=="Door" or id=="Gate" then
  local w=id=="Door" and 4 or 8;m:SetAttribute("DoorWidth",w)
  for x=-1,1,2 do part(m,"DoorPost",V(.35,8.3,.7),V(x*(w/2+.2),4.15,0),green) end
  part(m,"Lintel",V(w+.8,.35,.7),V(0,8.15,0),green)
  local leaf=Instance.new("Model");leaf.Name="DoorLeaf";leaf.Parent=m
  local face=part(leaf,"DoorPanel",V(w-.15,7.9,.4),V(0,4,0),wood);leaf.PrimaryPart=face
  part(leaf,"Handle",V(.16,.6,.18),V(w/2-.5,4,-.32),amber)
 elseif id=="Ramp" then
  part(m,"Ramp",V(8,8,8),V(0,4,0),wood,"WedgePart")
 elseif id=="Stairs" then
  for i=1,8 do part(m,"Step",V(8,i,1),V(0,i/2,-4+i-.5),i%2==0 and wood or green) end
 elseif id=="Ladder" then ladder(m,0,0,8)
 elseif id=="Watchtower" then
  legs(m,8,8,15.5)
  part(m,"Platform",V(8,.5,8),V(0,15.75,0),wood)
  for x=-1,1,2 do part(m,"Rail",V(.25,2,8),V(x*3.8,17,0),green) end
  part(m,"RearRail",V(8,2,.25),V(0,17,3.8),green);ladder(m,0,-4.4,16)
 elseif id=="Chest" or id=="LargeChest" then
  local w=id=="LargeChest" and 6 or 4
  part(m,"ChestBody",V(w,2.4,3),V(0,1.2,0),wood);part(m,"Lid",V(w+.12,.35,3.1),V(0,2.57,0),green)
  for x=-1,1,2 do part(m,"Band",V(.2,2.8,3.15),V(x*w*.3,1.4,0),metal) end
  part(m,"Latch",V(.5,.65,.2),V(0,2,-1.6),amber)
 elseif id=="Torch" or id=="StandingLamp" or id=="CampMarker" or id=="TrailBeacon" then
  local h=id=="StandingLamp" and 6 or 4
  part(m,"Post",V(.35,h,.35),V(0,h/2,0),wood)
  if id=="CampMarker" then part(m,"Flag",V(2,1.2,.1),V(.8,h-.8,0),green)
  else local glow=part(m,"FlameFacet",V(.7,1,.7),V(0,h,0),amber,"WedgePart");light(glow,id=="StandingLamp" and 24 or 16) end
 elseif id=="RainCollector" then
  legs(m,5,5,3)
  part(m,"Basin",V(4.5,.4,4.5),V(0,2.8,0),metal)
  for _,p in ipairs({{V(4.5,.6,.15),V(0,3.3,2.2)},{V(4.5,.6,.15),V(0,3.3,-2.2)},{V(.15,.6,4.5),V(2.2,3.3,0)},{V(.15,.6,4.5),V(-2.2,3.3,0)}}) do part(m,"BasinRim",p[1],p[2],green) end
  local water=part(m,"StoredWater",V(4.1,.05,4.1),V(0,3.06,0),Color3.fromRGB(86,147,170));water.Transparency=.5;water.CanCollide=false
 elseif id=="WaterFilter" then
  part(m,"FilterBase",V(4,.5,4),V(0,.25,0),stone)
  part(m,"FilterTank",V(2.6,3,2.6),V(0,2,0),green)
  part(m,"CoalCartridge",V(2,1,2),V(0,4,0),metal)
  part(m,"Tap",V(.3,.3,1),V(0,1.4,-1.7),amber)
 elseif id=="Bedroll" then
  part(m,"Mattress",V(3,.4,6),V(0,.2,0),green)
  part(m,"Pillow",V(2.8,.5,1.2),V(0,.45,2.2),Color3.fromRGB(206,199,164))
  part(m,"BlanketStripe",V(3.05,.08,.4),V(0,.44,-1.8),amber)
 elseif id=="SpikeTrap" then
  part(m,"TrapBase",V(5,.25,5),V(0,.125,0),wood)
  for x=-1,1 do for z=-1,1 do part(m,"Spike",V(.35,.9,.35),V(x*1.5,.7,z*1.5),metal,"WedgePart") end end
 elseif id=="Campfire" then
  for i=1,8 do local a=i*math.pi/4;part(m,"FireStone",V(.7,.6,.7),V(math.cos(a)*1.6,.3,math.sin(a)*1.6),stone) end
  part(m,"Log",V(2.5,.4,.5),V(0,.3,0),wood)
  local flame=part(m,"FlameFacet",V(.7,1.5,.7),V(0,1,0),amber,"WedgePart");light(flame,12);flame.CanCollide=false
 elseif id=="Furnace" or id=="Oven" or id=="Stove" then
  local h=id=="Stove" and 3 or 4
  part(m,"StoneBody",V(4,h,3.5),V(0,h/2,0),stone)
  part(m,"Firebox",V(2,1.4,.1),V(0,1.4,-1.8),metal)
  part(m,"IronTop",V(4.1,.2,3.6),V(0,h+.1,0),metal)
  if id=="Furnace" then part(m,"Chimney",V(1,2,1),V(1,h+1,1),stone)
  elseif id=="Stove" then for x=-1,1,2 do local p=part(m,"Burner",V(1.1,.1,1.1),V(x,h+.25,0),metal);p.Shape=Enum.PartType.Cylinder end
  else part(m,"OvenHandle",V(2,.2,.25),V(0,2.5,-1.98),amber) end
 else
  -- Specialist tables keep a shared expedition frame and distinct working surfaces.
  legs(m,5,3.5,3)
  part(m,"TableTop",V(5,.35,3.5),V(0,3.15,0),wood)
  if id=="Loom" then
   for x=-1,1,2 do part(m,"LoomPost",V(.25,4,.25),V(x*2,4.8,.8),wood) end
   part(m,"LoomBeam",V(4.25,.25,.25),V(0,6.7,.8),wood)
   for x=-4,4 do part(m,"Thread",V(.045,3,.045),V(x*.4,4.9,.8),Color3.fromRGB(206,199,164)) end
   part(m,"WovenCloth",V(3.5,1.3,.1),V(0,3.9,.8),green)
  elseif id=="Anvil" then
   part(m,"AnvilFoot",V(2.2,.3,1.4),V(0,3.5,0),metal);part(m,"AnvilWaist",V(1,.6,1),V(0,3.95,0),metal);part(m,"AnvilFace",V(2.8,.3,1.5),V(0,4.4,0),metal)
  elseif id=="MedicineTable" then
   for x=-1,1 do local bottle=part(m,"HerbBottle",V(.55,1,.55),V(x,3.85,.4),x==0 and amber or green);bottle.Transparency=.2 end
  elseif id=="SurveyDesk" then
   part(m,"Map",V(3.7,.03,2.1),V(0,3.35,0),Color3.fromRGB(206,199,164))
   part(m,"SurveyCompass",V(.8,.2,.8),V(1.5,3.48,-.8),amber)
  elseif id=="EnchantingTable" then
   local crystal=part(m,"EnchantCrystal",V(.8,1.5,.8),V(0,4.1,0),Color3.fromRGB(145,199,203),"WedgePart");light(crystal,8)
  elseif id=="RepairBench" then
   part(m,"Vise",V(1.1,.8,1),V(1.5,3.7,0),metal);part(m,"ToolRoll",V(2,.2,1.3),V(-1,3.4,0),green)
  else part(m,"WorkTools",V(1.2,.2,.3),V(.5,3.42,0),metal) end
 end
 m:SetAttribute("AuthoredGroundY",0)
 return m
end
return Art
