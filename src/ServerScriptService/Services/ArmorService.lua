-- Four independent equipment slots; gameplay protection is calculated by GearService.
local Players=game:GetService("Players")
local Inventory=require(script.Parent.InventoryService)
local Gear=require(script.Parent.GearService)
local Service={}
local mounted=setmetatable({}, {__mode="k"})
local palettes={Trail=Color3.fromRGB(101,126,80),Dune=Color3.fromRGB(194,163,107),Marsh=Color3.fromRGB(83,117,94),Frost=Color3.fromRGB(166,200,213),Ash=Color3.fromRGB(105,81,75),Crystal=Color3.fromRGB(155,134,193),Aurora=Color3.fromRGB(114,190,186),Meteor=Color3.fromRGB(108,111,126),Coast=Color3.fromRGB(116,170,178),Storm=Color3.fromRGB(111,144,173),Garden=Color3.fromRGB(136,164,102),Iron=Color3.fromRGB(127,106,91),Canopy=Color3.fromRGB(78,122,73),Diver=Color3.fromRGB(85,126,134),Lantern=Color3.fromRGB(140,158,101),Moon=Color3.fromRGB(166,164,194)}
local function plate(folder,body,color,scale,offset)
 if not body or not body:IsA("BasePart") then return end
 local piece=Instance.new("Part");piece.Name=body.Name.."Plate";piece.Size=Vector3.new(body.Size.X*scale.X,body.Size.Y*scale.Y,body.Size.Z*scale.Z);piece.Color=color;piece.Material=Enum.Material.SmoothPlastic
 piece.CFrame=body.CFrame*(offset or CFrame.new());piece.CanCollide=false;piece.CanQuery=false;piece.CanTouch=false;piece.Massless=true;piece.Parent=folder
 local weld=Instance.new("WeldConstraint");weld.Part0=body;weld.Part1=piece;weld.Parent=piece
end
function Service:Sync(player)
 Gear:Refresh(player)
 local char=player.Character;if not char then return end
 local inv=Inventory:GetAll(player);local signature={}
 for i=1,4 do local entry=(inv.Equipment or {})[i];signature[i]=entry and (entry.Uid..":"..tostring((entry.Durability or 0)>0)) or "" end
 local key=table.concat(signature,"/")
 if mounted[player] and mounted[player].Character==char and mounted[player].Key==key then return end
 local old=char:FindFirstChild("EquippedArmor");if old then old:Destroy() end
 local folder=Instance.new("Folder");folder.Name="EquippedArmor";folder.Parent=char
 for i,entry in pairs(inv.Equipment or {}) do
  local def=Gear:GetDefinition(entry)
  if def then
   local color=(entry.Durability or 0)>0 and (palettes[def.Set] or palettes.Dune) or Color3.fromRGB(80,77,72)
   if i==1 then plate(folder,char:FindFirstChild("Head"),color,Vector3.new(1.08,.48,1.08),CFrame.new(0,.3,0))
   elseif i==2 then plate(folder,char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"),color,Vector3.new(1.04,.82,1.08))
   elseif i==3 then
    for _,name in ipairs({"LeftUpperLeg","RightUpperLeg","Left Leg","Right Leg"}) do plate(folder,char:FindFirstChild(name),color,Vector3.new(1.05,.76,1.05)) end
   elseif i==4 then
    for _,name in ipairs({"LeftFoot","RightFoot"}) do plate(folder,char:FindFirstChild(name),color,Vector3.new(1.1,1.08,1.15)) end
    for _,name in ipairs({"Left Leg","Right Leg"}) do plate(folder,char:FindFirstChild(name),color,Vector3.new(1.08,.3,1.15),CFrame.new(0,-.7,0)) end
   end
  end
 end
 mounted[player]={Key=key,Character=char}
end
function Service:Init()
 if self.Initialized then return end;self.Initialized=true
 Inventory:OnChanged(function(player)self:Sync(player)end)
 local function bind(player)
  player.CharacterAdded:Connect(function()task.defer(function()self:Sync(player)end)end)
  player.CharacterAppearanceLoaded:Connect(function()mounted[player]=nil;self:Sync(player)end)
  self:Sync(player)
 end
 Players.PlayerAdded:Connect(bind);for _,player in ipairs(Players:GetPlayers()) do bind(player)end
 Players.PlayerRemoving:Connect(function(player)mounted[player]=nil end)
end
return Service
