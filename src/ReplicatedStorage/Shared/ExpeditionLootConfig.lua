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
-- Only loose, soft supplies can be gathered by hand. Everything else needs a
-- tool, so missing tags or differently capitalized names cannot make ore instant.
local gatherDuration = {
	BrownMushroom = 0.6, MossBloom = 0.7, Glowcap = 0.8,
	SnowLichen = 1, ChillBloom = 0.9, EmberBloom = 1.1, EchoBloom = 1.1, DawnBloom = 0.9,
	ReedFiber = 1, BogReed = 1.2, FrozenReed = 1.4, AshFiber = 1.1,
	LatticeFiber = 1.5, AuroraFiber = 1.3,
	SpringWater = 1.4, MarshWater = 1.7, ClayMud = 1.6, Sand = 1.3,
	PrismSand = 1.6, AlloyDust = 1.6, CosmicDust = 1.8, DriedBone = 0.7,
}
local resourceHealth = {
	CactusStem = 120, ForestStone = 160, SandstoneChunk = 180, Coal = 160,
	SulfiteOre = 200, SaltCrystal = 180, SunShard = 240,
	PeatClump = 120, MireStone = 220, WillowBark = 160, RootFiber = 120, SapResin = 100,
	IceCrystal = 260, PermafrostOre = 300, GlacialStone = 260,
	BasaltChunk = 280, SulfurOre = 300, ObsidianShard = 320, ScoriaRock = 260, LavaSalt = 220,
	CrystalShard = 320, PhaseQuartz = 360, VoidResidue = 240, PolarQuartz = 320,
	MeteorIron = 400, ImpactGlass = 340,
}
function Config.ResourceProfile(item, prefabName)
	local id = item.Id
	local duration = gatherDuration[id]
	if duration then
		return { Duration = duration, Min = item:HasTag("Fiber") and 3 or 2, Max = item:HasTag("Fiber") and 5 or 4 }
	end
	if id:lower():find("wood", 1, true) then
		local health = id == "Frostwood" and 300 or id == "MangroveWood" and 260 or 240
		if prefabName == "SmallTree" then health = 180 elseif prefabName == "BigTree" then health = 320 end
		return { Health = health, Min = 5, Max = 8 }
	end
	return { Health = resourceHealth[id] or 200, Min = 2, Max = 4 }
end
return Config
