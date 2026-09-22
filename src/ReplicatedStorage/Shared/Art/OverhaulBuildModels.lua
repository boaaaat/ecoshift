-- Expedition constructions, authored with their base on y=0.
local Catalog=require(script.Parent.Parent.OverhaulCatalog)
local LightModels=require(script.Parent.LightModels)
local Lights=require(script.Parent.Parent.LightConfig).Definitions
local Art={}
local V,CF,A=Vector3.new,CFrame.new,CFrame.Angles
local wood=Color3.fromRGB(121,91,58)
local endgrain=Color3.fromRGB(158,124,80)
local green=Color3.fromRGB(78,103,81)
local metal=Color3.fromRGB(57,66,65)
local stone=Color3.fromRGB(115,119,107)
local pale=Color3.fromRGB(145,146,128)
local brass=Color3.fromRGB(185,145,76)
local canvas=Color3.fromRGB(206,199,164)
local dark=Color3.fromRGB(35,40,38)
local amber=Color3.fromRGB(233,157,63)
local optionalDetail={ForgedRivet=true,TimberCheck=true,WornTimberEdge=true,PegEnd=true,QuiltSeam=true,StitchedEdge=true,MapContour=true,GaugeTick=true,BracePin=true}
local function part(m,name,size,pos,color,class,decorative,material)
 local p=Instance.new(class or "Part");p.Name=name;p.Size=size;p.CFrame=typeof(pos)=="CFrame" and pos or CF(pos)
 p.Color=color or wood
 p.Material=material or ((p.Color==wood or p.Color==endgrain or p.Color==green) and Enum.Material.Wood
  or (p.Color==metal or p.Color==brass) and Enum.Material.Metal or Enum.Material.SmoothPlastic)
 p.Anchored=true
 p.CanCollide=not decorative;p.CanTouch=not decorative;p.CanQuery=not decorative
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=m
 if decorative and optionalDetail[name] then p:SetAttribute("ArtDetail",true) end
 return p
end
local function detail(m,name,size,pos,color,material,class)
 return part(m,name,size,pos,color,class,true,material)
end
local function beam(m,name,from,to,width,color)
 return detail(m,name,V(width,(to-from).Magnitude,width),CFrame.lookAt((from+to)/2,to)*A(math.pi/2,0,0),color)
end
-- Roblox cylinders use their local X axis; callers specify an upright cylinder.
local function cylinder(m,name,radius,height,pos,color,material)
 local cf=typeof(pos)=="CFrame" and pos or CF(pos)
 local p=detail(m,name,V(height,radius*2,radius*2),cf*A(0,0,math.pi/2),color,material)
 p.Shape=Enum.PartType.Cylinder;return p
end
local function light(p,range,color)
 p.Material=Enum.Material.Neon;local l=Instance.new("PointLight");l.Color=color or amber;l.Range=range;l.Brightness=1.1;l.Shadows=true;l.Parent=p
end
local function legs(m,width,depth,height)
 for x=-1,1,2 do for z=-1,1,2 do
  local px,pz=x*(width/2-.2),z*(depth/2-.2)
  part(m,"TimberLeg",V(.3,height,.3),V(px,height/2,pz),wood,nil,false,Enum.Material.Wood)
  detail(m,"IronFoot",V(.34,.32,.34),V(px,.17,pz),metal,Enum.Material.Metal)
 end end
end
local function ladder(m,x,z,height)
 local truss=part(m,"ClimbableLadder",V(2,height,1),V(x,height/2,z),metal,"TrussPart");truss:SetAttribute("Climbable",true)
 for side=-1,1,2 do detail(m,"LadderRail",V(.18,height,.25),V(x+side*.88,height/2,z-.39),wood,Enum.Material.Wood) end
end
local function tabletop(m)
 legs(m,5,3.5,3)
 part(m,"TableTop",V(5,.35,3.5),V(0,3.15,0),wood,nil,false,Enum.Material.Wood)
 for z=-1,1,2 do detail(m,"Apron",V(4.6,.45,.14),V(0,2.8,z*1.52),green) end
 detail(m,"LowerShelf",V(4.4,.16,2.9),V(0,.8,0),wood,Enum.Material.Wood)
 for x=-1,1,2 do detail(m,"TopEndCap",V(.2,.38,3.5),V(x*2.38,3.15,0),endgrain,Enum.Material.Wood) end
 for i=1,4 do
  detail(m,"InsetTablePlank",V(.88,.035,3.36),V(-2.2+i*.88,3.342,0),wood:Lerp(endgrain,i%2*.15),Enum.Material.Wood)
 end
 for side=-1,1,2 do
  beam(m,"TableKneeBrace",V(side*2.1,2.1,1.45),V(side*1.35,2.96,1.45),.18,endgrain)
  for z=-1,1,2 do
   cylinder(m,"PegEnd",.055,.025,CF(side*2.15,2.8,z*1.605)*A(math.pi/2,0,0),brass,Enum.Material.Metal)
  end
 end
end
local function hammer(m,cf)
 detail(m,"HammerShaft",V(.13,.13,1.1),cf,wood,Enum.Material.Wood)
 detail(m,"HammerHead",V(.65,.27,.28),cf*CF(0,.05,.43),metal,Enum.Material.Metal)
end
local function bottle(m,x,z,color,height)
 cylinder(m,"ApothecaryBottle",.24,height,V(x,3.37+height/2,z),color)
 cylinder(m,"BottleNeck",.12,.2,V(x,3.45+height,z),color)
 cylinder(m,"Cork",.13,.12,V(x,3.58+height,z),wood)
 detail(m,"BottleLabel",V(.29,.25,.025),V(x,3.37+height/2,z-.243),canvas)
end
function Art.Create(id)
 if not Catalog.Placeables[id] then return nil end
 local m=Instance.new("Model");m.Name=id;m:SetAttribute("BuildType",id);m:SetAttribute("ArtVersion",5)
 local root=detail(m,"GroundAnchor",V(.1,.1,.1),V(0,.05,0),wood);root.Transparency=1;m.PrimaryPart=root
 if Lights[id] then LightModels.Build(m,id)
 elseif id=="Floor" or id=="Roof" then
  for i=0,7 do part(m,"Plank",V(.96,.5,8),V(-3.5+i,.25,0),i%3==0 and endgrain or wood,nil,false,Enum.Material.Wood) end
  for z=-1,1,2 do detail(m,"PanelBinding",V(7.94,.04,.17),V(0,.48,z*3.7),id=="Roof" and green or metal) end
 elseif id=="Wall" then
  for i=0,7 do part(m,"WallPlank",V(.98,8,.35),V(-3.5+i,4,0),i%3==0 and endgrain or wood,nil,false,Enum.Material.Wood) end
  for _,y in ipairs({2,6}) do part(m,"Brace",V(8,.3,.65),V(0,y,0),green) end
  beam(m,"DiagonalTimber",V(-3.55,2.1,-.25),V(3.55,5.9,-.25),.18,wood)
  for x=-1,1,2 do for _,y in ipairs({2,6}) do detail(m,"BracePin",V(.15,.15,.04),V(x*3.6,y,-.34),metal) end end
 elseif id=="Door" or id=="Gate" then
  local w=id=="Door" and 4 or 8;m:SetAttribute("DoorWidth",w)
  local postX=id=="Door" and 2.175 or 4
  for x=-1,1,2 do part(m,"DoorPost",V(.35,8.3,.7),V(x*postX,4.15,0),green,nil,false,Enum.Material.Wood) end
  part(m,"Lintel",V(8,.35,.7),V(0,8.15,0),green,nil,false,Enum.Material.Wood)
  if id=="Door" then
   for x=-1,1,2 do
    part(m,"DoorWallPanel",V(1.65,7.8,.4),V(x*3.175,4,0),wood,nil,false,Enum.Material.Wood)
    detail(m,"DoorWallBrace",V(1.5,.24,.08),V(x*3.175,2,-.25),endgrain)
    detail(m,"DoorWallBrace",V(1.5,.24,.08),V(x*3.175,6,-.25),endgrain)
   end
  end
  local leaf=Instance.new("Model");leaf.Name="DoorLeaf";leaf.Parent=m
  -- UtilityBuildService expects this exact closed-leaf pivot and width.
  local face=part(leaf,"DoorPanel",V(w-.15,7.9,.4),V(0,4,0),wood,nil,false,Enum.Material.Wood);leaf.PrimaryPart=face
  for i=1,w-1 do detail(leaf,"PlankSeam",V(.028,7.65,.012),V(-w/2+i,4,-.207),dark) end
  for _,y in ipairs({1.2,6.8}) do detail(leaf,"HingeStrap",V(w-.4,.22,.09),V(0,y,-.25),metal,Enum.Material.Metal) end
  beam(leaf,"DoorDiagonal",V(-w/2+.35,1.4,-.26),V(w/2-.35,6.6,-.26),.18,endgrain)
  detail(leaf,"LatchPlate",V(.42,.8,.05),V(w/2-.5,4,-.24),metal)
  detail(leaf,"Handle",V(.16,.6,.18),V(w/2-.5,4,-.32),brass,Enum.Material.Metal)
 elseif id=="Ramp" then
  part(m,"Ramp",V(8,8,8),V(0,4,0),wood,"WedgePart",false,Enum.Material.Wood)
  for i=1,7 do detail(m,"RampTread",V(7.8,.045,.15),CF(0,i+.025,-4+i)*A(math.pi/4,0,0),endgrain) end
 elseif id=="Stairs" then
  for i=1,8 do
   part(m,"Step",V(8,i,1),V(0,i/2,-4+i-.5),wood,nil,false,Enum.Material.Wood)
   detail(m,"TreadNosing",V(7.95,.07,.13),V(0,i-.04,-4+i-.92),endgrain)
  end
 elseif id=="Ladder" then ladder(m,0,0,8)
 elseif id=="Watchtower" then
  legs(m,8,8,15.5)
  part(m,"Platform",V(8,.5,8),V(0,15.75,0),wood,nil,false,Enum.Material.Wood)
  for x=-1,1,2 do
   part(m,"Rail",V(.25,2,8),V(x*3.8,17,0),green)
   beam(m,"TowerBrace",V(x*3.8,.6,3.8),V(x*3.8,14.8,-3.8),.25,wood)
   detail(m,"RailCap",V(.29,.14,8),V(x*3.8,17.9,0),endgrain)
  end
  part(m,"RearRail",V(8,2,.25),V(0,17,3.8),green)
  beam(m,"RearTowerBrace",V(-3.8,.6,3.8),V(3.8,14.8,3.8),.25,wood)
  ladder(m,0,-4.4,16)
 elseif id=="Chest" or id=="LargeChest" then
  local w=id=="LargeChest" and 6 or 4
  part(m,"ChestBody",V(w,2.4,3),V(0,1.2,0),wood,nil,false,Enum.Material.Wood)
  part(m,"Lid",V(w+.12,.35,3.1),V(0,2.57,0),green)
  for x=-1,1,2 do
   -- Separate straps leave the timber visible instead of using a solid band block.
   for z=-1,1,2 do detail(m,"ChestBand",V(.2,2.7,.075),V(x*w*.3,1.4,z*1.53),metal,Enum.Material.Metal) end
   detail(m,"LidBand",V(.2,.06,3.1),V(x*w*.3,2.76,0),metal,Enum.Material.Metal)
   detail(m,"CarryGrip",V(.09,.18,.9),V(x*(w/2+.04),1.4,0),brass)
  end
  for _,y in ipairs({.8,1.6}) do detail(m,"ChestPlankSeam",V(w-.08,.035,.02),V(0,y,-1.51),dark) end
  detail(m,"Latch",V(.5,.65,.2),V(0,2,-1.6),brass,Enum.Material.Metal)
  detail(m,"Keyhole",V(.075,.17,.02),V(0,2,-1.71),dark)
 elseif id=="CampMarker" then
  part(m,"Post",V(.35,4,.35),V(0,2,0),wood,nil,false,Enum.Material.Wood)
  part(m,"Flag",V(2,1.2,.1),V(.8,3.2,0),green,nil,false,Enum.Material.Fabric)
  detail(m,"FlagHem",V(2,.11,.12),V(.8,2.68,0),canvas)
  detail(m,"ExpeditionMark",V(.45,.45,.12),CF(.8,3.2,0)*A(0,0,math.pi/4),brass)
  for _,y in ipairs({2.65,3.7}) do detail(m,"FlagBinding",V(.4,.11,.4),V(0,y,0),canvas) end
 elseif id=="RainCollector" then
  legs(m,5,5,3)
  part(m,"Basin",V(4.5,.4,4.5),V(0,2.8,0),metal,nil,false,Enum.Material.Metal)
  for s=-1,1,2 do
   part(m,"BasinRim",V(4.5,.6,.15),V(0,3.3,s*2.2),green)
   part(m,"BasinRim",V(.15,.6,4.5),V(s*2.2,3.3,0),green)
  end
  local water=detail(m,"StoredWater",V(4.1,.05,4.1),V(0,3.06,0),Color3.fromRGB(86,147,170),Enum.Material.Glass);water.Transparency=.35
  cylinder(m,"StorageBarrel",1.03,1.9,V(0,1.05,0),wood,Enum.Material.Wood)
  for _,y in ipairs({.3,1.8}) do cylinder(m,"BarrelHoop",1.07,.12,V(0,y,0),metal,Enum.Material.Metal) end
  detail(m,"DrainPipe",V(.24,.75,.24),V(0,2.2,0),brass)
  detail(m,"Spigot",V(.22,.22,.5),V(0,.65,-1.14),brass)
 elseif id=="WaterFilter" then
  part(m,"FilterBase",V(4,.5,4),V(0,.25,0),stone,nil,false,Enum.Material.Slate)
  part(m,"FilterTank",V(2.6,3,2.6),V(0,2,0),green)
  part(m,"CoalCartridge",V(2,1,2),V(0,4,0),metal,nil,false,Enum.Material.Metal)
  for _,y in ipairs({.8,3.2}) do detail(m,"TankCollar",V(2.7,.16,2.7),V(0,y,0),brass) end
  detail(m,"InspectionWindow",V(.5,1.6,.04),V(.6,2,-1.32),dark)
  detail(m,"WaterGauge",V(.2,1.2,.045),V(.6,1.8,-1.35),Color3.fromRGB(86,147,170))
  for i=0,2 do detail(m,"GaugeTick",V(.19,.045,.05),V(.98,1.4+i*.45,-1.34),canvas) end
  part(m,"Tap",V(.3,.3,1),V(0,1.4,-1.7),brass,nil,false,Enum.Material.Metal)
  detail(m,"TapLever",V(.7,.12,.14),V(0,1.66,-1.8),metal)
  cylinder(m,"CartridgeCap",.65,.08,V(0,4.55,0),brass)
 elseif id=="Bedroll" then
  part(m,"Mattress",V(3,.4,6),V(0,.2,0),green,nil,false,Enum.Material.Fabric)
  local pillow=part(m,"Pillow",V(2.8,.5,1.2),V(0,.45,2.2),canvas,nil,false,Enum.Material.Fabric);pillow.Shape=Enum.PartType.Ball
  detail(m,"BlanketFold",V(2.9,.15,.8),V(0,.45,.9),green,Enum.Material.Fabric)
  for x=-1,1,2 do detail(m,"StitchedEdge",V(.045,.03,5.7),V(x*1.39,.416,0),canvas) end
  for _,z in ipairs({-2.2,-1.9}) do detail(m,"BlanketStripe",V(2.95,.03,.13),V(0,.422,z),canvas) end
  for i=0,3 do detail(m,"QuiltSeam",V(2.78,.022,.026),V(0,.415,-1.45+i*.65),green:Lerp(dark,.25),Enum.Material.Fabric) end
  for side=-1,1,2 do
   detail(m,"BedrollStrap",V(.18,.065,1.12),V(side*.97,.6,2.2),wood,Enum.Material.Fabric)
   detail(m,"StrapBuckle",V(.24,.04,.2),V(side*.97,.652,1.84),brass,Enum.Material.Metal)
  end
 elseif id=="SpikeTrap" then
  part(m,"TrapBase",V(5,.25,5),V(0,.125,0),wood,nil,false,Enum.Material.Wood)
  for x=-1,1 do for z=-1,1 do part(m,"Spike",V(.35,.9,.35),CF(x*1.5,.7,z*1.5)*A(0,(x+z)*math.pi/2,0),metal,"WedgePart",false,Enum.Material.Metal) end end
  for z=-1,1,2 do detail(m,"TrapBinding",V(4.9,.08,.22),V(0,.26,z*2.1),metal) end
  detail(m,"PressurePlate",V(1.8,.09,1.8),V(0,.29,0),green)
 elseif id=="Campfire" then
  for i=1,8 do
   local a=i*math.pi/4
   local rock=part(m,"FireStone",V(.84,.53+(i%3)*.065,.73),CF(math.cos(a)*1.6,.3,math.sin(a)*1.6)*A(.1,a+.3,.12),i%2==0 and stone or pale,nil,false,Enum.Material.Slate)
   rock.Shape=Enum.PartType.Ball
  end
  for i=-1,1,2 do part(m,"Log",V(2.5,.4,.5),CF(0,.3,0)*A(0,i*.55,0),wood,nil,false,Enum.Material.Wood) end
  detail(m,"CoalBed",V(1.05,.12,1.05),V(0,.53,0),Color3.fromRGB(171,75,38),Enum.Material.Neon)
  local flame=detail(m,"FlameFacet",V(.7,1.5,.7),V(0,1,0),amber,nil,"WedgePart");light(flame,12)
  detail(m,"FlameTip",V(.4,.8,.45),CF(.24,.86,-.1)*A(0,math.pi,-.2),canvas,Enum.Material.Neon,"WedgePart")
 elseif id=="Furnace" or id=="Oven" or id=="Stove" then
  local h=id=="Stove" and 3 or 4
  part(m,"StoneBody",V(4,h,3.5),V(0,h/2,0),id=="Stove" and green or stone,nil,false,id=="Stove" and Enum.Material.Metal or Enum.Material.Slate)
  part(m,"IronTop",V(4.1,.2,3.6),V(0,h+.1,0),metal,nil,false,Enum.Material.Metal)
  detail(m,"Firebox",V(2,1.4,.08),V(0,1.4,-1.78),dark)
  detail(m,"EmberSlit",V(1.7,.2,.03),V(0,1,-1.83),amber,Enum.Material.Neon)
  for x=-1,1 do detail(m,"FireGrate",V(.1,1.2,.09),V(x*.78,1.4,-1.88),metal,Enum.Material.Metal) end
  if id=="Furnace" then
   part(m,"Chimney",V(1,2,1),V(1,h+1,1),stone,nil,false,Enum.Material.Slate)
   detail(m,"FlueCap",V(1.12,.16,1.12),V(1,5.94,1),metal)
   for _,y in ipairs({.4,2.4,3.4}) do detail(m,"MasonryCourse",V(4.03,.045,3.53),V(0,y,0),dark) end
   for row=0,2 do for side=-1,1,2 do
    detail(m,"HearthFacingStone",V(.61,.72,.18),CF(side*1.64,.55+row*1.16,-1.81)*A(0,0,side*.025*(row-1)),stone:Lerp(pale,.12+row*.11),Enum.Material.Slate)
    detail(m,"SideStoneJoint",V(.025,.82,.07),V(side*2.015,.98+row*1.03,(row%2==0 and .4 or -.55)),dark,Enum.Material.Slate)
   end end
   detail(m,"HearthLintel",V(2.5,.3,.15),V(0,2.25,-1.8),pale,Enum.Material.Slate)
  elseif id=="Stove" then
   for x=-1,1,2 do
    cylinder(m,"Burner",.57,.08,V(x,3.25,0),dark,Enum.Material.Metal)
    detail(m,"BurnerGrate",V(1.3,.07,.13),V(x,3.32,0),metal)
    cylinder(m,"StoveKnob",.16,.09,CF(x,2.55,-1.81)*A(math.pi/2,0,0),brass)
   end
   detail(m,"FrontTrim",V(3.8,.12,.08),V(0,2.9,-1.8),brass)
  else
   detail(m,"OvenDoor",V(2.5,2.2,.08),V(0,2,-1.84),metal,Enum.Material.Metal)
   detail(m,"OvenWindow",V(1.8,.85,.05),V(0,1.75,-1.9),dark)
   part(m,"OvenHandle",V(2,.2,.25),V(0,2.5,-1.98),brass,nil,false,Enum.Material.Metal)
   for x=-1,1,2 do detail(m,"OvenPilaster",V(.4,3.65,.1),V(x*1.7,2,-1.78),pale,Enum.Material.Slate) end
  end
 else
  tabletop(m)
  if id=="Loom" then
   for x=-1,1,2 do part(m,"LoomPost",V(.25,4,.25),V(x*2,4.8,.8),wood,nil,false,Enum.Material.Wood) end
   part(m,"LoomBeam",V(4.25,.25,.25),V(0,6.7,.8),wood,nil,false,Enum.Material.Wood)
   for x=-4,4 do detail(m,"WarpThread",V(.035,3,.035),V(x*.4,4.9,.8),canvas) end
   part(m,"WovenCloth",V(3.5,1.3,.1),V(0,3.9,.8),green,nil,false,Enum.Material.Fabric)
   for _,y in ipairs({3.5,3.7,4.25}) do detail(m,"WovenStripe",V(3.45,.075,.12),V(0,y,.8),canvas) end
   cylinder(m,"ClothRoll",.21,3.5,CF(0,3.53,.5)*A(0,0,math.pi/2),green,Enum.Material.Fabric)
   detail(m,"Shuttle",V(1.1,.12,.22),CF(.8,3.4,-.6)*A(0,-.3,0),endgrain)
  elseif id=="Anvil" then
   part(m,"AnvilFoot",V(2.2,.3,1.4),V(0,3.5,0),metal,nil,false,Enum.Material.Metal)
   part(m,"AnvilWaist",V(1,.6,1),V(0,3.95,0),metal,nil,false,Enum.Material.Metal)
   part(m,"AnvilFace",V(2.8,.3,1.5),V(0,4.4,0),metal,nil,false,Enum.Material.Metal)
   detail(m,"AnvilHorn",V(.8,.35,.9),CF(-1.75,4.33,0)*A(0,-math.pi/2,0),metal,Enum.Material.Metal,"WedgePart")
   detail(m,"PolishedFace",V(2.3,.025,1.3),V(.1,4.563,0),pale,Enum.Material.Metal)
   hammer(m,CF(1.65,3.48,-.6)*A(0,.3,0))
  elseif id=="MedicineTable" then
   detail(m,"LinenRunner",V(3.2,.035,2.8),V(-.5,3.343,0),canvas,Enum.Material.Fabric)
   for x=-1,1 do bottle(m,x,.8,x==0 and amber or green,.55+(x+1)*.15) end
   cylinder(m,"Mortar",.44,.35,V(-.8,3.53,-.65),stone,Enum.Material.Slate)
   cylinder(m,"HerbalPaste",.31,.025,V(-.8,3.717,-.65),green)
   beam(m,"Pestle",V(-.85,3.73,-.65),V(-.48,4.1,-.65),.15,pale)
  elseif id=="SurveyDesk" then
   detail(m,"Map",V(3.7,.03,2.1),V(0,3.35,0),canvas)
   for x=-1,1,2 do cylinder(m,"MapRoll",.1,2.1,CF(x*1.8,3.43,0)*A(math.pi/2,0,0),canvas) end
   for i=0,2 do detail(m,"MapContour",V(1.3-i*.25,.013,.045),CF(-.4,3.372,-.5+i*.35)*A(0,i*.45,0),green) end
   cylinder(m,"SurveyCompass",.4,.14,V(1.45,3.45,-.65),brass,Enum.Material.Metal)
   detail(m,"CompassNeedle",V(.08,.025,.48),CF(1.45,3.54,-.65)*A(0,-.5,0),dark)
   detail(m,"FieldJournal",V(.85,.18,1.1),CF(-1.6,3.43,1)*A(0,.15,0),green)
  elseif id=="EnchantingTable" then
   detail(m,"InlaidSurface",V(4.3,.05,2.9),V(0,3.35,0),dark)
   cylinder(m,"CrystalSocket",.68,.22,V(0,3.51,0),brass,Enum.Material.Metal)
   local crystal=detail(m,"EnchantCrystal",V(.8,1.5,.8),CF(0,4.1,0)*A(0,math.pi/4,0),Color3.fromRGB(145,199,203),nil,"WedgePart");light(crystal,8,crystal.Color)
   for x=-1,1,2 do
    beam(m,"CrystalCradle",V(x*.55,3.6,0),V(x*.75,4.1,0),.12,brass)
    detail(m,"OpenBookPage",V(.75,.08,1),CF(x*.37,3.45,-1.05)*A(0,0,x*.12),canvas)
   end
  elseif id=="RepairBench" then
   part(m,"Vise",V(1.1,.8,1),V(1.5,3.7,0),metal,nil,false,Enum.Material.Metal)
   for z=-1,1,2 do detail(m,"ViseJaw",V(1.2,.14,.19),V(1.5,4.12,z*.45),pale,Enum.Material.Metal) end
   beam(m,"ViseHandle",V(1.5,3.5,-.73),V(1.5,4,-.73),.11,brass)
   detail(m,"ToolRoll",V(2,.2,1.3),V(-1,3.4,0),green,Enum.Material.Fabric)
   for i=0,2 do detail(m,"RepairTool",V(.12,.1,.85),V(-1.6+i*.5,3.56,0),metal) end
   hammer(m,CF(0,3.45,1)*A(0,math.pi/2,0))
  else
   detail(m,"WorkMat",V(2.5,.04,2.1),V(-.5,3.35,0),green)
   hammer(m,CF(.7,3.5,-.4)*A(0,-.4,0))
   detail(m,"SawBlade",V(.4,.045,1.4),CF(-.7,3.4,0)*A(0,.4,0),pale,Enum.Material.Metal)
   detail(m,"SawGrip",V(.48,.15,.35),CF(-.4,3.44,.68)*A(0,.4,0),endgrain)
   for i=0,1 do detail(m,"TimberStock",V(3.4,.2,.45),V(-.1,1+i*.23,.7),endgrain,Enum.Material.Wood) end
  end
 end
 -- Add joinery to the authored pieces. Details stay on the same parent as their
 -- source, so door hardware follows DoorLeaf's existing pivot when it opens.
 if not Lights[id] then
  local budget=28
  local hardwareNames={HingeStrap=true,ChestBand=true,LidBand=true,Apron=true,PanelBinding=true,
   Brace=true,TopEndCap=true,LatchPlate=true,IronFoot=true,TrapBinding=true}
  local woodNames={Plank=true,WallPlank=true,DoorPanel=true,ChestBody=true,TimberLeg=true,Post=true,LoomPost=true}
  for _,p in ipairs(m:GetDescendants()) do
   if p:IsA("BasePart") and p.Transparency==0 and budget>0 then
    if hardwareNames[p.Name] then
     local vertical=p.Size.Y>p.Size.X
     for sign=-1,1,2 do
      if budget<=0 then break end
      local position=p.CFrame*CF(vertical and 0 or sign*p.Size.X*.36,vertical and sign*p.Size.Y*.34 or 0,-p.Size.Z/2-.025)
      local stud=detail(p.Parent,"ForgedRivet",V(.105,.105,.055),position,brass:Lerp(metal,.5),Enum.Material.Metal)
      stud.Shape=Enum.PartType.Ball;budget-=1
     end
    elseif woodNames[p.Name] and budget>1 then
     -- Shallow dark checks and a raised worn edge read at normal third-person distance.
     local tall=p.Size.Y>p.Size.X
     detail(p.Parent,"TimberCheck",V(tall and .024 or math.min(p.Size.X*.35,.8),tall and math.min(p.Size.Y*.23,1.1) or .022,.012),
      p.CFrame*CF(p.Size.X*.19,p.Size.Y*.12,-p.Size.Z/2-.009),wood:Lerp(dark,.47),Enum.Material.Wood)
     local edgeSize=tall and V(.04,p.Size.Y*.85,.025) or V(p.Size.X*.8,.035,.025)
     detail(p.Parent,"WornTimberEdge",edgeSize,p.CFrame*CF(tall and -p.Size.X*.44 or 0,tall and 0 or p.Size.Y*.4,-p.Size.Z/2-.012),endgrain:Lerp(wood,.3),Enum.Material.Wood)
     budget-=2
    end
   end
  end
 end
 m:SetAttribute("AuthoredGroundY",0)
 return m
end
return Art
