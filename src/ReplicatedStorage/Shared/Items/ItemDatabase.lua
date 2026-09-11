-- ItemDatabase.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Item = require(script.Parent.Item)

local ItemDatabase = {}

local raw = {
	-- Core starter/utility
	{ Id = "Harvester", Name = "Harvester", StackSize = 1, Tags = { "Tool", "Holdable", "Starter" } },
	{ Id = "Torch", Name = "Torch", StackSize = 99, Tags = { "Placeable", "Utility" } },
	{ Id = "Campfire", Name = "Campfire", StackSize = 1, Tags = { "Placeable", "Utility" } },
	{ Id = "Chest", Name = "Chest", StackSize = 1, Tags = { "Placeable", "Storage" } },

	-- Forest raw
	{ Id = "ForestWood", Name = "Forest Wood", StackSize = 99, Tags = { "Resource", "Raw", "Forest" } },
	{ Id = "ForestStone", Name = "Forest Stone", StackSize = 99, Tags = { "Resource", "Raw", "Forest" } },
	{ Id = "ReedFiber", Name = "Reed Fiber", StackSize = 99, Tags = { "Resource", "Raw", "Forest", "Fiber" } },
	{ Id = "ClayMud", Name = "Clay Mud", StackSize = 99, Tags = { "Resource", "Raw", "Forest" } },
	{ Id = "BrownMushroom", Name = "Brown Mushroom", StackSize = 99, Tags = { "Resource", "Raw", "Forest", "Food" } },
	{ Id = "MossBloom", Name = "Moss Bloom", StackSize = 99, Tags = { "Resource", "Raw", "Forest" } },
	{ Id = "SapResin", Name = "Sap Resin", StackSize = 99, Tags = { "Resource", "Raw", "Forest" } },
	{ Id = "SpringWater", Name = "Spring Water", StackSize = 50, Tags = { "Resource", "Raw", "Forest", "Liquid", "Consumable" } },
	{ Id = "WolfPelt", Name = "Wolf Pelt", StackSize = 50, Tags = { "Resource", "MonsterDrop", "Forest" } },
	{ Id = "WolfFang", Name = "Wolf Fang", StackSize = 99, Tags = { "Resource", "MonsterDrop", "Forest" } },

	-- Desert raw
	{ Id = "CactusStem", Name = "Cactus Stem", StackSize = 99, Tags = { "Resource", "Raw", "Desert", "Food" } },
	{ Id = "Sand", Name = "Sand", StackSize = 99, Tags = { "Resource", "Raw", "Desert" } },
	{ Id = "SandstoneChunk", Name = "Sandstone Chunk", StackSize = 99, Tags = { "Resource", "Raw", "Desert" } },
	{ Id = "Coal", Name = "Coal", StackSize = 99, Tags = { "Resource", "Raw", "Fuel" } },
	{ Id = "DriedBone", Name = "Dried Bone", StackSize = 99, Tags = { "Resource", "Raw", "Desert" } },
	{ Id = "SulfiteOre", Name = "Sulfite Ore", StackSize = 99, Tags = { "Resource", "Raw", "Desert", "Ore" } },
	{ Id = "SaltCrystal", Name = "Salt Crystal", StackSize = 99, Tags = { "Resource", "Raw", "Desert", "Crystal" } },
	{ Id = "SunShard", Name = "Sun Shard", StackSize = 99, Tags = { "Resource", "Raw", "Desert", "Crystal" } },
	{ Id = "ScorpionStinger", Name = "Scorpion Stinger", StackSize = 99, Tags = { "Resource", "MonsterDrop", "Desert" } },
	{ Id = "SerpentScale", Name = "Serpent Scale", StackSize = 99, Tags = { "Resource", "MonsterDrop", "Desert" } },

	-- Swamp raw
	{ Id = "BogReed", Name = "Bog Reed", StackSize = 99, Tags = { "Resource", "Raw", "Swamp", "Fiber" } },
	{ Id = "PeatClump", Name = "Peat Clump", StackSize = 99, Tags = { "Resource", "Raw", "Swamp" } },
	{ Id = "MireStone", Name = "Mire Stone", StackSize = 99, Tags = { "Resource", "Raw", "Swamp" } },
	{ Id = "Glowcap", Name = "Glowcap", StackSize = 99, Tags = { "Resource", "Raw", "Swamp" } },
	{ Id = "MangroveWood", Name = "Mangrove Wood", StackSize = 99, Tags = { "Resource", "Raw", "Swamp" } },
	{ Id = "WillowBark", Name = "Willow Bark", StackSize = 99, Tags = { "Resource", "Raw", "Swamp" } },
	{ Id = "MarshWater", Name = "Marsh Water", StackSize = 50, Tags = { "Resource", "Raw", "Swamp", "Liquid" } },
	{ Id = "RootFiber", Name = "Root Fiber", StackSize = 99, Tags = { "Resource", "Raw", "Swamp", "Fiber" } },
	{ Id = "LeechVenomSac", Name = "Leech Venom Sac", StackSize = 99, Tags = { "Resource", "MonsterDrop", "Swamp" } },
	{ Id = "BogToadGland", Name = "Bog Toad Gland", StackSize = 99, Tags = { "Resource", "MonsterDrop", "Swamp" } },

	-- Frozen tundra raw
	{ Id = "Frostwood", Name = "Frostwood", StackSize = 99, Tags = { "Resource", "Raw", "FrozenTundra" } },
	{ Id = "IceCrystal", Name = "Ice Crystal", StackSize = 99, Tags = { "Resource", "Raw", "FrozenTundra", "Crystal" } },
	{ Id = "PermafrostOre", Name = "Permafrost Ore", StackSize = 99, Tags = { "Resource", "Raw", "FrozenTundra", "Ore" } },
	{ Id = "SnowLichen", Name = "Snow Lichen", StackSize = 99, Tags = { "Resource", "Raw", "FrozenTundra" } },
	{ Id = "GlacialStone", Name = "Glacial Stone", StackSize = 99, Tags = { "Resource", "Raw", "FrozenTundra" } },
	{ Id = "ChillBloom", Name = "Chill Bloom", StackSize = 99, Tags = { "Resource", "Raw", "FrozenTundra" } },
	{ Id = "FrozenReed", Name = "Frozen Reed", StackSize = 99, Tags = { "Resource", "Raw", "FrozenTundra", "Fiber" } },
	{ Id = "FrostWolfFur", Name = "Frost Wolf Fur", StackSize = 99, Tags = { "Resource", "MonsterDrop", "FrozenTundra" } },
	{ Id = "WraithEssence", Name = "Wraith Essence", StackSize = 99, Tags = { "Resource", "MonsterDrop", "FrozenTundra" } },

	-- Volcanic raw
	{ Id = "BasaltChunk", Name = "Basalt Chunk", StackSize = 99, Tags = { "Resource", "Raw", "Volcanic" } },
	{ Id = "SulfurOre", Name = "Sulfur Ore", StackSize = 99, Tags = { "Resource", "Raw", "Volcanic", "Ore" } },
	{ Id = "ObsidianShard", Name = "Obsidian Shard", StackSize = 99, Tags = { "Resource", "Raw", "Volcanic" } },
	{ Id = "EmberBloom", Name = "Ember Bloom", StackSize = 99, Tags = { "Resource", "Raw", "Volcanic" } },
	{ Id = "AshFiber", Name = "Ash Fiber", StackSize = 99, Tags = { "Resource", "Raw", "Volcanic", "Fiber" } },
	{ Id = "LavaSalt", Name = "Lava Salt", StackSize = 99, Tags = { "Resource", "Raw", "Volcanic" } },
	{ Id = "ScoriaRock", Name = "Scoria Rock", StackSize = 99, Tags = { "Resource", "Raw", "Volcanic" } },
	{ Id = "MagmaCore", Name = "Magma Core", StackSize = 99, Tags = { "Resource", "MonsterDrop", "Volcanic" } },
	{ Id = "GolemFragment", Name = "Golem Fragment", StackSize = 99, Tags = { "Resource", "MonsterDrop", "Volcanic" } },
	{ Id = "HoundFang", Name = "Hound Fang", StackSize = 99, Tags = { "Resource", "MonsterDrop", "Volcanic" } },

	-- Crystal wastes raw
	{ Id = "CrystalShard", Name = "Crystal Shard", StackSize = 99, Tags = { "Resource", "Raw", "CrystalWastes" } },
	{ Id = "VoidResidue", Name = "Void Residue", StackSize = 99, Tags = { "Resource", "Raw", "CrystalWastes" } },
	{ Id = "AlloyDust", Name = "Alloy Dust", StackSize = 99, Tags = { "Resource", "Raw", "CrystalWastes" } },
	{ Id = "PhaseQuartz", Name = "Phase Quartz", StackSize = 99, Tags = { "Resource", "Raw", "CrystalWastes" } },
	{ Id = "PrismSand", Name = "Prism Sand", StackSize = 99, Tags = { "Resource", "Raw", "CrystalWastes" } },
	{ Id = "EchoBloom", Name = "Echo Bloom", StackSize = 99, Tags = { "Resource", "Raw", "CrystalWastes" } },
	{ Id = "LatticeFiber", Name = "Lattice Fiber", StackSize = 99, Tags = { "Resource", "Raw", "CrystalWastes", "Fiber" } },
	{ Id = "SentinelCore", Name = "Sentinel Core", StackSize = 99, Tags = { "Resource", "MonsterDrop", "CrystalWastes" } },
	{ Id = "StalkerTalon", Name = "Stalker Talon", StackSize = 99, Tags = { "Resource", "MonsterDrop", "CrystalWastes" } },
	{ Id = "NullFragment", Name = "Null Fragment", StackSize = 99, Tags = { "Resource", "MonsterDrop", "CrystalWastes" } },

	-- Aurora Vale raw
	{ Id = "AuroraFiber", Name = "Aurora Fiber", StackSize = 99, Tags = { "Resource", "Raw", "AuroraVale", "Fiber" } },
	{ Id = "DawnBloom", Name = "Dawn Bloom", StackSize = 99, Tags = { "Resource", "Raw", "AuroraVale" } },
	{ Id = "PolarQuartz", Name = "Polar Quartz", StackSize = 99, Tags = { "Resource", "Raw", "AuroraVale", "Crystal" } },
	{ Id = "AuroraAntler", Name = "Aurora Antler", StackSize = 99, Tags = { "Resource", "MonsterDrop", "AuroraVale" } },

	-- Starfall Crater raw
	{ Id = "MeteorIron", Name = "Meteor Iron", StackSize = 99, Tags = { "Resource", "Raw", "StarfallCrater", "Ore" } },
	{ Id = "ImpactGlass", Name = "Impact Glass", StackSize = 99, Tags = { "Resource", "Raw", "StarfallCrater", "Glass" } },
	{ Id = "CosmicDust", Name = "Cosmic Dust", StackSize = 99, Tags = { "Resource", "Raw", "StarfallCrater" } },
	{ Id = "MeteorCore", Name = "Meteor Core", StackSize = 99, Tags = { "Resource", "MonsterDrop", "StarfallCrater" } },

	-- Refined materials
	{ Id = "AuroraLens", Name = "Aurora Lens", StackSize = 99, Tags = { "Material", "Refined", "Lens" } },
	{ Id = "MeteorAlloy", Name = "Meteor Alloy", StackSize = 99, Tags = { "Material", "Refined", "Alloy" } },
	{ Id = "ForestPlank", Name = "Forest Plank", StackSize = 99, Tags = { "Material", "Refined" } },
	{ Id = "FiberCloth", Name = "Fiber Cloth", StackSize = 99, Tags = { "Material", "Refined", "Fiber" } },
	{ Id = "HerbalPaste", Name = "Herbal Paste", StackSize = 99, Tags = { "Material", "Refined", "Alchemy" } },
	{ Id = "TanninOil", Name = "Tannin Oil", StackSize = 99, Tags = { "Material", "Refined", "Alchemy" } },
	{ Id = "BoneMeal", Name = "Bone Meal", StackSize = 99, Tags = { "Material", "Refined" } },
	{ Id = "CactusFiber", Name = "Cactus Fiber", StackSize = 99, Tags = { "Material", "Refined", "Fiber" } },
	{ Id = "SanditeIngot", Name = "Sandite Ingot", StackSize = 99, Tags = { "Material", "Refined", "Metal" } },
	{ Id = "TemperedGlass", Name = "Tempered Glass", StackSize = 99, Tags = { "Material", "Refined", "Glass" } },
	{ Id = "HeatWrap", Name = "Heat Wrap", StackSize = 99, Tags = { "Material", "Refined" } },
	{ Id = "MarshThread", Name = "Marsh Thread", StackSize = 99, Tags = { "Material", "Refined", "Fiber" } },
	{ Id = "PeatBrick", Name = "Peat Brick", StackSize = 99, Tags = { "Material", "Refined", "Stone" } },
	{ Id = "AntitoxinPaste", Name = "Antitoxin Paste", StackSize = 99, Tags = { "Material", "Refined", "Alchemy" } },
	{ Id = "BioGel", Name = "Bio Gel", StackSize = 99, Tags = { "Material", "Refined", "Alchemy" } },
	{ Id = "MireComposite", Name = "Mire Composite", StackSize = 99, Tags = { "Material", "Refined", "Composite" } },
	{ Id = "InsulatedCloth", Name = "Insulated Cloth", StackSize = 99, Tags = { "Material", "Refined", "Fiber" } },
	{ Id = "CryoAlloy", Name = "Cryo Alloy", StackSize = 99, Tags = { "Material", "Refined", "Alloy" } },
	{ Id = "IceLens", Name = "Ice Lens", StackSize = 99, Tags = { "Material", "Refined", "Lens" } },
	{ Id = "HoarfrostPowder", Name = "Hoarfrost Powder", StackSize = 99, Tags = { "Material", "Refined", "Alchemy" } },
	{ Id = "ThermalGel", Name = "Thermal Gel", StackSize = 99, Tags = { "Material", "Refined", "Alchemy" } },
	{ Id = "ObsiditeIngot", Name = "Obsidite Ingot", StackSize = 99, Tags = { "Material", "Refined", "Metal" } },
	{ Id = "MagmaGlass", Name = "Magma Glass", StackSize = 99, Tags = { "Material", "Refined", "Glass" } },
	{ Id = "HeatPlate", Name = "Heat Plate", StackSize = 99, Tags = { "Material", "Refined", "Plate" } },
	{ Id = "VulcanLeather", Name = "Vulcan Leather", StackSize = 99, Tags = { "Material", "Refined", "Leather" } },
	{ Id = "IgnitionPowder", Name = "Ignition Powder", StackSize = 99, Tags = { "Material", "Refined", "Alchemy" } },
	{ Id = "ResonantCrystal", Name = "Resonant Crystal", StackSize = 99, Tags = { "Material", "Refined", "Crystal" } },
	{ Id = "VoidAlloy", Name = "Void Alloy", StackSize = 99, Tags = { "Material", "Refined", "Alloy" } },
	{ Id = "PhaseCircuit", Name = "Phase Circuit", StackSize = 99, Tags = { "Material", "Refined", "Circuit" } },
	{ Id = "PrismGlass", Name = "Prism Glass", StackSize = 99, Tags = { "Material", "Refined", "Glass" } },
	{ Id = "QuantumThread", Name = "Quantum Thread", StackSize = 99, Tags = { "Material", "Refined", "Fiber" } },

	-- Placeable stations
	{ Id = "Workbench", Name = "Workbench", StackSize = 1, Tags = { "Placeable", "Station" } },
	{ Id = "Furnace", Name = "Furnace", StackSize = 1, Tags = { "Placeable", "Station" } },
	{ Id = "Loom", Name = "Loom", StackSize = 1, Tags = { "Placeable", "Station" } },
	{ Id = "DryingRack", Name = "Drying Rack", StackSize = 1, Tags = { "Placeable", "Station" } },
	{ Id = "AlchemyTable", Name = "Alchemy Table", StackSize = 1, Tags = { "Placeable", "Station" } },
	{ Id = "Kiln", Name = "Kiln", StackSize = 1, Tags = { "Placeable", "Station" } },
	{ Id = "AdvancedWorkbench", Name = "Advanced Workbench", StackSize = 1, Tags = { "Placeable", "Station" } },
	{ Id = "Anvil", Name = "Anvil", StackSize = 1, Tags = { "Placeable", "Station" } },
	{ Id = "Refinery", Name = "Refinery", StackSize = 1, Tags = { "Placeable", "Station" } },
	{ Id = "SurveyBench", Name = "Survey Bench", StackSize = 1, Tags = { "Placeable", "Station" } },
	{ Id = "MasterWorkbench", Name = "Master Workbench", StackSize = 1, Tags = { "Placeable", "Station" } },

	-- Consumables
	{ Id = "Bandage", Name = "Bandage", StackSize = 30, Tags = { "Consumable", "Medical" } },
	{ Id = "AntitoxinTonic", Name = "Antitoxin Tonic", StackSize = 20, Tags = { "Consumable", "Medical" } },
	{ Id = "HeatTonic", Name = "Heat Tonic", StackSize = 20, Tags = { "Consumable", "Medical" } },
	{ Id = "ColdTonic", Name = "Cold Tonic", StackSize = 20, Tags = { "Consumable", "Medical" } },
	{ Id = "StaminaRation", Name = "Stamina Ration", StackSize = 20, Tags = { "Consumable", "Food" } },
	{ Id = "ReinforcedRation", Name = "Reinforced Ration", StackSize = 20, Tags = { "Consumable", "Food" } },
	{ Id = "ToxinFilter", Name = "Toxin Filter", StackSize = 20, Tags = { "Consumable", "Medical" } },
	{ Id = "ThermalPatch", Name = "Thermal Patch", StackSize = 20, Tags = { "Consumable", "Medical" } },

	-- Tools
	{ Id = "StoneHatchet", Name = "Stone Hatchet", StackSize = 1, Tags = { "Tool", "Holdable" } },
	{ Id = "StonePickaxe", Name = "Stone Pickaxe", StackSize = 1, Tags = { "Tool", "Holdable" } },
	{ Id = "SanditePickaxe", Name = "Sandite Pickaxe", StackSize = 1, Tags = { "Tool", "Holdable" } },
	{ Id = "MireSickle", Name = "Mire Sickle", StackSize = 1, Tags = { "Tool", "Holdable" } },
	{ Id = "CryoPickaxe", Name = "Cryo Pickaxe", StackSize = 1, Tags = { "Tool", "Holdable" } },
	{ Id = "ObsidianAxe", Name = "Obsidian Axe", StackSize = 1, Tags = { "Tool", "Holdable" } },
	{ Id = "PhaseMultitool", Name = "Phase Multitool", StackSize = 1, Tags = { "Tool", "Holdable" } },

	-- Weapons
	{ Id = "MeteorPike", Name = "Meteor Pike", StackSize = 1, Tags = { "Weapon", "Holdable" } },
	{ Id = "StoneSpear", Name = "Stone Spear", StackSize = 1, Tags = { "Weapon", "Holdable" } },
	{ Id = "BoneSpear", Name = "Bone Spear", StackSize = 1, Tags = { "Weapon", "Holdable" } },
	{ Id = "SanditeBlade", Name = "Sandite Blade", StackSize = 1, Tags = { "Weapon", "Holdable" } },
	{ Id = "MireDagger", Name = "Mire Dagger", StackSize = 1, Tags = { "Weapon", "Holdable" } },
	{ Id = "FrostLance", Name = "Frost Lance", StackSize = 1, Tags = { "Weapon", "Holdable" } },
	{ Id = "MagmaHammer", Name = "Magma Hammer", StackSize = 1, Tags = { "Weapon", "Holdable" } },
	{ Id = "CrystalBow", Name = "Crystal Bow", StackSize = 1, Tags = { "Weapon", "Holdable" } },
	{ Id = "VoidEdge", Name = "Void Edge", StackSize = 1, Tags = { "Weapon", "Holdable" } },

	-- Armor
	{ Id = "ReedSunwrap", Name = "Reed Sunwrap", StackSize = 1, Tags = { "Armor" } },
	{ Id = "AuroraMantle", Name = "Aurora Mantle", StackSize = 1, Tags = { "Armor" } },
	{ Id = "StarforgedPlate", Name = "Starforged Plate", StackSize = 1, Tags = { "Armor" } },
	{ Id = "DesertCloak", Name = "Desert Cloak", StackSize = 1, Tags = { "Armor" } },
	{ Id = "SwampWaders", Name = "Swamp Waders", StackSize = 1, Tags = { "Armor" } },
	{ Id = "FrostParka", Name = "Frost Parka", StackSize = 1, Tags = { "Armor" } },
	{ Id = "VolcanicPlate", Name = "Volcanic Plate", StackSize = 1, Tags = { "Armor" } },
	{ Id = "CrystalWeave", Name = "Crystal Weave", StackSize = 1, Tags = { "Armor" } },
	{ Id = "AdaptiveSurvivalSuit", Name = "Adaptive Survival Suit", StackSize = 1, Tags = { "Armor" } },
	{ Id = "ReviveKit", Name = "Revival Kit", StackSize = 5, Tags = { "Medical", "Revival" } },

	-- Intel/strategy devices
	{ Id = "ShiftStabilizer", Name = "Shift Stabilizer", StackSize = 1, Tags = { "Utility", "WorldControl" } },
	{ Id = "ShiftTrigger", Name = "Shift Trigger", StackSize = 1, Tags = { "Utility", "WorldControl" } },
	{ Id = "BiomeSelector", Name = "Biome Selector", StackSize = 1, Tags = { "Utility", "WorldControl" } },
	{ Id = "FieldClock", Name = "Field Clock", StackSize = 1, Tags = { "Utility", "Intel" } },
	{ Id = "BiomePredictor", Name = "Biome Predictor", StackSize = 1, Tags = { "Utility", "Intel" } },
	{ Id = "WeatherPredictor", Name = "Weather Predictor", StackSize = 1, Tags = { "Utility", "Intel" } },
	{ Id = "ThreatMeter", Name = "Threat Meter", StackSize = 1, Tags = { "Utility", "Intel" } },
	{ Id = "ResourceCompass", Name = "Resource Compass", StackSize = 1, Tags = { "Utility", "Intel" } },
	{ Id = "EventSeismograph", Name = "Event Seismograph", StackSize = 1, Tags = { "Utility", "Intel" } },
	{ Id = "PathfinderBeacon", Name = "Pathfinder Beacon", StackSize = 1, Tags = { "Utility", "Intel" } },
	{ Id = "HazardAnalyzer", Name = "Hazard Analyzer", StackSize = 1, Tags = { "Utility", "Intel" } },
}

require(script.Parent.ItemDescriptions).Apply(raw)

-- OPTIMIZED: Pre-build lookup table for O(1) access
local rawLookup = {}
for _, def in ipairs(raw) do
	rawLookup[def.Id] = def
end

local cache = {}
local _itemIconsFolder = nil

local function getItemIconsFolder()
	if _itemIconsFolder == nil then
		_itemIconsFolder = ReplicatedStorage:FindFirstChild("ItemIcons") or false
	end
	return _itemIconsFolder
end

local function resolveIcon(def)
	if def.Icon and def.Icon ~= "" then
		return def.Icon
	end
	local folder = getItemIconsFolder()
	if not folder then return nil end
	local node = folder:FindFirstChild(def.Id)
	if not node then return nil end
	if node:IsA("StringValue") then
		return node.Value
	end
	if node:IsA("ImageLabel") or node:IsA("ImageButton") then
		return node.Image
	end
	if node:IsA("Decal") or node:IsA("Texture") then
		return node.Texture
	end
	local attr = node:GetAttribute("Icon") or node:GetAttribute("Image")
	if type(attr) == "string" then
		return attr
	end
	return nil
end

function ItemDatabase:Get(id)
	if not id then return nil end
	if cache[id] then return cache[id] end
	local def = rawLookup[id]
	if def then
		local icon = resolveIcon(def)
		local item = Item.new({
			Id = def.Id,
			Name = def.Name,
			Description = def.Description,
			StackSize = def.StackSize,
			Tags = def.Tags,
			Icon = icon,
			IconColor = def.IconColor,
		})
		cache[id] = item
		return item
	end
	return nil
end

function ItemDatabase:All()
	local list = {}
	for _, def in ipairs(raw) do
		list[#list + 1] = Item.new({
			Id = def.Id,
			Name = def.Name,
			Description = def.Description,
			StackSize = def.StackSize,
			Tags = def.Tags,
			Icon = resolveIcon(def),
			IconColor = def.IconColor,
		})
	end
	return list
end

function ItemDatabase:Define(def)
	if type(def) ~= "table" or not def.Id then return end
	raw[#raw + 1] = def
	rawLookup[def.Id] = def
	cache[def.Id] = nil
end

return ItemDatabase
