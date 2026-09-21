-- Visual cladding retains the world's simple, stable traversal colliders.
local Art={}
local Rock=game:GetService("ServerStorage"):WaitForChild("ArtAssets"):WaitForChild("WeatheredBoulder")
local V,CF,A=Vector3.new,CFrame.new,CFrame.Angles
local WHITE=Color3.new(1,1,1)
local timber=Color3.fromRGB(119,91,61)
local metal=Color3.fromRGB(61,68,64)
local optionalDetail={CornerIronStrap=true,DockBinding=true,PostBinding=true,FungalGill=true}
local function part(parent,name,size,frame,color,material,class)
 local p=Instance.new(class or "Part")
 p.Name,p.Size,p.CFrame,p.Color=name,size,frame,color
 p.Material=material or Enum.Material.Slate
 p.Anchored,p.CanCollide,p.CanTouch,p.CanQuery=true,false,false,false
 if optionalDetail[name] then p:SetAttribute("ArtDetail",true) end
 p.TopSurface,p.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
 p.Parent=parent
 return p
end
local function collider(parent,name,size,frame,color)
 local p=part(parent,name,size,frame,color)
 p.Transparency=1;p.CanCollide=true;p.CanTouch=true;p.CanQuery=true
 return p
end
local function rock(parent,name,size,frame,color)
 local p=Rock:Clone()
 p.Name,p.Size,p.CFrame=name,size,frame
 p.Anchored,p.CanCollide,p.CanTouch,p.CanQuery=true,false,false,false
 p.Color=WHITE;p:FindFirstChildOfClass("SurfaceAppearance").Color=WHITE:Lerp(color,.22)
 p.Parent=parent
 return p
end
local function beam(parent,name,from,to,width,color)
 return part(parent,name,V(width,(to-from).Magnitude,width),CFrame.lookAt((from+to)/2,to)*A(math.pi/2,0,0),color,Enum.Material.Wood)
end
local function masonry(source,rows,columns)
 source.Transparency=1
 local size=source.Size
 local h,w=size.Y/rows,size.X/columns
 for y=1,rows do for x=1,columns do
  local c=source.Color:Lerp(WHITE,.035*((x+y)%3))
  part(source.Parent,"DressedMasonry",V(w-.055,h-.055,size.Z+.055),source.CFrame*CF((x-(columns+1)/2)*w,(y-(rows+1)/2)*h,0)*A(0,0,((x+y)%3-1)*.004),c,Enum.Material.Slate)
 end end
end
local function rockColumn(source)
 source.Transparency=1
 for i=1,3 do
  local offset=((i%2)*2-1)*.12
  rock(source.Parent,"WeatheredColumnFace",V(source.Size.X*1.18,source.Size.Y*.4,source.Size.Z*1.14),source.CFrame*CF(offset,(i-2)*source.Size.Y*.31,offset)*A(.025*i,i*.63,.025*(i-2)),source.Color)
 end
end
local function vault(source)
 source.Transparency=1
 for i=1,5 do
  rock(source.Parent,"VaultRockLayer",V(source.Size.X*.25,source.Size.Y*1.22,source.Size.Z*1.05),source.CFrame*CF((i-3)*source.Size.X*.2,math.abs(i-3)*-.18,0)*A(.025*(i%2),i*.42,.025*(i-3)),source.Color)
 end
end
local function planks(source,width)
 source.Transparency=1
 local count=math.clamp(math.ceil(source.Size.Z/width),1,20)
 local step=source.Size.Z/count
 for i=1,count do
  part(source.Parent,"WeatheredPlank",V(source.Size.X,source.Size.Y,step-.06),source.CFrame*CF(0,0,(i-(count+1)/2)*step),source.Color:Lerp(WHITE,.025*(i%3)),Enum.Material.Wood)
 end
end
local function organic(source,name)
 source.Transparency=1
 local visible=part(source.Parent,name,source.Size,source.CFrame,source.Color,Enum.Material.SmoothPlastic)
 visible.Shape=Enum.PartType.Ball
 return visible
end
function Art.BuildCave(model,position,color)
 for side=-1,1,2 do
  rockColumn(collider(model,"Column",V(9,40,9),CF(position+V(side*18,20,0)),color))
 end
 vault(collider(model,"Vault",V(48,7,26),CF(position+V(0,42,0)),color))
end
function Art.BuildRuin(model,position,color)
 local floor=collider(model,"Walkway",V(30,2,12),CF(position+V(0,1,0)),color)
 masonry(floor,1,6)
 for side=-1,1,2 do
  local pillar=collider(model,"BrokenPillar",V(4,16,4),CF(position+V(side*12,8,0)),color)
  masonry(pillar,5,1)
  rock(model,"FracturedCapital",V(4.5,2,4.3),pillar.CFrame*CF(0,7.75,0)*A(.12,side*.4,.06),color)
 end
end
function Art.DressLandmark(model)
 -- Snapshot only the original collider parts, never recursively decorate additions.
 for _,source in ipairs(model:GetChildren()) do
  if not source:IsA("BasePart") then continue end
  local name,size,frame=source.Name,source.Size,source.CFrame
  if name=="CaveButtress" then rockColumn(source)
  elseif name=="EntranceArch" then vault(source)
  elseif name=="Foundation" then masonry(source,1,3)
  elseif name=="BackWall" then masonry(source,4,5)
  elseif name=="DoorJamb" then masonry(source,4,2)
  elseif name=="Roof" then masonry(source,1,5)
  elseif name=="RangerPlatform" or name=="RootApproach" or name=="RaisedWalkway" then
   planks(source,3)
   if name=="RangerPlatform" then
    for side=-1,1,2 do
     beam(model,"PlatformDiagonalBrace",frame:PointToWorldSpace(V(side*11,-5,0)),frame:PointToWorldSpace(V(side*5,-1,0)),.6,timber)
     for z=-1,1,2 do part(model,"CornerIronStrap",V(.3,2.1,1.1),frame*CF(side*13.9,0,z*7),metal,Enum.Material.Metal) end
    end
   elseif name=="RaisedWalkway" then
    for side=-1,1,2 do for z=-1,1,2 do
     local leg=part(model,"DockSupport",V(.8,4,.8),frame*CF(side*4,-2,z*20),timber,Enum.Material.Wood)
     part(model,"DockBinding",V(.9,.2,.9),leg.CFrame*CF(0,1.2,0),metal,Enum.Material.Metal)
    end end
   end
  elseif name=="LivingSupport" or name=="FungalStem" then
   if name=="FungalStem" then
    organic(source,"OrganicFungalStem")
   else
    source.Transparency=1
    local trunk=part(model,"RoundLivingSupport",V(size.Y,size.X,size.Z),frame*A(0,0,math.pi/2),source.Color,Enum.Material.Wood)
    trunk.Shape=Enum.PartType.Cylinder
    for side=-1,1,2 do beam(model,"SupportRootFlare",frame:PointToWorldSpace(V(side*3,-size.Y/2,1)),frame:PointToWorldSpace(V(0,-size.Y*.22,0)),.9,source.Color) end
   end
  elseif name=="FungalRoof" then
   organic(source,"OrganicFungalCap")
   for i=0,3 do part(model,"FungalGill",V(size.X*.72,.18,.23),frame*CF(0,-size.Y*.3,0)*A(0,i*math.pi/4,0),source.Color:Lerp(WHITE,.4),Enum.Material.Fabric) end
  elseif name=="SurveySpire" then
   source.Transparency=1
   part(model,"CrystalColumn",V(size.X,size.Y*.7,size.Z),frame*CF(0,-size.Y*.15,0),source.Color,Enum.Material.Glass)
   for i=0,3 do part(model,"CrystalPoint",V(size.X*.5,size.Y*.3,size.Z*.5),frame*CF(0,size.Y*.35,0)*A(0,i*math.pi/2,0)*CF(size.X*.25,0,size.Z*.25)*A(0,math.pi/2,0),source.Color:Lerp(WHITE,i*.035),Enum.Material.Glass,"CornerWedgePart") end
  elseif name=="Post" then
   for _,y in ipairs({-size.Y*.35,size.Y*.35}) do part(model,"PostBinding",V(size.X+.08,.25,size.Z+.08),frame*CF(0,y,0),metal,Enum.Material.Metal) end
  elseif name=="Beacon" then
   source.Transparency=1
   local orb=part(model,"SurveyBeaconLens",size*.78,frame,source.Color,Enum.Material.Neon);orb.Shape=Enum.PartType.Ball
   for side=-1,1,2 do part(model,"BeaconCage",V(.12,size.Y*.92,.12),frame*CF(side*size.X*.4,0,0),metal,Enum.Material.Metal) end
   for side=-1,1,2 do
    local collar=part(model,"BeaconCollar",V(.16,size.X*.94,size.Z*.94),frame*CF(0,side*size.Y*.36,0)*A(0,0,math.pi/2),metal,Enum.Material.Metal)
    collar.Shape=Enum.PartType.Cylinder
   end
  end
 end
 model:SetAttribute("SceneryArtVersion",1)
end
return Art
