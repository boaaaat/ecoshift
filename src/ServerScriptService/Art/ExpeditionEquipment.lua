-- Original expedition stations, protective equipment, and creature silhouettes.
-- Geometry only: callers own durability, collision bodies, Humanoids, loot and AI.
local Equipment = {}
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local WOOD = Color3.fromRGB(118, 94, 68)
local TIMBER = Color3.fromRGB(79, 73, 61)
local STEEL = Color3.fromRGB(119, 138, 139)
local LINEN = Color3.fromRGB(214, 206, 171)
local CHARCOAL = Color3.fromRGB(47, 49, 56)
local AMBER = Color3.fromRGB(232, 172, 94)
local ICE = Color3.fromRGB(167, 207, 218)
local LEAF = Color3.fromRGB(108, 142, 115)
local VIOLET = Color3.fromRGB(161, 143, 185)

local BIOME_COLORS = {
	Forest = Color3.fromRGB(108, 123, 98), Desert = Color3.fromRGB(188, 151, 99),
	Swamp = Color3.fromRGB(93, 126, 103), FrozenTundra = Color3.fromRGB(153, 186, 197),
	Volcanic = Color3.fromRGB(92, 76, 80), CrystalWastes = VIOLET,
	AuroraVale = Color3.fromRGB(146, 199, 187), StarfallCrater = Color3.fromRGB(134, 128, 152),
}

local function tint(color, value)
	return color:Lerp(value < 0 and CHARCOAL or LINEN, math.abs(value))
end

local function part(parent, name, size, cf, color, shape, collides, luminous)
	local p = Instance.new(shape or "Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Material = luminous and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch = true, collides == true, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if luminous then p.CastShadow = false end
	p.Parent = parent
	return p
end

local function beam(parent, name, from, to, width, depth, color, collides)
	return part(parent, name, V(width, (to - from).Magnitude, depth),
		CFrame.lookAt((from + to) * 0.5, to) * A(math.pi * 0.5, 0, 0), color, nil, collides)
end

local function model(name, kind)
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("ArtStyle", "Expedition")
	m:SetAttribute("ArtVersion", 1)
	m:SetAttribute("ArtKind", kind)
	return m
end

local function finish(m)
	local primary = m:FindFirstChildWhichIsA("BasePart")
	if not primary then m:Destroy(); return nil end
	m.PrimaryPart = primary
	primary.PivotOffset = primary.CFrame:Inverse()
	local _, size = m:GetBoundingBox()
	m:SetAttribute("ArtWidth", size.X)
	m:SetAttribute("ArtHeight", size.Y)
	m:SetAttribute("ArtDepth", size.Z)
	return m
end

local function shard(parent, name, base, height, width, color, rotation, luminous)
	local cf = CF(base) * (rotation or CFrame.identity)
	part(parent, name, V(width, height, width * 0.6), cf * CF(0, height * 0.5, 0), color, "WedgePart")
	part(parent, name .. "Back", V(width, height, width * 0.6), cf * CF(0, height * 0.5, -width * 0.3) * A(0, math.pi, 0), tint(color, -0.18), "WedgePart")
	if luminous then part(parent, name .. "Seam", V(0.045, height * 0.4, 0.035), cf * CF(width * 0.3, height * 0.4, width * 0.32), tint(color, 0.4), nil, false, true) end
end

local function tableFrame(m, width, depth, height, metal)
	local material = metal and STEEL or WOOD
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			part(m, "BenchLeg", V(0.32, height, 0.32), CF(x * (width * 0.5 - 0.27), height * 0.5, z * (depth * 0.5 - 0.23)), TIMBER, nil, true)
		end
	end
	for board = 0, 2 do
		part(m, "WorkSurface", V(width, 0.22, depth / 3 - 0.035), CF(0, height + 0.1, (board - 1) * depth / 3), tint(material, board * 0.045), nil, true)
	end
	beam(m, "LowerBrace", V(-width * 0.37, 0.65, depth * 0.25), V(width * 0.37, 0.65, depth * 0.25), 0.18, 0.2, TIMBER, true)
end

local function vessel(m, center, color, height)
	part(m, "VesselBody", V(0.55, height * 0.7, 0.55), CF(center + V(0, height * 0.35, 0)), color, "WedgePart")
	part(m, "VesselNeck", V(0.2, height * 0.38, 0.22), CF(center + V(0, height * 0.82, 0)), tint(color, 0.16))
	part(m, "VesselCork", V(0.23, 0.09, 0.25), CF(center + V(0, height * 1.02, 0)), WOOD)
end

local function fire(m, y, small)
	local scale = small and 0.45 or 1
	for index = 0, 2 do
		local p = part(m, "FlameFacet", V(0.8, 1.55 + index * 0.22, 0.65) * scale,
			CF((index - 1) * 0.34 * scale, y + (0.78 + index * 0.11) * scale, 0) * A(0, index * 1.9, 0),
			index == 1 and LINEN or AMBER, "WedgePart", false, true)
		p.Transparency = 0.12
	end
end

local BUILD_IDS = {
	Wall = true, Floor = true, Ramp = true, Gate = true, Tower = true, Trap = true, Machine = true,
	Workbench = true, AdvancedWorkbench = true, MasterWorkbench = true, Furnace = true, Anvil = true,
	Loom = true, DryingRack = true, AlchemyTable = true, Kiln = true, Refinery = true, SurveyBench = true,
	Campfire = true, Chest = true, Torch = true,
}

function Equipment.CreateBuild(id)
	if not BUILD_IDS[id] then return nil end
	local m = model(id, "Build")
	if id == "Floor" then
		for index = 0, 5 do part(m, "FloorBoard", V(0.94, 0.28, 5.8), CF(-2.42 + index * 0.97, 0.14, 0), tint(WOOD, (index % 3) * 0.045), nil, true) end
	elseif id == "Wall" then
		for index = 0, 5 do part(m, "WallPlank", V(0.91, 4.15, 0.27), CF(-2.36 + index * 0.94, 2.08, 0), tint(WOOD, (index % 3) * 0.05), nil, true) end
		for y = 0.65, 3.65, 3 do part(m, "WallBrace", V(5.75, 0.22, 0.21), CF(0, y, 0.22), TIMBER, nil, true) end
		beam(m, "DiagonalBrace", V(-2.5, 0.5, -0.21), V(2.5, 3.8, -0.21), 0.2, 0.18, TIMBER)
	elseif id == "Ramp" then
		part(m, "RampSlope", V(5.7, 2.55, 5.7), CF(0, 1.275, 0), WOOD, "WedgePart", true)
		for index = 0, 5 do
			local z = -2.35 + index * 0.94
			part(m, "TractionSlat", V(5.72, 0.12, 0.16), CF(0, 1.275 + z * (2.55 / 5.7) + 0.09, z) * A(math.atan(2.55 / 5.7), 0, 0), tint(TIMBER, 0.1), nil, true)
		end
	elseif id == "Gate" then
		for side = -1, 1, 2 do
			part(m, "GatePost", V(0.48, 4.7, 0.48), CF(side * 2.4, 2.35, 0), TIMBER, nil, true)
			part(m, "GateSidePanel", V(0.95, 2.3, 0.24), CF(side * 1.72, 1.15, 0), WOOD, nil, true)
		end
		part(m, "GateLintel", V(5.65, 0.4, 0.62), CF(0, 4.47, 0), WOOD, nil, true)
		part(m, "TrailMark", V(0.47, 0.38, 0.045), CF(0, 4.44, -0.34) * A(0, 0, 0.3), LEAF, "WedgePart")
	elseif id == "Tower" then
		for x = -1, 1, 2 do for z = -1, 1, 2 do
			part(m, "TowerPost", V(0.35, 8.0, 0.35), CF(x * 2.05, 4, z * 2.05), TIMBER, nil, true)
		end end
		part(m, "LookoutDeck", V(4.8, 0.25, 4.8), CF(0, 5.8, 0), WOOD, nil, true)
		for side = -1, 1, 2 do
			part(m, "SideRail", V(0.2, 0.18, 4.5), CF(side * 2.15, 7.2, 0), WOOD, nil, true)
			beam(m, "TowerBrace", V(side * 2.0, 0.4, -2.05), V(-side * 2.0, 5.55, -2.05), 0.18, 0.18, TIMBER)
		end
		part(m, "RearRail", V(4.5, 0.18, 0.2), CF(0, 7.2, 2.15), WOOD, nil, true)
		part(m, "Ladder", V(1.0, 5.8, 0.4), CF(0, 2.9, -2.28), TIMBER, "TrussPart", true)
	elseif id == "Trap" then
		for index = 0, 2 do part(m, "TrapBase", V(3.6, 0.14, 0.8), CF(0, 0.07, (index - 1) * 0.84), TIMBER, nil, true) end
		part(m, "PressurePlate", V(1.6, 0.12, 1.25), CF(0, 0.19, 0), STEEL)
		for side = -1, 1, 2 do
			part(m, "TrapJaw", V(0.16, 0.27, 2.65), CF(side * 1.35, 0.4, 0), STEEL)
			for index = 0, 2 do part(m, "TrapTooth", V(0.42, 0.52, 0.27), CF(side * 1.12, 0.57, (index - 1) * 0.76) * A(0, 0, side * 0.3), tint(STEEL, 0.2), "WedgePart") end
		end
	elseif id == "Workbench" or id == "AdvancedWorkbench" or id == "MasterWorkbench" then
		local advanced = id ~= "Workbench"
		tableFrame(m, 4.8, 2.9, 2.35, advanced)
		part(m, "ToolTray", V(1.65, 0.11, 0.75), CF(-1.0, 2.65, 0.6), TIMBER)
		part(m, "BenchVise", V(0.6, 0.35, 0.62), CF(1.85, 2.7, -0.82), advanced and STEEL or CHARCOAL)
		beam(m, "ViceHandle", V(1.3, 2.7, -1.14), V(2.2, 2.7, -1.14), 0.1, 0.1, STEEL)
		if id == "Workbench" then
			part(m, "CarvingBlock", V(0.95, 0.2, 0.65), CF(0.3, 2.6, -0.2) * A(0, 0.3, 0), tint(WOOD, 0.25), "WedgePart")
		elseif id == "AdvancedWorkbench" then
			part(m, "CalibrationBoard", V(2.0, 0.17, 1.25), CF(0, 2.6, -0.3), LEAF)
			part(m, "CaliperRail", V(1.4, 0.1, 0.12), CF(0, 2.74, -0.38), LINEN)
			for side = -1, 1, 2 do part(m, "CaliperJaw", V(0.12, 0.16, 0.48), CF(side * 0.48, 2.79, -0.32), STEEL) end
		else
			part(m, "AssemblyPlinth", V(1.8, 0.25, 1.6), CF(0, 2.66, -0.25), CHARCOAL)
			shard(m, "ResonanceJig", V(0, 2.8, -0.25), 1.05, 0.56, ICE, A(0, 0.35, 0), true)
			for side = -1, 1, 2 do beam(m, "JigArm", V(side * 0.85, 2.8, -0.25), V(side * 0.4, 3.45, -0.25), 0.14, 0.18, STEEL) end
		end
	elseif id == "Anvil" then
		part(m, "AnvilStump", V(2.0, 1.45, 1.8), CF(0, 0.725, 0), TIMBER, nil, true)
		part(m, "AnvilFoot", V(2.25, 0.22, 1.55), CF(0, 1.55, 0), CHARCOAL, nil, true)
		part(m, "AnvilWaist", V(1.1, 0.62, 0.85), CF(0, 1.92, 0), STEEL, "WedgePart", true)
		part(m, "StrikingFace", V(2.2, 0.3, 0.98), CF(-0.15, 2.35, 0), tint(STEEL, 0.2), nil, true)
		part(m, "AnvilHorn", V(0.85, 0.28, 0.8), CF(1.3, 2.34, 0) * A(0, math.pi * 0.5, 0), STEEL, "WedgePart", true)
	elseif id == "Furnace" or id == "Kiln" then
		local kiln = id == "Kiln"
		local color = kiln and Color3.fromRGB(167, 119, 88) or tint(STEEL, -0.32)
		local height = kiln and 2.25 or 3.1
		part(m, "HearthBase", V(3.5, 0.25, 3.1), CF(0, 0.125, 0), CHARCOAL, nil, true)
		for side = -1, 1, 2 do part(m, "HearthWall", V(0.65, height, 2.85), CF(side * 1.28, 0.25 + height * 0.5, 0), color, nil, true) end
		part(m, "HearthBack", V(2.4, height, 0.45), CF(0, 0.25 + height * 0.5, 1.3), tint(color, -0.1), nil, true)
		part(m, "HearthArch", V(3.15, 0.52, 3.0), CF(0, height + 0.26, 0), tint(color, 0.16), "WedgePart", true)
		part(m, "DarkFirebox", V(1.65, 1.3, 0.08), CF(0, 1.12, -1.08), CHARCOAL)
		for index = 0, 2 do part(m, "HearthCoal", V(0.38, 0.23, 0.45), CF((index - 1) * 0.45, 0.47, -0.9), AMBER, "WedgePart", false, true) end
		part(m, "Chimney", kiln and V(0.75, 0.55, 0.75) or V(0.85, 1.55, 0.85), CF(0, height + (kiln and 0.76 or 1.22), 0.75), color, nil, true)
		if not kiln then
			part(m, "Bellows", V(0.55, 0.85, 1.35), CF(1.78, 0.74, -0.1), WOOD, "WedgePart", true)
		else part(m, "ClayTile", V(0.85, 0.12, 0.6), CF(-0.7, 0.43, -1.68), tint(color, 0.2), "WedgePart") end
	elseif id == "Loom" then
		for side = -1, 1, 2 do
			part(m, "LoomPost", V(0.28, 3.5, 0.32), CF(side * 1.45, 1.75, 0), TIMBER, nil, true)
			part(m, "LoomFoot", V(0.65, 0.2, 2.05), CF(side * 1.45, 0.1, 0), WOOD, nil, true)
		end
		for y = 0.8, 3.3, 2.5 do part(m, "LoomBeam", V(3.1, 0.22, 0.32), CF(0, y, 0), WOOD, nil, true) end
		for index = 0, 5 do part(m, "WarpThread", V(0.045, 2.45, 0.04), CF(-1.04 + index * 0.416, 2.05, -0.04), LINEN) end
		part(m, "WovenCloth", V(2.28, 1.15, 0.1), CF(0, 1.35, -0.08), LEAF)
		part(m, "ClothHem", V(2.3, 0.12, 0.13), CF(0, 0.82, -0.1), LINEN)
	elseif id == "DryingRack" then
		for side = -1, 1, 2 do
			beam(m, "RackLeg", V(side * 1.8, 0, -1.0), V(side * 1.5, 3.15, 0), 0.22, 0.25, TIMBER, true)
			beam(m, "RackLeg", V(side * 1.8, 0, 1.0), V(side * 1.5, 3.15, 0), 0.22, 0.25, TIMBER, true)
		end
		part(m, "DryingRail", V(3.8, 0.25, 0.28), CF(0, 3.02, 0), WOOD, nil, true)
		for index = 0, 2 do
			part(m, "HangingHide", V(0.75, 1.72 - index * 0.2, 0.09), CF((index - 1) * 1.0, 2.05, -0.08), tint(WOOD, index * 0.16), "WedgePart")
			part(m, "HideTie", V(0.045, 0.4, 0.04), CF((index - 1) * 1.0, 2.92, -0.07), LINEN)
		end
	elseif id == "AlchemyTable" then
		tableFrame(m, 4.3, 2.5, 2.2)
		part(m, "MixingTray", V(2.8, 0.1, 1.45), CF(0, 2.48, -0.2), tint(LEAF, -0.15))
		vessel(m, V(-0.95, 2.55, -0.3), LEAF, 0.85)
		vessel(m, V(0.25, 2.55, -0.45), ICE, 1.05)
		vessel(m, V(1.25, 2.55, 0.1), AMBER, 0.65)
		part(m, "GrindingBowl", V(0.82, 0.24, 0.7), CF(-0.5, 2.65, 0.62), STEEL, "WedgePart")
	elseif id == "Refinery" or id == "Machine" then
		local refinery = id == "Refinery"
		part(m, "MachineSkid", V(4.4, 0.32, 3.25), CF(0, 0.16, 0), CHARCOAL, nil, true)
		for side = -1, 1, 2 do
			part(m, "ProcessingColumn", V(1.05, refinery and 3.5 or 2.7, 1.05), CF(side * 1.2, refinery and 2.0 or 1.6, 0.35), STEEL, nil, true)
			for index = 0, 2 do part(m, "ColumnBand", V(1.16, 0.13, 1.15), CF(side * 1.2, 0.8 + index * 0.8, 0.35), CHARCOAL) end
			part(m, "PressureWindow", V(0.2, 0.65, 0.04), CF(side * 1.2, 1.85, -0.195), side == -1 and AMBER or ICE, nil, false, true)
		end
		beam(m, "TransferConduit", V(-1.15, 3.12, 0.35), V(1.15, 3.12, 0.35), 0.2, 0.25, TIMBER)
		part(m, "ControlConsole", V(1.0, 0.62, 0.8), CF(0, 1.55, -1.05), tint(STEEL, -0.13), "WedgePart", true)
		if not refinery then shard(m, "PowerSpindle", V(0, 0.5, 0.2), 1.8, 0.6, VIOLET, A(0, 0.25, 0), true) end
	elseif id == "SurveyBench" then
		tableFrame(m, 4.7, 2.8, 2.2)
		local mapCf = CF(-0.45, 2.62, -0.12) * A(-0.16, 0, 0)
		part(m, "SurveyMap", V(2.6, 0.1, 1.9), mapCf, LINEN)
		for index = 0, 2 do part(m, "MapContour", V(1.6 - index * 0.28, 0.017, 0.045), mapCf * CF(-0.1, 0.06, -0.5 + index * 0.42) * A(0, index * 0.22, 0), LEAF) end
		beam(m, "SightStand", V(1.4, 2.4, 0.45), V(1.4, 3.35, 0.45), 0.15, 0.17, STEEL)
		beam(m, "SurveySight", V(1.4, 3.37, 0.85), V(1.4, 3.65, -0.65), 0.28, 0.32, TIMBER)
		part(m, "SightLens", V(0.32, 0.31, 0.065), CF(1.4, 3.66, -0.7) * A(-0.18, 0, 0), ICE)
	elseif id == "Campfire" then
		for index = 0, 5 do
			local angle = index * math.pi / 3
			part(m, "FireRing", V(0.8, 0.45, 0.6), CF(math.cos(angle) * 1.35, 0.23, math.sin(angle) * 1.35) * A(0, -angle, 0), tint(STEEL, -0.15 + index % 2 * 0.12), "WedgePart", true)
		end
		for side = -1, 1, 2 do part(m, "FireLog", V(2.05, 0.35, 0.38), CF(0, 0.25, 0) * A(0, side * 0.65, 0), TIMBER, nil, true) end
		fire(m, 0.28)
	elseif id == "Chest" then
		part(m, "ChestBox", V(3.9, 1.85, 2.4), CF(0, 0.925, 0), WOOD, nil, true)
		part(m, "ChestLid", V(4.05, 0.46, 2.53), CF(0, 2.02, 0), tint(WOOD, 0.16), "WedgePart", true)
		for side = -1, 1, 2 do
			part(m, "IronBand", V(0.17, 2.05, 2.54), CF(side * 1.24, 1.03, 0), CHARCOAL)
			part(m, "CarryHandle", V(0.16, 0.38, 0.76), CF(side * 2.02, 1.18, 0), STEEL)
		end
		part(m, "ChestLatch", V(0.43, 0.59, 0.17), CF(0, 1.69, -1.28), AMBER)
	elseif id == "Torch" then
		part(m, "TorchStake", V(0.22, 3.8, 0.25), CF(0, 1.9, 0), TIMBER, nil, true)
		part(m, "TorchBrazier", V(0.67, 0.4, 0.65), CF(0, 3.72, 0), CHARCOAL, "WedgePart")
		fire(m, 3.85, true)
	end
	return finish(m)
end

local ARMOR_DEFS = {
	ReedSunwrap = { Color = Color3.fromRGB(203, 192, 139), Trim = Color3.fromRGB(104, 134, 88), Kind = "Sunwrap" },
	DesertCloak = { Color = Color3.fromRGB(196, 171, 125), Trim = LEAF, Kind = "Cloak" },
	SwampWaders = { Color = Color3.fromRGB(76, 109, 98), Trim = LINEN, Kind = "Waders" },
	FrostParka = { Color = Color3.fromRGB(119, 157, 176), Trim = LINEN, Kind = "Parka" },
	VolcanicPlate = { Color = Color3.fromRGB(83, 76, 84), Trim = AMBER, Kind = "Plate" },
	CrystalWeave = { Color = VIOLET, Trim = ICE, Kind = "Weave" },
	AdaptiveSurvivalSuit = { Color = Color3.fromRGB(83, 113, 111), Trim = ICE, Kind = "Adaptive" },
	AuroraMantle = { Color = Color3.fromRGB(140, 192, 177), Trim = Color3.fromRGB(217, 185, 163), Kind = "Mantle" },
	StarforgedPlate = { Color = Color3.fromRGB(132, 137, 156), Trim = AMBER, Kind = "Starplate" },
}

function Equipment.CreateArmor(id)
	local def = ARMOR_DEFS[id]
	if not def then return nil end
	local accessory = Instance.new("Accessory")
	accessory.Name = id
	accessory.AccessoryType = Enum.AccessoryType.Front
	accessory:SetAttribute("ArtStyle", "Expedition")
	accessory:SetAttribute("ArtVersion", 1)
	accessory:SetAttribute("ArtKind", "Armor")
	-- Attachment sits against the torso front; positive Z art wraps toward its back.
	local sunwrap = def.Kind == "Sunwrap"
	local handle = part(accessory, "Handle", sunwrap and V(1.36, 0.65, 0.13) or V(1.5, 1.3, 0.19), CF(0, 0, 0), def.Color)
	local attachment = Instance.new("Attachment")
	attachment.Name = "BodyFrontAttachment"
	attachment.CFrame = CF(0, 0, 0.15)
	attachment.Parent = handle
	if sunwrap then
		-- A short woven shoulder shade and asymmetrical moss tie, without plated sides.
		for side = -1, 1, 2 do
			part(accessory, "ReedShoulderShade", V(0.78, 0.17, 0.91), CF(side * 0.78, 0.6, 0.35) * A(0, 0, side * -0.15), def.Color, "WedgePart")
			part(accessory, "ShortReedCape", V(0.84, 0.8, 0.1), CF(side * 0.42, 0.17, 1.13) * A(-0.1, 0, side * 0.12), tint(def.Color, side * 0.06), "WedgePart")
		end
		for index = -2, 2 do
			part(accessory, "WovenReed", V(0.055, 0.61, 0.045), CF(index * 0.24, 0, -0.09) * A(0, 0, -0.2), tint(def.Color, -0.16))
		end
		part(accessory, "MossTie", V(0.25, 1.12, 0.09), CF(-0.14, 0.1, -0.15) * A(0, 0, -0.6), def.Trim, "WedgePart")
		part(accessory, "ResinKnot", V(0.18, 0.18, 0.1), CF(0.12, 0.43, -0.21), AMBER, "WedgePart")
	else
		for side = -1, 1, 2 do
			part(accessory, "SidePanel", V(0.3, 1.18, 0.67), CF(side * 0.82, -0.05, 0.27) * A(0, 0, side * -0.04), tint(def.Color, -0.14), "WedgePart")
			part(accessory, "ShoulderPanel", V(0.61, 0.23, 0.8), CF(side * 0.81, 0.61, 0.29) * A(0, 0, side * -0.12), tint(def.Color, 0.12), "WedgePart")
		end
		part(accessory, "FieldBelt", V(1.68, 0.16, 0.15), CF(0, -0.53, -0.13), TIMBER)
		part(accessory, "BeltClasp", V(0.24, 0.21, 0.1), CF(0, -0.53, -0.24), def.Trim)
	end
	if def.Kind == "Cloak" or def.Kind == "Mantle" then
		for side = -1, 1, 2 do
			part(accessory, "SplitCape", V(0.86, 1.85, 0.13), CF(side * 0.43, -0.27, 1.21) * A(-0.08, 0, side * 0.07), tint(def.Color, side == -1 and -0.07 or 0.1), "WedgePart")
			part(accessory, "ShawlFold", V(0.83, 0.62, 0.14), CF(side * 0.39, 0.38, -0.18) * A(0, 0, side * 0.33), def.Trim, "WedgePart")
		end
		part(accessory, "MantleBrooch", V(0.19, 0.25, 0.11), CF(0, 0.36, -0.3), def.Trim, "WedgePart", false, def.Kind == "Mantle")
	elseif def.Kind == "Waders" then
		for side = -1, 1, 2 do
			-- Rigid waist tabs end above the forward thigh during a standard walk.
			part(accessory, "OilskinApron", V(0.64, 0.34, 0.12), CF(side * 0.36, -0.58, 0.03), tint(def.Color, -0.04), "WedgePart")
			part(accessory, "BibStrap", V(0.14, 1.02, 0.13), CF(side * 0.48, 0.16, -0.16), def.Trim)
		end
		part(accessory, "WaterproofPocket", V(0.72, 0.42, 0.15), CF(0, -0.09, -0.2), tint(def.Color, 0.18))
	elseif def.Kind == "Parka" then
		for side = -1, 1, 2 do
			part(accessory, "FurCollar", V(0.7, 0.35, 0.31), CF(side * 0.36, 0.64, 0.02) * A(0, 0, side * 0.16), def.Trim, "WedgePart")
			part(accessory, "ParkaPocket", V(0.45, 0.37, 0.13), CF(side * 0.41, -0.21, -0.19), tint(def.Color, 0.17))
		end
		part(accessory, "ParkaClosure", V(0.065, 1.2, 0.045), CF(0, 0, -0.15), LINEN)
	elseif def.Kind == "Plate" or def.Kind == "Starplate" then
		for index = 0, 2 do
			part(accessory, "OverlappingPlate", V(1.34 - index * 0.13, 0.42, 0.15), CF(0, 0.37 - index * 0.36, -0.17 - index * 0.025), tint(def.Color, index * 0.06), "WedgePart")
		end
		for side = -1, 1, 2 do
			part(accessory, "PauldronRidge", V(0.45, 0.42, 0.82), CF(side * 0.96, 0.65, 0.28), tint(def.Color, 0.2), "WedgePart")
			part(accessory, "HeatInlay", V(0.045, 0.58, 0.025), CF(side * 0.49, 0.12, -0.285), def.Trim, nil, false, true)
		end
		if def.Kind == "Starplate" then part(accessory, "MeteorTasset", V(1.15, 0.32, 0.15), CF(0, -0.59, 0), tint(def.Color, -0.1), "WedgePart") end
	elseif def.Kind == "Weave" then
		for side = -1, 1, 2 do
			part(accessory, "PrismChestFacet", V(0.65, 0.83, 0.12), CF(side * 0.31, 0.11, -0.16) * A(0, 0, side * 0.17), tint(def.Color, side == -1 and 0.16 or -0.1), "WedgePart")
			part(accessory, "WeaveRibbon", V(0.2, 1.65, 0.1), CF(side * 0.65, -0.34, 1.16), def.Trim, "WedgePart")
		end
	elseif def.Kind == "Adaptive" then
		part(accessory, "FilterPack", V(0.64, 0.98, 0.38), CF(0, 0.07, 1.24), tint(def.Color, -0.14))
		for side = -1, 1, 2 do part(accessory, "UtilityPocket", V(0.42, 0.47, 0.2), CF(side * 0.48, -0.14, -0.22), tint(def.Color, 0.14)) end
		for index = 0, 2 do part(accessory, "ConditionInlay", V(0.08, 0.16, 0.04), CF(-0.19 + index * 0.19, 0.38, -0.14), index == 0 and AMBER or index == 1 and ICE or LEAF, nil, false, true) end
	end
	for _, p in ipairs(accessory:GetChildren()) do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, false, true
			if p ~= handle then
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1, weld.Parent = handle, p, p
			end
		end
	end
	return accessory
end

-- Creature visuals face -Z. Their pose is authored around the ground origin.
local function eyes(m, center, spacing, color, luminous, size)
	size = size or 0.12
	for side = -1, 1, 2 do part(m, "Eye", V(size, size * 0.8, 0.045), CF(center + V(side * spacing, 0, 0)), color, nil, false, luminous) end
end

local function leg(m, hip, knee, foot, width, color, hoof)
	beam(m, "UpperLeg", hip, knee, width, width * 0.88, color)
	beam(m, "LowerLeg", knee, foot + V(0, 0.13, 0), width * 0.72, width * 0.68, tint(color, -0.1))
	part(m, hoof and "Hoof" or "Foot", V(width * 1.3, 0.26, width * 1.65), CF(foot + V(0, 0.13, -width * 0.18)), hoof and CHARCOAL or tint(color, -0.12), "WedgePart")
end

local function canine(m, color, variant)
	local frost, magma = variant == "Frost", variant == "Magma"
	local height = magma and 1.7 or 1.75
	part(m, "CanineBody", V(magma and 1.45 or 1.12, 1.02, 2.45), CF(0, height, 0.1), color, "WedgePart")
	part(m, "ShoulderMass", V(magma and 1.58 or 1.25, 1.22, 1.25), CF(0, height + 0.17, -0.65), tint(color, 0.1), "WedgePart")
	for side = -1, 1, 2 do
		leg(m, V(side * 0.43, height, -0.8), V(side * 0.5, 0.85, -0.68), V(side * 0.5, 0, -0.95), magma and 0.39 or 0.26, color)
		leg(m, V(side * 0.45, height, 0.86), V(side * 0.53, 0.83, 1.16), V(side * 0.5, 0, 0.95), magma and 0.37 or 0.25, color)
	end
	part(m, "CanineNeck", V(0.9, 1.15, 0.83), CF(0, 2.13, -1.17) * A(-0.28, 0, 0), tint(color, 0.07), "WedgePart")
	part(m, "CanineHead", V(0.94, 0.68, 0.97), CF(0, 2.47, -1.56), color, "WedgePart")
	part(m, "Muzzle", V(0.54, 0.34, 0.65), CF(0, 2.3, -2.11), tint(color, 0.18), "WedgePart")
	part(m, "Nose", V(0.28, 0.18, 0.12), CF(0, 2.38, -2.45), CHARCOAL)
	eyes(m, V(0, 2.58, -2.0), 0.32, magma and AMBER or CHARCOAL, magma)
	for side = -1, 1, 2 do part(m, "PointedEar", V(0.26, 0.53, 0.24), CF(side * 0.33, 2.97, -1.44) * A(0.14, 0, side * -0.1), tint(color, -0.1), "WedgePart") end
	beam(m, "TailRoot", V(0, 1.95, 1.17), V(0.18, 1.61, 1.95), 0.38, 0.36, color)
	beam(m, "TailTip", V(0.18, 1.61, 1.95), V(0.26, 1.06, 2.37), 0.25, 0.25, tint(color, -0.15))
	if frost then
		for side = -1, 1, 2 do part(m, "FrostMane", V(0.62, 1.1, 0.78), CF(side * 0.5, 2.3, -1.0) * A(0, 0, side * -0.22), LINEN, "WedgePart") end
		part(m, "FrostRidge", V(0.5, 0.34, 1.75), CF(0, 2.36, 0.05), ICE, "WedgePart")
	elseif magma then
		for index = 0, 2 do
			part(m, "CinderBackPlate", V(1.13, 0.42, 0.53), CF(0, 2.32, -0.4 + index * 0.55), tint(color, -0.18), "WedgePart")
			part(m, "EmberFault", V(0.63, 0.035, 0.04), CF(0, 2.54, -0.46 + index * 0.55), AMBER, nil, false, true)
		end
	end
end

local function stag(m, color)
	part(m, "StagBody", V(1.15, 1.1, 2.25), CF(0, 2.55, 0.15), color, "WedgePart")
	part(m, "WhiteChest", V(0.8, 1.05, 0.8), CF(0, 2.53, -0.85), LINEN, "WedgePart")
	for side = -1, 1, 2 do
		leg(m, V(side * 0.39, 2.65, -0.66), V(side * 0.45, 1.29, -0.58), V(side * 0.46, 0, -0.83), 0.21, color, true)
		leg(m, V(side * 0.39, 2.53, 0.9), V(side * 0.48, 1.23, 1.2), V(side * 0.46, 0, 0.85), 0.22, color, true)
	end
	beam(m, "StagNeck", V(0, 2.65, -0.75), V(0, 3.88, -1.25), 0.61, 0.67, tint(color, 0.12))
	part(m, "StagHead", V(0.68, 0.61, 1.1), CF(0, 4.02, -1.54), color, "WedgePart")
	part(m, "StagMuzzle", V(0.45, 0.29, 0.48), CF(0, 3.86, -2.1), tint(color, -0.15), "WedgePart")
	eyes(m, V(0, 4.13, -1.97), 0.24, CHARCOAL)
	for side = -1, 1, 2 do
		part(m, "StagEar", V(0.65, 0.2, 0.31), CF(side * 0.57, 4.16, -1.2) * A(0, side * 0.35, side * 0.2), tint(color, 0.2), "WedgePart")
		beam(m, "AntlerStem", V(side * 0.22, 4.28, -1.2), V(side * 0.69, 5.15, -0.97), 0.16, 0.17, LINEN)
		beam(m, "AntlerCrown", V(side * 0.69, 5.15, -0.97), V(side * 1.12, 5.62, -1.0), 0.12, 0.13, LINEN)
		beam(m, "AntlerTine", V(side * 0.49, 4.84, -1.06), V(side * 0.82, 5.13, -1.58), 0.1, 0.11, ICE)
		beam(m, "AntlerTine", V(side * 0.86, 5.34, -0.97), V(side * 0.72, 5.74, -1.23), 0.08, 0.09, ICE)
	end
	part(m, "StagTail", V(0.32, 0.56, 0.3), CF(0, 2.63, 1.4) * A(-0.35, 0, 0), LINEN, "WedgePart")
end

local function scorpion(m, color)
	part(m, "ScorpionCarapace", V(1.6, 0.67, 1.85), CF(0, 0.82, 0.1), color, "WedgePart")
	for index = 0, 2 do part(m, "BackSegment", V(1.25 - index * 0.15, 0.43, 0.42), CF(0, 0.83, 0.87 + index * 0.35), tint(color, -0.04 * index), "WedgePart") end
	for side = -1, 1, 2 do
		for index = 0, 2 do
			local z = -0.45 + index * 0.53
			beam(m, "ScorpionThigh", V(side * 0.58, 0.78, z), V(side * 1.27, 0.55, z + 0.18), 0.15, 0.15, color)
			beam(m, "ScorpionShin", V(side * 1.27, 0.55, z + 0.18), V(side * 1.78, 0.09, z - 0.08), 0.105, 0.11, tint(color, -0.1))
		end
		beam(m, "ClawArm", V(side * 0.48, 0.85, -0.8), V(side * 1.13, 0.66, -1.63), 0.25, 0.28, color)
		part(m, "PincerPalm", V(0.57, 0.37, 0.55), CF(side * 1.17, 0.66, -1.75), tint(color, 0.1), "WedgePart")
		for fork = -1, 1, 2 do beam(m, "PincerTip", V(side * 1.17 + fork * 0.19, 0.67, -1.91), V(side * 1.17 + fork * 0.15, 0.64, -2.36), 0.11, 0.12, tint(color, -0.08)) end
	end
	local tail = { V(0, 0.93, 1.48), V(0, 1.42, 1.88), V(0, 2.2, 1.65), V(0, 2.65, 0.9), V(0, 2.35, 0.34) }
	for index = 1, #tail - 1 do beam(m, "TailSegment", tail[index], tail[index + 1], 0.34 - index * 0.035, 0.33 - index * 0.03, tint(color, index * 0.025)) end
	part(m, "Stinger", V(0.18, 0.55, 0.2), CF(0, 2.13, 0.24) * A(-0.34, 0, 0), CHARCOAL, "WedgePart")
	eyes(m, V(0, 1.05, -0.87), 0.23, CHARCOAL)
end

local function serpent(m, color, leech)
	for index = 0, 5 do
		local z = -1.45 + index * 0.65
		local x = math.sin(index * 0.92) * (leech and 0.28 or 0.46)
		part(m, "BodySegment", V((leech and 1.02 or 0.88) - index * 0.065, 0.83 - index * 0.045, 0.95),
			CF(x, 0.44, z) * A(0, math.cos(index * 0.92) * 0.13, 0), tint(color, index % 2 * 0.06), "WedgePart")
	end
	if leech then
		part(m, "LeechMouth", V(0.76, 0.63, 0.13), CF(0, 0.47, -1.99), CHARCOAL)
		for side = -1, 1, 2 do part(m, "MouthLip", V(0.14, 0.66, 0.2), CF(side * 0.4, 0.46, -2.03), tint(color, 0.2), "WedgePart") end
		for y = 0.16, 0.79, 0.63 do part(m, "MouthLip", V(0.86, 0.12, 0.2), CF(0, y, -2.03), tint(color, 0.13)) end
	else
		part(m, "SerpentHead", V(1.18, 0.59, 1.03), CF(0, 0.88, -1.87), color, "WedgePart")
		for side = -1, 1, 2 do part(m, "HoodFlare", V(0.39, 0.82, 0.65), CF(side * 0.64, 0.78, -1.36) * A(0, 0, side * -0.17), tint(color, 0.18), "WedgePart") end
		eyes(m, V(0, 1.01, -2.35), 0.4, CHARCOAL)
		part(m, "Tongue", V(0.075, 0.035, 0.5), CF(0, 0.73, -2.52), AMBER)
	end
end

local function toad(m, color)
	part(m, "ToadBody", V(2.35, 1.28, 2.25), CF(0, 1.03, 0.28), color, "WedgePart")
	part(m, "ToadThroat", V(1.8, 0.72, 1.0), CF(0, 0.8, -0.7), tint(color, 0.35), "WedgePart")
	part(m, "ToadHead", V(2.3, 0.68, 1.35), CF(0, 1.33, -0.78), tint(color, 0.05), "WedgePart")
	for side = -1, 1, 2 do
		part(m, "PowerfulHaunch", V(0.92, 1.0, 1.6), CF(side * 1.12, 0.69, 0.72) * A(0, side * -0.16, 0), tint(color, -0.05), "WedgePart")
		part(m, "RearFoot", V(0.91, 0.22, 0.81), CF(side * 1.39, 0.11, 1.42), tint(color, -0.14), "WedgePart")
		beam(m, "FrontArm", V(side * 0.87, 1.04, -0.42), V(side * 1.12, 0.18, -1.0), 0.24, 0.27, color)
		part(m, "FrontWebbedFoot", V(0.61, 0.16, 0.64), CF(side * 1.15, 0.08, -1.15), tint(color, 0.08), "WedgePart")
		part(m, "EyeBrow", V(0.63, 0.65, 0.69), CF(side * 0.7, 1.75, -0.89), tint(color, 0.17), "WedgePart")
		part(m, "ToadEye", V(0.31, 0.28, 0.04), CF(side * 0.7, 1.82, -1.25), AMBER)
		part(m, "ToadPupil", V(0.065, 0.22, 0.025), CF(side * 0.7, 1.82, -1.28), CHARCOAL)
	end
	part(m, "MouthLine", V(1.54, 0.055, 0.045), CF(0, 1.1, -1.47), CHARCOAL)
	part(m, "TongueRibbon", V(0.26, 0.065, 0.54), CF(0, 1.07, -1.69), Color3.fromRGB(184, 139, 120), "WedgePart")
end

local function wraith(m, color)
	part(m, "SpectralMantle", V(1.4, 2.2, 0.83), CF(0, 2.9, 0.05), color, "WedgePart")
	for side = -1, 1, 2 do
		part(m, "HoodFold", V(0.45, 0.95, 0.78), CF(side * 0.42, 4.0, 0) * A(0, 0, side * -0.17), tint(color, 0.2), "WedgePart")
		part(m, "SpectralArm", V(0.43, 1.47, 0.4), CF(side * 1.05, 2.96, -0.1) * A(-0.14, 0, side * 0.3), tint(color, -0.13), "WedgePart")
		shard(m, "FloatingHand", V(side * 1.33, 1.9, -0.33), 0.57, 0.34, ICE, A(0, 0, side * 0.25))
	end
	part(m, "HoodShadow", V(0.58, 0.65, 0.08), CF(0, 3.97, -0.43), CHARCOAL)
	eyes(m, V(0, 4.08, -0.49), 0.16, ICE, true, 0.1)
	for index = 0, 2 do part(m, "TatteredHem", V(0.43, 1.55 - index * 0.25, 0.33), CF((index - 1) * 0.46, 1.37 + index * 0.11, 0.12) * A(0, index * 0.2, (index - 1) * -0.08), tint(color, index * 0.07), "WedgePart") end
end

local function golem(m, color)
	part(m, "GolemChest", V(2.65, 2.2, 1.6), CF(0, 4.05, 0), color, "WedgePart")
	part(m, "GolemWaist", V(1.9, 0.7, 1.25), CF(0, 2.78, 0), tint(color, -0.13))
	part(m, "GolemHead", V(1.36, 1.18, 1.25), CF(0, 5.72, -0.15), tint(color, 0.12), "WedgePart")
	for side = -1, 1, 2 do
		leg(m, V(side * 0.72, 2.8, 0), V(side * 0.83, 1.35, 0.08), V(side * 0.9, 0, -0.12), 0.91, color)
		part(m, "GolemShoulder", V(1.33, 1.17, 1.65), CF(side * 1.69, 4.64, 0), tint(color, -0.08), "WedgePart")
		beam(m, "GolemArm", V(side * 1.73, 4.45, 0), V(side * 2.02, 3.15, -0.13), 0.93, 0.98, color)
		part(m, "GolemFist", V(1.16, 1.2, 1.15), CF(side * 2.1, 2.72, -0.23), tint(color, 0.05), "WedgePart")
		part(m, "MagmaFault", V(0.075, 1.12, 0.06), CF(side * 0.72, 4.0, -0.84) * A(0, 0, side * 0.2), AMBER, nil, false, true)
	end
	eyes(m, V(0, 5.88, -0.81), 0.35, AMBER, true, 0.19)
	part(m, "CoreSlit", V(0.39, 0.55, 0.05), CF(0, 4.27, -0.86), AMBER, "WedgePart", false, true)
end

local function stalker(m, color)
	part(m, "StalkerThorax", V(0.9, 1.25, 1.25), CF(0, 2.2, 0), color, "WedgePart")
	part(m, "StalkerAbdomen", V(0.86, 0.75, 1.65), CF(0, 1.77, 1.0) * A(-0.2, 0, 0), tint(color, -0.13), "WedgePart")
	for side = -1, 1, 2 do
		leg(m, V(side * 0.39, 1.9, 0.42), V(side * 1.1, 1.0, 0.64), V(side * 1.25, 0, 0.31), 0.2, color)
		leg(m, V(side * 0.3, 1.81, 1.17), V(side * 0.79, 0.9, 1.73), V(side * 1.0, 0, 1.64), 0.18, tint(color, -0.1))
		beam(m, "RaptorialArm", V(side * 0.46, 2.43, -0.25), V(side * 1.08, 1.91, -0.91), 0.23, 0.27, color)
		shard(m, "ForearmBlade", V(side * 1.06, 1.35, -0.97), 1.2, 0.36, ICE, A(-0.45, 0, side * 0.26))
	end
	part(m, "TriangularHead", V(1.01, 0.54, 0.8), CF(0, 3.0, -0.42), tint(color, 0.15), "WedgePart")
	eyes(m, V(0, 3.04, -0.85), 0.34, ICE, true, 0.15)
	shard(m, "HeadCrest", V(0, 3.13, -0.15), 0.78, 0.34, color, A(0.15, 0, 0))
end

local function sentinel(m, color)
	part(m, "SentinelTorso", V(2.05, 2.05, 1.27), CF(0, 4.13, 0), tint(color, -0.42), "WedgePart")
	part(m, "SentinelVisor", V(0.94, 0.85, 0.77), CF(0, 5.56, -0.1), CHARCOAL, "WedgePart")
	part(m, "VisorLine", V(0.67, 0.09, 0.035), CF(0, 5.64, -0.51), ICE, nil, false, true)
	for side = -1, 1, 2 do
		part(m, "FloatingPauldron", V(1.12, 0.95, 1.13), CF(side * 1.58, 4.96, 0) * A(0, 0, side * -0.16), color, "WedgePart")
		beam(m, "SentinelArm", V(side * 1.59, 4.56, 0), V(side * 1.84, 3.2, -0.04), 0.45, 0.53, tint(color, -0.3))
		shard(m, "SentinelBlade", V(side * 1.86, 2.06, -0.18), 1.37, 0.56, tint(color, -0.2), A(0, 0, side * 0.08), true)
		beam(m, "HaloSide", V(side * 0.64, 5.91, 0.05), V(side * 1.11, 6.65, 0.05), 0.13, 0.13, color)
		beam(m, "HaloCrown", V(side * 1.11, 6.65, 0.05), V(0, 7.04, 0.05), 0.13, 0.13, ICE)
	end
	for index = 0, 2 do part(m, "FloatingSkirt", V(0.63, 1.4, 0.49), CF((index - 1) * 0.7, 2.15, 0.13) * A(0, index * 0.24, (index - 1) * -0.12), tint(color, -0.18), "WedgePart") end
	shard(m, "SentinelCore", V(0, 3.65, -0.72), 0.9, 0.43, color, A(0, 0, 0), true)
end

local function crawler(m, color)
	part(m, "CrawlerHull", V(2.55, 1.25, 2.55), CF(0, 1.66, 0.23), tint(color, -0.18))
	for side = -1, 1, 2 do
		part(m, "ImpactCarapace", V(1.15, 0.91, 2.9), CF(side * 0.84, 2.17, 0.23) * A(0, 0, side * -0.2), color, "WedgePart")
		for index = 0, 2 do
			local z = -0.72 + index * 0.86
			leg(m, V(side * 0.93, 1.68, z), V(side * 1.91, 1.0, z + 0.28), V(side * 2.49, 0, z - 0.08), 0.32, tint(color, -0.19))
		end
	end
	part(m, "CrawlerHead", V(1.19, 0.65, 1.03), CF(0, 1.38, -1.28), tint(color, -0.04), "WedgePart")
	eyes(m, V(0, 1.58, -1.83), 0.34, AMBER, true, 0.17)
	for index = 0, 2 do shard(m, "ImpactGlassSpine", V(0, 2.4, -0.45 + index * 0.66), 0.76 - index * 0.1, 0.4, ICE, A(0.18, 0.2, 0), index == 0) end
end

local CREATURE_IDS = {
	Wolf = true, FrostWolf = true, MagmaHound = true, AuroraStag = true, Scorpion = true,
	SandSerpent = true, GiantLeech = true, BogToad = true, IceWraith = true,
	LavaGolem = true, CrystalStalker = true, VoidSentinel = true, CometCrawler = true,
}

function Equipment.CreateCreature(id, biome)
	if not CREATURE_IDS[id] then return nil end
	local m = model(id, "Creature")
	m:SetAttribute("ArtFacing", "-Z")
	local color = BIOME_COLORS[biome] or BIOME_COLORS.Forest
	if id == "Wolf" then canine(m, color, "Wolf")
	elseif id == "FrostWolf" then canine(m, color, "Frost")
	elseif id == "MagmaHound" then canine(m, color, "Magma")
	elseif id == "AuroraStag" then stag(m, color)
	elseif id == "Scorpion" then scorpion(m, color)
	elseif id == "SandSerpent" then serpent(m, color, false)
	elseif id == "GiantLeech" then serpent(m, color, true)
	elseif id == "BogToad" then toad(m, color)
	elseif id == "IceWraith" then wraith(m, color)
	elseif id == "LavaGolem" then golem(m, color)
	elseif id == "CrystalStalker" then stalker(m, color)
	elseif id == "VoidSentinel" then sentinel(m, color)
	elseif id == "CometCrawler" then crawler(m, color)
	end
	-- Every visible creature part remains anchored until the gameplay factory welds it.
	return finish(m)
end

Equipment.BuildIds = BUILD_IDS
Equipment.ArmorDefinitions = ARMOR_DEFS
Equipment.CreatureIds = CREATURE_IDS

return Equipment
