-- InventoryActionService.lua
-- Handles client requests to move/swap inventory slots.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local InventoryService = require(script.Parent.InventoryService)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)
local StatsService = require(script.Parent.StatsService)
local ToolService = require(script.Parent.ToolService)

local InventoryActionService = {}

local FOOD_RESTORE = {
	RawMeat = 10,
	CookedMeat = 25,
	CactusFlesh = 8,
	Meal_Stew = 40,
	CactusJuice = 15,
	DesertSalve = 5,
}

local function canConsume(item)
	if not item then return false end
	return item:HasTag("Food") or item:HasTag("Consumable")
end

local function applyFood(plr, itemId)
	local restore = FOOD_RESTORE[itemId] or 0
	if restore <= 0 then return false end
	if not StatsService then return false end
	local maxHunger = StatsService:GetStat(plr, "MaxHunger") or 100
	local curHunger = StatsService:GetBase(plr, "Hunger") or StatsService:GetStat(plr, "Hunger") or 0
	local newHunger = math.min(maxHunger, curHunger + restore)
	StatsService:SetBase(plr, "Hunger", newHunger)
	return true
end

function InventoryActionService:Init()
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	local remote = Util.GetRemote(remotesFolder, Config.RemoteNames.InventoryAction)
	if not remote then return end
	remote.OnServerEvent:Connect(function(plr, action, payload)
		if action == "Move" and type(payload) == "table" then
			print(string.format("[InventoryAction] Move %s: %s[%s] -> %s[%s]", plr.Name, tostring(payload.FromType), tostring(payload.FromIndex), tostring(payload.ToType), tostring(payload.ToIndex)))
			InventoryService:Move(plr, payload.FromType, payload.FromIndex, payload.ToType, payload.ToIndex)
			return
		end
		if action == "Split" and type(payload) == "table" then
			print(string.format("[InventoryAction] Split %s: %s[%s]", plr.Name, tostring(payload.FromType), tostring(payload.FromIndex)))
			InventoryService:Split(plr, payload.FromType, payload.FromIndex, payload.ToType, payload.ToIndex, payload.Amount)
			return
		end
		if action == "Use" and type(payload) == "table" then
			local slotType = payload.SlotType
			local slotIndex = payload.SlotIndex
			if not slotType or typeof(slotIndex) ~= "number" then return end
			local inv = InventoryService:GetAll(plr)
			local slot = inv and ((slotType == "Hotbar" and inv.Hotbar and inv.Hotbar[slotIndex])
				or (slotType == "Storage" and inv.Storage and inv.Storage[slotIndex])
				or (slotType == "Armor" and inv.Armor)) or nil
			if not slot then return end
			local item = ItemDatabase:Get(slot.Id)
			if not canConsume(item) then return end
			if InventoryService:TakeFromSlot(plr, slotType, slotIndex, 1) then
				applyFood(plr, slot.Id)
			end
			return
		end
		if action == "Equip" and type(payload) == "table" then
			local slotType = payload.SlotType
			local slotIndex = payload.SlotIndex
			print(string.format("[InventoryAction] Equip request %s slot %s[%s]", plr.Name, tostring(slotType), tostring(slotIndex)))
			if slotType ~= "Hotbar" or typeof(slotIndex) ~= "number" then return end
			
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hum then
				warn(string.format("[InventoryAction] No Humanoid for %s", plr.Name))
				return
			end
			
			local inv = InventoryService:GetAll(plr)
			local slot = inv and inv.Hotbar and inv.Hotbar[slotIndex]
			
			-- If clicking an empty slot or non-tool slot, unequip current tool
			if not slot then
				print(string.format("[InventoryAction] Empty slot %s clicked, unequipping for %s", tostring(slotIndex), plr.Name))
				hum:UnequipTools()
				return
			end

			local item = ItemDatabase:Get(slot.Id)
			if item and canConsume(item) then
				if InventoryService:TakeFromSlot(plr, "Hotbar", slotIndex, 1) then
					applyFood(plr, slot.Id)
				end
				return
			end
			if not item or not item:HasTag("Holdable") then
				print(string.format("[InventoryAction] Slot %s is not holdable, unequipping for %s", tostring(slotIndex), plr.Name))
				hum:UnequipTools()
				return
			end
			
			local backpack = plr:FindFirstChildOfClass("Backpack")
			local tool = (char and char:FindFirstChild(slot.Id)) or (backpack and backpack:FindFirstChild(slot.Id))
			if not tool then
				ToolService:Sync(plr)
				backpack = plr:FindFirstChildOfClass("Backpack")
				tool = (char and char:FindFirstChild(slot.Id)) or (backpack and backpack:FindFirstChild(slot.Id))
			end
			if tool and tool:IsA("Tool") then
				hum:EquipTool(tool)
				print(string.format("[InventoryAction] Equipped %s for %s", slot.Id, plr.Name))
			else
				warn(string.format("[InventoryAction] Tool %s not found for %s", slot.Id, plr.Name))
			end
			return
		end
	end)
end

return InventoryActionService
