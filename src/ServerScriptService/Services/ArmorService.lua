-- Four independent equipment slots; gameplay protection is calculated by GearService.
local Players=game:GetService("Players")
local Inventory=require(script.Parent.InventoryService)
local Gear=require(script.Parent.GearService)
local ArmorArt=require(script.Parent.Parent.Art.ExpeditionArmor)
local Service={}
local mounted=setmetatable({}, {__mode="k"})
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
   ArmorArt.Mount(folder,char,i,def.Set,entry.Id,(entry.Durability or 0)<=0)
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
