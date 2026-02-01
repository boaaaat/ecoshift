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
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
	},
	Animal = {
		DetectionAngle = 90,
		DetectionDistance = 45,
		AutoDetectRadius = 8,
		Speed = 12,
		UsePathfinding = true,
		RepathInterval = 1.5,
		WanderRadius = 35,
		WanderInterval = 3.0,
		FleeDistance = 25,
		FleeSpeed = 16,
		PlayerPriority = "Closest",
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
			Damage = 10,
			Speed = 14,
			AttackRange = 5,
			AttackCooldown = 1.1,
			DetectionDistance = 110,
			PlayerPriority = "LowHealth",
			PackRadius = 30,
			PackSpeedBoost = 0.1,
			PackAttackBoost = 0.12,
			WanderRadius = 25,
			WanderInterval = 2.5,
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
	MaxCount = 24,
	PlayerScale = 1.0,
	Tables = {
		ForestCommon = {
			{ Id = "Wolf", Weight = 1.0 },
		},
	},
}

return EntityConfig
