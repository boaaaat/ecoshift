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
ChunkStreamingService._loadQueue = {}
ChunkStreamingService._loadQueueSet = {}
ChunkStreamingService._loadQueueHead = 1

-- Config (read from BiomeConfig or use defaults)
local CHUNK_SIZE = WorldGenConfig.chunk_size or 240
local LOAD_RADIUS = WorldGenConfig.stream_load_radius or 3 -- Load chunks within this radius (in chunks) around player
local UNLOAD_RADIUS = WorldGenConfig.stream_unload_radius or 5 -- Unload chunks beyond this radius
local UPDATE_INTERVAL = WorldGenConfig.stream_update_interval or 0.5 -- How often to check player positions
local UNLOAD_DELAY = WorldGenConfig.stream_unload_delay or 10 -- Seconds before unloading an unused chunk
local MAX_LOADS_PER_UPDATE = WorldGenConfig.stream_max_loads_per_update or 2
local STREAM_OPS_PER_YIELD = WorldGenConfig.stream_ops_per_yield or WorldGenConfig.ops_per_yield or 40
local STREAM_STEP_DELAY = WorldGenConfig.stream_step_delay or WorldGenConfig.step_delay or 0
local STREAM_BIND_OPS_PER_YIELD = WorldGenConfig.stream_bind_ops_per_yield or STREAM_OPS_PER_YIELD
local BASE_Y = WorldGenConfig.base_y or 0
local WORLD_RADIUS = WorldGenConfig.world_radius or 2200
local CENTER_EXCLUSION = WorldGenConfig.center_exclusion_radius or 260
local CENTER_EXCLUSION_SQ = CENTER_EXCLUSION * CENTER_EXCLUSION
local SPAWN_ENEMIES = WorldGenConfig.spawn_enemies ~= false
local REGION_PADDING = math.max(0, tonumber(WorldGenConfig.region_padding) or 0)
local STRUCTURE_PADDING = math.max(0, tonumber(WorldGenConfig.structure_padding) or 0)
local OBJECTIVE_PADDING = math.max(0, tonumber(WorldGenConfig.objective_padding) or 0)
local AVOID_REGIONS_FOR_STRUCTURES = WorldGenConfig.avoid_regions_for_structures ~= false
local TERRAIN_THICKNESS = (WorldGenConfig.TERRAIN and tonumber(WorldGenConfig.TERRAIN.Thickness)) or 24

local ASSET_OVERRIDES = WorldGenConfig.asset_overrides or {}
local MIN_SPACING_CONFIG = WorldGenConfig.stream_min_spacing or {}
local DENSITY_CONFIG = WorldGenConfig.spawn_density or {}
local REGION_NOISE_CONFIG = WorldGenConfig.region_noise or {}
local TERRAIN_DETAIL_CONFIG = WorldGenConfig.terrain_detail or {}

local REGION_SELECT_SCALE = tonumber(REGION_NOISE_CONFIG.scale) or 0.22
local REGION_COUNT_SCALE = tonumber(REGION_NOISE_CONFIG.count_scale) or 0.28
local REGION_WARP_SCALE = tonumber(REGION_NOISE_CONFIG.warp_scale) or 0.08
local REGION_WARP_STRENGTH = tonumber(REGION_NOISE_CONFIG.warp_strength) or 1.0

local TERRAIN_DETAIL_ENABLED = TERRAIN_DETAIL_CONFIG.enabled ~= false
local TERRAIN_DETAIL_CELL_SIZE = math.max(8, tonumber(TERRAIN_DETAIL_CONFIG.cell_size) or 24)
local TERRAIN_DETAIL_NOISE_SCALE = tonumber(TERRAIN_DETAIL_CONFIG.noise_scale) or 0.03
local TERRAIN_DETAIL_PATH_SCALE = tonumber(TERRAIN_DETAIL_CONFIG.path_scale) or 0.014
local TERRAIN_DETAIL_PATH_WIDTH = math.clamp(tonumber(TERRAIN_DETAIL_CONFIG.path_width) or 0.16, 0.02, 0.45)
local TERRAIN_DETAIL_OCTAVES = math.clamp(math.floor(tonumber(TERRAIN_DETAIL_CONFIG.octaves) or 2), 1, 4)
local TERRAIN_DETAIL_LACUNARITY = tonumber(TERRAIN_DETAIL_CONFIG.lacunarity) or 2
local TERRAIN_DETAIL_GAIN = tonumber(TERRAIN_DETAIL_CONFIG.gain) or 0.5

local DEFAULT_MIN_SPACING = {
	Resources = 9,
	Props = 7,
	Enemies = 12,
	Structures = 28,
	Objectives = 24,
	Chests = 10,
}

local DEFAULT_DENSITY = {
	resources = {
		scale = 0.03,
		threshold = 0.43,
		feather = 0.28,
		octaves = 2,
		lacunarity = 2,
		gain = 0.5,
		warp_scale = 0.012,
		warp_strength = 12,
		attempts_per_spawn = 6,
	},
	props = {
		scale = 0.036,
		threshold = 0.44,
		feather = 0.28,
		octaves = 2,
		lacunarity = 2,
		gain = 0.5,
		warp_scale = 0.014,
		warp_strength = 9,
		attempts_per_spawn = 7,
	},
	enemies = {
		scale = 0.024,
		threshold = 0.48,
		feather = 0.25,
		octaves = 2,
		lacunarity = 2,
		gain = 0.5,
		warp_scale = 0.01,
		warp_strength = 8,
		attempts_per_spawn = 8,
	},
}

local DEFAULT_GROUND_DETAIL = {
	Forest = {
		path = "Ground",
		patches = {
			{ material = "Ground", threshold = 0.58 },
			{ material = "Mud", threshold = 0.76 },
		},
	},
	Desert = {
		path = "Sandstone",
		patches = {
			{ material = "Sandstone", threshold = 0.62 },
			{ material = "Rock", threshold = 0.84 },
		},
	},
	Swamp = {
		path = "Mud",
		patches = {
			{ material = "Grass", threshold = 0.6 },
			{ material = "Mud", threshold = 0.72 },
		},
	},
	FrozenTundra = {
		path = "Ice",
		patches = {
			{ material = "Ice", threshold = 0.64 },
			{ material = "Rock", threshold = 0.86 },
		},
	},
	Volcanic = {
		path = "Basalt",
		patches = {
			{ material = "Rock", threshold = 0.58 },
			{ material = "Basalt", threshold = 0.78 },
		},
	},
	CrystalWastes = {
		path = "Rock",
		patches = {
			{ material = "Slate", threshold = 0.62 },
			{ material = "Rock", threshold = 0.82 },
		},
	},
}

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

local function materialFromName(name, fallback)
	if typeof(name) == "EnumItem" then
		return name
	end
	if type(name) ~= "string" then
		return fallback
	end
	local ok, material = pcall(function()
		return Enum.Material[name]
	end)
	if ok and material then
		return material
	end
	return fallback
end

local function getBaseMaterialForBiome(biomeName)
	local matName = WorldGenConfig.TERRAIN
		and WorldGenConfig.TERRAIN.MaterialByBiome
		and WorldGenConfig.TERRAIN.MaterialByBiome[biomeName]
	return materialFromName(matName, Enum.Material.Grass)
end

local function getGroundDetailConfigForBiome(biomeName)
	local overrideByBiome = TERRAIN_DETAIL_CONFIG.materials_by_biome
		or TERRAIN_DETAIL_CONFIG.materialsByBiome
		or (WorldGenConfig.TERRAIN and WorldGenConfig.TERRAIN.DetailMaterialsByBiome)
	local cfg = nil
	if type(overrideByBiome) == "table" then
		cfg = overrideByBiome[biomeName]
	end
	if type(cfg) ~= "table" then
		cfg = DEFAULT_GROUND_DETAIL[biomeName]
	end
	return cfg
end

local function sampleFractalNoise01(x, z, seed, scale, octaves, lacunarity, gain)
	local amplitude = 1
	local frequency = scale
	local total = 0
	local normalizer = 0
	for i = 1, octaves do
		total += amplitude * math.noise(x * frequency, z * frequency, seed + i * 17.173)
		normalizer += amplitude
		amplitude *= gain
		frequency *= lacunarity
	end
	if normalizer <= 0 then
		return 0.5
	end
	local n = total / normalizer
	return math.clamp((n + 1) * 0.5, 0, 1)
end

local function smoothstep01(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function resolveDensityConfig(kind, regionDef)
	local fallback = DEFAULT_DENSITY[kind] or {}
	local singular = kind:sub(-1) == "s" and kind:sub(1, -2) or kind
	local globalCfgRaw = DENSITY_CONFIG[kind] or DENSITY_CONFIG[singular]
	local globalCfg = type(globalCfgRaw) == "table" and globalCfgRaw or {}
	local regionCfgRaw = nil
	if regionDef then
		regionCfgRaw = regionDef[kind .. "_density"] or regionDef[singular .. "_density"]
	end
	local regionCfg = type(regionCfgRaw) == "table" and regionCfgRaw or {}
	local out = {}
	for k, v in pairs(fallback) do
		out[k] = v
	end
	for k, v in pairs(globalCfg) do
		out[k] = v
	end
	for k, v in pairs(regionCfg) do
		out[k] = v
	end
	return out
end

local function getCategorySpacing(categoryName, regionDef)
	local regionKey = nil
	if categoryName == "Resources" then
		regionKey = "resource_min_spacing"
	elseif categoryName == "Props" then
		regionKey = "prop_min_spacing"
	elseif categoryName == "Enemies" then
		regionKey = "enemy_min_spacing"
	elseif categoryName == "Structures" then
		regionKey = "structure_min_spacing"
	elseif categoryName == "Objectives" then
		regionKey = "objective_min_spacing"
	elseif categoryName == "Chests" then
		regionKey = "chest_min_spacing"
	end
	local regionValue = regionKey and regionDef and regionDef[regionKey] or nil
	if regionValue ~= nil then
		return math.max(0, tonumber(regionValue) or 0)
	end
	local cfgValue = MIN_SPACING_CONFIG[categoryName] or MIN_SPACING_CONFIG[categoryName:lower()]
	if cfgValue ~= nil then
		return math.max(0, tonumber(cfgValue) or 0)
	end
	return DEFAULT_MIN_SPACING[categoryName] or 0
end

local function getAssetOverrideForPrefab(prefabName)
	if type(prefabName) ~= "string" then
		return nil
	end
	local override = ASSET_OVERRIDES[prefabName]
	if type(override) == "table" then
		return override
	end
	return nil
end

local function getAssetYOffset(prefabName)
	local override = getAssetOverrideForPrefab(prefabName)
	if not override then
		return 0
	end
	return tonumber(override.yOffset or override.YOffset or override.offsetY or override.OffsetY) or 0
end

local function tryApplyScaleOverride(instance, prefabName)
	local override = getAssetOverrideForPrefab(prefabName)
	if not override then
		return
	end
	local scale = tonumber(override.scale or override.Scale)
	if not scale or scale <= 0 or math.abs(scale - 1) < 0.0001 then
		return
	end
	pcall(function()
		if instance:IsA("Model") then
			instance:ScaleTo(scale)
		elseif instance:IsA("BasePart") then
			instance.Size = instance.Size * scale
		end
	end)
end

local function rectIntersects(a, b)
	return a.minX <= b.maxX and a.maxX >= b.minX and a.minZ <= b.maxZ and a.maxZ >= b.minZ
end

local function makeRect(x, z, sizeX, sizeZ, padding)
	local halfX = math.max(0, sizeX * 0.5 + (padding or 0))
	local halfZ = math.max(0, sizeZ * 0.5 + (padding or 0))
	return {
		minX = x - halfX,
		maxX = x + halfX,
		minZ = z - halfZ,
		maxZ = z + halfZ,
	}
end

local function makeRectFromRegion(regionCenter, regionSize, padding)
	local size = regionSize
	if not size then
		size = Vector2.new(CHUNK_SIZE * 0.8, CHUNK_SIZE * 0.8)
	end
	return makeRect(regionCenter.X, regionCenter.Z, size.X or 0, size.Y or 0, padding)
end

local function expandRect(rect, amount)
	if not amount or amount <= 0 then
		return rect
	end
	return {
		minX = rect.minX - amount,
		maxX = rect.maxX + amount,
		minZ = rect.minZ - amount,
		maxZ = rect.maxZ + amount,
	}
end

local function defaultRegionSize(regionSize)
	if regionSize then
		return regionSize
	end
	return Vector2.new(CHUNK_SIZE * 0.8, CHUNK_SIZE * 0.8)
end

local function pointTooClose(points, x, z, minSpacing)
	if minSpacing <= 0 then
		return false
	end
	local minSq = minSpacing * minSpacing
	for i = 1, #points do
		local p = points[i]
		local dx = x - p.x
		local dz = z - p.z
		if (dx * dx + dz * dz) < minSq then
			return true
		end
	end
	return false
end

local function addPlacementPoint(points, x, z)
	points[#points + 1] = { x = x, z = z }
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
		local min = math.floor(tonumber(value.min or value.Min) or 0)
		local max = math.floor(tonumber(value.max or value.Max) or min)
		if max < min then
			min, max = max, min
		end
		return rng:NextInteger(min, max)
	elseif type(value) == "number" then
		return value
	end
	return 0
end

local function weightedIndexByValue(list, value01)
	if not list or #list == 0 then
		return nil
	end
	local total = 0
	for i = 1, #list do
		total += math.max(0, tonumber(list[i].Weight or list[i].weight) or 1)
	end
	if total <= 0 then
		return 1
	end
	local target = math.clamp(value01, 0, 1) * total
	for i = 1, #list do
		target -= math.max(0, tonumber(list[i].Weight or list[i].weight) or 1)
		if target <= 0 then
			return i
		end
	end
	return #list
end

local function pickRegionByNoise(regionDefs, cx, cz, slotIndex, seed)
	if not regionDefs or #regionDefs == 0 then
		return nil
	end
	if #regionDefs == 1 then
		return regionDefs[1]
	end
	local indexOffset = slotIndex * 37.11
	local wx = cx + indexOffset
	local wz = cz - indexOffset
	local warpX = math.noise(wx * REGION_WARP_SCALE, wz * REGION_WARP_SCALE, seed * 0.0017) * REGION_WARP_STRENGTH
	local warpZ = math.noise((wx + 67.3) * REGION_WARP_SCALE, (wz - 29.5) * REGION_WARP_SCALE, seed * 0.0023) * REGION_WARP_STRENGTH
	local value = (math.noise((wx + warpX) * REGION_SELECT_SCALE, (wz + warpZ) * REGION_SELECT_SCALE, seed * 0.0009) + 1) * 0.5
	local idx = weightedIndexByValue(regionDefs, value)
	return idx and regionDefs[idx] or regionDefs[1]
end

local function countFromNoise(value, cx, cz, seed, fallbackRng)
	if type(value) == "number" then
		return value
	end
	if type(value) ~= "table" then
		return randomInRange(fallbackRng, value)
	end
	local min = math.floor(tonumber(value.min or value.Min) or 0)
	local max = math.floor(tonumber(value.max or value.Max) or min)
	if max < min then
		min, max = max, min
	end
	if min == max then
		return min
	end
	local n = (math.noise(cx * REGION_COUNT_SCALE, cz * REGION_COUNT_SCALE, seed * 0.0029) + 1) * 0.5
	return min + math.floor(n * (max - min + 1 - 0.0001))
end

local function getPrefabFootprint(prefab)
	if not prefab then
		return 8, 8
	end
	if prefab:IsA("BasePart") then
		return math.max(4, prefab.Size.X), math.max(4, prefab.Size.Z)
	end
	if prefab:IsA("Model") then
		local ok, _, size = pcall(function()
			return prefab:GetBoundingBox()
		end)
		if ok and size then
			return math.max(4, size.X), math.max(4, size.Z)
		end
	end
	return 12, 12
end

local function getRegionTemp(regionDef)
	if type(regionDef) ~= "table" then return nil end
	if regionDef.Temp ~= nil then return regionDef.Temp end
	local env = regionDef.env or regionDef.Env
	if type(env) == "table" and env.Temp ~= nil then
		return env.Temp
	end
	return nil
end

local function computeRegionCenter(chunkCenter, regionSize, rng)
	regionSize = defaultRegionSize(regionSize)
	local halfChunk = CHUNK_SIZE * 0.5
	local halfX = (regionSize.X or 0) * 0.5
	local halfZ = (regionSize.Y or 0) * 0.5
	local minX = chunkCenter.X - halfChunk + halfX + REGION_PADDING
	local maxX = chunkCenter.X + halfChunk - halfX - REGION_PADDING
	local minZ = chunkCenter.Z - halfChunk + halfZ + REGION_PADDING
	local maxZ = chunkCenter.Z + halfChunk - halfZ - REGION_PADDING
	if minX > maxX then
		minX, maxX = chunkCenter.X, chunkCenter.X
	end
	if minZ > maxZ then
		minZ, maxZ = chunkCenter.Z, chunkCenter.Z
	end
	local x = rng:NextNumber(minX, maxX)
	local z = rng:NextNumber(minZ, maxZ)
	return Vector3.new(x, BASE_Y, z)
end

local function randomPointInRegion(regionCenter, regionSize, rng)
	local size = defaultRegionSize(regionSize)
	local halfX = (size.X or 0) * 0.5
	local halfZ = (size.Y or 0) * 0.5
	local x = regionCenter.X + rng:NextNumber(-halfX, halfX)
	local z = regionCenter.Z + rng:NextNumber(-halfZ, halfZ)
	return Vector3.new(x, BASE_Y, z)
end

local function getOffsetValue(obj)
	local offsetVal = obj:FindFirstChild("Offset", true)
	if offsetVal and offsetVal:IsA("NumberValue") then
		return offsetVal.Value
	end
	return 0
end

local function makeStep()
	local maxOps = tonumber(STREAM_OPS_PER_YIELD) or 40
	if maxOps < 1 then
		maxOps = 1
	end
	local ops = 0
	return function()
		ops += 1
		if ops >= maxOps then
			ops = 0
			if STREAM_STEP_DELAY > 0 then
				task.wait(STREAM_STEP_DELAY)
			else
				task.wait()
			end
		end
	end
end

function ChunkStreamingService:_newPlacementState()
	return {
		points = {
			Resources = {},
			Props = {},
			Enemies = {},
			Structures = {},
			Objectives = {},
			Chests = {},
		},
		rects = {
			Structures = {},
			Objectives = {},
			Chests = {},
		},
		regionRects = {},
	}
end

function ChunkStreamingService:_densityChance(cfg, x, z, seed)
	local scale = tonumber(cfg.scale) or 0
	if scale <= 0 then
		return 1
	end
	local warpScale = tonumber(cfg.warp_scale or cfg.warpScale) or (scale * 0.45)
	local warpStrength = tonumber(cfg.warp_strength or cfg.warpStrength) or 0
	if warpStrength ~= 0 then
		x += math.noise(x * warpScale, z * warpScale, seed * 0.0011 + 7.2) * warpStrength
		z += math.noise((x + 91.3) * warpScale, (z - 57.7) * warpScale, seed * 0.0017 + 13.9) * warpStrength
	end
	local octaves = math.clamp(math.floor(tonumber(cfg.octaves) or 2), 1, 4)
	local lacunarity = tonumber(cfg.lacunarity) or 2
	local gain = tonumber(cfg.gain) or 0.5
	local value = sampleFractalNoise01(x, z, seed * 0.0023 + 19.7, scale, octaves, lacunarity, gain)
	local threshold = tonumber(cfg.threshold) or 0.5
	local feather = math.max(0.01, tonumber(cfg.feather) or 0.25)
	local normalized = (value - (threshold - feather * 0.5)) / feather
	return smoothstep01(normalized)
end

function ChunkStreamingService:_isPointBlocked(placementState, categoryName, x, z, spacing)
	local points = placementState and placementState.points
	if not points then
		return false
	end
	local own = points[categoryName] or {}
	if pointTooClose(own, x, z, spacing) then
		return true
	end
	if categoryName == "Props" then
		if pointTooClose(points.Resources or {}, x, z, spacing * 0.65) then
			return true
		end
	elseif categoryName == "Structures" or categoryName == "Objectives" or categoryName == "Chests" then
		if pointTooClose(points.Structures or {}, x, z, spacing)
			or pointTooClose(points.Objectives or {}, x, z, spacing)
			or pointTooClose(points.Chests or {}, x, z, spacing) then
			return true
		end
	end
	return false
end

function ChunkStreamingService:_registerPoint(placementState, categoryName, x, z)
	local points = placementState and placementState.points
	if not points then
		return
	end
	if not points[categoryName] then
		points[categoryName] = {}
	end
	addPlacementPoint(points[categoryName], x, z)
end

function ChunkStreamingService:_isRectBlocked(placementState, rect, spacing, avoidRegions)
	local rects = placementState and placementState.rects
	if not rects then
		return false
	end
	local probe = expandRect(rect, spacing)
	if avoidRegions and AVOID_REGIONS_FOR_STRUCTURES then
		for i = 1, #placementState.regionRects do
			if rectIntersects(probe, placementState.regionRects[i]) then
				return true
			end
		end
	end
	local groups = { "Structures", "Objectives", "Chests" }
	for i = 1, #groups do
		local group = groups[i]
		local list = rects[group] or {}
		for j = 1, #list do
			if rectIntersects(probe, list[j]) then
				return true
			end
		end
	end
	return false
end

function ChunkStreamingService:_registerRect(placementState, categoryName, rect)
	local rects = placementState and placementState.rects
	if not rects then
		return
	end
	if not rects[categoryName] then
		rects[categoryName] = {}
	end
	rects[categoryName][#rects[categoryName] + 1] = rect
end

function ChunkStreamingService:_paintChunkGround(biomeName, chunkCenter, seed, step)
	if not TERRAIN_DETAIL_ENABLED then
		return
	end
	local detailCfg = getGroundDetailConfigForBiome(biomeName)
	if type(detailCfg) ~= "table" then
		return
	end
	local pathMaterial = materialFromName(
		detailCfg.path or detailCfg.pathMaterial or detailCfg.path_material,
		nil
	)
	local patchEntries = detailCfg.patches
	local patches = {}
	if type(patchEntries) == "table" then
		for i = 1, #patchEntries do
			local patch = patchEntries[i]
			if type(patch) == "table" then
				patches[#patches + 1] = {
					material = materialFromName(patch.material or patch.Material, nil),
					threshold = tonumber(patch.threshold or patch.Threshold) or 1,
				}
			end
		end
	end
	if not pathMaterial and #patches == 0 then
		return
	end
	table.sort(patches, function(a, b)
		return a.threshold < b.threshold
	end)

	local terrain = Workspace.Terrain
	local baseMaterial = getBaseMaterialForBiome(biomeName)
	local half = CHUNK_SIZE * 0.5
	local cell = TERRAIN_DETAIL_CELL_SIZE
	local y = BASE_Y - (TERRAIN_THICKNESS * 0.5)
	local startX = chunkCenter.X - half + cell * 0.5
	local startZ = chunkCenter.Z - half + cell * 0.5
	local endX = chunkCenter.X + half - cell * 0.5
	local endZ = chunkCenter.Z + half - cell * 0.5

	for x = startX, endX, cell do
		for z = startZ, endZ, cell do
			if not isInsideCenterExclusion(x, z) and ((x * x) + (z * z)) <= (WORLD_RADIUS * WORLD_RADIUS) then
				local material = baseMaterial
				local pathNoise = math.abs(math.noise(x * TERRAIN_DETAIL_PATH_SCALE, z * TERRAIN_DETAIL_PATH_SCALE, seed * 0.0007 + 41.1))
				if pathMaterial and pathNoise < TERRAIN_DETAIL_PATH_WIDTH then
					material = pathMaterial
				elseif #patches > 0 then
					local n = sampleFractalNoise01(
						x,
						z,
						seed * 0.0013 + 73.5,
						TERRAIN_DETAIL_NOISE_SCALE,
						TERRAIN_DETAIL_OCTAVES,
						TERRAIN_DETAIL_LACUNARITY,
						TERRAIN_DETAIL_GAIN
					)
					for i = 1, #patches do
						if n >= patches[i].threshold and patches[i].material then
							material = patches[i].material
						end
					end
				end
				terrain:FillBlock(CFrame.new(x, y, z), Vector3.new(cell, TERRAIN_THICKNESS, cell), material)
			end
			if step then
				step()
			end
		end
	end
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
			tryApplyScaleOverride(clone, prefab.Name)
			local yOffset = getOffsetValue(clone) + getAssetYOffset(prefab.Name)
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

function ChunkStreamingService:_enqueueChunkLoad(cx, cz)
	local key = chunkKey(cx, cz)
	if self._loadedChunks[key] or self._loadingChunks[key] or self._loadQueueSet[key] then
		return
	end
	self._loadQueue[#self._loadQueue + 1] = { cx = cx, cz = cz, key = key }
	self._loadQueueSet[key] = true
end

function ChunkStreamingService:_processLoadQueue(desiredSet)
	local maxLoads = tonumber(MAX_LOADS_PER_UPDATE) or 1
	if maxLoads <= 0 then
		maxLoads = 1
	end
	local loads = 0
	while loads < maxLoads do
		local head = self._loadQueueHead
		if head > #self._loadQueue then
			break
		end
		local entry = self._loadQueue[head]
		self._loadQueue[head] = nil
		self._loadQueueHead = head + 1
		if entry then
			self._loadQueueSet[entry.key] = nil
			if not desiredSet or desiredSet[entry.key] then
				self:_loadChunk(entry.cx, entry.cz)
				loads += 1
			end
		end
	end

	if self._loadQueueHead > 64 and self._loadQueueHead > (#self._loadQueue * 0.5) then
		local compacted = {}
		for i = self._loadQueueHead, #self._loadQueue do
			compacted[#compacted + 1] = self._loadQueue[i]
		end
		self._loadQueue = compacted
		self._loadQueueHead = 1
	end
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
		local step = makeStep()
		
		-- Generate chunk content
		local regions = self:_generateChunkContent(cx, cz, chunkCenter, chunkFolder, step)
		
		self._loadedChunks[key] = {
			folder = chunkFolder,
			lastAccess = os.clock(),
			cx = cx,
			cz = cz,
			regions = regions or {},
		}
		self._loadingChunks[key] = nil
		
		-- Bind resource nodes in this chunk
		task.defer(function()
			ResourceNodeService:BindFolder(chunkFolder)
			
			-- Bind chests and monsters for loot system
			local loot = getLootService()
			if loot then
				-- Scan chunk folder for tagged chests and monsters
				local descendants = chunkFolder:GetDescendants()
				for i = 1, #descendants do
					local descendant = descendants[i]
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
					if i % STREAM_BIND_OPS_PER_YIELD == 0 then
						task.wait()
					end
				end
			end
		end)
	end)
end

function ChunkStreamingService:_generateChunkContent(cx, cz, chunkCenter, chunkFolder, step)
	local biome = self:_findBiome(self._currentBiome)
	if not biome then 
		biome = self._biomes[1]
	end
	if not biome then return end
	step = step or makeStep()
	
	local biomeName = biome.name
	local regions = {}
	
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
	local placementState = self:_newPlacementState()

	self:_paintChunkGround(biomeName, chunkCenter, chunkSeed, step)
	
	-- Generate regions in this chunk
	local regionCount = countFromNoise(biome.region_count or biome.regionCount, cx, cz, seed, rng) or 1
	if regionCount < 1 then regionCount = 1 end
	
	for regionIndex = 1, regionCount do
		local regionDef = nil
		if biome.regions and #biome.regions > 0 then
			regionDef = pickRegionByNoise(biome.regions, cx, cz, regionIndex, seed)
		end
		if regionDef then
			local regionSize = defaultRegionSize(regionDef.size)
			local regionCenter = computeRegionCenter(chunkCenter, regionSize, rng)
			local regionTemp = getRegionTemp(regionDef)
			regions[#regions + 1] = {
				Center = regionCenter,
				Size = regionSize,
				Temp = regionTemp,
			}
			placementState.regionRects[#placementState.regionRects + 1] = makeRectFromRegion(regionCenter, regionSize, REGION_PADDING)
			local regionDistanceT = distanceT(regionCenter.X, regionCenter.Z)
			self:_scatterInChunk(
				biomeName,
				regionCenter,
				regionSize,
				regionDef,
				subfolders,
				rng,
				regionDistanceT,
				step,
				placementState,
				seed
			)
		end
		step()
	end
	
	-- Structures (probability per chunk)
	local structureChance = tonumber(biome.structure_count or biome.structureCount) or 0
	local structurePrefabs = self:_resolvePrefabsWeighted("StructurePrefabs", biomeName, biome.structures)
	local structureFactor = distanceFactorForList(structurePrefabs, distance_t)
	if rng:NextNumber() <= math.clamp(structureChance * structureFactor, 0, 1) then
		self:_placeStructure(
			biomeName,
			chunkCenter,
			biome.structures,
			subfolders.Structures,
			rng,
			structurePrefabs,
			distance_t,
			biome,
			step,
			placementState,
			"Structures"
		)
	end
	
	-- Chests (probability per chunk)
	local chestChance = tonumber(biome.chest_count or biome.chestCount) or 0
	if biome.chests then
		local chestPrefabs = self:_resolveChestEntries(biomeName, biome.chests)
		local chestFactor = distanceFactorForList(chestPrefabs, distance_t)
		if rng:NextNumber() <= math.clamp(chestChance * chestFactor, 0, 1) then
			self:_placeChest(
				biomeName,
				chunkCenter,
				biome.chests,
				subfolders.Structures,
				rng,
				chestPrefabs,
				distance_t,
				step,
				placementState
			)
		end
	end
	
	-- Objectives (probability per chunk)
	local objectiveChance = tonumber(biome.objective_count or biome.objectiveCount) or 0
	local objectivePrefabs = self:_resolvePrefabsWeighted("ObjectivePrefabs", biomeName, biome.objectives)
	local objectiveFactor = distanceFactorForList(objectivePrefabs, distance_t)
	if rng:NextNumber() <= math.clamp(objectiveChance * objectiveFactor, 0, 1) then
		self:_placeStructure(
			biomeName,
			chunkCenter,
			biome.objectives,
			subfolders.Objectives,
			rng,
			objectivePrefabs,
			distance_t,
			biome,
			step,
			placementState,
			"Objectives"
		)
	end

	return regions
end

function ChunkStreamingService:_scatterCategory(categoryName, regionCenter, regionSize, regionDef, parent, prefabs, count, rng, distance_t, step, placementState, seed)
	if count <= 0 or not prefabs or #prefabs == 0 then
		return
	end
	local densityKind = categoryName:lower()
	local densityCfg = resolveDensityConfig(densityKind, regionDef)
	local attemptsPerSpawn = math.max(2, tonumber(densityCfg.attempts_per_spawn or densityCfg.attemptsPerSpawn) or 6)
	local maxAttempts = math.max(count * attemptsPerSpawn, count + 6)
	local minSpacing = getCategorySpacing(categoryName, regionDef)
	local placed = 0
	local attempts = 0
	while placed < count and attempts < maxAttempts do
		attempts += 1
		local position = randomPointInRegion(regionCenter, regionSize, rng)
		local chance = self:_densityChance(densityCfg, position.X, position.Z, seed)
		if chance > 0 and rng:NextNumber() <= chance and not self:_isPointBlocked(placementState, categoryName, position.X, position.Z, minSpacing) then
			local prefab = self:_chooseWeighted(prefabs, rng, distance_t)
			if prefab then
				local clone = self:_placePrefab(prefab, position, parent, step)
				if clone then
					self:_registerPoint(placementState, categoryName, position.X, position.Z)
					placed += 1
				end
			end
		end
		step()
	end
end

function ChunkStreamingService:_scatterInChunk(biomeName, regionCenter, regionSize, regionDef, subfolders, rng, distance_t, step, placementState, seed)
	step = step or makeStep()
	
	-- Resources
	local resourcePrefabs = self:_resolvePrefabsWeighted("ResourcePrefabs", biomeName, regionDef.resources)
	local resourceCount = randomInRange(rng, regionDef.resource_count or regionDef.resourceCount) or 5
	local resourceFactor = distanceFactorForList(resourcePrefabs, distance_t)
	resourceCount = math.max(0, math.floor(resourceCount * resourceFactor + 0.5))
	self:_scatterCategory("Resources", regionCenter, regionSize, regionDef, subfolders.Resources, resourcePrefabs, resourceCount, rng, distance_t, step, placementState, seed)
	
	-- Props
	local propPrefabs = self:_resolvePrefabsWeighted("PropPrefabs", biomeName, regionDef.props)
	local propCount = randomInRange(rng, regionDef.prop_count or regionDef.propCount) or 3
	local propFactor = distanceFactorForList(propPrefabs, distance_t)
	propCount = math.max(0, math.floor(propCount * propFactor + 0.5))
	self:_scatterCategory("Props", regionCenter, regionSize, regionDef, subfolders.Props, propPrefabs, propCount, rng, distance_t, step, placementState, seed)
	
	if SPAWN_ENEMIES then
		-- Enemies
		local enemyPrefabs = self:_resolvePrefabsWeighted("EnemyPrefabs", biomeName, regionDef.enemies)
		local enemyCount = randomInRange(rng, regionDef.enemy_count or regionDef.enemyCount) or 0
		local enemyFactor = distanceFactorForList(enemyPrefabs, distance_t)
		enemyCount = math.max(0, math.floor(enemyCount * enemyFactor + 0.5))
		self:_scatterCategory("Enemies", regionCenter, regionSize, regionDef, subfolders.Enemies, enemyPrefabs, enemyCount, rng, distance_t, step, placementState, seed)
	end
end

function ChunkStreamingService:_placeStructure(biomeName, chunkCenter, names, parent, rng, prefabs, distance_t, biome, step, placementState, categoryName)
	if (not names or (type(names) == "table" and #names == 0)) and not prefabs then return end
	
	local prefabs = prefabs or self:_resolvePrefabsWeighted("StructurePrefabs", biomeName, names)
	if #prefabs == 0 then
		-- Try ObjectivePrefabs for objectives
		prefabs = self:_resolvePrefabsWeighted("ObjectivePrefabs", biomeName, names)
	end
	if #prefabs == 0 then return end

	categoryName = categoryName or (parent and parent.Name) or "Structures"
	local extraPadding = categoryName == "Objectives" and OBJECTIVE_PADDING or STRUCTURE_PADDING
	local minSpacing = getCategorySpacing(categoryName, nil)
	local tries = 10
	for _ = 1, tries do
		local prefab = self:_chooseWeighted(prefabs, rng, distance_t)
		if not prefab then
			return
		end
		local half = CHUNK_SIZE * 0.3
		local x = chunkCenter.X + rng:NextNumber(-half, half)
		local z = chunkCenter.Z + rng:NextNumber(-half, half)
		local footprintX, footprintZ = getPrefabFootprint(prefab)
		local rect = makeRect(x, z, footprintX, footprintZ, extraPadding)
		local avoidRegions = categoryName == "Structures" or categoryName == "Objectives"
		if not self:_isRectBlocked(placementState, rect, minSpacing, avoidRegions) then
			local position = Vector3.new(x, BASE_Y, z)
			local clone = self:_placePrefab(prefab, position, parent, step)
			if clone then
				self:_registerRect(placementState, categoryName, rect)
				self:_registerPoint(placementState, categoryName, x, z)
				if categoryName == "Structures" and parent and parent.Name == "Structures" then
					self:_spawnStructureChests(clone, biomeName, prefab.Name, rng, biome)
				end
				return clone
			end
		end
		if step then
			step()
		end
	end
end

function ChunkStreamingService:_placeChest(biomeName, chunkCenter, chestNames, parent, rng, prefabs, distance_t, step, placementState)
	if (not chestNames or (type(chestNames) == "table" and #chestNames == 0)) and not prefabs then return end
	
	-- Try chest folder first, then structure/prop prefabs
	local prefabs = prefabs or self:_resolveChestEntries(biomeName, chestNames)
	if #prefabs == 0 then return end

	local minSpacing = getCategorySpacing("Chests", nil)
	for _ = 1, 10 do
		local prefab = self:_chooseWeighted(prefabs, rng, distance_t)
		if not prefab then
			return
		end
		local half = CHUNK_SIZE * 0.35
		local x = chunkCenter.X + rng:NextNumber(-half, half)
		local z = chunkCenter.Z + rng:NextNumber(-half, half)
		local position = Vector3.new(x, BASE_Y, z)
		if isInsideCenterExclusion(position.X, position.Z) then
			if step then
				step()
			end
		else
			local footprintX, footprintZ = getPrefabFootprint(prefab)
			local rect = makeRect(x, z, footprintX, footprintZ, 0)
			if not self:_isRectBlocked(placementState, rect, minSpacing, false) then
				-- Place the chest
				local clone = prefab:Clone()
				tryApplyScaleOverride(clone, prefab.Name)
				local yOffset = getOffsetValue(clone) + getAssetYOffset(prefab.Name)
				local targetCf = CFrame.new(position.X, BASE_Y + yOffset, position.Z)

				if clone:IsA("Model") then
					clone:PivotTo(targetCf)
				elseif clone:IsA("BasePart") then
					clone.CFrame = targetCf
				end

				-- Ensure chest has proper tag for LootService (tag should already be on prefab)
				ensureChestTag(clone)

				clone.Parent = parent
				self:_registerRect(placementState, "Chests", rect)
				self:_registerPoint(placementState, "Chests", x, z)
				return clone
			end
			if step then
				step()
			end
		end
	end
end

function ChunkStreamingService:_placePrefab(prefab, position, parent, step)
	if not prefab then return end
	if isInsideCenterExclusion(position.X, position.Z) then
		return
	end
	
	local clone = prefab:Clone()
	tryApplyScaleOverride(clone, prefab.Name)

	-- Set CanQuery for world obstacles/resources
	if parent.Name == "Resources" or parent.Name == "Props" or parent.Name == "Structures" or parent.Name == "Objectives" then
		if clone:IsA("BasePart") then
			clone.CanQuery = true
		end
		local descendants = clone:GetDescendants()
		for i = 1, #descendants do
			local d = descendants[i]
			if d:IsA("BasePart") then
				d.CanQuery = true
			end
			if step and (i % 32 == 0) then
				step()
			end
		end
	end
	
	-- Get Y offset
	local yOffset = getOffsetValue(clone) + getAssetYOffset(prefab.Name)
	
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
		self:_enqueueChunkLoad(chunk.cx, chunk.cz)
	end
	self:_processLoadQueue(chunksToLoad)
	
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
	self._loadQueue = {}
	self._loadQueueSet = {}
	self._loadQueueHead = 1
	
	-- Force immediate reload around players
	self:_updateChunks()
end

function ChunkStreamingService:GetRegionTempAtPosition(position)
	if not position then return nil end
	local cx, cz = worldToChunk(position.X, position.Z)
	local key = chunkKey(cx, cz)
	local data = self._loadedChunks[key]
	if not data or not data.regions then return nil end
	for _, region in ipairs(data.regions) do
		local size = region.Size
		local center = region.Center
		if size and center then
			local halfX = (size.X or 0) * 0.5
			local halfZ = (size.Y or 0) * 0.5
			if position.X >= (center.X - halfX) and position.X <= (center.X + halfX)
				and position.Z >= (center.Z - halfZ) and position.Z <= (center.Z + halfZ) then
				if region.Temp ~= nil then
					return region.Temp
				end
			end
		end
	end
	return nil
end

function ChunkStreamingService:Init()
	if self._initialized then return end
	self._initialized = true
	self._loadQueue = {}
	self._loadQueueSet = {}
	self._loadQueueHead = 1
	
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
