-- InventoryService.lua
-- Slot-based inventory with client sync.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Classes = require(ReplicatedStorage.Shared.ClassConfig)
local Util = require(ReplicatedStorage.Shared.Util)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)

local ItemInstance = require(ReplicatedStorage.Shared.ItemInstance)
local InventoryService = {}
InventoryService._inventories = {} -- Server-owned inventory and equipment instances.
InventoryService._worldInitialized = {}
InventoryService._remote = nil
InventoryService._callbacks = {}
InventoryService._requestConn = nil

local HOTBAR_SLOTS = 6
local STORAGE_SLOTS = 18

local function emptySlots(n)
	local slots = {}
	for i = 1, n do
		slots[i] = nil
	end
	return slots
end

local function getInv(plr)
	local inv = InventoryService._inventories[plr]
	if not inv then
		inv = {
			Hotbar = emptySlots(HOTBAR_SLOTS),
			Storage = emptySlots(STORAGE_SLOTS),
			Equipment = {}, Accessory = {},
		}
		InventoryService._inventories[plr] = inv
	end
	return inv
end

local function maxStack(itemId)
	if ItemInstance.Definition(itemId) then return 1 end
	local item = ItemDatabase:Get(itemId)
	return (item and item.StackSize) or 99
end

local function isArmor(itemId)
	local item = ItemDatabase:Get(itemId)
	return item and item:HasTag("Armor") or false
end

local function getSlot(inv, slotType, index)
	if slotType == "Equipment" or slotType == "Accessory" then return (inv[slotType] or {})[index] end
	if slotType == "Hotbar" then
		return inv.Hotbar[index]
	elseif slotType == "Storage" then
		return inv.Storage[index]
	end
	return nil
end

local function setSlot(inv, slotType, index, slot)
	if slotType == "Equipment" or slotType == "Accessory" then inv[slotType] = inv[slotType] or {}; inv[slotType][index] = slot; return end
	if slotType == "Hotbar" then
		inv.Hotbar[index] = slot
	elseif slotType == "Storage" then
		inv.Storage[index] = slot
	end
end

local function validSlot(slotType, index)
	if (slotType == "Equipment" or slotType == "Accessory") then return type(index) == "number" and index % 1 == 0 and index >= 1 and index <= 4 end
	if slotType == "Hotbar" then
		return typeof(index) == "number" and index % 1 == 0 and index >= 1 and index <= HOTBAR_SLOTS
	elseif slotType == "Storage" then
		return typeof(index) == "number" and index % 1 == 0 and index >= 1 and index <= 36
	end
	return false
end

local function cloneSlot(slot)
	if not slot then return nil end
	return ItemInstance.Copy(slot)
end

local function snapshot(inv)
	local hotbar = {}
	local storage = {}
	-- FIXED: Use explicit false for empty slots instead of nil
	-- This prevents Roblox RemoteEvent from dropping sparse array entries
	for i = 1, HOTBAR_SLOTS do
		local slot = inv.Hotbar[i]
		hotbar[i] = slot and cloneSlot(slot) or false
	end
	for i = 1, (inv.StorageCapacity or STORAGE_SLOTS) do
		local slot = inv.Storage[i]
		storage[i] = slot and cloneSlot(slot) or false
	end
	local equipment, accessories = {}, {}
	for i = 1, 4 do equipment[i] = cloneSlot((inv.Equipment or {})[i]) or false; accessories[i] = cloneSlot((inv.Accessory or {})[i]) or false end
	return { Hotbar = hotbar, Storage = storage, Equipment = equipment, Accessory = accessories, StorageCapacity = inv.StorageCapacity or STORAGE_SLOTS }
end

function InventoryService:Init()
	if self._remote and self._requestConn then return end
	-- OPTIMIZED: Try immediate lookup first
	local remotesFolder = Util.GetDescendant(Config.Paths.Remotes)
	if not remotesFolder then
		remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 5)
	end
	if remotesFolder then
		self._remote = Util.GetRemote(remotesFolder, Config.RemoteNames.InventoryUpdate)
	end
	if self._remote and not self._requestConn then
		self._requestConn = self._remote.OnServerEvent:Connect(function(plr, action)
			if action == "RequestSnapshot" then
				self:Sync(plr)
			end
		end)
	end
	-- Expedition startup can deliberately wait for the full crew before requiring
	-- this module, so their earlier PlayerAdded events were not observed here.
	for _, plr in ipairs(Players:GetPlayers()) do
		if not self._worldInitialized[plr] then self:Reset(plr) end
	end
end

function InventoryService:Reset(plr, initializeWorld)
	if self._worldInitialized[plr] or plr:GetAttribute("WorldPlayerRestoring") then return end
	if not initializeWorld and (plr:GetAttribute("WorldPlayerLoading") or ReplicatedStorage:GetAttribute("WorldRestoring")) then return end
	self._worldInitialized[plr] = true
	local inv = {
		Hotbar = emptySlots(HOTBAR_SLOTS),
		Storage = emptySlots(STORAGE_SLOTS),
		Equipment = {}, Accessory = {},
	}
	self._inventories[plr] = inv
	inv.Hotbar[1] = ItemInstance.New("Harvester", 1)
	local kit = Classes.GetKit(plr:GetAttribute("Role") or "Generalist", plr:GetAttribute("ClassLevel") or 1)
	local storageIndex = 1
	for _, entry in ipairs(kit) do
		local item = assert(ItemDatabase:Get(entry.Id), "Missing class starter item: " .. entry.Id)
		local remaining = entry.N
		if isArmor(entry.Id) then
			inv.Equipment=inv.Equipment or {}
			local def=ItemInstance.Definition(entry.Id)
			local index=def and table.find({"Head","Chest","Legs","Boots"},def.Slot) or 2
			inv.Equipment[index] = ItemInstance.New(entry.Id,1)
			remaining -= 1
		elseif not inv.Hotbar[2] and (item:HasTag("Weapon") or item:HasTag("Tool")) then
			inv.Hotbar[2] = { Id = entry.Id, N = 1 }
			remaining -= 1
		end
		while remaining > 0 do
			assert(storageIndex <= STORAGE_SLOTS, "Class starter kit exceeds storage capacity")
			local n = math.min(remaining, maxStack(entry.Id))
			inv.Storage[storageIndex] = { Id = entry.Id, N = n }
			storageIndex += 1
			remaining -= n
		end
	end
	inv.Equipment, inv.Accessory = inv.Equipment or {}, {}
	for _, kind in ipairs({"Hotbar", "Storage"}) do for i, entry in pairs(inv[kind]) do inv[kind][i] = ItemInstance.New(entry.Id, entry.N, entry) end end
	self:Sync(plr)
end

function InventoryService:Clear(plr)
	local inv = {
		Hotbar = emptySlots(HOTBAR_SLOTS),
		Storage = emptySlots(STORAGE_SLOTS),
		Equipment = {}, Accessory = {},
	}
	self._inventories[plr] = inv
	self:Sync(plr)
	return inv
end

function InventoryService:DrainAll(plr)
	local inv = getInv(plr)
	local drops = {}
	for i = 1, HOTBAR_SLOTS do
		local slot = inv.Hotbar[i]
		if slot and slot.Id and slot.N and slot.N > 0 then
			drops[#drops + 1] = cloneSlot(slot)
		end
	end
	for i = 1, (inv.StorageCapacity or STORAGE_SLOTS) do
		local slot = inv.Storage[i]
		if slot and slot.Id and slot.N and slot.N > 0 then
			drops[#drops + 1] = cloneSlot(slot)
		end
	end
	for _, kind in ipairs({"Equipment", "Accessory"}) do for _, entry in pairs(inv[kind] or {}) do drops[#drops + 1] = cloneSlot(entry) end end
	self:Clear(plr)
	return drops
end

function InventoryService:GetAll(plr)
	return getInv(plr)
end

function InventoryService:CaptureWorldState(plr)
	-- Never manufacture an empty inventory while a player is departing. Roblox
	-- dispatches PlayerRemoving listeners independently, so another service's
	-- cleanup can run before the world snapshot listener even when it connected
	-- later. Refusing an uninitialized capture keeps the previous durable
	-- checkpoint instead of silently replacing it with an empty pack.
	local inv = self._inventories[plr]
	assert(self._worldInitialized[plr] and inv, "Inventory unavailable during world snapshot")
	return snapshot(inv)
end

local function readSnapshot(state)
	assert(type(state) == "table", "Missing saved inventory")
	local function read(slot)
		if slot == false or slot == nil then return nil end
		assert(type(slot) == "table" and type(slot.Id) == "string" and ItemDatabase:Get(slot.Id), "Unknown saved inventory item")
		assert(type(slot.N) == "number" and slot.N % 1 == 0 and slot.N > 0 and slot.N <= maxStack(slot.Id), "Invalid saved stack")
		return cloneSlot(slot)
	end
	assert(type(state.Hotbar) == "table" and #state.Hotbar == HOTBAR_SLOTS
		and type(state.Storage) == "table" and (#state.Storage >= STORAGE_SLOTS and #state.Storage <= 36), "Saved inventory shape changed")
	local inv = { Hotbar = {}, Storage = {}, Equipment = {}, Accessory = {}, StorageCapacity = #state.Storage }
	for i = 1, 4 do inv.Equipment[i] = read((state.Equipment or {})[i]); inv.Accessory[i] = read((state.Accessory or {})[i]) end
	for i = 1, HOTBAR_SLOTS do inv.Hotbar[i] = read(state.Hotbar[i]) end
	for i = 1, (inv.StorageCapacity or STORAGE_SLOTS) do inv.Storage[i] = read(state.Storage[i]) end
	return inv
end

function InventoryService:RestoreWorldState(plr, state, deferSync)
	local inv = readSnapshot(state)
	self._inventories[plr] = inv
	self._worldInitialized[plr] = true
	if not deferSync then self:Sync(plr) end
end

function InventoryService:TotalCount(plr, itemId)
	local inv = getInv(plr)
	local total = 0
	for i = 1, HOTBAR_SLOTS do
		local slot = inv.Hotbar[i]
		if slot and slot.Id == itemId then
			total += slot.N
		end
	end
	for i = 1, (inv.StorageCapacity or STORAGE_SLOTS) do
		local slot = inv.Storage[i]
		if slot and slot.Id == itemId then
			total += slot.N
		end
	end
	return total
end

function InventoryService:Has(plr, itemId, amount)
	amount = amount or 1
	return self:TotalCount(plr, itemId) >= amount
end

local function addToSlots(slots, slotCount, itemId, amount, existingOnly)
	local remaining = amount
	local stackMax = maxStack(itemId)
	-- fill existing stacks
	for i = 1, slotCount do
		local slot = slots[i]
		if slot and slot.Id == itemId and slot.N < stackMax then
			local add = math.min(stackMax - slot.N, remaining)
			slot.N += add
			remaining -= add
			if remaining <= 0 then return 0 end
		end
	end
	if existingOnly then return remaining end
	-- use empty slots
	for i = 1, slotCount do
		if not slots[i] then
			local add = math.min(stackMax, remaining)
			slots[i] = ItemInstance.New(itemId, add)
			remaining -= add
			if remaining <= 0 then return 0 end
		end
	end
	return remaining
end

local function addEntryToSlots(slots, count, entry, existingOnly)
 local remaining=entry.N
 local stackLimit=maxStack(entry.Id)
 for i=1,count do
  local current=slots[i]
  if current and ItemInstance.Stackable(current,entry) then
   local add=math.min(remaining,math.max(0,stackLimit-current.N));current.N+=add;remaining-=add
   if remaining<=0 then return 0 end
  end
 end
 if existingOnly then return remaining end
 for i=1,count do
  if not slots[i] then local copy=cloneSlot(entry);copy.N=math.min(remaining,stackLimit);slots[i]=copy;remaining-=copy.N;if remaining<=0 then return 0 end end
 end
 return remaining
end
-- Pure escrow projection. Validate everything before changing even the copy;
-- live inventories and callbacks are untouched until the caller commits.
function InventoryService:ProjectRefund(state, ingredients, dropOnly)
	local inv = readSnapshot(state)
	assert(type(ingredients) == "table" and #ingredients <= 128, "Invalid craft refund ingredients")
	local size = #ingredients
	local count = 0
	for index in pairs(ingredients) do count += 1; assert(type(index) == "number" and index % 1 == 0 and index >= 1 and index <= size, "Invalid craft refund ingredient list") end
	assert(count == size, "Sparse craft refund ingredient list")
	for _, entry in ipairs(ingredients) do
		assert(type(entry) == "table" and type(entry.Id) == "string" and ItemDatabase:Get(entry.Id), "Unknown craft refund item")
		assert(type(entry.N) == "number" and entry.N == entry.N and entry.N % 1 == 0 and entry.N > 0 and entry.N <= 1e8, "Invalid craft refund count")
	end
	local overflow = {}
	for _, entry in ipairs(ingredients) do
		local remaining = entry.N
		if not dropOnly then
			local refund=cloneSlot(entry);refund.N=remaining
			for _, existingOnly in ipairs({true, false}) do
				for _, kind in ipairs({"Hotbar", "Storage"}) do
					if remaining > 0 then
						refund.N = remaining
						remaining = addEntryToSlots(inv[kind], kind == "Hotbar" and HOTBAR_SLOTS or (inv.StorageCapacity or STORAGE_SLOTS), refund, existingOnly)
					end
				end
			end
		end
		if remaining > 0 then local copy=cloneSlot(entry);copy.N=remaining;table.insert(overflow, copy) end
	end
	return snapshot(inv), overflow
end

function InventoryService:CanFit(plr, itemId, amount)
	if type(itemId) ~= "string" or not ItemDatabase:Get(itemId) or type(amount) ~= "number" or amount ~= amount or amount == math.huge or amount < 0 or amount % 1 ~= 0 then return false end
	local inv = getInv(plr)
	local remaining = amount
	local stackMax = maxStack(itemId)
	for i = 1, HOTBAR_SLOTS do
		local slot = inv.Hotbar[i]
		if slot and slot.Id == itemId then
			remaining -= math.max(0, stackMax - slot.N)
		end
	end
	for i = 1, (inv.StorageCapacity or STORAGE_SLOTS) do
		local slot = inv.Storage[i]
		if slot and slot.Id == itemId then
			remaining -= math.max(0, stackMax - slot.N)
		end
	end
	local empty = 0
	for i = 1, HOTBAR_SLOTS do if not inv.Hotbar[i] then empty += 1 end end
	for i = 1, (inv.StorageCapacity or STORAGE_SLOTS) do if not inv.Storage[i] then empty += 1 end end
	remaining -= empty * stackMax
	return remaining <= 0
end

function InventoryService:Give(plr, itemId, amount, requireFit, deferSync)
	amount = math.floor(tonumber(amount) or 0)
	if amount ~= amount or amount == math.huge or amount <= 0 or type(itemId) ~= "string" or not ItemDatabase:Get(itemId) then return 0 end
	local inv = getInv(plr)
	if requireFit and not self:CanFit(plr, itemId, amount) then
		return 0
	end
	local remaining = amount
	-- Fill matching stacks in both sections before claiming any empty hotbar slot.
	for _, existingOnly in ipairs({true, false}) do
		for _, kind in ipairs({"Hotbar", "Storage"}) do
			if remaining > 0 then
				remaining = addToSlots(inv[kind], kind == "Hotbar" and HOTBAR_SLOTS or (inv.StorageCapacity or STORAGE_SLOTS), itemId, remaining, existingOnly)
			end
		end
	end
	local added = amount - remaining
	if added > 0 and not deferSync then
		self:Sync(plr)
	end
	return added
end

local function consumeNoSync(inv, itemId, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount ~= amount or amount == math.huge or amount <= 0 then return false end

	local total = 0
	for i = 1, HOTBAR_SLOTS do
		local slot = inv.Hotbar[i]
		if slot and slot.Id == itemId then
			total += slot.N
		end
	end
	for i = 1, (inv.StorageCapacity or STORAGE_SLOTS) do
		local slot = inv.Storage[i]
		if slot and slot.Id == itemId then
			total += slot.N
		end
	end
	if total < amount then
		return false
	end

	local remaining = amount
	local function consumeSlots(slots, slotCount)
		for i = 1, slotCount do
			local slot = slots[i]
			if slot and slot.Id == itemId then
				local take = math.min(slot.N, remaining)
				slot.N -= take
				remaining -= take
				if slot.N <= 0 then
					slots[i] = nil
				end
				if remaining <= 0 then
					return
				end
			end
		end
	end

	consumeSlots(inv.Hotbar, HOTBAR_SLOTS)
	if remaining > 0 then
		consumeSlots(inv.Storage, inv.StorageCapacity or STORAGE_SLOTS)
	end
	return remaining <= 0
end

function InventoryService:Consume(plr, itemId, amount, deferSync)
	local inv = getInv(plr)
	if not consumeNoSync(inv, itemId, amount) then return false end
	if not deferSync then self:Sync(plr) end
	return true
end

function InventoryService:PeekSlot(plr, slotType, slotIndex)
	if not validSlot(slotType, slotIndex) then return nil end
	return cloneSlot(getSlot(getInv(plr), slotType, slotIndex))
end

function InventoryService:TakeFromSlot(plr, slotType, slotIndex, amount, options)
	amount = math.floor(tonumber(amount) or 0)
	if amount ~= amount or amount == math.huge or amount <= 0 then return nil end
	if not validSlot(slotType, slotIndex) then return nil end
	local inv = getInv(plr)
	local slot = getSlot(inv, slotType, slotIndex)
	if not slot or slot.N < amount then return nil end
	if options and options.ExpectedId and slot.Id ~= options.ExpectedId then return nil end
	if not self:CanRemoveEquipment(plr, slotType, slotIndex) then return nil end
	local itemId = slot.Id
	slot.N -= amount
	if slot.N <= 0 then
		setSlot(inv, slotType, slotIndex, nil)
	end
	if not (options and options.DeferSync) then self:Sync(plr) end
	return itemId
end

function InventoryService:TryAddToSlot(plr, slotType, slotIndex, itemId, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount ~= amount or amount == math.huge or amount <= 0 or not itemId then return 0 end
	if not validSlot(slotType, slotIndex) then return 0 end
	local inv = getInv(plr)
	if slotType=="Storage" and slotIndex>(inv.StorageCapacity or STORAGE_SLOTS) then return 0 end
	if slotType=="Equipment" or slotType=="Accessory" then return 0 end
	local slot = getSlot(inv, slotType, slotIndex)
	local stackMax = maxStack(itemId)
	if slot then
		if slot.Id ~= itemId then return 0 end
		local canAdd = math.max(0, stackMax - slot.N)
		local add = math.min(canAdd, amount)
		if add <= 0 then return 0 end
		slot.N += add
		self:Sync(plr)
		return add
	end
	local add = math.min(stackMax, amount)
	setSlot(inv, slotType, slotIndex, ItemInstance.New(itemId, add))
	self:Sync(plr)
	return add
end

function InventoryService:CanAfford(plr, costList)
	local required = {}
	for _, cost in ipairs(costList or {}) do
		if cost and cost.Id then
			required[cost.Id] = (required[cost.Id] or 0) + (tonumber(cost.N) or 0)
		end
	end
	for itemId, amount in pairs(required) do
		if amount > 0 and not self:Has(plr, itemId, amount) then
			return false
		end
	end
	return true
end

function InventoryService:TakeCost(plr,costList,deferSync)
 if not self:CanAfford(plr,costList) then return nil end
 local inv=getInv(plr);local removed={}
 -- Affordability and debits have no yields or callbacks between them.
 local required={}
 for _,cost in ipairs(costList or {}) do required[cost.Id]=(required[cost.Id] or 0)+cost.N end
 for id,amount in pairs(required) do
  local remaining=amount
  for _,kind in ipairs({"Hotbar","Storage"}) do
   local count=kind=="Hotbar" and HOTBAR_SLOTS or (inv.StorageCapacity or STORAGE_SLOTS)
   for i=1,count do
    local entry=inv[kind][i]
    if entry and entry.Id==id and remaining>0 then
     local take=math.min(remaining,entry.N);local copy=cloneSlot(entry);copy.N=take;removed[#removed+1]=copy
     entry.N-=take;remaining-=take;if entry.N<=0 then inv[kind][i]=nil end
    end
   end
  end
 end
 if not deferSync then self:Sync(plr) end
 return removed
end
function InventoryService:PayCost(plr, costList, deferSync)
	if not self:CanAfford(plr, costList) then return false end
	local inv = getInv(plr)
	for _, cost in ipairs(costList or {}) do
		if not consumeNoSync(inv, cost.Id, cost.N) then
			return false
		end
	end
	if not deferSync then self:Sync(plr) end
	return true
end

function InventoryService:Sync(plr)
	self:RefreshCapacity(plr)
	self:Init()
	if not self._remote or not plr then return end
	self._remote:FireClient(plr, "Snapshot", snapshot(getInv(plr)))
	for _, cb in ipairs(self._callbacks) do
		pcall(cb, plr, getInv(plr))
	end
end

function InventoryService:OnChanged(callback)
	if type(callback) == "function" then
		table.insert(self._callbacks, callback)
	end
end

local ARMOR_SLOTS = {"Head", "Chest", "Legs", "Boots"}
local function accepts(inv, kind, index, entry)
 if kind == "Storage" then return index <= (inv.StorageCapacity or STORAGE_SLOTS) end
 if not entry then return true end
 if kind == "Equipment" then local def = ItemInstance.Definition(entry.Id); return def and def.Kind == "Armor" and def.Slot == ARMOR_SLOTS[index] end
 if kind == "Accessory" then
  local def = ItemInstance.Definition(entry.Id)
  if not def or def.Kind ~= "Accessory" then return false end
  for i, existing in pairs(inv.Accessory or {}) do
   local other = ItemInstance.Definition(existing.Id)
   if i ~= index and other and (existing.Id == entry.Id or (def.Family and def.Family == other.Family)) then return false end
  end
 end
 return true
end
local function proposedCapacity(inv, fromType, fromIndex, toType, toIndex)
 local bonus = 0
 for i = 1, 4 do
  local entry = getSlot(inv, "Accessory", i)
  if fromType == "Accessory" and fromIndex == i then entry = getSlot(inv,toType,toIndex) end
  if toType == "Accessory" and toIndex == i then entry = getSlot(inv,fromType,fromIndex) end
  local def = entry and ItemInstance.Definition(entry.Id)
  if def and (entry.Durability or 1) > 0 then bonus = math.max(bonus, (def.Modifiers or {}).StorageSlots or 0) end
 end
 return STORAGE_SLOTS + bonus
end
function InventoryService:CanRemoveEquipment(plr, kind, index)
 if kind ~= "Accessory" then return true end
 local inv = getInv(plr)
 local capacity = proposedCapacity(inv,kind,index,"Storage",0)
 local occupied=0;for _,entry in pairs(inv.Storage) do if entry then occupied+=1 end end
 if occupied>capacity then return false end
 return true
end
function InventoryService:Move(plr, fromType, fromIndex, toType, toIndex)
	if fromType == toType and fromIndex == toIndex then return false end
	print(string.format("[InventoryService] Move request: %s[%s] -> %s[%s]", tostring(fromType), tostring(fromIndex), tostring(toType), tostring(toIndex)))
	
	if not validSlot(fromType, fromIndex) then
		warn("[InventoryService] Invalid fromSlot:", fromType, fromIndex)
		return false
	end
	if not validSlot(toType, toIndex) then
		warn("[InventoryService] Invalid toSlot:", toType, toIndex)
		return false
	end
	
	local inv = getInv(plr)
	local fromSlot = getSlot(inv, fromType, fromIndex)
	if not accepts(inv, toType, toIndex, fromSlot) or not accepts(inv, fromType, fromIndex, getSlot(inv,toType,toIndex)) then return false end
	local capacity = proposedCapacity(inv,fromType,fromIndex,toType,toIndex)
	local occupied=0;for i,entry in pairs(inv.Storage) do if entry and not(fromType=="Storage" and fromIndex==i) and not(toType=="Storage" and toIndex==i) then occupied+=1 end end
 if toType=="Storage" and fromSlot then occupied+=1 end
 if fromType=="Storage" and getSlot(inv,toType,toIndex) then occupied+=1 end
 if occupied>capacity then return false end
	if toType == "Storage" and toIndex > capacity then return false end
	if not fromSlot then
		warn("[InventoryService] fromSlot is empty")
		return false
	end
	
	print(string.format("[InventoryService] Moving item: %s x%d", fromSlot.Id, fromSlot.N))
	
	
	local toSlot = getSlot(inv, toType, toIndex)
	-- If swapping into armor, ensure target is armor or empty

	-- Stack if same item
	if toSlot and ItemInstance.Stackable(toSlot, fromSlot) then
		local stackMax = maxStack(fromSlot.Id)
		local space = math.max(0, stackMax - toSlot.N)
		if space <= 0 then
			warn("[InventoryService] Target stack full, no move")
			return false
		end
		local move = math.min(space, fromSlot.N)
		toSlot.N += move
		fromSlot.N -= move
		if fromSlot.N <= 0 then
			setSlot(inv, fromType, fromIndex, nil)
		end
		self:Sync(plr)
		return true
	end
	
	-- Clone slots to avoid reference issues
	local fromClone = cloneSlot(fromSlot)
	local toClone = cloneSlot(toSlot)
	
	setSlot(inv, fromType, fromIndex, toClone)
	setSlot(inv, toType, toIndex, fromClone)
	inv.StorageCapacity = capacity
	
	print(string.format("[InventoryService] Move complete. From now has: %s, To now has: %s",
		toClone and (toClone.Id .. " x" .. toClone.N) or "empty",
		fromClone and (fromClone.Id .. " x" .. fromClone.N) or "empty"))
	
	self:Sync(plr)
	return true
end

-- Cursor transfers debit only when placed; closing the UI cannot lose held items.
function InventoryService:MoveAmount(plr, fromType, fromIndex, toType, toIndex, amount, expectedId)
	if not validSlot(fromType, fromIndex) or not validSlot(toType, toIndex) then return 0 end
	if fromType == toType and fromIndex == toIndex then return 0 end
	if type(amount) ~= "number" or amount ~= amount or amount == math.huge or amount < 1 or amount % 1 ~= 0 then return 0 end
	local inv = getInv(plr)
	local source, target = getSlot(inv, fromType, fromIndex), getSlot(inv, toType, toIndex)
	if not accepts(inv,toType,toIndex,source) or not self:CanRemoveEquipment(plr,fromType,fromIndex) then return 0 end
	if not source or source.Id ~= expectedId or (target and not ItemInstance.Stackable(target, source)) then return 0 end
	local count = math.min(amount, source.N, maxStack(source.Id) - (target and target.N or 0))
	if count <= 0 then return 0 end
	local movedEntry = cloneSlot(source); movedEntry.N = (target and target.N or 0) + count
	setSlot(inv, toType, toIndex, movedEntry)
	source.N -= count
	if source.N <= 0 then setSlot(inv, fromType, fromIndex, nil) end
	self:Sync(plr)
	return count
end

local function findEmptySlot(inv, slotType)
	if slotType == "Hotbar" then
		for i = 1, HOTBAR_SLOTS do
			if not inv.Hotbar[i] then return i end
		end
	elseif slotType == "Storage" then
		for i = 1, (inv.StorageCapacity or STORAGE_SLOTS) do
			if not inv.Storage[i] then return i end
		end

	end
	return nil
end

function InventoryService:Split(plr, fromType, fromIndex, toType, toIndex, amount)
	if not validSlot(fromType, fromIndex) then return false end
	if amount ~= nil and (typeof(amount) ~= "number" or amount ~= amount or math.abs(amount) == math.huge) then
		return false
	end
	local inv = getInv(plr)
	local fromSlot = getSlot(inv, fromType, fromIndex)
	if not fromSlot or fromSlot.N < 2 or fromSlot.Uid then return false end
	local split = math.floor(tonumber(amount) or math.floor(fromSlot.N / 2))
	if split <= 0 or split >= fromSlot.N then
		split = math.floor(fromSlot.N / 2)
	end
	if split <= 0 then return false end

	local targetType = toType
	local targetIndex = toIndex
	if not targetType or not targetIndex or not validSlot(targetType, targetIndex) then
		if fromType == "Hotbar" then
			targetType = "Storage"
			targetIndex = findEmptySlot(inv, targetType)
			if not targetIndex then
				targetType = "Hotbar"
				targetIndex = findEmptySlot(inv, targetType)
			end
		elseif fromType == "Storage" then
			targetType = "Hotbar"
			targetIndex = findEmptySlot(inv, targetType)
			if not targetIndex then
				targetType = "Storage"
				targetIndex = findEmptySlot(inv, targetType)
			end
		else
			targetType = "Storage"
			targetIndex = findEmptySlot(inv, targetType)
			if not targetIndex then
				targetType = "Hotbar"
				targetIndex = findEmptySlot(inv, targetType)
			end
		end
	end

	if not targetType or not targetIndex or not validSlot(targetType, targetIndex) then return false end
	if not accepts(inv,targetType,targetIndex,fromSlot) then return false end
	if targetType == "Storage" and targetIndex > (inv.StorageCapacity or 18) then return false end
	local targetSlot = getSlot(inv, targetType, targetIndex)
	if targetSlot then return false end

	setSlot(inv, targetType, targetIndex, { Id = fromSlot.Id, N = split })
	fromSlot.N -= split
	if fromSlot.N <= 0 then
		setSlot(inv, fromType, fromIndex, nil)
	end
	self:Sync(plr)
	return true
end

function InventoryService:TakeEntryFromSlot(plr, kind, index, amount, options)
 local entry = self:PeekSlot(plr,kind,index)
 if not entry or not self:TakeFromSlot(plr,kind,index,amount,options) then return nil end
 entry.N = amount
 return entry
end
function InventoryService:GiveEntry(plr, entry, requireFit, deferSync)
 if type(entry) ~= "table" or not ItemDatabase:Get(entry.Id) then return 0 end
 if not entry.Uid and not ItemInstance.Definition(entry.Id) then
  local plain = true
  for key in pairs(entry) do if key ~= "Id" and key ~= "N" then plain = false end end
  if plain then return self:Give(plr,entry.Id,entry.N,requireFit,deferSync) end
 end
 local inv = getInv(plr)
 local requested = math.max(0, math.floor(tonumber(entry.N) or 0))
 local destinations = {}
 for _, kind in ipairs({"Hotbar","Storage"}) do
  for i = 1, kind == "Hotbar" and HOTBAR_SLOTS or (inv.StorageCapacity or STORAGE_SLOTS) do
   if not inv[kind][i] then destinations[#destinations+1] = {kind,i} end
  end
 end
 if requireFit and #destinations < requested then return 0 end
 local count = math.min(requested,#destinations)
 for i = 1,count do
  local added = ItemInstance.New(entry.Id,1,entry)
  if i > 1 then added.Uid = game:GetService("HttpService"):GenerateGUID(false) end
  inv[destinations[i][1]][destinations[i][2]] = added
 end
 if count > 0 and not deferSync then self:Sync(plr) end
 return count
end
function InventoryService:TryAddEntryToSlot(plr, kind,index, entry)
 local inv = getInv(plr)
 if not validSlot(kind,index) or not accepts(inv,kind,index,entry) then return 0 end
 local current = getSlot(inv,kind,index)
 if current and not ItemInstance.Stackable(current,entry) then return 0 end
 local count = math.min(entry.N,maxStack(entry.Id)-(current and current.N or 0))
 if count <= 0 then return 0 end
 local copy = cloneSlot(entry); copy.N = count+(current and current.N or 0)
 setSlot(inv,kind,index,copy); self:Sync(plr); return count
end
function InventoryService:RefreshCapacity(plr)
 local inv = getInv(plr)
 local capacity = proposedCapacity(inv,"Storage",0,"Storage",0)
 -- Move contents into free base slots before shrinking; never discard an instance.
 for i=capacity+1,36 do
  if inv.Storage[i] then for j=1,capacity do if not inv.Storage[j] then inv.Storage[j]=inv.Storage[i];inv.Storage[i]=nil;break end end end
 end
 for i=capacity+1,36 do if inv.Storage[i] then capacity=i end end
 inv.StorageCapacity=capacity
end
-- Alias for Has (BuildService compatibility)
function InventoryService:HasItem(plr, itemId, amount)
	return self:Has(plr, itemId, amount)
end

-- Alias for Consume (BuildService compatibility)  
function InventoryService:Take(plr, itemId, amount)
	return self:Consume(plr, itemId, amount)
end

Players.PlayerAdded:Connect(function(plr)
	InventoryService:Reset(plr)
end)

Players.PlayerRemoving:Connect(function(plr)
	-- WorldSnapshotService captures departure state from another
	-- PlayerRemoving listener. Keep server-owned data alive through that event.
	task.defer(function()
		InventoryService._inventories[plr] = nil
		InventoryService._worldInitialized[plr] = nil
	end)
end)

return InventoryService
