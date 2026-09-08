-- Original Ecoshift geometry. No external meshes, scripts, loot, or combat stats.
-- World models are authored around a ground-level origin. Tools have welded art.
local ExpeditionModels = {}
local V = Vector3.new
local CF = CFrame.new
local A = CFrame.Angles
local RAD = math.rad
local WHITE = Color3.fromRGB(239, 235, 211)
local DARK = Color3.fromRGB(27, 34, 42)

local PALETTES = {
	Forest = { Bark = "66513C", Leaf = "52815B", Light = "93B56D", Stone = "7D8983", Soil = "77634D", Glow = "C6DD8B", Metal = "ABB3A5" },
	Desert = { Bark = "907049", Leaf = "789776", Light = "B6BB7A", Stone = "C99762", Soil = "DEC18B", Glow = "F3CB75", Metal = "C4985C" },
	Swamp = { Bark = "485B51", Leaf = "5F8370", Light = "A1B891", Stone = "64786C", Soil = "536152", Glow = "A0D4A1", Metal = "89A68F" },
	FrozenTundra = { Bark = "697E85", Leaf = "789FAD", Light = "BED8DC", Stone = "8CA9B5", Soil = "AEC0C3", Glow = "B7E5EC", Metal = "BCD5DE" },
	Volcanic = { Bark = "4B4140", Leaf = "925842", Light = "C78D5F", Stone = "554F55", Soil = "76615A", Glow = "EEAC66", Metal = "8E7770" },
	CrystalWastes = { Bark = "675D83", Leaf = "9583B4", Light = "C2B0D5", Stone = "827E9C", Soil = "AAA0AE", Glow = "C8B1EB", Metal = "B2ADC4" },
	AuroraVale = { Bark = "85969D", Leaf = "70B4B2", Light = "B6D5C6", Stone = "91AEBA", Soil = "CAD3CC", Glow = "B8E8CC", Metal = "B5D0CC" },
	StarfallCrater = { Bark = "625867", Leaf = "918195", Light = "C4B09A", Stone = "675F7C", Soil = "9A8998", Glow = "F2CEA1", Metal = "ACADBB" },
}
for _, palette in pairs(PALETTES) do
	for key, hex in pairs(palette) do palette[key] = Color3.fromHex(hex) end
end

local function shade(color, amount)
	return color:Lerp(amount < 0 and DARK or WHITE, math.abs(amount))
end

local function solid(parent, name, size, cf, color, shape, collides, material)
	local p = Instance.new(shape or "Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch = true, collides == true, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function beam(parent, name, from, to, width, depth, color, collides)
	local center = (from + to) * 0.5
	return solid(parent, name, V(width, (to - from).Magnitude, depth),
		CFrame.lookAt(center, to) * A(math.pi * 0.5, 0, 0), color, nil, collides)
end

local function glow(parent, name, size, cf, color)
	local p = solid(parent, name, size, cf, color, nil, false, Enum.Material.Neon)
	p.CastShadow = false
	return p
end

-- Four deliberately oriented corner wedges make a closed, square-pyramid crown.
local function crown(parent, center, width, height, depth, color, rotation)
	local base = CF(center) * A(0, rotation or 0, 0)
	for index = 0, 3 do
		local turn = A(0, index * math.pi * 0.5, 0)
		solid(parent, "CanopyFacet", V(width * 0.5, height, depth * 0.5),
			base * turn * CF(width * 0.25, 0, depth * 0.25), shade(color, (index - 1.5) * 0.09), "CornerWedgePart")
	end
end

-- A chiseled mass has broad painted planes, not randomly scattered little cubes.
local function boulder(parent, center, size, color, rotation)
	local base = CF(center) * A(0, rotation or 0, 0)
	solid(parent, "StoneHeart", size * V(0.66, 0.75, 0.64), base, shade(color, -0.05), nil, true)
	for index = 0, 3 do
		local side = A(0, index * math.pi * 0.5, 0)
		solid(parent, "ChiselFace", V(size.X * 0.58, size.Y, size.Z * 0.4),
			base * side * CF(0, 0, size.Z * 0.28), shade(color, index * 0.09 - 0.12), "WedgePart", true)
	end
end

local function crystal(parent, base, height, width, color, tilt, luminous)
	local cf = CF(base) * A(0, tilt and tilt.Y or 0, tilt and tilt.Z or 0)
	-- Paired triangular prisms form a long pointed crystal with a darker back face.
	solid(parent, "CrystalFace", V(width, height, width * 0.62),
		cf * CF(0, height * 0.5, 0), color, "WedgePart", true)
	solid(parent, "CrystalBack", V(width, height, width * 0.62),
		cf * CF(0, height * 0.5, -width * 0.31) * A(0, math.pi, 0), shade(color, -0.24), "WedgePart", true)
	if luminous then
		glow(parent, "MineralSeam", V(math.max(0.035, width * 0.07), height * 0.43, 0.045),
			cf * CF(width * 0.42, height * 0.34, width * 0.3), shade(color, 0.35))
	end
end

local function newWorld(name, biome, family)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("ArtFamily", family)
	model:SetAttribute("ArtVersion", 1)
	model:SetAttribute("ArtStyle", "Expedition")
	model:SetAttribute("ArtBiome", biome)
	return model
end

local function finishWorld(model)
	local primary = model:FindFirstChildWhichIsA("BasePart")
	if not primary then model:Destroy(); return nil end
	model.PrimaryPart = primary
	-- Do not add an invisible root that would distort harvesting bounds.
	primary.PivotOffset = primary.CFrame:Inverse()
	return model
end

local function tree(model, palette, variant, scale)
	scale = scale or 1
	local function pos(x, y, z) return V(x, y, z) * scale end
	local pine = variant == "Pine" or variant == "Cypress"
	local pale = variant == "Aurora"
	local trunk = pale and shade(palette.Bark, 0.3) or palette.Bark
	beam(model, "Trunk", pos(0, 0.12, 0), pos(0.2, 6.7, 0), 0.9 * scale, 0.8 * scale, trunk, true)
	for index = 0, 3 do
		local angle = index * math.pi * 0.5 + 0.3
		local radius = variant == "Mangrove" and 2.6 or 1.2
		beam(model, "ButtressRoot", pos(math.cos(angle) * radius, 0.13, math.sin(angle) * radius),
			pos(0, variant == "Mangrove" and 2.3 or 1.3, 0), 0.38 * scale, 0.36 * scale, shade(trunk, -0.1), true)
	end
	if pine then
		for layer = 0, 2 do
			local width = (5.5 - layer * 1.25) * scale
			crown(model, pos(0.1, 4.9 + layer * 1.7, 0), width, 2.7 * scale, width, shade(palette.Leaf, layer * 0.12), 0.28)
		end
	else
		beam(model, "LeftBough", pos(0, 4.0, 0), pos(-2.3, 6.5, -0.2), 0.42 * scale, 0.44 * scale, trunk)
		beam(model, "RightBough", pos(0.1, 4.5, 0), pos(2.1, 7.5, 0.25), 0.35 * scale, 0.38 * scale, trunk)
		crown(model, pos(-1.8, 6.3, 0), 5.0 * scale, 2.2 * scale, 4.6 * scale, palette.Leaf, 0.18)
		crown(model, pos(1.8, 7.3, 0.3), 4.3 * scale, 2.0 * scale, 4.0 * scale, shade(palette.Leaf, 0.14), -0.15)
		crown(model, pos(0.1, 8.2, -0.2), 4.0 * scale, 2.0 * scale, 3.9 * scale, palette.Light, 0.28)
	end
	if variant == "Willow" then
		for index = 0, 3 do
			local x = (index - 1.5) * 1.3
			solid(model, "HangingLeaf", pos(0.27, 2.3, 0.16), CF(pos(x, 5.1, 1.5)), palette.Light, "WedgePart")
		end
	elseif pale then
		glow(model, "AuroraBarkLine", pos(0.055, 1.8, 0.055), CF(pos(-0.3, 3.5, 0.39)) * A(0, 0, -0.09), palette.Glow)
	end
	solid(model, "PaintedBarkScar", pos(0.09, 1.25, 0.025), CF(pos(0.35, 2.4, 0.405)), shade(trunk, 0.24))
end

local function log(model, palette, stump, barkOnly)
	if barkOnly then
		for index = 0, 2 do
			solid(model, "BarkSlab", V(0.55, 1.7, 0.16), CF((index - 1) * 0.42, 0.84, index * 0.15) * A(0.1, 0.25, (index - 1) * 0.23),
				shade(palette.Bark, index * 0.12), "WedgePart", true)
		end
		return
	end
	local length = stump and 1.7 or 4.3
	local base = stump and CF(0, length * 0.5, 0) or CF(0, 0.7, 0) * A(0, 0, math.pi * 0.5)
	solid(model, "SplitTimber", V(1.1, length, 1.1), base, palette.Bark, nil, true)
	solid(model, "CutGrain", V(0.91, 0.055, 0.91), base * CF(0, length * 0.5 + 0.015, 0), shade(palette.Soil, 0.28))
	solid(model, "Heartwood", V(0.46, 0.065, 0.48), base * CF(-0.08, length * 0.5 + 0.04, 0.02) * A(0, 0.2, 0), palette.Bark)
	solid(model, "SplitEdge", V(0.3, length * 0.92, 0.3), base * CF(0.42, 0, 0.34), shade(palette.Bark, 0.2), "WedgePart", true)
	beam(model, "BrokenBranch", V(0.2, 0.7, 0), V(1.05, 1.6, 0.75), 0.24, 0.22, palette.Bark)
	if stump then
		for index = 0, 2 do
			local angle = index * math.pi * 2 / 3
			beam(model, "StumpRoot", V(math.cos(angle) * 1.3, 0.1, math.sin(angle) * 1.3), V(0, 0.65, 0), 0.3, 0.3, palette.Bark, true)
		end
	end
end

local function reeds(model, palette, variant)
	local fiber = variant == "Fiber"
	for index = 0, 4 do
		local angle = index * 2.399
		local height = (fiber and 1.7 or 2.65) + (index % 3) * 0.32
		local base = V(math.cos(angle) * 0.42, 0.08, math.sin(angle) * 0.42)
		local top = base + V(math.cos(angle) * 0.36, height, math.sin(angle) * 0.36)
		beam(model, "ReedStem", base, top, 0.09, 0.10, shade(palette.Leaf, -0.15))
		solid(model, "FoldedLeaf", V(0.38, height * 0.67, 0.055),
			CF(base + V(0, height * 0.43, 0)) * A(0, -angle, (index % 2 == 0 and 1 or -1) * 0.43),
			index % 2 == 0 and palette.Light or palette.Leaf, "WedgePart")
		if not fiber then
			solid(model, "SeedHead", V(0.16, 0.5, 0.17), CF(top - V(0, 0.16, 0)), shade(palette.Soil, -0.1))
		end
	end
end

local FLOWER_COLORS = {
	DawnBloom = "E8BE9A", DawnBush = "E8BE9A", EmberBloom = "D89E6F", FireFlowers = "D99D72",
	MossBloom = "B2C790", MossFlowers = "B2C790", ChillBloom = "AEDBE5", EchoBloom = "C1A8D9",
	PeachFlowers = "DAAB8C", PinkFlowers = "CE9FB4", WhiteFlowerBush = "E4DFCB", CoolFlower = "A7C9DE",
}
local function flowers(model, palette, name, bush)
	local petal = FLOWER_COLORS[name] and Color3.fromHex(FLOWER_COLORS[name]) or palette.Light
	for index = 0, 2 do
		local offset = V((index - 1) * 0.68, 0, (index % 2) * 0.48)
		local height = 1.15 + index * 0.24
		beam(model, "FlowerStem", offset + V(0, 0.06, 0), offset + V(0.12, height, 0), 0.1, 0.11, palette.Leaf)
		for wing = 0, 2 do
			local cf = CF(offset + V(0.12, height, 0)) * A(0, wing * math.pi * 2 / 3, 0)
			solid(model, "FoldedPetal", V(0.55, 0.26, 0.68), cf * CF(0, 0, 0.2), shade(petal, wing * 0.06), "WedgePart")
		end
		solid(model, "Leaf", V(0.36, 0.55, 0.06), CF(offset + V(0.18, height * 0.42, 0)) * A(0, 0.3, -0.65), palette.Light, "WedgePart")
		if name == "EchoBloom" or name == "DawnBloom" or name == "EmberBloom" or name == "QuantumFlowers" then
			glow(model, "FlowerHeart", V(0.11, 0.1, 0.11), CF(offset + V(0.12, height + 0.1, 0)), palette.Glow)
		end
	end
	if bush then crown(model, V(0, 0.47, 0.1), 2.5, 0.95, 2.1, palette.Leaf, 0.2) end
end

local function mushrooms(model, palette, luminous)
	for index = 0, 2 do
		local height = 0.75 + (index % 2) * 0.55
		local center = V((index - 1) * 0.69, height, (index % 2) * 0.45)
		solid(model, "FungusStem", V(0.2, height, 0.22), CF(center * V(1, 0.5, 1)), shade(palette.Soil, 0.42))
		local cap = luminous and palette.Light or Color3.fromRGB(154, 117, 87)
		solid(model, "CapLeft", V(0.75, 0.37, 0.8), CF(center + V(-0.22, 0, 0)), cap, "WedgePart")
		solid(model, "CapRight", V(0.75, 0.37, 0.8), CF(center + V(0.22, 0, 0)) * A(0, math.pi, 0), shade(cap, 0.15), "WedgePart")
		if luminous then glow(model, "CapGills", V(0.78, 0.045, 0.61), CF(center - V(0, 0.17, 0)), palette.Glow) end
	end
end

local function cactus(model, palette)
	solid(model, "CactusTrunk", V(0.93, 4.1, 0.82), CF(0, 2.05, 0), palette.Leaf, nil, true)
	solid(model, "SunlitRib", V(0.2, 3.75, 0.11), CF(-0.28, 2.0, 0.45), palette.Light)
	beam(model, "LeftArm", V(0, 1.5, 0), V(-1.15, 1.5, 0), 0.58, 0.57, palette.Leaf, true)
	beam(model, "LeftTip", V(-1.15, 1.4, 0), V(-1.15, 3.05, 0), 0.55, 0.55, shade(palette.Leaf, 0.1), true)
	beam(model, "RightArm", V(0, 2.5, 0), V(1.1, 2.5, 0), 0.5, 0.52, shade(palette.Leaf, -0.1), true)
	beam(model, "RightTip", V(1.1, 2.45, 0), V(1.1, 3.65, 0), 0.48, 0.5, palette.Leaf, true)
	for index = 0, 4 do
		solid(model, "IvorySpine", V(0.055, 0.26, 0.055), CF(0.34, 0.6 + index * 0.65, 0.47) * A(0.6, 0, 0.2), WHITE, "WedgePart")
	end
	solid(model, "CactusBud", V(0.35, 0.22, 0.32), CF(0, 4.17, 0), Color3.fromRGB(211, 159, 132), "WedgePart")
end

local function rootMat(model, palette)
	for index = 0, 3 do
		local angle = index * math.pi * 0.5 + 0.2
		local outward = V(math.cos(angle), 0, math.sin(angle))
		beam(model, "RootArch", outward * 1.4 + V(0, 0.12, 0), outward * 0.3 + V(0, 0.67, 0), 0.26, 0.24, shade(palette.Bark, index * 0.07), true)
		beam(model, "RootFork", outward * 0.45 + V(0, 0.6, 0), V(-outward.Z * 0.8, 0.12, outward.X * 0.8), 0.18, 0.18, palette.Bark)
	end
end

local function sediment(model, palette, variant)
	local color = variant == "Sand" and palette.Soil or shade(palette.Soil, -0.12)
	for index = 0, 2 do
		solid(model, "SedimentLayer", V(1.9 - index * 0.35, 0.22, 1.55 - index * 0.25),
			CF(index * 0.13, 0.13 + index * 0.2, -index * 0.08) * A(0, index * 0.25, 0), shade(color, index * 0.09), "WedgePart", true)
	end
	if variant == "Peat" then
		beam(model, "PeatRoot", V(-0.75, 0.44, 0.3), V(0.75, 0.55, -0.3), 0.09, 0.1, palette.Bark)
	elseif variant == "Dust" then
		for index = 0, 4 do
			local angle = index * 2.399
			solid(model, "MineralGrain", V(0.16, 0.13, 0.23), CF(math.cos(angle) * 0.48, 0.64, math.sin(angle) * 0.4),
				index % 2 == 0 and palette.Metal or palette.Glow, "WedgePart")
		end
	end
end

local function water(model, palette, marsh)
	local waterColor = marsh and Color3.fromRGB(101, 137, 123) or Color3.fromRGB(124, 183, 197)
	solid(model, "WaterSurface", V(1.8, 0.06, 1.7), CF(0, 0.21, 0) * A(0, 0.2, 0), waterColor)
	for index = 0, 5 do
		local angle = index * math.pi / 3
		solid(model, "SpringRim", V(0.9, 0.35, 0.45), CF(math.cos(angle) * 0.94, 0.18, math.sin(angle) * 0.85) * A(0, -angle, 0),
			shade(palette.Stone, (index % 3) * 0.07), "WedgePart", true)
	end
	solid(model, "SurfaceGlint", V(0.5, 0.025, 0.05), CF(-0.2, 0.255, -0.23) * A(0, -0.25, 0), shade(waterColor, 0.4))
end

local function resin(model, palette)
	log(model, palette, true)
	for index = 0, 2 do
		crystal(model, V(0.52, 0.28 + index * 0.35, 0.3), 0.36, 0.24, Color3.fromRGB(223, 164, 72), V(0, 0, -0.18), false)
	end
end

local function bones(model, palette, skull)
	local ivory = Color3.fromRGB(211, 197, 157)
	if skull then
		boulder(model, V(0, 0.7, 0), V(1.3, 1.1, 1.4), ivory, 0.2)
		for side = -1, 1, 2 do solid(model, "EyeSocket", V(0.25, 0.22, 0.04), CF(side * 0.3, 0.83, -0.73), palette.Bark) end
		solid(model, "Snout", V(0.45, 0.38, 0.7), CF(0, 0.5, -0.62), shade(ivory, 0.14), "WedgePart")
	else
		for index = 0, 1 do
			local cf = CF(0, 0.24 + index * 0.16, index * 0.42) * A(0, index == 0 and 0.32 or -0.4, 0)
			solid(model, "LongBone", V(2.0, 0.24, 0.22), cf, ivory, nil, true)
			for side = -1, 1, 2 do solid(model, "BoneJoint", V(0.37, 0.44, 0.4), cf * CF(side * 0.92, 0, 0), shade(ivory, 0.12), "WedgePart", true) end
		end
	end
end

local function ore(model, palette, name)
	local matrix = name == "Coal" and Color3.fromRGB(54, 59, 61) or palette.Stone
	boulder(model, V(0, 0.9, 0), V(2.6, 1.8, 2.2), matrix, 0.18)
	if name == "Coal" then return end
	local color = name == "SulfurOre" and Color3.fromRGB(198, 184, 107) or palette.Metal
	for index = 0, 2 do
		solid(model, "ExposedOre", V(0.37, 0.75, 0.12), CF((index - 1) * 0.52, 1.13 + (index % 2) * 0.25, -0.73) * A(-0.2, 0, 0.25 - index * 0.19),
			shade(color, index * 0.08), "WedgePart")
	end
	if name == "MeteorIron" then glow(model, "ImpactVein", V(1.05, 0.035, 0.065), CF(0, 1.63, -0.34) * A(0, 0.2, 0.12), palette.Glow) end
end

local function crystals(model, palette, name)
	local color = palette.Light
	if name == "ObsidianShard" then color = Color3.fromRGB(82, 74, 91)
	elseif name == "SunShard" then color = Color3.fromRGB(222, 178, 94)
	elseif name == "SaltCrystal" or name == "LavaSalt" then color = Color3.fromRGB(213, 207, 187)
	elseif name == "ImpactGlass" then color = Color3.fromRGB(179, 177, 196) end
	solid(model, "CrystalBed", V(2.0, 0.25, 1.65), CF(0, 0.14, 0), palette.Stone, "WedgePart", true)
	crystal(model, V(0, 0.16, 0), 2.25, 0.66, color, V(0, 0.12, 0.04), true)
	crystal(model, V(-0.62, 0.12, 0.18), 1.45, 0.48, shade(color, -0.08), V(0, -0.25, 0.22), false)
	crystal(model, V(0.6, 0.1, 0.2), 1.65, 0.49, shade(color, 0.12), V(0, 0.4, -0.25), false)
end

local RESOURCE_FAMILIES = {
	Tree = "Tree", BigTree = "BigTree", SmallTree = "SmallTree", ForestWood = "Tree",
	Frostwood = "Pine", MangroveTree = "Mangrove", MangroveWood = "Mangrove", CypressTree = "Cypress", WillowTreeSwamp = "Willow", WillowBark = "Bark",
	Mushroom = "Mushroom", BrownMushroom = "Mushroom", GlowcapCluster = "Glowcap", Glowcap = "Glowcap",
	Reed = "Reed", ReedFiber = "Reed", BogReed = "Reed", FrozenReed = "Reed",
	AshFiber = "Fiber", AuroraFiber = "Fiber", LatticeFiber = "Fiber", RootFiber = "Roots",
	MossBloom = "Flower", ChillBloom = "Flower", EmberBloom = "Flower", EchoBloom = "Flower", DawnBloom = "Flower", SnowLichen = "Lichen",
	Cactus = "Cactus", CactusStem = "Cactus", DriedBone = "Bone", SapResin = "Resin",
	SpringWater = "Water", MarshWater = "MarshWater", Mud = "Mud", ClayMud = "Mud", PeatMound = "Peat", PeatClump = "Peat",
	Sand = "Sand", PrismSand = "Dust", AlloyDust = "Dust", CosmicDust = "Dust", VoidResidue = "Void",
	Stone = "Rock", ForestStone = "Rock", Sandstone = "Rock", SandstoneChunk = "Rock", MireStone = "Rock", GlacialStone = "Rock", BasaltChunk = "Rock", ScoriaRock = "Rock",
	Coal = "Ore", SulfiteOre = "Ore", SulfurOre = "Ore", PermafrostOre = "Ore", MeteorIron = "Ore",
	SunShard = "Crystal", SaltCrystal = "Crystal", IceCrystal = "Crystal", ObsidianShard = "Crystal", LavaSalt = "Crystal",
	CrystalShard = "Crystal", PhaseQuartz = "Crystal", PolarQuartz = "Crystal", ImpactGlass = "Crystal",
}

function ExpeditionModels.CreateResource(name, biome)
	local family = RESOURCE_FAMILIES[name]
	if not family then return nil end
	local palette = PALETTES[biome] or PALETTES.Forest
	local model = newWorld(name, biome or "Forest", family)
	if family == "Tree" or family == "BigTree" or family == "SmallTree" then
		tree(model, palette, "Broadleaf", family == "BigTree" and 1.25 or family == "SmallTree" and 0.67 or 1)
	elseif family == "Pine" or family == "Mangrove" or family == "Cypress" or family == "Willow" then tree(model, palette, family)
	elseif family == "Bark" then log(model, palette, false, true)
	elseif family == "Reed" or family == "Fiber" then reeds(model, palette, family)
	elseif family == "Roots" then rootMat(model, palette)
	elseif family == "Flower" then flowers(model, palette, name)
	elseif family == "Lichen" then
		for index = 0, 2 do crown(model, V((index - 1) * 0.5, 0.16, index % 2 * 0.35), 0.95, 0.25, 0.9, shade(palette.Light, index * 0.06), index * 0.3) end
	elseif family == "Mushroom" or family == "Glowcap" then mushrooms(model, palette, family == "Glowcap")
	elseif family == "Cactus" then cactus(model, palette)
	elseif family == "Bone" then bones(model, palette)
	elseif family == "Resin" then resin(model, palette)
	elseif family == "Water" or family == "MarshWater" then water(model, palette, family == "MarshWater")
	elseif family == "Mud" or family == "Peat" or family == "Sand" or family == "Dust" then sediment(model, palette, family)
	elseif family == "Rock" then boulder(model, V(0, 0.8, 0), V(2.3, 1.6, 2.0), palette.Stone, 0.2)
	elseif family == "Ore" then ore(model, palette, name)
	elseif family == "Crystal" then crystals(model, palette, name)
	elseif family == "Void" then
		sediment(model, palette, "Dust")
		crystal(model, V(0.1, 0.48, 0), 0.65, 0.55, DARK, V(0, 0.3, 0.25), true)
	end
	return finishWorld(model)
end

local PROP_FAMILIES = {
	AuroraTree = "AuroraTree", Bush = "Bush", DawnBush = "FlowerBush", WhiteFlowerBush = "FlowerBush",
	MossFlowers = "Flower", CoolFlower = "Flower", FireFlowers = "Flower", PeachFlowers = "Flower", PinkFlowers = "Flower", QuantumFlowers = "Flower",
	BogFern = "Fern", CattailPatch = "Reed", LilyPadCluster = "Lily", RootTangle = "Roots", DeadShrub = "DeadShrub",
	FallenLog = "Log", DriftwoodLog = "Log", CraterLog = "Log", Stump = "Stump", MossyStump = "Stump",
	RockSmall = "Rock", PolarRock = "Rock", MeteorBoulder = "Meteor", ImpactSpire = "Spire", Sand = "Sand", SandDune = "Dune", Skull = "Skull",
}

function ExpeditionModels.CreateProp(name, biome)
	local family = PROP_FAMILIES[name]
	if not family then return nil end
	local palette = PALETTES[biome] or PALETTES.Forest
	local model = newWorld(name, biome or "Forest", family)
	if family == "AuroraTree" then tree(model, palette, "Aurora", 1.05)
	elseif family == "Log" or family == "Stump" then
		log(model, palette, family == "Stump")
		if name == "MossyStump" then crown(model, V(0.05, 1.83, 0.1), 1.2, 0.25, 1.1, palette.Leaf, 0.2) end
	elseif family == "Bush" then crown(model, V(0, 0.95, 0), 3.5, 1.8, 2.9, palette.Leaf, 0.25)
	elseif family == "Flower" or family == "FlowerBush" then flowers(model, palette, name, family == "FlowerBush")
	elseif family == "Fern" or family == "Reed" then reeds(model, palette, family == "Fern" and "Fiber" or "Reed")
	elseif family == "Roots" then rootMat(model, palette)
	elseif family == "Rock" or family == "Meteor" then
		boulder(model, V(0, family == "Meteor" and 1.6 or 0.65, 0), family == "Meteor" and V(3.7, 3.2, 3.2) or V(1.8, 1.3, 1.65), palette.Stone, 0.3)
		if family == "Meteor" then glow(model, "ImpactScar", V(0.045, 1.5, 0.08), CF(0.6, 1.7, -1.08) * A(0, 0, -0.2), palette.Glow) end
	elseif family == "Spire" then
		crystal(model, V(0, 0, 0), 5.4, 1.8, palette.Stone, V(0, 0.25, -0.07), false)
		crystal(model, V(1.05, 0, 0.3), 2.7, 1.0, shade(palette.Stone, 0.14), V(0, -0.2, 0.16), false)
	elseif family == "Sand" then sediment(model, palette, "Sand")
	elseif family == "Dune" then
		solid(model, "WindwardSlope", V(7.5, 1.25, 6), CF(0, 0.63, 0), palette.Soil, "WedgePart", true)
		solid(model, "LeewardSlope", V(7.5, 1.25, 2), CF(0, 0.63, 3.9) * A(0, math.pi, 0), shade(palette.Soil, -0.1), "WedgePart", true)
	elseif family == "Skull" then bones(model, palette, true)
	elseif family == "DeadShrub" then
		beam(model, "DryStem", V(0, 0.05, 0), V(0.1, 1.6, 0), 0.16, 0.17, palette.Bark)
		for side = -1, 1, 2 do
			beam(model, "DryFork", V(0, 0.8, 0), V(side * 0.75, 1.5, 0.25), 0.1, 0.1, palette.Bark)
			beam(model, "DryTwig", V(side * 0.5, 1.28, 0.2), V(side * 0.65, 1.9, 0.05), 0.07, 0.07, shade(palette.Bark, 0.2))
		end
	elseif family == "Lily" then
		for index = 0, 2 do
			local cf = CF((index - 1) * 0.92, 0.09, index % 2 * 0.7) * A(0, index * 0.8, 0)
			solid(model, "LilyLeaf", V(1.2, 0.12, 1.15), cf, shade(palette.Leaf, index * 0.06), "WedgePart")
			solid(model, "LeafVein", V(0.035, 0.022, 0.68), cf * CF(0, 0.08, 0.05), palette.Light)
		end
	end
	return finishWorld(model)
end

local TOOL_DEFS = {
	Harvester = { Family = "Pick", Biome = "Forest", Scale = 0.78 },
	StoneHatchet = { Family = "Axe", Biome = "Forest", Scale = 0.83 },
	StonePickaxe = { Family = "Pick", Biome = "Forest" },
	SanditePickaxe = { Family = "Pick", Biome = "Desert" },
	MireSickle = { Family = "Sickle", Biome = "Swamp" },
	CryoPickaxe = { Family = "Pick", Biome = "FrozenTundra", Glow = true },
	ObsidianAxe = { Family = "Axe", Biome = "Volcanic", Glow = true },
	PhaseMultitool = { Family = "Multitool", Biome = "CrystalWastes", Glow = true },
	StoneSpear = { Family = "Spear", Biome = "Forest", Scale = 0.87 },
	BoneSpear = { Family = "Spear", Biome = "Desert", Bone = true },
	SanditeBlade = { Family = "Blade", Biome = "Desert" },
	MireDagger = { Family = "Blade", Biome = "Swamp", Scale = 0.60 },
	FrostLance = { Family = "Spear", Biome = "FrozenTundra", Glow = true },
	MagmaHammer = { Family = "Hammer", Biome = "Volcanic", Glow = true },
	CrystalBow = { Family = "Bow", Biome = "CrystalWastes", Glow = true },
	VoidEdge = { Family = "Blade", Biome = "CrystalWastes", Glow = true },
	MeteorPike = { Family = "Pike", Biome = "StarfallCrater", Glow = true },
}

function ExpeditionModels.CreateTool(itemId, isWeapon)
	local def = TOOL_DEFS[itemId]
	if not def then return nil end
	local palette = PALETTES[def.Biome]
	local tool = Instance.new("Tool")
	tool.Name, tool.RequiresHandle = itemId, true
	tool:SetAttribute("ArtFamily", def.Family)
	tool:SetAttribute("ArtVersion", 1)
	tool:SetAttribute("ArtStyle", "Expedition")
	tool:SetAttribute("ArtKind", isWeapon and "Weapon" or "Tool")
	local scale = def.Scale or 1
	local handle = solid(tool, "Handle", V(0.25, 0.85, 0.26), CF(0, 0, 0), palette.Bark)
	local metal = def.Bone and WHITE or palette.Metal
	if itemId == "VoidEdge" or itemId == "ObsidianAxe" then metal = Color3.fromRGB(73, 67, 84) end
	local family = def.Family
	if family == "Spear" or family == "Pike" then
		solid(tool, "SpearShaft", V(0.2, 4.2, 0.2), CF(0, 0.6, 0), palette.Bark)
		crystal(tool, V(0, 2.35, 0), family == "Pike" and 1.6 or 1.25, 0.52, metal, V(0, 0, 0), def.Glow)
		solid(tool, "HeadBinding", V(0.31, 0.3, 0.31), CF(0, 2.32, 0), palette.Leaf)
		if family == "Pike" then
			for side = -1, 1, 2 do
				beam(tool, "PikeFork", V(side * 0.14, 2.2, 0), V(side * 0.53, 3.25, 0), 0.16, 0.2, palette.Metal)
				glow(tool, "ForkInlay", V(0.04, 0.37, 0.045), CF(side * 0.46, 3.06, 0.12), palette.Glow)
			end
		elseif def.Bone then
			for index = 0, 2 do solid(tool, "BoneBarb", V(0.25, 0.27, 0.16), CF(0.27, 2.6 + index * 0.21, 0), WHITE, "WedgePart") end
		end
	elseif family == "Pick" or family == "Multitool" then
		solid(tool, "ToolShaft", V(0.24, 2.15, 0.26), CF(0, 0.5, 0), palette.Bark)
		solid(tool, "HeadSocket", V(0.48, 0.55, 0.52), CF(0, 1.5, 0), shade(metal, -0.1))
		for side = -1, 1, 2 do
			beam(tool, "PickShoulder", V(side * 0.13, 1.65, 0), V(side * 0.85, 1.45, 0), 0.25, 0.3, metal)
			solid(tool, "PickBeak", V(0.32, 0.82, 0.3), CF(side * 0.96, 1.19, 0) * A(0, 0, side * -0.61), shade(metal, 0.15), "WedgePart")
		end
		if family == "Multitool" then
			crystal(tool, V(0, 1.64, 0), 0.76, 0.35, palette.Light, V(0, 0, 0), true)
		end
	elseif family == "Axe" then
		solid(tool, "AxeHaft", V(0.27, 2.3, 0.28), CF(0, 0.5, 0) * A(0, 0, -0.06), palette.Bark)
		solid(tool, "AxeCheek", V(1.1, 0.82, 0.32), CF(-0.36, 1.46, 0) * A(0, 0, 0.09), metal, "WedgePart")
		solid(tool, "AxeEdge", V(0.3, 1.16, 0.18), CF(-0.94, 1.35, 0) * A(0, 0, -0.12), shade(metal, 0.28), "WedgePart")
		solid(tool, "AxePoll", V(0.36, 0.44, 0.4), CF(0.25, 1.49, 0), shade(metal, -0.16))
	elseif family == "Sickle" then
		solid(tool, "SickleHaft", V(0.25, 1.7, 0.27), CF(0, 0.35, 0), palette.Bark)
		beam(tool, "HookBack", V(0, 1.15, 0), V(-0.7, 1.62, 0), 0.27, 0.18, metal)
		beam(tool, "HookCrown", V(-0.7, 1.62, 0), V(-1.25, 1.15, 0), 0.24, 0.16, metal)
		solid(tool, "HookPoint", V(0.29, 0.65, 0.12), CF(-1.22, 0.85, 0) * A(0, 0, 0.37), shade(metal, 0.2), "WedgePart")
	elseif family == "Blade" then
		solid(tool, "Crossguard", V(1.0, 0.16, 0.33), CF(0, 0.53, 0), palette.Bark)
		solid(tool, "BladeFlat", V(0.53, 2.25, 0.16), CF(0, 1.76, 0), metal)
		solid(tool, "BladePoint", V(0.53, 0.72, 0.16), CF(0, 3.13, 0), shade(metal, 0.15), "WedgePart")
		solid(tool, "SharpenedEdge", V(0.045, 2.2, 0.18), CF(-0.28, 1.79, 0), shade(metal, 0.35))
		if itemId == "VoidEdge" then glow(tool, "VoidChannel", V(0.055, 1.35, 0.025), CF(0.06, 1.96, -0.092), palette.Glow) end
	elseif family == "Hammer" then
		solid(tool, "HammerHaft", V(0.3, 2.2, 0.3), CF(0, 0.44, 0), palette.Bark)
		solid(tool, "HammerCore", V(1.7, 0.86, 0.86), CF(0, 1.6, 0), palette.Stone)
		for side = -1, 1, 2 do
			solid(tool, "HammerFace", V(0.27, 1.03, 1.02), CF(side * 0.92, 1.6, 0), shade(palette.Stone, 0.16), "WedgePart")
			glow(tool, "HeatBand", V(0.05, 0.82, 0.055), CF(side * 0.59, 1.6, -0.45), palette.Glow)
		end
	elseif family == "Bow" then
		for side = -1, 1, 2 do
			beam(tool, "BowRiser", V(0, side * 0.3, 0), V(0.68, side * 1.3, 0), 0.2, 0.24, palette.Bark)
			beam(tool, "BowLimb", V(0.68, side * 1.3, 0), V(0.17, side * 2.5, 0), 0.18, 0.22, metal)
			crystal(tool, V(0.64, side * 1.15, 0), 0.45, 0.23, palette.Light, V(0, 0, side * -0.4), false)
		end
		beam(tool, "Bowstring", V(0.17, -2.5, 0), V(0.17, 2.5, 0), 0.028, 0.028, shade(palette.Light, 0.35))
	end
	for index = 0, 3 do
		solid(tool, "GripWrap", V(0.28, 0.09, 0.29), CF(0, -0.28 + index * 0.18, 0) * A(0, 0.12, 0.04), shade(palette.Leaf, index * 0.025))
	end
	if def.Glow and family ~= "Blade" and family ~= "Bow" then
		glow(tool, "MakerInlay", V(0.055, 0.25, 0.035), CF(0, 0.7, -0.16), palette.Glow)
	end
	for _, p in ipairs(tool:GetChildren()) do
		if p:IsA("BasePart") then
			p.Size *= scale
			p.CFrame = CF(p.Position * scale) * p.CFrame.Rotation
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, false, true
			if p ~= handle then
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1, weld.Parent = handle, p, p
			end
		end
	end
	tool.Grip = CF(0, -0.08, 0) * A(0, 0, family == "Axe" and RAD(-5) or 0)
	return tool
end

-- Readable catalogs support source coverage review without instantiating models.
ExpeditionModels.ResourceFamilies = RESOURCE_FAMILIES
ExpeditionModels.PropFamilies = PROP_FAMILIES
ExpeditionModels.ToolDefinitions = TOOL_DEFS

return ExpeditionModels
