-- InventoryService.lua
-- Slot-based inventory with client sync.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)

local InventoryService = {}
InventoryService._inventories = {} -- [player] = { Hotbar = {}, Storage = {}, Armor = nil }
InventoryService._remote = nil
InventoryService._callbacks = {}

local HOTBAR_SLOTS = 4
local STORAGE_SLOTS = 10

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
		return true
	elseif slotType == "Hotbar" then
		return typeof(index) == "number" and index >= 1 and index <= HOTBAR_SLOTS
	elseif slotType == "Storage" then
		return typeof(index) == "number" and index >= 1 and index <= STORAGE_SLOTS
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
	for i = 1, HOTBAR_SLOTS do
		hotbar[i] = cloneSlot(inv.Hotbar[i])
	end
	for i = 1, STORAGE_SLOTS do
		storage[i] = cloneSlot(inv.Storage[i])
	end
	local armor = cloneSlot(inv.Armor)
	return { Hotbar = hotbar, Storage = storage, Armor = armor }
end

function InventoryService:Init()
	if self._remote then return end
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	self._remote = Util.GetRemote(remotesFolder, Config.RemoteNames.InventoryUpdate)
end

function InventoryService:Reset(plr)
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

function InventoryService:GetAll(plr)
	return getInv(plr)
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
	if amount <= 0 or not itemId then return 0 end
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

function InventoryService:Consume(plr, itemId, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return false end
	if not self:Has(plr, itemId, amount) then return false end
	local inv = getInv(plr)
	local remaining = amount
	local function consumeSlots(slots, slotCount)
		for i = 1, slotCount do
			local slot = slots[i]
			if slot and slot.Id == itemId then
				local take = math.min(slot.N, remaining)
				slot.N -= take
				remaining -= take
				if slot.N <= 0 then slots[i] = nil end
				if remaining <= 0 then return end
			end
		end
	end
	consumeSlots(inv.Hotbar, HOTBAR_SLOTS)
	if remaining > 0 then
		consumeSlots(inv.Storage, STORAGE_SLOTS)
	end
	self:Sync(plr)
	return true
end

function InventoryService:TakeFromSlot(plr, slotType, slotIndex, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return nil end
	if not validSlot(slotType, slotIndex) then return nil end
	local inv = getInv(plr)
	local slot = getSlot(inv, slotType, slotIndex)
	if not slot or slot.N < amount then return nil end
	local itemId = slot.Id
	slot.N -= amount
	if slot.N <= 0 then
		setSlot(inv, slotType, slotIndex, nil)
	end
	self:Sync(plr)
	return itemId
end

function InventoryService:CanAfford(plr, costList)
	for _, cost in ipairs(costList or {}) do
		if not self:Has(plr, cost.Id, cost.N) then
			return false
		end
	end
	return true
end

function InventoryService:PayCost(plr, costList)
	if not self:CanAfford(plr, costList) then return false end
	for _, cost in ipairs(costList or {}) do
		self:Consume(plr, cost.Id, cost.N)
	end
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
	if not validSlot(fromType, fromIndex) or not validSlot(toType, toIndex) then return false end
	local inv = getInv(plr)
	local fromSlot = getSlot(inv, fromType, fromIndex)
	if not fromSlot then return false end
	if toType == "Armor" and not isArmor(fromSlot.Id) then return false end
	local toSlot = getSlot(inv, toType, toIndex)
	-- If swapping into armor, ensure target is armor or empty
	if fromType == "Armor" and toSlot and not isArmor(toSlot.Id) then
		return false
	end
	setSlot(inv, fromType, fromIndex, toSlot)
	setSlot(inv, toType, toIndex, fromSlot)
	self:Sync(plr)
	return true
end

Players.PlayerAdded:Connect(function(plr)
	InventoryService:Reset(plr)
end)

Players.PlayerRemoving:Connect(function(plr)
	InventoryService._inventories[plr] = nil
end)

return InventoryService
