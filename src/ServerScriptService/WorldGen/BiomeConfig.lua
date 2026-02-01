local Config = {}

Config.seed = 12345
Config.world_radius = 2200
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
	Sandstone = { scale = 1.5, yOffset = 4 },
	DriedBone = { scale = 0.8, yOffset = 1 },
	-- DESERT PROPS
	Skull = { scale = 0.6, yOffset = 0.5 },
	DeadShrub = { scale = 1.0, yOffset = 1 },
	SandDune = { scale = 2.0, yOffset = 0 },
	-- DESERT STRUCTURES
	AncientRuins = { scale = 1.0, yOffset = 4 },
	DesertOutpost = { scale = 1.0, yOffset = 4 },
}

-- STREAMING CONFIG: Dynamic chunk loading around players
Config.use_streaming = true -- Set to false to use legacy full-world generation
Config.stream_load_radius = 3 -- Load chunks within this radius (in chunks)
Config.stream_unload_radius = 5 -- Unload chunks beyond this radius
Config.stream_update_interval = 0.5 -- How often to check player positions
Config.stream_unload_delay = 10 -- Seconds before unloading unused chunk

-- BIOME SHIFT CONFIG: How often biomes change
Config.biome_default = "Forest"
Config.biome_shift = {
	MinSeconds = 300, -- 5 minutes minimum
	MaxSeconds = 480, -- 8 minutes maximum
	TimeScaleSeconds = 900, -- Time scaling factor for weight calculations
}

-- BIOME METADATA: Environment effects, resource tags, enemy tables
-- Used by BiomeService for selection and SpawnService for enemy waves
Config.biome_metadata = {
	Forest = {
		env = { Temp = 0, Toxin = 0, Wet = 0 },
		resourceTags = { "Wood", "Plants", "Stone" },
		enemyTables = { "ForestCommon" },
	},
	Desert = {
		env = { Temp = 1, Toxin = 0, Wet = -1 },
		resourceTags = { "Stone", "Ore", "Cactus" },
		enemyTables = { "DesertCommon" },
	},
	Swamp = {
		env = { Temp = 0, Toxin = 1, Wet = 2 },
		resourceTags = { "Herb", "Reed", "Mud" },
		enemyTables = { "SwampCommon" },
	},
	FrozenTundra = {
		env = { Temp = -2, Toxin = 0, Wet = 0 },
		resourceTags = { "Ice", "Stone", "Fur" },
		enemyTables = { "TundraCommon" },
	},
	Volcanic = {
		env = { Temp = 2, Toxin = 0, Wet = -1 },
		resourceTags = { "Ore", "Sulfur", "Obsidian" },
		enemyTables = { "VolcanicCommon" },
	},
	CrystalWastes = {
		env = { Temp = 0, Toxin = 0, Wet = 0 },
		resourceTags = { "Crystal", "Void", "Alloy" },
		enemyTables = { "CrystalCommon" },
	},
}

-- BIOME WORLD GEN CONFIG: Regions, resources, props, structures per biome
Config.biomes = {
	Forest = {
		weight = 1.0,
		timeScaledWeight = -0.3,
		region_count = { min = 1, max = 2 },
		regions = {
			{
				name = "ForestClearing",
				size = Vector2.new(100, 100),
				resources = { Tree = 1, Mushroom = 2, Reed = 3 },
				resource_count = { min = 16, max = 28 },
				props = { "Bush", "FallenLog" },
				prop_count = { min = 10, max = 18 },
				enemies = { "Wolf" },
				enemy_count = { min = 0, max = 2 },
			},
			{
				name = "ThickGrove",
				size = Vector2.new(80, 80),
				resources = { Mud = 3, Stone = 1, Mushroom = 2 },
				resource_count = { min = 22, max = 36 },
				props = { "RockSmall", "Stump" },
				prop_count = { min = 8, max = 14 },
				enemies = { "Wolf" },
				enemy_count = { min = 0, max = 2 },
			},
		},
		structures = { "CabinRuin", "WatchTower" },
		structure_count = 0.05,
		objectives = {},
		objective_count = 0.025,
		chests = { "Common_Chest", "Rare_Chest" },
		chest_count = 0.08,
	},
	Desert = {
		weight = 0.8,
		timeScaledWeight = -0.1,
		region_count = { min = 1, max = 2 },
		regions = {
			{
				name = "SandyDunes",
				size = Vector2.new(100, 100),
				resources = { Cactus = 1, Sandstone = 2, DriedBone = 3 },
				resource_count = { min = 14, max = 24 },
				props = { "Skull", "DeadShrub", "SandDune" },
				prop_count = { min = 10, max = 18 },
				enemies = { "Scorpion" },
				enemy_count = { min = 0, max = 2 },
			},
			{
				name = "RockyOutcrop",
				size = Vector2.new(80, 80),
				resources = { Sandstone = 1, Stone = 2, DriedBone = 3 },
				resource_count = { min = 18, max = 30 },
				props = { "Skull", "DeadShrub" },
				prop_count = { min = 8, max = 14 },
				enemies = { "Scorpion", "SandSerpent" },
				enemy_count = { min = 0, max = 2 },
			},
		},
		structures = { "AncientRuins", "DesertOutpost" },
		structure_count = 0.05,
		objectives = {},
		objective_count = 0.025,
		chests = { "Desert_Chest", "Rare_Chest" },
		chest_count = 0.08,
	},
	--[[ SWAMP - Uncomment when assets are ready
	Swamp = {
		weight = 0.5,
		timeScaledWeight = 0.15,
		region_count = { min = 1, max = 2 },
		regions = {
			{
				name = "MurkyBog",
				size = Vector2.new(100, 100),
				resources = { WillowTree = 1, SwampReed = 2, GlowMoss = 3 },
				resource_count = { min = 16, max = 28 },
				props = { "LilyPad", "DeadTree", "MudPile" },
				prop_count = { min = 10, max = 18 },
				enemies = { "GiantLeech" },
				enemy_count = { min = 0, max = 2 },
			},
			{
				name = "ToxicMarsh",
				size = Vector2.new(80, 80),
				resources = { SwampReed = 1, GlowMoss = 2, Mud = 3 },
				resource_count = { min = 20, max = 32 },
				props = { "DeadTree", "MudPile" },
				prop_count = { min = 8, max = 14 },
				enemies = { "GiantLeech", "BogToad" },
				enemy_count = { min = 0, max = 2 },
			},
		},
		structures = { "SwampHut", "AbandonedBoat" },
		structure_count = 0.05,
		objectives = {},
		objective_count = 0.025,
		chests = { "Swamp_Chest", "Rare_Chest" },
		chest_count = 0.08,
	},
	--]]
	--[[ FROZEN TUNDRA - Uncomment when assets are ready
	FrozenTundra = {
		weight = 0.3,
		timeScaledWeight = 0.25,
		region_count = { min = 1, max = 2 },
		regions = {
			{
				name = "FrozenPlains",
				size = Vector2.new(100, 100),
				resources = { FrozenPine = 1, IceCrystal = 2, PermafrostOre = 4 },
				resource_count = { min = 14, max = 24 },
				props = { "IceShard", "SnowPile", "FrozenCorpse" },
				prop_count = { min = 10, max = 18 },
				enemies = { "FrostWolf" },
				enemy_count = { min = 0, max = 2 },
			},
			{
				name = "GlacialRidge",
				size = Vector2.new(80, 80),
				resources = { IceCrystal = 1, PermafrostOre = 2, Stone = 3 },
				resource_count = { min = 18, max = 28 },
				props = { "IceShard", "SnowPile" },
				prop_count = { min = 8, max = 14 },
				enemies = { "FrostWolf", "IceWraith" },
				enemy_count = { min = 0, max = 2 },
			},
		},
		structures = { "FrozenCabin", "IceCave" },
		structure_count = 0.05,
		objectives = {},
		objective_count = 0.025,
		chests = { "Frozen_Chest", "Rare_Chest" },
		chest_count = 0.08,
	},
	--]]
	--[[ VOLCANIC - Uncomment when assets are ready
	Volcanic = {
		weight = 0.2,
		timeScaledWeight = 0.35,
		region_count = { min = 1, max = 2 },
		regions = {
			{
				name = "AshenWastes",
				size = Vector2.new(100, 100),
				resources = { CharredTree = 1, Obsidian = 2, SulfurDeposit = 3 },
				resource_count = { min = 12, max = 22 },
				props = { "LavaRock", "AshPile", "SmokeVent" },
				prop_count = { min = 10, max = 18 },
				enemies = { "MagmaHound" },
				enemy_count = { min = 0, max = 2 },
			},
			{
				name = "MoltenCore",
				size = Vector2.new(80, 80),
				resources = { Obsidian = 1, SulfurDeposit = 2 },
				resource_count = { min = 16, max = 26 },
				props = { "LavaRock", "SmokeVent" },
				prop_count = { min = 8, max = 14 },
				enemies = { "MagmaHound", "LavaGolem" },
				enemy_count = { min = 0, max = 2 },
			},
		},
		structures = { "LavaForge", "ObsidianTemple" },
		structure_count = 0.05,
		objectives = {},
		objective_count = 0.025,
		chests = { "Volcanic_Chest", "Legendary_Chest" },
		chest_count = 0.08,
	},
	--]]
	--[[ CRYSTAL WASTES - Uncomment when assets are ready
	CrystalWastes = {
		weight = 0.1,
		timeScaledWeight = 0.4,
		region_count = { min = 1, max = 2 },
		regions = {
			{
				name = "ShatteredFields",
				size = Vector2.new(100, 100),
				resources = { VoidCrystal = 1, CorruptedOre = 2, PrismShard = 3 },
				resource_count = { min = 10, max = 18 },
				props = { "FloatingCrystal", "VoidRift", "CrystalSpire" },
				prop_count = { min = 10, max = 18 },
				enemies = { "CrystalStalker" },
				enemy_count = { min = 0, max = 2 },
			},
			{
				name = "VoidNexus",
				size = Vector2.new(80, 80),
				resources = { VoidCrystal = 1, PrismShard = 2 },
				resource_count = { min = 14, max = 22 },
				props = { "CrystalSpire", "VoidRift" },
				prop_count = { min = 8, max = 14 },
				enemies = { "CrystalStalker", "VoidSentinel" },
				enemy_count = { min = 0, max = 1 },
			},
		},
		structures = { "CrystalAltar", "VoidPortal" },
		structure_count = 0.05,
		objectives = {},
		objective_count = 0.025,
		chests = { "Void_Chest", "Celestial_Chest" },
		chest_count = 0.08,
	},
	--]]
}

return Config
