local Config = {}

Config.seed = Random.new():NextInteger(10000, 99999)
Config.world_radius = 1500
Config.center_exclusion_radius = 260
Config.base_y = 0
Config.chunk_size = 240
Config.max_chunks = nil -- set to a number to cap how many chunks generate
Config.biome_noise_scale = 0.0016
Config.time_scale_seconds = 900
Config.ops_per_yield = 100
-- OPTIMIZED: Reduced step delay
Config.step_delay = .1
Config.region_padding = 8
Config.structure_padding = 6
Config.objective_padding = 6
Config.avoid_regions_for_structures = true
Config.use_entity_config_enemies = true
Config.spawn_enemies = false -- set true to place enemies during worldgen (otherwise use SpawnOrchestrator)
Config.spawn_folder_name = "GeneratedWorld"

-- ASSET SIZE & OFFSET OVERRIDES: Applied when spawning prefabs
-- scale = multiplier (1 = original size), yOffset = vertical position above base_y
Config.asset_overrides = {
	-- FOREST RESOURCES
	Tree = { scale = 1.0, yOffset = 4 },
	Mushroom = { scale = 1.0, yOffset = 0.5 },
	Reed = { scale = 1.0, yOffset = 1 },
	Stone = { scale = 1.0, yOffset = 2 },
	Mud = { scale = 1.0, yOffset = 0.5 },
	-- FOREST PROPS
	Bush = { scale = 1.0, yOffset = 1 },
	FallenLog = { scale = 1.0, yOffset = 1 },
	RockSmall = { scale = 1.0, yOffset = 1 },
	Stump = { scale = 1.0, yOffset = 1 },

	-- DESERT RESOURCES
	Cactus = { scale = 1.2, yOffset = 3 },
	Coal = { scale = 1.0, yOffset = 1.5 },
	Sandstone = { scale = 1.5, yOffset = 4 },
	DriedBone = { scale = 0.8, yOffset = 1 },
	-- DESERT PROPS
	Skull = { scale = 0.6, yOffset = 0.5 },
	DeadShrub = { scale = 1.0, yOffset = 1 },
	Sand = { scale = 1.0, yOffset = 0 },
	SandDune = { scale = 2.0, yOffset = 0 },
	-- DESERT STRUCTURES
	AncientRuins = { scale = 1.0, yOffset = 4 },
	DesertOutpost = { scale = 1.0, yOffset = 4 },

	-- SWAMP RESOURCES
	MangroveTree = { scale = 1.0, yOffset = 3.5 },
	CypressTree = { scale = 1.0, yOffset = 3.5 },
	WillowTreeSwamp = { scale = 1.0, yOffset = 3.2 },
	BogReed = { scale = 1.0, yOffset = 1.0 },
	GlowcapCluster = { scale = 1.0, yOffset = 0.6 },
	PeatMound = { scale = 1.0, yOffset = 0.6 },
	MireStone = { scale = 1.0, yOffset = 1.4 },
	-- SWAMP PROPS
	LilyPadCluster = { scale = 1.0, yOffset = 0.2 },
	CattailPatch = { scale = 1.0, yOffset = 1.0 },
	DriftwoodLog = { scale = 1.0, yOffset = 0.9 },
	MossyStump = { scale = 1.0, yOffset = 0.9 },
	RootTangle = { scale = 1.0, yOffset = 0.9 },
	BogFern = { scale = 1.0, yOffset = 0.8 },
	-- SWAMP STRUCTURES
	SunkenShack = { scale = 1.0, yOffset = 2.8 },
	WreckedSkiff = { scale = 1.0, yOffset = 1.0 },
}

-- STREAMING CONFIG: Dynamic chunk loading around players
Config.stream_load_radius = 3 -- Load chunks within this radius (in chunks)
Config.stream_unload_radius = 5 -- Unload chunks beyond this radius
Config.stream_update_interval = 0.5 -- How often to check player positions
Config.stream_unload_delay = 10 -- Seconds before unloading unused chunk

-- STREAMING DENSITY/SPACING: Used by ChunkStreamingService
Config.stream_min_spacing = {
	Resources = 10,
	Props = 7,
	Enemies = 12,
	Structures = 28,
	Objectives = 24,
	Chests = 10,
}

-- DENSITY MASKS: 2D noise masks to avoid uniform random scatter.
-- Optional per-region overrides:
-- resource_density / prop_density / enemy_density
Config.spawn_density = {
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

-- REGION NOISE: Makes region type selection coherent across neighboring chunks.
Config.region_noise = {
	scale = 0.22,
	count_scale = 0.28,
	warp_scale = 0.08,
	warp_strength = 1.0,
}

-- FLAT TERRAIN DETAIL PASS: paints chunk-local material variation without changing Y height.
Config.terrain_detail = {
	enabled = true,
	cell_size = 24,
	noise_scale = 0.03,
	path_scale = 0.014,
	path_width = 0.16,
	octaves = 2,
	lacunarity = 2,
	gain = 0.5,
	materials_by_biome = {
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
	},
}

-- STRUCTURE CHESTS: Spawn chests inside structures at ChestSpawn markers
-- Prefabs: Chest models are resolved from ServerStorage/Chests by name
-- Spawn points: Any BasePart or Attachment named "ChestSpawn" or "ChestSpawn_*"
-- count: number or {min, max} per structure instance (clamped to spawn points)
-- tier_weights: tier weights can include DistanceWeight to bias rarer chests farther out
-- loot_table: optional LootTable name to use for all chests in the structure
-- chests: prefab list (strings or weighted entries), supports DistanceWeight like biome generation
Config.structure_chests = {
	Default = {
		count = { min = 0, max = 1 },
		spawn_points = { "ChestSpawn" },
		tier_weights = {
			Common = { Weight = 1.0, DistanceWeight = 0.6 },
			Rare = { Weight = 0.35, DistanceWeight = 1.2 },
			Legendary = { Weight = 0.12, DistanceWeight = 1.6 },
			Celestial = { Weight = 0.03, DistanceWeight = 2.0 },
		},
		chests = {
			"Common_Chest",
			"Rare_Chest",
			"Legendary_Chest",
		},
	},
	-- Example:
	CabinRuin = {
		count = { min = 1, max = 1 },
		tier_weights = {
			Common = { Weight = 1.0, DistanceWeight = 0.6 },
			Rare = { Weight = 0.35, DistanceWeight = 1.2 },
			Legendary = { Weight = 0.12, DistanceWeight = 1.6 },
			Celestial = { Weight = 0.03, DistanceWeight = 2.0 },
		},
		chests = {
			"Common_Chest",
			"Rare_Chest",
			"Legendary_Chest",
			"Celestial_Chest",
		},
	},
}

-- BIOME SHIFT CONFIG: How often biomes change
Config.biome_default = "Forest"
Config.biome_shift = {
	MinSeconds = 300, -- A normal shift occurs every five minutes.
	MaxSeconds = 300,
	TimeScaleSeconds = 900, -- Time scaling factor for weight calculations
	MinimumWeight = 0.4, -- Preserve access to early materials during long runs.
}

-- BIOME METADATA: Environment effects, resource tags, enemy tables
-- Used by BiomeService for selection and SpawnService for enemy waves
Config.biome_metadata = {
	Forest = {
		DisplayName = "Verdant Reach", MinElapsed = 0,
		env = { Temp = 0, Toxin = 0, Wet = 0 },
		resourceTags = { "Wood", "Plants", "Stone" },
		enemyTables = { "ForestCommon" },
	},
	Desert = {
		env = { Temp = 1, Toxin = 0, Wet = -1 },
		resourceTags = { "Stone", "Ore", "Cactus" },
		DisplayName = "Sunscar Dunes", MinElapsed = 5 * 60,
		enemyTables = { "DesertCommon" },
	},
	Swamp = {
		env = { Temp = 0, Toxin = 1, Wet = 2 },
		resourceTags = { "Herb", "Reed", "Mud" },
		DisplayName = "Mirefen", MinElapsed = 10 * 60,
		enemyTables = { "SwampCommon" },
	},
	FrozenTundra = {
		env = { Temp = -2, Toxin = 0, Wet = 0 },
		resourceTags = { "Ice", "Stone", "Fur" },
		DisplayName = "Frostfall", MinElapsed = 20 * 60,
		enemyTables = { "TundraCommon" },
	},
	Volcanic = {
		env = { Temp = 2, Toxin = 0, Wet = -1 },
		resourceTags = { "Ore", "Sulfur", "Obsidian" },
		DisplayName = "Cinder Rift", MinElapsed = 30 * 60,
		enemyTables = { "VolcanicCommon" },
	},
	CrystalWastes = {
		env = { Temp = 0, Toxin = 0, Wet = 0 },
		resourceTags = { "Crystal", "Void", "Alloy" },
		DisplayName = "Prism Barrens", MinElapsed = 40 * 60,
		enemyTables = { "CrystalCommon" },
	},
	AuroraVale = {
		DisplayName = "Aurora Vale", MinElapsed = 45 * 60,
		WeatherCycle = { "DawnSurge", "PolarNight" }, WeatherCycleSeconds = 60,
		env = { Temp = 0, Toxin = 0, Wet = 0.1 },
		resourceTags = { "Aurora", "Fiber", "Quartz" }, enemyTables = { "AuroraCommon" },
	},
	StarfallCrater = {
		DisplayName = "Starfall Crater", MinElapsed = 55 * 60,
		env = { Temp = 0.6, Toxin = 0.1, Wet = 0 },
		resourceTags = { "Meteor", "Metal", "Glass" }, enemyTables = { "StarfallCommon" },
	},
}

-- BIOME WORLD GEN CONFIG: Regions, resources, props, structures per biome
-- Optional: DistanceWeight can be set on any resource/prop/enemy/structure/objective/chest entry.
-- DistanceWeight = 1 (no change), <1 less frequent toward edge, >1 more frequent toward edge.
-- You can also use { Min = 0.8, Max = 1.4 } to control center/edge weights.
Config.biomes = {
	Forest = {
		weight = 1.0,
		timeScaledWeight = -0.1,
		region_count = { min = 1, max = 2 },
		regions = {
			{
				name = "ForestClearing",
				-- Optional: Temp or env = { Temp = number } for region-specific temperature
				size = Vector2.new(100, 100),
				resources = {
					Tree = { Weight = 1.2, DistanceWeight = { Min = 1.1, Max = 0.9 } },
					Mushroom = { Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 1.1 } },
					Reed = { Weight = 0.9, DistanceWeight = { Min = 0.9, Max = 1.3 } },
					SapResin = { Weight = 0.5 },
				},
				resource_count = { min = 16, max = 28 },
				props = {
					{ Name = "Bush", Weight = 1.2, DistanceWeight = { Min = 1.0, Max = 1.1 } },
					{ Name = "FallenLog", Weight = 0.7, DistanceWeight = { Min = 0.9, Max = 1.2 } },
				},
				prop_count = { min = 10, max = 18 },
				enemies = {
					{ Name = "Wolf", Weight = 1.0, DistanceWeight = { Min = 0.9, Max = 1.2 } },
				},
				enemy_count = { min = 0, max = 2 },
			},
			{
				name = "ThickGrove",
				size = Vector2.new(80, 80),
				resources = {
					Mud = { Weight = 1.1, DistanceWeight = { Min = 1.1, Max = 0.9 } },
					SpringWater = { Weight = 0.6 },
					Stone = { Weight = 0.7, DistanceWeight = { Min = 0.9, Max = 1.2 } },
					Mushroom = { Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 1.2 } },
				},
				resource_count = { min = 22, max = 36 },
				props = {
					{ Name = "RockSmall", Weight = 0.9, DistanceWeight = { Min = 0.9, Max = 1.2 } },
					{ Name = "Stump", Weight = 0.8, DistanceWeight = { Min = 1.1, Max = 0.9 } },
				},
				prop_count = { min = 8, max = 14 },
				enemies = {
					{ Name = "Wolf", Weight = 1.0, DistanceWeight = { Min = 0.9, Max = 1.2 } },
				},
				enemy_count = { min = 0, max = 2 },
			},
			{
				name = "FlowerHollow",
				size = Vector2.new(90, 90),
				resources = {
					Tree = { Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 0.9 } },
					Mushroom = { Weight = 1.1, DistanceWeight = { Min = 1.0, Max = 1.1 } },
					Reed = { Weight = 0.8, DistanceWeight = { Min = 0.9, Max = 1.2 } },
					MossBloom = { Weight = 0.8 },
				},
				resource_count = { min = 18, max = 30 },
				props = {
					{ Name = "CoolFlower", Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 1.1 } },
					{ Name = "FireFlowers", Weight = 0.6, DistanceWeight = { Min = 0.8, Max = 1.4 } },
					{ Name = "MossFlowers", Weight = 0.9, DistanceWeight = { Min = 1.1, Max = 1.0 } },
					{ Name = "PeachFlowers", Weight = 0.8, DistanceWeight = { Min = 1.0, Max = 1.2 } },
					{ Name = "PinkFlowers", Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 1.1 } },
					{ Name = "WhiteFlowerBush", Weight = 0.7, DistanceWeight = { Min = 0.9, Max = 1.3 } },
				},
				prop_count = { min = 16, max = 26 },
				enemies = {
					{ Name = "Wolf", Weight = 0.9, DistanceWeight = { Min = 0.9, Max = 1.2 } },
				},
				enemy_count = { min = 0, max = 1 },
			},
			{
				name = "OldGrowthRidge",
				size = Vector2.new(110, 90),
				resources = {
					BigTree = { Weight = 0.9, DistanceWeight = { Min = 0.9, Max = 1.3 } },
					SapResin = { Weight = 0.8 },
					Tree = { Weight = 1.1, DistanceWeight = { Min = 1.1, Max = 0.9 } },
					Stone = { Weight = 0.8, DistanceWeight = { Min = 0.9, Max = 1.2 } },
				},
				resource_count = { min = 16, max = 26 },
				props = {
					{ Name = "FallenLog", Weight = 0.9, DistanceWeight = { Min = 1.0, Max = 1.2 } },
					{ Name = "Stump", Weight = 0.7, DistanceWeight = { Min = 1.1, Max = 0.9 } },
					{ Name = "RockSmall", Weight = 0.8, DistanceWeight = { Min = 0.9, Max = 1.2 } },
				},
				prop_count = { min = 8, max = 14 },
				enemies = {
					{ Name = "Wolf", Weight = 1.0, DistanceWeight = { Min = 0.9, Max = 1.2 } },
				},
				enemy_count = { min = 0, max = 2 },
			},
			{
				name = "MistyGlen",
				size = Vector2.new(85, 100),
				resources = {
					Mud = { Weight = 1.0, DistanceWeight = { Min = 1.2, Max = 0.9 } },
					Mushroom = { Weight = 1.1, DistanceWeight = { Min = 1.0, Max = 1.2 } },
					Reed = { Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 1.3 } },
					SmallTree = { Weight = 0.8, DistanceWeight = { Min = 1.0, Max = 0.9 } },
					SpringWater = { Weight = 0.5 },
					MossBloom = { Weight = 0.5 },
				},
				resource_count = { min = 20, max = 34 },
				props = {
					{ Name = "Bush", Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 1.1 } },
					{ Name = "MossFlowers", Weight = 0.9, DistanceWeight = { Min = 1.1, Max = 1.0 } },
					{ Name = "QuantumFlowers", Weight = 0.5, DistanceWeight = { Min = 0.8, Max = 1.6 } },
				},
				prop_count = { min = 12, max = 20 },
				enemies = {
					{ Name = "Wolf", Weight = 0.9, DistanceWeight = { Min = 0.9, Max = 1.2 } },
				},
				enemy_count = { min = 0, max = 1 },
			},
		},
		structures = {
			{ Name = "CabinRuin", Weight = 0.7, DistanceWeight = { Min = 0.9, Max = 1.3 } },
			{ Name = "WatchTower", Weight = 0.5, DistanceWeight = { Min = 1.0, Max = 1.4 } },
		},
		structure_count = 0.5,
		objectives = {},
		objective_count = 0.025,
		chests = {
			{ Name = "Common_Chest", Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 0.9 } },
			{ Name = "Rare_Chest", Weight = 0.4, DistanceWeight = { Min = 0.9, Max = 1.3 } },
		},
		chest_count = 0.08,
	},
	Desert = {
		weight = 1.0,
		timeScaledWeight = -0.05,
		region_count = { min = 1, max = 2 },
		regions = {
			{
				-- Wide open dune fields: rolling sand with scattered cacti
				name = "SandyDunes",
				size = Vector2.new(110, 100),
				resources = {
					Cactus = { Weight = 0.8, DistanceWeight = { Min = 1.0, Max = 0.8 } },
					Sand = { Weight = 0.9 },
					SaltCrystal = { Weight = 0.5 },
					Sandstone = { Weight = 0.4, DistanceWeight = { Min = 0.8, Max = 1.2 } },
					DriedBone = { Weight = 0.3, DistanceWeight = { Min = 0.9, Max = 1.1 } },
				},
				resource_count = { min = 10, max = 18 },
				props = {
					{ Name = "SandDune", Weight = 1.4, DistanceWeight = { Min = 1.0, Max = 1.1 } },
					{ Name = "Sand", Weight = 1.2, DistanceWeight = { Min = 1.1, Max = 0.9 } },
					{ Name = "DeadShrub", Weight = 0.6, DistanceWeight = { Min = 0.9, Max = 1.2 } },
				},
				prop_count = { min = 14, max = 24 },
				enemies = {
					{ Name = "Scorpion", Weight = 1.0, DistanceWeight = { Min = 0.9, Max = 1.2 } },
				},
				enemy_count = { min = 0, max = 2 },
			},
			{
				-- Exposed rock and mineable stone: the desert quarry
				name = "RockyOutcrop",
				size = Vector2.new(85, 85),
				resources = {
					Sandstone = { Weight = 1.3, DistanceWeight = { Min = 1.1, Max = 0.9 } },
					SulfiteOre = { Weight = 0.9 },
					SunShard = { Weight = 0.25, DistanceWeight = { Min = 0.8, Max = 1.3 } },
					Coal = { Weight = 1.0, DistanceWeight = { Min = 0.8, Max = 1.3 } },
					DriedBone = { Weight = 0.5, DistanceWeight = { Min = 0.9, Max = 1.1 } },
				},
				resource_count = { min = 16, max = 28 },
				props = {
					{ Name = "Sand", Weight = 0.7, DistanceWeight = { Min = 0.9, Max = 1.1 } },
					{ Name = "Skull", Weight = 0.9, DistanceWeight = { Min = 1.0, Max = 1.2 } },
					{ Name = "DeadShrub", Weight = 0.6, DistanceWeight = { Min = 1.0, Max = 1.1 } },
				},
				prop_count = { min = 8, max = 14 },
				enemies = {
					{ Name = "Scorpion", Weight = 1.0, DistanceWeight = { Min = 0.9, Max = 1.2 } },
					{ Name = "SandSerpent", Weight = 0.6, DistanceWeight = { Min = 0.8, Max = 1.4 } },
				},
				enemy_count = { min = 0, max = 2 },
			},
			{
				-- Graveyard of bones and remains: eerie, skull-heavy
				name = "BoneYard",
				size = Vector2.new(80, 80),
				resources = {
					DriedBone = { Weight = 1.4, DistanceWeight = { Min = 1.0, Max = 1.2 } },
					Cactus = { Weight = 0.4, DistanceWeight = { Min = 1.0, Max = 0.8 } },
					Coal = { Weight = 0.6, DistanceWeight = { Min = 0.9, Max = 1.3 } },
				},
				resource_count = { min = 14, max = 22 },
				props = {
					{ Name = "Skull", Weight = 1.5, DistanceWeight = { Min = 1.0, Max = 1.1 } },
					{ Name = "Sand", Weight = 0.8, DistanceWeight = { Min = 1.0, Max = 0.9 } },
					{ Name = "DeadShrub", Weight = 0.5, DistanceWeight = { Min = 0.9, Max = 1.2 } },
				},
				prop_count = { min = 12, max = 20 },
				enemies = {
					{ Name = "Scorpion", Weight = 0.8, DistanceWeight = { Min = 0.9, Max = 1.2 } },
					{ Name = "SandSerpent", Weight = 0.7, DistanceWeight = { Min = 0.9, Max = 1.3 } },
				},
				enemy_count = { min = 0, max = 2 },
			},
			{
				-- Dense cactus field: thorny and resource-rich
				name = "CactusFlats",
				size = Vector2.new(95, 90),
				resources = {
					Cactus = { Weight = 1.5, DistanceWeight = { Min = 1.1, Max = 0.9 } },
					Sand = { Weight = 0.7 },
					SaltCrystal = { Weight = 0.6 },
					Sandstone = { Weight = 0.5, DistanceWeight = { Min = 0.9, Max = 1.2 } },
					DriedBone = { Weight = 0.3, DistanceWeight = { Min = 1.0, Max = 1.1 } },
				},
				resource_count = { min = 18, max = 30 },
				props = {
					{ Name = "DeadShrub", Weight = 1.2, DistanceWeight = { Min = 1.0, Max = 1.1 } },
					{ Name = "Sand", Weight = 0.9, DistanceWeight = { Min = 1.1, Max = 0.9 } },
					{ Name = "SandDune", Weight = 0.4, DistanceWeight = { Min = 0.9, Max = 1.2 } },
				},
				prop_count = { min = 10, max = 18 },
				enemies = {
					{ Name = "Scorpion", Weight = 1.0, DistanceWeight = { Min = 0.9, Max = 1.1 } },
				},
				enemy_count = { min = 0, max = 2 },
			},
			{
				-- Coal-rich scorched earth: blackened sand with mining opportunities
				name = "ScorchedBasin",
				size = Vector2.new(80, 90),
				resources = {
					Coal = { Weight = 1.4, DistanceWeight = { Min = 0.8, Max = 1.3 } },
					SulfiteOre = { Weight = 1.0 },
					SunShard = { Weight = 0.3, DistanceWeight = { Min = 0.8, Max = 1.3 } },
					Sandstone = { Weight = 0.9, DistanceWeight = { Min = 1.0, Max = 1.1 } },
					Cactus = { Weight = 0.3, DistanceWeight = { Min = 1.0, Max = 0.8 } },
				},
				resource_count = { min = 16, max = 26 },
				props = {
					{ Name = "DeadShrub", Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 1.1 } },
					{ Name = "Skull", Weight = 0.5, DistanceWeight = { Min = 0.9, Max = 1.2 } },
					{ Name = "Sand", Weight = 0.8, DistanceWeight = { Min = 1.1, Max = 0.9 } },
				},
				prop_count = { min = 10, max = 16 },
				enemies = {
					{ Name = "Scorpion", Weight = 0.9, DistanceWeight = { Min = 0.9, Max = 1.2 } },
					{ Name = "SandSerpent", Weight = 0.5, DistanceWeight = { Min = 0.8, Max = 1.4 } },
				},
				enemy_count = { min = 0, max = 2 },
			},
		},
		structures = {
			{ Name = "AncientRuins", Weight = 0.7, DistanceWeight = { Min = 0.9, Max = 1.3 } },
			{ Name = "DesertOutpost", Weight = 0.5, DistanceWeight = { Min = 1.0, Max = 1.4 } },
		},
		structure_count = 0.5,
		objectives = {},
		objective_count = 0.025,
		chests = {
			{ Name = "Common_Chest", Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 0.9 } },
			{ Name = "Rare_Chest", Weight = 0.4, DistanceWeight = { Min = 0.9, Max = 1.3 } },
		},
		chest_count = 0.08,
	},
	Swamp = {
		weight = 1.0,
		timeScaledWeight = 0,
		region_count = { min = 1, max = 2 },
		regions = {
			{
				-- Deep bog with dense reeds and mangrove roots
				name = "MurkyBog",
				size = Vector2.new(110, 100),
				resources = {
					BogReed = { Weight = 1.4, DistanceWeight = { Min = 1.0, Max = 1.2 } },
					MarshWater = { Weight = 0.6 },
					PeatMound = { Weight = 1.0, DistanceWeight = { Min = 1.1, Max = 1.0 } },
					MangroveTree = { Weight = 1.1, DistanceWeight = { Min = 1.0, Max = 1.2 } },
				},
				resource_count = { min = 18, max = 30 },
				props = {
					{ Name = "RootTangle", Weight = 1.2, DistanceWeight = { Min = 1.0, Max = 1.2 } },
					{ Name = "LilyPadCluster", Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 1.1 } },
					{ Name = "CattailPatch", Weight = 0.9, DistanceWeight = { Min = 1.1, Max = 1.0 } },
				},
				prop_count = { min = 12, max = 20 },
				enemies = {
					{ Name = "GiantLeech", Weight = 1.1, DistanceWeight = { Min = 1.0, Max = 1.4 } },
					{ Name = "BogToad", Weight = 0.7, DistanceWeight = { Min = 0.9, Max = 1.3 } },
				},
				enemy_count = { min = 0, max = 2 },
			},
			{
				-- Damp fungal pockets with bioluminescent mushrooms
				name = "FungalMarsh",
				size = Vector2.new(90, 80),
				resources = {
					GlowcapCluster = { Weight = 1.6, DistanceWeight = { Min = 1.0, Max = 1.2 } },
					PeatMound = { Weight = 1.0, DistanceWeight = { Min = 1.2, Max = 0.9 } },
					WillowTreeSwamp = { Weight = 0.8, DistanceWeight = { Min = 1.0, Max = 1.0 } },
				},
				resource_count = { min = 16, max = 28 },
				props = {
					{ Name = "MossyStump", Weight = 1.2, DistanceWeight = { Min = 1.1, Max = 1.0 } },
					{ Name = "BogFern", Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 1.1 } },
					{ Name = "DriftwoodLog", Weight = 0.8, DistanceWeight = { Min = 1.0, Max = 1.2 } },
				},
				prop_count = { min = 10, max = 18 },
				enemies = {
					{ Name = "BogToad", Weight = 1.0, DistanceWeight = { Min = 0.9, Max = 1.4 } },
					{ Name = "GiantLeech", Weight = 0.8, DistanceWeight = { Min = 1.0, Max = 1.3 } },
				},
				enemy_count = { min = 0, max = 2 },
			},
			{
				-- Dense cypress zone with exposed mineral pockets
				name = "CypressHollow",
				size = Vector2.new(95, 90),
				resources = {
					CypressTree = { Weight = 1.3, DistanceWeight = { Min = 1.0, Max = 1.3 } },
					RootFiber = { Weight = 0.8 },
					MangroveTree = { Weight = 0.8, DistanceWeight = { Min = 1.0, Max = 1.2 } },
					MireStone = { Weight = 0.9, DistanceWeight = { Min = 0.9, Max = 1.3 } },
				},
				resource_count = { min = 14, max = 24 },
				props = {
					{ Name = "RootTangle", Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 1.2 } },
					{ Name = "MossyStump", Weight = 0.9, DistanceWeight = { Min = 1.1, Max = 1.0 } },
					{ Name = "DriftwoodLog", Weight = 0.8, DistanceWeight = { Min = 1.0, Max = 1.2 } },
				},
				prop_count = { min = 8, max = 14 },
				enemies = {
					{ Name = "GiantLeech", Weight = 0.9, DistanceWeight = { Min = 1.0, Max = 1.3 } },
					{ Name = "BogToad", Weight = 0.6, DistanceWeight = { Min = 0.9, Max = 1.4 } },
				},
				enemy_count = { min = 0, max = 2 },
			},
			{
				-- Open waterlogged flats with reed and lily clusters
				name = "ReedwaterFlats",
				size = Vector2.new(100, 95),
				resources = {
					BogReed = { Weight = 1.8, DistanceWeight = { Min = 1.1, Max = 1.2 } },
					MarshWater = { Weight = 0.8 },
					RootFiber = { Weight = 0.6 },
					PeatMound = { Weight = 0.8, DistanceWeight = { Min = 1.2, Max = 0.9 } },
					GlowcapCluster = { Weight = 0.8, DistanceWeight = { Min = 1.0, Max = 1.1 } },
				},
				resource_count = { min = 20, max = 34 },
				props = {
					{ Name = "LilyPadCluster", Weight = 1.2, DistanceWeight = { Min = 1.0, Max = 1.1 } },
					{ Name = "CattailPatch", Weight = 1.1, DistanceWeight = { Min = 1.0, Max = 1.2 } },
					{ Name = "BogFern", Weight = 0.8, DistanceWeight = { Min = 0.9, Max = 1.2 } },
				},
				prop_count = { min = 12, max = 22 },
				enemies = {
					{ Name = "BogToad", Weight = 1.1, DistanceWeight = { Min = 0.9, Max = 1.4 } },
					{ Name = "GiantLeech", Weight = 0.7, DistanceWeight = { Min = 1.0, Max = 1.4 } },
				},
				enemy_count = { min = 0, max = 2 },
			},
			{
				-- Transition marsh edge with mixed flora and salvage
				name = "SunkenEdge",
				size = Vector2.new(85, 85),
				resources = {
					WillowTreeSwamp = { Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 1.1 } },
					MireStone = { Weight = 0.9, DistanceWeight = { Min = 0.9, Max = 1.2 } },
					PeatMound = { Weight = 0.9, DistanceWeight = { Min = 1.2, Max = 0.9 } },
					BogReed = { Weight = 0.9, DistanceWeight = { Min = 1.0, Max = 1.1 } },
				},
				resource_count = { min = 16, max = 26 },
				props = {
					{ Name = "DriftwoodLog", Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 1.1 } },
					{ Name = "MossyStump", Weight = 0.9, DistanceWeight = { Min = 1.1, Max = 1.0 } },
					{ Name = "BogFern", Weight = 0.8, DistanceWeight = { Min = 1.0, Max = 1.2 } },
				},
				prop_count = { min = 10, max = 16 },
				enemies = {
					{ Name = "GiantLeech", Weight = 0.8, DistanceWeight = { Min = 1.0, Max = 1.3 } },
					{ Name = "BogToad", Weight = 0.8, DistanceWeight = { Min = 0.9, Max = 1.3 } },
				},
				enemy_count = { min = 0, max = 2 },
			},
		},
		structures = {
			{ Name = "SunkenShack", Weight = 0.6, DistanceWeight = { Min = 0.9, Max = 1.3 } },
			{ Name = "WreckedSkiff", Weight = 0.4, DistanceWeight = { Min = 1.0, Max = 1.4 } },
		},
		structure_count = 0.4,
		objectives = {},
		objective_count = 0.025,
		chests = {
			{ Name = "Common_Chest", Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 0.9 } },
			{ Name = "Rare_Chest", Weight = 0.45, DistanceWeight = { Min = 0.9, Max = 1.3 } },
		},
		chest_count = 0.08,
	},
	-- Later regions enter gradually; their weights keep rising during endless runs.
	FrozenTundra = {
		weight = 1.1,
		timeScaledWeight = 0.55,
		region_count = { min = 1, max = 2 },
		regions = {
			{
				name = "RimeGrove",
				size = Vector2.new(100, 100),
				resources = {
					Frostwood = { Weight = 1.2 },
					FrozenReed = { Weight = 1.0 },
					SnowLichen = { Weight = 0.8 },
					ChillBloom = { Weight = 0.6 },
				},
				resource_count = { min = 18, max = 28 },
				props = {}, prop_count = { min = 0, max = 0 },
				enemies = { { Name = "FrostWolf", Weight = 1.0 } },
				enemy_count = { min = 0, max = 2 },
			},
			{
				name = "GlacialShelf",
				size = Vector2.new(90, 90),
				resources = {
					GlacialStone = { Weight = 1.2 },
					IceCrystal = { Weight = 1.0 },
					PermafrostOre = { Weight = 0.8 },
					SnowLichen = { Weight = 0.5 },
				},
				resource_count = { min = 18, max = 28 },
				props = {}, prop_count = { min = 0, max = 0 },
				enemies = { { Name = "IceWraith", Weight = 1.0 }, { Name = "FrostWolf", Weight = 0.5 } },
				enemy_count = { min = 0, max = 2 },
			},
		},
		structures = {}, structure_count = 0,
		objectives = {}, objective_count = 0,
		chests = { { Name = "Common_Chest", Weight = 1.0 }, { Name = "Rare_Chest", Weight = 0.5 } },
		chest_count = 0.08,
	},
	Volcanic = {
		weight = 1.0,
		timeScaledWeight = 0.65,
		region_count = { min = 1, max = 2 },
		regions = {
			{
				name = "CinderFields",
				size = Vector2.new(105, 100),
				resources = {
					BasaltChunk = { Weight = 1.2 },
					ScoriaRock = { Weight = 1.0 },
					AshFiber = { Weight = 0.9 },
					EmberBloom = { Weight = 0.7 },
				},
				resource_count = { min = 18, max = 28 },
				props = {}, prop_count = { min = 0, max = 0 },
				enemies = { { Name = "MagmaHound", Weight = 1.0 } },
				enemy_count = { min = 0, max = 2 },
			},
			{
				name = "ObsidianVent",
				size = Vector2.new(90, 95),
				resources = {
					ObsidianShard = { Weight = 1.1 },
					SulfurOre = { Weight = 1.0 },
					LavaSalt = { Weight = 0.8 },
					BasaltChunk = { Weight = 0.8 },
				},
				resource_count = { min = 18, max = 28 },
				props = {}, prop_count = { min = 0, max = 0 },
				enemies = { { Name = "MagmaHound", Weight = 1.0 }, { Name = "LavaGolem", Weight = 0.25 } },
				enemy_count = { min = 0, max = 2 },
			},
		},
		structures = {}, structure_count = 0,
		objectives = {}, objective_count = 0,
		chests = { { Name = "Common_Chest", Weight = 1.0 }, { Name = "Rare_Chest", Weight = 0.6 } },
		chest_count = 0.08,
	},
	CrystalWastes = {
		weight = 1.1,
		timeScaledWeight = 0.85,
		region_count = { min = 1, max = 2 },
		regions = {
			{
				name = "PrismGarden",
				size = Vector2.new(100, 100),
				resources = {
					CrystalShard = { Weight = 1.2 },
					PrismSand = { Weight = 1.0 },
					LatticeFiber = { Weight = 0.9 },
					EchoBloom = { Weight = 0.6 },
				},
				resource_count = { min = 18, max = 28 },
				props = {}, prop_count = { min = 0, max = 0 },
				enemies = { { Name = "CrystalStalker", Weight = 1.0 } },
				enemy_count = { min = 0, max = 2 },
			},
			{
				name = "NullRidge",
				size = Vector2.new(90, 90),
				resources = {
					PhaseQuartz = { Weight = 0.8 },
					VoidResidue = { Weight = 0.9 },
					AlloyDust = { Weight = 1.0 },
					CrystalShard = { Weight = 0.8 },
				},
				resource_count = { min = 18, max = 28 },
				props = {}, prop_count = { min = 0, max = 0 },
				enemies = { { Name = "CrystalStalker", Weight = 1.0 }, { Name = "VoidSentinel", Weight = 0.2 } },
				enemy_count = { min = 0, max = 2 },
			},
		},
		structures = {}, structure_count = 0,
		objectives = {}, objective_count = 0,
		chests = { { Name = "Common_Chest", Weight = 0.8 }, { Name = "Rare_Chest", Weight = 0.8 } },
		chest_count = 0.08,
	},
}

-- The two newest playable biomes use the same gathering/AI/station pipeline.
Config.biomes.AuroraVale = {
	weight = 1.1, timeScaledWeight = 0.75,
	region_count = { min = 1, max = 2 },
	regions = {
		{
			name = "DawnMeadow", size = Vector2.new(105, 110),
			resources = { AuroraFiber = { Weight = 1.4 }, DawnBloom = { Weight = 1.1 }, PolarQuartz = { Weight = 0.8 } },
			props = { { Name = "AuroraTree", Weight = 1 }, { Name = "DawnBush", Weight = 1 } },
			enemies = { { Name = "AuroraStag", Weight = 1 } },
			resource_count = { min = 18, max = 28 }, prop_count = { min = 6, max = 10 }, enemy_count = { min = 0, max = 2 },
		},
		{
			name = "PolarGrove", size = Vector2.new(100, 115),
			resources = { PolarQuartz = { Weight = 1.4 }, AuroraFiber = { Weight = 1.1 }, DawnBloom = { Weight = 0.7 } },
			props = { { Name = "AuroraTree", Weight = 1 }, { Name = "PolarRock", Weight = 1 } },
			enemies = { { Name = "AuroraStag", Weight = 1 } },
			resource_count = { min = 18, max = 28 }, prop_count = { min = 6, max = 10 }, enemy_count = { min = 0, max = 2 },
		},
	},
	structures = {}, structure_count = 0, objectives = {}, objective_count = 0,
	chests = { { Name = "Rare_Chest", Weight = 1 } }, chest_count = 0.08,
}
Config.biomes.StarfallCrater = {
	weight = 1.2, timeScaledWeight = 0.85,
	region_count = { min = 1, max = 2 },
	regions = {
		{
			name = "ImpactBasin", size = Vector2.new(110, 105),
			resources = { MeteorIron = { Weight = 1.4 }, ImpactGlass = { Weight = 1 }, CosmicDust = { Weight = 0.8 } },
			props = { { Name = "MeteorBoulder", Weight = 1 }, { Name = "ImpactSpire", Weight = 1 } },
			enemies = { { Name = "CometCrawler", Weight = 1 } },
			resource_count = { min = 18, max = 28 }, prop_count = { min = 5, max = 9 }, enemy_count = { min = 0, max = 2 },
		},
		{
			name = "GlassRim", size = Vector2.new(115, 100),
			resources = { ImpactGlass = { Weight = 1.4 }, CosmicDust = { Weight = 1.1 }, MeteorIron = { Weight = 0.8 } },
			props = { { Name = "ImpactSpire", Weight = 1 }, { Name = "CraterLog", Weight = 0.6 } },
			enemies = { { Name = "CometCrawler", Weight = 1 } },
			resource_count = { min = 18, max = 28 }, prop_count = { min = 5, max = 9 }, enemy_count = { min = 0, max = 2 },
		},
	},
	structures = {}, structure_count = 0, objectives = {}, objective_count = 0,
	chests = { { Name = "Rare_Chest", Weight = 1 } }, chest_count = 0.08,
}

-- Roadmap only: these eight entries never enter generation, forecasts or voting.
Config.future_biomes = {
	SaltglassCoast = { DisplayName = "Saltglass Coast", Implemented = false, Theme = "Tides, brine and shell composites" },
	StormspireHighlands = { DisplayName = "Stormspire Highlands", Implemented = false, Theme = "Wind, storms and conductive ores" },
	MyceliumHollow = { DisplayName = "Mycelium Hollow", Implemented = false, Theme = "Spores, medicines and living materials" },
	IronrootBadlands = { DisplayName = "Ironroot Badlands", Implemented = false, Theme = "Metal roots, dust and reinforced machinery" },
	SunkenArchive = { DisplayName = "Sunken Archive", Implemented = false, Theme = "Flooded ruins, salvage and pressure" },
	CanopySea = { DisplayName = "Canopy Sea", Implemented = false, Theme = "Vertical forest, silk and gliding fauna" },
	UmbralDepths = { DisplayName = "Umbral Depths", Implemented = false, Theme = "Darkness, acoustics and luminous minerals" },
	ShattermoonExpanse = { DisplayName = "Shattermoon Expanse", Implemented = false, Theme = "Fractured gravity and lunar materials" },
}

Config.terrain_detail.materials_by_biome.AuroraVale = {
	path = "Snow", patches = { { material = "Grass", threshold = 0.52 }, { material = "Ice", threshold = 0.82 } },
}
Config.terrain_detail.materials_by_biome.StarfallCrater = {
	path = "Basalt", patches = { { material = "Rock", threshold = 0.54 }, { material = "CrackedLava", threshold = 0.86 } },
}

-- Shared gameplay config (moved from ReplicatedStorage/Shared/Config.lua)
Config.BIOME_DEFAULT = Config.biome_default
Config.BIOME_SHIFT = Config.biome_shift

Config.WORLD = {
	WorldRadius = Config.world_radius,
	CenterExclusionRadius = Config.center_exclusion_radius,
	BaseY = Config.base_y,
}

Config.TERRAIN = {
	Thickness = 24,
	MaterialByBiome = {
		Forest = "Grass",
		Desert = "Sand",
		Swamp = "Mud",
		FrozenTundra = "Snow",
		Volcanic = "Basalt",
		CrystalWastes = "Rock",
		AuroraVale = "Snow",
		StarfallCrater = "Basalt",
	},
}

Config.BIOMES = {}
for name, gen in pairs(Config.biomes or {}) do
	local entry = {}
	local meta = Config.biome_metadata and Config.biome_metadata[name]
	if meta then
		for k, v in pairs(meta) do
			entry[k] = v
		end
	end
	entry.Weight = gen.weight or gen.Weight or 1
	entry.TimeScaledWeight = gen.timeScaledWeight or gen.time_scaled_weight or gen.TimeScaledWeight or 0
	entry.MinElapsed = gen.minElapsed or gen.MinElapsed or entry.MinElapsed or 0
	entry.DisplayName = gen.displayName or gen.DisplayName or entry.DisplayName or name
	Config.BIOMES[name] = entry
end

return Config
