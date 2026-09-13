-- Server-owned inventory movement and overhaul consumable dispatch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Catalog = require(ReplicatedStorage.Shared.OverhaulCatalog)
local InventoryService = require(script.Parent.InventoryService)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)
local ToolService = require(script.Parent.ToolService)
local FoodService = require(script.Parent.FoodService)
local InventoryActionService = {}
local function canConsume(item)
 return item and (item.Id=="WaterFlask" or FoodService:CanConsume(item.Id)
  or (Catalog.Consumables[item.Id] and item.Id~="RevivalKit"))
end
local function canAct(plr)
 if ReplicatedStorage:GetAttribute("WorldRestoring") or plr:GetAttribute("WorldPlayerRestoring")
  or plr:GetAttribute("WorldPlayerLoading") or plr:GetAttribute("IsDead") then return nil end
 local char=plr.Character
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not hum or hum.Health<=0 then return nil end
 return char,hum
end
function InventoryActionService:_consumeFromSlot(plr,slotType,slotIndex,callback)
 if not canAct(plr) then return false,"You cannot use items right now." end
 local slot=InventoryService:PeekSlot(plr,slotType,slotIndex)
 local item=slot and ItemDatabase:Get(slot.Id)
 if not canConsume(item) then return false,"This item cannot be consumed." end
 if item.Id=="WaterFlask" then return require(script.Parent.GearService):DrinkFlask(plr) end
 if Catalog.Consumables[item.Id] then return require(script.Parent.GearService):UseMedical(plr,slotType,slotIndex,callback) end
 return FoodService:Consume(plr,slotType,slotIndex,callback)
end

function InventoryActionService:_sendUseResult(plr, success, message)
	if self._remote then
		self._remote:FireClient(plr, "UseResult", { Success = success, Message = message })
	end
end

function InventoryActionService:UseHeld(plr, tool)
	local char = canAct(plr)
	if not char or not tool or not tool:IsA("Tool") or tool.Parent ~= char then return end
	local slotIndex = tool:GetAttribute("InventorySlotIndex")
	local expectedId = tool:GetAttribute("InventoryItemId")
	if typeof(slotIndex) ~= "number" or slotIndex % 1 ~= 0 or slotIndex < 1 or slotIndex > 6 then return end
	local slot = InventoryService:PeekSlot(plr, "Hotbar", slotIndex)
	if not slot or slot.Id ~= expectedId or (slot.Uid and slot.Uid ~= tool:GetAttribute("GearUid")) then return end
	local item = ItemDatabase:Get(slot.Id)
	if not canConsume(item) then return end
	local success, message = self:_consumeFromSlot(plr, "Hotbar", slotIndex, function(completed, result)
		self:_sendUseResult(plr, completed, result)
	end)
	self:_sendUseResult(plr, success, message)
end

function InventoryActionService:Init()
	if self._initialized then return end
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	local remote = Util.GetRemote(remotesFolder, Config.RemoteNames.InventoryAction)
	if not remote then return end
	self._initialized = true
	self._remote = remote
	remote.OnServerEvent:Connect(function(plr, action, payload)
		local _, hum = canAct(plr)
		if not hum then return end
		if action == "MoveAmount" and type(payload) == "table" then
			if type(payload.RequestId) ~= "string" or #payload.RequestId > 80 then return end
			local moved = InventoryService:MoveAmount(plr, payload.FromType, payload.FromIndex, payload.ToType, payload.ToIndex, payload.Amount, payload.ExpectedId)
			remote:FireClient(plr, "MoveAmountResult", {RequestId=payload.RequestId, Moved=moved})
			return
		end
		if action == "Move" and type(payload) == "table" then
			print(string.format("[InventoryAction] Move %s: %s[%s] -> %s[%s]", plr.Name, tostring(payload.FromType), tostring(payload.FromIndex), tostring(payload.ToType), tostring(payload.ToIndex)))
			local moved=InventoryService:Move(plr, payload.FromType, payload.FromIndex, payload.ToType, payload.ToIndex)
			if not moved then InventoryService:Sync(plr);remote:FireClient(plr,"UseResult",{Success=false,Message="That equipment does not fit. Empty extra pack slots before removing a pack; duplicate accessory families cannot stack."}) end
			return
		end
		if action == "Split" and type(payload) == "table" then
			print(string.format("[InventoryAction] Split %s: %s[%s]", plr.Name, tostring(payload.FromType), tostring(payload.FromIndex)))
			InventoryService:Split(plr, payload.FromType, payload.FromIndex, payload.ToType, payload.ToIndex, payload.Amount)
			return
		end
		if action == "Use" and type(payload) == "table" then
			remote:FireClient(plr, "UseResult", {Success=false, Message="Put the item in your hotbar, equip it, then activate it."})
			return
		end
		if action == "Equip" and type(payload) == "table" then
			local slotType = payload.SlotType
			local slotIndex = payload.SlotIndex
			print(string.format("[InventoryAction] Equip request %s slot %s[%s]", plr.Name, tostring(slotType), tostring(slotIndex)))
			if slotType ~= "Hotbar" or typeof(slotIndex) ~= "number" or slotIndex % 1 ~= 0 or slotIndex < 1 or slotIndex > 6 then return end
			
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
			if not item or not ToolService:IsHoldable(slot.Id) then
				print(string.format("[InventoryAction] Slot %s is not holdable, unequipping for %s", tostring(slotIndex), plr.Name))
				hum:UnequipTools()
				return
			end
			
			local backpack = plr:FindFirstChildOfClass("Backpack")
			local tool
			for _, container in ipairs({char, backpack}) do
				if container then
					for _, candidate in ipairs(container:GetChildren()) do
						if candidate:IsA("Tool") and candidate:GetAttribute("InventorySlotIndex") == slotIndex then tool = candidate break end
					end
				end
				if tool then break end
			end
			if not tool then
				ToolService:Sync(plr)
				backpack = plr:FindFirstChildOfClass("Backpack")
				for _, container in ipairs({char, backpack}) do
					if container then for _, candidate in ipairs(container:GetChildren()) do
						if candidate:IsA("Tool") and candidate:GetAttribute("InventorySlotIndex") == slotIndex then tool = candidate break end
					end end
					if tool then break end
				end
			end
			if slot.Uid then
				tool=nil
				for _,container in ipairs({char,backpack}) do if container then for _,candidate in ipairs(container:GetChildren()) do if candidate:IsA("Tool") and candidate:GetAttribute("GearUid")==slot.Uid then tool=candidate;break end end end end
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
