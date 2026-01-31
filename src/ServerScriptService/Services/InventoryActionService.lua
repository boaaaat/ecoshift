-- InventoryActionService.lua
-- Handles client requests to move/swap inventory slots.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local InventoryService = require(script.Parent.InventoryService)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)
local ToolService = require(script.Parent.ToolService)

local InventoryActionService = {}

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
			if not item or not item:HasTag("Tool") then
				print(string.format("[InventoryAction] Slot %s is not a tool, unequipping for %s", tostring(slotIndex), plr.Name))
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
