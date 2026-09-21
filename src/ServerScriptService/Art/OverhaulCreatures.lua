-- Original expedition fauna. Visual joints follow the server-owned movement rig.
-- Coordinates face -Z; grounded feet sit at -3 before the existing role scale.
local Catalog = require(game.ReplicatedStorage.Shared.OverhaulBiomes)
local Art = {}
local V, RGB, M = Vector3.new, Color3.fromRGB, Enum.Material
local optionalDetail={HoofGroove=true,Toe=true,FeatherShaft=true,FlankStripe=true,CarapaceGrowthBand=true,CapSpot=true}

-- Explicit silhouettes keep a new species from silently becoming a generic quadruped.
local species = {
 Wolf={"Canine"}, Boar={"Boar"}, BarkSpider={"Spider","Bark"}, Deer={"Grazer","Antlers"},
 Scorpion={"Scorpion"}, SandSerpent={"Serpent","Crest"}, DuneBeetle={"Beetle","Horn"}, DesertFox={"Canine","Fox"},
 Leech={"Serpent","Leech"}, BogToad={"Toad"}, MarshSnake={"Serpent"}, Heron={"Bird","Wader"},
 FrostWolf={"Canine","Frost"}, IceWraith={"Wraith"}, IceBear={"Bear"}, SnowHare={"Hare"},
 AshHound={"Canine","Ember"}, LavaGolem={"Guardian","Lava"}, CinderCrab={"Crab","Ember"}, AshLizard={"Lizard"},
 CrystalStalker={"Canine","Crystal"}, PrismGuard={"Guardian","Crystal"}, ShardMite={"Mite","Crystal"}, CrystalGrazer={"Grazer","Crystal"},
 AuroraStag={"Grazer","Antlers"}, SnowOwl={"Bird","Owl"}, SpringBear={"Bear","Moss"}, ValleyHare={"Hare"},
 RockCrawler={"Armored","Rock"}, StarBeetle={"Beetle","Star"}, DustMite={"Mite"}, CraterLizard={"Lizard","Crest"},
 TideCrab={"Crab"}, ReefEel={"Serpent","Eel"}, Shellback={"Turtle"}, Sandpiper={"Bird","Wader"},
 GaleRaptor={"Raptor"}, ThunderRam={"Grazer","Ram"}, CliffSpider={"Spider"}, MountainGoat={"Grazer","Goat"},
 SporeMite={"Mite","Spore"}, RootGuardian={"Guardian","Root"}, CapBeetle={"Beetle","Mushroom"}, MossSnail={"Snail"},
 Rustback={"Armored","Metal"}, Burrower={"Serpent","Burrower"}, ThornJackal={"Canine","Thorn"}, RockHare={"Hare"},
 BranchCat={"Canine","Cat"}, GiantMoth={"Moth"}, VineSnake={"Serpent","Vine"}, CanopyDeer={"Grazer","Antlers"},
 LanternEel={"Serpent","Lantern"}, ArchiveGuard={"Guardian","Archive"}, CanalCrab={"Crab","Archive"}, Silverfish={"Fish"},
 EchoHunter={"Canine","Echo"}, CaveGrazer={"Grazer","Cave"}, CaveBat={"Bat"}, Stoneback={"Armored","Rock"},
 MoonCrawler={"Armored","Moon"}, RiftHopper={"Toad","Rift"}, MoonMite={"Mite","Moon"}, DustGrazer={"Grazer","Moon"},
}

-- Body, light underside, hard surface, accent: painted planes and sparse glow.
local palettes = {
 Forest={RGB(103,108,88),RGB(195,185,150),RGB(73,59,43),RGB(151,170,89)},
 Desert={RGB(183,133,71),RGB(236,207,153),RGB(105,72,45),RGB(226,169,62)},
 Swamp={RGB(70,102,74),RGB(164,178,112),RGB(49,64,47),RGB(186,204,102)},
 FrozenTundra={RGB(184,205,211),RGB(231,237,222),RGB(91,132,154),RGB(133,222,234)},
 Volcanic={RGB(68,58,61),RGB(127,101,82),RGB(40,39,45),RGB(242,127,49)},
 CrystalWastes={RGB(115,102,155),RGB(196,181,214),RGB(74,63,106),RGB(160,222,231)},
 AuroraVale={RGB(133,159,154),RGB(224,226,200),RGB(77,96,108),RGB(139,221,187)},
 StarfallCrater={RGB(119,106,111),RGB(178,163,144),RGB(68,67,83),RGB(227,172,107)},
 SaltglassCoast={RGB(83,143,145),RGB(225,210,166),RGB(52,89,108),RGB(168,221,200)},
 StormspireHighlands={RGB(127,140,138),RGB(214,209,182),RGB(66,80,91),RGB(190,212,221)},
 MyceliumHollow={RGB(123,117,149),RGB(204,191,158),RGB(73,79,66),RGB(196,165,205)},
 IronrootBadlands={RGB(158,100,68),RGB(207,168,122),RGB(79,67,62),RGB(194,131,73)},
 CanopySea={RGB(75,117,81),RGB(192,183,124),RGB(48,69,48),RGB(181,181,82)},
 SunkenArchive={RGB(86,132,141),RGB(179,199,187),RGB(53,79,91),RGB(122,218,216)},
 UmbralDepths={RGB(88,88,114),RGB(169,166,181),RGB(48,50,68),RGB(134,181,208)},
 ShattermoonExpanse={RGB(157,154,175),RGB(218,214,221),RGB(86,82,112),RGB(174,194,236)},
}

function Art.Create(id)
 local def = Catalog.Creatures[id]
 if not def then return nil end
 local profile = species[id]
 assert(profile, "Missing creature art: " .. id)
 local family, variant = profile[1], profile[2]
 local colors = palettes[def.Biome]
 local body, pale, armor, accent = colors[1], colors[2], colors[3], colors[4]
 if id == "Wolf" then body = RGB(112,119,119) end
 if id == "Boar" then body = RGB(109,78,57) end
 if id == "Deer" or id == "CanopyDeer" then body = RGB(157,112,66) end
 if id == "DesertFox" then body = RGB(206,155,98) end
 if id == "BranchCat" then body = RGB(161,148,74) end
 if id == "Heron" or id == "Sandpiper" then body = RGB(158,177,176) end
 local scale = def.Role == "H" and 1.5 or def.Role == "S" and .55 or def.Role == "N" and .75 or 1
 local model = Instance.new("Model")
 model.Name = id
 local root = Instance.new("Part")
 root.Name = "HumanoidRootPart"
 root.Size = V(3,3,4) * scale
 root.Transparency = 1
 root.CanCollide = true
 root.Parent = model
 model.PrimaryPart = root

 local groups = {}
 local activeGroup
 local furSurface=family=="Canine" or family=="Bear" or family=="Boar" or family=="Hare" or family=="Grazer"
 local function group(key, kind, pivot, phase, side)
  local g = groups[key]
  if not g then
   g = {parts={},kind=kind,pivot=pivot,phase=phase or 0,side=side or 1}
   groups[key] = g
  end
  return g
 end
 local faceNames = {Head=true,Muzzle=true,Nose=true,Eye=true,EyeSocket=true,Ear=true,InnerEar=true,
  Antler=true,AntlerFork=true,AntlerTine=true,HornBase=true,CurledHorn=true,HornTip=true,
  Jaw=true,LowerJaw=true,Beak=true,Brow=true,FacialDisc=true,FaceShadow=true,Visor=true,
  Tusk=true,Mouth=true,MouthRim=true,MouthTooth=true,Lure=true,LureStem=true,HeadCrest=true,LeafFrill=true,NosePlate=true}
 local legNames = {UpperLeg=true,LowerLeg=true,Paw=true,Hoof=true,Foreleg=true,Forepaw=true,
  HindFoot=true,Leg=true,LegTip=true,ClawFoot=true,WebbedFoot=true,Foot=true,Shin=true,Ankle=true,Talon=true,RootToe=true}
 local wingNames = {Wing=true,WingLobe=true,WingMembrane=true,FlightFeather=true,WingEyespot=true,WingEyeCenter=true,WingFinger=true,Forewing=true}
 local function chooseGroup(name, position)
  if activeGroup then return activeGroup end
  local side = position.X < 0 and -1 or 1
  if faceNames[name] then return group("Head","Head",V(0,position.Y,position.Z+.55)) end
  if legNames[name] or name=="Haunch" and family=="Raptor" then
   if family=="Raptor" or family=="Bird" or family=="Bat" or family=="Guardian" then
    local pivot=family=="Raptor" and V(side*.85,-.8,.8)
     or family=="Guardian" and V(side*.85,-.65,0) or V(side*.45,-1.1,.1)
    return group("Leg"..side,"Leg",pivot,side==1 and 0 or math.pi,side)
   end
   local front=position.Z < 0 and -1 or 1
   return group("Leg"..side..":"..front,"Leg",V(side*.85,-.8,front*1.2),(side*front==1) and 0 or math.pi,side)
  end
  if wingNames[name] then return group("Wing"..side,"Wing",V(side*.65,.2,0),0,side) end
  if name=="Tail" or name=="TailTip" or name=="TailFan" or name=="TailFin" or name=="Stinger" then
   return group("Tail","Tail",V(0,-.1,1.65))
  end
  if name=="Arm" or name=="Fist" or name=="Claw" then return group("Arm"..side,"Arm",V(side*1.7,.9,0),side==1 and 0 or math.pi,side) end
  return group("Body","Body",V(0,0,0))
 end

 local function part(name, size, position, color, material, shape, rotation)
  local p = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
  p.Name, p.Size = name, size * scale
  p.CFrame = CFrame.new(position * scale) * (rotation or CFrame.identity)
  p.Color, p.Material = color or body, material or (furSurface and (color==body or color==pale) and M.Fabric or M.SmoothPlastic)
  if shape == "Ball" then p.Shape = Enum.PartType.Ball end
  p.CanCollide, p.CanTouch, p.Massless = false, false, true
  if optionalDetail[name] then p:SetAttribute("ArtDetail",true) end
  p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
  p.Parent = model
  table.insert(chooseGroup(name,position).parts,p)
  return p
 end
 local function link(name, a, b, width, depth, color, material)
  return part(name,V(width,depth,(b-a).Magnitude),(a+b)/2,color,material,nil,CFrame.lookAt(a,b).Rotation)
 end
 local function wedge(name, size, pos, color, rotation, material)
  return part(name,size,pos,color,material,"Wedge",rotation)
 end
 local function eyes(pos, separation, glow)
  for side = -1,1,2 do
   part("EyeSocket",V(.42,.38,.2),pos+V(side*separation,0,.03),armor,nil,"Ball")
   part("Eye",V(.2,.22,.12),pos+V(side*separation,.025,-.1),glow and accent or RGB(231,195,112),glow and M.Neon or M.SmoothPlastic,"Ball")
  end
 end
 local function ears(pos, width, height)
  for side = -1,1,2 do
   wedge("Ear",V(width,height,.55),pos+V(side*.7,0,0),body,CFrame.Angles(0,0,-side*.18))
   wedge("InnerEar",V(width*.55,height*.65,.08),pos+V(side*.7,0,-.29),pale,CFrame.Angles(0,0,-side*.18))
  end
 end
 local function crest(pos, count, color, material)
  for i = 1,count do wedge("DorsalCrest",V(.45,.85+(i%2)*.35,.85),pos+V(0,0,(i-1)*.8),color,nil,material) end
 end
 local function fourLegs(length, width, hoof)
  for side = -1,1,2 do for front = -1,1,2 do
   local z = front*length
   local hip, knee, ankle = V(side*width,-.45,z), V(side*(width+.1),-1.65,z+(front == 1 and .35 or -.15)), V(side*width,-2.65,z)
   activeGroup=group("Leg"..side..":"..front,"Leg",hip,side*front==1 and 0 or math.pi,side)
   link("UpperLeg",hip,knee,.65,.72,body)
   link("LowerLeg",knee,ankle,.38,.43,body)
   part(hoof and "Hoof" or "Paw",V(.64,.4,.9),ankle+V(0,-.15,-.15),hoof and armor or pale)
   for toe=-1,1 do
    part(hoof and "HoofGroove" or "Toe",V(.1,.12,.25),ankle+V(toe*.17,-.22,-.54),armor,nil,"Ball")
   end
   activeGroup=nil
  end end
 end
 local function horns(head, kind)
  for side = -1,1,2 do
   local base = head+V(side*.65,.7,0)
   if kind == "Ram" then
    local a,b,c = base+V(side*.65,.65,.1),base+V(side*.95,.15,.65),base+V(side*.7,-.45,.25)
    link("HornBase",base,a,.5,.5,pale)
    link("CurledHorn",a,b,.48,.48,pale)
    link("HornTip",b,c,.28,.28,armor)
   else
    local tip = base+V(side*.5,kind == "Goat" and 1.25 or 1.9,.5)
    link("Antler",base,tip,.23,.26,pale)
    if kind == "Antlers" then
     link("AntlerFork",base+V(side*.2,.8,.2),base+V(side*1.15,1.3,-.3),.18,.2,pale)
     link("AntlerTine",base+V(side*.4,1.4,.38),base+V(side*.75,2,-.15),.13,.16,pale)
    end
   end
  end
 end

 if family == "Canine" then
  local cat = variant == "Cat"
  part("Ribcage",V(2.2,2.05,3.6),V(0,-.05,0),body,nil,"Ball")
  part("ShoulderMantle",V(2.35,1.5,2),V(0,.65,-1.1),body:Lerp(armor,.2),M.Fabric,"Ball")
  part("Breast",V(1.3,1.55,.65),V(0,-.2,-1.7),pale,nil,"Ball")
  fourLegs(1.25,.82,false)
  part("Neck",V(1.5,1.8,1.4),V(0,.75,-1.7),body,nil,"Ball")
  part("Head",V(1.6,1.35,1.6),V(0,1.35,-2.3),body,nil,"Ball")
  part("Muzzle",V(cat and 1.05 or .95,.65,cat and .8 or 1.5),V(0,1,-3.1),pale,M.Fabric,"Ball")
  part("Nose",V(.5,.3,.2),V(0,1.16,cat and -3.52 or -3.87),armor)
  eyes(V(0,1.53,-3.12),.55,variant == "Ember" or variant == "Crystal")
  ears(V(0,2.35,-2.2),variant == "Fox" and .8 or .6,variant == "Fox" and 1.6 or variant == "Echo" and 1.8 or .95)
  local tailEnd = V(cat and 1.2 or .65,cat and 1.1 or -.55,3.9)
  link("Tail",V(0,.3,1.7),tailEnd,cat and .35 or .7,cat and .35 or .75,body)
  link("TailTip",tailEnd,tailEnd+V(.2,.15,.65),cat and .3 or .55,cat and .3 or .6,pale)
  if variant == "Crystal" or variant == "Thorn" or variant == "Ember" then crest(V(0,1.35,-.7),3,variant == "Thorn" and armor or accent,variant == "Ember" and M.Neon or M.Slate) end
  if cat then for side=-1,1,2 do for i=1,3 do part("FlankStripe",V(.08,.7,.22),V(side*1.04,.3,(i-2)*.8),armor,nil,nil,CFrame.Angles(.3,0,0)) end end end
 elseif family == "Grazer" then
  part("Body",V(2.4,2.15,3.7),V(0,.1,0),body,nil,"Ball")
  part("Belly",V(1.6,.7,2.65),V(0,-.65,0),pale,nil,"Ball")
  fourLegs(1.25,.85,true)
  part("Neck",V(1.25,2.6,1.35),V(0,1.05,-1.65),body,nil,"Ball",CFrame.Angles(.22,0,0))
  local head = V(0,2.15,-2.1)
  part("Head",V(1.35,1.3,1.9),head,body,nil,"Ball")
  part("Muzzle",V(1,.6,.75),head+V(0,-.33,-.85),pale)
  eyes(head+V(0,.15,-.91),.48,variant == "Crystal")
  for side=-1,1,2 do wedge("Ear",V(1.15,.45,.65),head+V(side*1,.55,.1),body,CFrame.Angles(0,0,side*.3)) end
  horns(head,variant == "Antlers" and "Antlers" or variant == "Ram" and "Ram" or "Goat")
  link("Tail",V(0,.4,1.7),V(0,-.15,2.5),.35,.45,pale)
  if variant == "Crystal" or variant == "Moon" then crest(V(0,1.35,-.25),3,accent,M.Slate) end
  if variant == "Cave" then part("NosePlate",V(1.05,.25,.9),head+V(0,.6,-.6),armor,M.Slate) end
 elseif family == "Boar" or family == "Bear" then
  local bear = family == "Bear"
  part("Body",V(bear and 3.1 or 2.85,2.6,4.25),V(0,-.05,0),body,nil,"Ball")
  part("ShoulderHump",V(2.6,2.2,2.1),V(0,.7,-1),body,nil,"Ball")
  fourLegs(1.35,1.05,not bear)
  part("Head",V(2.2,1.8,1.9),V(0,.15,-2.25),body,nil,"Ball")
  part("Muzzle",V(1.4,.95,1.05),V(0,-.1,-3.15),pale,nil,"Ball")
  part("Nose",V(.85,.5,.2),V(0,-.03,-3.7),armor)
  eyes(V(0,.5,-3.1),.72,false)
  for side=-1,1,2 do
   part("Ear",V(.65,.75,.5),V(side*.85,1.15,-2.2),body,nil,bear and "Ball" or nil)
   if not bear then wedge("Tusk",V(.3,.95,.55),V(side*.88,.15,-3.4),pale,CFrame.Angles(-.3,0,-side*.25)) end
  end
  if not bear then crest(V(0,1.35,-1),4,armor,M.SmoothPlastic) end
  if variant == "Moss" then part("MossMantle",V(2.5,.3,1.4),V(0,1.64,-.7),accent,M.Grass) end
 elseif family == "Hare" then
  part("Haunch",V(2.35,2.35,2.4),V(0,-.9,.7),body,nil,"Ball")
  part("Breast",V(1.6,1.8,1.8),V(0,-1,-.9),pale,nil,"Ball")
  for side=-1,1,2 do
   part("HindFoot",V(.85,.5,1.8),V(side*.86,-2.7,.55),body,nil,"Ball")
   link("Foreleg",V(side*.5,-1,-1.3),V(side*.5,-2.65,-1.5),.38,.42,body)
   part("Forepaw",V(.48,.35,.7),V(side*.5,-2.78,-1.7),pale)
  end
  part("Head",V(1.5,1.5,1.6),V(0,.05,-1.55),body,nil,"Ball")
  ears(V(0,1.9,-1.3),.55,2.5)
  eyes(V(0,.25,-2.29),.48,false)
  part("Nose",V(.25,.2,.16),V(0,-.1,-2.4),armor)
  part("Tail",V(.9,.9,.9),V(0,-.7,2),pale,nil,"Ball")
 elseif family == "Serpent" then
  local leech = variant == "Leech" or variant == "Burrower"
  local water = variant == "Eel" or variant == "Lantern"
  for i=1,7 do
   local taper = 1-(i-1)*.105
   local p = V(math.sin(i*.8)*.55,-1.9,(i-3)*.9)
   activeGroup=group("Spine"..i,"Spine",p,i*.68)
   part("Segment"..i,V(1.8*taper,1.35*taper,1.5),p,body:Lerp(armor,(i%2)*.13),nil,"Ball")
   if not leech then part("BellyScute",V(1.25*taper,.15,1),p+V(0,-.5*taper,0),pale) end
   if water and i>1 then wedge("DorsalFin",V(.12,.65*taper,1.1),p+V(0,.6*taper,0),accent) end
   activeGroup=nil
  end
  local head = V(0,leech and -1.85 or -.95,-2.6)
  if not leech then link("RaisedNeck",V(.4,-1.8,-1.5),head,1.25,1.05,body) end
  part("Head",V(leech and 1.55 or 1.9,1.1,1.7),head,body,nil,"Ball")
  if leech then
   part("MouthRim",V(1.35,.95,.18),head+V(0,0,-.8),pale,nil,"Ball")
   part("Mouth",V(.95,.6,.2),head+V(0,0,-.91),armor,nil,"Ball")
   for side=-1,1,2 do wedge("MouthTooth",V(.22,.35,.17),head+V(side*.35,.1,-1.03),pale) end
  else
   part("LowerJaw",V(1.35,.24,1.3),head+V(0,-.44,-.15),pale)
   eyes(head+V(0,.23,-.74),.62,water)
  end
  if variant == "Crest" then wedge("HeadCrest",V(.4,1.4,1.3),head+V(0,.95,.1),armor) end
  if variant == "Vine" then for side=-1,1,2 do wedge("LeafFrill",V(.9,.14,1.3),head+V(side*1,.1,.5),accent,CFrame.Angles(0,side*.5,0)) end end
  if variant == "Lantern" then
   link("LureStem",head+V(0,.4,0),head+V(0,1.25,-.45),.12,.12,armor)
   part("Lure",V(.38,.4,.38),head+V(0,1.2,-.6),accent,M.Neon,"Ball")
  end
 elseif family == "Spider" or family == "Mite" or family == "Beetle" or family == "Scorpion" or family == "Crab" then
  local crab, spider = family == "Crab", family == "Spider"
  local mite, scorpion = family == "Mite", family == "Scorpion"
  local width = crab and 3.5 or mite and 2.2 or 2.8
  part("Abdomen",V(width,1.7,crab and 2.2 or 3.25),V(0,-1.2,.4),body,nil,"Ball")
  part("Head",V(1.7,.95,1.3),V(0,-1.45,-1.65),armor,nil,"Ball")
  local legPairs = (spider or mite or scorpion or crab) and 4 or 3
  for side=-1,1,2 do for i=1,legPairs do
   local z=(i-(legPairs+1)/2)*.72
   local hip=V(side*width*.37,-1.35,z)
   local knee=V(side*(width*.5+1),-.8,z+(i-(legPairs+1)/2)*.5)
   local foot=V(side*(width*.5+1.55),-2.9,z+(i-(legPairs+1)/2)*.7)
   activeGroup=group("Leg"..side..":"..i,"Leg",hip,(i%2==0 and 0 or math.pi)+(side==1 and math.pi or 0),side)
   link("Leg",hip,knee,.22,.3,armor)
   link("LegTip",knee,foot,.15,.22,armor)
   part("KneeJoint",V(.35,.35,.35),knee,body,nil,"Ball")
   activeGroup=nil
  end end
  if not crab then eyes(V(0,-1.25,-2.25),.5,variant == "Crystal" or variant == "Moon") end
  if spider then
   part("Thorax",V(1.85,1.3,1.65),V(0,-1.15,-.9),body,nil,"Ball")
   for side=-1,1,2 do wedge("Fang",V(.3,.6,.6),V(side*.45,-1.95,-2.2),pale,CFrame.Angles(math.pi,0,0)) end
   wedge("BackMark",V(1.3,.12,1.8),V(0,-.29,.75),accent)
  elseif family == "Beetle" then
   for side=-1,1,2 do part("WingCase",V(1.38,1.3,3),V(side*.73,-.65,.35),armor,nil,"Ball") end
   part("ShellSeam",V(.12,.15,2.5),V(0,-.04,.35),pale)
   for side=-1,1,2 do link("Antenna",V(side*.5,-1,-1.9),V(side*.9,-.3,-2.5),.12,.12,pale) end
   if variant == "Horn" then wedge("Horn",V(.48,1.5,1.2),V(0,-.05,-1.8),armor) end
   if variant == "Mushroom" then
    part("CapStem",V(.45,.9,.45),V(0,.4,.4),pale,M.Wood)
    part("MushroomCap",V(3,.65,2.6),V(0,.95,.4),accent,nil,"Ball")
    part("CapSpot",V(.55,.08,.55),V(.6,1.25,.5),pale)
   end
  elseif crab or scorpion then
   for side=-1,1,2 do
    local claw=V(side*2.1,-1,-2.7)
    link("PincerArm",V(side*1,-1.2,-.9),claw,.4,.45,body)
    part("PincerPalm",V(.9,.8,1),claw,body,nil,"Ball")
    for digit=-1,1,2 do wedge("Pincer",V(.32,.55,.95),claw+V(digit*.33,0,-.75),pale,CFrame.Angles(0,-digit*.2,0)) end
    if crab then
     link("Eyestalk",V(side*.55,-1,-1.3),V(side*.7,-.25,-1.5),.18,.18,armor)
     part("StalkEye",V(.28,.3,.28),V(side*.7,-.2,-1.5),accent,nil,"Ball")
    end
   end
   if scorpion then
    local points={V(0,-1,1.8),V(0,-.1,2.8),V(0,1.2,2.6),V(0,1.9,1.7),V(0,1.6,.8)}
    for i=1,#points-1 do link("Tail",points[i],points[i+1],.6-i*.08,.65-i*.08,armor) end
    wedge("Stinger",V(.4,.65,.7),V(0,1.35,.55),pale,CFrame.Angles(math.pi,0,0))
   end
  end
  if variant == "Crystal" or variant == "Moon" or variant == "Star" then crest(V(0,-.05,0),2,accent,M.Slate) end
  if variant == "Spore" then for side=-1,1,2 do part("SporeSac",V(.7,.8,.7),V(side*.7,-.1,.65),accent,nil,"Ball") end end
 elseif family == "Toad" then
  part("Body",V(3.1,2,3),V(0,-1.25,.3),body,nil,"Ball")
  part("Throat",V(2.3,1.25,1.1),V(0,-1.6,-1.1),pale,nil,"Ball")
  part("Head",V(2.9,1.2,1.6),V(0,-.8,-1.1),body,nil,"Ball")
  for side=-1,1,2 do
   part("EyeBrow",V(.85,.8,.8),V(side*.95,-.15,-1.45),body,nil,"Ball")
   part("Haunch",V(1.5,1.5,2),V(side*1.45,-1.6,1),body,nil,"Ball")
   link("Foreleg",V(side*1,-1.3,-1.1),V(side*1.55,-2.65,-1.7),.4,.48,body)
   for z=-1,1,2 do wedge("WebbedFoot",V(1.05,.2,1.25),V(side*1.6,-2.9,z*1.65),pale,CFrame.Angles(0,side*.2,0)) end
  end
  eyes(V(0,-.1,-1.87),.95,variant == "Rift")
  part("MouthLine",V(2.1,.1,.1),V(0,-1.16,-1.9),armor)
  for i=1,3 do part("BackNodule",V(.55,.35,.55),V((i-2)*.75,-.22,.5+(i%2)*.4),accent,nil,"Ball") end
 elseif family == "Lizard" or family == "Armored" or family == "Turtle" then
  local armored, turtle = family == "Armored", family == "Turtle"
  part("Body",V(2.7,1.6,3.8),V(0,-1.3,0),body,nil,"Ball")
  for side=-1,1,2 do for front=-1,1,2 do
   local knee=V(side*1.65,-1.7,front*1.1)
   link("Leg",V(side*.9,-1.3,front*1.1),knee,.5,.6,body)
   link("Foreleg",knee,V(side*1.95,-2.6,front*1.5),.35,.4,body)
   part("ClawFoot",V(.7,.3,.95),V(side*1.95,-2.85,front*1.5-.15),pale)
  end end
  part("Neck",V(1.25,1,1.4),V(0,-1.2,-2),body,nil,"Ball")
  part("Head",V(1.6,1,1.7),V(0,-1,-2.8),body,nil,"Ball")
  part("Jaw",V(1.3,.22,1.4),V(0,-1.4,-2.9),pale)
  eyes(V(0,-.75,-3.51),.52,false)
  link("Tail",V(0,-1.2,1.6),V(.5,-1.6,3.1),.85,.65,body)
  if not turtle then link("TailTip",V(.5,-1.6,3.1),V(1,-2.1,4.2),.35,.25,body) end
  if turtle then
   part("ShellRim",V(3.5,.35,4.1),V(0,-.8,0),pale,nil,"Ball")
   part("Carapace",V(3.4,2,3.95),V(0,-.25,0),armor,nil,"Ball")
   for z=-1,1 do part("ShellScute",V(1.5,.18,.95),V(0,.75,z*1.02),body) end
  elseif armored then
   local material=variant == "Metal" and M.CorrodedMetal or M.Slate
   for i=1,3 do
    part("CarapacePlate",V(3.25,.6,1.3),V(0,-.05,(i-2)*1.12),armor,material,nil,CFrame.Angles(0,0,i%2 == 0 and .05 or -.05))
    wedge("ArmorRidge",V(.9,.55,1.25),V(0,.48,(i-2)*1.12),body,nil,material)
   end
  else crest(V(0,-.25,-.5),4,accent,M.SmoothPlastic) end
 elseif family == "Snail" then
  part("Foot",V(2.25,.6,4.4),V(0,-2.6,-.2),body,nil,"Ball")
  part("Shell",V(2.8,2.9,2.65),V(0,-.9,.5),armor,nil,"Ball")
  for side=-1,1,2 do
   part("ShellWhorl",V(.16,1.9,1.9),V(side*1.34,-.9,.5),pale,nil,"Ball")
   part("ShellSpiral",V(.2,1.12,1.12),V(side*1.43,-.9,.5),body,nil,"Ball")
   part("WhorlCenter",V(.22,.45,.45),V(side*1.52,-.9,.5),armor,nil,"Ball")
   link("Eyestalk",V(side*.48,-2,-1.7),V(side*.75,-.7,-2),.16,.16,body)
   part("Eye",V(.3,.3,.3),V(side*.75,-.65,-2),armor,nil,"Ball")
  end
  part("Head",V(1.5,.7,1.3),V(0,-2.18,-1.8),body,nil,"Ball")
  part("Moss",V(1.8,.2,1.7),V(0,.5,.5),accent,M.Grass)
 elseif family == "Bird" or family == "Bat" or family == "Moth" then
  local wader, owl = variant == "Wader", variant == "Owl"
  local bat, moth = family == "Bat", family == "Moth"
  part("Breast",V(moth and .9 or 1.8,2.2,2.2),V(0,-.3,0),body,nil,"Ball")
  part("Bib",V(1.1,1.6,.45),V(0,-.3,-1),pale,nil,"Ball")
  for side=-1,1,2 do
   if wader then
    wedge("FoldedWing",V(.7,1.3,2.35),V(side*.8,-.3,.2),armor)
   else
    wedge("Wing",V(3.3,.2,2.5),V(side*2.1,.25,.25),body,CFrame.Angles(0,-side*.23,side*.1))
    for i=1,3 do wedge(moth and "WingLobe" or bat and "WingMembrane" or "FlightFeather",V(moth and 1.5 or .8,.16,2.3-i*.27),V(side*(1.35+i*.72),.18,.95+i*.12),i%2 == 0 and accent or armor,CFrame.Angles(0,-side*.3,0)) end
    if moth then
     part("WingEyespot",V(1,.12,1.1),V(side*2.4,.43,.3),pale,nil,"Ball")
     part("WingEyeCenter",V(.48,.14,.55),V(side*2.4,.5,.3),armor,nil,"Ball")
    elseif bat then link("WingFinger",V(side*.6,.35,-.35),V(side*4,.35,.6),.12,.13,pale) end
   end
   if not moth then
    link("Leg",V(side*.45,-1.1,.1),V(side*.45,-2.72,-.15),wader and .16 or .24,wader and .16 or .24,armor)
    part("Foot",V(.5,.2,.85),V(side*.45,-2.9,-.35),pale)
   end
  end
  local head=V(0,wader and 1.7 or .95,wader and -1.35 or -.7)
  if wader then link("Neck",V(0,.3,-.65),head,.5,.6,pale) end
  part("Head",V(owl and 1.9 or 1.3,owl and 1.8 or 1.25,1.3),head,body,nil,"Ball")
  if owl then part("FacialDisc",V(1.65,1.45,.28),head+V(0,0,-.62),pale,nil,"Ball") end
  eyes(head+V(0,.15,-.68),owl and .48 or .36,bat)
  if bat then ears(head+V(0,1,0),.6,1.2)
  elseif moth then for side=-1,1,2 do link("Antenna",head+V(side*.25,.4,0),head+V(side*.75,1.2,-.2),.12,.12,pale) end
  else wedge("Beak",V(.4,.4,wader and 1.75 or .65),head+V(0,-.15,wader and -1.4 or -.9),accent,CFrame.Angles(0,math.pi,0)) end
  wedge("Tail",V(1.05,.2,1.6),V(0,-.6,1.75),armor)
 elseif family == "Fish" then
  part("Body",V(1.05,1.65,3.6),V(0,-.7,0),pale,M.Metal,"Ball")
  part("Head",V(1.05,1.25,1.1),V(0,-.7,-1.4),body,nil,"Ball")
  eyes(V(0,-.48,-1.91),.35,false)
  wedge("DorsalFin",V(.12,1.2,1.65),V(0,.45,.2),armor)
  for side=-1,1,2 do wedge("PectoralFin",V(.9,.12,1.15),V(side*.7,-.9,-.2),accent,CFrame.Angles(0,side*.45,side*.2)) end
  for vertical=-1,1,2 do wedge("TailFin",V(.16,1.1,1.4),V(0,-.7+vertical*.45,2.2),body,CFrame.Angles(vertical == 1 and 0 or math.pi,0,0)) end
 elseif family == "Raptor" then
  part("Body",V(1.9,2.1,2.8),V(0,.05,.1),body,nil,"Ball")
  for side=-1,1,2 do
   part("Haunch",V(.9,1.6,1.3),V(side*.85,-.85,.8),body,nil,"Ball")
   link("Shin",V(side*.85,-1.2,.9),V(side*.75,-2.05,1.15),.35,.4,armor)
   link("Ankle",V(side*.75,-2.05,1.15),V(side*.75,-2.7,-.1),.27,.3,pale)
   for toe=-1,1 do link("Talon",V(side*.75,-2.85,-.05),V(side*.75+toe*.22,-2.85,-.9),.12,.15,armor) end
   wedge("Forewing",V(1.4,.2,1.8),V(side*1.05,.1,-.6),armor,CFrame.Angles(0,side*.35,side*.2))
  end
  part("Neck",V(.9,1.8,1.1),V(0,1.1,-1.2),body,nil,"Ball")
  part("Head",V(1.1,1.1,1.65),V(0,1.8,-1.7),body,nil,"Ball")
  wedge("Beak",V(.75,.6,1),V(0,1.65,-2.7),pale,CFrame.Angles(0,math.pi,0))
  eyes(V(0,2,-2.49),.39,false)
  crest(V(0,2.55,-1.5),2,accent,M.SmoothPlastic)
  link("Tail",V(0,.1,1.1),V(0,.45,3.15),.75,.65,body)
  wedge("TailFan",V(1.5,.2,1.3),V(0,.45,3.45),armor)
 elseif family == "Wraith" then
  part("Torso",V(2.3,2.7,1.65),V(0,.6,0),armor,M.Glacier)
  for side=-1,1,2 do
   wedge("Shoulder",V(1.4,1.3,1.5),V(side*1.6,1.45,0),body,nil,M.Glacier)
   link("Arm",V(side*1.65,.9,0),V(side*2,-.8,-.5),.45,.65,body,M.Glacier)
   wedge("Claw",V(.55,1.1,.6),V(side*2,-1.25,-.65),pale,CFrame.Angles(math.pi,0,0),M.Glacier)
  end
  for i=1,3 do wedge("IceShroud",V(.8,2.5,1.25),V((i-2)*.65,-1.3,.1),i%2 == 0 and armor or body,CFrame.Angles(math.pi,0,(i-2)*.12),M.Glacier) end
  part("Head",V(1.45,1.6,1.35),V(0,2.5,-.1),body,M.Glacier)
  part("FaceShadow",V(1.05,.65,.1),V(0,2.4,-.81),armor)
  eyes(V(0,2.5,-.9),.3,true)
  crest(V(0,3.45,-.4),2,pale,M.Glacier)
 elseif family == "Guardian" then
  local material=variant == "Root" and M.Wood or variant == "Archive" and M.CorrodedMetal or M.Slate
  part("Torso",V(3,3.1,1.9),V(0,.65,0),armor,material)
  wedge("ChestPlate",V(2.8,2.1,.5),V(0,1,-1.05),body,CFrame.Angles(0,math.pi,0),material)
  part("CoreSetting",V(1.15,1.15,.35),V(0,1,-1.4),pale,material,nil,CFrame.Angles(0,0,math.pi/4))
  part("Core",V(.55,.55,.15),V(0,1,-1.62),accent,M.Neon,nil,CFrame.Angles(0,0,math.pi/4))
  for side=-1,1,2 do
   part("Shoulder",V(1.65,1.4,1.8),V(side*2,1.55,0),body,material,nil,CFrame.Angles(0,0,side*.18))
   link("Arm",V(side*2,.85,0),V(side*2.25,-.8,-.25),1,1.1,armor,material)
   part("Fist",V(1.35,1.1,1.3),V(side*2.3,-1.15,-.35),body,material)
   link("Leg",V(side*.85,-.65,0),V(side*.9,-2.5,.05),.95,1.15,armor,material)
   part("Foot",V(1.2,.55,1.8),V(side*.9,-2.72,-.3),body,material)
  end
  part("Head",V(1.8,1.55,1.6),V(0,2.85,0),body,material)
  part("Brow",V(2,.35,.55),V(0,3.2,-.8),armor,material)
  eyes(V(0,2.85,-.83),.5,true)
  if variant == "Root" then
   horns(V(0,2.8,0),"Antlers")
   for side=-1,1,2 do link("RootToe",V(side*.9,-2.8,-.6),V(side*1.45,-2.9,-1.35),.3,.3,body,M.Wood) end
   part("MossShoulder",V(1.65,.18,1.5),V(-2,2.3,0),accent,M.Grass)
  elseif variant == "Crystal" then crest(V(0,3.85,-.5),2,accent,M.Slate)
  elseif variant == "Archive" then
   for side=-1,1,2 do part("PressureTank",V(.7,2.4,.8),V(side*1,1,1.3),body,M.Metal) end
   part("Visor",V(1.55,.2,.12),V(0,2.8,-.98),accent,M.Neon)
  elseif variant == "Lava" then
   for side=-1,1,2 do part("MagmaSeam",V(.1,1.5,.12),V(side*.95,.75,-1.02),accent,M.Neon) end
  end
 end

 -- Layered silhouette details inherit their parent's joint instead of floating as it moves.
 local furry=family=="Canine" or family=="Bear" or family=="Boar" or family=="Hare" or family=="Grazer"
 local scaly=family=="Lizard" or family=="Armored" or family=="Turtle" or family=="Serpent" or family=="Fish"
 local shell=family=="Beetle" or family=="Crab" or family=="Scorpion" or family=="Mite"
 for _,g in pairs(groups) do
  activeGroup=g
  local originals=table.clone(g.parts)
  for _,p in ipairs(originals) do
   local pos,size=p.Position/scale,p.Size/scale
   if furry and (p.Name=="Ribcage" or p.Name=="Body" or p.Name=="Haunch") then
    for side=-1,1,2 do
     for i=1,3 do
      part("LayeredFur",V(.3,.7,.7),pos+V(side*size.X*.41,size.Y*.12,(i-2)*size.Z*.22),body:Lerp(pale,.12+i*.055),M.Fabric,"Ball",CFrame.Angles(.15,0,side*.17))
     end
    end
   elseif furry and p.Name=="Head" then
    for side=-1,1,2 do
     part("Cheek",V(size.X*.39,size.Y*.53,size.Z*.55),pos+V(side*size.X*.34,-size.Y*.2,-size.Z*.23),body:Lerp(pale,.25),nil,"Ball")
     wedge("BrowRidge",V(size.X*.38,.19,.38),pos+V(side*size.X*.3,size.Y*.29,-size.Z*.46),armor:Lerp(body,.6),CFrame.Angles(0,0,-side*.13))
    end
   elseif scaly and (p.Name=="Body" or p.Name:match("^Segment")) then
    for side=-1,1,2 do
     for i=1,2 do
      part("OverlappingScale",V(.15,size.Y*.32,size.Z*.27),pos+V(side*size.X*.46,size.Y*.1,(i-1.5)*size.Z*.31),body:Lerp(pale,.15+i*.08),M.SmoothPlastic,"Ball",CFrame.Angles(0,side*.18,.1))
     end
    end
   elseif shell and (p.Name=="WingCase" or p.Name=="Abdomen") then
    for i=1,3 do
     part("CarapaceGrowthBand",V(size.X*.67,.06,.12),pos+V(0,size.Y*.46,(i-2)*size.Z*.23),armor:Lerp(accent,.22),M.SmoothPlastic,"Ball")
    end
   elseif p.Name=="CarapacePlate" or p.Name=="Shoulder" and family=="Guardian" then
    wedge("ChippedPlateEdge",V(size.X*.64,.12,size.Z*.8),pos+V(0,size.Y*.5,0),body:Lerp(pale,.24),CFrame.Angles(0,.15,0),p.Material)
   elseif p.Name=="FlightFeather" then
    link("FeatherShaft",pos-V(.18,0,.55),pos+V(.18,.06,.55),.05,.045,pale)
   end
  end
 end
 activeGroup=nil
 for name,g in pairs(groups) do
  local anchor=g.parts[1]
  if anchor then
   local pivot=CFrame.new(g.pivot*scale)
   local motor=Instance.new("Motor6D")
   motor.Name="ArtJoint_"..name
   motor.Part0,motor.Part1=root,anchor
   motor.C0=root.CFrame:ToObjectSpace(pivot)
   motor.C1=anchor.CFrame:ToObjectSpace(pivot)
   motor:SetAttribute("MotionKind",g.kind)
   motor:SetAttribute("MotionPhase",g.phase)
   motor:SetAttribute("MotionSide",g.side)
   motor.Parent=root
   for i=2,#g.parts do
    local weld=Instance.new("WeldConstraint")
    weld.Part0,weld.Part1,weld.Parent=anchor,g.parts[i],g.parts[i]
   end
  end
 end
 model:SetAttribute("ArtFamily",family)
 model:SetAttribute("ArtScale",scale)
 model:SetAttribute("ArtVersion",4)
 game:GetService("CollectionService"):AddTag(model,"AnimatedExpeditionCreature")

 -- Preserve the movement/collision/stat contract. Decoration does not own behavior.
 local hum = Instance.new("Humanoid")
 hum.Name = "Humanoid"
 hum.RequiresNeck = false
 hum.BreakJointsOnDeath = false
 hum.UseJumpPower = false
 hum.JumpHeight = 7
 hum.HipHeight = 1.5 * scale
 hum.MaxHealth, hum.Health = 72, 72
 hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
 hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
 hum.NameDisplayDistance, hum.HealthDisplayDistance = 0, 0
 hum.Parent = model
 model:SetAttribute("EntityId",id)
 model:SetAttribute("EntityType",def.Role == "N" and "Animal" or "Monster")
 model:SetAttribute("CreatureRole",def.Role)
 model:SetAttribute("AIClass","OverhaulCreature")
 model:SetAttribute("OverhaulCreature",true)
 model:SetAttribute("DisplayName",def.Name)
 return model
end

return Art
