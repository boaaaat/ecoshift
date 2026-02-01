-- Config.lua
-- Central game tuning values. Edit freely.

local Config = {}

Config.Paths = {
	Remotes = "ReplicatedStorage/Remotes",
	EnemySpawnsFolder = "Workspace/EnemySpawns",
	ResourceNodesFolder = "Workspace/ResourceNodes",
	ObjectivesFolder = "Workspace/Objectives",
}

Config.RemoteNames = {
	Build = "Build",
	Damage = "Damage",
	Interact = "Interact",
	EventBroadcast = "EventBroadcast",
	ObjectiveUpdate = "ObjectiveUpdate",
	BiomeChanged = "BiomeChanged",
	Craft = "Craft",
	Ping = "Ping",
	InventoryUpdate = "InventoryUpdate",
	InventoryAction = "InventoryAction",
	ProfileUpdate = "ProfileUpdate",
	RoleUpdate = "RoleUpdate",
	RoleSelect = "RoleSelect",
	GameStateUpdate = "GameStateUpdate",
	DropItem = "DropItem",
	ChestEvent = "ChestEvent",
	TimeUpdate = "TimeUpdate",
	HarvestFeedback = "HarvestFeedback",
}

Config.BIOME_DEFAULT = "Forest"
Config.BIOME_SHIFT = {
	MinSeconds = 300, -- 5 minutes
	MaxSeconds = 480, -- 8 minutes
	TimeScaleSeconds = 900,
}

-- NOTE: Biome metadata is now in BiomeConfig.lua (ServerScriptService/WorldGen/BiomeConfig.lua)
-- This table is kept for backward compatibility with BiomeService and SpawnService
-- Only include biomes that are currently active (Forest & Desert for testing)
Config.BIOMES = {
	Forest = {
		Weight = 1.0,
		TimeScaledWeight = -0.2,
		env = { Temp = 0, Toxin = 0, Wet = 0 },
		resourceTags = { "Wood", "Plants", "Stone" },
		enemyTables = { "ForestCommon" },
	},
	Desert = {
		Weight = 0.8,
		TimeScaledWeight = -0.1,
		env = { Temp = 1, Toxin = 0, Wet = -1 },
		resourceTags = { "Stone", "Ore", "Cactus" },
		enemyTables = { "DesertCommon" },
	},
	-- Uncomment these when assets are ready:
	--[[
	Swamp = {
		Weight = 0.7,
		TimeScaledWeight = 0.15,
		env = { Temp = 0, Toxin = 1, Wet = 2 },
		resourceTags = { "Herb", "Reed", "Mud" },
		enemyTables = { "SwampCommon" },
	},
	FrozenTundra = {
		Weight = 0.6,
		TimeScaledWeight = 0.25,
		env = { Temp = -2, Toxin = 0, Wet = 0 },
		resourceTags = { "Ice", "Stone", "Fur" },
		enemyTables = { "TundraCommon" },
	},
	Volcanic = {
		Weight = 0.4,
		TimeScaledWeight = 0.35,
		env = { Temp = 2, Toxin = 0, Wet = -1 },
		resourceTags = { "Ore", "Sulfur", "Obsidian" },
		enemyTables = { "VolcanicCommon" },
	},
	CrystalWastes = {
		Weight = 0.3,
		TimeScaledWeight = 0.4,
		env = { Temp = 0, Toxin = 0, Wet = 0 },
		resourceTags = { "Crystal", "Void", "Alloy" },
		enemyTables = { "CrystalCommon" },
	},
	--]]
}
	CycleDurationSeconds = 600, -- 10 real minutes = 1 full in-game day
	StartTime = 6, -- Start at 6 AM
	EnemyNightMultiplier = 1.5, -- Enemies 50% stronger at night
	ResourceNightMultiplier = 0.7, -- 30% fewer resources at night
	NightVisionRequired = true, -- Future: require torches/night vision
}

Config.DATASTORE = {
	ProfileStore = "EcoshiftProfile_v1",
	AutosaveInterval = 60,
}

Config.WORLD = {
	WorldRadius = 2200,
	CenterExclusionRadius = 260,
	BaseY = 0,
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
	},
}

Config.GRID = {
	Size = 6,
	BuildMaxDistance = 45,
}

Config.STARTER_ITEMS = {}

Config.UI = {
	PlaceholderIcon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
}

-- OPTIMIZED: Increased prompt rate for faster resource binding
Config.PROMPTS = {
	MaxPerSecond = 2000,
}

Config.LOOT = {
	DefaultTable = "Default",
	DropSpread = 4,
	DropHeight = 2,
	TierWeightMult = {
		[1] = 1.0,
		[2] = 1.35,
		[3] = 1.75,
		[4] = 2.2,
	},
}

Config.ROLES = {
	Default = "Generalist",
	Definitions = {
		Generalist = { Name = "Generalist", Gather = 1.0, Build = 1.0, Combat = 1.0, Heal = 1.0, Craft = 1.0 },
		Builder = { Name = "Builder", Gather = 0.9, Build = 1.3, Combat = 0.9, Heal = 0.9, Craft = 1.1 },
		Hunter = { Name = "Hunter", Gather = 1.0, Build = 0.9, Combat = 1.25, Heal = 0.9, Craft = 1.0 },
		Gatherer = { Name = "Gatherer", Gather = 1.3, Build = 0.9, Combat = 0.9, Heal = 0.9, Craft = 1.0 },
		Engineer = { Name = "Engineer", Gather = 1.0, Build = 1.1, Combat = 0.9, Heal = 0.9, Craft = 1.25 },
		Medic = { Name = "Medic", Gather = 0.9, Build = 0.9, Combat = 0.9, Heal = 1.4, Craft = 1.0 },
	},
}

Config.THREAT = {
	Clamp = { 0, 10 },
	BasePerMinute = 0.35,
	BossKill = 2.5,
	FailedObjective = 1.5,
}

Config.EVENTS = {
	MinorCadence = { 180, 300 },
	MajorCadence = { 420, 540 },
	PoolMinor = {
		"MeteorShower",
		"ToxicFog",
		"ResourceBoom",
		"MonsoonFlood",
	},
	PoolMajor = {
		"MonsterSiege",
		"WormholeRift",
		"BiomeQuake",
	},
}

Config.OBJECTIVES = {
	MaxConcurrent = 2,
	DurationSeconds = { 140, 240 },
	Pool = {
		{ Id = "RelayRepair", MinMinute = 0 },
		{ Id = "InfectionPurge", MinMinute = 2 },
		{ Id = "CrystalHarvest", MinMinute = 3 },
		{ Id = "LostResearcher", MinMinute = 4 },
		{ Id = "CommsUplink", MinMinute = 5 },
		{ Id = "BeastCull", MinMinute = 6 },
		{ Id = "SupplyHeist", MinMinute = 7 },
		{ Id = "DamSluice", MinMinute = 8 },
	},
}

-- NOTE: Full biome configuration is now in BiomeConfig.lua (ServerScriptService/WorldGen)
-- This minimal table is kept for client-side services that need basic biome info
Config.BIOMES = {
	Forest = {
		env = { Temp = 0, Toxin = 0, Wet = 0 },
	},
	Desert = {
		env = { Temp = 1, Toxin = 0, Wet = -1 },
	},
	-- Other biomes commented out until assets are ready (see BiomeConfig.lua)
}

Config.RECIPES = {
	StoneHatchet = {
		{ Id = "Wood", N = 2 },
		{ Id = "Stone", N = 1 },
	},
	StonePickaxe = {
		{ Id = "Wood", N = 2 },
		{ Id = "Stone", N = 2 },
	},
	Bow = {
		{ Id = "Wood", N = 3 },
		{ Id = "Reed", N = 2 },
	},
	Arrow = {
		{ Id = "Wood", N = 1 },
		{ Id = "Stone", N = 1 },
	},
	Campfire = {
		{ Id = "Wood", N = 4 },
		{ Id = "Stone", N = 2 },
	},
}

Config.BUILD = {
	AllowedTypes = {
		Wall = true,
		Floor = true,
		Ramp = true,
		Gate = true,
		Tower = true,
		Trap = true,
		Machine = true,
	},
	Costs = {
		Wall = { { Id = "Wood", N = 2 } },
		Floor = { { Id = "Wood", N = 2 } },
		Ramp = { { Id = "Wood", N = 3 } },
		Gate = { { Id = "Wood", N = 4 }, { Id = "Stone", N = 2 } },
		Tower = { { Id = "Wood", N = 6 }, { Id = "Stone", N = 4 } },
		Trap = { { Id = "Stone", N = 2 } },
		Machine = { { Id = "Stone", N = 6 } },
	},
}

Config.UI = {
	UpdateInterval = 0.25,
}

return Config
