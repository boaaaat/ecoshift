-- Species silhouettes for the complete biome roster; gameplay rig is server-owned.
local Catalog=require(game.ReplicatedStorage.Shared.OverhaulBiomes)
local Art={}
function Art.Create(id)
 local def=Catalog.Creatures[id];if not def then return nil end
 local m=Instance.new("Model");m.Name=id
 local hue=0;for i=1,#id do hue=(hue+string.byte(id,i)*i)%360 end
 local color=Catalog.Biomes[def.Biome].Color:Lerp(Color3.fromHSV(hue/360,.35,.65),.35)
 local heavy=def.Role=="H";local scale=heavy and 1.5 or def.Role=="S" and .55 or def.Role=="N" and .75 or 1
 local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Size=Vector3.new(3,3,4)*scale;root.Transparency=1;root.CanCollide=true;root.Parent=m;m.PrimaryPart=root
 local function limb(name,size,offset,c,shape)
  local p=Instance.new("Part");p.Name=name;p.Size=size*scale;p.CFrame=CFrame.new(offset*scale);p.Color=c or color;p.Material=Enum.Material.SmoothPlastic;p.CanCollide=false;p.Massless=true;p.Parent=m
  if shape then p.Shape=shape end
  local weld=Instance.new("WeldConstraint");weld.Part0=root;weld.Part1=p;weld.Parent=p
  return p
 end
 local snake=id:find("Snake") or id:find("Serpent") or id:find("Eel") or id=="Leech" or id=="Burrower"
 local insect=id:find("Spider") or id:find("Mite") or id:find("Beetle") or id:find("Crab") or id=="Scorpion"
 local winged=id:find("Owl") or id:find("Bat") or id:find("Moth") or id=="Heron" or id=="Sandpiper"
 local humanoid=id:find("Guard") or id:find("Golem") or id:find("Wraith") or id=="RootGuardian"
 local shell=id:find("Crawler") or id:find("back") or id=="Shellback" or id=="MossSnail"
 if snake then
  for i=1,6 do limb("Segment"..i,Vector3.new(1.5,1.4,1.7),Vector3.new(math.sin(i)*.5,-.6,(i-3)*1.15),color:Lerp(Color3.new(.3,.3,.3),i/15),Enum.PartType.Ball) end
  limb("RaisedHead",Vector3.new(2,1.3,2),Vector3.new(0,.3,-3),color)
 elseif insect then
  limb("Shell",Vector3.new(3,2,4),Vector3.new(0,0,0),color,Enum.PartType.Ball)
  for side=-1,1,2 do for i=1,4 do limb("Leg",Vector3.new(2,.35,.4),Vector3.new(side*2,-.8,i-2.5),color:Lerp(Color3.new(0,0,0),.25)) end end
  if id=="Scorpion" then for i=1,3 do limb("Tail",Vector3.new(.7,.7,1),Vector3.new(0,i*.7,2+i*.35),color) end end
 elseif winged then
  limb("Breast",Vector3.new(2,2,3),Vector3.zero,color,Enum.PartType.Ball)
  for side=-1,1,2 do limb("Wing",Vector3.new(4,.35,3),Vector3.new(side*2.3,.4,0),color:Lerp(Color3.new(.8,.8,.8),.2)) end
  limb("Beak",Vector3.new(.5,.5,1.4),Vector3.new(0,.2,-2),Color3.fromRGB(205,169,77))
 elseif humanoid then
  limb("Torso",Vector3.new(3.3,4,2.5),Vector3.new(0,.5,0),color)
  for side=-1,1,2 do limb("Arm",Vector3.new(1.3,4,1.4),Vector3.new(side*2.3,0,0),color);limb("Leg",Vector3.new(1.2,2,1.5),Vector3.new(side*.9,-2,0),color) end
  limb("Crest",Vector3.new(2,2,2),Vector3.new(0,3.5,0),color:Lerp(Color3.new(.8,.8,.9),.2))
 else
  limb("Body",Vector3.new(3,2.5,5),Vector3.zero,color,Enum.PartType.Ball)
  for side=-1,1,2 do for z=-1,1,2 do limb("Leg",Vector3.new(.8,2,.8),Vector3.new(side*1.1,-1.7,z*1.6),color) end end
  if shell then limb("Carapace",Vector3.new(4,2.4,5.3),Vector3.new(0,1,0),color:Lerp(Color3.new(.35,.35,.4),.4),Enum.PartType.Ball) end
  if id:find("Hare") then for side=-1,1,2 do limb("Ear",Vector3.new(.5,2.5,.7),Vector3.new(side*.7,2,-2.5),color) end end
  if id:find("Stag") or id:find("Deer") or id:find("Ram") or id:find("Goat") then for side=-1,1,2 do limb("Antler",Vector3.new(.4,3,.5),Vector3.new(side*.9,2.5,-2.2),Color3.fromRGB(194,185,151)) end end
 end
 limb("Head",Vector3.new(1.8,1.7,1.8),Vector3.new(0,.7,-2.6),color,Enum.PartType.Ball)
 for side=-1,1,2 do local eye=limb("Eye",Vector3.new(.25,.25,.2),Vector3.new(side*.5,1,-3.45),Color3.fromRGB(234,207,114));eye.Material=Enum.Material.Neon end
 local hum=Instance.new("Humanoid");hum.Name="Humanoid";hum.RequiresNeck=false;hum.BreakJointsOnDeath=false;hum.UseJumpPower=false;hum.JumpHeight=7;hum.HipHeight=1.5*scale;hum.MaxHealth=72;hum.Health=72
 hum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
 hum.HealthDisplayType=Enum.HumanoidHealthDisplayType.AlwaysOff
 hum.NameDisplayDistance=0;hum.HealthDisplayDistance=0;hum.Parent=m
 m:SetAttribute("EntityId",id);m:SetAttribute("EntityType",def.Role=="N" and "Animal" or "Monster");m:SetAttribute("CreatureRole",def.Role);m:SetAttribute("AIClass","OverhaulCreature");m:SetAttribute("OverhaulCreature",true);m:SetAttribute("DisplayName",def.Name)
 return m
end
return Art
