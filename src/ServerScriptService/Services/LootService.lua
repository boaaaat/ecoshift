-- LootService.lua
-- Handles chest prompts, chest UI sync, and monster loot drops.
local CollectionService = game:GetService("CollectionService")
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

local LootService = {}
LootService._chests = {} -- [Instance] = { Id, Tier, Table, Slots }
LootService._chestById = {}
LootService._openByPlayer = {} -- [player] = chestId
LootService._monsterConns = setmetatable({}, { __mode = "k" })

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

local function getTierFromTags(instance, map)
	for tag, tier in pairs(map) do
		if CollectionService:HasTag(instance, tag) then
			return tier
		end
	end
	return 1
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
	return cfg.DefaultTable or "Default"
end

local function getPrimary(model)
	if model:IsA("BasePart") then return model end
	if model.PrimaryPart then return model.PrimaryPart end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then return d end
	end
	return nil
end

local function compressSlots(items)
	local slots = {}
	for _, item in ipairs(items) do
		slots[#slots + 1] = { Id = item.Id, N = item.N }
	end
	return slots
end

local function compactSlots(slots)
	local out = {}
	for _, slot in ipairs(slots) do
		if slot and slot.Id and slot.N and slot.N > 0 then
			out[#out + 1] = { Id = slot.Id, N = slot.N }
		end
	end
	return out
end

function LootService:_ensureChestData(chest)
	local data = self._chests[chest]
	if data then return data end
	local id = HttpService:GenerateGUID(false)
	local tier = getTierFromTags(chest, CHEST_TAGS)
	local tableName = getLootTableName(chest)
	local items = LootTableService:Roll(tableName, tier)
	data = {
		Id = id,
		Tier = tier,
		Table = tableName,
		Slots = compressSlots(items),
	}
	self._chests[chest] = data
	self._chestById[id] = chest
	return data
end

function LootService:_sendChest(plr, chest)
	local data = self:_ensureChestData(chest)
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	local remote = Util.GetRemote(remotesFolder, Config.RemoteNames.ChestEvent)
	if not remote then return end
	self._openByPlayer[plr] = data.Id
	remote:FireClient(plr, "Open", {
		ChestId = data.Id,
		Tier = data.Tier,
		Table = data.Table,
		Slots = data.Slots,
		Title = chest.Name,
	})
end

function LootService:_updateChest(plr, data)
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	local remote = Util.GetRemote(remotesFolder, Config.RemoteNames.ChestEvent)
	if not remote then return end
	remote:FireClient(plr, "Update", {
		ChestId = data.Id,
		Slots = data.Slots,
	})
end

local function attachChestPrompt(chest)
	local part = getPrimary(chest)
	if not part then return end
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open"
		prompt.ObjectText = chest.Name
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end
	prompt.Triggered:Connect(function(plr)
		LootService:_sendChest(plr, chest)
	end)
end

function LootService:_bindChest(chest)
	if not chest or not chest.Parent then return end
	PromptQueueService:Enqueue(function()
		attachChestPrompt(chest)
	end)
end

local function dropLoot(model, tier)
	if not model or model:GetAttribute("LootDropped") then return end
	model:SetAttribute("LootDropped", true)
	local tableName = getLootTableName(model)
	local items = LootTableService:Roll(tableName, tier)
	local root = getPrimary(model)
	local pos = root and root.Position or model:GetPivot().Position
	local cfg = Config.LOOT or {}
	local spread = tonumber(cfg.DropSpread) or 4
	local height = tonumber(cfg.DropHeight) or 2
	for _, item in ipairs(items) do
		local offset = Vector3.new(
			math.random() * spread - spread * 0.5,
			height,
			math.random() * spread - spread * 0.5
		)
		ItemDropService:SpawnDrop(item.Id, item.N, pos + offset)
	end
end

function LootService:_bindMonster(monster)
	if not monster or not monster.Parent then return end
	local tier = getTierFromTags(monster, MONSTER_TAGS)
	if self._monsterConns[monster] then return end
	local hum = monster:FindFirstChildOfClass("Humanoid")
	local health = monster:FindFirstChild("Health")
	if hum then
		self._monsterConns[monster] = hum.Died:Connect(function()
			dropLoot(monster, tier)
		end)
	elseif health and health:IsA("NumberValue") then
		self._monsterConns[monster] = health.Changed:Connect(function()
			if health.Value <= 0 then
				dropLoot(monster, tier)
			end
		end)
	end
end

function LootService:Init()
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	local remote = Util.GetRemote(remotesFolder, Config.RemoteNames.ChestEvent)
	if remote then
		remote.OnServerEvent:Connect(function(plr, action, payload)
			if action == "Close" then
				self._openByPlayer[plr] = nil
				return
			end
			if action == "Take" and type(payload) == "table" then
				local chestId = payload.ChestId
				local fromIndex = tonumber(payload.FromIndex)
				local toType = payload.ToType
				local toIndex = tonumber(payload.ToIndex)
				local amount = tonumber(payload.Amount) or 0
				if not chestId or not fromIndex then return end
				if amount <= 0 then return end
				local chest = self._chestById[chestId]
				if not chest or not chest.Parent then return end
				if self._openByPlayer[plr] ~= chestId then return end
				local data = self._chests[chest]
				if not data then return end
				local slot = data.Slots[fromIndex]
				if not slot then return end
				local take = math.min(slot.N, amount)
				local added = 0
				if toType and toIndex then
					added = InventoryService:TryAddToSlot(plr, toType, toIndex, slot.Id, take)
				end
				if added <= 0 then
					added = InventoryService:Give(plr, slot.Id, take, true)
				end
				if added <= 0 then return end
				slot.N -= added
				if slot.N <= 0 then
					data.Slots[fromIndex] = nil
				end
				data.Slots = compactSlots(data.Slots)
				self:_updateChest(plr, data)
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
end

return LootService
