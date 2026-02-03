-- LootTableService.lua
-- Loads loot tables from ServerStorage/LootTables and rolls items.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)

local LootTableService = {}
LootTableService._cache = {}
LootTableService._tagCache = nil

local RARITY_NAMES = {
	[1] = "Common",
	[2] = "Rare",
	[3] = "Legendary",
	[4] = "Celestial",
}

local function getLootTablesFolder()
	local folder = ServerStorage:FindFirstChild("LootTables")
	return folder
end

local function normalizePath(path)
	if type(path) ~= "string" then return nil end
	local trimmed = path:match("^%s*(.-)%s*$")
	if not trimmed or trimmed == "" then return nil end
	trimmed = trimmed:gsub("\\", "/")
	trimmed = trimmed:gsub("^LootTables/", "")
	trimmed = trimmed:gsub("^/+", "")
	trimmed = trimmed:gsub("/+$", "")
	if trimmed == "" then return nil end
	return trimmed
end

local function resolveNode(root, path)
	if not root then return nil end
	local normalized = normalizePath(path)
	if not normalized then return nil end
	local parts = {}
	for part in string.gmatch(normalized, "[^/]+") do
		if part == ".." then
			return nil
		elseif part ~= "." and part ~= "" then
			parts[#parts + 1] = part
		end
	end
	if #parts == 0 then return nil end
	local node = root
	local actualParts = {}
	for i, part in ipairs(parts) do
		local child = node:FindFirstChild(part)
		if not child and i == #parts then
			local base = part:gsub("%.lua$", "")
			if base ~= part then
				child = node:FindFirstChild(base)
			end
		end
		if not child then
			return nil
		end
		actualParts[#actualParts + 1] = child.Name
		node = child
	end
	return node, table.concat(actualParts, "/"), normalized
end

local function readValue(child, name, fallback)
	if not child then return fallback end
	local attr = child:GetAttribute(name)
	if attr ~= nil then return attr end
	local v = child:FindFirstChild(name)
	if v and v:IsA("ValueBase") then
		return v.Value
	end
	return fallback
end

local function getTagLookup()
	if LootTableService._tagCache then
		return LootTableService._tagCache
	end
	local lookup = {}
	local items = ItemDatabase:All()
	for _, item in ipairs(items) do
		local tags = item.Tags or {}
		for _, tag in ipairs(tags) do
			if type(tag) == "string" and tag ~= "" then
				local list = lookup[tag]
				if not list then
					list = {}
					lookup[tag] = list
				end
				list[#list + 1] = item.Id
			end
		end
	end
	LootTableService._tagCache = lookup
	return lookup
end

local function resolveTagEntry(entry, rng)
	if not entry or not entry.Tag then return nil end
	local lookup = getTagLookup()
	local list = lookup[entry.Tag]
	if not list or #list == 0 then return nil end
	local idx = rng:NextInteger(1, #list)
	return list[idx]
end

local function rarityNameForTier(tier)
	return RARITY_NAMES[tier] or "Common"
end

local function normalizeRarityKey(key)
	if type(key) ~= "string" then return nil end
	local k = key:lower()
	if k == "common" then return "Common" end
	if k == "rare" then return "Rare" end
	if k == "legendary" then return "Legendary" end
	if k == "celestial" then return "Celestial" end
	return nil
end

local function normalizeEntry(raw)
	if type(raw) ~= "table" then return nil end
	local tag = raw.Tag or raw.tag
	if tag ~= nil and (type(tag) ~= "string" or tag == "") then
		return nil
	end
	local id = raw.Id or raw.ItemId or raw.Name or raw[1]
	if tag == nil and type(id) ~= "string" then return nil end
	local min = raw.Min or raw.min or raw.MinCount or raw.min_count or raw[2] or 1
	local max = raw.Max or raw.max or raw.MaxCount or raw.max_count or raw[3] or min
	local weight = raw.Weight or raw.weight or raw.Probability or raw.probability or raw[4] or 1
	local minTier = raw.MinTier or raw.min_tier or raw.minTier or 1
	local maxTier = raw.MaxTier or raw.max_tier or raw.maxTier
	local chance = raw.Chance or raw.chance
	return {
		Id = (type(id) == "string" and id) or nil,
		Tag = tag,
		IsTag = tag ~= nil,
		Min = math.max(1, math.floor(tonumber(min) or 1)),
		Max = math.max(1, math.floor(tonumber(max) or min or 1)),
		Weight = math.max(0, tonumber(weight) or 0),
		MinTier = math.max(1, math.floor(tonumber(minTier) or 1)),
		MaxTier = maxTier and math.floor(tonumber(maxTier) or 0) or nil,
		Chance = chance and tonumber(chance) or nil,
	}
end

local function normalizePool(raw, name)
	if type(raw) ~= "table" then return nil end
	local tbl = {}
	tbl.Name = name or raw.Name
	tbl.Rolls = raw.Rolls or raw.rolls or raw.RollCount or raw.rollCount
	tbl.MinRolls = raw.MinRolls or raw.min_rolls or raw.MinRoll or raw.min_roll
	tbl.MaxRolls = raw.MaxRolls or raw.max_rolls or raw.MaxRoll or raw.max_roll
	tbl.Unique = raw.Unique or raw.unique or false
	tbl.AllowDuplicates = raw.AllowDuplicates
	if tbl.AllowDuplicates == nil then
		tbl.AllowDuplicates = not tbl.Unique
	end
	tbl.Chance = raw.Chance or raw.chance
	tbl.Items = {}
	for _, entry in ipairs(raw.Items or raw.items or {}) do
		local norm = normalizeEntry(entry)
		if norm then
			tbl.Items[#tbl.Items + 1] = norm
		end
	end
	tbl.Guaranteed = {}
	for _, entry in ipairs(raw.Guaranteed or raw.guaranteed or {}) do
		local norm = normalizeEntry(entry)
		if norm then
			norm.Guaranteed = true
			tbl.Guaranteed[#tbl.Guaranteed + 1] = norm
		end
	end
	return tbl
end

local function normalizeTable(raw)
	local tbl = {}
	tbl.Name = raw.Name
	tbl.Rolls = raw.Rolls or raw.rolls or raw.RollCount or raw.rollCount
	tbl.MinRolls = raw.MinRolls or raw.min_rolls or raw.MinRoll or raw.min_roll
	tbl.MaxRolls = raw.MaxRolls or raw.max_rolls or raw.MaxRoll or raw.max_roll
	tbl.Unique = raw.Unique or raw.unique or false
	tbl.AllowDuplicates = raw.AllowDuplicates
	if tbl.AllowDuplicates == nil then
		tbl.AllowDuplicates = not tbl.Unique
	end
	tbl.TierWeightMult = raw.TierWeightMult or raw.tier_weight_mult
	tbl.DropSpread = raw.DropSpread or raw.drop_spread
	tbl.DropHeight = raw.DropHeight or raw.drop_height
	tbl.Items = {}
	tbl.Guaranteed = {}
	for _, entry in ipairs(raw.Items or raw.items or {}) do
		local norm = normalizeEntry(entry)
		if norm then
			tbl.Items[#tbl.Items + 1] = norm
		end
	end
	for _, entry in ipairs(raw.Guaranteed or raw.guaranteed or {}) do
		local norm = normalizeEntry(entry)
		if norm then
			norm.Guaranteed = true
			tbl.Guaranteed[#tbl.Guaranteed + 1] = norm
		end
	end
	local rarities = raw.Rarities or raw.rarities
	if type(rarities) == "table" then
		tbl.Rarities = {}
		for key, pool in pairs(rarities) do
			local normKey = normalizeRarityKey(key) or tostring(key)
			local norm = normalizePool(pool, normKey)
			if norm then
				tbl.Rarities[normKey] = norm
			end
		end
	end
	return tbl
end

local function parseFolderTable(folder, name)
	local raw = { Name = name, Items = {} }
	raw.Rolls = readValue(folder, "Rolls", nil)
	raw.MinRolls = readValue(folder, "MinRolls", nil)
	raw.MaxRolls = readValue(folder, "MaxRolls", nil)
	raw.Unique = readValue(folder, "Unique", false)
	raw.DropSpread = readValue(folder, "DropSpread", nil)
	raw.DropHeight = readValue(folder, "DropHeight", nil)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Folder") or child:IsA("Configuration") then
			local entry = {
				Id = child.Name,
				Min = readValue(child, "Min", 1),
				Max = readValue(child, "Max", readValue(child, "Min", 1)),
				Weight = readValue(child, "Weight", 1),
				MinTier = readValue(child, "MinTier", readValue(child, "min_tier", 1)),
				MaxTier = readValue(child, "MaxTier", nil),
			}
			raw.Items[#raw.Items + 1] = entry
		end
	end
	return normalizeTable(raw)
end

function LootTableService:Get(tableName)
	local key = normalizePath(tableName)
	if not key then return nil end
	if self._cache[key] then return self._cache[key] end
	local folder = getLootTablesFolder()
	if not folder then return nil end
	local node, resolvedKey = resolveNode(folder, key)
	if not node then return nil end
	local raw = nil
	if node:IsA("ModuleScript") then
		local ok, result = pcall(require, node)
		if ok and type(result) == "table" then
			result.Name = result.Name or resolvedKey or key
			raw = normalizeTable(result)
		end
	elseif node:IsA("Folder") or node:IsA("Configuration") then
		local subModule = node:FindFirstChild("Table")
		if subModule and subModule:IsA("ModuleScript") then
			local ok, result = pcall(require, subModule)
			if ok and type(result) == "table" then
				result.Name = result.Name or resolvedKey or key
				raw = normalizeTable(result)
			end
		else
			raw = parseFolderTable(node, resolvedKey or key)
		end
	end
	if resolvedKey then
		self._cache[resolvedKey] = raw
	end
	self._cache[key] = raw
	return raw
end

local function getRollCount(tbl, rng)
	if type(tbl.Rolls) == "number" then
		return math.max(1, math.floor(tbl.Rolls))
	end
	if type(tbl.Rolls) == "table" then
		local min = tbl.Rolls.min or tbl.Rolls.Min or tbl.Rolls[1] or 1
		local max = tbl.Rolls.max or tbl.Rolls.Max or tbl.Rolls[2] or min
		min = math.max(1, math.floor(tonumber(min) or 1))
		max = math.max(min, math.floor(tonumber(max) or min))
		return rng:NextInteger(min, max)
	end
	local min = tbl.MinRolls or tbl.MinRoll or 1
	local max = tbl.MaxRolls or tbl.MaxRoll or min
	min = math.max(1, math.floor(tonumber(min) or 1))
	max = math.max(min, math.floor(tonumber(max) or min))
	return rng:NextInteger(min, max)
end

local function getRollCountWithFallback(tbl, fallback, rng)
	if tbl and (tbl.Rolls ~= nil or tbl.MinRolls ~= nil or tbl.MaxRolls ~= nil or tbl.MinRoll ~= nil or tbl.MaxRoll ~= nil) then
		return getRollCount(tbl, rng)
	end
	if fallback then
		return getRollCount(fallback, rng)
	end
	return 1
end

local function getTierWeightMult(tbl, tier)
	local mult = nil
	if type(tbl.TierWeightMult) == "table" then
		mult = tbl.TierWeightMult[tier]
	end
	if not mult then
		local cfg = Config.LOOT or {}
		local t = cfg.TierWeightMult or {}
		mult = t[tier]
	end
	mult = tonumber(mult) or 1
	if mult <= 0 then mult = 1 end
	return mult
end

local function eligible(entry, tier)
	if entry.MinTier and tier < entry.MinTier then return false end
	if entry.MaxTier and tier > entry.MaxTier then return false end
	if entry.Chance and entry.Chance < 1 then
		if math.random() > entry.Chance then
			return false
		end
	end
	return entry.Weight > 0
end

local function chooseWeighted(rng, entries)
	local total = 0
	for _, entry in ipairs(entries) do
		total += entry._weight
	end
	if total <= 0 then return nil end
	local roll = rng:NextNumber(0, total)
	for _, entry in ipairs(entries) do
		roll -= entry._weight
		if roll <= 0 then
			return entry
		end
	end
	return entries[#entries]
end

function LootTableService:Roll(tableName, tier)
	local tbl = self:Get(tableName)
	if not tbl then return {} end
	tier = math.max(1, math.floor(tonumber(tier) or 1))
	local rng = Random.new()
	local results = {}
	local tierMult = getTierWeightMult(tbl, tier)

	local activeTable = tbl
	if tbl.Rarities then
		local rarityName = rarityNameForTier(tier)
		local poolTbl = tbl.Rarities[rarityName]
		if not poolTbl then
			return {}
		end
		local chance = tonumber(poolTbl.Chance)
		if chance and chance < 1 then
			if rng:NextNumber() > chance then
				return {}
			end
		end
		activeTable = poolTbl
	end

	local pool = {}
	for _, entry in ipairs(activeTable.Items or {}) do
		if eligible(entry, tier) then
			local minTier = entry.MinTier or 1
			local weight = entry.Weight or 1
			if minTier > 1 then
				weight = weight * (tierMult ^ (minTier - 1))
			end
			local copy = {}
			for k, v in pairs(entry) do copy[k] = v end
			copy._weight = weight
			pool[#pool + 1] = copy
		end
	end

	for _, entry in ipairs(activeTable.Guaranteed or {}) do
		local itemId = entry.Id
		if entry.IsTag then
			itemId = resolveTagEntry(entry, rng)
		end
		if itemId then
			local count = rng:NextInteger(entry.Min, entry.Max)
			results[#results + 1] = { Id = itemId, N = count }
		end
	end

	local rolls = getRollCountWithFallback(activeTable, tbl, rng)
	local unique = not (activeTable.AllowDuplicates == true)

	for i = 1, rolls do
		if #pool == 0 then break end
		local entry = chooseWeighted(rng, pool)
		if entry then
			local itemId = entry.Id
			if entry.IsTag then
				itemId = resolveTagEntry(entry, rng)
			end
			if itemId then
				local count = rng:NextInteger(entry.Min, entry.Max)
				results[#results + 1] = { Id = itemId, N = count }
				if unique then
					if entry.IsTag then
						for idx = #pool, 1, -1 do
							if pool[idx] == entry then
								table.remove(pool, idx)
								break
							end
						end
					else
						for idx = #pool, 1, -1 do
							if pool[idx].Id == entry.Id then
								table.remove(pool, idx)
							end
						end
					end
				end
			else
				for idx = #pool, 1, -1 do
					if pool[idx] == entry then
						table.remove(pool, idx)
						break
					end
				end
			end
		end
	end

	-- Merge stacks
	local merged = {}
	for _, item in ipairs(results) do
		merged[item.Id] = (merged[item.Id] or 0) + item.N
	end
	local out = {}
	for id, count in pairs(merged) do
		local stackMax = (ItemDatabase:Get(id) and ItemDatabase:Get(id).StackSize) or 99
		local remaining = count
		while remaining > 0 do
			local add = math.min(stackMax, remaining)
			out[#out + 1] = { Id = id, N = add }
			remaining -= add
		end
	end
	return out
end

return LootTableService
