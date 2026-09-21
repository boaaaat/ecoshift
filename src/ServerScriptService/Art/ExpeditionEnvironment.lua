-- Ground-origin art for the active campaign world. No harvesting or world state.
-- Rock: original baked PBR Blender mesh, source in assets/models/environment/weathered-boulder.
-- Crown: original smooth Blender leaf cluster. Grass: free Proudism pack 9682467046.
-- Only the listed mesh geometry is used; no marketplace scripts are loaded.
local Art = {}
local RockTemplate = game:GetService("ServerStorage"):WaitForChild("ArtAssets"):WaitForChild("WeatheredBoulder")
local CanopyTemplate = game:GetService("ServerStorage"):WaitForChild("ArtAssets"):WaitForChild("SmoothCanopy")
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local WHITE, DARK = Color3.fromRGB(235, 233, 215), Color3.fromRGB(31, 35, 43)
local function color(hex) return Color3.fromHex(hex) end
local function shade(c, n) return c:Lerp(n < 0 and DARK or WHITE, math.abs(n)) end
local PALETTES = {
 Forest={"6E5139","52764D","9EBA74","7D8880"}, Desert={"97734D","879967","C3BC81","BA8860"},
 Swamp={"53604B","557E66","A9BC83","63766B"}, FrozenTundra={"6D777D","658A8F","C6DCE0","8CA7B5"},
 Volcanic={"554744","6F6157","B48361","514E58"}, CrystalWastes={"665775","8F83AF","CCBCE0","77758C"},
 AuroraVale={"A0ABA4","76AAA1","C2D9C4","91ADB6"}, StarfallCrater={"645D65","8A8191","BFB1C9","716977"},
 SaltglassCoast={"9B8970","648F80","B6CBAB","AEBAAF"}, StormspireHighlands={"5C686A","637C77","A6BAB0","717E91"},
 MyceliumHollow={"625869","6D9180","B2D3B6","766681"}, IronrootBadlands={"665044","787448","B2A47A","9B6E55"},
 CanopySea={"6B5141","437B5E","8CBA77","6F8279"}, SunkenArchive={"696F61","648F83","B0C6AD","829992"},
 UmbralDepths={"585363","666583","A49DBA","5B596F"}, ShattermoonExpanse={"777083","958EA9","D3CCDF","9792A5"},
}
for _, p in pairs(PALETTES) do for i, c in ipairs(p) do p[i] = color(c) end end
local MESH = {
 Grass={Id="535380308",Size=V(58.40475845,50,65.43595886)},
}
local function part(model, name, size, frame, c, material, class, collide)
 local p=Instance.new(class or "Part")
 p.Name,p.Size,p.CFrame,p.Color=name,size,frame,c
 p.Material=material or Enum.Material.SmoothPlastic
 p.Anchored,p.CanCollide,p.CanTouch=true,collide==true,false
 p.TopSurface,p.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
 p.Parent=model
 return p
end
local function mesh(model, name, kind, size, frame, c)
 if kind=="Rock" or kind=="Crown" then
  local p=(kind=="Rock" and RockTemplate or CanopyTemplate):Clone()
  p.Name,p.Size,p.CFrame=name,size,frame
  p.Anchored,p.CanCollide,p.CanTouch,p.CanQuery=true,false,false,true
  -- PBR color is authored in the texture; preserve it and apply a light biome tint.
  p.Color=Color3.new(1,1,1)
  local surface=p:FindFirstChildOfClass("SurfaceAppearance")
  surface.Color=Color3.new(1,1,1):Lerp(c,kind=="Rock" and .25 or .4)
  p.Parent=model
  return p
 end
 local p=part(model,name,size,frame,c)
 if kind=="Cap" or kind=="Stem" then
  p.Shape=Enum.PartType.Ball
  return p
 end
 local def=MESH[kind];local m=Instance.new("SpecialMesh")
 m.MeshType=Enum.MeshType.FileMesh;m.MeshId="rbxassetid://"..def.Id
 m.Scale=size/def.Size;m.Parent=p
 return p
end
local function beam(model,name,from,to,width,c,collide)
 return part(model,name,V(width,(to-from).Magnitude,width),CFrame.lookAt((from+to)/2,to)*A(math.pi/2,0,0),c,Enum.Material.Wood,nil,collide)
end
local function cylinder(model,name,size,frame,c,material,collide)
 local p=part(model,name,V(size.Y,size.X,size.Z),frame*A(0,0,math.pi/2),c,material,nil,collide)
 p.Shape=Enum.PartType.Cylinder;return p
end
local function rock(model,position,size,c,yaw)
 mesh(model,"ChiseledStone","Rock",size,CF(position)*A(0,yaw or 0,0),c)
 -- A compact invisible core gives walkable collision without a box around the silhouette.
 local core=part(model,"StoneCollision",size*V(.66,.68,.64),CF(position),c,nil,nil,true)
 core.Transparency=1;core.CanQuery=false
end
local function crystal(model,frame,height,width,c,luminous)
 local mat=Enum.Material.SmoothPlastic
 part(model,"CrystalShaft",V(width,height*.65,width),frame*CF(0,height*.325,0),c,mat,nil,true)
 for i=0,3 do
  part(model,"CrystalTip",V(width*.5,height*.35,width*.5),frame*CF(0,height*.825,0)*A(0,i*math.pi/2,0)*CF(width*.25,0,width*.25)*A(0,math.pi/2,0),shade(c,(i-1)*.1),mat,"CornerWedgePart")
 end
 if luminous then
  local seam=part(model,"MineralInlay",V(.045,height*.46,.045),frame*CF(width*.5+.01,height*.39,-width*.25),shade(c,.45),Enum.Material.Neon)
  seam.CastShadow=false
 end
end
local function canopy(model,frame,size,c,pine,snow)
 if not pine then mesh(model,"LeafCluster","Crown",size,frame,c);return end
 for i=0,2 do
  local taper=1-i*.28
  local cluster=mesh(model,"ConiferNeedleCluster","Crown",V(size.X*taper,size.Y*.46,size.Z*taper),frame*CF(0,(i-1)*size.Y*.27,0)*A(0,i*.8,0),shade(c,i*.045))
  if snow then
   cluster:FindFirstChildOfClass("SurfaceAppearance"):Destroy()
   cluster.TextureID="";cluster.Color=c;cluster.Material=Enum.Material.Snow
  end
 end
end
local function tree(model,id,p,options)
 local height=options.Large and 18 or 12
 local pine=options.Pine;local bark=options.Birch and color("DEDCC9") or p[1]
 if id=="Ironwood" then bark=color("66534D") elseif id=="Heartwood" then bark=color("805238") end
 local trunkHeight=height*.67;local width=height*.105
 cylinder(model,"Trunk",V(width,trunkHeight,width),CF(0,trunkHeight/2,0),bark,Enum.Material.Wood,true)
 for i=0,3 do
  local angle=i*math.pi/2+.4;local radius=height*(options.Wetland and .19 or .1)
  local outer=V(math.cos(angle)*radius,.14,math.sin(angle)*radius)
  beam(model,"ButtressRoot",outer,V(0,height*.16,0),width*.34,shade(bark,-.12),true)
 end
 if options.Birch then
  for i=1,4 do
   part(model,"BirchBarkMark",V(width*.7,.15,width*.065),CF(0,i*trunkHeight/5,-width*.5),shade(bark,-.68))
  end
 end
 -- Eight small details per tree: shallow knots, bark checks, and forked branches.
 for side=-1,1,2 do
  local knotFrame=CF(side*width*.15,trunkHeight*(side==1 and .36 or .66),-width*.485)*A(0,0,side*.16)
  local knot=part(model,"BarkKnot",V(width*.29,width*.46,.045),knotFrame,shade(bark,-.33),Enum.Material.Wood)
  knot.Shape=Enum.PartType.Ball
  part(model,"BarkCheck",V(.028,height*.11,.016),knotFrame*CF(0,height*.067,-.02)*A(0,0,-side*.06),shade(bark,-.45),Enum.Material.Wood)
  local start=V(side*width*.24,height*.43,0)
  local fork=V(side*height*.17,height*.55,-height*.075)
  beam(model,"SecondaryBranch",start,fork,width*.21,shade(bark,-.08))
  beam(model,"BranchFork",fork,fork+V(side*height*.055,height*.075,-height*.055),width*.1,shade(bark,.05))
 end
 local leaf=id=="Heartwood" and p[2]:Lerp(color("B78D57"),.3) or p[2]
 if pine then
  for i=0,2 do
   local w=height*(.54-i*.115)
   canopy(model,CF(0,height*(.49+i*.16),0)*A(0,.2+i*.1,0),V(w,height*.29,w),shade(leaf,i*.12),true)
   if options.Snow then canopy(model,CF(0,height*(.53+i*.16),0)*A(0,.2+i*.1,0),V(w*.75,height*.22,w*.75),p[3],true,true) end
  end
 else
  for i=1,3 do
   local side=i==1 and -1 or i==2 and 1 or 0
   local top=V(side*height*.18,height*(.64+i*.065),(i%2)*height*.07)
   beam(model,"Branch",V(0,height*.42,0),top,width*.38,bark)
   canopy(model,CF(top)*A(.08,options.Yaw+i*.55,side*.09),V(height*.53,height*.32,height*.47),shade(leaf,(i-1)*.09))
  end
  if options.Wetland then
   for i=0,3 do part(model,"WillowFrond",V(.36,height*.24,.15),CF((i-1.5)*height*.11,height*.53,height*.19)*A(0,0,(i-1.5)*.08),p[3],nil,"WedgePart") end
  end
 end
end
local function mushroom(model,id,p)
 local luminous=id~="Mushroom"
 for i=0,2 do
  local s=i==1 and 1.25 or .78;local frame=CF((i-1)*.95,0,(i%2)*.6)*A(0,i*1.4,0)
  mesh(model,"MushroomStem","Stem",V(1.05,1.25,1.05)*s,frame*CF(0,.62*s,0),shade(p[1],.62))
  mesh(model,"MushroomCap","Cap",V(1.8,.86,1.4)*s,frame*CF(0,1.36*s,0),luminous and p[3] or color("BC8263"))
  if luminous then cylinder(model,"LuminousGills",V(1.05,.055,.85)*s,frame*CF(0,1.15*s,0),p[3],Enum.Material.Neon) end
  for j=0,2 do
   part(model,"RadialGill",V(.035,.035,.95)*s,frame*CF(0,1.09*s,0)*A(0,j*math.pi/3,0),shade(p[1],.42),Enum.Material.Fabric)
  end
  for j=-1,1,2 do
   local spot=part(model,"CapFreckle",V(.25,.055,.19)*s,frame*CF(j*.38*s,1.71*s,j*.13*s)*A(0,j*.6,j*-.23),shade(p[1],.73))
   spot.Shape=Enum.PartType.Ball
  end
 end
end
local PLANTS = {
 Fiber="Fiber",AshFiber="Fiber",GlowFiber="Fiber",CrystalThread="Fiber",MoonThread="Fiber",Reeds="Reed",Kelp="Kelp",
 HealingHerb="Herb",FrostBloom="Flower",DawnFlower="Flower",WildHerb="Herb",CoolMint="Herb",BitterSeed="Herb",
 WarmPepper="Pepper",EmberPepper="Pepper",CrystalBasil="Herb",StarSeed="Herb",Berries="Berries",RootVegetable="Root",
 CloudWool="Cotton",ThickSpores="Spores",LivingRoot="Roots",StrongSilk="Silk",LiftSeed="Seed",DarkMoss="Moss",
}
local ACCENT = {
 IronOre="BC997D",Sunstone="E5B758",IceCrystal="A9D6E4",BlackGlass="504958",Sulfur="C9BB64",FireCore="F2A461",
 ClearCrystal="C5B9E4",AuroraStone="A0D6C4",ImpactGlass="C1B3D1",MeteorOre="A7A0B5",StarCore="EFCD9D",
 StormOre="8DB9D3",StormCore="A5D8EA",RedOre="BC755A",LightOre="DACB9B",MoonOre="C8BCD9",GravityShard="B49ACB",
 PressureGlass="9ECCC5",Salt="D9D5B9",DarkDust="6B5C82",MoonRock="A5A0B3",Coal="363B40",
}
local CRYSTALS={Sunstone=true,IceCrystal=true,BlackGlass=true,ClearCrystal=true,ImpactGlass=true,PressureGlass=true,GravityShard=true}
local CORES={FireCore=true,StarCore=true,StormCore=true}
local function plant(model,id,p,family)
 local leaf=p[2];local accent=p[3]
 if id=="WarmPepper" or id=="EmberPepper" then accent=color("C87754")
 elseif id=="DawnFlower" then accent=color("DEAC95") elseif id=="FrostBloom" then accent=color("B6DAE7") end
 if family=="Roots" or family=="Silk" then
  for i=0,3 do
   local angle=i*math.pi/2+.3;local outer=V(math.cos(angle)*1.5,.08,math.sin(angle)*1.5)
   beam(model,"RootArch",outer,V(0,1.1,0),.22,p[1])
   if family=="Silk" then beam(model,"SilkStrand",outer*.75+V(0,.25,0),V(0,1.2,0),.045,WHITE) end
  end
 elseif family=="Moss" then
  for i=0,2 do mesh(model,"MossCushion","Crown",V(1.5,.45,1.2),CF((i-1)*.7,.22,i%2*.45),shade(leaf,i*.1)) end
 elseif family=="Berries" then
  mesh(model,"BerryBush","Crown",V(2.7,1.6,2.1),CF(0,.86,0),leaf)
  for side=-1,1,2 do beam(model,"BerryBranch",V(0,.1,0),V(side*.77,1.21,.16),.09,p[1]) end
  for i=0,5 do
   local a=i*2.399;local berryFrame=CF(math.cos(a)*1.02,1.1+(i%2)*.27,math.sin(a)*.75)
   local berry=part(model,"BerryCluster",V(.3,.28,.3),berryFrame,color("A34E6F"));berry.Shape=Enum.PartType.Ball
   part(model,"BerryCalyx",V(.12,.07,.12),berryFrame*CF(0,.135,0)*A(0,a,0),shade(leaf,-.2),nil,"WedgePart")
  end
 elseif family=="Fiber" then
  for i=0,1 do mesh(model,"FiberTuft","Grass",V(1.8,2.3,1.8),CF((i-.5)*.55,1.15,0)*A(0,i*1.7,0),i==0 and leaf or accent) end
 else
  for i=0,2 do
   local base=V((i-1)*.64,.06,(i%2)*.38)
   local height=(family=="Reed" or family=="Kelp") and 2.5+i*.3 or 1.1+i*.16
   beam(model,"PlantStem",base,base+V(.12,height,0),.09,leaf)
   for side=-1,1,2 do
    local leafFrame=CF(base+V(side*.22,height*.46,0))*A(0,side*.55,side*.55)
    part(model,"FoldedLeaf",V(family=="Kelp" and .7 or .5,height*.62,.085),leafFrame,side==1 and accent or leaf,nil,"WedgePart")
    part(model,"LeafMidrib",V(.024,height*.42,.025),leafFrame*CF(0,-height*.04,-.051),shade(leaf,.24))
   end
   local top=base+V(.12,height,0)
   if family=="Reed" then cylinder(model,"ReedSeedHead",V(.2,.58,.2),CF(top),p[1])
   elseif family=="Cotton" or family=="Spores" then mesh(model,"SeedHead","Crown",V(.67,.55,.6),CF(top),family=="Cotton" and WHITE or accent)
   elseif family=="Flower" then
    for j=0,5 do part(model,"FoldedPetal",V(.4,.22,.56),CF(top)*A(0,j*math.pi/3,0)*CF(0,0,.24)*A(.12,0,0),shade(accent,(j%3)*.055),nil,"WedgePart") end
    local pollen=part(model,"Pollen",V(.22,.17,.22),CF(top+V(0,.13,0)),color("D5BF7B"));pollen.Shape=Enum.PartType.Ball
    for j=0,2 do local a=j*math.pi*2/3;beam(model,"FlowerStamen",top+V(0,.13,0),top+V(math.cos(a)*.13,.29,math.sin(a)*.13),.027,shade(accent,.25)) end
   elseif family=="Root" then cylinder(model,"EdibleRoot",V(.38,.52,.38),CF(base+V(0,.16,0)),color("BF9568"))
   elseif family=="Pepper" or family=="Seed" then crystal(model,CF(top-V(0,.25,0))*A(0,0,.25),.45,.22,accent,false)
   elseif family=="Herb" then part(model,"HerbBud",V(.23,.32,.23),CF(top),accent,nil,"WedgePart") end
  end
 end
end
local function deposit(model,id,p)
 local accent=ACCENT[id] and color(ACCENT[id]) or p[4]
 local function ellipsoid(object)
  -- Native Ball parts stay spherical. A Sphere SpecialMesh follows the parent
  -- block's three dimensions, preserving long sap runs and flattened nodules.
  object.Shape=Enum.PartType.Block
  local shape=Instance.new("SpecialMesh");shape.MeshType=Enum.MeshType.Sphere;shape.Parent=object
  return object
 end
 if id=="Resin" or id=="DeepResin" then
  cylinder(model,"ResinStump",V(2.15,3.6,2.1),CF(0,1.8,0),p[1],Enum.Material.Wood,true)
  cylinder(model,"CutWood",V(2,.07,1.95),CF(0,3.62,0),shade(p[1],.5))
  local sapColor=id=="DeepResin" and color("D19240") or color("DEB45B")
  for i=0,3 do
   local angle=i*math.pi/2+.3
   local frame=CF()*A(0,angle,0)*CF(0,2.65,1.15)
   ellipsoid(part(model,"BarkWound",V(.58,1.6,.065),frame*CF(0,.12,-.09),shade(p[1],-.32),Enum.Material.Wood))
   -- The sap has real depth outside the 1.075-stud bark radius. Overlapping
   -- rounded drips taper downwards instead of burying a thin oval in the trunk.
   local sap=ellipsoid(part(model,"AmberSapRun",V(.39,1.3,.31),frame*A(0,0,.06),sapColor,Enum.Material.SmoothPlastic));sap.Reflectance=.12
   local trail=ellipsoid(part(model,"AmberSapTrail",V(.23,.8,.26),frame*CF(.065,-.63,-.01)*A(0,0,-.09),shade(sapColor,-.07),Enum.Material.SmoothPlastic));trail.Reflectance=.12
   local bead=ellipsoid(part(model,"ResinBead",V(.38,.49,.35),frame*CF(.085,-.96,.015),shade(sapColor,.12),Enum.Material.SmoothPlastic));bead.Reflectance=.15
   beam(model,"StumpRoot",V(math.sin(angle)*1.55,.12,math.cos(angle)*1.55),V(0,.75,0),.27,p[1])
  end
 elseif id=="Sand" or id=="Peat" or id=="DarkDust" then
  for i=0,2 do mesh(model,"SedimentBank","Rock",V(3-i*.35,.45,2.7-i*.35),CF(i*.13,.22+i*.25,0)*A(0,i*.25,0),id=="Sand" and color("D2B989") or shade(id=="Peat" and p[1] or accent,i*.09)) end
 elseif id=="ShellPlate" or id=="Pearl" or id=="EchoShell" then
  rock(model,V(0,.32,0),V(2.7,.64,2.2),p[4])
  for i=0,4 do part(model,"ShellRib",V(.38,.55,1.7),CF(0,.7,.2)*A(0,(i-2)*.3,0)*CF((i-2)*.19,0,0),shade(WHITE,-i*.045),nil,"WedgePart") end
  if id=="Pearl" then local pearl=part(model,"Pearl",V(.6,.6,.6),CF(0,.92,-.45),WHITE);pearl.Shape=Enum.PartType.Ball end
 elseif id=="OldGear" then
  rock(model,V(0,.5,0),V(2.8,1,2.4),p[4])
  cylinder(model,"RecoveredHub",V(1.5,.25,1.5),CF(0,1.08,0),color("998461"),Enum.Material.Metal)
  for i=0,7 do part(model,"GearTooth",V(.35,.28,.45),CF(0,1.09,0)*A(0,i*math.pi/4,0)*CF(0,0,.82),color("998461"),Enum.Material.Metal) end
 elseif CRYSTALS[id] or CORES[id] then
  rock(model,V(0,.28,0),V(3.1,.56,2.5),p[4])
  crystal(model,CF(0,.2,0)*A(0,.3,-.08),CORES[id] and 2.6 or 2.9,.8,accent,true)
  crystal(model,CF(-.85,.14,.22)*A(0,-.3,.27),1.65,.52,shade(accent,-.15),false)
  crystal(model,CF(.8,.15,.35)*A(0,.6,-.3),1.9,.59,shade(accent,.1),false)
  if CORES[id] then for side=-1,1,2 do rock(model,V(side*.95,.67,-.2),V(1.1,1.34,1.3),shade(p[4],-.25),side*.5) end end
 else
  rock(model,V(0,1.35,0),V(4,2.7,3.7),id=="Coal" and accent or p[4],.24)
  rock(model,V(1.3,.45,.65),V(1.5,.9,1.6),shade(p[4],-.14),1.1)
  if id~="Stone" and id~="MoonRock" and id~="Coal" then
   -- Sit proud of the host rock's bounds: former shallow face slivers were
   -- completely occluded by the larger imported boulder's surface.
   for i=0,3 do
    local angle=i*math.pi/2+.2
    local frame=CF()*A(0,angle,0)*CF(0,1.6+(i%2)*.27,-1.8)*A(-.18,0,.12)
    -- Uneven overlapping nodules expose a mineral seam without flat slab edges.
    ellipsoid(part(model,"ExposedMineral",V(.7,.63,.57),frame,accent,Enum.Material.Metal))
    ellipsoid(part(model,"MineralNodule",V(.42,.45,.4),frame*CF(-.16,.38,-.02)*A(.14,.28,.13),shade(accent,.12),Enum.Material.Metal))
    ellipsoid(part(model,"MineralNodule",V(.44,.51,.43),frame*CF(.17,-.36,.015)*A(-.09,-.23,-.15),shade(accent,-.12),Enum.Material.Metal))
   end
   for side=-1,1,2 do
    ellipsoid(part(model,"MineralCrown",V(.76,.5,.64),CF(side*.48,2.59,-.06)*A(.12,side*.4,.08),shade(accent,.15),Enum.Material.Metal))
   end
  end
 end
end
function Art.CreateResource(id,biome,options)
 options=options or {};options.Yaw=options.Yaw or 0
 local p=PALETTES[biome] or PALETTES.Forest
 local model=Instance.new("Model");model.Name=id
 if id=="Wood" or id=="Ironwood" or id=="Heartwood" then tree(model,id,p,options)
 elseif id=="Cactus" then
  local green=color("839965")
  cylinder(model,"CactusTrunk",V(1.65,6.8,1.65),CF(0,3.4,0),green,nil,true)
  for side=-1,1,2 do
   local y=side==1 and 3.8 or 2.4
   beam(model,"CactusArm",V(0,y,0),V(side*2,y,0),.85,green,true)
   cylinder(model,"CactusTip",V(.85,2.1,.85),CF(side*2,y+.8,0),shade(green,.1),nil,true)
  end
  for i=0,5 do part(model,"CactusSpine",V(.06,.28,.06),CF(.65,.65+i*.94,-.53)*A(.6,0,.2),WHITE,nil,"WedgePart") end
  part(model,"CactusFlower",V(.55,.26,.55),CF(0,6.85,0),color("D5A491"),nil,"WedgePart")
  for i=0,5 do
   local a=i*math.pi/3
   cylinder(model,"CactusRib",V(.14,6.55,.14),CF(math.cos(a)*.8,3.4,math.sin(a)*.8),shade(green,i%2==0 and .12 or -.13))
  end
  for side=-1,1,2 do
   local y=side==1 and 3.8 or 2.4
   cylinder(model,"ArmRib",V(.09,1.95,.09),CF(side*2,y+.8,-.415),shade(green,.2))
   local tip=part(model,"CactusGrowthTip",V(.82,.31,.82),CF(side*2,y+1.88,0),shade(green,.2));tip.Shape=Enum.PartType.Ball
  end
  for i=0,4 do part(model,"CactusPetal",V(.22,.09,.34),CF(0,6.94,0)*A(0,i*math.pi*2/5,0)*CF(0,0,.24),color("DCAAB2"),nil,"WedgePart") end
 elseif id=="Mushroom" or id=="Glowcap" or id=="GlowMushroom" then mushroom(model,id,p)
 elseif PLANTS[id] then plant(model,id,p,PLANTS[id])
 else deposit(model,id,p) end
 model:SetAttribute("ArtStyle","Expedition");model:SetAttribute("ArtVersion",3)
 model:SetAttribute("ArtBiome",biome)
 model.WorldPivot=CF()
 model.PrimaryPart=model:FindFirstChildWhichIsA("BasePart")
 return model
end
return Art
