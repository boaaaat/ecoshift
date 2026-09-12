-- Permanent expedition classes. Fractions are bonuses, not replacement multipliers.
local C = {}
C.Order = { "Generalist", "Gatherer", "Builder", "Hunter", "Medic", "Engineer", "Scout", "Cook", "Botanist", "Prospector", "Warden", "Climatologist" }
C.RequiredSeconds = { 0, 3600, 14400, 43200, 86400 }
C.UpgradePrices = { 0, 300, 900, 2400, 3600 }
C.MaxLevel = 5
local function item(id, n, replace) return { Id = id, N = n or 1, Replace = replace } end
local function def(price, description, icon, passives, ability, kits)
	return { Price = price, Description = description, Icon = icon, Passives = passives, Ability = ability, Kits = kits }
end
local ordinary = { .10, .15, .20, .25, .30 }
C.Definitions = {
	Generalist = def(0, "Adaptable survival and emergency recovery.", "compass", {
		GatherPower = {.05,.07,.09,.11,.15}, HungerReduction = {.05,.07,.09,.11,.15},
	}, { Name="Second Wind", Cooldown=180, Description="Recover health, stamina and heat/cold exposure.", Health={15,20,25}, Energy={20,25,30}, Exposure={15,20,25} }, {
		{item("Bandage"),item("SpringWater",2)}, {item("BrownMushroom",4)}, {item("Torch",2)}, {item("ReedSunwrap")}, {item("StoneSpear"),item("StaminaRation")},
	}),
	Gatherer = def(400, "Break resources faster and gather loose plants quickly.", "harvest", {
		GatherPower={.08,.12,.16,.20,.25}, GatherTimeReduction={.05,.08,.11,.14,.18},
	}, {Name="Harvest Rhythm",Cooldown=120,Description="Temporarily accelerate resource breaking and hand gathering.",Power={.25,.35,.45},GatherReduction={.20,.25,.30},Duration={12,15,18}}, {
		{item("StoneHatchet")},{item("ReedFiber",4)},{item("SpringWater",2)},{item("Bandage",2)},{item("MireSickle")},
	}),
	Builder = def(500, "Efficient construction with deployable field defenses.", "build", {
		BuildDiscount={.05,.08,.11,.14,.18},
	}, {Name="Field Deployment",Cooldown=180,Description="Choose a destructible turret or a shelter with a player-operated door. Both last 60 seconds.",Duration={60,60,60},TurretHealth={120,160,200},Damage={6,8,10},Range={50,55,60},ShelterHealth={300,400,500}}, {
		{item("ForestWood",12),item("ForestStone",8)},{item("ForestPlank",6)},{item("Chest")},{item("Workbench")},{item("SanditePickaxe")},
	}),
	Hunter = def(500, "Monster damage and focused team hunting.", "target", {
		CombatBonus={.08,.11,.14,.17,.20},
	}, {Name="Marked Prey",Cooldown=120,Description="Mark a visible monster for team damage and tracking; bosses receive half the bonus.",Bonus={.10,.15,.20},Duration={20,25,30},Range={60,60,60}}, {
		{item("StoneSpear")},{item("BrownMushroom",4)},{item("Bandage",2)},{item("ReedSunwrap")},{item("SanditeBlade",1,"StoneSpear")},
	}),
	Medic = def(600, "Medical healing and faster kit-assisted rescue.", "health", {
		HealBonus=ordinary,ReviveReduction=ordinary,
	}, {Name="Rally Pulse",Cooldown=180,Description="Heal living crew over five seconds and shorten Revival Kit interactions.",Health={20,25,30},ReviveReduction={.40,.50,.60},Duration={8,10,12},Radius={24,24,24}}, {
		{item("Bandage",2)},{item("ReviveKit")},{item("Bandage",2)},{item("ReviveKit")},{item("AntitoxinTonic"),item("StaminaRation")},
	}),
	Engineer = def(800, "Faster fabrication and shared station overclocking.", "craft", {
		CraftBonus=ordinary,
	}, {Name="Overclock",Cooldown=150,Description="Accelerate current and new crafts at a nearby crew station.",Rate={.25,.35,.45},Duration={20,25,30},Range={12,12,12}}, {
		{item("ForestWood",8),item("ForestStone",6)},{item("ForestPlank",4),item("SapResin",2)},{item("Workbench")},{item("Furnace")},{item("SanditePickaxe")},
	}),
	Scout = def(400, "Fast, economical travel and shared discoveries.", "map", {
		SpeedBonus={.03,.04,.05,.06,.08},SprintReduction={.08,.11,.14,.17,.20},
	}, {Name="Trail Scan",Cooldown=120,Description="Explore nearby terrain for the crew and temporarily mark resources, structures and monsters.",Radius={120,160,200},Duration={15,20,25}}, {
		{item("Torch",2),item("SpringWater",2)},{item("StoneSpear")},{item("SpringWater",2),item("BrownMushroom",4)},{item("ReedSunwrap")},{item("StaminaRation",2)},
	}),
	Cook = def(400, "Efficient food use and restorative crew meals.", "food", {
		HungerReduction=ordinary,FoodBonus=ordinary,
	}, {Name="Mess Call",Cooldown=240,Description="Restore nearby crew hunger and stamina over ten seconds.",Hunger={15,20,25},Energy={10,15,20},Duration={10,10,10},Radius={24,24,24}}, {
		{item("BrownMushroom",6),item("SpringWater",2)},{item("Campfire")},{item("BrownMushroom",6)},{item("DryingRack")},{item("StaminaRation",2)},
	}),
	Botanist = def(600, "Plant harvests and controlled regrowth.", "leaf", {
		PlantYield=ordinary,PlantTimeReduction=ordinary,
	}, {Name="Bloom Cycle",Cooldown=180,Description="Regrow nearby harvested plants, once per plant per shift for the entire crew.",Count={3,4,5},Radius={24,24,24}}, {
		{item("ReedFiber",6),item("MossBloom",4)},{item("Bandage")},{item("SpringWater",3)},{item("HerbalPaste",2)},{item("MireSickle"),item("AntitoxinTonic")},
	}),
	Prospector = def(600, "Stronger mineral mining and extra primary mineral finds.", "pickaxe", {
		MineralPower={.15,.20,.25,.30,.35},MineralYield={.05,.08,.11,.14,.18},
	}, {Name="Vein Sense",Cooldown=120,Description="Locate mineral nodes and briefly improve mining power.",Radius={80,100,120},Duration={15,20,25},PowerDuration={12,15,18},Power={.20,.30,.40}}, {
		{item("StonePickaxe"),item("ForestStone",8)},{item("Torch",2)},{item("Bandage",2)},{item("SpringWater",3)},{item("SanditePickaxe",1,"StonePickaxe")},
	}),
	Warden = def(600, "More health, monster protection and threat control.", "armor", {
		MaxHealth={5,10,15,20,25},MonsterReduction={.05,.07,.09,.11,.15},
	}, {Name="Hold the Line",Cooldown=150,Description="Draw up to six non-boss monsters and reduce incoming monster damage.",Radius={20,20,20},TauntDuration={6,7,8},Duration={8,10,12},Reduction={.25,.30,.35}}, {
		{item("StoneSpear"),item("Bandage")},{item("BrownMushroom",4)},{item("Bandage")},{item("ReedSunwrap")},{item("SanditeBlade",1,"StoneSpear"),item("DesertCloak",1,"ReedSunwrap")},
	}),
	Climatologist = def(800, "Resist and recover from heat and cold exposure.", "temperature", {
		ExposureReduction=ordinary,ExposureRecovery=ordinary,
	}, {Name="Shelter Field",Cooldown=180,Description="Create an area that slows heat/cold buildup and removes exposure while crew remain inside.",Radius={20,20,20},Duration={20,25,30},Reduction={.30,.40,.50},Recovery={1,1.5,2}}, {
		{item("SpringWater",4)},{item("ReedSunwrap")},{item("Torch",2)},{item("SpringWater",4)},{item("DesertCloak",1,"ReedSunwrap"),item("StaminaRation")},
	}),
}
C.PassiveLabels = {GatherPower="Resource breaking power",HungerReduction="Less hunger drain",GatherTimeReduction="Faster hand gathering",BuildDiscount="Lower building costs",CombatBonus="Monster damage",HealBonus="Medical healing",ReviveReduction="Shorter kit revives",CraftBonus="Crafting work rate",SpeedBonus="Movement speed",SprintReduction="Less sprint drain",FoodBonus="Food restoration",PlantYield="Extra plant chance",PlantTimeReduction="Faster plant gathering",MineralPower="Mineral breaking power",MineralYield="Extra mineral chance",MaxHealth="Maximum HP",MonsterReduction="Less monster damage",ExposureReduction="Less exposure buildup",ExposureRecovery="Exposure recovery"}
for id, definition in pairs(C.Definitions) do definition.Name = id end
function C.Level(level) return math.clamp(math.floor(tonumber(level) or 1),1,5) end
function C.GetPassives(id, level)
	local result = {}
	for key, values in pairs((C.Definitions[id] or C.Definitions.Generalist).Passives) do result[key] = values[C.Level(level)] end
	return result
end
function C.GetAbility(id, level)
	local definition = C.Definitions[id] or C.Definitions.Generalist
	local result = { Unlocked = C.Level(level) >= 3 }
	for key,value in pairs(definition.Ability) do result[key] = type(value)=="table" and value[math.clamp(C.Level(level)-2,1,3)] or value end
	return result
end
function C.GetKit(id, level)
	local counts, order = {}, {}
	for index=1,C.Level(level) do
		for _,entry in ipairs((C.Definitions[id] or C.Definitions.Generalist).Kits[index]) do
			if entry.Replace then counts[entry.Replace]=nil end
			if not counts[entry.Id] then table.insert(order,entry.Id) end
			counts[entry.Id]=(counts[entry.Id] or 0)+entry.N
		end
	end
	local result, emitted = {}, {}
	for _,itemId in ipairs(order) do if counts[itemId] and not emitted[itemId] then table.insert(result,{Id=itemId,N=counts[itemId]}); emitted[itemId]=true end end
	return result
end
C.Plants = { BrownMushroom=true,MossBloom=true,ReedFiber=true,Glowcap=true,BogReed=true,RootFiber=true,SnowLichen=true,ChillBloom=true,FrozenReed=true,EmberBloom=true,AshFiber=true,EchoBloom=true,LatticeFiber=true,AuroraFiber=true,DawnBloom=true }
C.Minerals = { ForestStone=true,SandstoneChunk=true,Coal=true,SulfiteOre=true,SaltCrystal=true,SunShard=true,MireStone=true,IceCrystal=true,PermafrostOre=true,GlacialStone=true,BasaltChunk=true,SulfurOre=true,ObsidianShard=true,LavaSalt=true,ScoriaRock=true,CrystalShard=true,PhaseQuartz=true,PolarQuartz=true,MeteorIron=true,ImpactGlass=true }
function C.ResourceKind(id) return C.Plants[id] and "Plant" or C.Minerals[id] and "Mineral" or "Other" end
return C
