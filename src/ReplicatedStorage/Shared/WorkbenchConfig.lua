-- WorkbenchConfig.lua
-- Defines crafting stations, recipes, and station-specialized crafting modifiers.

local WorkbenchConfig = {}

WorkbenchConfig.STATION_TIERS = {
	Hand = 0,
	Workbench = 1,
	AdvancedWorkbench = 2,
	MasterWorkbench = 3,
	Furnace = 10,
	Anvil = 11,
	Loom = 12,
	DryingRack = 13,
	AlchemyTable = 14,
	Kiln = 15,
	Refinery = 16,
	SurveyBench = 17,
}

WorkbenchConfig.STATIONS = {
	Hand = {
		Tier = 0,
		Name = "Hand Crafting",
		Description = "Basic field crafting",
		MaxRecipeComplexity = 2,
		Icon = "🤲",
	},
	Workbench = {
		Tier = 1,
		Name = "Workbench",
		Description = "Craft baseline tools and stations",
		MaxRecipeComplexity = 4,
		Icon = "🔨",
		BuildType = "Workbench",
		InteractRadius = 8,
	},
	AdvancedWorkbench = {
		Tier = 2,
		Name = "Advanced Workbench",
		Description = "Precision assembly for complex equipment",
		MaxRecipeComplexity = 6,
		Icon = "⚙",
		BuildType = "AdvancedWorkbench",
		InteractRadius = 8,
	},
	MasterWorkbench = {
		Tier = 3,
		Name = "Master Workbench",
		Description = "Top-tier fabrication",
		MaxRecipeComplexity = 9,
		Icon = "⭐",
		BuildType = "MasterWorkbench",
		InteractRadius = 8,
	},
	Furnace = {
		Tier = 10,
		Name = "Furnace",
		Description = "Smelt ores and heat-process materials",
		MaxRecipeComplexity = 3,
		Icon = "🔥",
		BuildType = "Furnace",
		InteractRadius = 6,
	},
	Anvil = {
		Tier = 11,
		Name = "Anvil",
		Description = "Forge hardened tools, weapons, and armor",
		MaxRecipeComplexity = 4,
		Icon = "🛠",
		BuildType = "Anvil",
		InteractRadius = 6,
	},
	Loom = {
		Tier = 12,
		Name = "Loom",
		Description = "Weave textiles and tailored armor",
		MaxRecipeComplexity = 4,
		Icon = "🧵",
		BuildType = "Loom",
		InteractRadius = 6,
	},
	DryingRack = {
		Tier = 13,
		Name = "Drying Rack",
		Description = "Efficiently dry and preserve food/fiber/leather",
		MaxRecipeComplexity = 4,
		Icon = "🌬",
		BuildType = "DryingRack",
		InteractRadius = 6,
	},
	AlchemyTable = {
		Tier = 14,
		Name = "Alchemy Table",
		Description = "Compound tonics, filters, gels, and medicinal mixes",
		MaxRecipeComplexity = 5,
		Icon = "⚗",
		BuildType = "AlchemyTable",
		InteractRadius = 6,
	},
	Kiln = {
		Tier = 15,
		Name = "Kiln",
		Description = "High-temperature stone/glass/ceramic processing",
		MaxRecipeComplexity = 4,
		Icon = "🏺",
		BuildType = "Kiln",
		InteractRadius = 6,
	},
	Refinery = {
		Tier = 16,
		Name = "Refinery",
		Description = "High-yield alloy and circuit refining",
		MaxRecipeComplexity = 6,
		Icon = "🏭",
		BuildType = "Refinery",
		InteractRadius = 6,
	},
	SurveyBench = {
		Tier = 17,
		Name = "Survey Bench",
		Description = "Build strategic intel devices",
		MaxRecipeComplexity = 6,
		Icon = "🧭",
		BuildType = "SurveyBench",
		InteractRadius = 8,
	},
}

WorkbenchConfig.STATION_GLOBAL_MODIFIERS = {
	DryingRack = {
		TimeMult = 0.65,
		ProcessKinds = { Food = true, Fiber = true, Leather = true },
	},
	Kiln = {
		TimeMult = 0.60,
		ProcessKinds = { Heat = true, Glass = true, Stone = true, Clay = true },
	},
	AlchemyTable = {
		TimeMult = 0.70,
		ProcessKinds = {
			Paste = true,
			Tonic = true,
			Filter = true,
			Gel = true,
			Powder = true,
			Medicine = true,
		},
	},
	Refinery = {
		TimeMult = 0.55,
		ExtraYieldChance = 0.10,
		ProcessKinds = { Alloy = true, Circuit = true, Crystal = true },
	},
	AdvancedWorkbench = {
		TimeMult = 0.85,
		Categories = { Tools = true, Weapons = true },
	},
	MasterWorkbench = {
		TimeMult = 0.75,
		Categories = { Tools = true, Weapons = true, Armor = true },
	},
}

WorkbenchConfig.RECIPES = {
	-- Base processed materials
	ForestPlank = {
		Ingredients = { { Id = "ForestWood", N = 1 } },
		Output = { Id = "ForestPlank", N = 2 },
		AllowedStations = { "Hand", "Workbench" },
		Category = "Materials",
		ProcessKind = "Wood",
		BaseCraftTime = 2,
	},
	FiberCloth = {
		Ingredients = { { Id = "ReedFiber", N = 3 } },
		Output = { Id = "FiberCloth", N = 1 },
		AllowedStations = { "Loom", "DryingRack" },
		Category = "Materials",
		ProcessKind = "Fiber",
		BaseCraftTime = 6,
	},
	HerbalPaste = {
		Ingredients = {
			{ Id = "BrownMushroom", N = 2 },
			{ Id = "MossBloom", N = 1 },
		},
		Output = { Id = "HerbalPaste", N = 1 },
		AllowedStations = { "AlchemyTable" },
		Category = "Materials",
		ProcessKind = "Paste",
		BaseCraftTime = 8,
	},
	TanninOil = {
		Ingredients = {
			{ Id = "SapResin", N = 2 },
			{ Id = "WillowBark", N = 1 },
		},
		Output = { Id = "TanninOil", N = 1 },
		AllowedStations = { "AlchemyTable" },
		Category = "Materials",
		ProcessKind = "Paste",
		BaseCraftTime = 8,
	},

	BoneMeal = {
		Ingredients = { { Id = "DriedBone", N = 2 } },
		Output = { Id = "BoneMeal", N = 1 },
		AllowedStations = { "Hand", "Workbench" },
		Category = "Materials",
		ProcessKind = "Stone",
		BaseCraftTime = 3,
	},
	CactusFiber = {
		Ingredients = { { Id = "CactusStem", N = 2 } },
		Output = { Id = "CactusFiber", N = 1 },
		AllowedStations = { "Loom", "DryingRack" },
		Category = "Materials",
		ProcessKind = "Fiber",
		BaseCraftTime = 5,
	},
	SanditeIngot = {
		Ingredients = {
			{ Id = "SulfiteOre", N = 1 },
			{ Id = "Coal", N = 1 },
		},
		Output = { Id = "SanditeIngot", N = 1 },
		AllowedStations = { "Furnace", "Kiln" },
		Category = "Materials",
		ProcessKind = "Heat",
		BaseCraftTime = 7,
	},
	TemperedGlass = {
		Ingredients = {
			{ Id = "Sand", N = 2 },
			{ Id = "SaltCrystal", N = 1 },
		},
		Output = { Id = "TemperedGlass", N = 1 },
		AllowedStations = { "Kiln", "Furnace" },
		Category = "Materials",
		ProcessKind = "Glass",
		BaseCraftTime = 8,
	},
	HeatWrap = {
		Ingredients = {
			{ Id = "CactusFiber", N = 2 },
			{ Id = "TemperedGlass", N = 1 },
		},
		Output = { Id = "HeatWrap", N = 1 },
		AllowedStations = { "Loom", "AlchemyTable" },
		Category = "Materials",
		ProcessKind = "Fiber",
		BaseCraftTime = 8,
	},

	MarshThread = {
		Ingredients = {
			{ Id = "BogReed", N = 2 },
			{ Id = "RootFiber", N = 1 },
		},
		Output = { Id = "MarshThread", N = 1 },
		AllowedStations = { "Loom", "DryingRack" },
		Category = "Materials",
		ProcessKind = "Fiber",
		BaseCraftTime = 6,
	},
	PeatBrick = {
		Ingredients = {
			{ Id = "PeatClump", N = 2 },
			{ Id = "ClayMud", N = 1 },
		},
		Output = { Id = "PeatBrick", N = 1 },
		AllowedStations = { "Kiln", "Furnace" },
		Category = "Materials",
		ProcessKind = "Clay",
		BaseCraftTime = 8,
	},
	AntitoxinPaste = {
		Ingredients = {
			{ Id = "Glowcap", N = 2 },
			{ Id = "BogToadGland", N = 1 },
		},
		Output = { Id = "AntitoxinPaste", N = 1 },
		AllowedStations = { "AlchemyTable" },
		Category = "Materials",
		ProcessKind = "Paste",
		BaseCraftTime = 9,
	},
	BioGel = {
		Ingredients = {
			{ Id = "Glowcap", N = 1 },
			{ Id = "MarshWater", N = 1 },
			{ Id = "LeechVenomSac", N = 1 },
		},
		Output = { Id = "BioGel", N = 1 },
		AllowedStations = { "AlchemyTable" },
		Category = "Materials",
		ProcessKind = "Gel",
		BaseCraftTime = 10,
	},
	MireComposite = {
		Ingredients = {
			{ Id = "MireStone", N = 2 },
			{ Id = "PeatBrick", N = 1 },
			{ Id = "BioGel", N = 1 },
		},
		Output = { Id = "MireComposite", N = 1 },
		AllowedStations = { "AdvancedWorkbench" },
		Category = "Materials",
		ProcessKind = "Composite",
		BaseCraftTime = 12,
	},

	InsulatedCloth = {
		Ingredients = {
			{ Id = "FrozenReed", N = 2 },
			{ Id = "FrostWolfFur", N = 1 },
		},
		Output = { Id = "InsulatedCloth", N = 1 },
		AllowedStations = { "Loom", "DryingRack" },
		Category = "Materials",
		ProcessKind = "Fiber",
		BaseCraftTime = 8,
	},
	CryoAlloy = {
		Ingredients = {
			{ Id = "PermafrostOre", N = 1 },
			{ Id = "Coal", N = 1 },
			{ Id = "IceCrystal", N = 1 },
		},
		Output = { Id = "CryoAlloy", N = 1 },
		AllowedStations = { "Refinery", "Furnace" },
		Category = "Materials",
		ProcessKind = "Alloy",
		BaseCraftTime = 12,
	},
	IceLens = {
		Ingredients = {
			{ Id = "IceCrystal", N = 2 },
			{ Id = "TemperedGlass", N = 1 },
		},
		Output = { Id = "IceLens", N = 1 },
		AllowedStations = { "Kiln", "Refinery" },
		Category = "Materials",
		ProcessKind = "Glass",
		BaseCraftTime = 10,
	},
	HoarfrostPowder = {
		Ingredients = {
			{ Id = "SnowLichen", N = 2 },
			{ Id = "WraithEssence", N = 1 },
		},
		Output = { Id = "HoarfrostPowder", N = 1 },
		AllowedStations = { "AlchemyTable" },
		Category = "Materials",
		ProcessKind = "Powder",
		BaseCraftTime = 9,
	},
	ThermalGel = {
		Ingredients = {
			{ Id = "HoarfrostPowder", N = 1 },
			{ Id = "SpringWater", N = 1 },
			{ Id = "SapResin", N = 1 },
		},
		Output = { Id = "ThermalGel", N = 1 },
		AllowedStations = { "AlchemyTable" },
		Category = "Materials",
		ProcessKind = "Gel",
		BaseCraftTime = 10,
	},

	ObsiditeIngot = {
		Ingredients = {
			{ Id = "ObsidianShard", N = 1 },
			{ Id = "SulfurOre", N = 1 },
			{ Id = "Coal", N = 1 },
		},
		Output = { Id = "ObsiditeIngot", N = 1 },
		AllowedStations = { "Refinery", "Furnace" },
		Category = "Materials",
		ProcessKind = "Alloy",
		BaseCraftTime = 12,
	},
	MagmaGlass = {
		Ingredients = {
			{ Id = "PrismSand", N = 2 },
			{ Id = "ObsidianShard", N = 1 },
		},
		Output = { Id = "MagmaGlass", N = 1 },
		AllowedStations = { "Kiln" },
		Category = "Materials",
		ProcessKind = "Glass",
		BaseCraftTime = 9,
	},
	HeatPlate = {
		Ingredients = {
			{ Id = "BasaltChunk", N = 2 },
			{ Id = "ObsiditeIngot", N = 1 },
		},
		Output = { Id = "HeatPlate", N = 1 },
		AllowedStations = { "Anvil" },
		Category = "Materials",
		ProcessKind = "Heat",
		BaseCraftTime = 11,
	},
	VulcanLeather = {
		Ingredients = {
			{ Id = "AshFiber", N = 2 },
			{ Id = "HoundFang", N = 1 },
			{ Id = "MagmaCore", N = 1 },
		},
		Output = { Id = "VulcanLeather", N = 1 },
		AllowedStations = { "DryingRack", "AlchemyTable" },
		Category = "Materials",
		ProcessKind = "Leather",
		BaseCraftTime = 12,
	},
	IgnitionPowder = {
		Ingredients = {
			{ Id = "SulfurOre", N = 1 },
			{ Id = "Coal", N = 1 },
			{ Id = "ScoriaRock", N = 1 },
		},
		Output = { Id = "IgnitionPowder", N = 1 },
		AllowedStations = { "AlchemyTable" },
		Category = "Materials",
		ProcessKind = "Powder",
		BaseCraftTime = 9,
	},

	ResonantCrystal = {
		Ingredients = {
			{ Id = "CrystalShard", N = 2 },
			{ Id = "PhaseQuartz", N = 1 },
		},
		Output = { Id = "ResonantCrystal", N = 1 },
		AllowedStations = { "Refinery" },
		Category = "Materials",
		ProcessKind = "Crystal",
		BaseCraftTime = 11,
	},
	VoidAlloy = {
		Ingredients = {
			{ Id = "AlloyDust", N = 2 },
			{ Id = "VoidResidue", N = 1 },
			{ Id = "ObsiditeIngot", N = 1 },
		},
		Output = { Id = "VoidAlloy", N = 1 },
		AllowedStations = { "Refinery" },
		Category = "Materials",
		ProcessKind = "Alloy",
		BaseCraftTime = 12,
	},
	PhaseCircuit = {
		Ingredients = {
			{ Id = "ResonantCrystal", N = 1 },
			{ Id = "VoidAlloy", N = 1 },
			{ Id = "EchoBloom", N = 1 },
		},
		Output = { Id = "PhaseCircuit", N = 1 },
		AllowedStations = { "Refinery" },
		Category = "Materials",
		ProcessKind = "Circuit",
		BaseCraftTime = 13,
	},
	PrismGlass = {
		Ingredients = {
			{ Id = "PrismSand", N = 2 },
			{ Id = "CrystalShard", N = 1 },
		},
		Output = { Id = "PrismGlass", N = 1 },
		AllowedStations = { "Kiln" },
		Category = "Materials",
		ProcessKind = "Glass",
		BaseCraftTime = 9,
	},
	QuantumThread = {
		Ingredients = {
			{ Id = "LatticeFiber", N = 2 },
			{ Id = "VoidResidue", N = 1 },
			{ Id = "MarshThread", N = 1 },
		},
		Output = { Id = "QuantumThread", N = 1 },
		AllowedStations = { "Loom", "Refinery" },
		Category = "Materials",
		ProcessKind = "Fiber",
		BaseCraftTime = 11,
	},

	AuroraLens = {
		Ingredients = {
			{ Id = "PolarQuartz", N = 2 },
			{ Id = "IceLens", N = 1 },
			{ Id = "BioGel", N = 1 },
		},
		Output = { Id = "AuroraLens", N = 1 },
		AllowedStations = { "AdvancedWorkbench" },
		Category = "Materials",
		ProcessKind = "Glass",
		BaseCraftTime = 12,
	},
	MeteorAlloy = {
		Ingredients = {
			{ Id = "MeteorIron", N = 2 },
			{ Id = "ObsiditeIngot", N = 1 },
			{ Id = "CryoAlloy", N = 1 },
			{ Id = "CosmicDust", N = 1 },
		},
		Output = { Id = "MeteorAlloy", N = 1 },
		AllowedStations = { "Refinery" },
		Category = "Materials",
		ProcessKind = "Alloy",
		BaseCraftTime = 14,
	},

	-- Utility placeables
	Torch = {
		Ingredients = {
			{ Id = "ForestWood", N = 1 },
			{ Id = "SapResin", N = 1 },
		},
		Output = { Id = "Torch", N = 2 },
		AllowedStations = { "Hand", "Workbench" },
		Category = "Utility",
		BaseCraftTime = 2,
	},
	Campfire = {
		Ingredients = {
			{ Id = "ForestWood", N = 4 },
			{ Id = "ForestStone", N = 2 },
		},
		Output = { Id = "Campfire", N = 1 },
		AllowedStations = { "Workbench" },
		Category = "Utility",
		BaseCraftTime = 5,
	},
	Chest = {
		Ingredients = {
			{ Id = "ForestPlank", N = 8 },
			{ Id = "FiberCloth", N = 1 },
		},
		Output = { Id = "Chest", N = 1 },
		AllowedStations = { "Workbench" },
		Category = "Storage",
		BaseCraftTime = 6,
	},

	-- Placeable station progression
	Workbench = {
		Ingredients = {
			{ Id = "ForestPlank", N = 8 },
			-- Use unwoven fiber: the first loom requires this workbench.
			{ Id = "ReedFiber", N = 6 },
		},
		Output = { Id = "Workbench", N = 1 },
		AllowedStations = { "Hand" },
		Category = "Stations",
		BaseCraftTime = 5,
	},
	Furnace = {
		Ingredients = {
			{ Id = "ForestStone", N = 12 },
			{ Id = "ClayMud", N = 6 },
		},
		Output = { Id = "Furnace", N = 1 },
		AllowedStations = { "Workbench" },
		Category = "Stations",
		BaseCraftTime = 9,
	},
	Loom = {
		Ingredients = {
			{ Id = "ForestPlank", N = 6 },
			{ Id = "ReedFiber", N = 8 },
		},
		Output = { Id = "Loom", N = 1 },
		AllowedStations = { "Workbench" },
		Category = "Stations",
		BaseCraftTime = 8,
	},
	DryingRack = {
		Ingredients = {
			{ Id = "MangroveWood", N = 6 },
			{ Id = "ReedFiber", N = 6 },
			{ Id = "RootFiber", N = 4 },
		},
		Output = { Id = "DryingRack", N = 1 },
		AllowedStations = { "Workbench" },
		Category = "Stations",
		BaseCraftTime = 9,
	},
	AlchemyTable = {
		Ingredients = {
			{ Id = "MireStone", N = 8 },
			{ Id = "TemperedGlass", N = 4 },
			-- Assemble the catalyst here; BioGel itself requires this station.
			{ Id = "Glowcap", N = 2 },
			{ Id = "MarshWater", N = 2 },
			{ Id = "LeechVenomSac", N = 2 },
		},
		Output = { Id = "AlchemyTable", N = 1 },
		AllowedStations = { "Workbench", "AdvancedWorkbench" },
		Category = "Stations",
		BaseCraftTime = 10,
	},
	Kiln = {
		Ingredients = {
			{ Id = "SandstoneChunk", N = 10 },
			{ Id = "SulfiteOre", N = 4 },
			{ Id = "ForestStone", N = 6 },
		},
		Output = { Id = "Kiln", N = 1 },
		AllowedStations = { "Workbench", "AdvancedWorkbench" },
		Category = "Stations",
		BaseCraftTime = 10,
	},
	AdvancedWorkbench = {
		Ingredients = {
			{ Id = "Workbench", N = 1 },
			{ Id = "SanditeIngot", N = 4 },
			-- Four composites' components avoid requiring an advanced bench first.
			{ Id = "MireStone", N = 8 },
			{ Id = "PeatBrick", N = 4 },
			{ Id = "BioGel", N = 4 },
		},
		Output = { Id = "AdvancedWorkbench", N = 1 },
		AllowedStations = { "Workbench" },
		Category = "Stations",
		BaseCraftTime = 12,
	},
	Anvil = {
		Ingredients = {
			{ Id = "SanditeIngot", N = 8 },
			{ Id = "ForestStone", N = 6 },
		},
		Output = { Id = "Anvil", N = 1 },
		AllowedStations = { "AdvancedWorkbench" },
		Category = "Stations",
		BaseCraftTime = 12,
	},
	Refinery = {
		Ingredients = {
			{ Id = "AdvancedWorkbench", N = 1 },
			-- Includes the ingredients of two VoidAlloy, which require a refinery.
			{ Id = "ObsiditeIngot", N = 8 },
			{ Id = "CryoAlloy", N = 4 },
			{ Id = "AlloyDust", N = 4 },
			{ Id = "VoidResidue", N = 2 },
		},
		Output = { Id = "Refinery", N = 1 },
		AllowedStations = { "AdvancedWorkbench" },
		Category = "Stations",
		BaseCraftTime = 14,
	},
	SurveyBench = {
		Ingredients = {
			{ Id = "AdvancedWorkbench", N = 1 },
			{ Id = "PrismGlass", N = 4 },
			{ Id = "PhaseCircuit", N = 2 },
			{ Id = "IceLens", N = 2 },
		},
		Output = { Id = "SurveyBench", N = 1 },
		AllowedStations = { "AdvancedWorkbench" },
		Category = "Stations",
		BaseCraftTime = 14,
	},
	MasterWorkbench = {
		Ingredients = {
			{ Id = "AdvancedWorkbench", N = 1 },
			{ Id = "ObsiditeIngot", N = 4 },
			{ Id = "CryoAlloy", N = 4 },
			{ Id = "ResonantCrystal", N = 4 },
		},
		Output = { Id = "MasterWorkbench", N = 1 },
		AllowedStations = { "AdvancedWorkbench" },
		Category = "Stations",
		BaseCraftTime = 15,
	},

	-- Survival consumables
	ReviveKit = {
		Ingredients = {
			{ Id = "ReedFiber", N = 6 },
			{ Id = "SapResin", N = 2 },
			{ Id = "BrownMushroom", N = 2 },
		},
		Output = { Id = "ReviveKit", N = 1 },
		AllowedStations = { "Hand" },
		Category = "Consumables",
		ProcessKind = "Medicine",
		BaseCraftTime = 4,
	},
	Bandage = {
		Ingredients = {
			{ Id = "FiberCloth", N = 2 },
			{ Id = "HerbalPaste", N = 1 },
		},
		Output = { Id = "Bandage", N = 1 },
		AllowedStations = { "Loom", "AlchemyTable" },
		Category = "Consumables",
		ProcessKind = "Medicine",
		BaseCraftTime = 6,
	},
	AntitoxinTonic = {
		Ingredients = {
			{ Id = "AntitoxinPaste", N = 2 },
			{ Id = "MarshWater", N = 1 },
			{ Id = "BioGel", N = 1 },
		},
		Output = { Id = "AntitoxinTonic", N = 1 },
		AllowedStations = { "AlchemyTable" },
		Category = "Consumables",
		ProcessKind = "Tonic",
		BaseCraftTime = 8,
	},
	HeatTonic = {
		Ingredients = {
			{ Id = "EmberBloom", N = 2 },
			{ Id = "CactusStem", N = 2 },
			{ Id = "SpringWater", N = 1 },
		},
		Output = { Id = "HeatTonic", N = 1 },
		AllowedStations = { "AlchemyTable" },
		Category = "Consumables",
		ProcessKind = "Tonic",
		BaseCraftTime = 8,
	},
	ColdTonic = {
		Ingredients = {
			{ Id = "HoarfrostPowder", N = 2 },
			{ Id = "ChillBloom", N = 2 },
			{ Id = "SpringWater", N = 1 },
		},
		Output = { Id = "ColdTonic", N = 1 },
		AllowedStations = { "AlchemyTable" },
		Category = "Consumables",
		ProcessKind = "Tonic",
		BaseCraftTime = 8,
	},
	StaminaRation = {
		Ingredients = {
			{ Id = "BrownMushroom", N = 2 },
			{ Id = "CactusStem", N = 2 },
			{ Id = "BogReed", N = 1 },
		},
		Output = { Id = "StaminaRation", N = 1 },
		AllowedStations = { "Hand", "DryingRack" },
		Category = "Consumables",
		ProcessKind = "Food",
		BaseCraftTime = 6,
	},
	ReinforcedRation = {
		Ingredients = {
			{ Id = "StaminaRation", N = 1 },
			{ Id = "FrostWolfFur", N = 1 },
			{ Id = "LavaSalt", N = 1 },
		},
		Output = { Id = "ReinforcedRation", N = 1 },
		AllowedStations = { "DryingRack" },
		Category = "Consumables",
		ProcessKind = "Food",
		BaseCraftTime = 7,
	},
	ToxinFilter = {
		Ingredients = {
			{ Id = "ReedFiber", N = 3 },
			{ Id = "BioGel", N = 2 },
			{ Id = "TemperedGlass", N = 1 },
		},
		Output = { Id = "ToxinFilter", N = 1 },
		AllowedStations = { "AlchemyTable" },
		Category = "Consumables",
		ProcessKind = "Filter",
		BaseCraftTime = 8,
	},
	ThermalPatch = {
		Ingredients = {
			{ Id = "HeatWrap", N = 1 },
			{ Id = "ThermalGel", N = 1 },
			{ Id = "FiberCloth", N = 2 },
		},
		Output = { Id = "ThermalPatch", N = 1 },
		AllowedStations = { "AlchemyTable" },
		Category = "Consumables",
		ProcessKind = "Medicine",
		BaseCraftTime = 8,
	},

	-- Tools, weapons, armor
	StoneHatchet = {
		Ingredients = {
			{ Id = "ForestWood", N = 3 },
			{ Id = "ForestStone", N = 2 },
		},
		Output = { Id = "StoneHatchet", N = 1 },
		AllowedStations = { "Workbench" },
		Category = "Tools",
		BaseCraftTime = 5,
	},
	StonePickaxe = {
		Ingredients = {
			{ Id = "ForestWood", N = 2 },
			{ Id = "ForestStone", N = 3 },
		},
		Output = { Id = "StonePickaxe", N = 1 },
		AllowedStations = { "Workbench" },
		Category = "Tools",
		BaseCraftTime = 5,
	},
	SanditePickaxe = {
		Ingredients = {
			{ Id = "SanditeIngot", N = 3 },
			{ Id = "ForestWood", N = 2 },
			{ Id = "TemperedGlass", N = 1 },
		},
		Output = { Id = "SanditePickaxe", N = 1 },
		AllowedStations = { "Anvil" },
		Category = "Tools",
		BaseCraftTime = 9,
	},
	MireSickle = {
		Ingredients = {
			{ Id = "MireComposite", N = 3 },
			{ Id = "ForestPlank", N = 2 },
			{ Id = "BioGel", N = 1 },
		},
		Output = { Id = "MireSickle", N = 1 },
		AllowedStations = { "AdvancedWorkbench" },
		Category = "Tools",
		BaseCraftTime = 9,
	},
	CryoPickaxe = {
		Ingredients = {
			{ Id = "CryoAlloy", N = 3 },
			{ Id = "Frostwood", N = 2 },
			{ Id = "IceLens", N = 1 },
			{ Id = "MireComposite", N = 1 },
		},
		Output = { Id = "CryoPickaxe", N = 1 },
		AllowedStations = { "Anvil" },
		Category = "Tools",
		BaseCraftTime = 10,
	},
	ObsidianAxe = {
		Ingredients = {
			{ Id = "ObsiditeIngot", N = 3 },
			{ Id = "Frostwood", N = 2 },
			{ Id = "HoundFang", N = 1 },
			{ Id = "TanninOil", N = 1 },
		},
		Output = { Id = "ObsidianAxe", N = 1 },
		AllowedStations = { "Anvil" },
		Category = "Tools",
		BaseCraftTime = 10,
	},
	PhaseMultitool = {
		Ingredients = {
			{ Id = "VoidAlloy", N = 3 },
			{ Id = "PhaseCircuit", N = 2 },
			{ Id = "ResonantCrystal", N = 2 },
			{ Id = "ThermalGel", N = 1 },
			{ Id = "MireComposite", N = 1 },
		},
		Output = { Id = "PhaseMultitool", N = 1 },
		AllowedStations = { "MasterWorkbench" },
		Category = "Tools",
		BaseCraftTime = 12,
	},

	StoneSpear = {
		Ingredients = {
			{ Id = "ForestWood", N = 3 },
			{ Id = "ForestStone", N = 2 },
			{ Id = "ReedFiber", N = 2 },
		},
		Output = { Id = "StoneSpear", N = 1 },
		AllowedStations = { "Hand" },
		Category = "Weapons",
		BaseCraftTime = 4,
	},
	BoneSpear = {
		Ingredients = {
			{ Id = "DriedBone", N = 4 },
			{ Id = "ReedFiber", N = 2 },
			{ Id = "CactusFiber", N = 1 },
		},
		Output = { Id = "BoneSpear", N = 1 },
		AllowedStations = { "Workbench" },
		Category = "Weapons",
		BaseCraftTime = 6,
	},
	SanditeBlade = {
		Ingredients = {
			{ Id = "SanditeIngot", N = 2 },
			{ Id = "SerpentScale", N = 1 },
			{ Id = "ForestWood", N = 1 },
		},
		Output = { Id = "SanditeBlade", N = 1 },
		AllowedStations = { "AdvancedWorkbench" },
		Category = "Weapons",
		BaseCraftTime = 8,
	},
	MireDagger = {
		Ingredients = {
			{ Id = "MireComposite", N = 2 },
			{ Id = "LeechVenomSac", N = 1 },
			{ Id = "SanditeIngot", N = 1 },
		},
		Output = { Id = "MireDagger", N = 1 },
		AllowedStations = { "AdvancedWorkbench" },
		Category = "Weapons",
		BaseCraftTime = 8,
	},
	FrostLance = {
		Ingredients = {
			{ Id = "CryoAlloy", N = 2 },
			{ Id = "MireComposite", N = 1 },
			{ Id = "FrostWolfFur", N = 1 },
		},
		Output = { Id = "FrostLance", N = 1 },
		AllowedStations = { "Anvil" },
		Category = "Weapons",
		BaseCraftTime = 10,
	},
	MagmaHammer = {
		Ingredients = {
			{ Id = "ObsiditeIngot", N = 3 },
			{ Id = "MagmaCore", N = 1 },
			{ Id = "GlacialStone", N = 2 },
			{ Id = "TanninOil", N = 1 },
		},
		Output = { Id = "MagmaHammer", N = 1 },
		AllowedStations = { "Anvil" },
		Category = "Weapons",
		BaseCraftTime = 10,
	},
	CrystalBow = {
		Ingredients = {
			{ Id = "QuantumThread", N = 2 },
			{ Id = "ResonantCrystal", N = 2 },
			{ Id = "Frostwood", N = 2 },
			{ Id = "ObsiditeIngot", N = 1 },
			{ Id = "TanninOil", N = 1 },
		},
		Output = { Id = "CrystalBow", N = 1 },
		AllowedStations = { "MasterWorkbench" },
		Category = "Weapons",
		BaseCraftTime = 12,
	},
	VoidEdge = {
		Ingredients = {
			{ Id = "VoidAlloy", N = 3 },
			{ Id = "NullFragment", N = 2 },
			{ Id = "SentinelCore", N = 1 },
			{ Id = "CryoAlloy", N = 1 },
			{ Id = "BioGel", N = 1 },
			{ Id = "ForestPlank", N = 1 },
		},
		Output = { Id = "VoidEdge", N = 1 },
		AllowedStations = { "MasterWorkbench" },
		Category = "Weapons",
		BaseCraftTime = 13,
	},

	MeteorPike = {
		Ingredients = {
			{ Id = "MeteorAlloy", N = 3 },
			{ Id = "AuroraLens", N = 1 },
			{ Id = "ForestPlank", N = 2 },
		},
		Output = { Id = "MeteorPike", N = 1 },
		AllowedStations = { "MasterWorkbench" },
		Category = "Weapons",
		BaseCraftTime = 14,
	},

	-- First-shift heat protection: gather and assemble entirely in Verdant Reach.
	ReedSunwrap = {
		Ingredients = {
			{ Id = "ReedFiber", N = 6 },
			{ Id = "MossBloom", N = 2 },
			{ Id = "SapResin", N = 2 },
		},
		Output = { Id = "ReedSunwrap", N = 1 },
		AllowedStations = { "Hand" },
		Category = "Armor",
		BaseCraftTime = 5,
	},
	DesertCloak = {
		Ingredients = {
			{ Id = "CactusFiber", N = 4 },
			{ Id = "HeatWrap", N = 2 },
			{ Id = "FiberCloth", N = 2 },
		},
		Output = { Id = "DesertCloak", N = 1 },
		AllowedStations = { "Loom" },
		Category = "Armor",
		BaseCraftTime = 9,
	},
	SwampWaders = {
		Ingredients = {
			{ Id = "MarshThread", N = 4 },
			{ Id = "BioGel", N = 2 },
			{ Id = "MangroveWood", N = 2 },
			{ Id = "SapResin", N = 2 },
		},
		Output = { Id = "SwampWaders", N = 1 },
		AllowedStations = { "Loom" },
		Category = "Armor",
		BaseCraftTime = 9,
	},
	FrostParka = {
		Ingredients = {
			{ Id = "InsulatedCloth", N = 5 },
			{ Id = "MarshThread", N = 2 },
			{ Id = "TemperedGlass", N = 1 },
			{ Id = "ThermalGel", N = 1 },
		},
		Output = { Id = "FrostParka", N = 1 },
		AllowedStations = { "Loom" },
		Category = "Armor",
		BaseCraftTime = 10,
	},
	VolcanicPlate = {
		Ingredients = {
			{ Id = "ObsiditeIngot", N = 5 },
			{ Id = "HeatPlate", N = 2 },
			{ Id = "VulcanLeather", N = 2 },
			{ Id = "InsulatedCloth", N = 2 },
		},
		Output = { Id = "VolcanicPlate", N = 1 },
		AllowedStations = { "Anvil" },
		Category = "Armor",
		BaseCraftTime = 11,
	},
	CrystalWeave = {
		Ingredients = {
			{ Id = "QuantumThread", N = 4 },
			{ Id = "PrismGlass", N = 2 },
			{ Id = "MarshThread", N = 2 },
			{ Id = "CryoAlloy", N = 1 },
		},
		Output = { Id = "CrystalWeave", N = 1 },
		AllowedStations = { "Loom" },
		Category = "Armor",
		BaseCraftTime = 10,
	},
	AuroraMantle = {
		Ingredients = {
			{ Id = "AuroraFiber", N = 4 },
			{ Id = "InsulatedCloth", N = 2 },
			{ Id = "HeatWrap", N = 2 },
			{ Id = "AuroraAntler", N = 1 },
			{ Id = "DawnBloom", N = 2 },
		},
		Output = { Id = "AuroraMantle", N = 1 },
		AllowedStations = { "Loom" },
		Category = "Armor",
		BaseCraftTime = 12,
	},
	StarforgedPlate = {
		Ingredients = {
			{ Id = "MeteorAlloy", N = 4 },
			{ Id = "AuroraFiber", N = 3 },
			{ Id = "SwampWaders", N = 1 },
			{ Id = "ImpactGlass", N = 2 },
		},
		Output = { Id = "StarforgedPlate", N = 1 },
		AllowedStations = { "MasterWorkbench" },
		Category = "Armor",
		BaseCraftTime = 16,
	},
	AdaptiveSurvivalSuit = {
		Ingredients = {
			{ Id = "DesertCloak", N = 1 },
			{ Id = "SwampWaders", N = 1 },
			{ Id = "FrostParka", N = 1 },
			{ Id = "VolcanicPlate", N = 1 },
			{ Id = "CrystalWeave", N = 1 },
			{ Id = "VoidAlloy", N = 2 },
			{ Id = "AuroraMantle", N = 1 },
			{ Id = "MeteorAlloy", N = 2 },
		},
		Output = { Id = "AdaptiveSurvivalSuit", N = 1 },
		AllowedStations = { "MasterWorkbench" },
		Category = "Armor",
		BaseCraftTime = 14,
	},

	-- Intel/strategy devices
	ShiftStabilizer = {
		Ingredients = { { Id = "SanditeIngot", N = 3 }, { Id = "TemperedGlass", N = 2 }, { Id = "BioGel", N = 2 } },
		Output = { Id = "ShiftStabilizer", N = 1 },
		AllowedStations = { "AdvancedWorkbench" }, Category = "Intel", BaseCraftTime = 12,
	},
	ShiftTrigger = {
		Ingredients = { { Id = "SanditeIngot", N = 3 }, { Id = "SunShard", N = 2 }, { Id = "BioGel", N = 1 }, { Id = "MagmaCore", N = 1 } },
		Output = { Id = "ShiftTrigger", N = 1 },
		AllowedStations = { "AdvancedWorkbench" }, Category = "Intel", BaseCraftTime = 12,
	},
	BiomeSelector = {
		Ingredients = {
			{ Id = "PhaseCircuit", N = 2 },
			{ Id = "CryoAlloy", N = 2 },
			{ Id = "ObsiditeIngot", N = 2 },
			{ Id = "SentinelCore", N = 1 },
			{ Id = "AuroraLens", N = 1 },
			{ Id = "MeteorAlloy", N = 2 },
			{ Id = "MeteorCore", N = 1 },
		},
		Output = { Id = "BiomeSelector", N = 1 },
		AllowedStations = { "SurveyBench" }, Category = "Intel", BaseCraftTime = 16,
	},
	FieldClock = {
		Ingredients = {
			{ Id = "TemperedGlass", N = 2 },
			{ Id = "SanditeIngot", N = 1 },
			{ Id = "ForestPlank", N = 2 },
		},
		Output = { Id = "FieldClock", N = 1 },
		AllowedStations = { "Workbench" },
		Category = "Intel",
		BaseCraftTime = 10,
	},
	BiomePredictor = {
		Ingredients = {
			{ Id = "FieldClock", N = 1 },
			{ Id = "IceLens", N = 2 },
			{ Id = "BioGel", N = 2 },
			{ Id = "SanditeIngot", N = 2 },
		},
		Output = { Id = "BiomePredictor", N = 1 },
		AllowedStations = { "AdvancedWorkbench" },
		Category = "Intel",
		BaseCraftTime = 12,
	},
	WeatherPredictor = {
		Ingredients = {
			{ Id = "BiomePredictor", N = 1 },
			{ Id = "PrismGlass", N = 2 },
			{ Id = "VoidAlloy", N = 2 },
			{ Id = "EchoBloom", N = 2 },
		},
		Output = { Id = "WeatherPredictor", N = 1 },
		AllowedStations = { "SurveyBench" },
		Category = "Intel",
		BaseCraftTime = 13,
	},
	ThreatMeter = {
		Ingredients = {
			{ Id = "SanditeIngot", N = 2 },
			{ Id = "MagmaCore", N = 1 },
			{ Id = "SentinelCore", N = 1 },
			{ Id = "TemperedGlass", N = 1 },
		},
		Output = { Id = "ThreatMeter", N = 1 },
		AllowedStations = { "SurveyBench" },
		Category = "Intel",
		BaseCraftTime = 12,
	},
	ResourceCompass = {
		Ingredients = {
			{ Id = "ResonantCrystal", N = 2 },
			{ Id = "PhaseQuartz", N = 2 },
			{ Id = "ForestWood", N = 1 },
			{ Id = "TanninOil", N = 1 },
		},
		Output = { Id = "ResourceCompass", N = 1 },
		AllowedStations = { "SurveyBench" },
		Category = "Intel",
		BaseCraftTime = 11,
	},
	EventSeismograph = {
		Ingredients = {
			{ Id = "ObsidianShard", N = 3 },
			{ Id = "GlacialStone", N = 2 },
			{ Id = "VoidResidue", N = 2 },
			{ Id = "PhaseCircuit", N = 1 },
		},
		Output = { Id = "EventSeismograph", N = 1 },
		AllowedStations = { "SurveyBench" },
		Category = "Intel",
		BaseCraftTime = 12,
	},
	PathfinderBeacon = {
		Ingredients = {
			{ Id = "ResourceCompass", N = 1 },
			{ Id = "PrismGlass", N = 1 },
			{ Id = "QuantumThread", N = 1 },
			{ Id = "HeatPlate", N = 1 },
		},
		Output = { Id = "PathfinderBeacon", N = 1 },
		AllowedStations = { "SurveyBench" },
		Category = "Intel",
		BaseCraftTime = 12,
	},
	HazardAnalyzer = {
		Ingredients = {
			{ Id = "AntitoxinPaste", N = 2 },
			{ Id = "ThermalGel", N = 2 },
			{ Id = "PrismGlass", N = 1 },
			{ Id = "ResonantCrystal", N = 1 },
		},
		Output = { Id = "HazardAnalyzer", N = 1 },
		AllowedStations = { "SurveyBench" },
		Category = "Intel",
		BaseCraftTime = 12,
	},
}

-- Structural costs move to crafting; stations retain their own recipes and costs.
for id, costs in pairs(require(script.Parent.Config).BUILD.Costs) do
	local ingredients = {}
	for _, entry in ipairs(costs) do
		table.insert(ingredients, {Id=entry.Id, N=entry.N, StructuralMaterial=true})
	end
	WorkbenchConfig.RECIPES[id] = {Ingredients=ingredients, Output={Id=id,N=1}, AllowedStations={"Hand"}, Category="Structures", BaseCraftTime=3}
end

function WorkbenchConfig:IngredientCost(ingredient, player)
	local count = math.max(1, math.floor(ingredient.N or 1))
	if ingredient.StructuralMaterial then
		local discount = math.clamp(tonumber(player and player:GetAttribute("Class_BuildDiscount")) or 0, 0, .18)
		count = math.max(1, math.ceil(count * (1 - discount)))
	end
	return count
end

WorkbenchConfig.CATEGORIES = {
	"Structures",
	"Materials",
	"Tools",
	"Weapons",
	"Armor",
	"Consumables",
	"Utility",
	"Storage",
	"Stations",
	"Intel",
}

local function listContains(list, target)
	if type(list) ~= "table" then return false end
	for _, value in ipairs(list) do
		if value == target then
			return true
		end
	end
	return false
end

function WorkbenchConfig:CanCraftAt(recipeId, stationType)
	local recipe = self.RECIPES[recipeId]
	if not recipe then return false end
	if not self.STATIONS[stationType] then return false end
	-- Only the two general-purpose benches inherit the basic field recipes.
	if (stationType == "Workbench" or stationType == "AdvancedWorkbench")
		and self:CanCraftAt(recipeId, "Hand") then return true end

	if type(recipe.AllowedStations) == "table" and #recipe.AllowedStations > 0 then
		return listContains(recipe.AllowedStations, stationType)
	end

	if recipe.StationType then
		return recipe.StationType == stationType
	end

	local station = self.STATIONS[stationType]
	local tier = recipe.StationTier or 0
	if tier == 0 then return stationType == "Hand" end
	return station.Tier >= tier
end

function WorkbenchConfig:GetRecipesForStation(stationType)
	local station = self.STATIONS[stationType]
	if not station then return {} end

	local recipes = {}
	for recipeId, _ in pairs(self.RECIPES) do
		if self:CanCraftAt(recipeId, stationType) then
			recipes[recipeId] = self.RECIPES[recipeId]
		end
	end
	return recipes
end

function WorkbenchConfig:GetHandRecipes()
	return self:GetRecipesForStation("Hand")
end

function WorkbenchConfig:GetMinimumStation(recipeId)
	local recipe = self.RECIPES[recipeId]
	if not recipe then return nil end

	if type(recipe.AllowedStations) == "table" and #recipe.AllowedStations > 0 then
		for _, stationType in ipairs({
			"Hand",
			"Workbench",
			"Furnace",
			"Loom",
			"DryingRack",
			"AlchemyTable",
			"Kiln",
			"AdvancedWorkbench",
			"Anvil",
			"Refinery",
			"SurveyBench",
			"MasterWorkbench",
		}) do
			if listContains(recipe.AllowedStations, stationType) then
				return stationType
			end
		end
		return recipe.AllowedStations[1]
	end

	if recipe.StationType then
		return recipe.StationType
	end

	local tier = recipe.StationTier or 0
	if tier == 0 then return "Hand" end
	if tier == 1 then return "Workbench" end
	if tier == 2 then return "AdvancedWorkbench" end
	if tier == 3 then return "MasterWorkbench" end
	return nil
end

local function mergeMultiplier(baseMult, nextMult)
	return (tonumber(baseMult) or 1) * (tonumber(nextMult) or 1)
end

function WorkbenchConfig:GetEffectiveStationModifiers(recipe, stationType)
	if type(recipe) ~= "table" then
		return 1, 0
	end
	local timeMult = 1
	local extraYieldChance = 0

	if recipe.StationModifiers and recipe.StationModifiers[stationType] then
		local cfg = recipe.StationModifiers[stationType]
		timeMult = mergeMultiplier(timeMult, cfg.TimeMult)
		extraYieldChance = math.max(extraYieldChance, tonumber(cfg.ExtraYieldChance) or 0)
	end

	local globalCfg = self.STATION_GLOBAL_MODIFIERS[stationType]
	if globalCfg then
		local applies = false
		if globalCfg.ProcessKinds and recipe.ProcessKind and globalCfg.ProcessKinds[recipe.ProcessKind] then
			applies = true
		elseif globalCfg.Categories and recipe.Category and globalCfg.Categories[recipe.Category] then
			applies = true
		end
		if applies then
			timeMult = mergeMultiplier(timeMult, globalCfg.TimeMult)
			extraYieldChance = math.max(extraYieldChance, tonumber(globalCfg.ExtraYieldChance) or 0)
		end
	end

	return math.max(0.05, timeMult), math.max(0, extraYieldChance)
end

return WorkbenchConfig
