-- InventoryActionService.lua
-- Handles client requests to move/swap inventory slots.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local InventoryService = require(script.Parent.InventoryService)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)
local StatsService = require(script.Parent.StatsService)
local ToolService = require(script.Parent.ToolService)

local InventoryActionService = {}
local resistEffects = setmetatable({}, { __mode = "k" })

local FOOD_RESTORE = {
	BrownMushroom = 6,
	CactusStem = 8,
	StaminaRation = 24,
	ReinforcedRation = 40,
}
local RESIST_EFFECTS = {
	AntitoxinTonic = {Key = "Res_Toxin", Amount = 0.35, Duration = 120},
	HeatTonic = {Key = "Res_Heat", Amount = 0.35, Duration = 120},
	ColdTonic = {Key = "Res_Cold", Amount = 0.35, Duration = 120},
	ToxinFilter = {Key = "Res_Toxin", Amount = 0.25, Duration = 90},
}

local function canConsume(item)
	if not item then return false end
	return (item:HasTag("Food") or item:HasTag("Consumable"))
		and (FOOD_RESTORE[item.Id] ~= nil or RESIST_EFFECTS[item.Id] ~= nil or item.Id == "Bandage" or item.Id == "ThermalPatch")
end

local function canAct(plr)
	if ReplicatedStorage:GetAttribute("WorldRestoring") or plr:GetAttribute("WorldPlayerRestoring")
		or plr:GetAttribute("WorldPlayerLoading") or plr:GetAttribute("IsDead") then return nil end
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return nil end
	return char, hum
end

local function hasUsefulEffect(plr, char, hum, itemId)
	if FOOD_RESTORE[itemId] then
		local maximum = StatsService:GetStat(plr, "MaxHunger") or 100
		return (StatsService:GetBase(plr, "Hunger") or StatsService:GetStat(plr, "Hunger") or 0) < maximum
	end
	if itemId == "Bandage" then return hum.Health < hum.MaxHealth end
	local effect = RESIST_EFFECTS[itemId]
	if effect then return (tonumber(char:GetAttribute(effect.Key)) or 0) < 0.9 end
	return itemId == "ThermalPatch"
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

local function applyTimedCharacterResist(char, key, delta, duration)
	if not char or type(key) ~= "string" then return end
	local cur = tonumber(char:GetAttribute(key)) or 0
	local nextValue = math.clamp(cur + (tonumber(delta) or 0), -0.9, 0.9)
	local applied = nextValue - cur
	if applied == 0 then return end
	char:SetAttribute(key, nextValue)
	local entries = resistEffects[char] or {}
	resistEffects[char] = entries
	local effect = { Key = key, Applied = applied, ExpiresAt = os.clock() + duration }
	entries[effect] = true
	task.delay(duration, function()
		if not entries[effect] then return end
		entries[effect] = nil
		if not char.Parent then return end
		local now = tonumber(char:GetAttribute(key)) or 0
		char:SetAttribute(key, math.clamp(now - applied, -0.9, 0.9))
	end)
end

local function applyTimedStatModifier(plr, stat, delta, duration, idPrefix)
	if not StatsService or not StatsService.AddModifier then return end
	local id = string.format("%s_%s_%s", idPrefix or "Consumable", stat, HttpService:GenerateGUID(false))
	StatsService:AddModifier(plr, stat, delta, "Add", duration, id)
end

local function applyConsumableEffects(plr, char, hum, itemId)
	if itemId == "Bandage" then
		if hum then
			hum.Health = math.min(hum.MaxHealth, hum.Health + 25)
		end
		return
	end
	local effect = RESIST_EFFECTS[itemId]
	if effect then
		applyTimedCharacterResist(char, effect.Key, effect.Amount, effect.Duration)
		return
	end
	if itemId == "ThermalPatch" then
		applyTimedStatModifier(plr, "TemperatureResistance", 3.0, 90, "ThermalPatch")
		applyTimedCharacterResist(char, "Res_Wet", 0.2, 90)
	end
end

function InventoryActionService:_consumeFromSlot(plr, slotType, slotIndex)
	local char, hum = canAct(plr)
	if not char then return false end
	local slot = InventoryService:PeekSlot(plr, slotType, slotIndex)
	local item = slot and ItemDatabase:Get(slot.Id)
	if not canConsume(item) or not hasUsefulEffect(plr, char, hum, slot.Id) then return false end
	-- Debit and effect finish before inventory callbacks can change the slot or
	-- character. ExpectedId also prevents consuming a replacement item.
	local removed = InventoryService:TakeFromSlot(plr, slotType, slotIndex, 1, {ExpectedId = slot.Id, DeferSync = true})
	if not removed then return false end
	applyFood(plr, removed)
	applyConsumableEffects(plr, char, hum, removed)
	InventoryService:Sync(plr)
	return true
end

function InventoryActionService:Init()
	if self._initialized then return end
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	local remote = Util.GetRemote(remotesFolder, Config.RemoteNames.InventoryAction)
	if not remote then return end
	self._initialized = true
	remote.OnServerEvent:Connect(function(plr, action, payload)
		local _, hum = canAct(plr)
		if not hum then return end
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
			self:_consumeFromSlot(plr, payload.SlotType, payload.SlotIndex)
			return
		end
		if action == "Equip" and type(payload) == "table" then
			local slotType = payload.SlotType
			local slotIndex = payload.SlotIndex
			print(string.format("[InventoryAction] Equip request %s slot %s[%s]", plr.Name, tostring(slotType), tostring(slotIndex)))
			if slotType ~= "Hotbar" or typeof(slotIndex) ~= "number" or slotIndex % 1 ~= 0 or slotIndex < 1 or slotIndex > 4 then return end
			
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
				self:_consumeFromSlot(plr, "Hotbar", slotIndex)
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

function InventoryActionService:CaptureCharacterState(char)
	local effects = {}
	for effect in pairs(resistEffects[char] or {}) do
		local remaining = effect.ExpiresAt - os.clock()
		if remaining > 0 then table.insert(effects, { Key = effect.Key, Applied = effect.Applied, Remaining = remaining }) end
	end
	return effects
end

function InventoryActionService:RestoreCharacterState(char, effects)
	local codec = require(script.Parent.WorldSnapshotCodec)
	codec.BoundedCount(effects, 128)
	for effect in pairs(resistEffects[char] or {}) do resistEffects[char][effect] = nil end
	for _, key in ipairs({ "Res_Heat", "Res_Cold", "Res_Toxin", "Res_Wet" }) do char:SetAttribute(key, 0) end
	for _, effect in ipairs(effects) do
		assert(effect.Key == "Res_Heat" or effect.Key == "Res_Cold" or effect.Key == "Res_Toxin" or effect.Key == "Res_Wet", "Unknown saved resistance")
		applyTimedCharacterResist(char, effect.Key, codec.Number(effect.Applied, -0.9, 0.9), codec.Number(effect.Remaining, 0, 86400))
	end
end

return InventoryActionService
