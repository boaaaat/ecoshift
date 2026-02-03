-- ChunkStreamingService.lua
-- Dynamically loads/unloads world chunks around players
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldGenConfig = require(ReplicatedStorage.Shared.BiomeConfig)
local BiomeService = require(script.Parent.BiomeService)
local ResourceNodeService = require(script.Parent.ResourceNodeService)

-- Lazy-load LootService to avoid circular dependency
local LootService = nil
local function getLootService()
	if not LootService then
		LootService = require(script.Parent.LootService)
	end
	return LootService
end

local ChunkStreamingService = {}
ChunkStreamingService._loadedChunks = {} -- [chunkKey] = { folder, lastAccess, objects }
ChunkStreamingService._loadingChunks = {} -- [chunkKey] = true (currently loading)
ChunkStreamingService._chunkFolders = {} -- [chunkKey] = Folder
ChunkStreamingService._initialized = false
ChunkStreamingService._currentBiome = "Forest"
ChunkStreamingService._prefabRoots = nil
ChunkStreamingService._prefabLookup = {}
ChunkStreamingService._chestLookup = nil
ChunkStreamingService._chestLookupFolder = nil
ChunkStreamingService._biomes = nil

-- Config (read from BiomeConfig or use defaults)
local CHUNK_SIZE = WorldGenConfig.chunk_size or 240
local LOAD_RADIUS = WorldGenConfig.stream_load_radius or 3 -- Load chunks within this radius (in chunks) around player
local UNLOAD_RADIUS = WorldGenConfig.stream_unload_radius or 5 -- Unload chunks beyond this radius
local UPDATE_INTERVAL = WorldGenConfig.stream_update_interval or 0.5 -- How often to check player positions
local UNLOAD_DELAY = WorldGenConfig.stream_unload_delay or 10 -- Seconds before unloading an unused chunk
local BASE_Y = WorldGenConfig.base_y or 0
local WORLD_RADIUS = WorldGenConfig.world_radius or 2200
local CENTER_EXCLUSION = WorldGenConfig.center_exclusion_radius or 260
local CENTER_EXCLUSION_SQ = CENTER_EXCLUSION * CENTER_EXCLUSION
local SPAWN_ENEMIES = WorldGenConfig.spawn_enemies ~= false

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function isInsideCenterExclusion(x, z)
	if CENTER_EXCLUSION <= 0 then
		return false
	end
	return (x * x + z * z) <= CENTER_EXCLUSION_SQ
end

local function distanceT(x, z)
	local inner = CENTER_EXCLUSION or 0
	local outer = WORLD_RADIUS or 1
	if outer <= inner then
		return 0
	end
	local dist = math.sqrt((x * x) + (z * z))
	return math.clamp((dist - inner) / math.max(outer - inner, 1), 0, 1)
end

local function distanceWeightFactor(weight, t)
	if t == nil then
		return 1
	end
	if type(weight) == "table" then
		local min = tonumber(weight.Min or weight.min) or 1
		local max = tonumber(weight.Max or weight.max) or 1
		return math.max(0, lerp(min, max, t))
	end
	if weight == nil then
		return 1
	end
	local w = tonumber(weight) or 1
	return math.max(0, lerp(1, w, t))
end

local function entryWeight(entry, distance_t)
	local weight = tonumber(entry.Weight or entry.weight) or 1
	if distance_t ~= nil then
		local dWeight = entry.DistanceWeight or entry.distanceWeight
		weight = weight * distanceWeightFactor(dWeight, distance_t)
	end
	return weight
end

local function distanceFactorForList(list, distance_t)
	if distance_t == nil or not list or #list == 0 then
		return 1
	end
	local total = 0
	local weighted = 0
	for _, entry in ipairs(list) do
		local base = tonumber(entry.Weight or entry.weight) or 1
		if base > 0 then
			local dWeight = entry.DistanceWeight or entry.distanceWeight
			local factor = distanceWeightFactor(dWeight, distance_t)
			total += base
			weighted += base * factor
		end
	end
	if total <= 0 then
		return 1
	end
	return weighted / total
end

local CHEST_TAG_ORDER = {
	"Common_Chest",
	"Rare_Chest",
	"Legendary_Chest",
	"Celestial_Chest",
}

local function getTierFromInstance(instance)
	if not instance then return 1 end
	for tier, tag in ipairs(CHEST_TAG_ORDER) do
		if CollectionService:HasTag(instance, tag) then
			return tier
		end
	end
	local name = instance.Name:lower()
	if name:find("celestial") then
		return 4
	elseif name:find("legendary") then
		return 3
	elseif name:find("rare") then
		return 2
	end
	return 1
end

local function ensureChestTag(instance)
	if not instance then return end
	for _, tag in ipairs(CHEST_TAG_ORDER) do
		if CollectionService:HasTag(instance, tag) then
			return
		end
	end
	local tier = getTierFromInstance(instance)
	CollectionService:AddTag(instance, CHEST_TAG_ORDER[tier] or "Common_Chest")
end

local function normalizeTierKey(key)
	if type(key) == "number" then
		local t = math.floor(key)
		if t >= 1 and t <= 4 then
			return t
		end
	elseif type(key) == "string" then
		local n = tonumber(key)
		if n then
			return normalizeTierKey(n)
		end
		local k = key:lower()
		if k == "common" then return 1 end
		if k == "rare" then return 2 end
		if k == "legendary" then return 3 end
		if k == "celestial" then return 4 end
	end
	return nil
end

local function normalizeTierWeightsConfig(raw)
	local out = {}
	if type(raw) ~= "table" then return out end
	if #raw > 0 then
		for i = 1, math.min(4, #raw) do
			out[i] = raw[i]
		end
	else
		for key, val in pairs(raw) do
			local t = normalizeTierKey(key)
			if t then
				out[t] = val
			end
		end
	end
	return out
end

local function tierWeightForDistance(entry, distance_t)
	if entry == nil then return 0 end
	if type(entry) == "number" then
		return entry
	end
	if type(entry) == "table" then
		local base = tonumber(entry.Weight or entry.weight) or 0
		local dWeight = entry.DistanceWeight or entry.distanceWeight
		if distance_t ~= nil and dWeight ~= nil then
			base = base * distanceWeightFactor(dWeight, distance_t)
		end
		return base
	end
	return 0
end

local function chooseTier(weights, rng)
	local total = 0
	for _, w in pairs(weights) do
		total += w
	end
	if total <= 0 then return nil end
	local roll = rng:NextNumber(0, total)
	for tier = 1, 4 do
		local w = weights[tier] or 0
		if w > 0 then
			roll -= w
			if roll <= 0 then
				return tier
			end
		end
	end
	return 1
end

local function nameMatchesPrefixes(name, prefixes)
	for _, prefix in ipairs(prefixes) do
		if name == prefix or name:sub(1, #prefix + 1) == (prefix .. "_") then
			return true
		end
	end
	return false
end

local function collectSpawnPoints(root, prefixes)
	local points = {}
	if not root or not prefixes or #prefixes == 0 then return points end
	for _, d in ipairs(root:GetDescendants()) do
		if (d:IsA("BasePart") or d:IsA("Attachment")) and nameMatchesPrefixes(d.Name, prefixes) then
			points[#points + 1] = d
		end
	end
	return points
end

local function getSpawnPointCFrame(point)
	if point:IsA("Attachment") then
		return point.WorldCFrame
	end
	return point.CFrame
end

local function shuffle(list, rng)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

local function chunkKey(cx, cz)
	return cx .. "," .. cz
end

local function parseChunkKey(key)
	local cx, cz = key:match("([^,]+),([^,]+)")
	return tonumber(cx), tonumber(cz)
end

local function worldToChunk(x, z)
	local cx = math.floor(x / CHUNK_SIZE)
	local cz = math.floor(z / CHUNK_SIZE)
	return cx, cz
end

local function chunkToWorld(cx, cz)
	local x = cx * CHUNK_SIZE + CHUNK_SIZE * 0.5
	local z = cz * CHUNK_SIZE + CHUNK_SIZE * 0.5
	return x, z
end

local function getChunkDistance(cx1, cz1, cx2, cz2)
	return math.max(math.abs(cx1 - cx2), math.abs(cz1 - cz2))
end

local function randomInRange(rng, value)
	if type(value) == "table" then
		return rng:NextInteger(value.min or 0, value.max or 0)
	elseif type(value) == "number" then
		return value
	end
	return 0
end

local function getOffsetValue(obj)
	local offsetVal = obj:FindFirstChild("Offset", true)
	if offsetVal and offsetVal:IsA("NumberValue") then
		return offsetVal.Value
	end
	return 0
end

function ChunkStreamingService:_ensureWorldFolder()
	local folderName = WorldGenConfig.spawn_folder_name or "GeneratedWorld"
	local folder = Workspace:FindFirstChild(folderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = Workspace
	end
	self._worldFolder = folder
	
	-- Create subfolders
	local subfolders = {"Resources", "Props", "Structures", "Objectives", "Enemies"}
	for _, name in ipairs(subfolders) do
		if not folder:FindFirstChild(name) then
			local sub = Instance.new("Folder")
			sub.Name = name
			sub.Parent = folder
		end
	end
end

function ChunkStreamingService:_initPrefabRoots()
	if self._prefabRoots then return end
	
	local prefabFolderNames = {
		ResourcePrefabs = "ResourcePrefabs",
		PropPrefabs = "PropPrefabs",
		StructurePrefabs = "StructurePrefabs",
		ObjectivePrefabs = "ObjectivePrefabs",
		EnemyPrefabs = "EnemyPrefabs",
	}
	
	self._prefabRoots = {}
	for key, folderName in pairs(prefabFolderNames) do
		local folder = ServerStorage:FindFirstChild(folderName)
		if folder then
			self._prefabRoots[key] = folder
		end
	end
end

function ChunkStreamingService:_initBiomes()
	if self._biomes then return end
	
	-- BiomeConfig.biomes is a dictionary {name = biomeData}
	-- Convert to array format with name field
	self._biomes = {}
	local configBiomes = WorldGenConfig.biomes or {}
	for name, biomeData in pairs(configBiomes) do
		local biome = {}
		for k, v in pairs(biomeData) do
			biome[k] = v
		end
		biome.name = name
		table.insert(self._biomes, biome)
	end
end

function ChunkStreamingService:_findBiome(name)
	if not name then return nil end
	for _, biome in ipairs(self._biomes) do
		if biome.name == name then
			return biome
		end
	end
	return nil
end

function ChunkStreamingService:_getPrefabLookup(typeName, biomeName)
	local biomeCache = self._prefabLookup[biomeName]
	if not biomeCache then
		biomeCache = {}
		self._prefabLookup[biomeName] = biomeCache
	end
	local typeCache = biomeCache[typeName]
	if typeCache then
		return typeCache
	end
	local root = self._prefabRoots[typeName]
	local folder = root and root:FindFirstChild(biomeName)
	local lookup = {}
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			lookup[child.Name] = child
		end
	end
	biomeCache[typeName] = lookup
	return lookup
end

function ChunkStreamingService:_getChestLookup()
	local folder = ServerStorage:FindFirstChild("Chests")
	if self._chestLookup and self._chestLookupFolder == folder then
		return self._chestLookup
	end
	local lookup = {}
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			lookup[child.Name] = child
		end
	end
	self._chestLookup = lookup
	self._chestLookupFolder = folder
	return lookup
end

local function resolveLookupWeighted(lookup, names)
	local list = {}
	if not lookup then return list end

	if names == true or names == "*" then
		for _, prefab in pairs(lookup) do
			list[#list + 1] = { Prefab = prefab, Weight = 1 }
		end
		return list
	end

	if type(names) == "table" then
		if #names > 0 then
			for _, entry in ipairs(names) do
				if type(entry) == "string" then
					local prefab = lookup[entry]
					if prefab then
						list[#list + 1] = { Prefab = prefab, Weight = 1 }
					end
				elseif type(entry) == "table" then
					local name = entry.Name or entry.Id or entry.Prefab or entry[1]
					local weight = tonumber(entry.Weight or entry.weight) or 1
					local distance_weight = entry.DistanceWeight or entry.distanceWeight
					if type(name) == "string" then
						local prefab = lookup[name]
						if prefab and weight > 0 then
							list[#list + 1] = { Prefab = prefab, Weight = weight, DistanceWeight = distance_weight }
						end
					end
				end
			end
		else
			for key, value in pairs(names) do
				if type(key) == "string" then
					local prefab = lookup[key]
					local weight = 1
					local distance_weight = nil
					if type(value) == "number" then
						weight = value
					elseif type(value) == "table" then
						weight = tonumber(value.Weight or value.weight) or 1
						distance_weight = value.DistanceWeight or value.distanceWeight
					end
					if prefab and weight > 0 then
						list[#list + 1] = { Prefab = prefab, Weight = weight, DistanceWeight = distance_weight }
					end
				end
			end
		end
	end
	return list
end

function ChunkStreamingService:_resolvePrefabsWeighted(typeName, biomeName, names)
	local lookup = self:_getPrefabLookup(typeName, biomeName)
	local list = {}
	
	if names == true or names == "*" then
		for _, prefab in pairs(lookup) do
			list[#list + 1] = { Prefab = prefab, Weight = 1 }
		end
		return list
	end
	
	if type(names) == "table" then
		if #names > 0 then
			for _, entry in ipairs(names) do
				if type(entry) == "string" then
					local prefab = lookup[entry]
					if prefab then
						list[#list + 1] = { Prefab = prefab, Weight = 1 }
					end
				elseif type(entry) == "table" then
					local name = entry.Name or entry.Id or entry.Prefab or entry[1]
					local weight = tonumber(entry.Weight or entry.weight) or 1
					local distance_weight = entry.DistanceWeight or entry.distanceWeight
					if type(name) == "string" then
						local prefab = lookup[name]
						if prefab and weight > 0 then
							list[#list + 1] = { Prefab = prefab, Weight = weight, DistanceWeight = distance_weight }
						end
					end
				end
			end
		else
			for key, value in pairs(names) do
				if type(key) == "string" then
					local prefab = lookup[key]
					local weight = 1
					local distance_weight = nil
					if type(value) == "number" then
						weight = value
					elseif type(value) == "table" then
						weight = tonumber(value.Weight or value.weight) or 1
						distance_weight = value.DistanceWeight or value.distanceWeight
					end
					if prefab and weight > 0 then
						list[#list + 1] = { Prefab = prefab, Weight = weight, DistanceWeight = distance_weight }
					end
				end
			end
		end
	end
	return list
end

function ChunkStreamingService:_getStructureChestConfig(biome, structureName)
	local map = nil
	if biome and type(biome.structure_chests) == "table" then
		map = biome.structure_chests
	else
		map = WorldGenConfig.structure_chests
	end
	if type(map) ~= "table" then return nil end
	local defaultCfg = map.Default or map.default
	local specificCfg = map[structureName]
	if not defaultCfg and not specificCfg then
		return nil
	end
	local merged = {}
	if type(defaultCfg) == "table" then
		for k, v in pairs(defaultCfg) do
			merged[k] = v
		end
	end
	if type(specificCfg) == "table" then
		for k, v in pairs(specificCfg) do
			merged[k] = v
		end
	end
	return merged
end

function ChunkStreamingService:_resolveChestEntries(biomeName, chestNames)
	local chestLookup = self:_getChestLookup()
	local entries = resolveLookupWeighted(chestLookup, chestNames)
	if #entries == 0 then
		entries = self:_resolvePrefabsWeighted("StructurePrefabs", biomeName, chestNames)
	end
	if #entries == 0 then
		entries = self:_resolvePrefabsWeighted("PropPrefabs", biomeName, chestNames)
	end
	return entries
end

function ChunkStreamingService:_spawnStructureChests(structureClone, biomeName, structureName, rng, biome)
	if not structureClone or not structureClone.Parent then return end
	local cfg = self:_getStructureChestConfig(biome, structureName)
	if not cfg then return end

	local prefixes = cfg.spawn_points or cfg.spawnPoints or {"ChestSpawn"}
	local spawnPoints = collectSpawnPoints(structureClone, prefixes)
	if #spawnPoints == 0 then return end

	local rawCount = cfg.count or cfg.Count
	local count = randomInRange(rng, rawCount)
	if rawCount == nil then
		count = 1
	end
	count = math.max(0, math.floor(tonumber(count) or 0))
	if count <= 0 then return end

	if count > #spawnPoints then
		count = #spawnPoints
	end

	shuffle(spawnPoints, rng)

	local chestNames = cfg.chests or cfg.Chests
	if chestNames == nil and biome then
		chestNames = biome.chests or biome.Chests
	end
	if chestNames == nil then return end

	local entries = self:_resolveChestEntries(biomeName, chestNames)
	if #entries == 0 then return end

	local tierLists = { {}, {}, {}, {} }
	for _, entry in ipairs(entries) do
		local tier = getTierFromInstance(entry.Prefab)
		tierLists[tier][#tierLists[tier] + 1] = entry
	end

	local tierConfig = normalizeTierWeightsConfig(cfg.tier_weights or cfg.tierWeights)

	for i = 1, count do
		local point = spawnPoints[i]
		local cf = getSpawnPointCFrame(point)
		local pos = cf.Position
		local distance_t = distanceT(pos.X, pos.Z)

		local weights = {}
		local total = 0
		for tier = 1, 4 do
			if #tierLists[tier] > 0 then
				local w = tierWeightForDistance(tierConfig[tier], distance_t)
				if w > 0 then
					weights[tier] = w
					total += w
				end
			end
		end
		if total <= 0 then
			for tier = 1, 4 do
				if #tierLists[tier] > 0 then
					weights[tier] = 1
					total += 1
				end
			end
		end
		if total <= 0 then
			return
		end

		local chosenTier = chooseTier(weights, rng)
		local list = chosenTier and tierLists[chosenTier] or nil
		if not list or #list == 0 then
			for tier = 1, 4 do
				if #tierLists[tier] > 0 then
					list = tierLists[tier]
					break
				end
			end
		end
		if not list or #list == 0 then
			return
		end

		local prefab = self:_chooseWeighted(list, rng, distance_t)
		if prefab then
			local clone = prefab:Clone()
			local yOffset = getOffsetValue(clone)
			local targetCf = cf * CFrame.new(0, yOffset, 0)
			if clone:IsA("Model") then
				clone:PivotTo(targetCf)
			elseif clone:IsA("BasePart") then
				clone.CFrame = targetCf
			end
			local lootTable = cfg.loot_table or cfg.lootTable or cfg.LootTable or cfg.lootTableName or cfg.LootTableName
			if type(lootTable) == "string" and lootTable ~= "" then
				clone:SetAttribute("LootTable", lootTable)
			end
			ensureChestTag(clone)

			local parent = structureClone
			if not (parent:IsA("Model") or parent:IsA("Folder")) then
				parent = structureClone.Parent
			end
			if parent then
				clone.Parent = parent
				local loot = getLootService()
				if loot and loot._ensureChestData then
					loot:_ensureChestData(clone)
				end
			end
		end
	end
end

function ChunkStreamingService:_chooseWeighted(list, rng, distance_t)
	local total = 0
	for _, entry in ipairs(list) do
		total += entryWeight(entry, distance_t)
	end
	if total <= 0 then return nil end
	local roll = rng:NextNumber(0, total)
	for _, entry in ipairs(list) do
		roll -= entryWeight(entry, distance_t)
		if roll <= 0 then
			return entry.Prefab
		end
	end
	return list[#list] and list[#list].Prefab
end

function ChunkStreamingService:_getOrCreateChunkFolder(cx, cz)
	local key = chunkKey(cx, cz)
	if self._chunkFolders[key] then
		return self._chunkFolders[key]
	end
	
	local folder = Instance.new("Folder")
	folder.Name = "Chunk_" .. key
	folder.Parent = self._worldFolder
	folder:SetAttribute("ChunkX", cx)
	folder:SetAttribute("ChunkZ", cz)
	
	self._chunkFolders[key] = folder
	return folder
end

function ChunkStreamingService:_loadChunk(cx, cz)
	local key = chunkKey(cx, cz)
	
	-- Already loaded or loading
	if self._loadedChunks[key] or self._loadingChunks[key] then
		if self._loadedChunks[key] then
			self._loadedChunks[key].lastAccess = os.clock()
		end
		return
	end
	
	-- Check if within world bounds
	local worldX, worldZ = chunkToWorld(cx, cz)
	local dist = math.sqrt(worldX * worldX + worldZ * worldZ)
	
	if dist > WORLD_RADIUS or isInsideCenterExclusion(worldX, worldZ) then
		return -- Outside world bounds
	end
	
	self._loadingChunks[key] = true
	
	task.spawn(function()
		local chunkFolder = self:_getOrCreateChunkFolder(cx, cz)
		local chunkCenter = Vector3.new(worldX, BASE_Y, worldZ)
		
		-- Generate chunk content
		self:_generateChunkContent(cx, cz, chunkCenter, chunkFolder)
		
		self._loadedChunks[key] = {
			folder = chunkFolder,
			lastAccess = os.clock(),
			cx = cx,
			cz = cz,
		}
		self._loadingChunks[key] = nil
		
		-- Bind resource nodes in this chunk
		task.defer(function()
			ResourceNodeService:BindFolder(chunkFolder)
			
			-- Bind chests and monsters for loot system
			local loot = getLootService()
			if loot then
				-- Scan chunk folder for tagged chests and monsters
				for _, descendant in ipairs(chunkFolder:GetDescendants()) do
					-- Check chest tags
					if CollectionService:HasTag(descendant, "Common_Chest") or
					   CollectionService:HasTag(descendant, "Rare_Chest") or
					   CollectionService:HasTag(descendant, "Legendary_Chest") or
					   CollectionService:HasTag(descendant, "Celestial_Chest") then
						if loot._bindChest then
							loot:_bindChest(descendant)
						end
					end
					-- Check monster tags
					if CollectionService:HasTag(descendant, "Common_Monster") or
					   CollectionService:HasTag(descendant, "Rare_Monster") or
					   CollectionService:HasTag(descendant, "Legendary_Monster") or
					   CollectionService:HasTag(descendant, "Celestial_Monster") then
						if loot._bindMonster then
							loot:_bindMonster(descendant)
						end
					end
				end
			end
		end)
	end)
end

function ChunkStreamingService:_generateChunkContent(cx, cz, chunkCenter, chunkFolder)
	local biome = self:_findBiome(self._currentBiome)
	if not biome then 
		biome = self._biomes[1]
	end
	if not biome then return end
	
	local biomeName = biome.name
	
	-- Create chunk-local subfolders
	local subfolders = {}
	for _, name in ipairs({"Resources", "Props", "Structures", "Objectives", "Enemies"}) do
		local sub = chunkFolder:FindFirstChild(name)
		if not sub then
			sub = Instance.new("Folder")
			sub.Name = name
			sub.Parent = chunkFolder
		end
		subfolders[name] = sub
	end
	
	-- Use chunk coords as seed modifier for deterministic generation
	local seed = WorldGenConfig.seed or 12345
	local chunkSeed = seed + cx * 73856093 + cz * 19349663
	local rng = Random.new(chunkSeed)
	local distance_t = distanceT(chunkCenter.X, chunkCenter.Z)
	
	-- Generate regions in this chunk
	local regionCount = randomInRange(rng, biome.region_count or biome.regionCount) or 1
	if regionCount < 1 then regionCount = 1 end
	
	for _ = 1, regionCount do
		local regionDef = nil
		if biome.regions and #biome.regions > 0 then
			regionDef = biome.regions[rng:NextInteger(1, #biome.regions)]
		end
		if regionDef then
			self:_scatterInChunk(biomeName, chunkCenter, regionDef, subfolders, rng, distance_t)
		end
	end
	
	-- Structures (probability per chunk)
	local structureChance = tonumber(biome.structure_count or biome.structureCount) or 0
	local structurePrefabs = self:_resolvePrefabsWeighted("StructurePrefabs", biomeName, biome.structures)
	local structureFactor = distanceFactorForList(structurePrefabs, distance_t)
	if rng:NextNumber() <= math.clamp(structureChance * structureFactor, 0, 1) then
		self:_placeStructure(biomeName, chunkCenter, biome.structures, subfolders.Structures, rng, structurePrefabs, distance_t, biome)
	end
	
	-- Chests (probability per chunk)
	local chestChance = tonumber(biome.chest_count or biome.chestCount) or 0
	if biome.chests then
		local chestPrefabs = self:_resolveChestEntries(biomeName, biome.chests)
		local chestFactor = distanceFactorForList(chestPrefabs, distance_t)
		if rng:NextNumber() <= math.clamp(chestChance * chestFactor, 0, 1) then
			self:_placeChest(biomeName, chunkCenter, biome.chests, subfolders.Structures, rng, chestPrefabs, distance_t)
		end
	end
	
	-- Objectives (probability per chunk)
	local objectiveChance = tonumber(biome.objective_count or biome.objectiveCount) or 0
	local objectivePrefabs = self:_resolvePrefabsWeighted("ObjectivePrefabs", biomeName, biome.objectives)
	local objectiveFactor = distanceFactorForList(objectivePrefabs, distance_t)
	if rng:NextNumber() <= math.clamp(objectiveChance * objectiveFactor, 0, 1) then
		self:_placeStructure(biomeName, chunkCenter, biome.objectives, subfolders.Objectives, rng, objectivePrefabs, distance_t, biome)
	end
end

function ChunkStreamingService:_scatterInChunk(biomeName, chunkCenter, regionDef, subfolders, rng, distance_t)
	local half = CHUNK_SIZE * 0.4
	
	-- Resources
	local resourcePrefabs = self:_resolvePrefabsWeighted("ResourcePrefabs", biomeName, regionDef.resources)
	local resourceCount = randomInRange(rng, regionDef.resource_count or regionDef.resourceCount) or 5
	local resourceFactor = distanceFactorForList(resourcePrefabs, distance_t)
	resourceCount = math.max(0, math.floor(resourceCount * resourceFactor + 0.5))
	
	for _ = 1, resourceCount do
		local prefab = self:_chooseWeighted(resourcePrefabs, rng, distance_t)
		if prefab then
			local x = chunkCenter.X + rng:NextNumber(-half, half)
			local z = chunkCenter.Z + rng:NextNumber(-half, half)
			local position = Vector3.new(x, BASE_Y, z)
			self:_placePrefab(prefab, position, subfolders.Resources)
		end
	end
	
	-- Props
	local propPrefabs = self:_resolvePrefabsWeighted("PropPrefabs", biomeName, regionDef.props)
	local propCount = randomInRange(rng, regionDef.prop_count or regionDef.propCount) or 3
	local propFactor = distanceFactorForList(propPrefabs, distance_t)
	propCount = math.max(0, math.floor(propCount * propFactor + 0.5))
	
	for _ = 1, propCount do
		local prefab = self:_chooseWeighted(propPrefabs, rng, distance_t)
		if prefab then
			local x = chunkCenter.X + rng:NextNumber(-half, half)
			local z = chunkCenter.Z + rng:NextNumber(-half, half)
			local position = Vector3.new(x, BASE_Y, z)
			self:_placePrefab(prefab, position, subfolders.Props)
		end
	end
	
	if SPAWN_ENEMIES then
		-- Enemies
		local enemyPrefabs = self:_resolvePrefabsWeighted("EnemyPrefabs", biomeName, regionDef.enemies)
		local enemyCount = randomInRange(rng, regionDef.enemy_count or regionDef.enemyCount) or 0
		local enemyFactor = distanceFactorForList(enemyPrefabs, distance_t)
		enemyCount = math.max(0, math.floor(enemyCount * enemyFactor + 0.5))
		
		for _ = 1, enemyCount do
			local prefab = self:_chooseWeighted(enemyPrefabs, rng, distance_t)
			if prefab then
				local x = chunkCenter.X + rng:NextNumber(-half, half)
				local z = chunkCenter.Z + rng:NextNumber(-half, half)
				local position = Vector3.new(x, BASE_Y, z)
				self:_placePrefab(prefab, position, subfolders.Enemies)
			end
		end
	end
end

function ChunkStreamingService:_placeStructure(biomeName, chunkCenter, names, parent, rng, prefabs, distance_t, biome)
	if (not names or (type(names) == "table" and #names == 0)) and not prefabs then return end
	
	local prefabs = prefabs or self:_resolvePrefabsWeighted("StructurePrefabs", biomeName, names)
	if #prefabs == 0 then
		-- Try ObjectivePrefabs for objectives
		prefabs = self:_resolvePrefabsWeighted("ObjectivePrefabs", biomeName, names)
	end
	if #prefabs == 0 then return end
	
	local prefab = self:_chooseWeighted(prefabs, rng, distance_t)
	if prefab then
		local half = CHUNK_SIZE * 0.3
		local x = chunkCenter.X + rng:NextNumber(-half, half)
		local z = chunkCenter.Z + rng:NextNumber(-half, half)
		local position = Vector3.new(x, BASE_Y, z)
		local clone = self:_placePrefab(prefab, position, parent)
		if clone and parent and parent.Name == "Structures" then
			self:_spawnStructureChests(clone, biomeName, prefab.Name, rng, biome)
		end
	end
end

function ChunkStreamingService:_placeChest(biomeName, chunkCenter, chestNames, parent, rng, prefabs, distance_t)
	if (not chestNames or (type(chestNames) == "table" and #chestNames == 0)) and not prefabs then return end
	
	-- Try chest folder first, then structure/prop prefabs
	local prefabs = prefabs or self:_resolveChestEntries(biomeName, chestNames)
	if #prefabs == 0 then return end
	
	local prefab = self:_chooseWeighted(prefabs, rng, distance_t)
	if prefab then
		local half = CHUNK_SIZE * 0.35
		local x = chunkCenter.X + rng:NextNumber(-half, half)
		local z = chunkCenter.Z + rng:NextNumber(-half, half)
		local position = Vector3.new(x, BASE_Y, z)
		if isInsideCenterExclusion(position.X, position.Z) then
			return
		end
		
		-- Place the chest
		local clone = prefab:Clone()
		local yOffset = getOffsetValue(clone)
		local targetCf = CFrame.new(position.X, BASE_Y + yOffset, position.Z)
		
		if clone:IsA("Model") then
			clone:PivotTo(targetCf)
		elseif clone:IsA("BasePart") then
			clone.CFrame = targetCf
		end
		
		-- Ensure chest has proper tag for LootService (tag should already be on prefab)
		ensureChestTag(clone)
		
		clone.Parent = parent
	end
end

function ChunkStreamingService:_placePrefab(prefab, position, parent)
	if not prefab then return end
	if isInsideCenterExclusion(position.X, position.Z) then
		return
	end
	
	local clone = prefab:Clone()

	-- Set CanQuery for world obstacles/resources
	if parent.Name == "Resources" or parent.Name == "Props" or parent.Name == "Structures" or parent.Name == "Objectives" then
		if clone:IsA("BasePart") then
			clone.CanQuery = true
		end
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanQuery = true
			end
		end
	end
	
	-- Get Y offset
	local yOffset = getOffsetValue(clone)
	
	local targetCf = CFrame.new(position.X, BASE_Y + yOffset, position.Z)
	if clone:IsA("Model") then
		clone:PivotTo(targetCf)
	elseif clone:IsA("BasePart") then
		clone.CFrame = targetCf
	end
	clone.Parent = parent
	return clone
end

function ChunkStreamingService:_unloadChunk(cx, cz)
	local key = chunkKey(cx, cz)
	local data = self._loadedChunks[key]
	if not data then return end
	
	-- Destroy chunk folder and all contents
	if data.folder and data.folder.Parent then
		data.folder:Destroy()
	end
	
	self._loadedChunks[key] = nil
	self._chunkFolders[key] = nil
end

function ChunkStreamingService:_getPlayerChunks()
	local playerChunks = {}
	
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local cx, cz = worldToChunk(hrp.Position.X, hrp.Position.Z)
			playerChunks[chunkKey(cx, cz)] = {cx = cx, cz = cz}
		end
	end
	
	return playerChunks
end

function ChunkStreamingService:_updateChunks()
	local playerChunks = self:_getPlayerChunks()
	local chunksToLoad = {}
	local now = os.clock()
	
	-- Determine which chunks need loading
	for _, pChunk in pairs(playerChunks) do
		for dx = -LOAD_RADIUS, LOAD_RADIUS do
			for dz = -LOAD_RADIUS, LOAD_RADIUS do
				local cx = pChunk.cx + dx
				local cz = pChunk.cz + dz
				local key = chunkKey(cx, cz)
				chunksToLoad[key] = {cx = cx, cz = cz}
			end
		end
	end
	
	-- Load needed chunks
	for key, chunk in pairs(chunksToLoad) do
		self:_loadChunk(chunk.cx, chunk.cz)
	end
	
	-- Check for chunks to unload
	for key, data in pairs(self._loadedChunks) do
		local shouldUnload = true
		
		for _, pChunk in pairs(playerChunks) do
			local dist = getChunkDistance(data.cx, data.cz, pChunk.cx, pChunk.cz)
			if dist <= UNLOAD_RADIUS then
				shouldUnload = false
				data.lastAccess = now
				break
			end
		end
		
		if shouldUnload and (now - data.lastAccess) > UNLOAD_DELAY then
			self:_unloadChunk(data.cx, data.cz)
		end
	end
end

function ChunkStreamingService:SetBiome(biomeName, force)
	if self._currentBiome == biomeName and not force then return end
	
	self._currentBiome = biomeName
	
	-- Clear all loaded chunks and reload
	for key, data in pairs(self._loadedChunks) do
		if data.folder and data.folder.Parent then
			data.folder:Destroy()
		end
	end
	self._loadedChunks = {}
	self._chunkFolders = {}
	self._loadingChunks = {}
	
	-- Force immediate reload around players
	self:_updateChunks()
end

function ChunkStreamingService:Init()
	if self._initialized then return end
	self._initialized = true
	
	self:_ensureWorldFolder()
	self:_initPrefabRoots()
	self:_initBiomes()
	self._currentBiome = BiomeService:GetCurrent()
	
	-- Subscribe to biome changes
	_G.Ecoshift = _G.Ecoshift or {}
	task.spawn(function()
		for _ = 1, 50 do
			if type(_G.Ecoshift.OnBiomeChangedAdd) == "function" then
				_G.Ecoshift.OnBiomeChangedAdd(function(newBiome)
					self:SetBiome(newBiome)
				end)
				break
			end
			task.wait(0.1)
		end
	end)
	
	-- Main update loop
	task.spawn(function()
		while true do
			self:_updateChunks()
			task.wait(UPDATE_INTERVAL)
		end
	end)
	
	-- Initial load for any players already in game
	task.defer(function()
		task.wait(0.5)
		self:_updateChunks()
	end)
	
	print("[ChunkStreamingService] Initialized - Dynamic chunk loading enabled")
end

return ChunkStreamingService
