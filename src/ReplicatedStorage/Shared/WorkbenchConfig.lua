-- WorkbenchConfig.lua
-- Defines workbench tiers and crafting station capabilities
-- Similar to Minecraft: Hand crafting for basics, workbenches for advanced items

local WorkbenchConfig = {}

-- Station tier levels
-- 0 = Hand/Inventory crafting (basic items like Minecraft's 2x2 grid)
-- 1 = Basic Workbench (like Minecraft crafting table)
-- 2 = Advanced Workbench (more complex recipes)
-- 3 = Master Workbench (end-game recipes)
-- Special stations for specific crafting types
WorkbenchConfig.STATION_TIERS = {
	Hand = 0,           -- Inventory crafting
	Workbench = 1,      -- Basic crafting table
	AdvancedWorkbench = 2,
	MasterWorkbench = 3,
	Furnace = 10,       -- Smelting
	Anvil = 11,         -- Tool repair/upgrade
	Loom = 12,          -- Cloth/armor crafting
}

-- Station definitions with metadata
WorkbenchConfig.STATIONS = {
	Hand = {
		Tier = 0,
		Name = "Hand Crafting",
		Description = "Basic crafting from your inventory",
		MaxRecipeComplexity = 2,  -- Max ingredients
		Icon = "🤲",
	},
	Workbench = {
		Tier = 1,
		Name = "Workbench",
		Description = "A sturdy table for crafting tools and equipment",
		MaxRecipeComplexity = 4,
		Icon = "🔨",
		BuildType = "Workbench",  -- Matches BUILD.AllowedTypes
		InteractRadius = 8,
	},
	AdvancedWorkbench = {
		Tier = 2,
		Name = "Advanced Workbench",
		Description = "Precision tools for complex crafting",
		MaxRecipeComplexity = 6,
		Icon = "⚙️",
		BuildType = "AdvancedWorkbench",
		InteractRadius = 8,
	},
	MasterWorkbench = {
		Tier = 3,
		Name = "Master Workbench",
		Description = "The ultimate crafting station for legendary items",
		MaxRecipeComplexity = 9,
		Icon = "⭐",
		BuildType = "MasterWorkbench",
		InteractRadius = 8,
	},
	Furnace = {
		Tier = 10,
		Name = "Furnace",
		Description = "Smelt ores and cook food",
		MaxRecipeComplexity = 2,
		Icon = "🔥",
		BuildType = "Furnace",
		InteractRadius = 6,
		ProcessingTime = 3,  -- Seconds per item
	},
	Anvil = {
		Tier = 11,
		Name = "Anvil",
		Description = "Repair and upgrade tools",
		MaxRecipeComplexity = 3,
		Icon = "🔧",
		BuildType = "Anvil",
		InteractRadius = 6,
	},
	Loom = {
		Tier = 12,
		Name = "Loom",
		Description = "Weave cloth and craft armor",
		MaxRecipeComplexity = 4,
		Icon = "🧵",
		BuildType = "Loom",
		InteractRadius = 6,
	},
}

-- Recipes with station requirements
-- StationTier: minimum tier required (0 = hand, 1+ = needs workbench)
-- StationType: specific station type required (optional, for special stations)
WorkbenchConfig.RECIPES = {
	-- ============================================
	-- TIER 0: HAND CRAFTING (Inventory)
	-- Basic survival items, simple tools
	-- ============================================
	Stick = {
		Ingredients = { { Id = "Wood", N = 1 } },
		Output = { Id = "Stick", N = 4 },
		StationTier = 0,
		Category = "Materials",
	},
	Plank = {
		Ingredients = { { Id = "Wood", N = 1 } },
		Output = { Id = "Plank", N = 4 },
		StationTier = 0,
		Category = "Materials",
	},
	Torch = {
		Ingredients = { 
			{ Id = "Stick", N = 1 },
			{ Id = "Coal", N = 1 },
		},
		Output = { Id = "Torch", N = 4 },
		StationTier = 0,
		Category = "Utility",
	},
	Workbench = {
		Ingredients = { { Id = "Plank", N = 4 } },
		Output = { Id = "Workbench", N = 1 },
		StationTier = 0,
		Category = "Stations",
	},
	
	-- ============================================
	-- TIER 1: BASIC WORKBENCH
	-- Tools, weapons, basic equipment
	-- ============================================
	StoneHatchet = {
		Ingredients = {
			{ Id = "Wood", N = 2 },
			{ Id = "Stone", N = 1 },
		},
		Output = { Id = "StoneHatchet", N = 1 },
		StationTier = 1,
		Category = "Tools",
	},
	StonePickaxe = {
		Ingredients = {
			{ Id = "Wood", N = 2 },
			{ Id = "Stone", N = 2 },
		},
		Output = { Id = "StonePickaxe", N = 1 },
		StationTier = 1,
		Category = "Tools",
	},
	WoodenSword = {
		Ingredients = {
			{ Id = "Plank", N = 2 },
			{ Id = "Stick", N = 1 },
		},
		Output = { Id = "WoodenSword", N = 1 },
		StationTier = 1,
		Category = "Weapons",
	},
	Bow = {
		Ingredients = {
			{ Id = "Wood", N = 3 },
			{ Id = "Reed", N = 2 },
		},
		Output = { Id = "Bow", N = 1 },
		StationTier = 1,
		Category = "Weapons",
	},
	Arrow = {
		Ingredients = {
			{ Id = "Stick", N = 1 },
			{ Id = "Stone", N = 1 },
		},
		Output = { Id = "Arrow", N = 4 },
		StationTier = 1,
		Category = "Ammo",
	},
	Campfire = {
		Ingredients = {
			{ Id = "Wood", N = 4 },
			{ Id = "Stone", N = 2 },
		},
		Output = { Id = "Campfire", N = 1 },
		StationTier = 1,
		Category = "Utility",
	},
	Chest = {
		Ingredients = {
			{ Id = "Plank", N = 8 },
		},
		Output = { Id = "Chest", N = 1 },
		StationTier = 1,
		Category = "Storage",
	},
	Furnace = {
		Ingredients = {
			{ Id = "Stone", N = 8 },
		},
		Output = { Id = "Furnace", N = 1 },
		StationTier = 1,
		Category = "Stations",
	},
	AdvancedWorkbench = {
		Ingredients = {
			{ Id = "Plank", N = 6 },
			{ Id = "IronIngot", N = 2 },
		},
		Output = { Id = "AdvancedWorkbench", N = 1 },
		StationTier = 1,
		Category = "Stations",
	},
	
	-- ============================================
	-- TIER 2: ADVANCED WORKBENCH
	-- Metal tools, better weapons, armor
	-- ============================================
	IronSword = {
		Ingredients = {
			{ Id = "IronIngot", N = 2 },
			{ Id = "Stick", N = 1 },
		},
		Output = { Id = "IronSword", N = 1 },
		StationTier = 2,
		Category = "Weapons",
	},
	IronPickaxe = {
		Ingredients = {
			{ Id = "IronIngot", N = 3 },
			{ Id = "Stick", N = 2 },
		},
		Output = { Id = "IronPickaxe", N = 1 },
		StationTier = 2,
		Category = "Tools",
	},
	IronHatchet = {
		Ingredients = {
			{ Id = "IronIngot", N = 3 },
			{ Id = "Stick", N = 2 },
		},
		Output = { Id = "IronHatchet", N = 1 },
		StationTier = 2,
		Category = "Tools",
	},
	IronArmor = {
		Ingredients = {
			{ Id = "IronIngot", N = 5 },
			{ Id = "Leather", N = 2 },
		},
		Output = { Id = "IronArmor", N = 1 },
		StationTier = 2,
		Category = "Armor",
	},
	Shield = {
		Ingredients = {
			{ Id = "IronIngot", N = 2 },
			{ Id = "Plank", N = 4 },
		},
		Output = { Id = "Shield", N = 1 },
		StationTier = 2,
		Category = "Weapons",
	},
	Anvil = {
		Ingredients = {
			{ Id = "IronIngot", N = 6 },
		},
		Output = { Id = "Anvil", N = 1 },
		StationTier = 2,
		Category = "Stations",
	},
	Loom = {
		Ingredients = {
			{ Id = "Plank", N = 6 },
			{ Id = "Reed", N = 4 },
		},
		Output = { Id = "Loom", N = 1 },
		StationTier = 2,
		Category = "Stations",
	},
	MasterWorkbench = {
		Ingredients = {
			{ Id = "Plank", N = 8 },
			{ Id = "IronIngot", N = 4 },
			{ Id = "GoldIngot", N = 2 },
		},
		Output = { Id = "MasterWorkbench", N = 1 },
		StationTier = 2,
		Category = "Stations",
	},
	
	-- ============================================
	-- TIER 3: MASTER WORKBENCH
	-- Endgame equipment, legendary items
	-- ============================================
	DiamondSword = {
		Ingredients = {
			{ Id = "Diamond", N = 2 },
			{ Id = "Stick", N = 1 },
			{ Id = "GoldIngot", N = 1 },
		},
		Output = { Id = "DiamondSword", N = 1 },
		StationTier = 3,
		Category = "Weapons",
	},
	DiamondPickaxe = {
		Ingredients = {
			{ Id = "Diamond", N = 3 },
			{ Id = "Stick", N = 2 },
		},
		Output = { Id = "DiamondPickaxe", N = 1 },
		StationTier = 3,
		Category = "Tools",
	},
	DiamondArmor = {
		Ingredients = {
			{ Id = "Diamond", N = 8 },
			{ Id = "IronIngot", N = 2 },
		},
		Output = { Id = "DiamondArmor", N = 1 },
		StationTier = 3,
		Category = "Armor",
	},
	EnchantedBow = {
		Ingredients = {
			{ Id = "Bow", N = 1 },
			{ Id = "Diamond", N = 1 },
			{ Id = "Crystal", N = 2 },
		},
		Output = { Id = "EnchantedBow", N = 1 },
		StationTier = 3,
		Category = "Weapons",
	},
	
	-- ============================================
	-- FURNACE RECIPES (Smelting)
	-- ============================================
	IronIngot = {
		Ingredients = {
			{ Id = "IronOre", N = 1 },
			{ Id = "Coal", N = 1 },
		},
		Output = { Id = "IronIngot", N = 1 },
		StationType = "Furnace",
		Category = "Materials",
		ProcessingTime = 3,
	},
	GoldIngot = {
		Ingredients = {
			{ Id = "GoldOre", N = 1 },
			{ Id = "Coal", N = 1 },
		},
		Output = { Id = "GoldIngot", N = 1 },
		StationType = "Furnace",
		Category = "Materials",
		ProcessingTime = 4,
	},
	Glass = {
		Ingredients = {
			{ Id = "Sand", N = 2 },
			{ Id = "Coal", N = 1 },
		},
		Output = { Id = "Glass", N = 1 },
		StationType = "Furnace",
		Category = "Materials",
		ProcessingTime = 2,
	},
	CookedMeat = {
		Ingredients = {
			{ Id = "RawMeat", N = 1 },
		},
		Output = { Id = "CookedMeat", N = 1 },
		StationType = "Furnace",
		Category = "Food",
		ProcessingTime = 2,
	},
	
	-- ============================================
	-- LOOM RECIPES (Cloth/Armor)
	-- ============================================
	Cloth = {
		Ingredients = {
			{ Id = "Reed", N = 4 },
		},
		Output = { Id = "Cloth", N = 1 },
		StationType = "Loom",
		Category = "Materials",
	},
	ClothSet = {
		Ingredients = {
			{ Id = "Cloth", N = 5 },
		},
		Output = { Id = "ClothSet", N = 1 },
		StationType = "Loom",
		Category = "Armor",
	},
	Leather = {
		Ingredients = {
			{ Id = "RawHide", N = 2 },
		},
		Output = { Id = "Leather", N = 1 },
		StationType = "Loom",
		Category = "Materials",
	},
	LeatherArmor = {
		Ingredients = {
			{ Id = "Leather", N = 5 },
			{ Id = "Cloth", N = 2 },
		},
		Output = { Id = "LeatherArmor", N = 1 },
		StationType = "Loom",
		Category = "Armor",
	},
	
	-- ============================================
	-- DESERT RECIPES - TIER 0 (Hand Crafting)
	-- ============================================
	CactusFlesh = {
		Ingredients = { { Id = "Cactus", N = 1 } },
		Output = { Id = "CactusFlesh", N = 2 },
		StationTier = 0,
		Category = "Materials",
	},
	CactusSpine = {
		Ingredients = { { Id = "Cactus", N = 1 } },
		Output = { Id = "CactusSpine", N = 4 },
		StationTier = 0,
		Category = "Materials",
	},
	BoneMite = {
		Ingredients = { { Id = "Bone", N = 2 } },
		Output = { Id = "BoneMite", N = 1 },
		StationTier = 0,
		Category = "Materials",
	},
	
	-- ============================================
	-- DESERT RECIPES - TIER 1 (Basic Workbench)
	-- ============================================
	CactusClub = {
		Ingredients = {
			{ Id = "Cactus", N = 3 },
			{ Id = "CactusSpine", N = 4 },
		},
		Output = { Id = "CactusClub", N = 1 },
		StationTier = 1,
		Category = "Weapons",
	},
	BoneSword = {
		Ingredients = {
			{ Id = "Bone", N = 4 },
			{ Id = "Stick", N = 1 },
		},
		Output = { Id = "BoneSword", N = 1 },
		StationTier = 1,
		Category = "Weapons",
	},
	BoneHatchet = {
		Ingredients = {
			{ Id = "Bone", N = 3 },
			{ Id = "Stick", N = 2 },
		},
		Output = { Id = "BoneHatchet", N = 1 },
		StationTier = 1,
		Category = "Tools",
	},
	CactusJuice = {
		Ingredients = {
			{ Id = "CactusFlesh", N = 3 },
		},
		Output = { Id = "CactusJuice", N = 2 },
		StationTier = 1,
		Category = "Food",
	},
	
	-- ============================================
	-- DESERT RECIPES - TIER 2 (Advanced Workbench)
	-- ============================================
	SanditeSword = {
		Ingredients = {
			{ Id = "SanditeIngot", N = 2 },
			{ Id = "Stick", N = 1 },
		},
		Output = { Id = "SanditeSword", N = 1 },
		StationTier = 2,
		Category = "Weapons",
	},
	SanditePickaxe = {
		Ingredients = {
			{ Id = "SanditeIngot", N = 3 },
			{ Id = "Stick", N = 2 },
		},
		Output = { Id = "SanditePickaxe", N = 1 },
		StationTier = 2,
		Category = "Tools",
	},
	ScorpionDagger = {
		Ingredients = {
			{ Id = "CactusSpine", N = 6 },
			{ Id = "SanditeIngot", N = 1 },
			{ Id = "Bone", N = 2 },
		},
		Output = { Id = "ScorpionDagger", N = 1 },
		StationTier = 2,
		Category = "Weapons",
	},
	BoneArmor = {
		Ingredients = {
			{ Id = "Bone", N = 8 },
			{ Id = "Leather", N = 2 },
		},
		Output = { Id = "BoneArmor", N = 1 },
		StationTier = 2,
		Category = "Armor",
	},
	SanditeArmor = {
		Ingredients = {
			{ Id = "SanditeIngot", N = 5 },
			{ Id = "Cloth", N = 2 },
		},
		Output = { Id = "SanditeArmor", N = 1 },
		StationTier = 2,
		Category = "Armor",
	},
	DesertSalve = {
		Ingredients = {
			{ Id = "CactusFlesh", N = 2 },
			{ Id = "BoneMite", N = 1 },
			{ Id = "Sulfite", N = 1 },
		},
		Output = { Id = "DesertSalve", N = 2 },
		StationTier = 2,
		Category = "Food",
	},
	
	-- ============================================
	-- DESERT FURNACE RECIPES
	-- ============================================
	SanditeIngot = {
		Ingredients = {
			{ Id = "Sandite", N = 1 },
			{ Id = "Coal", N = 1 },
		},
		Output = { Id = "SanditeIngot", N = 1 },
		StationType = "Furnace",
		Category = "Materials",
		ProcessingTime = 3,
	},
	Sandite_Glass = {
		Ingredients = {
			{ Id = "Sand", N = 3 },
			{ Id = "Sandite", N = 1 },
		},
		Output = { Id = "Sandite_Glass", N = 2 },
		StationType = "Furnace",
		Category = "Materials",
		ProcessingTime = 4,
	},
	
	-- ============================================
	-- DESERT LOOM RECIPES
	-- ============================================
	DesertCloak = {
		Ingredients = {
			{ Id = "Cloth", N = 4 },
			{ Id = "CactusSpine", N = 2 },
			{ Id = "Sand", N = 2 },
		},
		Output = { Id = "DesertCloak", N = 1 },
		StationType = "Loom",
		Category = "Armor",
	},
}

-- Category display order
WorkbenchConfig.CATEGORIES = {
	"Materials",
	"Tools",
	"Weapons",
	"Armor",
	"Ammo",
	"Food",
	"Utility",
	"Storage",
	"Stations",
}

-- Get all recipes available at a given station
function WorkbenchConfig:GetRecipesForStation(stationType)
	local station = self.STATIONS[stationType]
	if not station then return {} end
	
	local recipes = {}
	for recipeId, recipe in pairs(self.RECIPES) do
		local canCraft = false
		
		-- Check if recipe requires specific station type
		if recipe.StationType then
			canCraft = recipe.StationType == stationType
		elseif recipe.StationTier then
			-- Check tier-based crafting
			canCraft = recipe.StationTier <= station.Tier
		end
		
		if canCraft then
			recipes[recipeId] = recipe
		end
	end
	
	return recipes
end

-- Get recipes available for hand crafting (inventory)
function WorkbenchConfig:GetHandRecipes()
	return self:GetRecipesForStation("Hand")
end

-- Check if a recipe can be crafted at a station
function WorkbenchConfig:CanCraftAt(recipeId, stationType)
	local recipe = self.RECIPES[recipeId]
	if not recipe then return false end
	
	local station = self.STATIONS[stationType]
	if not station then return false end
	
	-- Specific station type required
	if recipe.StationType then
		return recipe.StationType == stationType
	end
	
	-- Tier-based check
	if recipe.StationTier then
		return recipe.StationTier <= station.Tier
	end
	
	return true
end

-- Get minimum station required for a recipe
function WorkbenchConfig:GetMinimumStation(recipeId)
	local recipe = self.RECIPES[recipeId]
	if not recipe then return nil end
	
	if recipe.StationType then
		return recipe.StationType
	end
	
	-- Find the lowest tier station that can craft this
	local tier = recipe.StationTier or 0
	if tier == 0 then return "Hand" end
	if tier == 1 then return "Workbench" end
	if tier == 2 then return "AdvancedWorkbench" end
	if tier == 3 then return "MasterWorkbench" end
	
	return nil
end

return WorkbenchConfig
