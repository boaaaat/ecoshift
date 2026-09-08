local MapConfig = {}
local Theme = require(script.Parent.UI.UITheme)
local C = Theme.Colors

MapConfig.GeneratedWorldFolderName = nil -- nil = read from BiomeConfig.spawn_folder_name

MapConfig.Minimap = {
	Size = 150,
	Margin = 14,
	Position = "BottomRight",
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

MapConfig.PlayerPortraits = {
	FullscreenSize = 20, -- Screen pixels; portraits do not grow with map zoom.
	MinimapSize = 18,
}

-- Marker glyph source:
-- Type = "emoji" uses Value as text glyph
-- Type = "icon" uses Value as Image (rbxassetid://...)
MapConfig.MarkerGlyphs = {
	PlayerSelf = { Type = "emoji", Value = "▲" },
	PlayerOther = { Type = "emoji", Value = "●" },
	Spawn = { Type = "emoji", Value = "◆" },
	Enemy = { Type = "emoji", Value = "!" },
	Structure = { Type = "emoji", Value = "■" },
	Objective = { Type = "emoji", Value = "+" },
	PlayerUnique = {
		Type = "emoji_pool",
		Values = { "●" },
	},
	EnemyUnique = {
		Type = "emoji_pool",
		Values = { "!" },
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
	GlyphPool = { "◇", "△", "+" },
}

MapConfig.Colors = {
	UIBackground = C.Background,
	UIPanel = C.Panel,
	UIBorder = C.Border,
	TextPrimary = C.Text,
	TextMuted = C.TextMuted,
	MinimapBackground = C.Night,
	MinimapRing = C.Amber,
	Player = C.Paper,
	Teammate = C.Sage,
	Structure = C.Cold,
	Objective = C.Amber,
	Spawn = C.Amber,
	RegionFill = Color3.fromRGB(255, 255, 255),
	Resource = Color3.fromRGB(116, 221, 93),
	Enemy = Color3.fromRGB(231, 116, 82),
	BiomeTile = {
		Forest = Color3.fromRGB(56, 92, 52),
		Desert = Color3.fromRGB(138, 119, 72),
		Swamp = Color3.fromRGB(60, 88, 76),
		FrozenTundra = Color3.fromRGB(151, 167, 178),
		Volcanic = Color3.fromRGB(107, 72, 65),
		CrystalWastes = Color3.fromRGB(112, 103, 134),
		AuroraVale = Color3.fromRGB(107, 167, 163),
		StarfallCrater = Color3.fromRGB(138, 114, 141),
		Unknown = Color3.fromRGB(72, 78, 86),
	},
}

-- These aliases are also used when minimap markers are rebuilt after a switch.
Theme.Changed:Connect(function()
	for key, token in pairs({ UIBackground = "Background", UIPanel = "Panel", UIBorder = "Border", TextPrimary = "Text", TextMuted = "TextMuted" }) do
		MapConfig.Colors[key] = C[token]
	end
end)

return MapConfig
