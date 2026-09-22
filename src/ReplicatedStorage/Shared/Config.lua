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
	BowEffect = "BowEffect",
	Interact = "Interact",
	EventBroadcast = "EventBroadcast",
	ObjectiveUpdate = "ObjectiveUpdate",
	BiomeChanged = "BiomeChanged",
	Craft = "Craft",
	Cooking = "Cooking",
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
	ProfileStore = "EcoshiftProfile_Overhaul_20260912",
	AutosaveInterval = 60,
}

Config.GRID = {
	Size = 8,
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

-- CampaignConfig and EventsConfig own progression and event cadence.

Config.BUILD = {SalvageSeconds=3,SalvageMaxDistance=15,CampRadius=200,AllowedTypes={},PlaceableItems={},Costs={}}
local Catalog=require(script.Parent.OverhaulCatalog)
for id in pairs(Catalog.Placeables) do Config.BUILD.AllowedTypes[id]=true;Config.BUILD.PlaceableItems[id]=true end

Config.UI = Config.UI or {}
Config.UI.UpdateInterval = 0.25

return Config
