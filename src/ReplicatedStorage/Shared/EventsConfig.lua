-- EventsConfig.lua
-- Data-driven event definitions, per-biome pools, and cadence.
-- To add a new event: add a Definition, then reference it in BiomePools.
-- To tweak a biome's version: add Overrides in that biome's pool entry.

local EventsConfig = {}

-------------------------------------------------------------------------
-- BASE DEFINITIONS
-- Every event lives here with its default values.
-- BiomePools can override any field via deep merge.
-------------------------------------------------------------------------
EventsConfig.Definitions = {

	----------------------------------------------------------------
	-- MINOR EVENTS
	----------------------------------------------------------------

	MeteorShower = {
		Type = "Minor",
		MinElapsed = 15 * 60,
		Duration = { min = 45, max = 75 },
		Effects = { EnemyMultiplier = 0.25 },
		Modifiers = {},
		Drops = {},
		DropInterval = 0,
		ClientHints = { Icon = "MeteorShower", Color = { 255, 120, 40 } },
		EndOnBiomeChange = true,
	},

	ToxicFog = {
		Type = "Minor",
		MinElapsed = 15 * 60,
		Duration = { min = 50, max = 80 },
		Effects = {},
		Modifiers = { Toxin = 1 },
		Drops = {},
		DropInterval = 0,
		ClientHints = { Icon = "ToxicFog", Color = { 80, 220, 80 } },
		EndOnBiomeChange = true,
	},

	ResourceBoom = {
		Type = "Minor",
		MinElapsed = 0,
		Duration = { min = 40, max = 70 },
		Effects = { ResourceMultiplier = 0.75 },
		Modifiers = {},
		Drops = {},
		DropInterval = 0,
		ClientHints = { Icon = "ResourceBoom", Color = { 60, 200, 255 } },
		EndOnBiomeChange = true,
	},

	MonsoonFlood = {
		Type = "Minor",
		MinElapsed = 10 * 60,
		Duration = { min = 45, max = 75 },
		Effects = {},
		Modifiers = { Wet = 1 },
		Drops = {},
		DropInterval = 0,
		ClientHints = { Icon = "MonsoonFlood", Color = { 40, 100, 220 } },
		EndOnBiomeChange = true,
	},

	-- Desert-specific
	Sandstorm = {
		Type = "Minor",
		MinElapsed = 20 * 60,
		Duration = { min = 50, max = 80 },
		Effects = { ResourceMultiplier = -0.3 },
		Modifiers = { Temp = 1 },
		Drops = { { ItemId = "Sand", Count = { min = 1, max = 3 }, Chance = 0.4 } },
		DropInterval = 12,
		ClientHints = { Icon = "Sandstorm", Color = { 210, 180, 100 } },
		EndOnBiomeChange = true,
	},

	SolarFlare = {
		Type = "Minor",
		MinElapsed = 40 * 60,
		Duration = { min = 30, max = 55 },
		Effects = {},
		Modifiers = { Temp = 2 },
		Drops = { { ItemId = "TemperedGlass", Count = 1, Chance = 0.2 } },
		DropInterval = 15,
		ClientHints = { Icon = "SolarFlare", Color = { 255, 200, 50 } },
		EndOnBiomeChange = true,
	},

	BuriedTreasure = {
		Type = "Minor",
		MinElapsed = 0,
		Duration = { min = 60, max = 90 },
		Effects = {},
		Modifiers = {},
		Drops = {
			{ ItemId = "Coal", Count = { min = 2, max = 4 }, Chance = 0.5 },
			{ ItemId = "DriedBone", Count = { min = 1, max = 2 }, Chance = 0.3 },
			{ ItemId = "SulfiteOre", Count = 1, Chance = 0.15 },
		},
		DropInterval = 10,
		ClientHints = { Icon = "BuriedTreasure", Color = { 200, 170, 80 } },
		EndOnBiomeChange = true,
	},

	ScorpionSwarm = {
		Type = "Minor",
		MinElapsed = 20 * 60,
		Duration = { min = 40, max = 65 },
		Effects = { EnemyMultiplier = 0.5 },
		Modifiers = {},
		Drops = {
			{ ItemId = "ScorpionStinger", Count = { min = 1, max = 2 }, Chance = 0.35 },
			{ ItemId = "DriedBone", Count = 1, Chance = 0.2 },
		},
		DropInterval = 8,
		ClientHints = { Icon = "ScorpionSwarm", Color = { 160, 100, 40 } },
		EndOnBiomeChange = true,
	},

	OasisMirage = {
		Type = "Minor",
		MinElapsed = 0,
		Duration = { min = 50, max = 75 },
		Effects = { ResourceMultiplier = 0.5 },
		Modifiers = { Temp = -1 },
		Drops = {
			{ ItemId = "CactusStem", Count = { min = 1, max = 2 }, Chance = 0.45 },
			{ ItemId = "StaminaRation", Count = 1, Chance = 0.25 },
		},
		DropInterval = 10,
		ClientHints = { Icon = "OasisMirage", Color = { 60, 180, 200 } },
		EndOnBiomeChange = true,
	},

	SulfurVent = {
		Type = "Minor",
		MinElapsed = 30 * 60,
		Duration = { min = 35, max = 60 },
		Effects = {},
		Modifiers = { Toxin = 1, Temp = 1 },
		Drops = {
			{ ItemId = "SulfiteOre", Count = { min = 1, max = 3 }, Chance = 0.5 },
			{ ItemId = "Coal", Count = 1, Chance = 0.2 },
		},
		DropInterval = 10,
		ClientHints = { Icon = "SulfurVent", Color = { 200, 200, 50 } },
		EndOnBiomeChange = true,
	},

	DustDevil = {
		Type = "Minor",
		MinElapsed = 15 * 60,
		Duration = { min = 25, max = 45 },
		Effects = { ResourceMultiplier = -0.2 },
		Modifiers = {},
		Drops = {
			{ ItemId = "Sand", Count = { min = 2, max = 5 }, Chance = 0.5 },
			{ ItemId = "DriedBone", Count = 1, Chance = 0.15 },
		},
		DropInterval = 6,
		ClientHints = { Icon = "DustDevil", Color = { 190, 160, 110 } },
		EndOnBiomeChange = true,
	},

	-- Desert major
	SandWurmRise = {
		Type = "Major",
		MinElapsed = 40 * 60,
		Duration = { min = 80, max = 120 },
		Effects = { EnemyMultiplier = 0.7 },
		Modifiers = { Temp = 1 },
		Drops = {
			{ ItemId = "DriedBone", Count = { min = 2, max = 4 }, Chance = 0.4 },
			{ ItemId = "SulfiteOre", Count = { min = 1, max = 2 }, Chance = 0.3 },
			{ ItemId = "SunShard", Count = { min = 1, max = 2 }, Chance = 0.2 },
		},
		DropInterval = 12,
		ClientHints = { Icon = "SandWurmRise", Color = { 180, 130, 60 } },
		EndOnBiomeChange = false,
	},

	-- Swamp-specific
	MiasmaBurst = {
		Type = "Minor",
		MinElapsed = 30 * 60,
		Duration = { min = 40, max = 65 },
		Effects = {},
		Modifiers = { Toxin = 2, Wet = 1 },
		Drops = {},
		DropInterval = 0,
		ClientHints = { Icon = "MiasmaBurst", Color = { 100, 160, 60 } },
		EndOnBiomeChange = true,
	},

	-- Tundra-specific
	Blizzard = {
		Type = "Minor",
		MinElapsed = 30 * 60,
		Duration = { min = 50, max = 80 },
		Effects = { ResourceMultiplier = -0.2 },
		Modifiers = { Temp = -2 },
		Drops = {},
		DropInterval = 0,
		ClientHints = { Icon = "Blizzard", Color = { 200, 220, 255 } },
		EndOnBiomeChange = true,
	},

	-- Volcanic-specific
	LavaFlow = {
		Type = "Minor",
		MinElapsed = 35 * 60,
		Duration = { min = 35, max = 60 },
		Effects = {},
		Modifiers = { Temp = 2 },
		Drops = { { ItemId = "ObsidianShard", Count = 1, Chance = 0.25 } },
		DropInterval = 10,
		ClientHints = { Icon = "LavaFlow", Color = { 255, 80, 20 } },
		EndOnBiomeChange = true,
	},

	-- Crystal-specific
	VoidSurge = {
		Type = "Minor",
		MinElapsed = 45 * 60,
		Duration = { min = 40, max = 70 },
		Effects = { EnemyMultiplier = 0.4 },
		Modifiers = {},
		Drops = { { ItemId = "CrystalShard", Count = 1, Chance = 0.2 } },
		DropInterval = 15,
		ClientHints = { Icon = "VoidSurge", Color = { 160, 80, 255 } },
		EndOnBiomeChange = true,
	},

	----------------------------------------------------------------
	-- MAJOR EVENTS
	----------------------------------------------------------------

	MonsterSiege = {
		Type = "Major",
		MinElapsed = 30 * 60,
		Duration = { min = 90, max = 140 },
		Effects = { EnemyMultiplier = 0.6 },
		Modifiers = {},
		Drops = {},
		DropInterval = 0,
		ClientHints = { Icon = "MonsterSiege", Color = { 200, 50, 50 } },
		EndOnBiomeChange = false,
	},

	WormholeRift = {
		Type = "Major",
		MinElapsed = 45 * 60,
		Duration = { min = 90, max = 130 },
		Effects = { ResourceMultiplier = 0.5 },
		Modifiers = {},
		Drops = {},
		DropInterval = 0,
		ClientHints = { Icon = "WormholeRift", Color = { 140, 60, 220 } },
		EndOnBiomeChange = false,
	},

	BiomeQuake = {
		Type = "Major",
		MinElapsed = 30 * 60,
		Duration = { min = 90, max = 140 },
		Effects = {},
		Modifiers = {},
		Drops = {},
		DropInterval = 0,
		ClientHints = { Icon = "BiomeQuake", Color = { 180, 120, 60 } },
		EndOnBiomeChange = false,
	},
}

-------------------------------------------------------------------------
-- BIOME POOLS
-- Each entry: { Id = "EventName", Weight = number, Overrides = { ... } }
-- Overrides deep-merge onto the base Definition when the event fires.
-- "Global" pool is always included; biome pools add to / override it.
-- If a biome entry has the same Id as a Global entry, the biome entry wins.
-------------------------------------------------------------------------
EventsConfig.BiomePools = {

	Global = {
		Minor = {
			{ Id = "MeteorShower", Weight = 1.0 },
			{ Id = "ResourceBoom", Weight = 1.0 },
		},
		Major = {
			{ Id = "MonsterSiege", Weight = 1.0 },
			{ Id = "WormholeRift", Weight = 0.7 },
			{ Id = "BiomeQuake", Weight = 0.5 },
		},
	},

	Forest = {
		Minor = {
			{ Id = "ToxicFog", Weight = 1.0 },
			{ Id = "MonsoonFlood", Weight = 0.8 },
			{ Id = "ResourceBoom", Weight = 1.2, Overrides = {
				Effects = { ResourceMultiplier = 1.0 },
			}},
		},
		Major = {},
	},

	Desert = {
		Minor = {
			{ Id = "Sandstorm", Weight = 1.2 },
			{ Id = "SolarFlare", Weight = 0.8 },
			{ Id = "BuriedTreasure", Weight = 0.6 },
			{ Id = "ScorpionSwarm", Weight = 1.0 },
			{ Id = "OasisMirage", Weight = 0.5 },
			{ Id = "SulfurVent", Weight = 0.7 },
			{ Id = "DustDevil", Weight = 0.9 },
			{ Id = "MeteorShower", Weight = 0.5, Overrides = {
				Drops = { { ItemId = "Coal", Count = 1, Chance = 0.3 } },
			}},
		},
		Major = {
			{ Id = "SandWurmRise", Weight = 1.3 },
			{ Id = "MonsterSiege", Weight = 1.0, Overrides = {
				Effects = { EnemyMultiplier = 0.8 },
			}},
		},
	},

	Swamp = {
		Minor = {
			{ Id = "ToxicFog", Weight = 1.5 },
			{ Id = "MiasmaBurst", Weight = 1.0 },
			{ Id = "MonsoonFlood", Weight = 1.0, Overrides = {
				Modifiers = { Wet = 2 },
			}},
		},
		Major = {},
	},

	FrozenTundra = {
		Minor = {
			{ Id = "Blizzard", Weight = 1.3 },
			{ Id = "ResourceBoom", Weight = 0.5, Overrides = {
				Effects = { ResourceMultiplier = 0.4 },
			}},
		},
		Major = {},
	},

	Volcanic = {
		Minor = {
			{ Id = "LavaFlow", Weight = 1.2 },
			{ Id = "MeteorShower", Weight = 1.0, Overrides = {
				Effects = { EnemyMultiplier = 0.4 },
				Drops = { { ItemId = "ObsidianShard", Count = 1, Chance = 0.15 } },
			}},
		},
		Major = {
			{ Id = "BiomeQuake", Weight = 1.5 },
		},
	},

	CrystalWastes = {
		Minor = {
			{ Id = "VoidSurge", Weight = 1.3 },
			{ Id = "ResourceBoom", Weight = 0.6, Overrides = {
				Drops = { { ItemId = "CrystalShard", Count = 1, Chance = 0.2 } },
			}},
		},
		Major = {
			{ Id = "WormholeRift", Weight = 1.5 },
		},
	},
}

-------------------------------------------------------------------------
-- CADENCE  (timing between events)
-------------------------------------------------------------------------
EventsConfig.Cadence = {
	MinorCadence = { 180, 300 },
	MajorCadence = { 420, 540 },
	MaxConcurrentMinor = 1,
	MaxConcurrentMajor = 1,
}

return EventsConfig
