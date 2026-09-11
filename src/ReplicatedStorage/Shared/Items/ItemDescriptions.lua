-- Player-facing uses, based on implemented effects rather than item names/tags.
local Workbench = require(script.Parent.Parent.WorkbenchConfig)
local Survival = require(script.Parent.Parent.SurvivalConfig)
local Descriptions = {}
local direct = {
	SpringWater = "Drink to remove 30 heat exposure. Gather it in Verdant Reach before entering hot biomes.",
	Harvester = "Break resource nodes to gather materials; also provides weak emergency melee defense.",
	Torch = "Place at camp to light the surrounding area.",
	Campfire = "Place a campfire at camp. It currently provides no warmth or cooking.",
	Chest = "Place at camp to store items outside your pack.",
	BrownMushroom = "Eat to restore 6 hunger, or use in medicine and food recipes.",
	CactusStem = "Eat to restore 8 hunger, or process into Cactus Fiber at a Loom or Drying Rack.",
	Bandage = "Use to restore up to 25 health.",
	AntitoxinTonic = "Adds 35% toxin resistance for 120 seconds to reduce poison exposure.",
	HeatTonic = "Adds 35% heat resistance for 120 seconds to slow overheating.",
	ColdTonic = "Adds 35% cold resistance for 120 seconds to slow chilling.",
	StaminaRation = "Eat to restore 24 hunger. Does not restore stamina.",
	ReinforcedRation = "Eat to restore 40 hunger.",
	ToxinFilter = "Adds 25% toxin resistance for 90 seconds to reduce poison exposure.",
	ThermalPatch = "Speeds recovery toward neutral body temperature and adds 20% wet resistance for 90 seconds.",
	ReviveKit = "Revives a fallen teammate with 30 health, 50 hunger, 50 stamina and neutral exposure.",
	StoneHatchet = "Break resource nodes more quickly than the starter Harvester.",
	StonePickaxe = "Break resource nodes more quickly than the starter Harvester.",
	SanditePickaxe = "Gather from resource nodes with more harvesting power than stone tools.",
	MireSickle = "Gather from resource nodes with the same harvesting power as a Sandite Pickaxe.",
	CryoPickaxe = "Break resource nodes with more harvesting power than a Sandite Pickaxe.",
	ObsidianAxe = "Break resource nodes with more harvesting power than a Cryo Pickaxe.",
	PhaseMultitool = "Break resource nodes with the highest harvesting power of the current gathering tools.",
	StoneSpear = "A basic melee weapon for fighting nearby enemies.",
	BoneSpear = "A bone melee weapon with the same base damage as a Stone Spear.",
	SanditeBlade = "A melee blade that hits harder than the starter spears.",
	MireDagger = "A melee dagger that hits harder than the starter spears.",
	FrostLance = "A melee lance that hits harder than a Sandite Blade.",
	MagmaHammer = "A heavy melee weapon that hits harder than a Frost Lance.",
	CrystalBow = "A ranged weapon; hold to charge, then release for a stronger shot.",
	VoidEdge = "A powerful melee blade that hits harder than a Magma Hammer.",
	MeteorPike = "A melee pike with the highest base damage of the current melee weapons.",
	Workbench = "Place to craft basic tools, weapons and more crafting stations.",
	AdvancedWorkbench = "Place to assemble advanced equipment and craft supported tools and weapons faster.",
	MasterWorkbench = "Place to craft top-tier equipment and speed up supported tools, weapons and armor.",
	Furnace = "Place to smelt ores and heat-process crafting materials.",
	Anvil = "Place to forge metal tools, weapons and armor.",
	Loom = "Place to weave fibers into textiles, medicines and wearable armor.",
	DryingRack = "Place to process supported food, fiber and leather recipes faster.",
	AlchemyTable = "Place to make pastes, tonics, filters and other medicines.",
	Kiln = "Place to process supported stone, glass and heated materials faster.",
	Refinery = "Place to refine alloys, circuits and crystals faster, with a chance of bonus output.",
	SurveyBench = "Place to craft forecast instruments and biome-control devices.",
	FieldClock = "Carry to reveal the time remaining until the next biome shift.",
	BiomePredictor = "Carry to reveal the next biome and the shift countdown.",
	WeatherPredictor = "Carry to reveal the next weather, next biome and shift countdown.",
	ShiftStabilizer = "Use in Survey to add 60 seconds to this biome once per shift; requires fuel and team approval.",
	ShiftTrigger = "Use in Survey to start a 15-second shift warning after the first minute; requires fuel and team approval.",
	BiomeSelector = "Use in Survey to choose the next unlocked biome; requires fuel and team approval.",
	ThreatMeter = "Not active yet. Crafting it currently grants no threat information.",
	ResourceCompass = "Not active yet. Can be used as an ingredient for a Pathfinder Beacon.",
	EventSeismograph = "Not active yet. Crafting it currently grants no event information.",
	PathfinderBeacon = "Not active yet. Crafting it currently grants no navigation benefits.",
	HazardAnalyzer = "Not active yet. Crafting it currently grants no hazard analysis.",
}

function Descriptions.Apply(items)
	local names, uses = {}, {}
	for _, item in ipairs(items) do names[item.Id] = item.Name end
	for _, recipe in pairs(Workbench.RECIPES) do
		for _, ingredient in ipairs(recipe.Ingredients or {}) do
			local output = recipe.Output and recipe.Output.Id
			if output and names[output] then
				uses[ingredient.Id] = uses[ingredient.Id] or {}
				uses[ingredient.Id][names[output]] = true
			end
		end
	end
	for _, item in ipairs(items) do
		local armor = Survival.ARMOR[item.Id]
		if direct[item.Id] then item.Description = direct[item.Id]
		elseif armor then
			local protections = {}
			for _, kind in ipairs({ { "Heat", "heat" }, { "Cold", "cold" }, { "Toxin", "toxins" }, { "Wet", "wetness" } }) do
				local amount = armor[kind[1] .. "Resistance"] or 0
				if amount > 0 then table.insert(protections, string.format("%s (%d%%)", kind[2], math.floor(amount * 100 + .5))) end
			end
			item.Description = "Equip to resist " .. table.concat(protections, ", ") .. "."
		else
			local outputs = {}
			for name in pairs(uses[item.Id] or {}) do table.insert(outputs, name) end
			table.sort(outputs)
			if #outputs > 0 then
				local examples = {}; for index = 1, math.min(3, #outputs) do table.insert(examples, outputs[index]) end
				item.Description = "Used to craft " .. table.concat(examples, ", ") .. (#outputs > 3 and " and other items." or ".")
			elseif not item.Description then item.Description = "A crafting material with no current recipe use." end
		end
	end
end
return Descriptions
