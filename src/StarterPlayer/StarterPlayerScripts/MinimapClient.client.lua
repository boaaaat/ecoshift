local Settings = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ClientSettings"))
if require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end
-- MinimapClient.client.lua
-- Tactical minimap + fullscreen world map (M)

local Players = game:GetService("Players")
local Theme = require(game:GetService("ReplicatedStorage").Shared.UI.UITheme)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local BiomeConfig = require(ReplicatedStorage.Shared.BiomeConfig)
local MapConfig = require(ReplicatedStorage.Shared.MapConfig)

local DEBUG = false
local function dprint(...)
	if DEBUG then
		print("[Map]", ...)
	end
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local crewMarkerRemote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("CrewMapMarker")
if not crewMarkerRemote then
	task.spawn(function()
		crewMarkerRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CrewMapMarker", 120)
	end)
end

local WORLD_RADIUS = (BiomeConfig.WORLD and BiomeConfig.WORLD.WorldRadius) or (BiomeConfig.world_radius or 1000)
local CHUNK_SIZE = BiomeConfig.chunk_size or 240
local GENERATED_FOLDER_NAME = MapConfig.GeneratedWorldFolderName or BiomeConfig.spawn_folder_name or "GeneratedWorld"
local ORIENTATION = MapConfig.Orientation or {}
local MAP_FLIP_X = ORIENTATION.FlipX == true
local MAP_FLIP_Z = ORIENTATION.FlipZ == true

local MAP_CAPTURE_ACTION = "EcoshiftMapCapture"
local MAP_TOGGLE_ACTION = "EcoshiftToggleMap"

local STATE = {
	minimapRange = MapConfig.Minimap.Range,
	minimapVisible = true,
	fullMapOpen = false,
	fullZoom = MapConfig.Fullscreen.DefaultZoom,
 mapLayer = player:GetAttribute("MapLayer") or "Surface",
	panWorld = Vector2.new(0, 0),
	fullRenderBoostUntil = 0,
	fogEnabled = true,
	markerVisibility = {
		Players = MapConfig.MarkerDefaults.Players,
		Structures = MapConfig.MarkerDefaults.Structures,
		Objectives = MapConfig.MarkerDefaults.Objectives,
		Spawn = MapConfig.MarkerDefaults.Spawn,
		Resources = MapConfig.MarkerDefaults.Resources,
		Enemies = MapConfig.MarkerDefaults.Enemies,
		Regions = MapConfig.MarkerDefaults.Regions,
	},
	spawnPosition = nil,
	customBlips = {},
	abilityBlips = {},
	enemyEmojiByTypeKey = {},
	usedEnemyEmojis = {},
	enemyEmojiRng = Random.new(),
}

local WORLD = {
	chunksByKey = {}, -- ["cx,cz"] = { cx, cz, biome, regions = { {name, x, z, sx, sz, temp} }, folder }
	localChunksByKey = {},
	sharedChunksByKey = {},
	sharedChunkFolders = {},
	sharedFolder = nil,
	sharedFolderConns = {},
	sharedRootConns = {},
	chunkByFolder = {}, -- [Folder] = key
	chunkConns = {}, -- [Folder] = { RBXScriptConnection }
	markersByInstance = {}, -- [Instance] = { markerType, label }
	markerConns = {}, -- [Instance] = { RBXScriptConnection }
	exploredChunks = {}, -- ["cx,cz"] = true
	generatedFolder = nil,
	generatedFolderConns = {},
	workspaceConns = {},
	resourceEntries = {},
	enemyEntries = {},
	lastOptionalScan = 0,
}

local UI = {
	gui = nil,
	minimapContainer = nil,
	minimapFrame = nil,
	minimapBlips = nil,
	minimapPlayer = nil,
	minimapSpawn = nil,
	minimapChunkLayer = nil,
	minimapRegionLayer = nil,
	minimapMarkerLayer = nil,
	minimapCoords = nil,
	minimapZoom = nil,
	fullRoot = nil,
	fullCanvas = nil,
	fullChunkLayer = nil,
	fullRegionLayer = nil,
	fullMarkerLayer = nil,
	zoomLabel = nil,
	cursorLabel = nil,
	mapToggleButton = nil,
	waypointRoot = nil,
	waypointIcon = nil,
	waypointDistance = nil,
	toggleButtons = {},
}

local RENDER_CACHE = {
	minimapBlips = {},
	minimapChunkFrames = {},
	minimapRegionFrames = {},
	minimapMarkerFrames = {},
	chunkFrames = {},
	regionFrames = {},
	markerFrames = {},
	usedMinimapChunkKeys = {},
	usedMinimapRegionKeys = {},
	usedMinimapMarkerKeys = {},
	usedChunkKeys = {},
	usedRegionKeys = {},
	usedMarkerKeys = {},
}

local INPUT = {
	dragInput = nil,
	dragging = false,
	lastTouchPan = nil,
	pressPosition = nil,
	dragDistance = 0,
	gamepadPan = Vector2.new(0, 0),
}

-- Forward declare glyph helpers so createUI can call them.
local getMarkerGlyph
local applyGlyphToFrame
local clearGlyphFromFrame
local applyPlayerPortrait
local setFullMapOpen
local playerPortraitCache = {}

local function tableClear(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

local function chunkKey(cx, cz)
	return tostring(cx) .. "," .. tostring(cz)
end

local function worldToChunk(x, z)
	local cx = math.floor(x / CHUNK_SIZE)
	local cz = math.floor(z / CHUNK_SIZE)
	return cx, cz
end

local function chunkCenter(cx, cz)
	return cx * CHUNK_SIZE + CHUNK_SIZE * 0.5, cz * CHUNK_SIZE + CHUNK_SIZE * 0.5
end

local function getCharacterRoot(plr)
	local char = plr and plr.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

local function finiteVector3(value)
	return typeof(value) == "Vector3"
		and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and math.abs(value.X) < math.huge and math.abs(value.Y) < math.huge and math.abs(value.Z) < math.huge
end

local function getPlayerMapPose(plr)
	if not plr then return nil end
	local dead = plr:GetAttribute("IsDead") == true
	-- Streamed characters are smoother than the server's map telemetry.
	local root = getCharacterRoot(plr)
	if not dead and root and root:IsA("BasePart") and root:IsDescendantOf(Workspace) then
		return root.Position, root.CFrame.LookVector, false
	end
	-- Fallen players use server telemetry from DeathService's ragdoll, never
	-- their hidden or removed character root.
	local position = plr:GetAttribute("MapPosition")
	local look = plr:GetAttribute("MapLookVector")
	if not finiteVector3(position) or not finiteVector3(look) then return nil end
	if look.Magnitude < .001 or look.Magnitude > 1.1 then return nil end
	return position, look, dead
end

local function getObjectPosition(obj)
	if not obj or not obj.Parent then return nil end
	if obj:IsA("BasePart") then
		return obj.Position
	end
	if obj:IsA("Model") then
		if obj.PrimaryPart then
			return obj.PrimaryPart.Position
		end
		local anyPart = obj:FindFirstChildWhichIsA("BasePart", true)
		if anyPart then
			return anyPart.Position
		end
		local ok, pivot = pcall(function() return obj:GetPivot() end)
		if ok then
			return pivot.Position
		end
	end
	return nil
end

local function mapOrientedXZ(x, z)
	if MAP_FLIP_X then
		x = -x
	end
	if MAP_FLIP_Z then
		z = -z
	end
	return x, z
end

local function headingDegFromLook(look)
	-- Compute heading from the same oriented map vector used by position projection.
	-- 0 = up on the map, 90 = right on the map.
	local mapX, mapZ = mapOrientedXZ(look.X, look.Z)
	return math.deg(math.atan2(mapX, mapZ))
end

local function headingDegFromPoints(fromPos, toPos)
	if typeof(fromPos) ~= "Vector3" or typeof(toPos) ~= "Vector3" then
		return 0
	end
	local dir = toPos - fromPos
	if dir.Magnitude <= 0.001 then
		return 0
	end
	return headingDegFromLook(Vector3.new(dir.X, 0, dir.Z))
end

local function markerRotationWithOffset(angle, kind)
	local rotCfg = MapConfig.MarkerRotation or {}
	local offset = 0
	local base = angle or 0
	if kind == "Players" then
		offset = tonumber(rotCfg.PlayerOffset) or 0
	elseif kind == "Enemies" then
		offset = tonumber(rotCfg.EnemyOffset) or 0
	elseif kind == "Spawn" then
		offset = tonumber(rotCfg.SpawnOffset) or 0
	end
	return base + offset
end

local function playerYawForRotatingMinimap(root)
	if not root then return 0 end
	local look = root.CFrame.LookVector
	return math.atan2(look.X, look.Z)
end

local function getBiomeColor(biome)
	local map = MapConfig.Colors.BiomeTile or {}
	local meta=BiomeConfig.biome_metadata[biome]
 return meta and meta.MapColor or map[biome] or map.Unknown or Color3.fromRGB(72, 78, 86)
end

local function hashString(text)
	local h = 2166136261
	local s = tostring(text or "")
	for i = 1, #s do
		h = bit32.bxor(h, s:byte(i))
		h = (h * 16777619) % 4294967296
	end
	return h
end

local function colorFromHash(text)
	local h = hashString(text)
	local hue = (h % 360) / 360
	local sat = 0.35 + ((bit32.rshift(h, 8) % 30) / 100)
	local val = 0.48 + ((bit32.rshift(h, 16) % 35) / 100)
	return Color3.fromHSV(hue, math.clamp(sat, 0.3, 0.8), math.clamp(val, 0.4, 0.9))
end

local function glyphPoolPick(pool, seedText)
	if type(pool) ~= "table" or #pool == 0 then
		return "❖"
	end
	local idx = (hashString(seedText) % #pool) + 1
	local value = pool[idx]
	if type(value) ~= "string" or value == "" then
		return "❖"
	end
	return value
end

local FALLBACK_ENEMY_EMOJIS = { "👹", "👺", "👻", "💀", "🧟", "🧌", "🕷️", "🦂", "🐍", "🐺", "🦇", "🪳" }

local function getUniqueEmojiPool(kind)
	local glyphs = MapConfig.MarkerGlyphs or {}
	local cfg = glyphs[kind]
	if type(cfg) == "table" then
		local t = string.lower(tostring(cfg.Type or cfg.type or ""))
		local values = cfg.Values or cfg.values
		if t == "emoji_pool" and type(values) == "table" and #values > 0 then
			return values
		end
	end
	return FALLBACK_ENEMY_EMOJIS
end

local function allocateUniqueEmoji(pool, usedCounts, rng)
	if type(pool) ~= "table" or #pool == 0 then
		return "🙂"
	end
	local available = {}
	for i = 1, #pool do
		local emoji = pool[i]
		if type(emoji) == "string" and emoji ~= "" and not usedCounts[emoji] then
			available[#available + 1] = emoji
		end
	end
	local pickSet = (#available > 0) and available or pool
	local pick = pickSet[rng:NextInteger(1, #pickSet)] or "🙂"
	usedCounts[pick] = (usedCounts[pick] or 0) + 1
	return pick
end

local function cachePlayerPortrait(plr)
	local userId = plr.UserId
	if playerPortraitCache[userId] then return end
	local entry = { Image = "", Ready = false, Initial = plr.Name:sub(1, 1):upper() }
	playerPortraitCache[userId] = entry
	-- Thumbnail calls yield; fetch on join, never inside map rendering.
	if userId <= 0 then return end -- Local Studio test players may not have avatars.
	local function attempt(number)
		if playerPortraitCache[userId] ~= entry or plr.Parent ~= Players then return end
		local ok, image, ready = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if playerPortraitCache[userId] ~= entry or plr.Parent ~= Players then return end
		if ok and ready and type(image) == "string" and image ~= "" then
			entry.Image, entry.Ready = image, true
		elseif number < 3 then
			task.delay(number * 2, function() attempt(number + 1) end)
		end
	end
	task.spawn(attempt, 1)
end

local function getEnemyTypeKey(inst)
	if not inst then
		return "Enemy"
	end
	local function readTypeKey(obj)
		if not obj then return nil end
		local entityId = obj:GetAttribute("EntityId")
		if type(entityId) == "string" and entityId ~= "" then
			return entityId
		end
		local configId = obj:GetAttribute("ConfigId")
		if type(configId) == "string" and configId ~= "" then
			return configId
		end
		local entityType = obj:GetAttribute("EntityType")
		if type(entityType) == "string" and entityType ~= "" then
			return entityType
		end
		return nil
	end

	local key = readTypeKey(inst)
	if key then
		return key
	end

	local model = inst:FindFirstAncestorWhichIsA("Model")
	key = readTypeKey(model)
	if key then
		return key
	end
	if model and type(model.Name) == "string" and model.Name ~= "" then
		return model.Name
	end
	if type(inst.Name) == "string" and inst.Name ~= "" then
		return inst.Name
	end
	return "Enemy"
end

local function getEnemyEmoji(inst)
	local typeKey = getEnemyTypeKey(inst)
	local existing = STATE.enemyEmojiByTypeKey[typeKey]
	if existing then
		return existing
	end
	local pool = getUniqueEmojiPool("EnemyUnique")
	local emoji = allocateUniqueEmoji(pool, STATE.usedEnemyEmojis, STATE.enemyEmojiRng)
	STATE.enemyEmojiByTypeKey[typeKey] = emoji
	return emoji
end

local function getPlayerGlyph(plr)
	return {
		Type = "portrait",
		UserId = plr.UserId,
		IsSelf = plr == player,
		IsDead = plr:GetAttribute("IsDead") == true,
	}
end

local function getEnemyGlyph(inst)
	local base = MapConfig.MarkerGlyphs and MapConfig.MarkerGlyphs.Enemy
	if type(base) == "table" then
		local t = string.lower(tostring(base.Type or base.type or "emoji"))
		if t == "icon" then
			return base
		end
	end
	return {
		Type = "emoji",
		Value = getEnemyEmoji(inst),
	}
end

local function glyphKeyForMapMarkerGroup(group)
	if group == "Structures" then
		return "Structure"
	end
	return nil
end

local function resolveRegionStyle(regionName)
	local regionStyles = MapConfig.RegionStyles or {}
	local defaultStyle = regionStyles.Default or {}
	local overrides = (regionStyles.ByName and regionStyles.ByName[regionName]) or {}
	local style = {}

	style.FillColor = overrides.FillColor or defaultStyle.FillColor or colorFromHash(regionName)
	style.FillTransparency = tonumber(overrides.FillTransparency or defaultStyle.FillTransparency) or 0.88
	style.StrokeColor = overrides.StrokeColor or defaultStyle.StrokeColor or style.FillColor:Lerp(Color3.new(1, 1, 1), 0.35)
	style.StrokeTransparency = tonumber(overrides.StrokeTransparency or defaultStyle.StrokeTransparency) or 0.45
	style.ShowLabel = overrides.ShowLabel
	if style.ShowLabel == nil then
		style.ShowLabel = defaultStyle.ShowLabel ~= false
	end

	local glyphOverride = overrides.Glyph or defaultStyle.Glyph
	if glyphOverride then
		style.Glyph = glyphOverride
	else
		local pool = regionStyles.GlyphPool
		style.Glyph = {
			Type = "emoji",
			Value = glyphPoolPick(pool, regionName),
		}
	end
	return style
end

local function interiorFolder()
 local folders=Workspace:FindFirstChild("ExpeditionInteriors")
 local id=player:GetAttribute("InteriorId")
 return id and folders and folders:FindFirstChild(id)
end
local function mapOrigin()
 local folder=STATE.mapLayer=="Interior" and interiorFolder()
 return folder and folder:GetAttribute("MapOrigin") or Vector3.zero
end
local function mapRadius()
 local folder=STATE.mapLayer=="Interior" and interiorFolder()
 local extent=folder and folder:GetAttribute("MapExtent")
 return typeof(extent)=="Vector2" and math.max(extent.X,extent.Y)*.6 or WORLD_RADIUS
end
local function chunkLayer(chunk)
 local region=chunk.regions and chunk.regions[1]
 return region and region.layer or "Surface"
end
local function terrainMapColor(chunk)
 local base=getBiomeColor(chunk.biome);local region=chunk.regions and chunk.regions[1]
 if not region then return base end
 if region.water then return base:Lerp(Color3.fromRGB(57,116,140),.65) end
 local height=tonumber(region.height) or 0
 return height>0 and base:Lerp(Color3.fromRGB(222,220,184),math.clamp(height/380,0,.5)) or base:Lerp(Color3.fromRGB(22,31,33),math.clamp(-height/180,0,.5))
end
local function clampPan()
	local maxPan = mapRadius() * 1.35
	STATE.panWorld = Vector2.new(
		math.clamp(STATE.panWorld.X, -maxPan, maxPan),
		math.clamp(STATE.panWorld.Y, -maxPan, maxPan)
	)
end

local function mapScale(absSize, zoom)
	local usable = math.min(absSize.X, absSize.Y)
	if usable <= 0 then return 1 end
	return (usable / (mapRadius() * 2)) * zoom
end

local function worldToCanvas(wx, wz, absSize, zoom, panWorld)
	local scale = mapScale(absSize, zoom)
	local cx = absSize.X * 0.5
	local cy = absSize.Y * 0.5
	local origin=mapOrigin()
 local mapX, mapZ = mapOrientedXZ(wx-origin.X, wz-origin.Z)
	local x = cx + (mapX + panWorld.X) * scale
	local y = cy - (mapZ + panWorld.Y) * scale
	return x, y, scale
end

local function canvasToWorld(px, py, absSize, zoom, panWorld)
	local scale = mapScale(absSize, zoom)
	if scale <= 0 then
		return 0, 0
	end
	local cx = absSize.X * 0.5
	local cy = absSize.Y * 0.5
	local wx = ((px - cx) / scale) - panWorld.X
	local wz = -((py - cy) / scale) - panWorld.Y
	if MAP_FLIP_X then
		wx = -wx
	end
	if MAP_FLIP_Z then
		wz = -wz
	end
	local origin=mapOrigin()
 return wx+origin.X, wz+origin.Z
end

local function safeJSONDecode(raw)
	if type(raw) ~= "string" or raw == "" then
		return {}
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if ok and type(data) == "table" then
		return data
	end
	return {}
end

local function cleanupConnections(list)
	if type(list) ~= "table" then return end
	for i = 1, #list do
		local conn = list[i]
		if conn then
			conn:Disconnect()
		end
	end
	for i = #list, 1, -1 do
		list[i] = nil
	end
end

local function buildCoreFrame(parent, size, position, color, transparency)
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency or 0
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

local function buildLabel(parent, text, size, position, font, textSize, color, xAlign)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = font or Enum.Font.Gotham
	label.TextSize = textSize or 12
	label.TextColor3 = color or MapConfig.Colors.TextPrimary
	label.TextXAlignment = xAlign or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function styleCard(frame)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = MapConfig.Colors.UIBorder
	stroke.Thickness = 1
	stroke.Transparency = 0.2
	stroke.Parent = frame
end

local function getPositionPreset()
	local p = MapConfig.Minimap.Position or "TopRight"
	if p == "TopLeft" then
		return UDim2.new(0, MapConfig.Minimap.Margin, 0, MapConfig.Minimap.Margin)
	elseif p == "BottomRight" then
		return UDim2.new(1, -MapConfig.Minimap.Margin - MapConfig.Minimap.Size - 20, 1, -MapConfig.Minimap.Margin - MapConfig.Minimap.Size - 54)
	elseif p == "BottomLeft" then
		return UDim2.new(0, MapConfig.Minimap.Margin, 1, -MapConfig.Minimap.Margin - MapConfig.Minimap.Size - 54)
	end
	return UDim2.new(1, -MapConfig.Minimap.Margin - MapConfig.Minimap.Size - 20, 0, MapConfig.Minimap.Margin)
end

local function createUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MinimapUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	UI.gui = gui

	-- Minimap card
	local miniW = MapConfig.Minimap.Size + 20
	local miniH = MapConfig.Minimap.Size + 54
	local miniContainer = buildCoreFrame(gui, UDim2.fromOffset(miniW, miniH), getPositionPreset(), MapConfig.Colors.UIPanel, 0.18)
	miniContainer.Name = "MinimapContainer"
	local mobileLayer = Instance.new("ScreenGui")
	mobileLayer.Name, mobileLayer.ResetOnSpawn, mobileLayer.DisplayOrder = "MobileMinimapLayer", false, gui.DisplayOrder
	mobileLayer.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	mobileLayer.Parent = gui.Parent
	miniContainer.AnchorPoint = Vector2.new(1, 1)
	miniContainer.Position = UDim2.new(1, -18, 1, -18)
	local miniScale = Instance.new("UIScale")
	miniScale.Parent = miniContainer
	Theme.Panel(miniContainer)
	styleCard(miniContainer)

	local mapFrame = buildCoreFrame(miniContainer, UDim2.fromOffset(MapConfig.Minimap.Size, MapConfig.Minimap.Size), UDim2.fromOffset(10, 10), MapConfig.Colors.MinimapBackground, 0.1)
	mapFrame.Name = "MinimapFrame"
	mapFrame.ClipsDescendants = true
	local mapCorner = Instance.new("UICorner")
	mapCorner.CornerRadius = UDim.new(1, 0)
	mapCorner.Parent = mapFrame
	local mapStroke = Instance.new("UIStroke")
	mapStroke.Color = MapConfig.Colors.MinimapRing
	mapStroke.Thickness = 2
	mapStroke.Transparency = 0.2
	mapStroke.Parent = mapFrame

	local chunkLayer = buildCoreFrame(mapFrame, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(), 1)
	chunkLayer.Name = "MiniChunkLayer"

	local regionLayer = buildCoreFrame(mapFrame, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(), 1)
	regionLayer.Name = "MiniRegionLayer"

	local markerLayer = buildCoreFrame(mapFrame, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(), 1)
	markerLayer.Name = "MiniMarkerLayer"

	local playerBlip = buildCoreFrame(markerLayer, UDim2.fromOffset(32, 32), UDim2.fromScale(0.5, 0.5), Color3.new(1, 1, 1), 1)
	playerBlip.Name = "PlayerBlip"
	playerBlip.AnchorPoint = Vector2.new(0.5, 0.5)
	playerBlip.ZIndex = 10
	local playerCorner = Instance.new("UICorner")
	playerCorner.CornerRadius = UDim.new(1, 0)
	playerCorner.Parent = playerBlip
	applyPlayerPortrait(playerBlip, getPlayerGlyph(player))

	local coords = buildLabel(miniContainer, "X: 0  Z: 0", UDim2.new(1, -12, 0, 16), UDim2.fromOffset(8, miniH - 38), Enum.Font.GothamMedium, 11, MapConfig.Colors.TextPrimary)
	coords.Name = "Coords"
	local zoom = buildLabel(miniContainer, "Range: " .. tostring(STATE.minimapRange), UDim2.new(1, -12, 0, 14), UDim2.fromOffset(8, miniH - 22), Enum.Font.Gotham, 10, MapConfig.Colors.TextMuted)
	zoom.Name = "Zoom"
	local miniHit = Instance.new("TextButton")
	miniHit.Name = "OpenAtlas"
	miniHit.Text = ""
	miniHit.BackgroundTransparency = 1
	miniHit.Size = UDim2.fromScale(1, 1)
	miniHit.ZIndex = 30
	miniHit.Parent = miniContainer
	miniHit.Activated:Connect(function() setFullMapOpen(true) end)

	UI.minimapContainer = miniContainer
	UI.minimapFrame = mapFrame
	UI.minimapBlips = markerLayer
	UI.minimapPlayer = playerBlip
	UI.minimapSpawn = nil
	UI.minimapChunkLayer = chunkLayer
	UI.minimapRegionLayer = regionLayer
	UI.minimapMarkerLayer = markerLayer
	UI.minimapCoords = coords
	UI.minimapZoom = zoom

	-- Shared crew waypoint. It remains in the world HUD after the atlas closes,
	-- clamps to the screen edge when off-screen, and never uses a square marker.
	local waypointRoot = Instance.new("Frame")
	waypointRoot.Name = "CrewWaypoint"
	waypointRoot.AnchorPoint = Vector2.new(0.5, 0.5)
	waypointRoot.Size = UDim2.fromOffset(116, 62)
	waypointRoot.BackgroundTransparency = 1
	waypointRoot.BorderSizePixel = 0
	waypointRoot.ZIndex = 34
	waypointRoot.Visible = false
	waypointRoot.Parent = gui

	local waypointIconHost = Instance.new("Frame")
	waypointIconHost.Name = "WaypointIcon"
	waypointIconHost.AnchorPoint = Vector2.new(0.5, 0)
	waypointIconHost.Position = UDim2.fromScale(0.5, 0)
	waypointIconHost.Size = UDim2.fromOffset(38, 38)
	waypointIconHost.BackgroundTransparency = 1
	waypointIconHost.ZIndex = 35
	waypointIconHost.Parent = waypointRoot
	local waypointGlyph = Theme.Icon(waypointIconHost, "Waypoint", 34)
	for _, descendant in ipairs(waypointGlyph:GetDescendants()) do
		if descendant:IsA("Frame") then
			descendant:SetAttribute("ThemeFixed", true)
			descendant.BackgroundColor3 = Theme.Colors.Amber
		end
	end

	local waypointDistance = buildLabel(waypointRoot, "0 studs", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 38), Enum.Font.GothamBold, 13, Theme.Colors.Paper, Enum.TextXAlignment.Center)
	waypointDistance.Name = "Distance"
	waypointDistance.TextStrokeColor3 = Theme.Colors.Night
	waypointDistance.TextStrokeTransparency = 0.15
	waypointDistance.ZIndex = 35

	UI.waypointRoot = waypointRoot
	UI.waypointIcon = waypointIconHost
	UI.waypointDistance = waypointDistance
	playerGui:GetAttributeChangedSignal("BuildPlacementActive"):Connect(function()
		miniContainer.Visible = STATE.minimapVisible and not (Theme.IsMobile() and (playerGui:GetAttribute("BuildPlacementActive") or playerGui:GetAttribute("MenuCursorOpen")))
	end)

	-- Fullscreen map
	local fullRoot = buildCoreFrame(gui, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), Theme.Colors.Night, 0.28)
	fullRoot.Name = "WorldMapRoot"
	fullRoot.ZIndex = 50
	fullRoot.Visible = false

	local panel = buildCoreFrame(fullRoot, UDim2.fromScale(0.92, 0.9), UDim2.fromScale(0.04, 0.05), MapConfig.Colors.UIPanel, 0.05)
	panel.Name = "Panel"
	styleCard(panel)

	local header = buildCoreFrame(panel, UDim2.new(1, -16, 0, 40), UDim2.fromOffset(8, 8), Color3.new(), 1)
	header.Name = "Header"
	local mapTitle = buildLabel(header, "EXPEDITION ATLAS", UDim2.new(1, -54, 0, 22), UDim2.fromOffset(0, 0), Enum.Font.GothamBlack, 18, MapConfig.Colors.TextPrimary)
	local mapHint = buildLabel(header, "CLICK MARKER  /  SCROLL ZOOM  /  DRAG PAN", UDim2.new(1, -54, 0, 16), UDim2.fromOffset(0, 24), Enum.Font.Gotham, 11, MapConfig.Colors.TextMuted)
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseMapButton"
	closeButton.Size = UDim2.fromOffset(40, 40)
	closeButton.Position = UDim2.new(1, -40, 0, 0)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 28
	closeButton.Text = "×"
	closeButton.Parent = header
	Theme.Button(closeButton, false)
	Theme.Bind(closeButton, "TextColor3", "Text")
	closeButton.Activated:Connect(function() setFullMapOpen(false) end)

	local body = buildCoreFrame(panel, UDim2.new(1, -16, 1, -56), UDim2.fromOffset(8, 48), Color3.new(), 1)
	local sidebarW = 170
	local mapArea = buildCoreFrame(body, UDim2.new(1, -sidebarW - 10, 1, 0), UDim2.fromOffset(0, 0), Theme.Colors.SlotEmpty, 0)
	styleCard(mapArea)

	local canvas = buildCoreFrame(mapArea, UDim2.new(1, -14, 1, -14), UDim2.fromOffset(7, 7), Theme.Colors.Night, 0)
	canvas.Name = "Canvas"
	canvas.ClipsDescendants = true
	canvas.Active = true

	local chunkLayer = buildCoreFrame(canvas, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), Color3.new(), 1)
	chunkLayer.Name = "ChunkLayer"
	local regionLayer = buildCoreFrame(canvas, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), Color3.new(), 1)
	regionLayer.Name = "RegionLayer"
	local markerLayer = buildCoreFrame(canvas, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), Color3.new(), 1)
	markerLayer.Name = "MarkerLayer"

	local sidebar = Instance.new("ScrollingFrame")
	sidebar.Name = "MapLegend"
	sidebar.Size = UDim2.new(0, sidebarW, 1, 0)
	sidebar.Position = UDim2.new(1, -sidebarW, 0, 0)
	sidebar.BackgroundColor3 = Theme.Colors.Background
	sidebar.BorderSizePixel = 0
	sidebar.ScrollBarThickness = 5
	sidebar.CanvasSize = UDim2.fromOffset(0, 0)
	sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sidebar.ScrollingDirection = Enum.ScrollingDirection.Y
	sidebar.ZIndex = 40
	sidebar.Parent = body
	UI.legend = sidebar
	sidebar.Active = true
	styleCard(sidebar)
	local legendButton = Instance.new("TextButton")
	legendButton.Name = "ToggleLegend"
	legendButton.Text = "LEGEND"
	legendButton.TextSize = 12
	legendButton.Font = Enum.Font.GothamBold
	legendButton.Size = UDim2.fromOffset(78, 44)
	legendButton.Position = UDim2.new(1, -130, 0, 0)
	legendButton.Parent = header
	Theme.Button(legendButton, true)
	legendButton.Activated:Connect(function() sidebar.Visible = not sidebar.Visible end)

	local y = 8
	buildLabel(sidebar, "Legend", UDim2.new(1, -10, 0, 20), UDim2.fromOffset(10, y), Enum.Font.GothamBold, 14, MapConfig.Colors.TextPrimary)
	y += 24

	for _, name in ipairs({"Players", "Structures", "Objectives", "Spawn", "Regions", "Resources", "Enemies"}) do
		local btn = Instance.new("TextButton")
		btn.Name = name .. "Toggle"
		btn.Size = UDim2.new(1, -20, 0, 24)
		btn.Position = UDim2.fromOffset(10, y)
		btn.BackgroundColor3 = Theme.Colors.SlotEmpty
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		btn.Font = Enum.Font.GothamMedium
		btn.TextSize = 12
		btn.TextColor3 = MapConfig.Colors.TextPrimary
		btn.Parent = sidebar
		Theme.Button(btn)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = btn
		UI.toggleButtons[name] = btn
		y += 28
	end

	y += 8
	local centerBtn = Instance.new("TextButton")
	centerBtn.Size = UDim2.new(1, -20, 0, 26)
	centerBtn.Position = UDim2.fromOffset(10, y)
	centerBtn.BackgroundColor3 = Theme.Colors.SlotSelected
	centerBtn.BorderSizePixel = 0
	centerBtn.AutoButtonColor = false
	centerBtn.Font = Enum.Font.GothamBold
	centerBtn.TextSize = 12
	centerBtn.TextColor3 = MapConfig.Colors.TextPrimary
	centerBtn.Text = "Center On Player"
	centerBtn.Parent = sidebar
	local centerCorner = Instance.new("UICorner")
	centerCorner.CornerRadius = UDim.new(0, 6)
	centerCorner.Parent = centerBtn
	y += 32

	local resetZoomBtn = centerBtn:Clone()
	resetZoomBtn.Position = UDim2.fromOffset(10, y)
	resetZoomBtn.Text = "Reset Zoom"
	resetZoomBtn.Parent = sidebar
	y += 36
 local layerBtn=centerBtn:Clone();layerBtn.Name="MapLayer";layerBtn.Text="Layer: Surface";layerBtn.Position=UDim2.fromOffset(10,y);layerBtn.Parent=sidebar;y+=36
 UI.layerButton=layerBtn
 layerBtn.Activated:Connect(function()
  local layers=player:GetAttribute("InteriorId") and {"Surface","Cave","Interior"} or {"Surface","Cave"}
  STATE.mapLayer=layers[((table.find(layers,STATE.mapLayer) or 0)%#layers)+1]
  STATE.panWorld=Vector2.zero;STATE.fullZoom=MapConfig.Fullscreen.DefaultZoom
  layerBtn.Text="Layer: "..STATE.mapLayer;STATE.fullRenderBoostUntil=os.clock()+1
 end)

	local zoomLabel = buildLabel(sidebar, "Zoom: 100%", UDim2.new(1, -20, 0, 18), UDim2.fromOffset(10, y), Enum.Font.GothamMedium, 12, MapConfig.Colors.TextPrimary)
	y += 22
	local cursorLabel = buildLabel(sidebar, "Cursor: -", UDim2.new(1, -20, 0, 56), UDim2.fromOffset(10, y), Enum.Font.Gotham, 11, MapConfig.Colors.TextMuted)
	cursorLabel.TextWrapped = true
	cursorLabel.TextYAlignment = Enum.TextYAlignment.Top

	Theme.AnimatePanel(fullRoot)
	Theme.CaptureCursor(fullRoot)
	UI.fullRoot = fullRoot
	UI.fullCanvas = canvas
	UI.fullChunkLayer = chunkLayer
	UI.fullRegionLayer = regionLayer
	UI.fullMarkerLayer = markerLayer
	UI.zoomLabel = zoomLabel
	UI.cursorLabel = cursorLabel

	-- The minimap itself is the touch target; no duplicate bottom-screen MAP button.
	Theme.BindResponsive(gui, function(mobile, safeSize)
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or safeSize
		gui.IgnoreGuiInset = not mobile
		local width = 127 -- 20% larger than the previous 106px mobile card.
		miniContainer.Parent = mobile and mobileLayer or gui
		miniContainer.BackgroundTransparency = mobile and .48 or .04
		miniScale.Scale = mobile and 1 or math.min(math.clamp(math.min(viewport.X / 1440, viewport.Y / 900), 1, 2.5), (viewport.X - 40) / 900, (viewport.Y - 90) / 610)
		miniContainer.AnchorPoint = mobile and Vector2.zero or Vector2.new(1,1)
		-- Keep the larger mobile map on the far-left rail, below the vitals card.
		miniContainer.Position = mobile and UDim2.fromOffset(4,196) or UDim2.new(1, -18 * miniScale.Scale, 1, -18 * miniScale.Scale)
		miniContainer.Size = UDim2.fromOffset(mobile and width or miniW, mobile and width or miniH)
		local mapSize = mobile and 118 or MapConfig.Minimap.Size
		mapFrame.Size = UDim2.fromOffset(mapSize, mapSize)
		mapFrame.Position = UDim2.fromOffset(mobile and 4 or 10, mobile and 4 or 10)
		coords.Visible = not mobile
		zoom.Visible = not mobile
		zoom.Position = mobile and UDim2.new(0, 6, 1, -23) or UDim2.fromOffset(8, miniH - 22)
		zoom.TextSize = mobile and 13 or 10
		panel.Size = mobile and UDim2.new(1, -12, 1, -12) or UDim2.fromScale(.92, .9)
		panel.Position = mobile and UDim2.fromOffset(6, 6) or UDim2.fromScale(.04, .05)
		mapHint.Text = mobile and "TAP MARKER / PINCH ZOOM / DRAG PAN" or "CLICK MARKER  /  SCROLL ZOOM  /  DRAG PAN"
		mapTitle.Text = mobile and safeSize.X < 480 and "ATLAS" or "EXPEDITION ATLAS"
		mapTitle.Size = UDim2.new(1, mobile and -140 or -54, 0, 22)
		mapHint.Size = UDim2.new(1, mobile and -140 or -54, 0, 16)
		legendButton.Visible = mobile
		sidebar.Visible = not mobile
		mapArea.Size = UDim2.new(1, mobile and 0 or -sidebarW - 10, 1, 0)
		closeButton.Size = UDim2.fromOffset(mobile and 44 or 40, mobile and 44 or 40)
		closeButton.Position = UDim2.new(1, mobile and -44 or -40, 0, 0)
		local rowY = 32
		for _, name in ipairs({"Players", "Structures", "Objectives", "Spawn", "Regions", "Resources", "Enemies"}) do
			local button = UI.toggleButtons[name]
			button.Position = UDim2.fromOffset(10, rowY)
			button.Size = UDim2.new(1, -20, 0, mobile and 44 or 24)
			button.TextSize = mobile and 14 or 12
			rowY += mobile and 48 or 28
		end
		for _, button in ipairs({centerBtn, resetZoomBtn, layerBtn}) do
			button.Position = UDim2.fromOffset(10, rowY + 8)
			button.Size = UDim2.new(1, -20, 0, mobile and 44 or 26)
			button.TextSize = mobile and 14 or 12
			rowY += mobile and 48 or 32
		end
		zoomLabel.Position = UDim2.fromOffset(10, rowY + 12)
		cursorLabel.Position = UDim2.fromOffset(10, rowY + 34)
	end)

	for name, btn in pairs(UI.toggleButtons) do
		btn.MouseButton1Click:Connect(function()
			STATE.markerVisibility[name] = not STATE.markerVisibility[name]
		end)
	end

	centerBtn.MouseButton1Click:Connect(function()
		STATE.panWorld = Vector2.new(0, 0)
	end)

	resetZoomBtn.MouseButton1Click:Connect(function()
		STATE.fullZoom = MapConfig.Fullscreen.DefaultZoom
		STATE.panWorld = Vector2.new(0, 0)
	end)

end

local function updateLegendButtons()
	for name, btn in pairs(UI.toggleButtons) do
		local enabled = STATE.markerVisibility[name]
		btn.Text = (enabled and "[ON] " or "[OFF] ") .. name
		btn.BackgroundColor3 = enabled and Theme.Colors.SlotSelected or Theme.Colors.SlotEmpty
	end
end

local function registerMarkerInstance(inst)
	if not inst or WORLD.markersByInstance[inst] then return end
	local markerType = inst:GetAttribute("MapMarkerType")
	if type(markerType) ~= "string" then
		return
	end

	WORLD.markersByInstance[inst] = {
		markerType = markerType,
		label = inst:GetAttribute("MapMarkerLabel") or inst.Name,
	}

	WORLD.markerConns[inst] = {
		inst:GetAttributeChangedSignal("MapMarkerType"):Connect(function()
			if not inst.Parent then
				WORLD.markersByInstance[inst] = nil
				cleanupConnections(WORLD.markerConns[inst])
				WORLD.markerConns[inst] = nil
				return
			end
			local entry = WORLD.markersByInstance[inst]
			if not entry then return end
			local updatedType = inst:GetAttribute("MapMarkerType")
			if type(updatedType) ~= "string" then
				WORLD.markersByInstance[inst] = nil
				cleanupConnections(WORLD.markerConns[inst])
				WORLD.markerConns[inst] = nil
				return
			end
			entry.markerType = updatedType
		end),
		inst:GetAttributeChangedSignal("MapMarkerLabel"):Connect(function()
			local entry = WORLD.markersByInstance[inst]
			if entry then
				entry.label = inst:GetAttribute("MapMarkerLabel") or inst.Name
			end
		end),
	}
end

local function unregisterMarkerInstance(inst)
	WORLD.markersByInstance[inst] = nil
	cleanupConnections(WORLD.markerConns[inst])
	WORLD.markerConns[inst] = nil
end

local function parseChunkFolder(folder)
	local cx = folder:GetAttribute("MapChunkX")
	local cz = folder:GetAttribute("MapChunkZ")
	if type(cx) ~= "number" or type(cz) ~= "number" then
		local rawCx = folder:GetAttribute("ChunkX")
		local rawCz = folder:GetAttribute("ChunkZ")
		if type(rawCx) == "number" and type(rawCz) == "number" then
			cx, cz = rawCx, rawCz
		else
			local name = folder.Name
			local fromNameX, fromNameZ = name:match("Chunk_([^,]+),([^,]+)")
			cx = tonumber(fromNameX)
			cz = tonumber(fromNameZ)
		end
	end

	if type(cx) ~= "number" or type(cz) ~= "number" then
		return nil
	end

	local key = chunkKey(cx, cz)
	local biome = folder:GetAttribute("MapBiome")
	if type(biome) ~= "string" then
		biome = "Unknown"
	end

	local rawRegions = safeJSONDecode(folder:GetAttribute("MapRegionsJson"))
	local regions = {}
	for i = 1, #rawRegions do
		local r = rawRegions[i]
		if type(r) == "table" then
			regions[#regions + 1] = {
				name = tostring(r.name or "Region"),
				x = tonumber(r.x) or 0,
				z = tonumber(r.z) or 0,
				sx = math.max(0, tonumber(r.sx) or 0),
				sz = math.max(0, tonumber(r.sz) or 0),
				temp = tonumber(r.temp),
 height=tonumber(r.height),water=r.water==true,layer=r.layer=="Cave" and "Cave" or "Surface",
			}
		end
	end

	local record = {
		cx = cx,
		cz = cz,
		biome = biome,
		regions = regions,
		folder = folder,
	}
	if WORLD.sharedChunkFolders[folder] then
		WORLD.sharedChunksByKey[key] = record
		WORLD.exploredChunks[key] = true
	else
		WORLD.localChunksByKey[key] = record
	end
	-- Replicated chart data remains available when world geometry streams out.
	WORLD.chunksByKey[key] = WORLD.sharedChunksByKey[key] or WORLD.localChunksByKey[key]
	WORLD.chunkByFolder[folder] = key

	if not STATE.fogEnabled then
		WORLD.exploredChunks[key] = true
	end
end

local function bindChunkFolder(folder)
	if not folder or not folder:IsA("Folder") then return end
	if WORLD.chunkConns[folder] then
		parseChunkFolder(folder)
		return
	end

	parseChunkFolder(folder)

	for _, d in ipairs(folder:GetDescendants()) do
		registerMarkerInstance(d)
	end

	WORLD.chunkConns[folder] = {
		folder:GetAttributeChangedSignal("MapChunkX"):Connect(function() parseChunkFolder(folder) end),
		folder:GetAttributeChangedSignal("MapChunkZ"):Connect(function() parseChunkFolder(folder) end),
		folder:GetAttributeChangedSignal("MapBiome"):Connect(function() parseChunkFolder(folder) end),
		folder:GetAttributeChangedSignal("MapRegionsJson"):Connect(function() parseChunkFolder(folder) end),
		folder.DescendantAdded:Connect(function(inst)
			registerMarkerInstance(inst)
		end),
		folder.DescendantRemoving:Connect(function(inst)
			unregisterMarkerInstance(inst)
		end),
	}
end

local function unbindChunkFolder(folder)
	local key = WORLD.chunkByFolder[folder]
	if key then
		if WORLD.sharedChunkFolders[folder] then
			WORLD.sharedChunksByKey[key] = nil
			WORLD.exploredChunks[key] = nil
		else
			WORLD.localChunksByKey[key] = nil
		end
		WORLD.chunksByKey[key] = WORLD.sharedChunksByKey[key] or WORLD.localChunksByKey[key]
		WORLD.chunkByFolder[folder] = nil
	end
	WORLD.sharedChunkFolders[folder] = nil
	cleanupConnections(WORLD.chunkConns[folder])
	WORLD.chunkConns[folder] = nil

	for inst in pairs(WORLD.markersByInstance) do
		local ok, isDescendant = pcall(function()
			return inst:IsDescendantOf(folder)
		end)
		if ok and isDescendant then
			unregisterMarkerInstance(inst)
		end
	end
end

local function bindGeneratedFolder(folder)
	if WORLD.generatedFolder == folder then return end

	local oldFolders = {}
	for oldFolder in pairs(WORLD.chunkConns) do
		if not WORLD.sharedChunkFolders[oldFolder] then oldFolders[#oldFolders + 1] = oldFolder end
	end
	for i = 1, #oldFolders do
		local oldFolder = oldFolders[i]
		unbindChunkFolder(oldFolder)
	end

	cleanupConnections(WORLD.generatedFolderConns)
	WORLD.generatedFolder = folder

	if not folder then return end

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Folder") and child.Name:find("Chunk_") == 1 then
			bindChunkFolder(child)
		end
	end

	WORLD.generatedFolderConns = {
		folder.ChildAdded:Connect(function(child)
			if child:IsA("Folder") and child.Name:find("Chunk_") == 1 then
				bindChunkFolder(child)
			end
		end),
		folder.ChildRemoved:Connect(function(child)
			if child:IsA("Folder") then
				unbindChunkFolder(child)
			end
		end),
	}
end

local function refreshGeneratedFolderBinding()
	bindGeneratedFolder(Workspace:FindFirstChild(GENERATED_FOLDER_NAME))
end

local function bindSharedExploration(folder)
	if WORLD.sharedFolder == folder then return end
	cleanupConnections(WORLD.sharedFolderConns)
	local old = {}
	for child in pairs(WORLD.sharedChunkFolders) do old[#old + 1] = child end
	for _, child in ipairs(old) do unbindChunkFolder(child) end
	WORLD.sharedFolder = folder
	if not folder then return end
	local function added(child)
		if not child:IsA("Folder") then return end
		WORLD.sharedChunkFolders[child] = true
		bindChunkFolder(child)
	end
	WORLD.sharedFolderConns = {
		folder.ChildAdded:Connect(added),
		folder.ChildRemoved:Connect(unbindChunkFolder),
	}
	for _, child in ipairs(folder:GetChildren()) do added(child) end
end

local function initWorldBindings()
	refreshGeneratedFolderBinding()
	WORLD.sharedRootConns = {
		ReplicatedStorage.ChildAdded:Connect(function(child)
			if child.Name == "TeamExploration" and child:IsA("Folder") then bindSharedExploration(child) end
		end),
		ReplicatedStorage.ChildRemoved:Connect(function(child)
			if child == WORLD.sharedFolder then bindSharedExploration(nil) end
		end),
	}
	bindSharedExploration(ReplicatedStorage:FindFirstChild("TeamExploration"))

	WORLD.workspaceConns = {
		Workspace.ChildAdded:Connect(function(child)
			if child.Name == GENERATED_FOLDER_NAME and child:IsA("Folder") then
				bindGeneratedFolder(child)
			end
		end),
		Workspace.ChildRemoved:Connect(function(child)
			if child == WORLD.generatedFolder then
				bindGeneratedFolder(nil)
			end
		end),
		Workspace.DescendantAdded:Connect(function(inst)
			registerMarkerInstance(inst)
		end),
		Workspace.DescendantRemoving:Connect(function(inst)
			unregisterMarkerInstance(inst)
		end),
	}

	for _, inst in ipairs(Workspace:GetDescendants()) do
		registerMarkerInstance(inst)
	end
end

local function isChunkExplored(cx, cz)
	if not STATE.fogEnabled then return true end
	return WORLD.exploredChunks[chunkKey(cx, cz)] == true
end

local function isPositionExplored(pos)
	if not STATE.fogEnabled then return true end
	local cx, cz = worldToChunk(pos.X, pos.Z)
	return isChunkExplored(cx, cz)
end

local function normalizeMarkerType(raw)
	if type(raw) ~= "string" then return nil end
	if raw == "Objective" then return "Objectives" end
	if raw == "Structure" or raw == "PlayerBuiltStructure" then return "Structures" end
	return nil
end

local function colorForMarkerType(kind)
	if kind == "Objectives" then
		return MapConfig.Colors.Objective
	elseif kind == "Structures" then
		return MapConfig.Colors.Structure
	elseif kind == "Players" then
		return MapConfig.Colors.Player
	elseif kind == "Spawn" then
		return MapConfig.Colors.Spawn
	elseif kind == "Resources" then
		return MapConfig.Colors.Resource
	elseif kind == "Enemies" then
		return MapConfig.Colors.Enemy
	end
	return MapConfig.Colors.TextPrimary
end

getMarkerGlyph = function(kind)
	local cfg = kind
	if type(kind) ~= "table" then
		local glyphs = MapConfig.MarkerGlyphs or {}
		cfg = glyphs[kind]
	end
	if type(cfg) ~= "table" then
		return { Type = "emoji", Value = "?" }
	end
	local markerType = string.lower(tostring(cfg.Type or cfg.type or "emoji"))
	local value = cfg.Value or cfg.value
	if markerType == "emoji_pool" then
		local values = cfg.Values or cfg.values
		if type(values) == "table" and #values > 0 then
			value = values[1]
		end
		markerType = "emoji"
	end
	if type(value) ~= "string" or value == "" then
		value = "?"
	end
	if markerType ~= "icon" and markerType ~= "theme" then
		markerType = "emoji"
	end
	return {
		Type = markerType,
		Value = value,
	}
end

applyGlyphToFrame = function(frame, glyphKey, color, textSize)
	if not frame then return end
	local glyph = getMarkerGlyph(glyphKey)

	local emoji = frame:FindFirstChild("GlyphEmoji")
	if not emoji then
		emoji = Instance.new("TextLabel")
		emoji.Name = "GlyphEmoji"
		emoji.Size = UDim2.fromScale(1, 1)
		emoji.Position = UDim2.fromOffset(0, 0)
		emoji.BackgroundTransparency = 1
		emoji.TextXAlignment = Enum.TextXAlignment.Center
		emoji.TextYAlignment = Enum.TextYAlignment.Center
		emoji.Font = Enum.Font.GothamBold
		emoji.TextScaled = true
		emoji.Parent = frame
	end

	local icon = frame:FindFirstChild("GlyphIcon")
	if not icon then
		icon = Instance.new("ImageLabel")
		icon.Name = "GlyphIcon"
		icon.Size = UDim2.fromScale(1, 1)
		icon.Position = UDim2.fromOffset(0, 0)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = frame
	end

	local themeIcon = frame:FindFirstChild("GlyphTheme")
	if not themeIcon then
		themeIcon = Instance.new("Frame")
		themeIcon.Name = "GlyphTheme"
		themeIcon.Size = UDim2.fromScale(1, 1)
		themeIcon.Position = UDim2.fromOffset(0, 0)
		themeIcon.BackgroundTransparency = 1
		themeIcon.ZIndex = frame.ZIndex + 1
		themeIcon.Parent = frame
	end

	if glyph.Type == "icon" then
		icon.Image = glyph.Value
		icon.ImageColor3 = color or Color3.new(1, 1, 1)
		icon.Visible = true
		emoji.Visible = false
		themeIcon.Visible = false
	elseif glyph.Type == "theme" then
		local wantedSize = math.max(12, textSize or 12)
		local drawn = themeIcon:FindFirstChild("Glyph")
		if not drawn or drawn:GetAttribute("IconKind") ~= glyph.Value or drawn:GetAttribute("RequestedSize") ~= wantedSize then
			drawn = Theme.Icon(themeIcon, glyph.Value, wantedSize)
			drawn:SetAttribute("RequestedSize", wantedSize)
		end
		for _, descendant in ipairs(drawn:GetDescendants()) do
			if descendant:IsA("Frame") then
				descendant:SetAttribute("ThemeFixed", true)
				descendant.BackgroundColor3 = color or Color3.new(1, 1, 1)
			end
		end
		themeIcon.Visible = true
		icon.Visible = false
		emoji.Visible = false
	else
		emoji.Text = glyph.Value
		emoji.TextColor3 = color or Color3.new(1, 1, 1)
		emoji.TextSize = textSize or 12
		emoji.Visible = true
		icon.Visible = false
		themeIcon.Visible = false
	end
end

clearGlyphFromFrame = function(frame)
	if not frame then return end
	local emoji = frame:FindFirstChild("GlyphEmoji")
	if emoji then emoji.Visible = false end
	local icon = frame:FindFirstChild("GlyphIcon")
	if icon then icon.Visible = false end
	local themeIcon = frame:FindFirstChild("GlyphTheme")
	if themeIcon then themeIcon.Visible = false end
end

applyPlayerPortrait = function(frame, descriptor)
	clearGlyphFromFrame(frame)
	local portrait = frame:FindFirstChild("PlayerPortrait")
	if not portrait then
		portrait = Instance.new("ImageLabel")
		portrait.Name = "PlayerPortrait"
		portrait.Size = UDim2.fromScale(1, 1)
		portrait.BackgroundTransparency = 1
		portrait.ImageColor3 = Color3.new(1, 1, 1)
		portrait.ScaleType = Enum.ScaleType.Crop
		portrait.ZIndex = 11
		portrait:SetAttribute("ThemeFixed", true)
		portrait.Parent = frame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = portrait
		local fallback = Instance.new("TextLabel")
		fallback.Name = "PortraitFallback"
		fallback.Size = UDim2.fromScale(1, 1)
		fallback.BackgroundTransparency = 1
		fallback.Font = Enum.Font.GothamBold
		fallback.TextScaled = true
		fallback.ZIndex = 11
		fallback.Parent = frame
		local border = Instance.new("UIStroke")
		border.Name = "PortraitBorder"
		border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		border.Parent = frame
		local notch = Instance.new("Frame")
		notch.Name = "HeadingNotch"
		notch.AnchorPoint = Vector2.new(.5, .5)
		notch.Position = UDim2.fromScale(.5, 0)
		notch.Size = UDim2.fromScale(.2, .1)
		notch.BorderSizePixel = 0
		notch.ZIndex = 12
		notch.Parent = frame
	end
	local entry = playerPortraitCache[descriptor.UserId]
	local url = entry and entry.Image or ""
	if portrait.Image ~= url then portrait.Image = url end
	local ready = entry ~= nil and entry.Ready and portrait.IsLoaded
	local deadTint = MapConfig.Colors.PlayerDead or Color3.fromRGB(255, 105, 105)
	portrait.ImageColor3 = descriptor.IsDead and deadTint or Color3.new(1, 1, 1)
	-- Allow the image to load while the initial remains above it as a fallback.
	portrait.Visible = url ~= ""
	local fallback = frame.PortraitFallback
	fallback.Text = entry and entry.Initial or "?"
	fallback.Visible = not ready
	fallback.TextColor3 = descriptor.IsDead and deadTint or MapConfig.Colors.Player
	local outlineColor = descriptor.IsDead and deadTint or (descriptor.IsSelf and MapConfig.Colors.MinimapRing or MapConfig.Colors.Teammate)
	frame.PortraitBorder.Color = outlineColor
	frame.PortraitBorder.Thickness = descriptor.IsSelf and 2 or 1
	frame.HeadingNotch.BackgroundColor3 = outlineColor
	frame.BackgroundColor3 = MapConfig.Colors.MinimapBackground
	frame.BackgroundTransparency = 0
	frame.ZIndex = 10
	frame:SetAttribute("PortraitUserId", descriptor.UserId)
	frame:SetAttribute("PortraitReady", ready)
	frame:SetAttribute("PortraitDead", descriptor.IsDead == true)
end

local function getOptionalMarkers()
	local now = os.clock()
	if now - WORLD.lastOptionalScan < 0.8 then
		return
	end
	WORLD.lastOptionalScan = now

	tableClear(WORLD.resourceEntries)
	tableClear(WORLD.enemyEntries)

	if STATE.markerVisibility.Resources then
		local seen = {}
		for _, tagName in ipairs({"Resource", "Harvestable"}) do
			for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
				if not seen[inst] then
					seen[inst] = true
					local pos = getObjectPosition(inst)
					if pos then
						WORLD.resourceEntries[#WORLD.resourceEntries + 1] = { instance = inst, position = pos }
						if #WORLD.resourceEntries >= 300 then
							break
						end
					end
				end
			end
			if #WORLD.resourceEntries >= 300 then
				break
			end
		end
	end

	if STATE.markerVisibility.Enemies then
		local seen = {}
		for _, tagName in ipairs({"Enemy", "Monster", "Animal"}) do
			for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
				if not seen[inst] then
					seen[inst] = true
					local root = inst:FindFirstChild("HumanoidRootPart") or inst.PrimaryPart
					if root and root:IsA("BasePart") then
						WORLD.enemyEntries[#WORLD.enemyEntries + 1] = { instance = inst, position = root.Position, look = root.CFrame.LookVector }
						if #WORLD.enemyEntries >= 200 then
							break
						end
					end
				end
			end
			if #WORLD.enemyEntries >= 200 then
				break
			end
		end
	end
end

local function setCaptureInput(enabled)
	-- Keep gameplay movement active even while map is open.
	ContextActionService:UnbindAction(MAP_CAPTURE_ACTION)
end

local function markFullMapInteraction()
	local duration = tonumber(MapConfig.Fullscreen.InteractionBoostDuration) or 0.2
	duration = math.max(0, duration)
	STATE.fullRenderBoostUntil = math.max(STATE.fullRenderBoostUntil or 0, os.clock() + duration)
end

setFullMapOpen = function(open)
	STATE.fullMapOpen = open
	if not open then
		INPUT.dragInput = nil
		INPUT.dragging = false
		INPUT.lastTouchPan = nil
		INPUT.pressPosition = nil
		INPUT.dragDistance = 0
		INPUT.gamepadPan = Vector2.zero
	end
	if UI.fullRoot then
		UI.fullRoot.Visible = open
	end
	setCaptureInput(open)
	if open then
		markFullMapInteraction()
		updateLegendButtons()
	end
end

local function toggleFullMap()
	setFullMapOpen(not STATE.fullMapOpen)
end

local function mouseGuiPosition()
	local point = UserInputService:GetMouseLocation()
	-- Mouse coordinates include Roblox's top inset. AbsolutePosition does not
	-- when this ScreenGui draws through that inset, so compare in one space.
	if UI.gui and UI.gui.IgnoreGuiInset then
		point -= GuiService:GetGuiInset()
	end
	return point
end

local function getMouseOver(guiObject)
	if not guiObject then return false end
	local pos = mouseGuiPosition()
	local absPos = guiObject.AbsolutePosition
	local absSize = guiObject.AbsoluteSize
	return pos.X >= absPos.X and pos.X <= (absPos.X + absSize.X) and pos.Y >= absPos.Y and pos.Y <= (absPos.Y + absSize.Y)
end

local function containsPoint(object, point)
	if not object or not object.Visible then return false end
	local p, s = object.AbsolutePosition, object.AbsoluteSize
	return point.X >= p.X and point.Y >= p.Y and point.X <= p.X+s.X and point.Y <= p.Y+s.Y
end
local function canGestureMap(point)
	return STATE.fullMapOpen and containsPoint(UI.fullCanvas, point) and not containsPoint(UI.legend, point)
end
local function pointerPosition(input)
	-- Touch InputObject positions already share GuiObject.AbsolutePosition's
	-- coordinate space. Mouse locations need the inset correction above.
	if input.UserInputType == Enum.UserInputType.Touch then
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	return mouseGuiPosition()
end

local function getCrewMarker()
	local folder = WORLD.sharedFolder or ReplicatedStorage:FindFirstChild("TeamExploration")
	if not folder then return nil end
	local x, z = folder:GetAttribute("CrewMarkerX"), folder:GetAttribute("CrewMarkerZ")
	local layer = folder:GetAttribute("CrewMarkerLayer")
	if type(x) ~= "number" or type(z) ~= "number" or (layer ~= "Surface" and layer ~= "Cave") then return nil end
	return {X=x, Z=z, Layer=layer}
end

local function toggleCrewMarkerAt(point)
	if not crewMarkerRemote or not UI.fullCanvas or STATE.mapLayer == "Interior" then return end
	local canvasPosition, canvasSize = UI.fullCanvas.AbsolutePosition, UI.fullCanvas.AbsoluteSize
	local localPoint = point - canvasPosition
	local marker = getCrewMarker()
	if marker and marker.Layer == STATE.mapLayer then
		local markerX, markerY = worldToCanvas(marker.X, marker.Z, canvasSize, STATE.fullZoom, STATE.panWorld)
		if (localPoint - Vector2.new(markerX, markerY)).Magnitude <= 22 then
			crewMarkerRemote:FireServer({Remove=true})
			return
		end
	end
	local worldX, worldZ = canvasToWorld(localPoint.X, localPoint.Y, canvasSize, STATE.fullZoom, STATE.panWorld)
	crewMarkerRemote:FireServer({X=worldX, Z=worldZ, Layer=STATE.mapLayer})
end

local function setFullZoom(target, focusAbs)
	local oldZoom = STATE.fullZoom
	STATE.fullZoom = math.clamp(target, MapConfig.Fullscreen.MinZoom, MapConfig.Fullscreen.MaxZoom)
	if oldZoom == STATE.fullZoom then
		return
	end

	if UI.fullCanvas and focusAbs then
		local canvasPos = UI.fullCanvas.AbsolutePosition
		local canvasSize = UI.fullCanvas.AbsoluteSize
		local localX = focusAbs.X - canvasPos.X
		local localY = focusAbs.Y - canvasPos.Y
		if localX >= 0 and localY >= 0 and localX <= canvasSize.X and localY <= canvasSize.Y then
			local beforeX, beforeZ = canvasToWorld(localX, localY, canvasSize, oldZoom, STATE.panWorld)
			local afterX, afterZ = canvasToWorld(localX, localY, canvasSize, STATE.fullZoom, STATE.panWorld)
			STATE.panWorld = STATE.panWorld + Vector2.new(afterX - beforeX, afterZ - beforeZ)
		end
	end
	clampPan()
	markFullMapInteraction()
end

local function applyFullZoom(deltaSign, focusAbs)
	setFullZoom(STATE.fullZoom * (1 + MapConfig.Fullscreen.ZoomStep) ^ deltaSign, focusAbs)
end

local function applyMinimapZoom(deltaSign)
	STATE.minimapRange = math.clamp(
		STATE.minimapRange - (MapConfig.Minimap.ZoomStep * deltaSign),
		MapConfig.Minimap.MinRange,
		MapConfig.Minimap.MaxRange
	)
end

local function startDrag(input)
	local point = pointerPosition(input)
	if not canGestureMap(point) or INPUT.dragInput == input then return end
	INPUT.dragInput = input
	INPUT.dragging = true
	INPUT.pressPosition = point
	INPUT.dragDistance = 0
	markFullMapInteraction()
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		INPUT.lastTouchPan = mouseGuiPosition()
	else
		INPUT.lastTouchPan = input.Position
	end
end

local function endDrag(input)
	if INPUT.dragInput == input then
		local point = pointerPosition(input)
		local placeMarker = INPUT.dragDistance < 8 and INPUT.pressPosition ~= nil and canGestureMap(point)
		INPUT.dragInput = nil
		INPUT.dragging = false
		INPUT.lastTouchPan = nil
		INPUT.pressPosition = nil
		INPUT.dragDistance = 0
		if placeMarker then toggleCrewMarkerAt(point) end
	end
end

local function updateDrag(input)
	if not STATE.fullMapOpen or not INPUT.dragging then return end
	local dragInput = INPUT.dragInput
	if not dragInput then return end
	-- Mouse drag is handled in RenderStepped for reliability.
	if dragInput.UserInputType == Enum.UserInputType.MouseButton1 then
		return
	end
	if dragInput ~= input then
		return
	end
	if not UI.fullCanvas then return end
	local absSize = UI.fullCanvas.AbsoluteSize
	local scale = mapScale(absSize, STATE.fullZoom)
	if scale <= 0 then return end

	local currentPos = input.Position
	local prevPos = INPUT.lastTouchPan or currentPos
	local delta = currentPos - prevPos
	INPUT.lastTouchPan = currentPos
	if delta.Magnitude == 0 then return end
	INPUT.dragDistance += delta.Magnitude

	STATE.panWorld = STATE.panWorld + Vector2.new(delta.X / scale, -delta.Y / scale)
	clampPan()
	markFullMapInteraction()
end

local function updateMouseDrag()
	if not STATE.fullMapOpen or not INPUT.dragging then return end
	local dragInput = INPUT.dragInput
	if not dragInput or dragInput.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
		INPUT.dragInput = nil
		INPUT.dragging = false
		INPUT.lastTouchPan = nil
		INPUT.pressPosition = nil
		INPUT.dragDistance = 0
		return
	end
	if not UI.fullCanvas then return end
	local absSize = UI.fullCanvas.AbsoluteSize
	local scale = mapScale(absSize, STATE.fullZoom)
	if scale <= 0 then return end

	local currentPos = mouseGuiPosition()
	local prevPos = INPUT.lastTouchPan or currentPos
	local delta = currentPos - prevPos
	INPUT.lastTouchPan = currentPos
	if delta.Magnitude == 0 then return end
	INPUT.dragDistance += delta.Magnitude

	STATE.panWorld = STATE.panWorld + Vector2.new(delta.X / scale, -delta.Y / scale)
	clampPan()
	markFullMapInteraction()
end

local function bindMapKey()
	ContextActionService:UnbindAction(MAP_TOGGLE_ACTION)
	ContextActionService:BindAction(MAP_TOGGLE_ACTION, function(_, inputState)
		if not Settings.CanInput() or inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		toggleFullMap()
		return Enum.ContextActionResult.Sink
	end, false, Settings.Key("Map"), Enum.KeyCode.ButtonSelect)
end
Settings.Changed:Connect(bindMapKey)
local function bindInput()
	bindMapKey()

	if UI.fullCanvas then
		UI.fullCanvas.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				startDrag(input)
			end
		end)
		UI.fullCanvas.InputEnded:Connect(endDrag)
	end

	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			if canGestureMap(pointerPosition(input)) then
				applyFullZoom(input.Position.Z > 0 and 1 or -1, pointerPosition(input))
			elseif UI.minimapFrame and getMouseOver(UI.minimapFrame) then
				applyMinimapZoom(input.Position.Z > 0 and 1 or -1)
			end
		elseif not gameProcessed and input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2 then
			INPUT.gamepadPan = Vector2.new(input.Position.X, input.Position.Y)
		end

		-- Keep map drag responsive even when core scripts mark input as processed.
		if not gameProcessed or INPUT.dragging then
			updateDrag(input)
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		endDrag(input)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2 then
			INPUT.gamepadPan = Vector2.new(0, 0)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
			and STATE.fullMapOpen
			and UI.fullCanvas
			and canGestureMap(pointerPosition(input)) then
			startDrag(input)
		end

		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.Escape and STATE.fullMapOpen then
			setFullMapOpen(false)
			return
		end

		if input.KeyCode == Enum.KeyCode.Equals or input.KeyCode == Enum.KeyCode.Plus or input.KeyCode == Enum.KeyCode.RightBracket or input.KeyCode == Enum.KeyCode.ButtonR2 then
			if STATE.fullMapOpen then
				applyFullZoom(1, mouseGuiPosition())
			else
				applyMinimapZoom(1)
			end
		elseif input.KeyCode == Enum.KeyCode.Minus or input.KeyCode == Enum.KeyCode.LeftBracket or input.KeyCode == Enum.KeyCode.ButtonL2 then
			if STATE.fullMapOpen then
				applyFullZoom(-1, mouseGuiPosition())
			else
				applyMinimapZoom(-1)
			end
		end
	end)

	local pinchZoom
	pcall(function()
		UserInputService.TouchPinch:Connect(function(positions, scale, _, state, gameProcessed)
			if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				pinchZoom = nil
				return
			end
			if not STATE.fullMapOpen or #positions < 2 then return end
			for _, position in ipairs(positions) do if not canGestureMap(position) then pinchZoom = nil; return end end
			if state == Enum.UserInputState.Begin then pinchZoom = STATE.fullZoom end
			if not pinchZoom then return end
			-- Scale is relative to gesture start; zoom around the fingers, not a stale mouse position.
			INPUT.dragging, INPUT.dragInput, INPUT.lastTouchPan = false, nil, nil
			INPUT.pressPosition, INPUT.dragDistance = nil, 0
			setFullZoom(pinchZoom * scale, (positions[1] + positions[2]) * 0.5)
		end)
	end)
end

local function acquireMinimapBlip(index)
	local blip = RENDER_CACHE.minimapBlips[index]
	if blip then
		return blip
	end
	blip = Instance.new("Frame")
	blip.AnchorPoint = Vector2.new(0.5, 0.5)
	blip.Size = UDim2.fromOffset(8, 8)
	blip.BorderSizePixel = 0
	blip.Visible = false
	blip.Parent = UI.minimapBlips
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = blip
	RENDER_CACHE.minimapBlips[index] = blip
	return blip
end

local function hideUnusedMinimapBlips(fromIndex)
	for i = fromIndex, #RENDER_CACHE.minimapBlips do
		RENDER_CACHE.minimapBlips[i].Visible = false
	end
end

local function getNearestRegionName(wx, wz)
	local bestName = nil
	local bestDist = math.huge
	for key, chunk in pairs(WORLD.chunksByKey) do
		if not STATE.fogEnabled or WORLD.exploredChunks[key] then
			for i = 1, #chunk.regions do
				local region = chunk.regions[i]
				local halfX = region.sx * 0.5
				local halfZ = region.sz * 0.5
				local inside = (wx >= region.x - halfX and wx <= region.x + halfX and wz >= region.z - halfZ and wz <= region.z + halfZ)
				if inside then
					return region.name
				end
				local dx = wx - region.x
				local dz = wz - region.z
				local dist = dx * dx + dz * dz
				if dist < bestDist then
					bestDist = dist
					bestName = region.name
				end
			end
		end
	end
	return bestName
end

local function acquireNamedFrame(cacheTable, key, parent)
	local frame = cacheTable[key]
	if frame then
		return frame
	end
	frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.Visible = true
	frame.Parent = parent
	cacheTable[key] = frame
	return frame
end

local function acquireMarkerFrame(key)
	local frame = RENDER_CACHE.markerFrames[key]
	if frame then return frame end

	frame = Instance.new("Frame")
	frame.Name = key
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(10, 10)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = MapConfig.Colors.TextPrimary
	frame.Visible = true
	frame.Parent = UI.fullMarkerLayer
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame

	RENDER_CACHE.markerFrames[key] = frame
	return frame
end

local function acquireMinimapMarkerFrame(key)
	local frame = RENDER_CACHE.minimapMarkerFrames[key]
	if frame then return frame end

	frame = Instance.new("Frame")
	frame.Name = key
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(10, 10)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = MapConfig.Colors.TextPrimary
	frame.Visible = true
	frame.Parent = UI.minimapMarkerLayer
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame

	RENDER_CACHE.minimapMarkerFrames[key] = frame
	return frame
end

local function hideUnusedNamedFrames(cacheTable, usedTable)
	for key, frame in pairs(cacheTable) do
		frame.Visible = usedTable[key] == true
	end
end

local function styleMarkerFrame(frame, markerKind, rotation, markerSize, glyphKey)
	if not frame then return end
	frame.Size = UDim2.fromOffset(markerSize, markerSize)
	frame.AnchorPoint = glyphKey == "CrewMarker" and Vector2.new(0.5, 1) or Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = colorForMarkerType(markerKind)

	if markerKind == "Players" or markerKind == "Enemies" or markerKind == "Spawn" then
		frame.Rotation = markerRotationWithOffset(rotation or 0, markerKind)
	else
		frame.Rotation = (markerKind == "Objectives") and (rotation or 0) or 0
	end

	local direction = frame:FindFirstChild("Direction")
	if direction then
		direction:Destroy() -- remove legacy triangle symbol
	end
	if markerKind == "Players" and type(glyphKey) == "table" and glyphKey.Type == "portrait" then
		-- The whole headshot turns; its top notch uses the same zero/up heading
		-- as the old arrow and the map's existing axis-flipped projection.
		applyPlayerPortrait(frame, glyphKey)
		return
	end

	if glyphKey then
		applyGlyphToFrame(frame, glyphKey, colorForMarkerType(markerKind), math.max(12, markerSize - 1))
		frame.BackgroundTransparency = 1
	else
		clearGlyphFromFrame(frame)
		frame.BackgroundTransparency = 0
	end

end

-- Interior coordinates are deliberately separate from the shifting surface atlas.
local function renderInteriorMap(canvas,mini)
 local overlay=canvas:FindFirstChild("InteriorLayer")
 if not overlay then overlay=buildCoreFrame(canvas,UDim2.fromScale(1,1),UDim2.fromOffset(0,0),Theme.Colors.Night,0);overlay.Name="InteriorLayer";overlay.ZIndex=15 end
 local enabled=mini and player:GetAttribute("InteriorId")~=nil or not mini and STATE.mapLayer=="Interior"
 overlay.Visible=enabled
 if not enabled then return false end
 local folder=interiorFolder();local used={}
 if not folder then return true end
 local origin=folder:GetAttribute("MapOrigin");if typeof(origin)~="Vector3" then return true end
 local size=mini and Vector2.new(canvas.Size.X.Offset,canvas.Size.Y.Offset) or canvas.AbsoluteSize
 local scale=math.min(size.X,size.Y)/228
 local function project(pos)
  if not mini then return worldToCanvas(pos.X,pos.Z,size,STATE.fullZoom,STATE.panWorld) end
  local x,z=mapOrientedXZ(pos.X-origin.X,pos.Z-origin.Z)
  return size.X*.5+x*scale,size.Y*.5-z*scale,scale
 end
 local function frame(key)
  local f=overlay:FindFirstChild(key)
  if not f then f=buildCoreFrame(overlay,UDim2.fromOffset(1,1),UDim2.fromOffset(0,0),Theme.Colors.Accent,0);f.Name=key end
  f.Visible=true;used[key]=true;return f
 end
 for i,part in ipairs(folder:GetChildren()) do
  if part:IsA("BasePart") and part.Transparency<.95 then
   local x,y,factor=project(part.Position);local f=frame("room_"..i)
   f.AnchorPoint=Vector2.new(.5,.5);f.Position=UDim2.fromOffset(x,y)
   f.Size=UDim2.fromOffset(math.max(2,part.Size.X*factor),math.max(2,part.Size.Z*factor))
   f.BackgroundColor3=part.Color;f.BackgroundTransparency=part.Name=="Floor" and .65 or .1;f.ZIndex=part.Name=="Floor" and 15 or 16
  end
 end
 for _,p in ipairs(Players:GetPlayers()) do
  if p:GetAttribute("InteriorId")==player:GetAttribute("InteriorId") then
   local pos,look=getPlayerMapPose(p)
   if pos then local x,y=project(pos);local f=frame("crew_"..p.UserId)
    f.AnchorPoint=Vector2.new(.5,.5);f.Position=UDim2.fromOffset(x,y);f.Size=UDim2.fromOffset(mini and 16 or 26,mini and 16 or 26)
    f.ZIndex=20;f.BackgroundTransparency=1;f.Rotation=headingDegFromLook(look);applyPlayerPortrait(f,getPlayerGlyph(p))
   end
  end
 end
 for i,actor in ipairs(folder:GetChildren()) do
  if actor:IsA("Model") and actor:FindFirstChildOfClass("Humanoid") and actor:FindFirstChildOfClass("Humanoid").Health>0 then
   local x,y=project(actor:GetPivot().Position);local f=frame("enemy_"..i)
   f.AnchorPoint=Vector2.new(.5,.5);f.Position=UDim2.fromOffset(x,y);f.Size=UDim2.fromOffset(mini and 5 or 9,mini and 5 or 9);f.BackgroundColor3=Color3.fromRGB(222,97,74);f.ZIndex=19
  end
 end
 for _,f in ipairs(overlay:GetChildren()) do if f:IsA("GuiObject") and not used[f.Name] then f.Visible=false end end
 return true
end
local function renderFullscreen(playerPos)
	if not UI.fullCanvas or not UI.fullRoot.Visible then return end
 if renderInteriorMap(UI.fullCanvas,false) then return end

	local canvasSize = UI.fullCanvas.AbsoluteSize
	if canvasSize.X <= 0 or canvasSize.Y <= 0 then return end

	tableClear(RENDER_CACHE.usedChunkKeys)
	tableClear(RENDER_CACHE.usedRegionKeys)
	tableClear(RENDER_CACHE.usedMarkerKeys)

	updateLegendButtons()
	getOptionalMarkers()

	for key, chunk in pairs(WORLD.chunksByKey) do
		if isChunkExplored(chunk.cx, chunk.cz) and chunkLayer(chunk)==STATE.mapLayer then
			local cx, cz = chunkCenter(chunk.cx, chunk.cz)
			local px, py, scale = worldToCanvas(cx, cz, canvasSize, STATE.fullZoom, STATE.panWorld)
			local sizePx = math.max(2, CHUNK_SIZE * scale)
			if px + sizePx >= -8 and py + sizePx >= -8 and px - sizePx <= canvasSize.X + 8 and py - sizePx <= canvasSize.Y + 8 then
				local frame = acquireNamedFrame(RENDER_CACHE.chunkFrames, key, UI.fullChunkLayer)
				frame.Position = UDim2.fromOffset(math.floor(px - sizePx * 0.5), math.floor(py - sizePx * 0.5))
				frame.Size = UDim2.fromOffset(math.ceil(sizePx), math.ceil(sizePx))
				frame.BackgroundColor3 = terrainMapColor(chunk)
				frame.BackgroundTransparency = 0.16
				local label = frame:FindFirstChild("BiomeLabel")
				if not label then
					label = buildLabel(frame, "", UDim2.new(1, -8, 0, 22), UDim2.fromOffset(4, 4), Enum.Font.GothamBold, 14, MapConfig.Colors.TextPrimary, Enum.TextXAlignment.Center)
					label.Name = "BiomeLabel"
					label.TextStrokeTransparency = 0.35
				end
				local metadata = BiomeConfig.biome_metadata[chunk.biome]
				label.Text = metadata and metadata.DisplayName or chunk.biome
				-- Keep the name in the visible part of a tile when zoom crops its edges.
				local left = math.max(4, -frame.Position.X.Offset + 4)
				local right = math.min(sizePx - 4, canvasSize.X - frame.Position.X.Offset - 4)
				local top = math.max(4, -frame.Position.Y.Offset + 4)
				local bottom = math.min(sizePx - 4, canvasSize.Y - frame.Position.Y.Offset - 4)
				label.Position = UDim2.fromOffset(left, top)
				label.Size = UDim2.fromOffset(math.max(0, right - left), 22)
				label.Visible = STATE.markerVisibility.Regions and right - left >= 124 and bottom - top >= 22
				RENDER_CACHE.usedChunkKeys[key] = true
			end
		end
	end

	if STATE.markerVisibility.Regions then
		for key, chunk in pairs(WORLD.chunksByKey) do
			if isChunkExplored(chunk.cx, chunk.cz) and chunkLayer(chunk)==STATE.mapLayer then
				for i = 1, #chunk.regions do
					local region = chunk.regions[i]
					local rk = key .. ":" .. tostring(i)
					local rx, ry, scale = worldToCanvas(region.x, region.z, canvasSize, STATE.fullZoom, STATE.panWorld)
					local rw = math.max(3, region.sx * scale)
					local rh = math.max(3, region.sz * scale)
					local frame = acquireNamedFrame(RENDER_CACHE.regionFrames, rk, UI.fullRegionLayer)
					frame.Position = UDim2.fromOffset(math.floor(rx - rw * 0.5), math.floor(ry - rh * 0.5))
					frame.Size = UDim2.fromOffset(math.ceil(rw), math.ceil(rh))
					local style = resolveRegionStyle(region.name)
					frame.BackgroundColor3 = style.FillColor
					frame.BackgroundTransparency = math.clamp(style.FillTransparency, 0, 1)
					local stroke = frame:FindFirstChildOfClass("UIStroke")
					if not stroke then
						stroke = Instance.new("UIStroke")
						stroke.Parent = frame
						stroke.Thickness = 1
					end
					stroke.Color = style.StrokeColor
					stroke.Transparency = math.clamp(style.StrokeTransparency, 0, 1)

					local label = frame:FindFirstChild("Label")
					if not label then
						label = buildLabel(frame, "", UDim2.new(1, -8, 1, -8), UDim2.fromOffset(4, 4), Enum.Font.GothamMedium, 14, MapConfig.Colors.TextPrimary, Enum.TextXAlignment.Center)
						label.Name = "Label"
						label.TextWrapped = true
						label.TextStrokeTransparency = 0.35
					end
					label.Text = region.name:gsub("(%l)(%u)", "%1 %2")
					local left = math.max(4, -frame.Position.X.Offset + 4)
					local right = math.min(rw - 4, canvasSize.X - frame.Position.X.Offset - 4)
					local top = math.max(4, -frame.Position.Y.Offset + 4)
					local bottom = math.min(rh - 4, canvasSize.Y - frame.Position.Y.Offset - 4)
					label.Position = UDim2.fromOffset(left, top)
					label.Size = UDim2.fromOffset(math.max(0, right - left), math.max(0, bottom - top))
					label.Visible = style.ShowLabel and right - left >= 68 and bottom - top >= 40

					local canShowGlyph = not label.Visible and rw > 16 and rh > 16
					if canShowGlyph and style.Glyph then
						applyGlyphToFrame(frame, style.Glyph, style.StrokeColor, math.max(10, math.floor(math.min(rw, rh) * 0.33)))
					else
						clearGlyphFromFrame(frame)
					end
					RENDER_CACHE.usedRegionKeys[rk] = true
				end
			end
		end
	end

	local function drawMarker(key, wx, wz, markerKind, rotation, size, glyphKey, explicitLayer)
  if explicitLayer then
   if explicitLayer~=STATE.mapLayer then return end
  else
   local cell=WORLD.chunksByKey[chunkKey(math.floor(wx/CHUNK_SIZE),math.floor(wz/CHUNK_SIZE))]
   if cell and chunkLayer(cell)~=STATE.mapLayer then return end
  end
		local px, py = worldToCanvas(wx, wz, canvasSize, STATE.fullZoom, STATE.panWorld)
		if px < -20 or py < -20 or px > canvasSize.X + 20 or py > canvasSize.Y + 20 then
			return
		end
		local markerSize = size
		if markerKind == "Enemies" or markerKind == "Spawn" then
			local zoomScale = math.clamp(STATE.fullZoom, 0.75, 2.5)
			markerSize = math.max(10, math.floor(size * zoomScale + 0.5))
		end
		local frame = acquireMarkerFrame(key)
		frame.Position = UDim2.fromOffset(px, py)
		styleMarkerFrame(frame, markerKind, rotation, markerSize, glyphKey)
		frame.Visible = true
		RENDER_CACHE.usedMarkerKeys[key] = true
	end

	if STATE.markerVisibility.Spawn and STATE.spawnPosition then
		local spawnRotation = 0
		if playerPos and typeof(playerPos) == "Vector3" then
			spawnRotation = headingDegFromPoints(STATE.spawnPosition, playerPos)
		end
		drawMarker("spawn", STATE.spawnPosition.X, STATE.spawnPosition.Z, "Spawn", spawnRotation, 28, "Spawn")
	end
	local crewMarker = getCrewMarker()
	if crewMarker and crewMarker.Layer == STATE.mapLayer then
		drawMarker("crew_marker", crewMarker.X, crewMarker.Z, "Objectives", 0, 20, "CrewMarker", crewMarker.Layer)
	end

	if STATE.markerVisibility.Structures or STATE.markerVisibility.Objectives then
		for inst, data in pairs(WORLD.markersByInstance) do
			if inst.Parent then
				local group = normalizeMarkerType(data.markerType)
				if group and STATE.markerVisibility[group] then
					local pos = getObjectPosition(inst)
					if pos and isPositionExplored(pos) then
						drawMarker("marker_" .. tostring(inst), pos.X, pos.Z, group, group == "Objectives" and 45 or 0, group == "Objectives" and 11 or 9, glyphKeyForMapMarkerGroup(group))
					end
				end
			end
		end
	end

	if STATE.markerVisibility.Players then
		for _, plr in ipairs(Players:GetPlayers()) do
			local position, look = getPlayerMapPose(plr)
			if position and (plr:GetAttribute("MapLayer") or "Surface")==STATE.mapLayer then
				local heading = headingDegFromLook(look)
				local size = (MapConfig.PlayerPortraits and MapConfig.PlayerPortraits.FullscreenSize) or 24
				drawMarker("player_" .. tostring(plr.UserId), position.X, position.Z, "Players", heading, size, getPlayerGlyph(plr))
			end
		end
	end

	if STATE.markerVisibility.Resources then
		for i = 1, #WORLD.resourceEntries do
			local entry = WORLD.resourceEntries[i]
			local pos = entry.position
			if pos and isPositionExplored(pos) then
				drawMarker("resource_" .. tostring(entry.instance), pos.X, pos.Z, "Resources", 0, 6)
			end
		end
	end

	if STATE.markerVisibility.Enemies then
		for i = 1, #WORLD.enemyEntries do
			local entry = WORLD.enemyEntries[i]
			local pos = entry.position
			local heading = entry.look and headingDegFromLook(entry.look) or 0
			local enemyInst = entry.instance
			if enemyInst and enemyInst.Parent then
				local root = enemyInst:FindFirstChild("HumanoidRootPart") or enemyInst.PrimaryPart
				if root and root:IsA("BasePart") then
					pos = root.Position
					heading = headingDegFromLook(root.CFrame.LookVector)
				end
			end
			if pos and isPositionExplored(pos) then
				drawMarker("enemy_" .. tostring(entry.instance), pos.X, pos.Z, "Enemies", heading, 20, getEnemyGlyph(entry.instance))
			end
		end
	end

	for name, data in pairs(STATE.customBlips) do
		local pos = data.position
		if typeof(pos) == "Vector3" and isPositionExplored(pos) then
			drawMarker("custom_" .. name, pos.X, pos.Z, "Objectives", 0, 8)
		end
	end

	for key, data in pairs(STATE.abilityBlips) do
		if data.Expires <= os.clock() then STATE.abilityBlips[key] = nil; continue end
		local pos = data.Position
		if data.Target and data.Target:IsDescendantOf(workspace) then
			pos = data.Target:IsA("Model") and data.Target:GetPivot().Position or data.Target:IsA("BasePart") and data.Target.Position or pos
		end
		if typeof(pos) == "Vector3" then
			local kind = data.Kind == "Monster" and "Enemies" or data.Kind == "Structure" and "Structures" or "Resources"
			drawMarker("ability_" .. key, pos.X, pos.Z, kind, 0, 12)
		end
	end

	hideUnusedNamedFrames(RENDER_CACHE.chunkFrames, RENDER_CACHE.usedChunkKeys)
	hideUnusedNamedFrames(RENDER_CACHE.regionFrames, RENDER_CACHE.usedRegionKeys)
	hideUnusedNamedFrames(RENDER_CACHE.markerFrames, RENDER_CACHE.usedMarkerKeys)

	if UI.zoomLabel then
		UI.zoomLabel.Text = string.format("Zoom: %d%%", math.floor(STATE.fullZoom * 100 + 0.5))
	end

	if UI.cursorLabel then
		if getMouseOver(UI.fullCanvas) then
			local mouse = mouseGuiPosition()
			local localPos = mouse - UI.fullCanvas.AbsolutePosition
			local wx, wz = canvasToWorld(localPos.X, localPos.Y, canvasSize, STATE.fullZoom, STATE.panWorld)
			local region = getNearestRegionName(wx, wz)
			if region then
				UI.cursorLabel.Text = string.format("Cursor: X %d, Z %d\nRegion: %s", math.floor(wx), math.floor(wz), region)
			else
				UI.cursorLabel.Text = string.format("Cursor: X %d, Z %d\nRegion: -", math.floor(wx), math.floor(wz))
			end
		else
			UI.cursorLabel.Text = "Cursor: -"
		end
	end
end

local function renderMinimap(playerPos, playerLook)
	if not UI.minimapContainer then return end
	UI.minimapContainer.Visible = STATE.minimapVisible and playerPos ~= nil and not (Theme.IsMobile() and (playerGui:GetAttribute("BuildPlacementActive") or playerGui:GetAttribute("MenuCursorOpen")))
	if not STATE.minimapVisible then return end
	if not playerPos then return end
 if renderInteriorMap(UI.minimapFrame,true) then return end
	local playerMapX, playerMapZ = mapOrientedXZ(playerPos.X, playerPos.Z)

	UI.minimapCoords.Text = string.format("X: %d  Z: %d", math.floor(playerPos.X), math.floor(playerPos.Z))
	UI.minimapZoom.Text = string.format("Range: %dm", math.floor(STATE.minimapRange))

	-- Marker/tile offsets use the map's local pixels. AbsoluteSize includes
	-- Theme.Fit's UIScale and would scale the projection a second time.
	local mapSize = UI.minimapFrame and Vector2.new(UI.minimapFrame.Size.X.Offset, UI.minimapFrame.Size.Y.Offset) or Vector2.zero
	if mapSize.X <= 0 or mapSize.Y <= 0 then return end

	local radiusPx = math.max(8, math.min(mapSize.X, mapSize.Y) * 0.5 - 4)
	local centerX = mapSize.X * 0.5
	local centerY = mapSize.Y * 0.5
	local scale = radiusPx / math.max(STATE.minimapRange, 1)
	local miniZoomScale = math.clamp((MapConfig.Minimap.Range or STATE.minimapRange) / math.max(STATE.minimapRange, 1), 0.75, 2.5)
	local minimapEmojiScale = math.clamp(tonumber(MapConfig.Minimap.EmojiScale) or 0.7, 0.4, 1.5)
	local screenScale = math.max(.1, UI.minimapFrame.AbsoluteSize.X / mapSize.X)
	-- Keep portraits small at large UI scales and legible when the HUD shrinks.
	local portraitPixels = math.min((MapConfig.PlayerPortraits and MapConfig.PlayerPortraits.MinimapSize) or 21.6, UI.minimapFrame.AbsoluteSize.X * .24)
	local miniPortraitSize = portraitPixels / screenScale

	tableClear(RENDER_CACHE.usedMinimapChunkKeys)
	tableClear(RENDER_CACHE.usedMinimapRegionKeys)
	tableClear(RENDER_CACHE.usedMinimapMarkerKeys)

	local function worldToMiniPixels(worldX, worldZ, clampToEdge)
		local mapX, mapZ = mapOrientedXZ(worldX, worldZ)
		local dx = (mapX - playerMapX) * scale
		local dy = -(mapZ - playerMapZ) * scale
		local dist = math.sqrt(dx * dx + dy * dy)
		if dist > radiusPx then
			if clampToEdge and dist > 0 then
				local f = radiusPx / dist
				return centerX + (dx * f), centerY + (dy * f), true
			end
			return nil, nil, true
		end
		return centerX + dx, centerY + dy, false
	end

	for key, chunk in pairs(WORLD.chunksByKey) do
		if isChunkExplored(chunk.cx, chunk.cz) then
			local cx, cz = chunkCenter(chunk.cx, chunk.cz)
			local mx, my = worldToMiniPixels(cx, cz, false)
			local sizePx = math.max(2, CHUNK_SIZE * scale)
			local relX = (mx or centerX) - centerX
			local relY = (my or centerY) - centerY
			if math.abs(relX) <= (radiusPx + sizePx) and math.abs(relY) <= (radiusPx + sizePx) then
				local frame = acquireNamedFrame(RENDER_CACHE.minimapChunkFrames, key, UI.minimapChunkLayer)
				frame.Position = UDim2.fromOffset(math.floor((mx or centerX) - sizePx * 0.5), math.floor((my or centerY) - sizePx * 0.5))
				frame.Size = UDim2.fromOffset(math.ceil(sizePx), math.ceil(sizePx))
				frame.BackgroundColor3 = terrainMapColor(chunk)
				frame.BackgroundTransparency = 0.16
				RENDER_CACHE.usedMinimapChunkKeys[key] = true
			end
		end
	end

	if STATE.markerVisibility.Regions then
		for key, chunk in pairs(WORLD.chunksByKey) do
			if isChunkExplored(chunk.cx, chunk.cz) then
				for i = 1, #chunk.regions do
					local region = chunk.regions[i]
					local rk = key .. ":" .. tostring(i)
					local mx, my = worldToMiniPixels(region.x, region.z, false)
					local rw = math.max(3, region.sx * scale)
					local rh = math.max(3, region.sz * scale)
					local relX = (mx or centerX) - centerX
					local relY = (my or centerY) - centerY
					if math.abs(relX) <= (radiusPx + rw) and math.abs(relY) <= (radiusPx + rh) then
						local frame = acquireNamedFrame(RENDER_CACHE.minimapRegionFrames, rk, UI.minimapRegionLayer)
						frame.Position = UDim2.fromOffset(math.floor((mx or centerX) - rw * 0.5), math.floor((my or centerY) - rh * 0.5))
						frame.Size = UDim2.fromOffset(math.ceil(rw), math.ceil(rh))
						local style = resolveRegionStyle(region.name)
						frame.BackgroundColor3 = style.FillColor
						frame.BackgroundTransparency = math.clamp(style.FillTransparency, 0, 1)
						local stroke = frame:FindFirstChildOfClass("UIStroke")
						if not stroke then
							stroke = Instance.new("UIStroke")
							stroke.Parent = frame
							stroke.Thickness = 1
						end
						stroke.Color = style.StrokeColor
						stroke.Transparency = math.clamp(style.StrokeTransparency, 0, 1)

						local label = frame:FindFirstChild("Label")
						if not label then
							label = buildLabel(frame, "", UDim2.new(1, -4, 0, 12), UDim2.fromOffset(2, 2), Enum.Font.Gotham, 10, MapConfig.Colors.TextMuted, Enum.TextXAlignment.Center)
							label.Name = "Label"
						end
						label.Text = region.name
						label.TextColor3 = style.StrokeColor
						label.Visible = style.ShowLabel and rw > 42 and rh > 18

						local canShowGlyph = rw > 16 and rh > 16
						if canShowGlyph and style.Glyph then
							applyGlyphToFrame(frame, style.Glyph, style.StrokeColor, math.max(10, math.floor(math.min(rw, rh) * 0.33)))
						else
							clearGlyphFromFrame(frame)
						end

						RENDER_CACHE.usedMinimapRegionKeys[rk] = true
					end
				end
			end
		end
	end

	local function drawMiniMarker(key, worldX, worldZ, markerKind, rotation, size, glyphKey, clampToEdge)
		local mx, my = worldToMiniPixels(worldX, worldZ, clampToEdge)
		if not mx then
			return
		end
		local markerSize = size
		if markerKind == "Enemies" or markerKind == "Spawn" then
			markerSize = math.max(10, math.floor(size * miniZoomScale + 0.5))
		end
		if glyphKey and markerKind ~= "Players" then
			markerSize = math.max(8, math.floor(markerSize * minimapEmojiScale + 0.5))
		end
		local frame = acquireMinimapMarkerFrame(key)
		frame.Position = UDim2.fromOffset(mx, my)
		styleMarkerFrame(frame, markerKind, rotation, markerSize, glyphKey)
		frame.Visible = true
		RENDER_CACHE.usedMinimapMarkerKeys[key] = true
	end

	-- Always center local player marker, styled like main map markers.
	local playerHeading = headingDegFromLook(playerLook)
	local localPlayerSize = miniPortraitSize
	styleMarkerFrame(UI.minimapPlayer, "Players", playerHeading, localPlayerSize, getPlayerGlyph(player))
	UI.minimapPlayer.Position = UDim2.fromOffset(centerX, centerY)

	if STATE.markerVisibility.Spawn and STATE.spawnPosition then
		local spawnRotation = headingDegFromPoints(STATE.spawnPosition, playerPos)
		drawMiniMarker("spawn", STATE.spawnPosition.X, STATE.spawnPosition.Z, "Spawn", spawnRotation, 28, "Spawn", true)
	end
	local crewMarker = getCrewMarker()
	if crewMarker and crewMarker.Layer == STATE.mapLayer then
		drawMiniMarker("crew_marker", crewMarker.X, crewMarker.Z, "Objectives", 0, 18, "CrewMarker", true)
	end

	if STATE.markerVisibility.Structures or STATE.markerVisibility.Objectives then
		for inst, data in pairs(WORLD.markersByInstance) do
			if inst.Parent then
				local group = normalizeMarkerType(data.markerType)
				if group and STATE.markerVisibility[group] then
					local pos = getObjectPosition(inst)
					if pos and isPositionExplored(pos) then
						drawMiniMarker("marker_" .. tostring(inst), pos.X, pos.Z, group, group == "Objectives" and 45 or 0, group == "Objectives" and 11 or 9, glyphKeyForMapMarkerGroup(group), false)
					end
				end
			end
		end
	end

	if STATE.markerVisibility.Players then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player then
				local position, look = getPlayerMapPose(plr)
				if position then
					local heading = headingDegFromLook(look)
					drawMiniMarker("player_" .. tostring(plr.UserId), position.X, position.Z, "Players", heading, miniPortraitSize, getPlayerGlyph(plr), false)
				end
			end
		end
	end

	if STATE.markerVisibility.Enemies then
		for i = 1, #WORLD.enemyEntries do
			local entry = WORLD.enemyEntries[i]
			local pos = entry.position
			local heading = entry.look and headingDegFromLook(entry.look) or 0
			local enemyInst = entry.instance
			if enemyInst and enemyInst.Parent then
				local root = enemyInst:FindFirstChild("HumanoidRootPart") or enemyInst.PrimaryPart
				if root and root:IsA("BasePart") then
					pos = root.Position
					heading = headingDegFromLook(root.CFrame.LookVector)
				end
			end
			if pos and isPositionExplored(pos) then
				drawMiniMarker("enemy_" .. tostring(entry.instance), pos.X, pos.Z, "Enemies", heading, 20, getEnemyGlyph(entry.instance), false)
			end
		end
	end

	if STATE.markerVisibility.Resources then
		for i = 1, #WORLD.resourceEntries do
			local entry = WORLD.resourceEntries[i]
			local pos = entry.position
			if pos and isPositionExplored(pos) then
				drawMiniMarker("resource_" .. tostring(entry.instance), pos.X, pos.Z, "Resources", 0, 6, nil, false)
			end
		end
	end

	for _, data in pairs(STATE.customBlips) do
		if typeof(data.position) == "Vector3" and isPositionExplored(data.position) then
			drawMiniMarker("custom_" .. tostring(data.position), data.position.X, data.position.Z, "Objectives", 0, 8, nil, false)
		end
	end

	for key, data in pairs(STATE.abilityBlips) do
		if data.Expires <= os.clock() then STATE.abilityBlips[key] = nil; continue end
		local pos = data.Position
		if data.Target and data.Target:IsDescendantOf(workspace) then
			pos = data.Target:IsA("Model") and data.Target:GetPivot().Position or data.Target:IsA("BasePart") and data.Target.Position or pos
		end
		if typeof(pos) == "Vector3" then
			local kind = data.Kind == "Monster" and "Enemies" or data.Kind == "Structure" and "Structures" or "Resources"
			drawMiniMarker("ability_" .. key, pos.X, pos.Z, kind, 0, 10, nil, false)
		end
	end

	hideUnusedNamedFrames(RENDER_CACHE.minimapChunkFrames, RENDER_CACHE.usedMinimapChunkKeys)
	hideUnusedNamedFrames(RENDER_CACHE.minimapRegionFrames, RENDER_CACHE.usedMinimapRegionKeys)
	hideUnusedNamedFrames(RENDER_CACHE.minimapMarkerFrames, RENDER_CACHE.usedMinimapMarkerKeys)
	hideUnusedMinimapBlips(1)
end

local function initSpawnCapture()
	local function resolveCampSpawn()
		-- The character's first replicated position can be a restored logout position.
		-- Spawn belongs to the world, so keep the marker anchored to the camp instead.
		local campCenter = Workspace:GetAttribute("CampCenter") or ReplicatedStorage:GetAttribute("CampCenter")
		if typeof(campCenter) == "Vector3" then
			return campCenter
		end

		local closestSpawn, closestDistance
		for _, instance in ipairs(Workspace:GetDescendants()) do
			if instance:IsA("SpawnLocation") then
				local distance = Vector2.new(instance.Position.X, instance.Position.Z).Magnitude
				if not closestDistance or distance < closestDistance then
					closestSpawn, closestDistance = instance, distance
				end
			end
		end
		local campRadius = tonumber(BiomeConfig.center_exclusion_radius) or 200
		if closestSpawn and closestDistance <= campRadius then
			return closestSpawn.Position
		end
		return Vector3.zero
	end

	local function refresh()
		STATE.spawnPosition = resolveCampSpawn()
		dprint("Camp spawn set", STATE.spawnPosition)
	end

	refresh()
	Workspace:GetAttributeChangedSignal("CampCenter"):Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal("CampCenter"):Connect(refresh)
	Workspace.DescendantAdded:Connect(function(instance)
		if instance:IsA("SpawnLocation") then refresh() end
	end)
end

local function applyGamepadPan(dt)
	if not STATE.fullMapOpen then return end
	if INPUT.gamepadPan.Magnitude < 0.08 then return end
	if not UI.fullCanvas then return end

	local pixelPerSec = MapConfig.Fullscreen.GamepadPanPixelsPerSecond
	local deltaPixels = INPUT.gamepadPan * pixelPerSec * dt
	local scale = mapScale(UI.fullCanvas.AbsoluteSize, STATE.fullZoom)
	if scale <= 0 then return end

	STATE.panWorld = STATE.panWorld + Vector2.new(-deltaPixels.X / scale, deltaPixels.Y / scale)
	clampPan()
	markFullMapInteraction()
end

local function updateCrewWaypoint(playerPosition)
	local root = UI.waypointRoot
	if not root then return end
	local marker = getCrewMarker()
	local currentLayer = player:GetAttribute("MapLayer") or "Surface"
	if STATE.fullMapOpen or player:GetAttribute("InteriorId") ~= nil or not marker or marker.Layer ~= currentLayer or not finiteVector3(playerPosition) then
		root.Visible = false
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		root.Visible = false
		return
	end
	local viewport = camera.ViewportSize
	local guiSize = UI.gui and UI.gui.AbsoluteSize or viewport
	if viewport.X <= 1 or viewport.Y <= 1 or guiSize.X <= 1 or guiSize.Y <= 1 then
		root.Visible = false
		return
	end

	-- The shared marker is horizontal map data. Project it at the local
	-- player's height so distant or streamed-out terrain is not required.
	local projected, inViewport = camera:WorldToViewportPoint(Vector3.new(marker.X, playerPosition.Y + 2.5, marker.Z))
	local point = Vector2.new(projected.X * guiSize.X / viewport.X, projected.Y * guiSize.Y / viewport.Y)
	local center = guiSize * 0.5
	local halfWidth = math.max(1, center.X - 58)
	local halfHeight = math.max(1, center.Y - 58)
	local onScreen = inViewport and projected.Z > 0
		and point.X >= 58 and point.X <= guiSize.X - 58
		and point.Y >= 58 and point.Y <= guiSize.Y - 58

	if not onScreen then
		local direction = point - center
		if projected.Z <= 0 then direction = -direction end
		if direction.Magnitude < 0.001 then direction = Vector2.new(0, -1) end
		local edgeScale = math.min(
			halfWidth / math.max(math.abs(direction.X), 0.001),
			halfHeight / math.max(math.abs(direction.Y), 0.001)
		)
		point = center + direction * edgeScale
	end

	local horizontalDistance = (Vector2.new(marker.X, marker.Z) - Vector2.new(playerPosition.X, playerPosition.Z)).Magnitude
	UI.waypointDistance.Text = string.format("%d studs", math.floor(horizontalDistance + 0.5))
	root.Position = UDim2.fromOffset(point.X, point.Y)
	root.Visible = true
end

local lastMinimapRender = 0
local lastFullRender = 0

local function update()
	local now = os.clock()
	local position, look = getPlayerMapPose(player)
	updateCrewWaypoint(position)
	if STATE.markerVisibility.Enemies or STATE.markerVisibility.Resources then
		getOptionalMarkers()
	end

	if (now - lastMinimapRender) >= (MapConfig.Minimap.UpdateRate or 0.12) then
		lastMinimapRender = now
		renderMinimap(position, look)
	end

	local fullRate = tonumber(MapConfig.Fullscreen.UpdateRate) or 0.1
	local boostedRate = tonumber(MapConfig.Fullscreen.BoostedUpdateRate)
	if boostedRate == nil then
		boostedRate = 0 -- 0 = every RenderStepped while interacting
	end
	local interacting = now < (STATE.fullRenderBoostUntil or 0)
	local fullInterval = interacting and math.max(0, boostedRate) or math.max(0, fullRate)

	if STATE.fullMapOpen and (fullInterval <= 0 or (now - lastFullRender) >= fullInterval) then
		lastFullRender = now
		renderFullscreen(position)
	end
end

-------------------------------------------------------------------
-- Public API (kept compatible with prior script)
-------------------------------------------------------------------
local MinimapClient = {}

function MinimapClient:SetRange(range)
	if type(range) ~= "number" then return end
	STATE.minimapRange = math.clamp(range, MapConfig.Minimap.MinRange, MapConfig.Minimap.MaxRange)
end

function MinimapClient:SetVisible(visible)
	STATE.minimapVisible = visible == true
	if UI.minimapContainer then
		UI.minimapContainer.Visible = STATE.minimapVisible and not (Theme.IsMobile() and (playerGui:GetAttribute("BuildPlacementActive") or playerGui:GetAttribute("MenuCursorOpen")))
	end
end

function MinimapClient:Toggle()
	toggleFullMap()
end

function MinimapClient:ZoomIn()
	if STATE.fullMapOpen then
		applyFullZoom(1, mouseGuiPosition())
	else
		applyMinimapZoom(1)
	end
end

function MinimapClient:ZoomOut()
	if STATE.fullMapOpen then
		applyFullZoom(-1, mouseGuiPosition())
	else
		applyMinimapZoom(-1)
	end
end

function MinimapClient:SetZoom(range)
	if type(range) ~= "number" then return end
	STATE.minimapRange = math.clamp(range, MapConfig.Minimap.MinRange, MapConfig.Minimap.MaxRange)
end

function MinimapClient:SetRotateWithPlayer(rotate)
	-- Minimap is intentionally north-up and non-rotating.
	MapConfig.Minimap.RotateWithPlayer = false
end

function MinimapClient:SetFogEnabled(enabled)
	STATE.fogEnabled = enabled == true
	if not STATE.fogEnabled then
		for key in pairs(WORLD.chunksByKey) do
			WORLD.exploredChunks[key] = true
		end
	end
end

function MinimapClient:RevealAll()
	STATE.fogEnabled = false
	for key in pairs(WORLD.chunksByKey) do
		WORLD.exploredChunks[key] = true
	end
end

function MinimapClient:ResetExploration()
	tableClear(WORLD.exploredChunks)
	-- A local debug reset cannot erase the expedition's shared discoveries.
	for key in pairs(WORLD.sharedChunksByKey) do WORLD.exploredChunks[key] = true end
end

function MinimapClient:SetSpawnPoint(position)
	if typeof(position) == "Vector3" then
		STATE.spawnPosition = position
	end
end

function MinimapClient:GetSpawnPoint()
	return STATE.spawnPosition
end

function MinimapClient:GetExploredCount()
	local c = 0
	for _ in pairs(WORLD.exploredChunks) do
		c += 1
	end
	return c
end

function MinimapClient:AddCustomBlip(name, worldPosition, color)
	if type(name) ~= "string" or typeof(worldPosition) ~= "Vector3" then return end
	STATE.customBlips[name] = { position = worldPosition, color = color }
end

function MinimapClient:ForceRescan()
	refreshGeneratedFolderBinding()
	for _, inst in ipairs(Workspace:GetDescendants()) do
		registerMarkerInstance(inst)
	end
end

local function init()
	local portraitAdded = Players.PlayerAdded:Connect(cachePlayerPortrait)
	for _, plr in ipairs(Players:GetPlayers()) do cachePlayerPortrait(plr) end
	createUI()
	initWorldBindings()
	initSpawnCapture()
	bindInput()

	local portraitRemoving = Players.PlayerRemoving:Connect(function(plr)
		local userId = plr and plr.UserId
		if type(userId) == "number" then
			playerPortraitCache[userId] = nil
			local key = "player_" .. tostring(userId)
			for _, cache in ipairs({ RENDER_CACHE.markerFrames, RENDER_CACHE.minimapMarkerFrames }) do
				if cache[key] then cache[key]:Destroy(); cache[key] = nil end
			end
		end
	end)
	script.Destroying:Connect(function()
		portraitAdded:Disconnect()
		portraitRemoving:Disconnect()
		cleanupConnections(WORLD.sharedRootConns)
		bindSharedExploration(nil)
		tableClear(playerPortraitCache) -- Invalidate any pending fetch/retry jobs.
	end)

	RunService.RenderStepped:Connect(function(dt)
		updateMouseDrag()
		applyGamepadPan(dt)
		update()
	end)

	dprint("Initialized", GENERATED_FOLDER_NAME)
end

init()

player:GetAttributeChangedSignal("FieldKitMap"):Connect(toggleFullMap)
player:GetAttributeChangedSignal("MapLayer"):Connect(function()
 STATE.mapLayer=player:GetAttribute("MapLayer") or "Surface"
 STATE.panWorld=Vector2.zero;STATE.fullZoom=MapConfig.Fullscreen.DefaultZoom
 if UI.layerButton then UI.layerButton.Text="Layer: "..STATE.mapLayer end
 STATE.fullRenderBoostUntil=os.clock()+1
end)

-- Ability discoveries have server-bounded lifetimes and never activate world chunks.
task.spawn(function()
	local ability = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ClassAbility")
	ability.OnClientEvent:Connect(function(action, data)
		if type(data) ~= "table" then return end
		if action == "ClearMarkers" then
			local groups={};for _,key in ipairs(data.Keys or {}) do groups[tostring(key)]=true end
			for key,marker in pairs(STATE.abilityBlips) do if groups[marker.Group] then STATE.abilityBlips[key]=nil end end
			STATE.fullRenderBoostUntil=os.clock()+1;return
		end
		if action ~= "Markers" then return end
		local expires = os.clock() + math.clamp(tonumber(data.Duration) or 0, 0, 60)
		for index, marker in ipairs(data.Markers or {}) do
			if typeof(marker.Position) == "Vector3" then
				local key = tostring(data.Key or "scan") .. ":" .. tostring(marker.Id or index)
				STATE.abilityBlips[key] = {Position=marker.Position, Target=marker.Target, Kind=marker.Kind, Label=marker.Label, Expires=expires, Group=tostring(data.Key or "scan")}
			end
		end
		STATE.fullRenderBoostUntil=os.clock()+1
	end)
end)

task.spawn(function()
 local remotes=ReplicatedStorage:WaitForChild("Remotes")
 remotes:WaitForChild("GearAction").OnClientEvent:Connect(function(action,markers)
  if action~="Warnings" or type(markers)~="table" then return end
  for i,marker in ipairs(markers) do if typeof(marker.Position)=="Vector3" then
   STATE.abilityBlips["packwarning:"..i]={Position=marker.Position,Kind="Enemies",Label=marker.Name,Expires=os.clock()+math.clamp(tonumber(marker.Expires) or 8,0,8)}
  end end
 end)
end)
task.spawn(function()
 local remote=ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("InstrumentAction")
 remote.OnClientEvent:Connect(function(action,data)
  if action~="Snapshot" or type(data)~="table" then return end
  for key in pairs(STATE.abilityBlips) do if key:sub(1,11)=="instrument:" then STATE.abilityBlips[key]=nil end end
  local entries={};if data.ResourceTarget then entries[#entries+1]=data.ResourceTarget end
  for _,beacon in ipairs(data.Beacons or {}) do entries[#entries+1]=beacon end
  if data.Event then entries[#entries+1]=data.Event end
  for i,entry in ipairs(entries) do if typeof(entry.Position)=="Vector3" then
   STATE.abilityBlips["instrument:"..i]={Position=entry.Position,Kind="Objectives",Label=entry.Name or entry.Id or "Signal",Expires=os.clock()+6}
  end end
 end)
end)
task.spawn(function()
 local remote=ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EventBroadcast")
 remote.OnClientEvent:Connect(function(action,id,data)
  if type(data)~="table" then return end
  if action=="Minor_End" or action=="Major_End" then STATE.abilityBlips["event:"..id]=nil;return end
  if action~="Minor_Start" and action~="Major_Start" then return end
  local p=data.Position
  if type(p)=="table" and type(p[1])=="number" then STATE.abilityBlips["event:"..id]={Position=Vector3.new(p[1],p[2],p[3]),Kind="Objectives",Label=data.Name or id,Expires=os.clock()+math.max(0,(data.Duration or 0)-(data.Elapsed or 0))} end
 end)
 remote:FireServer("RequestActive")
end)
return MinimapClient
