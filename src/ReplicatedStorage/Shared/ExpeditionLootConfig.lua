-- Explicit biome-local supplies. Caches ease shortages without dropping finished
-- world controls, monster trophies, or materials from an unvisited late biome.
local Config = {}
Config.CacheMaterials = {
	Forest={Raw={"ForestWood","ForestStone","ReedFiber","MossBloom"},Refined={"ForestPlank","FiberCloth","HerbalPaste"}},
	Desert={Raw={"CactusStem","SandstoneChunk","SulfiteOre","SaltCrystal"},Refined={"CactusFiber","SanditeIngot","TemperedGlass"}},
	Swamp={Raw={"BogReed","PeatClump","MireStone","Glowcap"},Refined={"MarshThread","PeatBrick","AntitoxinPaste"}},
	FrozenTundra={Raw={"Frostwood","IceCrystal","PermafrostOre","SnowLichen"},Refined={"InsulatedCloth","IceLens","HoarfrostPowder"}},
	Volcanic={Raw={"BasaltChunk","SulfurOre","ObsidianShard","EmberBloom"},Refined={"ObsiditeIngot","MagmaGlass","IgnitionPowder"}},
	CrystalWastes={Raw={"CrystalShard","PhaseQuartz","PrismSand","VoidResidue"},Refined={"PrismGlass","QuantumThread","ResonantCrystal"}},
	AuroraVale={Raw={"AuroraFiber","DawnBloom","PolarQuartz"},Refined={"InsulatedCloth","IceLens"}},
	StarfallCrater={Raw={"MeteorIron","ImpactGlass","CosmicDust"},Refined={"MagmaGlass","PrismGlass"}},
}
function Config.CacheTable(biome)
	local supplies=assert(Config.CacheMaterials[biome],"Unknown cache biome")
	local common,rare={},{}
	for _,id in ipairs(supplies.Raw) do
		table.insert(common,{Id=id,Min=2,Max=5,Weight=1})
		table.insert(rare,{Id=id,Min=4,Max=7,Weight=1})
	end
	for _,id in ipairs(supplies.Refined) do table.insert(rare,{Id=id,Min=1,Max=2,Weight=.7}) end
	return { Name=biome.."Supplies", Rarities={
		Common={Rolls=3,Unique=true,AllowDuplicates=false,Items=common,Guaranteed={{Id="Bandage",Min=1,Max=1}}},
		Rare={Rolls=4,Unique=true,AllowDuplicates=false,Items=rare,Guaranteed={{Id="StaminaRation",Min=1,Max=2},{Id="Bandage",Min=1,Max=2}}},
	} }
end
function Config.ResourceProfile(item)
	local id=item.Id
	-- Cacti use the equipped harvesting tool, like other substantial plants.
	if id=="CactusStem" then return {Health=60,Min=2,Max=4} end
	if id:find("Wood") then return {Health=60,Min=5,Max=8} end
	if item:HasTag("Ore") then return {Health=80,Min=2,Max=4} end
	if item:HasTag("Crystal") or id=="PhaseQuartz" or id=="MeteorIron" then return {Health=90,Min=2,Max=3} end
	if item:HasTag("Fiber") or id:find("Bark") then return {Duration=.85,Min=3,Max=5} end
	if id:find("Stone") or id:find("Rock") or id:find("Basalt") or id:find("Obsidian") then return {Health=60,Min=3,Max=5} end
	if item:HasTag("Liquid") then return {Duration=1.2,Min=2,Max=3} end
	return {Duration=1,Min=2,Max=4}
end
return Config
