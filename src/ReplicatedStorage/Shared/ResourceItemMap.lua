local ResourceItemMap = {}

ResourceItemMap.Map = {
	-- Legacy/general aliases
	Wood = "ForestWood",
	Stone = "ForestStone",
	Reed = "ReedFiber",
	Mud = "ClayMud",
	Mushroom = "BrownMushroom",
	Bone = "DriedBone",
	Sulfite = "SulfiteOre",
	Sandite = "SulfiteOre",
	Cactus = "CactusStem",
	CactusFlesh = "CactusStem",
	CactusSpine = "ScorpionStinger",
	CactusJuice = "StaminaRation",
	DesertSalve = "AntitoxinTonic",
	Obsidite = "ObsiditeIngot",
	Sandite_Glass = "TemperedGlass",

	-- Forest
	Tree = "ForestWood",
	BigTree = "ForestWood",
	SmallTree = "ForestWood",
	MossFlowers = "MossBloom",

	-- Desert
	Sandstone = "SandstoneChunk",
	SunCrystal = "SunShard",

	-- Swamp
	PeatMound = "PeatClump",
	GlowcapCluster = "Glowcap",
	MangroveTree = "MangroveWood",
	CypressTree = "MangroveWood",
	WillowTreeSwamp = "WillowBark",

	-- Frozen Tundra
	FrostWood = "Frostwood",

	-- Volcanic
	Sulfur = "SulfurOre",

	-- Crystal Wastes
	Crystal = "CrystalShard",
}

function ResourceItemMap.Normalize(itemId)
	if type(itemId) ~= "string" or itemId == "" then
		return itemId
	end
	return ResourceItemMap.Map[itemId] or itemId
end

return ResourceItemMap
