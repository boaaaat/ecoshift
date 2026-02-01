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
			MaxGroupsPerRegion = nil,
			MaxCountPerRegion = nil,
			Biomes = {
				Forest = {
					Weight = 1.0,
					Regions = {
						ThickGrove = 2.5,
						ForestClearing = 1.0,
					},
				},
			},
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
		ForestCommon = {
			{ Id = "Wolf", Weight = 1.0, DistanceWeight = { Min = 1.0, Max = 1.5 } },
		},
	},
}

EntityConfig.SpawnPoints = {
	Count = 24,
	MinRadiusPadding = 60,
	MaxRadiusPadding = 80,
}

return EntityConfig
