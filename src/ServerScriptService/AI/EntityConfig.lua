-- EntityConfig.lua
-- Central configuration for all AI entities (monsters + animals).
local EntityConfig = {}

EntityConfig.StepInterval = 0.2

-- Weight multipliers by entity type (applied during world generation spawns)
EntityConfig.TypeWeights = {
	Monster = 1.0,
	Animal = 0.6,
}

-- Default AI tuning
EntityConfig.Defaults = {
	Monster = {
		DetectionAngle = 120,
		DetectionDistance = 90,
		AutoDetectRadius = 10,
		Damage = 8,
		Speed = 12,
		AttackRange = 4,
		AttackCooldown = 1.2,
		PlayerPriority = "LowHealth",
		UsePathfinding = true,
		RepathInterval = 1.0,
		RepathDistance = 10,
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		StuckMinMove = 0.08,
		StuckJumpTime = 0.1,
	},
	Animal = {
		DetectionAngle = 90,
		DetectionDistance = 45,
		AutoDetectRadius = 8,
		Speed = 12,
		UsePathfinding = true,
		RepathInterval = 1.5,
		RepathDistance = 12,
		WanderRadius = 35,
		WanderInterval = 3.0,
		FleeDistance = 25,
		FleeSpeed = 16,
		PlayerPriority = "Closest",
		StuckMinMove = 0.08,
		StuckJumpTime = 0.1,
	},
}

-- Entity definitions
-- Spawn features:
--   Weight / TimeScaledWeight: base + time-based scaling.
--   Biomes[BiomeName].Weight: biome weight multiplier.
--   Biomes[BiomeName].Regions[RegionName]: region weight multiplier.
--   GroupSize: number spawned per group.
--   GroupRadius: cluster radius for group members.
--   MaxGroupsPerRegion / MaxCountPerRegion: optional caps per region.
EntityConfig.Entities = {
	-- FOREST ENEMIES
	Wolf = {
		Type = "Monster",
		AIClass = "Wolf",
		AI = {
			Damage = 14,
			Speed = 16,
			AttackRange = 6,
			AttackCooldown = 0.8,
			DetectionAngle = 150,
			DetectionDistance = 140,
			AutoDetectRadius = 20,
			PlayerPriority = "Closest",
			RepathInterval = 1.4,
			RepathDistance = 14,
			PackRadius = 40,
			PackSpeedBoost = 0.2,
			PackAttackBoost = 0.2,
			WanderRadius = 20,
			WanderInterval = 1.5,
		},
		Spawn = {
			Weight = 1.0,
			TimeScaledWeight = 0.0,
			GroupSize = { min = 2, max = 4 },
			GroupRadius = 8,
			Biomes = { Forest = { Weight = 1.0 } },
		},
	},

	-- DESERT ENEMIES
	Scorpion = {
		Type = "Monster",
		AIClass = "Wolf", -- Uses wolf AI (aggressive melee)
		AI = {
			Damage = 12,
			Speed = 18, -- Fast
			AttackRange = 5,
			AttackCooldown = 1.0,
			DetectionAngle = 180,
			DetectionDistance = 100,
			AutoDetectRadius = 15,
			PlayerPriority = "Closest",
			RepathInterval = 1.2,
			WanderRadius = 25,
			WanderInterval = 2.0,
		},
		Spawn = {
			Weight = 1.0,
			GroupSize = { min = 1, max = 3 },
			GroupRadius = 6,
			Biomes = { Desert = { Weight = 1.0 } },
		},
	},
	SandSerpent = {
		Type = "Monster",
		AIClass = "Wolf",
		AI = {
			Damage = 20,
			Speed = 14,
			AttackRange = 7,
			AttackCooldown = 1.5,
			DetectionAngle = 120,
			DetectionDistance = 80,
			AutoDetectRadius = 12,
			PlayerPriority = "Closest",
			RepathInterval = 1.5,
			WanderRadius = 30,
			WanderInterval = 3.0,
		},
		Spawn = {
			Weight = 0.6, -- Rarer
			GroupSize = { min = 1, max = 2 },
			GroupRadius = 10,
			Biomes = { Desert = { Weight = 1.0 } },
		},
	},

	-- SWAMP ENEMIES
	GiantLeech = {
		Type = "Monster",
		AIClass = "Wolf",
		AI = {
			Damage = 8,
			Speed = 10, -- Slow
			AttackRange = 4,
			AttackCooldown = 0.8, -- Fast attacks, low damage
			DetectionAngle = 360,
			DetectionDistance = 60,
			AutoDetectRadius = 10,
			PlayerPriority = "Closest",
			RepathInterval = 1.5,
			WanderRadius = 15,
			WanderInterval = 2.5,
		},
		Spawn = {
			Weight = 1.0,
			GroupSize = { min = 2, max = 5 },
			GroupRadius = 8,
			Biomes = { Swamp = { Weight = 1.0 } },
		},
	},
	BogToad = {
		Type = "Monster",
		AIClass = "Wolf",
		AI = {
			Damage = 15,
			Speed = 12,
			AttackRange = 6, -- Ranged tongue attack
			AttackCooldown = 1.8,
			DetectionAngle = 140,
			DetectionDistance = 90,
			AutoDetectRadius = 15,
			PlayerPriority = "Closest",
			RepathInterval = 1.3,
			WanderRadius = 20,
			WanderInterval = 2.0,
		},
		Spawn = {
			Weight = 0.7,
			GroupSize = { min = 1, max = 2 },
			GroupRadius = 10,
			Biomes = { Swamp = { Weight = 1.0 } },
		},
	},

	-- TUNDRA ENEMIES
	FrostWolf = {
		Type = "Monster",
		AIClass = "Wolf",
		AI = {
			Damage = 18, -- Stronger than regular wolf
			Speed = 17,
			AttackRange = 6,
			AttackCooldown = 0.9,
			DetectionAngle = 150,
			DetectionDistance = 150,
			AutoDetectRadius = 25,
			PlayerPriority = "Closest",
			PackRadius = 50,
			PackSpeedBoost = 0.25,
			PackAttackBoost = 0.25,
			WanderRadius = 25,
			WanderInterval = 1.5,
		},
		Spawn = {
			Weight = 1.0,
			GroupSize = { min = 3, max = 5 }, -- Larger packs
			GroupRadius = 10,
			Biomes = { FrozenTundra = { Weight = 1.0 } },
		},
	},
	IceWraith = {
		Type = "Monster",
		AIClass = "Wolf",
		AI = {
			Damage = 22,
			Speed = 20, -- Very fast, ghostly
			AttackRange = 5,
			AttackCooldown = 1.5,
			DetectionAngle = 360,
			DetectionDistance = 120,
			AutoDetectRadius = 30,
			PlayerPriority = "Closest",
			RepathInterval = 0.8, -- Erratic movement
			WanderRadius = 40,
			WanderInterval = 1.0,
		},
		Spawn = {
			Weight = 0.5, -- Rare
			GroupSize = { min = 1, max = 2 },
			GroupRadius = 15,
			Biomes = { FrozenTundra = { Weight = 1.0 } },
		},
	},

	-- VOLCANIC ENEMIES
	MagmaHound = {
		Type = "Monster",
		AIClass = "Wolf",
		AI = {
			Damage = 25,
			Speed = 15,
			AttackRange = 6,
			AttackCooldown = 1.0,
			DetectionAngle = 150,
			DetectionDistance = 130,
			AutoDetectRadius = 20,
			PlayerPriority = "LowHealth",
			PackRadius = 35,
			PackSpeedBoost = 0.15,
			PackAttackBoost = 0.3,
			WanderRadius = 20,
			WanderInterval = 2.0,
		},
		Spawn = {
			Weight = 1.0,
			GroupSize = { min = 2, max = 3 },
			GroupRadius = 8,
			Biomes = { Volcanic = { Weight = 1.0 } },
		},
	},
	LavaGolem = {
		Type = "Monster",
		AIClass = "Wolf",
		AI = {
			Damage = 40, -- Heavy hitter
			Speed = 8, -- Very slow
			AttackRange = 8,
			AttackCooldown = 2.5,
			DetectionAngle = 120,
			DetectionDistance = 80,
			AutoDetectRadius = 15,
			PlayerPriority = "Closest",
			RepathInterval = 2.0,
			WanderRadius = 15,
			WanderInterval = 4.0,
		},
		Spawn = {
			Weight = 0.4, -- Rare
			GroupSize = { min = 1, max = 1 }, -- Always solo
			GroupRadius = 0,
			Biomes = { Volcanic = { Weight = 1.0 } },
		},
	},

	-- CRYSTAL WASTES ENEMIES
	CrystalStalker = {
		Type = "Monster",
		AIClass = "Wolf",
		AI = {
			Damage = 30,
			Speed = 22, -- Very fast
			AttackRange = 5,
			AttackCooldown = 0.7,
			DetectionAngle = 180,
			DetectionDistance = 160,
			AutoDetectRadius = 35,
			PlayerPriority = "LowHealth",
			RepathInterval = 0.6, -- Erratic, teleport-like
			WanderRadius = 50,
			WanderInterval = 0.8,
		},
		Spawn = {
			Weight = 1.0,
			GroupSize = { min = 1, max = 3 },
			GroupRadius = 12,
			Biomes = { CrystalWastes = { Weight = 1.0 } },
		},
	},
	VoidSentinel = {
		Type = "Monster",
		AIClass = "Wolf",
		AI = {
			Damage = 60, -- Boss-level damage
			Speed = 10,
			AttackRange = 10,
			AttackCooldown = 2.0,
			DetectionAngle = 360,
			DetectionDistance = 200,
			AutoDetectRadius = 50,
			PlayerPriority = "LowHealth",
			RepathInterval = 1.5,
			WanderRadius = 30,
			WanderInterval = 5.0,
		},
		Spawn = {
			Weight = 0.2, -- Very rare boss
			GroupSize = { min = 1, max = 1 },
			GroupRadius = 0,
			Biomes = { CrystalWastes = { Weight = 1.0 } },
		},
	},
}

-- Enemy wave configuration (used by SpawnService)
EntityConfig.EnemyWaves = {
	BaseCount = 2,
	MinCount = 1,
	MaxCount = 24,
	PlayerScale = 1.0,
	PeriodSeconds = 24,
	DistanceSample = "Max", -- Max | Average | Min
	Distance = {
		MinRadius = 0,
		MaxRadius = 2200,
		Exponent = 1.0,
		WeightMultMin = 1.0,
		WeightMultMax = 1.35,
		CountMultMin = 1.0,
		CountMultMax = 1.5,
	},
	Tables = {
		-- Forest enemies
		ForestCommon = {
			{ Id = "Wolf", Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 1.5 } },
		},
		-- Desert enemies
		DesertCommon = {
			{ Id = "Scorpion", Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 1.5 } },
			{ Id = "SandSerpent", Weight = 0.6, DistanceWeight = { Min = 0.8, Max = 1.8 } },
		},
		-- Swamp enemies
		SwampCommon = {
			{ Id = "GiantLeech", Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 1.3 } },
			{ Id = "BogToad", Weight = 0.7, DistanceWeight = { Min = 0.8, Max = 1.5 } },
		},
		-- Tundra enemies
		TundraCommon = {
			{ Id = "FrostWolf", Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 1.5 } },
			{ Id = "IceWraith", Weight = 0.5, DistanceWeight = { Min = 0.6, Max = 2.0 } },
		},
		-- Volcanic enemies
		VolcanicCommon = {
			{ Id = "MagmaHound", Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 1.4 } },
			{ Id = "LavaGolem", Weight = 0.4, DistanceWeight = { Min = 0.5, Max = 1.5 } },
		},
		-- Crystal Wastes enemies
		CrystalCommon = {
			{ Id = "CrystalStalker", Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 1.6 } },
			{ Id = "VoidSentinel", Weight = 0.2, DistanceWeight = { Min = 0.3, Max = 1.0 } },
		},
	},
}

EntityConfig.SpawnPoints = {
	Count = 24,
	MinRadiusPadding = 60,
	MaxRadiusPadding = 80,
}

return EntityConfig
