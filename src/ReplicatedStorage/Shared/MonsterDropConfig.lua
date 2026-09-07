local MonsterDropConfig = {}

MonsterDropConfig.Monsters = {
	AuroraStag = {
		Boss = false,
		Drops = {
			{ ItemId = "AuroraAntler", Min = 1, Max = 2, Chance = 1.0 },
			{ ItemId = "DawnBloom", Min = 1, Max = 1, Chance = 0.4 },
		},
		CraftUnlocks = { "AuroraMantle", "AuroraLens" },
	},
	CometCrawler = {
		Boss = false,
		Drops = {
			{ ItemId = "MeteorCore", Min = 1, Max = 1, Chance = 1.0 },
			{ ItemId = "MeteorIron", Min = 1, Max = 2, Chance = 0.5 },
		},
		CraftUnlocks = { "MeteorPike", "StarforgedPlate", "BiomeSelector" },
	},
	Wolf = {
		Boss = false,
		Drops = {
			{ ItemId = "WolfPelt", Min = 1, Max = 2, Chance = 1.0 },
			{ ItemId = "WolfFang", Min = 1, Max = 1, Chance = 0.6 },
		},
		CraftUnlocks = { "Bandage", "StoneHatchet", "StonePickaxe", "ResourceCompass" },
	},
	Scorpion = {
		Boss = false,
		Drops = {
			{ ItemId = "ScorpionStinger", Min = 1, Max = 2, Chance = 1.0 },
			{ ItemId = "CactusStem", Min = 1, Max = 2, Chance = 0.4 },
		},
		CraftUnlocks = { "SanditeBlade", "ToxinFilter", "AntitoxinTonic" },
	},
	SandSerpent = {
		Boss = false,
		Drops = {
			{ ItemId = "SerpentScale", Min = 1, Max = 2, Chance = 1.0 },
			{ ItemId = "SunShard", Min = 1, Max = 1, Chance = 0.25 },
		},
		CraftUnlocks = { "SanditeBlade", "SanditePickaxe", "ThreatMeter" },
	},
	GiantLeech = {
		Boss = false,
		Drops = {
			{ ItemId = "LeechVenomSac", Min = 1, Max = 2, Chance = 1.0 },
			{ ItemId = "BogReed", Min = 1, Max = 2, Chance = 0.4 },
		},
		CraftUnlocks = { "MireDagger", "BioGel", "AntitoxinPaste" },
	},
	BogToad = {
		Boss = false,
		Drops = {
			{ ItemId = "BogToadGland", Min = 1, Max = 2, Chance = 1.0 },
			{ ItemId = "Glowcap", Min = 1, Max = 2, Chance = 0.5 },
		},
		CraftUnlocks = { "AntitoxinPaste", "AntitoxinTonic", "SwampWaders" },
	},
	FrostWolf = {
		Boss = false,
		Drops = {
			{ ItemId = "FrostWolfFur", Min = 1, Max = 2, Chance = 1.0 },
			{ ItemId = "IceCrystal", Min = 1, Max = 2, Chance = 0.35 },
		},
		CraftUnlocks = { "FrostParka", "InsulatedCloth", "ReinforcedRation" },
	},
	IceWraith = {
		Boss = false,
		Drops = {
			{ ItemId = "WraithEssence", Min = 1, Max = 1, Chance = 1.0 },
			{ ItemId = "SnowLichen", Min = 1, Max = 2, Chance = 0.45 },
		},
		CraftUnlocks = { "HoarfrostPowder", "ColdTonic", "CryoAlloy" },
	},
	MagmaHound = {
		Boss = false,
		Drops = {
			{ ItemId = "HoundFang", Min = 1, Max = 1, Chance = 1.0 },
			{ ItemId = "EmberBloom", Min = 1, Max = 2, Chance = 0.5 },
		},
		CraftUnlocks = { "ObsidianAxe", "VulcanLeather", "HeatTonic" },
	},
	LavaGolem = {
		Boss = true,
		Drops = {
			{ ItemId = "MagmaCore", Min = 1, Max = 1, Chance = 1.0 },
			{ ItemId = "GolemFragment", Min = 1, Max = 2, Chance = 1.0 },
			{ ItemId = "ObsidianShard", Min = 2, Max = 4, Chance = 0.7 },
		},
		CraftUnlocks = { "MagmaHammer", "VolcanicPlate", "Refinery" },
	},
	CrystalStalker = {
		Boss = false,
		Drops = {
			{ ItemId = "StalkerTalon", Min = 1, Max = 1, Chance = 1.0 },
			{ ItemId = "CrystalShard", Min = 1, Max = 2, Chance = 0.5 },
		},
		CraftUnlocks = { "CrystalBow", "PhaseCircuit", "PrismGlass" },
	},
	VoidSentinel = {
		Boss = true,
		Drops = {
			{ ItemId = "SentinelCore", Min = 1, Max = 1, Chance = 1.0 },
			{ ItemId = "NullFragment", Min = 1, Max = 2, Chance = 1.0 },
			{ ItemId = "PhaseQuartz", Min = 1, Max = 2, Chance = 0.5 },
		},
		CraftUnlocks = { "VoidEdge", "WeatherPredictor", "AdaptiveSurvivalSuit" },
	},
}

return MonsterDropConfig
