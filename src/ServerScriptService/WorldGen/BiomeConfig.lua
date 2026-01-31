local Config = {}

Config.seed = 12345
Config.world_radius = 2200
Config.center_exclusion_radius = 260
Config.base_y = 0
Config.chunk_size = 240
Config.biome_noise_scale = 0.0016
Config.time_scale_seconds = 900
Config.ops_per_yield = 40
Config.step_delay = 0
Config.region_padding = 8
Config.structure_padding = 6
Config.objective_padding = 6
Config.avoid_regions_for_structures = true
Config.spawn_folder_name = "GeneratedWorld"

Config.biomes = {
	Forest = {
		weight = 1.0,
		timeScaledWeight = -0.3,
		region_count = { min = 1, max = 2 },
		regions = {
			{
				name = "ForestClearing",
				size = Vector2.new(220, 220),
				resources = { "Tree", "Rock" },
				resource_count = { min = 16, max = 28 },
				props = { "Bush", "Flower" },
				prop_count = { min = 10, max = 18 },
				enemies = { "Slime" },
				enemy_count = { min = 0, max = 2 },
			},
			{
				name = "ThickGrove",
				size = Vector2.new(260, 200),
				resources = { "Tree", "Rock" },
				resource_count = { min = 22, max = 36 },
				props = { "Mushroom", "Bush" },
				prop_count = { min = 8, max = 14 },
				enemies = { "Slime" },
				enemy_count = { min = 0, max = 2 },
			},
		},
		structures = { "Cabin", "Watchtower" },
		structure_count = { min = 0, max = 1 },
		objectives = { "AncientTotem" },
		objective_count = { min = 0, max = 1 },
	},
	Desert = {
		weight = 0.7,
		timeScaledWeight = -0.15,
		region_count = { min = 1, max = 2 },
		regions = {
			{
				name = "Dunes",
				size = Vector2.new(240, 240),
				resources = { "Cactus", "Stone" },
				resource_count = { min = 10, max = 18 },
				props = { "Bone", "Shrub" },
				prop_count = { min = 6, max = 12 },
				enemies = { "Scorpion" },
				enemy_count = { min = 0, max = 2 },
			},
		},
		structures = { "Ruins", "Outpost" },
		structure_count = { min = 0, max = 1 },
		objectives = { "DesertObelisk" },
		objective_count = { min = 0, max = 1 },
	},
	FrozenTundra = {
		weight = 0.35,
		timeScaledWeight = 0.45,
		region_count = { min = 1, max = 2 },
		regions = {
			{
				name = "FrozenField",
				size = Vector2.new(230, 230),
				resources = { "IceCrystal", "Stone" },
				resource_count = { min = 12, max = 20 },
				props = { "IceShard" },
				prop_count = { min = 6, max = 12 },
				enemies = { "FrostSpirit" },
				enemy_count = { min = 0, max = 2 },
			},
		},
		structures = { "FrozenCamp" },
		structure_count = { min = 0, max = 1 },
		objectives = { "IceCore" },
		objective_count = { min = 0, max = 1 },
	},
	Swamp = {
		weight = 0.5,
		timeScaledWeight = 0.2,
		region_count = { min = 1, max = 2 },
		regions = {
			{
				name = "Bog",
				size = Vector2.new(230, 230),
				resources = { "Reed", "Mushroom" },
				resource_count = { min = 12, max = 20 },
				props = { "Stump", "Vine" },
				prop_count = { min = 6, max = 12 },
				enemies = { "SwarmLeech" },
				enemy_count = { min = 0, max = 2 },
			},
		},
		structures = { "SwampHut" },
		structure_count = { min = 0, max = 1 },
		objectives = { "SwampRelic" },
		objective_count = { min = 0, max = 1 },
	},
	Volcanic = {
		weight = 0.3,
		timeScaledWeight = 0.4,
		region_count = { min = 1, max = 2 },
		regions = {
			{
				name = "LavaField",
				size = Vector2.new(240, 220),
				resources = { "Obsidian", "Sulfur" },
				resource_count = { min = 10, max = 18 },
				props = { "Basalt", "Ash" },
				prop_count = { min = 6, max = 12 },
				enemies = { "MagmaHound" },
				enemy_count = { min = 0, max = 2 },
			},
		},
		structures = { "LavaForge" },
		structure_count = { min = 0, max = 1 },
		objectives = { "VolcanicCore" },
		objective_count = { min = 0, max = 1 },
	},
	CrystalWastes = {
		weight = 0.25,
		timeScaledWeight = 0.5,
		region_count = { min = 1, max = 2 },
		regions = {
			{
				name = "CrystalField",
				size = Vector2.new(230, 230),
				resources = { "CrystalShard", "VoidQuartz" },
				resource_count = { min = 10, max = 18 },
				props = { "Prism", "Spire" },
				prop_count = { min = 6, max = 12 },
				enemies = { "Shardling" },
				enemy_count = { min = 0, max = 2 },
			},
		},
		structures = { "CrystalAltar" },
		structure_count = { min = 0, max = 1 },
		objectives = { "PrismCore" },
		objective_count = { min = 0, max = 1 },
	},
}

return Config
