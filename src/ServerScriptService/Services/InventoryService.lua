-- InventoryService.lua
-- Slot-based inventory with client sync.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)

local InventoryService = {}
InventoryService._inventories = {} -- [player] = { Hotbar = {}, Storage = {}, Armor = nil }
InventoryService._worldInitialized = {}
InventoryService._remote = nil
InventoryService._callbacks = {}
InventoryService._requestConn = nil

local HOTBAR_SLOTS = 4
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
			Armor = nil,
		}
		InventoryService._inventories[plr] = inv
	end
	return inv
end

local function maxStack(itemId)
	local item = ItemDatabase:Get(itemId)
	return (item and item.StackSize) or 99
end

local function isArmor(itemId)
	local item = ItemDatabase:Get(itemId)
	return item and item:HasTag("Armor") or false
end

local function getSlot(inv, slotType, index)
	if slotType == "Armor" then
		return inv.Armor
	elseif slotType == "Hotbar" then
		return inv.Hotbar[index]
	elseif slotType == "Storage" then
		return inv.Storage[index]
	end
	return nil
end

local function setSlot(inv, slotType, index, slot)
	if slotType == "Armor" then
		inv.Armor = slot
	elseif slotType == "Hotbar" then
		inv.Hotbar[index] = slot
	elseif slotType == "Storage" then
		inv.Storage[index] = slot
	end
end

local function validSlot(slotType, index)
	if slotType == "Armor" then
		return index == nil or index == 1
	elseif slotType == "Hotbar" then
		return typeof(index) == "number" and index % 1 == 0 and index >= 1 and index <= HOTBAR_SLOTS
	elseif slotType == "Storage" then
		return typeof(index) == "number" and index % 1 == 0 and index >= 1 and index <= STORAGE_SLOTS
	end
	return false
end

local function cloneSlot(slot)
	if not slot then return nil end
	return { Id = slot.Id, N = slot.N }
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
	for i = 1, STORAGE_SLOTS do
		local slot = inv.Storage[i]
		storage[i] = slot and cloneSlot(slot) or false
	end
	local armor = cloneSlot(inv.Armor)
	return { Hotbar = hotbar, Storage = storage, Armor = armor }
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

function InventoryService:Reset(plr)
	if plr:GetAttribute("WorldPlayerRestoring") then return end
	self._worldInitialized[plr] = true
	local inv = {
		Hotbar = emptySlots(HOTBAR_SLOTS),
		Storage = emptySlots(STORAGE_SLOTS),
		Armor = nil,
	}
	self._inventories[plr] = inv
	inv.Hotbar[1] = { Id = "Harvester", N = 1 }
	for _, entry in ipairs(Config.STARTER_ITEMS or {}) do
		self:Give(plr, entry.Id, entry.N, true)
	end
	self:Sync(plr)
end

function InventoryService:Clear(plr)
	local inv = {
		Hotbar = emptySlots(HOTBAR_SLOTS),
		Storage = emptySlots(STORAGE_SLOTS),
		Armor = nil,
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
			drops[#drops + 1] = { Id = slot.Id, N = slot.N }
		end
	end
	for i = 1, STORAGE_SLOTS do
		local slot = inv.Storage[i]
		if slot and slot.Id and slot.N and slot.N > 0 then
			drops[#drops + 1] = { Id = slot.Id, N = slot.N }
		end
	end
	if inv.Armor and inv.Armor.Id and inv.Armor.N and inv.Armor.N > 0 then
		drops[#drops + 1] = { Id = inv.Armor.Id, N = inv.Armor.N }
	end
	self:Clear(plr)
	return drops
end

function InventoryService:GetAll(plr)
	return getInv(plr)
end

function InventoryService:CaptureWorldState(plr)
	return snapshot(getInv(plr))
end

function InventoryService:RestoreWorldState(plr, state)
	assert(type(state) == "table", "Missing saved inventory")
	local function read(slot, armor)
		if slot == false or slot == nil then return nil end
		assert(type(slot) == "table" and type(slot.Id) == "string" and ItemDatabase:Get(slot.Id), "Unknown saved inventory item")
		assert(type(slot.N) == "number" and slot.N % 1 == 0 and slot.N > 0 and slot.N <= maxStack(slot.Id), "Invalid saved stack")
		assert(not armor or (slot.N == 1 and isArmor(slot.Id)), "Invalid saved armor")
		return cloneSlot(slot)
	end
	assert(type(state.Hotbar) == "table" and #state.Hotbar == HOTBAR_SLOTS and type(state.Storage) == "table" and #state.Storage == STORAGE_SLOTS, "Saved inventory shape changed")
	local inv = { Hotbar = {}, Storage = {}, Armor = read(state.Armor, true) }
	for i = 1, HOTBAR_SLOTS do inv.Hotbar[i] = read(state.Hotbar[i]) end
	for i = 1, STORAGE_SLOTS do inv.Storage[i] = read(state.Storage[i]) end
	self._inventories[plr] = inv
	self._worldInitialized[plr] = true
	self:Sync(plr)
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
	for i = 1, STORAGE_SLOTS do
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

local function addToSlots(slots, slotCount, itemId, amount)
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
	-- use empty slots
	for i = 1, slotCount do
		if not slots[i] then
			local add = math.min(stackMax, remaining)
			slots[i] = { Id = itemId, N = add }
			remaining -= add
			if remaining <= 0 then return 0 end
		end
	end
	return remaining
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
	for i = 1, STORAGE_SLOTS do
		local slot = inv.Storage[i]
		if slot and slot.Id == itemId then
			remaining -= math.max(0, stackMax - slot.N)
		end
	end
	local empty = 0
	for i = 1, HOTBAR_SLOTS do if not inv.Hotbar[i] then empty += 1 end end
	for i = 1, STORAGE_SLOTS do if not inv.Storage[i] then empty += 1 end end
	remaining -= empty * stackMax
	return remaining <= 0
end

function InventoryService:Give(plr, itemId, amount, requireFit)
	amount = math.floor(tonumber(amount) or 0)
	if amount ~= amount or amount == math.huge or amount <= 0 or type(itemId) ~= "string" or not ItemDatabase:Get(itemId) then return 0 end
	local inv = getInv(plr)
	if requireFit and not self:CanFit(plr, itemId, amount) then
		return 0
	end
	local remaining = addToSlots(inv.Hotbar, HOTBAR_SLOTS, itemId, amount)
	if remaining > 0 then
		remaining = addToSlots(inv.Storage, STORAGE_SLOTS, itemId, remaining)
	end
	local added = amount - remaining
	if added > 0 then
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
	for i = 1, STORAGE_SLOTS do
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
		consumeSlots(inv.Storage, STORAGE_SLOTS)
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
	if slotType == "Armor" and not isArmor(itemId) then
		return 0
	end
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
	setSlot(inv, slotType, slotIndex, { Id = itemId, N = add })
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

function InventoryService:Move(plr, fromType, fromIndex, toType, toIndex)
	if fromType == toType and (fromType == "Armor" or fromIndex == toIndex) then return false end
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
	if not fromSlot then
		warn("[InventoryService] fromSlot is empty")
		return false
	end
	
	print(string.format("[InventoryService] Moving item: %s x%d", fromSlot.Id, fromSlot.N))
	
	if toType == "Armor" and not isArmor(fromSlot.Id) then
		warn("[InventoryService] Cannot move non-armor to armor slot")
		return false
	end
	
	local toSlot = getSlot(inv, toType, toIndex)
	-- If swapping into armor, ensure target is armor or empty
	if fromType == "Armor" and toSlot and not isArmor(toSlot.Id) then
		warn("[InventoryService] Cannot swap non-armor into armor slot")
		return false
	end

	-- Stack if same item
	if toSlot and toSlot.Id == fromSlot.Id then
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
	
	print(string.format("[InventoryService] Move complete. From now has: %s, To now has: %s",
		toClone and (toClone.Id .. " x" .. toClone.N) or "empty",
		fromClone and (fromClone.Id .. " x" .. fromClone.N) or "empty"))
	
	self:Sync(plr)
	return true
end

local function findEmptySlot(inv, slotType)
	if slotType == "Hotbar" then
		for i = 1, HOTBAR_SLOTS do
			if not inv.Hotbar[i] then return i end
		end
	elseif slotType == "Storage" then
		for i = 1, STORAGE_SLOTS do
			if not inv.Storage[i] then return i end
		end
	elseif slotType == "Armor" then
		if not inv.Armor then return 1 end
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
	if not fromSlot or fromSlot.N < 2 then return false end
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
	if targetType == "Armor" and not isArmor(fromSlot.Id) then return false end
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
	InventoryService._inventories[plr] = nil
	InventoryService._worldInitialized[plr] = nil
end)

return InventoryService
