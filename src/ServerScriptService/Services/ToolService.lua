-- ToolService.lua
-- Syncs inventory tool items to player Backpack/Character.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local InventoryService = require(script.Parent.InventoryService)
local ItemDatabase = require(game:GetService("ReplicatedStorage").Shared.Items.ItemDatabase)

local Instances=require(game:GetService("ReplicatedStorage").Shared.ItemInstance)
local ToolService = {}
local HOTBAR_SLOTS = 6

local function isHoldable(itemId)
	local item = ItemDatabase:Get(itemId)
	return item and item:HasTag("Holdable") or false
end

function ToolService:Sync(plr)
 local inv=InventoryService:GetAll(plr);local backpack=plr:FindFirstChildOfClass("Backpack")
 if not backpack then return end
 local desired={}
 for i,entry in pairs(inv.Hotbar) do if entry and isHoldable(entry.Id) then desired[entry.Uid or entry.Id]=entry end end
 local existing={}
 for _,container in ipairs({backpack,plr.Character}) do
  if container then for _,tool in ipairs(container:GetChildren()) do
   if tool:IsA("Tool") then local key=tool:GetAttribute("GearUid") or tool.Name;if not desired[key] or existing[key] then tool:Destroy() else existing[key]=tool end end
  end end
 end
 for key,entry in pairs(desired) do
  local tool=existing[key]
  if not tool then
   local templates=ServerStorage:FindFirstChild("Tools");local template=templates and templates:FindFirstChild(entry.Id)
   if template and template:IsA("Tool") then tool=template:Clone() else
    tool=Instance.new("Tool");tool.Name=entry.Id
    local handle=Instance.new("Part");handle.Name="Handle";handle.Size=Vector3.new(.35,2.8,.35);handle.Color=Color3.fromRGB(112,91,63);handle.CanCollide=false;handle.Massless=true;handle.Parent=tool
    local head=Instance.new("Part");head.Name="Head";head.Size=Vector3.new(1.2,.65,.3);head.Color=Color3.fromRGB(149,165,151);head.CanCollide=false;head.Massless=true;head.CFrame=handle.CFrame*CFrame.new(0,1.1,0);head.Parent=tool
    local weld=Instance.new("WeldConstraint");weld.Part0=handle;weld.Part1=head;weld.Parent=handle
   end
   tool.CanBeDropped=false
  end
  local def=Instances.Definition(entry.Id)
  tool:SetAttribute("GearUid",entry.Uid);tool:SetAttribute("GearGrade",entry.Grade);tool:SetAttribute("Durability",entry.Durability);tool:SetAttribute("MaxDurability",entry.MaxDurability)
  if def then
   tool:SetAttribute("Damage",(entry.Durability or 1)>0 and def.Damage or 0)
   tool:SetAttribute("Range",def.Reach or 8);tool:SetAttribute("AttackSpeed",1/(def.AttackCycle or 1))
   local power=def.Power and def.Power*(entry.Id=="Harvester" and 1 or 2^((entry.Grade or def.Grade)-def.Grade))
   tool:SetAttribute("ToolPower",power);tool:SetAttribute("MiningGrade",entry.Grade);tool:SetAttribute("ToolFamily",def.ToolFamily)
   if def.Kind=="Tool" then
    tool:SetAttribute("WeaponType",nil);tool:SetAttribute("ToolType",def.ToolFamily or "Universal");tool:SetAttribute("CombatDamage",entry.Id=="Harvester" and 6 or 0);tool:SetAttribute("HarvestPower",power);tool:SetAttribute("CombatRange",8)
   else
    local weaponType=def.WeaponFamily=="Bow" and "Bow" or def.WeaponFamily=="Staff" and "Gun" or "Sword"
    tool:SetAttribute("ToolType",nil);tool:SetAttribute("WeaponType",weaponType)
    -- Old model value objects cannot override the current-rules profile.
    for _,name in ipairs({"Damage","Range","AttackSpeed","WeaponType","ToolType","CombatDamage","Ammo"}) do local child=tool:FindFirstChild(name);if child and child:IsA("ValueBase") then child:Destroy() end end
   end
  end
  if not tool.Parent then tool.Parent=backpack end
 end
end
function ToolService:Init()
	if self._initialized then return end
	self._initialized = true
	InventoryService:OnChanged(function(plr)
		ToolService:Sync(plr)
	end)
	local function bindPlayer(plr)
		local function syncCharacter()
			local backpack = plr:WaitForChild("Backpack", 10)
			if not backpack then
				warn(string.format("[ToolService] No Backpack for %s", plr.Name))
				return
			end
			ToolService:Sync(plr)
		end
		plr.CharacterAdded:Connect(function()
			task.defer(syncCharacter)
		end)
		task.spawn(syncCharacter)
	end
	Players.PlayerAdded:Connect(bindPlayer)
	for _, plr in ipairs(Players:GetPlayers()) do
		bindPlayer(plr)
	end
end

return ToolService
