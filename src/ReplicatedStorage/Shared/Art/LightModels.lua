-- Ground-authored expedition fixtures. Geometry stays visible at every quality.
local Collection = game:GetService("CollectionService")
local Config = require(script.Parent.Parent.LightConfig)
local Art = {}
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local WOOD, IRON, STONE = Color3.fromRGB(115, 83, 48), Color3.fromRGB(57, 65, 64), Color3.fromRGB(107, 119, 108)
local BRASS, DARK = Color3.fromRGB(185, 143, 68), Color3.fromRGB(36, 32, 46)

local function part(parent, name, size, cf, color, material, decorative)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, typeof(cf) == "Vector3" and CF(cf) or cf
	p.Color, p.Material = color, material or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch = true, not decorative, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function glow(parent, name, size, cf, color)
	return part(parent, name, size, cf, color, Enum.Material.Neon, true)
end
local function bar(parent, name, from, to, width, color, luminous)
	local center = (from + to) * .5
	return part(parent, name, V(width, (to - from).Magnitude, width), CFrame.lookAt(center, to) * A(math.pi / 2, 0, 0), color,
		luminous and Enum.Material.Neon or Enum.Material.Metal, true)
end
local function ring(parent, name, cf, radius, color, width, luminous, arc)
	local angle = arc or math.pi * 2
	local segments = math.ceil(16 * angle / (math.pi * 2))
	for i = 1, segments do
		local a, b = (i - 1) * angle / segments, i * angle / segments
		bar(parent, name, cf:PointToWorldSpace(V(math.cos(a) * radius, 0, math.sin(a) * radius)),
			cf:PointToWorldSpace(V(math.cos(b) * radius, 0, math.sin(b) * radius)), width or .1, color, luminous)
	end
end
local function crystal(parent, cf, size, color)
	-- A solid diamond with shoulders; decorative shards may be pointed, unlike the torch head.
	return glow(parent, "CrystalFacet", size, cf * A(0, math.pi / 4, math.pi / 4), color)
end
local function base(model, width, height, color)
	part(model, "Foundation", V(width, .3, width), V(0, .15, 0), color, Enum.Material.Slate)
	part(model, "Pedestal", V(width * .6, height, width * .6), V(0, .3 + height / 2, 0), color)
	part(model, "Capstone", V(width * .85, .22, width * .85), V(0, .3 + height, 0), BRASS, Enum.Material.Metal)
end
local function cage(model, center, width, height, color)
	for _, y in ipairs({-height / 2, height / 2}) do
		part(model, "LanternRim", V(width, .14, width), center + V(0, y, 0), color, Enum.Material.Metal)
	end
	for x = -1, 1, 2 do for z = -1, 1, 2 do
		part(model, "LanternBar", V(.1, height, .1), center + V(x * (width / 2 - .05), 0, z * (width / 2 - .05)), color, Enum.Material.Metal)
	end end
end
local function orbit(model, name, cf, radius, color, speed, tilt, satellites)
	local rotor = Instance.new("Model"); rotor.Name = name; rotor.Parent = model
	-- A replicated primary part keeps the rotation center exact on every client.
	local pivot = part(rotor, "OrbitPivot", V(.1, .1, .1), cf, color, nil, true)
	pivot.Transparency, pivot.CanQuery = 1, false
	rotor.PrimaryPart = pivot
	ring(rotor, "OrbitBand", cf * A(tilt or 0, 0, 0), radius, color, .1)
	for i = 1, satellites or 0 do
		local a = i * math.pi * 2 / satellites
		local pos = (cf * A(tilt or 0, 0, 0)):PointToWorldSpace(V(math.cos(a) * radius, 0, math.sin(a) * radius))
		crystal(rotor, CF(pos), V(.32, .32, .32), color)
	end
	rotor:SetAttribute("LightOrbitSpeed", speed)
	return rotor
end

function Art.Build(model, id)
	local def = Config.Definitions[id]
	if not def then return false end
	-- Do not stream in half a fixture or a halo without its pivot.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local color, accent, style = def.Color, def.Accent, def.Style
	local source
	if style == "Torch" then
		part(model, "TimberStake", V(.32, 3.25, .32), V(0, 1.625, 0), WOOD, Enum.Material.Wood)
		for _, y in ipairs({2.65, 2.9, 3.15}) do part(model, "Binding", V(.44, .1, .44), V(0, y, 0), IRON) end
		part(model, "SquareBrazier", V(.94, .18, .94), V(0, 3.14, 0), IRON, Enum.Material.Metal)
		source = glow(model, "EmberCube", V(.75, .75, .75), V(0, 3.6, 0), color)
	elseif style == "Candle" then
		base(model, 1.6, .1, WOOD)
		cage(model, V(0, 1.23, 0), 1.3, 1.4, WOOD)
		part(model, "WaxCandle", V(.45, .65, .45), V(0, .85, 0), Color3.fromRGB(233, 214, 163))
		source = glow(model, "CandleCore", V(.25, .25, .25), V(0, 1.3, 0), color)
		ring(model, "CarryLoop", CF(0, 2.14, 0) * A(math.pi / 2, 0, 0), .25, IRON, .07)
	elseif style == "Standing" or style == "Trail" then
		local h = style == "Standing" and 5.6 or 3.6
		base(model, 1.55, .3, IRON)
		part(model, "Post", V(.3, h, .3), V(0, h / 2, 0), WOOD, Enum.Material.Wood)
		cage(model, V(0, h, 0), 1.35, 1.5, BRASS)
		source = glow(model, "LanternCube", V(.75, .95, .75), V(0, h, 0), color)
		part(model, "RoofCap", V(1.7, .18, 1.7), V(0, h + .86, 0), IRON)
	elseif style == "Mire" then
		base(model, 2.2, .25, WOOD)
		for i = 0, 3 do
			local a = i * math.pi / 2
			bar(model, "RootRib", V(math.cos(a), .5, math.sin(a)), V(math.cos(a) * .7, 2.6, math.sin(a) * .7), .23, WOOD)
		end
		ring(model, "RootCrown", CF(0, 2.5, 0), .95, WOOD, .17)
		source = glow(model, "GlowcapHeart", V(.8, .65, .8), V(0, 1.7, 0), color)
		for i = 1, 3 do
			local x, z = math.cos(i * 2.1) * .62, math.sin(i * 2.1) * .62
			part(model, "MushroomStem", V(.13, .9, .13), V(x, .95, z), accent)
			glow(model, "MushroomCap", V(.65, .2, .65), CF(x, 1.48, z) * A(0, i, 0), color)
		end
	elseif style == "Frost" then
		base(model, 2.35, .85, STONE)
		for i = 0, 3 do
			local a = i * math.pi / 2
			crystal(model, CF(math.cos(a) * .72, 2.1, math.sin(a) * .72) * A(0, a, 0), V(.38, 1.7, .38), accent)
		end
		source = glow(model, "FrostLens", V(.75, 1.65, .75), V(0, 3, 0), color)
		ring(model, "LensClamp", CF(0, 3.4, 0), .63, BRASS, .1)
	elseif style == "Brazier" then
		base(model, 3.4, .5, DARK)
		part(model, "CoalBowl", V(2.8, .4, 2.8), V(0, 1.45, 0), IRON, Enum.Material.Metal)
		ring(model, "BowlRim", CF(0, 1.95, 0), 1.55, IRON, .23)
		for i = 0, 3 do
			local a = i * math.pi / 2 + math.pi / 4
			bar(model, "Claw", V(math.cos(a), .8, math.sin(a)), V(math.cos(a) * 1.5, 2.8, math.sin(a) * 1.5), .26, IRON)
		end
		source = glow(model, "CoalBed", V(1.9, .32, 1.9), V(0, 1.75, 0), color)
		for x = -1, 1 do for z = -1, 1 do part(model, "CharredCoal", V(.4, .22, .4), CF(x * .55, 1.98, z * .55) * A(.15, x + z, .2), DARK, Enum.Material.Slate, true) end end
	elseif style == "Obelisk" then
		base(model, 2.8, 1.9, DARK)
		for _, y in ipairs({.85, 1.5, 2.15}) do
			glow(model, "EtchedBand", V(1.7, .055, 1.7), V(0, y, 0), color)
		end
		source = crystal(model, CF(0, 4, 0), V(.95, 2.65, .95), color)
		for x = -1, 1, 2 do bar(model, "CrystalCradle", V(x * .8, 2.1, 0), V(x * 1.25, 4.1, 0), .18, BRASS) end
	elseif style == "Aurora" then
		base(model, 3.3, .55, IRON)
		for z = -1, 1, 2 do
			ring(model, "AuroraArch", CF(0, 3, z * .45) * A(math.pi / 2, 0, 0), 1.6, BRASS, .13)
			for x = -1, 1, 2 do
				glow(model, "AuroraRibbon", V(.08, 2.4, .08), V(x * .7, 3, z * .45), x == 1 and color or Color3.fromRGB(188, 165, 246))
			end
		end
		source = crystal(model, CF(0, 3.1, 0), V(.9, 1.8, .9), color)
	elseif style == "Orrery" then
		base(model, 3.2, 1.15, IRON)
		part(model, "Axis", V(.35, 3, .35), V(0, 2.3, 0), BRASS, Enum.Material.Metal)
		source = glow(model, "StarCore", V(1.1, 1.1, 1.1), CF(0, 3.7, 0) * A(.4, .5, .5), color)
		orbit(model, "OuterOrbit", CF(0, 3.7, 0), 2.3, BRASS, .3, .75, 3)
		orbit(model, "InnerOrbit", CF(0, 3.7, 0), 1.65, accent, -.45, -.75, 2)
	elseif style == "Storm" then
		base(model, 3.8, .9, IRON)
		part(model, "ReactorHousing", V(1.1, 3.2, 1.1), V(0, 2.85, 0), DARK)
		for i = 1, 5 do ring(model, "ReactorCoil", CF(0, 1.3 + i * .55, 0), 1, i % 2 == 0 and color or BRASS, .12, i % 2 == 0) end
		source = glow(model, "StormCore", V(.95, 1.1, .95), V(0, 5.05, 0), color)
		for i = 0, 3 do
			local a = i * math.pi / 2
			bar(model, "LightningProng", V(math.cos(a) * 1.5, 1.2, math.sin(a) * 1.5), V(math.cos(a), 6.2, math.sin(a)), .2, IRON)
			glow(model, "ProngTip", V(.22, .5, .22), V(math.cos(a), 6.25, math.sin(a)), accent)
		end
	elseif style == "Abyss" then
		base(model, 4.8, 1.1, DARK)
		for i = 0, 3 do
			local a = i * math.pi / 2 + math.pi / 4
			local x, z = math.cos(a) * 2, math.sin(a) * 2
			part(model, "ShrinePillar", V(.5, 4.6, .5), V(x, 3.6, z), IRON)
			glow(model, "PillarRune", V(.55, .12, .55), V(x, 5.3, z), color)
			crystal(model, CF(x, 6.25, z), V(.35, .8, .35), accent)
		end
		source = crystal(model, CF(0, 4.6, 0), V(1.1, 2.3, 1.1), color)
		orbit(model, "RunicHalo", CF(0, 4.6, 0), 2.4, color, -.2, .3, 6)
		ring(model, "LowerRuneBand", CF(0, 1.55, 0), 1.75, accent, .09, true)
	elseif style == "Moon" then
		base(model, 6.2, .6, STONE)
		part(model, "Moonwell", V(3.4, .3, 3.4), V(0, 1.2, 0), IRON)
		glow(model, "SilverWell", V(2.8, .08, 2.8), V(0, 1.41, 0), color)
		for x = -1, 1, 2 do bar(model, "CrownSupport", V(x * 2.4, .7, 0), V(x * 1.9, 4, 0), .35, STONE) end
		ring(model, "CrescentCrown", CF(0, 5.4, 0) * A(math.pi / 2, 0, math.pi / 4), 2.8, accent, .23, false, math.pi * 1.5)
		source = crystal(model, CF(0, 4.6, 0), V(1.2, 1.8, 1.2), color)
		orbit(model, "CelestialHalo", CF(0, 4.6, 0), 2.5, BRASS, .18, .35, 4)
		orbit(model, "LunarHalo", CF(0, 4.6, 0), 1.85, color, -.28, -.6, 3)
		for i = 1, 8 do
			local a = i * math.pi / 4
			glow(model, "WellRune", V(.16, .12, .4), CF(math.cos(a) * 2.65, .95, math.sin(a) * 2.65) * A(0, -a, 0), color)
		end
	end
	assert(source, "Missing light art: " .. id)
	source.Name = "LightCore"
	source:SetAttribute("LightId", id)
	local lamp = Instance.new("PointLight")
	lamp.Name, lamp.Color, lamp.Range, lamp.Brightness, lamp.Shadows = "FixtureLight", color, def.Range, def.Brightness, true
	lamp.Parent = source
	-- The server carries only steady light; each client creates its own quality effects.
	Collection:AddTag(source, Config.SourceTag)
	model:SetAttribute("LightArtVersion", 1)
	return true
end

return Art
