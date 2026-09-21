-- Layered armor decoration. Protection and equipment state stay in GearService.
-- Sizes and offsets are fractions of each mounted body part; joints remain avatar-owned.
local Art = {}
local V, RGB, M = Vector3.new, Color3.fromRGB, Enum.Material
local optionalDetail={TempleFastener=true,CoatFastener=true,HemBinding=true,BootLacing=true,ThighFold=true,StrapBuckle=true}
-- Cloth, edging, hardware, motif. Sixteen current sets plus the two standalone coats.
local sets = {
 Trail={RGB(94,120,76),RGB(197,173,117),RGB(73,59,43),"Field"},
 Dune={RGB(191,156,98),RGB(232,211,159),RGB(112,77,48),"Wrap"},
 Marsh={RGB(76,110,90),RGB(170,179,115),RGB(53,68,59),"Reed"},
 Frost={RGB(137,177,193),RGB(226,225,205),RGB(71,103,123),"Fur"},
 Ash={RGB(82,70,69),RGB(198,123,76),RGB(43,44,50),"Plate"},
 Crystal={RGB(125,108,164),RGB(191,221,226),RGB(65,61,92),"Prism"},
 Aurora={RGB(92,151,153),RGB(196,221,209),RGB(69,88,108),"Fur"},
 Meteor={RGB(92,94,115),RGB(201,155,106),RGB(48,49,64),"Plate"},
 Coast={RGB(88,149,158),RGB(225,211,166),RGB(47,83,101),"Shell"},
 Storm={RGB(91,126,159),RGB(198,211,208),RGB(55,75,94),"Storm"},
 Garden={RGB(122,149,91),RGB(201,184,140),RGB(67,83,58),"Leaf"},
 Iron={RGB(124,98,79),RGB(173,154,120),RGB(61,64,67),"Plate"},
 Canopy={RGB(64,108,66),RGB(172,174,102),RGB(40,63,44),"Leaf"},
 Diver={RGB(63,108,120),RGB(173,204,203),RGB(44,68,80),"Diver"},
 Lantern={RGB(116,136,84),RGB(219,198,115),RGB(54,68,57),"Lamp"},
 Moon={RGB(141,138,169),RGB(214,215,234),RGB(70,71,98),"Moon"},
 SunVest={RGB(209,175,109),RGB(242,222,173),RGB(115,84,48),"Vest"},
 DesertCoat={RGB(186,149,94),RGB(230,207,154),RGB(103,75,46),"Wrap"},
}

function Art.Mount(folder, character, slot, setId, itemId, broken)
 local style = sets[setId or itemId]
 if not style then return end
 local cloth, trim, hardware, motif = style[1], style[2], style[3], style[4]
 if broken then
  cloth, trim, hardware = RGB(80,77,72),RGB(118,108,91),RGB(62,59,56)
 end
 local plated = motif == "Plate" or motif == "Prism" or motif == "Moon" or motif == "Diver"
 local surface = plated and M.Metal or M.Fabric
 local function mount(body, name, size, offset, color, material, wedge, rotation)
  if not body or not body:IsA("BasePart") then return end
  local p = Instance.new(wedge and "WedgePart" or "Part")
  p.Name = name
  p.Size = body.Size * size
  p.CFrame = body.CFrame * CFrame.new(body.Size * offset) * (rotation or CFrame.identity)
  p.Color, p.Material = color, material or surface
  p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
  if optionalDetail[name] then p:SetAttribute("ArtDetail",true) end
  p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
  p.Parent = folder
  local weld = Instance.new("WeldConstraint")
  weld.Part0, weld.Part1, weld.Parent = body, p, p
  return p
 end
 if slot == 1 then
  local head = character:FindFirstChild("Head")
  mount(head,"HoodCrown",V(1.07,.24,1.09),V(0,.49,.015),cloth)
  mount(head,"HoodBack",V(1.05,.6,.13),V(0,.15,.49),cloth)
  for side=-1,1,2 do mount(head,"HoodSide",V(.13,.65,.75),V(side*.49,.16,.08),cloth) end
  if motif == "Fur" then
   mount(head,"FurBrow",V(1.1,.22,.2),V(0,.37,-.5),trim,M.Fabric)
   for side=-1,1,2 do mount(head,"FurCheek",V(.16,.6,.2),V(side*.5,.05,-.43),trim,M.Fabric) end
  elseif motif == "Diver" or motif == "Moon" then
   mount(head,"VisorRim",V(.86,.38,.1),V(0,.02,-.55),hardware,M.Metal)
   local glass = mount(head,"Visor",V(.74,.26,.06),V(0,.02,-.61),trim,M.Glass)
   if glass then glass.Transparency = .35 end
   mount(head,"Breather",V(.3,.16,.18),V(0,-.22,-.58),hardware,M.Metal)
  elseif motif == "Lamp" then
   mount(head,"LampBand",V(1.11,.13,1.12),V(0,.32,0),hardware)
   mount(head,"LampHousing",V(.24,.32,.19),V(0,.32,-.62),hardware,M.Metal)
   mount(head,"LampLens",V(.16,.2,.07),V(0,.32,-.75),trim,broken and M.SmoothPlastic or M.Neon)
  elseif motif == "Wrap" or motif == "Reed" then
   mount(head,"SunBrim",V(1.22,.09,1.36),V(0,.4,-.1),trim)
   mount(head,"WrapBand",V(1.09,.12,1.12),V(0,.32,0),hardware)
  elseif motif == "Leaf" then
   for side=-1,1,2 do mount(head,"LeafBrow",V(.53,.25,.22),V(side*.26,.43,-.52),trim,M.Fabric,true,CFrame.Angles(0,0,-side*.17)) end
  elseif motif == "Prism" then
   mount(head,"PrismBrow",V(.28,.5,.2),V(0,.61,-.37),trim,M.Slate,true)
  else
   mount(head,"BrowTrim",V(1.08,.12,.18),V(0,.39,-.5),trim)
   if plated then mount(head,"HelmetRidge",V(.15,.12,.96),V(0,.64,.04),hardware,M.Metal) end
  end
  for side=-1,1,2 do
   mount(head,"TempleBinding",V(.145,.1,.65),V(side*.515,.25,.05),hardware,plated and M.Metal or M.Fabric)
   mount(head,"TempleFastener",V(.04,.09,.09),V(side*.592,.25,-.14),trim,M.Metal)
   mount(head,plated and "AngledCheekPlate" or "HoodFold",V(.15,.32,.42),V(side*.51,-.02,.15),cloth:Lerp(trim,.16),surface,true,CFrame.Angles(0,0,-side*.12))
  end
 elseif slot == 2 then
  local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
  local vest = motif == "Vest"
  mount(torso,"CoatFront",V(vest and .84 or 1.02,.78,.13),V(0,-.035,-.53),cloth)
  mount(torso,"CoatBack",V(.98,.78,.12),V(0,-.035,.53),cloth)
  for side=-1,1,2 do
   mount(torso,"Harness",V(.085,.73,.045),V(side*.29,.015,-.62),hardware,M.Fabric)
  end
  mount(torso,"WaistBelt",V(1.045,.11,1.11),V(0,-.34,0),hardware,M.Fabric)
  if motif == "Diver" then
   mount(torso,"PressureGauge",V(.18,.23,.13),V(.17,.12,-.66),trim,M.Metal)
   for side=-1,1,2 do mount(torso,"AirCylinder",V(.23,.67,.29),V(side*.24,.02,.7),trim,M.Metal) end
  elseif motif == "Leaf" or motif == "Shell" or motif == "Prism" then
   mount(torso,"Clasp",V(.16,.18,.07),V(0,.24,-.65),trim,M.Slate,motif == "Prism",CFrame.Angles(0,0,math.pi/4))
   for side=-1,1,2 do mount(torso,"LayeredMantle",V(.5,.29,.15),V(side*.26,.32,-.58),trim,surface,true,CFrame.Angles(0,0,-side*.13)) end
  elseif motif == "Fur" or motif == "Storm" then
   mount(torso,"Fastener",V(.09,.56,.05),V(0,.035,-.63),trim,M.Metal)
   for side=-1,1,2 do mount(torso,"PaddedCollar",V(.39,.18,.28),V(side*.27,.39,-.38),trim,M.Fabric) end
  else
   mount(torso,"Buckle",V(.15,.12,.08),V(0,-.34,-.62),trim,M.Metal)
   if plated then
    for side=-1,1,2 do mount(torso,"ChestPlate",V(.39,.46,.12),V(side*.24,.11,-.64),trim,M.Metal,true,CFrame.Angles(0,0,side*.08)) end
   else
    for side=-1,1,2 do mount(torso,"FieldPocket",V(.23,.22,.14),V(side*.28,-.15,-.65),trim,M.Fabric) end
   end
  end
  for side=-1,1,2 do
   mount(torso,"ShoulderYoke",V(.36,.12,.94),V(side*.32,.435,0),cloth:Lerp(trim,.2),surface,true,CFrame.Angles(0,0,-side*.06))
   mount(torso,"HarnessSlide",V(.125,.095,.06),V(side*.29,.15,-.654),trim,M.Metal)
   mount(torso,"HemBinding",V(.39,.04,.025),V(side*.28,-.415,-.61),trim,M.Fabric)
   if plated then
    mount(torso,"OverlappingWaistPlate",V(.45,.17,.08),V(side*.25,-.245,-.66),cloth:Lerp(hardware,.3),M.Metal,true)
   else
    mount(torso,"PocketFlap",V(.25,.07,.035),V(side*.28,-.045,-.735),cloth,M.Fabric,true)
   end
  end
  for i=0,2 do mount(torso,"CoatFastener",V(.033,.035,.024),V(0,.18-i*.17,-.613),trim,M.Metal) end
 elseif slot == 3 then
  for _, name in ipairs({"LeftUpperLeg","RightUpperLeg","Left Leg","Right Leg"}) do
   local leg = character:FindFirstChild(name)
   local side = name:find("Left") and -1 or 1
   mount(leg,"TrouserPanel",V(1.055,.69,1.06),V(0,.02,0),cloth)
   mount(leg,"OuterSeam",V(.07,.64,.1),V(side*.52,.02,-.51),trim)
   mount(leg,"ThighStrap",V(1.07,.1,1.08),V(0,.19,0),hardware,M.Fabric)
   mount(leg,plated and "KneePlate" or "KneePatch",V(.72,.24,.15),V(0,-.22,-.56),trim,plated and M.Metal or M.Fabric,plated)
   mount(leg,"StrapBuckle",V(.17,.09,.05),V(side*.29,.19,-.565),trim,M.Metal)
   mount(leg,"KneeBinding",V(.65,.035,.024),V(0,-.12,-.642),hardware,plated and M.Metal or M.Fabric)
   mount(leg,"ThighFold",V(.57,.045,.025),V(-side*.1,.06,-.545),cloth:Lerp(trim,.18),surface,false,CFrame.Angles(0,0,side*.08))
  end
 elseif slot == 4 then
  local function boot(body, r6)
   -- R6 boots occupy the bottom of the leg; R15 boots follow the independent foot.
   local height, y = r6 and .3 or 1.08, r6 and -.35 or 0
   mount(body,"Boot",V(1.08,height,1.14),V(0,y,0),cloth)
   mount(body,"Sole",V(1.12,r6 and .06 or .18,1.2),V(0,r6 and -.48 or -.49,-.015),hardware,M.SmoothPlastic)
   mount(body,"ToeCap",V(1.1,r6 and .13 or .42,.29),V(0,r6 and -.415 or -.2,-.53),trim,plated and M.Metal or M.SmoothPlastic,true)
   mount(body,"Cuff",V(1.12,r6 and .07 or .2,1.18),V(0,r6 and -.23 or .35,0),motif == "Fur" and trim or hardware,M.Fabric)
   for i=0,2 do
    mount(body,"BootLacing",V(.54,r6 and .018 or .045,.035),V(0,(r6 and -.29 or .2)-i*(r6 and .035 or .12),-.587),hardware,M.Fabric,false,CFrame.Angles(0,0,(i%2==0 and .12 or -.12)))
   end
  end
  for _, name in ipairs({"LeftFoot","RightFoot"}) do boot(character:FindFirstChild(name),false) end
  for _, name in ipairs({"Left Leg","Right Leg"}) do boot(character:FindFirstChild(name),true) end
 end
end

function Art.CreateDisplay(itemId,definition)
 if not definition or definition.Kind~="Armor" then return nil end
 local slot=({Head=1,Chest=2,Legs=3,Boots=4})[definition.Slot]
 if not slot then return nil end
 local rig=Instance.new("Model")
 for _,entry in ipairs({{"Head",V(2,1,1),V(0,2.5,0)},{"Torso",V(2,2,1),V(0,1,0)},
  {"Left Leg",V(1,2,1),V(-.5,-1,0)},{"Right Leg",V(1,2,1),V(.5,-1,0)}}) do
  local body=Instance.new("Part");body.Name,body.Size,body.Position=entry[1],entry[2],entry[3];body.Parent=rig
 end
 local model=Instance.new("Model");model.Name=itemId
 Art.Mount(model,rig,slot,definition.Set,itemId,false)
 local primary=model:FindFirstChildWhichIsA("BasePart")
 if not primary then rig:Destroy();model:Destroy();return nil end
 for _,object in ipairs(model:GetDescendants()) do if object:IsA("WeldConstraint") then object:Destroy() end end
 for _,object in ipairs(model:GetChildren()) do
  if object:IsA("BasePart") then
   object.Anchored=true
   if object~=primary then
    local weld=Instance.new("WeldConstraint");weld.Part0,weld.Part1,weld.Parent=primary,object,object
   end
  end
 end
 model.PrimaryPart=primary
 local frame,size=model:GetBoundingBox()
 model:PivotTo(CFrame.new(0,size.Y/2,0)*frame:Inverse()*model:GetPivot())
 model:SetAttribute("ArtStyle","Expedition");model:SetAttribute("ArtVersion",4)
 rig:Destroy()
 return model
end
return Art
