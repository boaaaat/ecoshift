-- Config.lua
-- Central game tuning values. Edit freely.

local Config = {}

Config.Paths = {
	Remotes = "ReplicatedStorage/Remotes",
	EnemySpawnsFolder = "Workspace/EnemySpawns",
	ObjectivesFolder = "Workspace/Objectives",
}

Config.RemoteNames = {
	Build = "Build",
	Damage = "Damage",
	CombatAction = "CombatAction",
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
	WorldControl = "WorldControl",
	DropItem = "DropItem",
	ChestEvent = "ChestEvent",
	TimeUpdate = "TimeUpdate",
	HarvestFeedback = "HarvestFeedback",
	SprintToggle = "SprintToggle",
}

Config.DATASTORE = {
	ProfileStore = "EcoshiftProfile_v1",
	AutosaveInterval = 60,
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
	DropSpread = 4,
	DropHeight = 2,
	TierWeightMult = {
		[1] = 1.0,
		[2] = 1.35,
		[3] = 1.75,
		[4] = 2.2,
	},
}

local Classes = require(script.Parent.ClassConfig)
Config.ROLES = { Default = "Generalist", Definitions = {} }
for id, definition in pairs(Classes.Definitions) do
 Config.ROLES.Definitions[id] = {Name=definition.Name, Gather=1, Build=1, Combat=1, Heal=1, Craft=1}
end

Config.THREAT = {
	Clamp = { 0, 10 },
	BasePerMinute = 0.35,
	BossKill = 2.5,
	FailedObjective = 1.5,
}

-- Event cadence values consumed by EventService.
Config.EVENTS = {
	MinorCadence = { 180, 300 },
	MajorCadence = { 420, 540 },
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

-- NOTE: Biome configuration moved to ReplicatedStorage/Shared/BiomeConfig.lua

Config.BUILD = {
	CampRadius = 100, -- 200-stud diameter around the expedition spawn at X/Z zero.
	AllowedTypes = {
		Wall = true,
		Floor = true,
		Ramp = true,
		Gate = true,
		Tower = true,
		Trap = true,
		Machine = true,
		-- Crafting Stations (placeable from inventory)
		Workbench = true,
		AdvancedWorkbench = true,
		MasterWorkbench = true,
		Furnace = true,
		Anvil = true,
		Loom = true,
		DryingRack = true,
		AlchemyTable = true,
		Kiln = true,
		Refinery = true,
		SurveyBench = true,
		Campfire = true,
		Chest = true,
		Torch = true,
	},
	Costs = {
		Wall = { { Id = "ForestWood", N = 2 } },
		Floor = { { Id = "ForestWood", N = 2 } },
		Ramp = { { Id = "ForestWood", N = 3 } },
		Gate = { { Id = "ForestWood", N = 4 }, { Id = "ForestStone", N = 2 } },
		Tower = { { Id = "ForestWood", N = 6 }, { Id = "ForestStone", N = 4 } },
		Trap = { { Id = "ForestStone", N = 2 } },
		Machine = { { Id = "ForestStone", N = 6 } },
		-- Crafting stations are placed from inventory items, no direct cost
		-- (player must craft the item first, then place it)
	},
	-- Items that can be placed as structures (consume the item when placed)
	PlaceableItems = {
		Workbench = true,
		AdvancedWorkbench = true,
		MasterWorkbench = true,
		Furnace = true,
		Anvil = true,
		Loom = true,
		DryingRack = true,
		AlchemyTable = true,
		Kiln = true,
		Refinery = true,
		SurveyBench = true,
		Campfire = true,
		Chest = true,
		Torch = true,
	},
}

Config.UI = Config.UI or {}
Config.UI.UpdateInterval = 0.25

return Config
