local MapConfig = {}

MapConfig.GeneratedWorldFolderName = nil -- nil = read from BiomeConfig.spawn_folder_name

MapConfig.Minimap = {
	Size = 200,
	Margin = 14,
	Position = "TopRight",
	Range = 500,
	MinRange = 80,
	MaxRange = 500,
	ZoomStep = 25,
	UpdateRate = 0.12,
	RotateWithPlayer = false,
	EmojiScale = 0.7, -- Minimap-only glyph/emoji marker size multiplier
}

MapConfig.Fullscreen = {
	UpdateRate = 0.1,
	BoostedUpdateRate = 0, -- 0 = redraw every frame during interaction (drag/zoom/pan)
	InteractionBoostDuration = 0.2,
	DefaultZoom = 1.0,
	MinZoom = 0.35,
	MaxZoom = 3.5,
	ZoomStep = 0.12,
	GamepadPanPixelsPerSecond = 900,
}

MapConfig.Orientation = {
	-- Position projection flips.
	FlipX = false,
	FlipZ = true,
}

MapConfig.Exploration = {
	RevealChunkRadius = 1,
}

MapConfig.MarkerDefaults = {
	Players = true,
	Structures = true,
	Objectives = true,
	Spawn = true,
	Resources = false,
	Enemies = true,
	Regions = true,
}

MapConfig.MarkerRotation = {
	-- Glyphs are visually authored facing right in many emoji/icon sets.
	-- Use offsets if your selected emoji/icon has a different native forward direction.
	PlayerOffset = 0,
	EnemyOffset = 0,
	SpawnOffset = 0,
}

-- Marker glyph source:
-- Type = "emoji" uses Value as text glyph
-- Type = "icon" uses Value as Image (rbxassetid://...)
MapConfig.MarkerGlyphs = {
	PlayerSelf = { Type = "emoji", Value = "🧍" },
	PlayerOther = { Type = "emoji", Value = "🙂" },
	Spawn = { Type = "emoji", Value = "⬆️" },
	Enemy = { Type = "emoji", Value = "👹" },
	Structure = { Type = "emoji", Value = "🏠" },
	Objective = { Type = "emoji", Value = "🎯" },
	PlayerUnique = {
		Type = "emoji_pool",
		Values = { "😀", "😃", "😄", "😁", "😆", "😎", "🥳", "🤠", "🙂", "😊", "😺", "😸" },
	},
	EnemyUnique = {
		Type = "emoji_pool",
		Values = { "👹", "👺", "👻", "💀", "🧟", "🧌", "🕷️", "🦂", "🐍", "🐺", "🦇", "🪳" },
	},
}

-- Region rendering:
-- Defaults are auto-generated per region name when not configured.
-- To override a region look, add it to ByName:
-- ForestClearing = {
--   FillColor = Color3.fromRGB(60, 110, 68),
--   FillTransparency = 0.86,
--   StrokeColor = Color3.fromRGB(195, 230, 178),
--   StrokeTransparency = 0.35,
--   Glyph = { Type = "icon", Value = "rbxassetid://1234567890" }, -- or emoji glyph
--   ShowLabel = true,
-- }
MapConfig.RegionStyles = {
	Default = {
		FillTransparency = 0.88,
		StrokeTransparency = 0.45,
		ShowLabel = true,
	},
	ByName = {},
	GlyphPool = { "🌲", "🌿", "🌾", "🏜️", "🪨", "🏕️", "🗿", "🌊", "🔥", "❄️", "🍄", "🏔️" },
}

MapConfig.Colors = {
	UIBackground = Color3.fromRGB(11, 14, 18),
	UIPanel = Color3.fromRGB(20, 26, 34),
	UIBorder = Color3.fromRGB(62, 78, 96),
	TextPrimary = Color3.fromRGB(230, 236, 242),
	TextMuted = Color3.fromRGB(156, 170, 184),
	MinimapBackground = Color3.fromRGB(10, 16, 20),
	MinimapRing = Color3.fromRGB(72, 90, 108),
	Player = Color3.fromRGB(100, 200, 255),
	Teammate = Color3.fromRGB(116, 255, 170),
	Structure = Color3.fromRGB(125, 204, 255),
	Objective = Color3.fromRGB(255, 183, 77),
	Spawn = Color3.fromRGB(255, 140, 60),
	RegionFill = Color3.fromRGB(255, 255, 255),
	Resource = Color3.fromRGB(116, 221, 93),
	Enemy = Color3.fromRGB(255, 104, 104),
	BiomeTile = {
		Forest = Color3.fromRGB(56, 92, 52),
		Desert = Color3.fromRGB(138, 119, 72),
		Swamp = Color3.fromRGB(60, 88, 76),
		FrozenTundra = Color3.fromRGB(151, 167, 178),
		Volcanic = Color3.fromRGB(107, 72, 65),
		CrystalWastes = Color3.fromRGB(112, 103, 134),
		Unknown = Color3.fromRGB(72, 78, 86),
	},
}

return MapConfig
