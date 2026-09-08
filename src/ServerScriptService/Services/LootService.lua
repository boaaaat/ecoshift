-- LootService.lua
-- Handles chest prompts, chest UI sync, and monster loot drops.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local InventoryService = require(script.Parent.InventoryService)
local ItemDropService = require(script.Parent.ItemDropService)
local PromptQueueService = require(script.Parent.PromptQueueService)
local LootTableService = require(script.Parent.LootTableService)
local GameStateService = require(script.Parent.GameStateService)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)
local MonsterDropConfig = require(ReplicatedStorage.Shared.MonsterDropConfig)

local LootService = {}
LootService._chests = {} -- [Instance] = { Id, Tier, Table, Slots }
LootService._chestById = {}
LootService._openByPlayer = {} -- [player] = chestId
LootService._monsterConns = setmetatable({}, { __mode = "k" })
LootService._chestCleanupConns = setmetatable({}, { __mode = "k" })
LootService._chestPromptConns = setmetatable({}, { __mode = "k" })
LootService._remote = nil
LootService._missingTableWarnAt = {}

local CHEST_TAGS = {
	Common_Chest = 1,
	Rare_Chest = 2,
	Legendary_Chest = 3,
	Celestial_Chest = 4,
}

local MONSTER_TAGS = {
	Common_Monster = 1,
	Rare_Monster = 2,
	Legendary_Monster = 3,
	Celestial_Monster = 4,
}

local PROMPT_BOUND_ATTR = "LootServiceBound"
local DROP_RNG = Random.new()
local DEFAULT_CHEST_SLOT_COUNT = 10
local MISSING_TABLE_WARN_WINDOW = 30

local function positiveInteger(value)
	return type(value) == "number" and value > 0 and value < math.huge and value % 1 == 0
end

local function getTierFromTags(instance, map)
	for tag, tier in pairs(map) do
		if CollectionService:HasTag(instance, tag) then
			return tier
		end
	end
	return 1
end

local function isChestTagged(instance)
	if typeof(instance) ~= "Instance" then return false end
	for tag in pairs(CHEST_TAGS) do
		if CollectionService:HasTag(instance, tag) then
			return true
		end
	end
	return false
end

local function getLootTableName(instance)
	local attr = instance:GetAttribute("LootTable") or instance:GetAttribute("LootTableName")
	if type(attr) == "string" and attr ~= "" then
		return attr
	end
	local val = instance:FindFirstChild("LootTable") or instance:FindFirstChild("LootTableName")
	if val and val:IsA("StringValue") and val.Value ~= "" then
		return val.Value
	end
	local cfg = Config.LOOT or {}
	local defaultTable = cfg.DefaultTable
	if type(defaultTable) == "string" and defaultTable ~= "" then
		return defaultTable
	end
	return nil
end

local function getExplicitLootTableName(instance)
	local attr = instance:GetAttribute("LootTable") or instance:GetAttribute("LootTableName")
	if type(attr) == "string" and attr ~= "" then
		return attr
	end
	local val = instance:FindFirstChild("LootTable") or instance:FindFirstChild("LootTableName")
	if val and val:IsA("StringValue") and val.Value ~= "" then
		return val.Value
	end
	return nil
end

local function getPrimary(model)
	if model:IsA("BasePart") then return model end
	if model.PrimaryPart then return model.PrimaryPart end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then return d end
	end
	return nil
end

local function maxStack(itemId)
	local item = ItemDatabase:Get(itemId)
	return (item and item.StackSize) or 99
end

local function getChestSlotCount(chest)
	local saved = chest and chest:GetAttribute("SlotCount")
	return type(saved) == "number" and saved % 1 == 0 and saved >= 1 and saved <= 100 and saved or DEFAULT_CHEST_SLOT_COUNT
end

local function normalizeChestSlots(slots, slotCount)
	local out = {}
	for i = 1, slotCount do
		local slot = slots and slots[i]
		if slot and type(slot) == "table" and slot.Id and tonumber(slot.N) and tonumber(slot.N) > 0 then
			out[i] = { Id = slot.Id, N = math.floor(tonumber(slot.N)) }
		else
			out[i] = nil
		end
	end
	return out
end

local function encodeChestSlotsForClient(slots, slotCount)
	local encoded = {}
	for i = 1, slotCount do
		local slot = slots and slots[i]
		encoded[i] = (slot and { Id = slot.Id, N = slot.N }) or false
	end
	return encoded
end

local function getInventorySlot(inv, slotType, slotIndex)
	if not inv then return nil end
	if slotType == "Hotbar" then
		return inv.Hotbar and inv.Hotbar[slotIndex]
	elseif slotType == "Storage" then
		return inv.Storage and inv.Storage[slotIndex]
	elseif slotType == "Armor" then
		return inv.Armor
	end
	return nil
end

local function resolveChestFromPayload(payload)
	if type(payload) ~= "table" then return nil end
	local inst = payload.Chest or payload.Target or payload.Instance
	if typeof(inst) ~= "Instance" then return nil end
	if inst:IsA("ProximityPrompt") then
		inst = inst.Parent
	end
	if inst and inst:IsA("BasePart") then
		inst = inst:FindFirstAncestorOfClass("Model") or inst
	end
	if not inst or not inst.Parent then return nil end
	return inst
end

local function canPlayerOpenChest(plr, chest)
	if not plr or plr.Parent ~= Players or not chest or not chest:IsDescendantOf(Workspace)
		or GameStateService:IsGameOver() or plr:GetAttribute("IsDead") then return false end
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local primary = getPrimary(chest)
	if not hum or hum.Health <= 0 or not root or not primary then return false end
	-- The prompt is bound to this same primary part; allow only half a stud of latency drift.
	return (root.Position - primary.Position).Magnitude <= 8.5
end

function LootService:_warnMissingChestTable(chest, tableName)
	local key = tableName
	if type(key) ~= "string" or key == "" then
		key = "__DEFAULT_UNSET__"
	end
	local now = os.clock()
	local lastWarn = self._missingTableWarnAt[key] or 0
	if now - lastWarn < MISSING_TABLE_WARN_WINDOW then
		return
	end
	self._missingTableWarnAt[key] = now
	if key == "__DEFAULT_UNSET__" then
		warn(string.format(
			"[LootService] Chest %s has no loot table configured and Config.LOOT.DefaultTable is unset. Chest will open empty until a loot table is configured.",
			chest and chest.Name or "UnknownChest"
		))
	else
		warn(string.format(
			"[LootService] Chest %s requested missing loot table %q. Chest will open empty until that table is authored.",
			chest and chest.Name or "UnknownChest",
			tableName
		))
	end
end

function LootService:_ensureRemote()
	if self._remote then
		return self._remote
	end
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	self._remote = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.ChestEvent) or nil
	return self._remote
end

function LootService:_getChestViewers(chestId)
	local viewers = {}
	for plr, openChestId in pairs(self._openByPlayer) do
		if openChestId == chestId then
			viewers[#viewers + 1] = plr
		end
	end
	return viewers
end

function LootService:_closeChestForPlayer(plr, chestId)
	if not plr then return end
	if chestId and self._openByPlayer[plr] ~= chestId then
		return
	end
	self._openByPlayer[plr] = nil
	local remote = self:_ensureRemote()
	if remote then
		remote:FireClient(plr, "Close", {
			ChestId = chestId,
		})
	end
end

function LootService:_closeChestViewers(chestId)
	if not chestId then return end
	for _, plr in ipairs(self:_getChestViewers(chestId)) do
		self:_closeChestForPlayer(plr, chestId)
	end
end

function LootService:_ensureChestData(chest)
	local data = self._chests[chest]
	if data then return data end
	local restoreKey = chest:GetAttribute("WorldObjectKey")
	local saved = restoreKey and self._restoreChests and self._restoreChests[restoreKey]
	if saved then
		self._restoreChests[restoreKey] = nil
		self:RestoreChestState(chest, saved)
		return self._chests[chest]
	end
	local id = HttpService:GenerateGUID(false)
	local tier = getTierFromTags(chest, CHEST_TAGS)
	local tableName = getLootTableName(chest)
	local items = {}
	if chest:GetAttribute("BuildType") == "Chest" then
		-- Crafted storage starts empty, even when a default world loot table exists.
		tableName = nil
	elseif tableName and LootTableService:Get(tableName) then
		items = LootTableService:Roll(tableName, tier)
	else
		self:_warnMissingChestTable(chest, tableName)
	end
	local slotCount = getChestSlotCount(chest)
	local slots = {}
	local cursor = 1
	for _, item in ipairs(items) do
		if cursor > slotCount then break end
		slots[cursor] = { Id = item.Id, N = item.N }
		cursor += 1
	end
	data = {
		Id = id,
		Tier = tier,
		Table = tableName or "",
		SlotCount = slotCount,
		Slots = normalizeChestSlots(slots, slotCount),
	}
	print(string.format("[LootService] Chest %s -> table %s tier %d items %d", chest.Name, tostring(tableName or "none"), tier, #items))
	self._chests[chest] = data
	self._chestById[id] = chest
	return data
end

function LootService:CaptureChestState(chest)
	local data = self:_ensureChestData(chest)
	return { Tier = data.Tier, Table = data.Table, SlotCount = data.SlotCount, Slots = encodeChestSlotsForClient(data.Slots, data.SlotCount) }
end

function LootService:StageChestState(key, state)
	self._restoreChests = self._restoreChests or {}
	self._restoreChests[key] = state
end

function LootService:RestoreChestState(chest, state)
	assert(type(state) == "table" and type(state.Slots) == "table", "Invalid saved chest")
	assert(type(state.SlotCount) == "number" and state.SlotCount % 1 == 0 and state.SlotCount >= 1 and state.SlotCount <= 100, "Invalid saved chest size")
	assert(#state.Slots == state.SlotCount, "Saved chest slots changed")
	local slots = {}
	for i = 1, state.SlotCount do
		local slot = state.Slots[i]
		if slot ~= false then
			assert(type(slot) == "table" and type(slot.Id) == "string" and ItemDatabase:Get(slot.Id) and positiveInteger(slot.N) and slot.N <= maxStack(slot.Id), "Invalid saved chest item")
			slots[i] = { Id = slot.Id, N = slot.N }
		end
	end
	local old = self._chests[chest]
	if old then self:_closeChestViewers(old.Id); self._chestById[old.Id] = nil end
	local id = HttpService:GenerateGUID(false)
	chest:SetAttribute("SlotCount", state.SlotCount)
	self._chests[chest] = { Id = id, Tier = state.Tier, Table = state.Table, SlotCount = state.SlotCount, Slots = slots }
	self._chestById[id] = chest
end

function LootService:_clearChestData(chest)
	local data = self._chests[chest]
	if data and data.Id then
		self:_closeChestViewers(data.Id)
		self._chestById[data.Id] = nil
	end
	self._chests[chest] = nil
	local conn = self._chestCleanupConns[chest]
	if conn then
		conn:Disconnect()
		self._chestCleanupConns[chest] = nil
	end
	local primary = getPrimary(chest)
	local prompt = primary and primary:FindFirstChildOfClass("ProximityPrompt")
	local promptConn = prompt and self._chestPromptConns[prompt]
	if promptConn then
		promptConn:Disconnect()
		self._chestPromptConns[prompt] = nil
	end
end

function LootService:_sendChest(plr, chest)
	if not canPlayerOpenChest(plr, chest) then return end
	local data = self:_ensureChestData(chest)
	data.SlotCount = getChestSlotCount(chest)
	data.Slots = normalizeChestSlots(data.Slots, data.SlotCount)
	local remote = self:_ensureRemote()
	if not remote then return end
	self._openByPlayer[plr] = data.Id
	print(string.format("[LootService] Open chest %s for %s (items %d)", chest.Name, plr.Name, #data.Slots))
	remote:FireClient(plr, "Open", {
		ChestId = data.Id,
		Tier = data.Tier,
		Table = data.Table,
		SlotCount = data.SlotCount,
		Slots = encodeChestSlotsForClient(data.Slots, data.SlotCount),
		Title = chest.Name,
	})
end

function LootService:_updateChest(data)
	local chest = self._chestById[data.Id]
	data.SlotCount = chest and getChestSlotCount(chest) or DEFAULT_CHEST_SLOT_COUNT
	data.Slots = normalizeChestSlots(data.Slots, data.SlotCount)
	local remote = self:_ensureRemote()
	if not remote then return end
	for _, plr in ipairs(self:_getChestViewers(data.Id)) do
		if chest and chest.Parent and canPlayerOpenChest(plr, chest) then
			remote:FireClient(plr, "Update", {
				ChestId = data.Id,
				SlotCount = data.SlotCount,
				Slots = encodeChestSlotsForClient(data.Slots, data.SlotCount),
			})
		else
			self:_closeChestForPlayer(plr, data.Id)
		end
	end
end

local function attachChestPrompt(chest)
	local part = getPrimary(chest)
	if not part then return end
	local prompt = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
	end
	prompt.Parent = part
	prompt.ActionText = "Open"
	prompt.ObjectText = chest.Name
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute(PROMPT_BOUND_ATTR, true)
	if LootService._chestPromptConns[prompt] then
		return
	end
	LootService._chestPromptConns[prompt] = prompt.Triggered:Connect(function(plr)
		print(string.format("[LootService] Prompt triggered on %s by %s", chest.Name, plr.Name))
		LootService:_sendChest(plr, chest)
	end)
end

function LootService:_bindChest(chest)
	if not chest or not chest.Parent then return end
	if not self._chestCleanupConns[chest] then
		local ok, conn = pcall(function()
			return chest.Destroying:Connect(function()
				self:_clearChestData(chest)
			end)
		end)
		if ok and conn then
			self._chestCleanupConns[chest] = conn
		end
	end
	PromptQueueService:Enqueue(function()
		attachChestPrompt(chest)
	end)
end

local function dropLoot(model, tier, tableName, destroyModel)
	if not model or model:GetAttribute("LootDropped") then return end
	if tableName ~= nil and tableName == "" then return end
	model:SetAttribute("LootDropped", true)
	local tName = tableName or getLootTableName(model)
	if not tName or tName == "" then return end
	local items = LootTableService:Roll(tName, tier)
	local root = getPrimary(model)
	local pos = root and root.Position or model:GetPivot().Position
	local cfg = Config.LOOT or {}
	local spread = tonumber(cfg.DropSpread) or 4
	local height = tonumber(cfg.DropHeight) or 2
	for _, item in ipairs(items) do
		local offset = Vector3.new(
			DROP_RNG:NextNumber() * spread - spread * 0.5,
			height,
			DROP_RNG:NextNumber() * spread - spread * 0.5
		)
		ItemDropService:SpawnDrop(item.Id, item.N, pos + offset)
	end
	if destroyModel and model and model.Parent then
		model:Destroy()
	end
end

local function randomIntRange(min, max)
	local lo = math.floor(tonumber(min) or 1)
	local hi = math.floor(tonumber(max) or lo)
	if hi < lo then hi = lo end
	return math.random(lo, hi)
end

local function resolveMonsterDropConfig(monster)
	local monsters = MonsterDropConfig and MonsterDropConfig.Monsters
	if type(monsters) ~= "table" or not monster then
		return nil
	end
	local entityId = monster:GetAttribute("EntityId")
	if type(entityId) == "string" and monsters[entityId] then
		return monsters[entityId]
	end
	local name = monster.Name
	if type(name) == "string" then
		local prefix = string.match(name, "^(.*)_%d+$")
		if prefix and monsters[prefix] then
			return monsters[prefix]
		end
		return monsters[name]
	end
	return nil
end

local function dropConfiguredMonsterLoot(monster)
	if not monster or not monster.Parent then return false end
	local cfg = resolveMonsterDropConfig(monster)
	if not cfg or type(cfg.Drops) ~= "table" then return false end
	local root = getPrimary(monster)
	local pos = root and root.Position or monster:GetPivot().Position
	for _, drop in ipairs(cfg.Drops) do
		local chance = tonumber(drop.Chance) or 1
		if math.random() <= chance then
			local count = randomIntRange(drop.Min or 1, drop.Max or drop.Min or 1)
			if count > 0 and drop.ItemId then
				local offset = Vector3.new(
					DROP_RNG:NextNumber() * 4 - 2,
					2,
					DROP_RNG:NextNumber() * 4 - 2
				)
				ItemDropService:SpawnDrop(drop.ItemId, count, pos + offset)
			end
		end
	end
	return true
end

local function findHealthValue(model)
	if not model or not model.Parent then return nil end
	local health = model:FindFirstChild("Health", true)
	if health and health:IsA("ValueBase") and typeof(health.Value) == "number" then
		return health
	end
	return nil
end

function LootService:GetChestContents(chest)
	local data = self._chests[chest]
	if not data then
		return {}
	end
	data.SlotCount = getChestSlotCount(chest)
	data.Slots = normalizeChestSlots(data.Slots, data.SlotCount)
	local slots = {}
	for i = 1, data.SlotCount do
		local slot = data.Slots[i]
		if slot then
			slots[#slots + 1] = { Id = slot.Id, N = slot.N }
		end
	end
	return slots
end

function LootService:SpillChestContents(chest, position)
	local data = self._chests[chest]
	if not data then
		return 0
	end
	data.SlotCount = getChestSlotCount(chest)
	data.Slots = normalizeChestSlots(data.Slots, data.SlotCount)
	local root = getPrimary(chest)
	local basePos = typeof(position) == "Vector3" and position
		or (root and root.Position)
		or chest:GetPivot().Position
	local droppedStacks = 0
	for i = 1, data.SlotCount do
		local slot = data.Slots[i]
		if slot and slot.Id and slot.N > 0 then
			local offset = Vector3.new(
				DROP_RNG:NextNumber() * 4 - 2,
				2,
				DROP_RNG:NextNumber() * 4 - 2
			)
			ItemDropService:SpawnDrop(slot.Id, slot.N, basePos + offset)
			droppedStacks += 1
			data.Slots[i] = nil
		end
	end
	self:_clearChestData(chest)
	return droppedStacks
end

function LootService:_bindMonster(monster, opts)
	if not monster or not monster.Parent then return end
	local tier = (opts and opts.Tier) or getTierFromTags(monster, MONSTER_TAGS)
	local requireExplicit = opts and opts.RequireExplicit or false
	if self._monsterConns[monster] then return end
	local hum = monster:FindFirstChildOfClass("Humanoid")
	local health = findHealthValue(monster)
	local function handleDeath()
		if dropConfiguredMonsterLoot(monster) then
			if monster and monster.Parent then
				monster:Destroy()
			end
			return
		end
		local tableName = requireExplicit and getExplicitLootTableName(monster) or getLootTableName(monster)
		if requireExplicit and not tableName then
			if monster and monster.Parent then
				monster:Destroy()
			end
			return
		end
		dropLoot(monster, tier, tableName, true)
	end
	if hum then
		self._monsterConns[monster] = hum.Died:Connect(function()
			handleDeath()
		end)
	elseif health and health:IsA("NumberValue") then
		self._monsterConns[monster] = health.Changed:Connect(function()
			if health.Value <= 0 then
				handleDeath()
			end
		end)
	end
end

function LootService:Init()
	if self._initialized then return end
	self._initialized = true
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	local remote = Util.GetRemote(remotesFolder, Config.RemoteNames.ChestEvent)
	self._remote = remote
	if remote then
		remote.OnServerEvent:Connect(function(plr, action, payload)
			print(string.format("[LootService] ChestEvent %s from %s", tostring(action), plr.Name))
			if GameStateService:IsGameOver() then
				return
			end
			if action == "Open" then
				local chest = resolveChestFromPayload(payload)
				if not chest or not chest.Parent then return end
				if not isChestTagged(chest) then return end
				if not canPlayerOpenChest(plr, chest) then return end
				self:_bindChest(chest)
				self:_sendChest(plr, chest)
				return
			end
			if action == "Close" then
				self._openByPlayer[plr] = nil
				return
			end
			if action == "Move" and type(payload) == "table" then
				local chestId = payload.ChestId
				local fromIndex = tonumber(payload.FromIndex)
				local toIndex = tonumber(payload.ToIndex)
				if type(chestId) ~= "string" or not positiveInteger(fromIndex) or not positiveInteger(toIndex) then return end
				local chest = self._chestById[chestId]
				if not chest or not chest.Parent then return end
				if self._openByPlayer[plr] ~= chestId then return end
				if not canPlayerOpenChest(plr, chest) then
					self:_closeChestForPlayer(plr, chestId)
					return
				end
				local data = self._chests[chest]
				if not data then return end
				if fromIndex < 1 or fromIndex > data.SlotCount or toIndex < 1 or toIndex > data.SlotCount then return end
				if fromIndex == toIndex then return end
				local fromSlot = data.Slots[fromIndex]
				local toSlot = data.Slots[toIndex]
				if not fromSlot then return end

				if toSlot and toSlot.Id == fromSlot.Id then
					local stackMax = maxStack(fromSlot.Id)
					local space = math.max(0, stackMax - toSlot.N)
					if space <= 0 then return end
					local moved = math.min(space, fromSlot.N)
					toSlot.N += moved
					fromSlot.N -= moved
					if fromSlot.N <= 0 then
						data.Slots[fromIndex] = nil
					end
				else
					data.Slots[fromIndex], data.Slots[toIndex] = data.Slots[toIndex], data.Slots[fromIndex]
				end

				self:_updateChest(data)
				return
			end
			if action == "Put" and type(payload) == "table" then
				local chestId = payload.ChestId
				local toIndex = tonumber(payload.ToIndex)
				local fromType = payload.FromType
				local fromIndex = tonumber(payload.FromIndex)
				if type(chestId) ~= "string" or not positiveInteger(toIndex) or not positiveInteger(fromIndex) then return end

				local chest = self._chestById[chestId]
				if not chest or not chest.Parent then return end
				if self._openByPlayer[plr] ~= chestId then return end
				if not canPlayerOpenChest(plr, chest) then
					self:_closeChestForPlayer(plr, chestId)
					return
				end
				local data = self._chests[chest]
				if not data then return end
				if toIndex < 1 or toIndex > data.SlotCount then return end

				local inv = InventoryService:GetAll(plr)
				local sourceSlot = getInventorySlot(inv, fromType, fromIndex)
				if not sourceSlot then return end
				local itemId = sourceSlot.Id

				local amount = tonumber(payload.Amount) or sourceSlot.N
				if not positiveInteger(amount) then return end
				if amount > sourceSlot.N then amount = sourceSlot.N end

				local targetSlot = data.Slots[toIndex]
				if targetSlot and targetSlot.Id ~= itemId then
					return
				end

				if targetSlot then
					local stackMax = maxStack(itemId)
					local space = math.max(0, stackMax - targetSlot.N)
					if space <= 0 then return end
					amount = math.min(amount, space)
				end
				if amount <= 0 then return end

				local takenId = InventoryService:TakeFromSlot(plr, fromType, fromIndex, amount)
				if not takenId or takenId ~= itemId then return end

				if targetSlot then
					targetSlot.N += amount
				else
					data.Slots[toIndex] = { Id = itemId, N = amount }
				end
				self:_updateChest(data)
				return
			end
			if action == "Take" and type(payload) == "table" then
				local chestId = payload.ChestId
				local fromIndex = tonumber(payload.FromIndex)
				local toType = payload.ToType
				local toIndex = tonumber(payload.ToIndex)
				local amount = tonumber(payload.Amount) or 0
				if type(chestId) ~= "string" or not positiveInteger(fromIndex) or not positiveInteger(amount) then return end
				if (toType ~= nil or toIndex ~= nil) and (type(toType) ~= "string" or not positiveInteger(toIndex)) then return end
				local chest = self._chestById[chestId]
				if not chest or not chest.Parent then return end
				if self._openByPlayer[plr] ~= chestId then return end
				if not canPlayerOpenChest(plr, chest) then
					self:_closeChestForPlayer(plr, chestId)
					return
				end
				local data = self._chests[chest]
				if not data then return end
				if fromIndex < 1 or fromIndex > data.SlotCount then return end
				local slot = data.Slots[fromIndex]
				if not slot then return end
				local take = math.min(slot.N, amount)
				local added = 0
				if toType and toIndex then
					added = InventoryService:TryAddToSlot(plr, toType, toIndex, slot.Id, take)
				else
					added = InventoryService:Give(plr, slot.Id, take, true)
				end
				if added <= 0 then
					print("[LootService] Take failed (inventory full or invalid)")
					return
				end
				slot.N -= added
				if slot.N <= 0 then
					data.Slots[fromIndex] = nil
				end
				print(string.format("[LootService] Took %s x%d (remaining %d)", slot.Id, added, #data.Slots))
				self:_updateChest(data)
				return
			end
		end)
	end

	for tag in pairs(CHEST_TAGS) do
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			self:_bindChest(inst)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
			self:_bindChest(inst)
		end)
	end

	for tag in pairs(MONSTER_TAGS) do
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			self:_bindMonster(inst)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
			self:_bindMonster(inst)
		end)
	end

	-- Generic monsters (uses explicit LootTable/LootTableName if present)
	for _, inst in ipairs(CollectionService:GetTagged("Monster")) do
		self:_bindMonster(inst, { Tier = 1, RequireExplicit = true })
	end
	CollectionService:GetInstanceAddedSignal("Monster"):Connect(function(inst)
		self:_bindMonster(inst, { Tier = 1, RequireExplicit = true })
	end)

	Players.PlayerRemoving:Connect(function(plr)
		self._openByPlayer[plr] = nil
	end)
	local function bindPlayer(plr)
		plr:GetAttributeChangedSignal("IsDead"):Connect(function()
			if plr:GetAttribute("IsDead") then self:_closeChestForPlayer(plr) end
		end)
	end
	Players.PlayerAdded:Connect(bindPlayer)
	for _, plr in ipairs(Players:GetPlayers()) do bindPlayer(plr) end
	GameStateService:OnStateChanged(function(state)
		if state.MatchState == "GameOver" then
			for _, plr in ipairs(Players:GetPlayers()) do self:_closeChestForPlayer(plr) end
		end
	end)
end

function LootService:RescanChests()
	for tag in pairs(CHEST_TAGS) do
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			self:_bindChest(inst)
		end
	end
end

function LootService:RescanMonsters()
	for tag in pairs(MONSTER_TAGS) do
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			self:_bindMonster(inst)
		end
	end
	for _, inst in ipairs(CollectionService:GetTagged("Monster")) do
		self:_bindMonster(inst, { Tier = 1, RequireExplicit = true })
	end
end

return LootService
