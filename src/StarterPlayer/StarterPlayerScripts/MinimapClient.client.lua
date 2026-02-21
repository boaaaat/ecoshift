-- MinimapClient.client.lua
-- Tactical minimap + fullscreen world map (M)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
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

local WORLD_RADIUS = (BiomeConfig.WORLD and BiomeConfig.WORLD.WorldRadius) or (BiomeConfig.world_radius or 1000)
local CHUNK_SIZE = BiomeConfig.chunk_size or 240
local GENERATED_FOLDER_NAME = MapConfig.GeneratedWorldFolderName or BiomeConfig.spawn_folder_name or "GeneratedWorld"

local MAP_CAPTURE_ACTION = "EcoshiftMapCapture"
local MAP_TOGGLE_ACTION = "EcoshiftToggleMap"

local STATE = {
	minimapRange = MapConfig.Minimap.Range,
	minimapVisible = true,
	fullMapOpen = false,
	fullZoom = MapConfig.Fullscreen.DefaultZoom,
	panWorld = Vector2.new(0, 0),
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
}

local WORLD = {
	chunksByKey = {}, -- ["cx,cz"] = { cx, cz, biome, regions = { {name, x, z, sx, sz, temp} }, folder }
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
	toggleButtons = {},
}

local RENDER_CACHE = {
	minimapBlips = {},
	chunkFrames = {},
	regionFrames = {},
	markerFrames = {},
	usedChunkKeys = {},
	usedRegionKeys = {},
	usedMarkerKeys = {},
}

local INPUT = {
	dragInput = nil,
	dragging = false,
	lastTouchPan = nil,
	gamepadPan = Vector2.new(0, 0),
}

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

local function headingDegFromLook(look)
	-- 0 = north (-Z), 90 = east (+X)
	return math.deg(math.atan2(look.X, -look.Z))
end

local function playerYawForRotatingMinimap(root)
	if not root then return 0 end
	local look = root.CFrame.LookVector
	return math.atan2(look.X, look.Z)
end

local function getBiomeColor(biome)
	local map = MapConfig.Colors.BiomeTile or {}
	return map[biome] or map.Unknown or Color3.fromRGB(72, 78, 86)
end

local function clampPan()
	local maxPan = WORLD_RADIUS * 1.35
	STATE.panWorld = Vector2.new(
		math.clamp(STATE.panWorld.X, -maxPan, maxPan),
		math.clamp(STATE.panWorld.Y, -maxPan, maxPan)
	)
end

local function mapScale(absSize, zoom)
	local usable = math.min(absSize.X, absSize.Y)
	if usable <= 0 then return 1 end
	return (usable / (WORLD_RADIUS * 2)) * zoom
end

local function worldToCanvas(wx, wz, absSize, zoom, panWorld)
	local scale = mapScale(absSize, zoom)
	local cx = absSize.X * 0.5
	local cy = absSize.Y * 0.5
	local x = cx + (wx + panWorld.X) * scale
	local y = cy - (wz + panWorld.Y) * scale
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
	return wx, wz
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
	gui.Parent = playerGui

	UI.gui = gui

	-- Minimap card
	local miniW = MapConfig.Minimap.Size + 20
	local miniH = MapConfig.Minimap.Size + 54
	local miniContainer = buildCoreFrame(gui, UDim2.fromOffset(miniW, miniH), getPositionPreset(), MapConfig.Colors.UIPanel, 0.18)
	miniContainer.Name = "MinimapContainer"
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

	for i = 1, 2 do
		local ring = buildCoreFrame(mapFrame, UDim2.fromScale(i / 3, i / 3), UDim2.fromScale(0.5 - (i / 6), 0.5 - (i / 6)), Color3.fromRGB(255, 255, 255), 1)
		local ringCorner = Instance.new("UICorner")
		ringCorner.CornerRadius = UDim.new(1, 0)
		ringCorner.Parent = ring
		local ringStroke = Instance.new("UIStroke")
		ringStroke.Color = MapConfig.Colors.MinimapRing
		ringStroke.Transparency = 0.7
		ringStroke.Thickness = 1
		ringStroke.Parent = ring
	end

	local blips = buildCoreFrame(mapFrame, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(), 1)
	blips.Name = "Blips"

	local playerBlip = Instance.new("ImageLabel")
	playerBlip.Name = "PlayerBlip"
	playerBlip.Size = UDim2.fromOffset(14, 16)
	playerBlip.AnchorPoint = Vector2.new(0.5, 0.5)
	playerBlip.Position = UDim2.fromScale(0.5, 0.5)
	playerBlip.BackgroundTransparency = 1
	playerBlip.Image = "rbxassetid://7072718362"
	playerBlip.ImageColor3 = MapConfig.Colors.Player
	playerBlip.ZIndex = 10
	playerBlip.Parent = blips

	local spawnBlip = buildCoreFrame(blips, UDim2.fromOffset(10, 10), UDim2.fromScale(0.5, 0.5), MapConfig.Colors.Spawn, 0)
	spawnBlip.Name = "SpawnBlip"
	spawnBlip.AnchorPoint = Vector2.new(0.5, 0.5)
	spawnBlip.Visible = false
	spawnBlip.ZIndex = 9
	local spawnCorner = Instance.new("UICorner")
	spawnCorner.CornerRadius = UDim.new(1, 0)
	spawnCorner.Parent = spawnBlip

	local coords = buildLabel(miniContainer, "X: 0  Z: 0", UDim2.new(1, -12, 0, 16), UDim2.fromOffset(8, miniH - 38), Enum.Font.GothamMedium, 11, MapConfig.Colors.TextPrimary)
	coords.Name = "Coords"
	local zoom = buildLabel(miniContainer, "Range: " .. tostring(STATE.minimapRange), UDim2.new(1, -12, 0, 14), UDim2.fromOffset(8, miniH - 22), Enum.Font.Gotham, 10, MapConfig.Colors.TextMuted)
	zoom.Name = "Zoom"

	UI.minimapContainer = miniContainer
	UI.minimapFrame = mapFrame
	UI.minimapBlips = blips
	UI.minimapPlayer = playerBlip
	UI.minimapSpawn = spawnBlip
	UI.minimapCoords = coords
	UI.minimapZoom = zoom

	-- Fullscreen map
	local fullRoot = buildCoreFrame(gui, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), Color3.fromRGB(5, 8, 12), 0.28)
	fullRoot.Name = "WorldMapRoot"
	fullRoot.Visible = false

	local panel = buildCoreFrame(fullRoot, UDim2.fromScale(0.92, 0.9), UDim2.fromScale(0.04, 0.05), MapConfig.Colors.UIPanel, 0.05)
	panel.Name = "Panel"
	styleCard(panel)

	local header = buildCoreFrame(panel, UDim2.new(1, -16, 0, 40), UDim2.fromOffset(8, 8), Color3.new(), 1)
	buildLabel(header, "WORLD MAP", UDim2.new(1, -190, 1, 0), UDim2.fromOffset(0, 0), Enum.Font.GothamBlack, 18, MapConfig.Colors.TextPrimary)
	buildLabel(header, "M/ESC close  |  Wheel/Triggers zoom  |  Drag/Stick pan", UDim2.new(0, 430, 1, 0), UDim2.new(1, -430, 0, 0), Enum.Font.Gotham, 11, MapConfig.Colors.TextMuted, Enum.TextXAlignment.Right)

	local body = buildCoreFrame(panel, UDim2.new(1, -16, 1, -56), UDim2.fromOffset(8, 48), Color3.new(), 1)
	local sidebarW = 210
	local mapArea = buildCoreFrame(body, UDim2.new(1, -sidebarW - 10, 1, 0), UDim2.fromOffset(0, 0), Color3.fromRGB(12, 17, 23), 0)
	styleCard(mapArea)

	local canvas = buildCoreFrame(mapArea, UDim2.new(1, -14, 1, -14), UDim2.fromOffset(7, 7), Color3.fromRGB(8, 12, 16), 0)
	canvas.Name = "Canvas"
	canvas.ClipsDescendants = true
	canvas.Active = true

	local chunkLayer = buildCoreFrame(canvas, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), Color3.new(), 1)
	chunkLayer.Name = "ChunkLayer"
	local regionLayer = buildCoreFrame(canvas, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), Color3.new(), 1)
	regionLayer.Name = "RegionLayer"
	local markerLayer = buildCoreFrame(canvas, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), Color3.new(), 1)
	markerLayer.Name = "MarkerLayer"

	local sidebar = buildCoreFrame(body, UDim2.new(0, sidebarW, 1, 0), UDim2.new(1, -sidebarW, 0, 0), Color3.fromRGB(16, 22, 29), 0)
	styleCard(sidebar)

	local y = 8
	buildLabel(sidebar, "Legend", UDim2.new(1, -10, 0, 20), UDim2.fromOffset(10, y), Enum.Font.GothamBold, 14, MapConfig.Colors.TextPrimary)
	y += 24

	for _, name in ipairs({"Players", "Structures", "Objectives", "Spawn", "Regions", "Resources", "Enemies"}) do
		local btn = Instance.new("TextButton")
		btn.Name = name .. "Toggle"
		btn.Size = UDim2.new(1, -20, 0, 24)
		btn.Position = UDim2.fromOffset(10, y)
		btn.BackgroundColor3 = Color3.fromRGB(34, 47, 60)
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		btn.Font = Enum.Font.GothamMedium
		btn.TextSize = 12
		btn.TextColor3 = MapConfig.Colors.TextPrimary
		btn.Parent = sidebar
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
	centerBtn.BackgroundColor3 = Color3.fromRGB(46, 74, 96)
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

	local zoomLabel = buildLabel(sidebar, "Zoom: 100%", UDim2.new(1, -20, 0, 18), UDim2.fromOffset(10, y), Enum.Font.GothamMedium, 12, MapConfig.Colors.TextPrimary)
	y += 22
	local cursorLabel = buildLabel(sidebar, "Cursor: -", UDim2.new(1, -20, 0, 56), UDim2.fromOffset(10, y), Enum.Font.Gotham, 11, MapConfig.Colors.TextMuted)
	cursorLabel.TextWrapped = true
	cursorLabel.TextYAlignment = Enum.TextYAlignment.Top

	UI.fullRoot = fullRoot
	UI.fullCanvas = canvas
	UI.fullChunkLayer = chunkLayer
	UI.fullRegionLayer = regionLayer
	UI.fullMarkerLayer = markerLayer
	UI.zoomLabel = zoomLabel
	UI.cursorLabel = cursorLabel

	-- Touch map toggle button
	if UserInputService.TouchEnabled then
		local mapButton = Instance.new("TextButton")
		mapButton.Name = "MapToggleButton"
		mapButton.Size = UDim2.fromOffset(60, 44)
		mapButton.Position = UDim2.new(1, -72, 1, -56)
		mapButton.BackgroundColor3 = Color3.fromRGB(32, 44, 56)
		mapButton.BackgroundTransparency = 0.1
		mapButton.BorderSizePixel = 0
		mapButton.Font = Enum.Font.GothamBold
		mapButton.TextSize = 16
		mapButton.TextColor3 = MapConfig.Colors.TextPrimary
		mapButton.Text = "MAP"
		mapButton.Parent = gui
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 8)
		bc.Parent = mapButton
		UI.mapToggleButton = mapButton
	end

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

	if UI.mapToggleButton then
		UI.mapToggleButton.MouseButton1Click:Connect(function()
			STATE.fullMapOpen = not STATE.fullMapOpen
		end)
	end
end

local function updateLegendButtons()
	for name, btn in pairs(UI.toggleButtons) do
		local enabled = STATE.markerVisibility[name]
		btn.Text = (enabled and "[ON] " or "[OFF] ") .. name
		btn.BackgroundColor3 = enabled and Color3.fromRGB(55, 94, 120) or Color3.fromRGB(34, 47, 60)
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
			}
		end
	end

	WORLD.chunksByKey[key] = {
		cx = cx,
		cz = cz,
		biome = biome,
		regions = regions,
		folder = folder,
	}
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
		WORLD.chunksByKey[key] = nil
		WORLD.chunkByFolder[folder] = nil
	end
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
		oldFolders[#oldFolders + 1] = oldFolder
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

local function initWorldBindings()
	refreshGeneratedFolderBinding()

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

local function revealAround(pos)
	if not STATE.fogEnabled then
		for key in pairs(WORLD.chunksByKey) do
			WORLD.exploredChunks[key] = true
		end
		return
	end
	local radius = math.max(0, MapConfig.Exploration.RevealChunkRadius or 0)
	local cx, cz = worldToChunk(pos.X, pos.Z)
	for dx = -radius, radius do
		for dz = -radius, radius do
			WORLD.exploredChunks[chunkKey(cx + dx, cz + dz)] = true
		end
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
	if enabled then
		ContextActionService:BindActionAtPriority(
			MAP_CAPTURE_ACTION,
			function() return Enum.ContextActionResult.Sink end,
			false,
			3000,
			Enum.KeyCode.W,
			Enum.KeyCode.A,
			Enum.KeyCode.S,
			Enum.KeyCode.D,
			Enum.KeyCode.Up,
			Enum.KeyCode.Down,
			Enum.KeyCode.Left,
			Enum.KeyCode.Right,
			Enum.KeyCode.Space,
			Enum.KeyCode.ButtonA,
			Enum.KeyCode.Thumbstick1
		)
	else
		ContextActionService:UnbindAction(MAP_CAPTURE_ACTION)
	end
end

local function setFullMapOpen(open)
	STATE.fullMapOpen = open
	if UI.fullRoot then
		UI.fullRoot.Visible = open
	end
	setCaptureInput(open)
	if open then
		updateLegendButtons()
	end
end

local function toggleFullMap()
	setFullMapOpen(not STATE.fullMapOpen)
end

local function getMouseOver(guiObject)
	if not guiObject then return false end
	local pos = UserInputService:GetMouseLocation()
	local absPos = guiObject.AbsolutePosition
	local absSize = guiObject.AbsoluteSize
	return pos.X >= absPos.X and pos.X <= (absPos.X + absSize.X) and pos.Y >= absPos.Y and pos.Y <= (absPos.Y + absSize.Y)
end

local function applyFullZoom(deltaSign, focusAbs)
	local oldZoom = STATE.fullZoom
	local target = oldZoom + (MapConfig.Fullscreen.ZoomStep * deltaSign)
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
end

local function applyMinimapZoom(deltaSign)
	STATE.minimapRange = math.clamp(
		STATE.minimapRange - (MapConfig.Minimap.ZoomStep * deltaSign),
		MapConfig.Minimap.MinRange,
		MapConfig.Minimap.MaxRange
	)
end

local function startDrag(input)
	if not STATE.fullMapOpen then return end
	INPUT.dragInput = input
	INPUT.dragging = true
end

local function endDrag(input)
	if INPUT.dragInput == input then
		INPUT.dragInput = nil
		INPUT.dragging = false
		INPUT.lastTouchPan = nil
	end
end

local function updateDrag(input)
	if not STATE.fullMapOpen or not INPUT.dragging or INPUT.dragInput ~= input then return end
	if not UI.fullCanvas then return end
	local absSize = UI.fullCanvas.AbsoluteSize
	local scale = mapScale(absSize, STATE.fullZoom)
	if scale <= 0 then return end

	local delta = input.Delta
	if delta.Magnitude == 0 then return end

	STATE.panWorld = STATE.panWorld + Vector2.new(-delta.X / scale, delta.Y / scale)
	clampPan()
end

local function bindInput()
	ContextActionService:BindAction(MAP_TOGGLE_ACTION, function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		toggleFullMap()
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M, Enum.KeyCode.ButtonSelect)

	if UI.fullCanvas then
		UI.fullCanvas.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				startDrag(input)
			end
		end)
		UI.fullCanvas.InputEnded:Connect(endDrag)
	end

	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.MouseWheel then
			if STATE.fullMapOpen and UI.fullCanvas and getMouseOver(UI.fullCanvas) then
				applyFullZoom(input.Position.Z > 0 and 1 or -1, UserInputService:GetMouseLocation())
			elseif UI.minimapFrame and getMouseOver(UI.minimapFrame) then
				applyMinimapZoom(input.Position.Z > 0 and 1 or -1)
			end
		elseif input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2 then
			INPUT.gamepadPan = Vector2.new(input.Position.X, input.Position.Y)
		end

		updateDrag(input)
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		endDrag(input)
		if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2 then
			INPUT.gamepadPan = Vector2.new(0, 0)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.Escape and STATE.fullMapOpen then
			setFullMapOpen(false)
			return
		end

		if input.KeyCode == Enum.KeyCode.Equals or input.KeyCode == Enum.KeyCode.Plus or input.KeyCode == Enum.KeyCode.RightBracket or input.KeyCode == Enum.KeyCode.ButtonR2 then
			if STATE.fullMapOpen then
				applyFullZoom(1, UserInputService:GetMouseLocation())
			else
				applyMinimapZoom(1)
			end
		elseif input.KeyCode == Enum.KeyCode.Minus or input.KeyCode == Enum.KeyCode.LeftBracket or input.KeyCode == Enum.KeyCode.ButtonL2 then
			if STATE.fullMapOpen then
				applyFullZoom(-1, UserInputService:GetMouseLocation())
			else
				applyMinimapZoom(-1)
			end
		end
	end)

	pcall(function()
		UserInputService.TouchPinch:Connect(function(_, scale, _, state, gameProcessed)
			if gameProcessed or not STATE.fullMapOpen then return end
			if state == Enum.UserInputState.Change then
				if scale > 1.01 then
					applyFullZoom(1, UserInputService:GetMouseLocation())
				elseif scale < 0.99 then
					applyFullZoom(-1, UserInputService:GetMouseLocation())
				end
			end
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

local function worldToMinimap(worldPos, playerPos, playerRotation)
	local offset = worldPos - playerPos
	local dx = offset.X
	local dz = offset.Z

	if MapConfig.Minimap.RotateWithPlayer then
		local c = math.cos(-playerRotation)
		local s = math.sin(-playerRotation)
		local rx = dx * c - dz * s
		local rz = dx * s + dz * c
		dx, dz = rx, rz
	end

	local maxPixel = MapConfig.Minimap.Size * 0.5 - 4
	local scale = maxPixel / STATE.minimapRange
	local x = dx * scale
	local y = -dz * scale
	local dist = math.sqrt(x * x + y * y)
	if dist > maxPixel then
		return nil, true
	end
	return x, y, false
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

local function hideUnusedNamedFrames(cacheTable, usedTable)
	for key, frame in pairs(cacheTable) do
		frame.Visible = usedTable[key] == true
	end
end

local function renderFullscreen(playerPos)
	if not UI.fullCanvas or not UI.fullRoot.Visible then return end

	local canvasSize = UI.fullCanvas.AbsoluteSize
	if canvasSize.X <= 0 or canvasSize.Y <= 0 then return end

	tableClear(RENDER_CACHE.usedChunkKeys)
	tableClear(RENDER_CACHE.usedRegionKeys)
	tableClear(RENDER_CACHE.usedMarkerKeys)

	updateLegendButtons()
	getOptionalMarkers()

	for key, chunk in pairs(WORLD.chunksByKey) do
		if isChunkExplored(chunk.cx, chunk.cz) then
			local cx, cz = chunkCenter(chunk.cx, chunk.cz)
			local px, py, scale = worldToCanvas(cx, cz, canvasSize, STATE.fullZoom, STATE.panWorld)
			local sizePx = math.max(2, CHUNK_SIZE * scale)
			if px + sizePx >= -8 and py + sizePx >= -8 and px - sizePx <= canvasSize.X + 8 and py - sizePx <= canvasSize.Y + 8 then
				local frame = acquireNamedFrame(RENDER_CACHE.chunkFrames, key, UI.fullChunkLayer)
				frame.Position = UDim2.fromOffset(math.floor(px - sizePx * 0.5), math.floor(py - sizePx * 0.5))
				frame.Size = UDim2.fromOffset(math.ceil(sizePx), math.ceil(sizePx))
				frame.BackgroundColor3 = getBiomeColor(chunk.biome)
				frame.BackgroundTransparency = 0.16
				RENDER_CACHE.usedChunkKeys[key] = true
			end
		end
	end

	if STATE.markerVisibility.Regions then
		for key, chunk in pairs(WORLD.chunksByKey) do
			if isChunkExplored(chunk.cx, chunk.cz) then
				for i = 1, #chunk.regions do
					local region = chunk.regions[i]
					local rk = key .. ":" .. tostring(i)
					local rx, ry, scale = worldToCanvas(region.x, region.z, canvasSize, STATE.fullZoom, STATE.panWorld)
					local rw = math.max(3, region.sx * scale)
					local rh = math.max(3, region.sz * scale)
					local frame = acquireNamedFrame(RENDER_CACHE.regionFrames, rk, UI.fullRegionLayer)
					frame.Position = UDim2.fromOffset(math.floor(rx - rw * 0.5), math.floor(ry - rh * 0.5))
					frame.Size = UDim2.fromOffset(math.ceil(rw), math.ceil(rh))
					frame.BackgroundColor3 = MapConfig.Colors.RegionFill
					frame.BackgroundTransparency = 0.9
					local stroke = frame:FindFirstChildOfClass("UIStroke")
					if not stroke then
						stroke = Instance.new("UIStroke")
						stroke.Parent = frame
						stroke.Thickness = 1
					end
					stroke.Color = MapConfig.Colors.TextMuted
					stroke.Transparency = 0.55

					local label = frame:FindFirstChild("Label")
					if not label then
						label = buildLabel(frame, "", UDim2.new(1, -4, 0, 12), UDim2.fromOffset(2, 2), Enum.Font.Gotham, 10, MapConfig.Colors.TextMuted, Enum.TextXAlignment.Center)
						label.Name = "Label"
					end
					label.Text = region.name
					label.Visible = rw > 42 and rh > 18
					RENDER_CACHE.usedRegionKeys[rk] = true
				end
			end
		end
	end

	local function drawMarker(key, wx, wz, markerKind, rotation, size)
		local px, py = worldToCanvas(wx, wz, canvasSize, STATE.fullZoom, STATE.panWorld)
		if px < -20 or py < -20 or px > canvasSize.X + 20 or py > canvasSize.Y + 20 then
			return
		end
		local frame = acquireMarkerFrame(key)
		frame.Position = UDim2.fromOffset(px, py)
		frame.Size = UDim2.fromOffset(size, size)
		frame.BackgroundColor3 = colorForMarkerType(markerKind)
		frame.Rotation = (markerKind == "Objectives" or markerKind == "Spawn") and (rotation or 0) or 0

		local direction = frame:FindFirstChild("Direction")
		if markerKind == "Players" or markerKind == "Enemies" then
			if not direction then
				direction = Instance.new("ImageLabel")
				direction.Name = "Direction"
				direction.AnchorPoint = Vector2.new(0.5, 0.5)
				direction.Position = UDim2.fromScale(0.5, 0.5)
				direction.Size = UDim2.fromScale(1, 1)
				direction.BackgroundTransparency = 1
				direction.Image = "rbxassetid://7072718362"
				direction.Parent = frame
			end
			direction.Visible = true
			direction.ImageColor3 = colorForMarkerType(markerKind)
			direction.Rotation = rotation or 0
			frame.BackgroundTransparency = 1
		else
			if direction then
				direction.Visible = false
			end
			frame.BackgroundTransparency = 0
		end
		frame.Visible = true
		RENDER_CACHE.usedMarkerKeys[key] = true
	end

	if STATE.markerVisibility.Spawn and STATE.spawnPosition then
		drawMarker("spawn", STATE.spawnPosition.X, STATE.spawnPosition.Z, "Spawn", 45, 12)
	end

	if STATE.markerVisibility.Structures or STATE.markerVisibility.Objectives then
		for inst, data in pairs(WORLD.markersByInstance) do
			if inst.Parent then
				local group = normalizeMarkerType(data.markerType)
				if group and STATE.markerVisibility[group] then
					local pos = getObjectPosition(inst)
					if pos and isPositionExplored(pos) then
						drawMarker("marker_" .. tostring(inst), pos.X, pos.Z, group, group == "Objectives" and 45 or 0, group == "Objectives" and 11 or 9)
					end
				end
			end
		end
	end

	if STATE.markerVisibility.Players then
		for _, plr in ipairs(Players:GetPlayers()) do
			local hrp = getCharacterRoot(plr)
			if hrp then
				local look = hrp.CFrame.LookVector
				local heading = headingDegFromLook(look)
				local size = plr == player and 13 or 11
				drawMarker("player_" .. tostring(plr.UserId), hrp.Position.X, hrp.Position.Z, "Players", heading, size)
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
			if pos and isPositionExplored(pos) then
				local heading = entry.look and headingDegFromLook(entry.look) or 0
				drawMarker("enemy_" .. tostring(entry.instance), pos.X, pos.Z, "Enemies", heading, 8)
			end
		end
	end

	for name, data in pairs(STATE.customBlips) do
		local pos = data.position
		if typeof(pos) == "Vector3" and isPositionExplored(pos) then
			drawMarker("custom_" .. name, pos.X, pos.Z, "Objectives", 0, 8)
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
			local mouse = UserInputService:GetMouseLocation()
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

local function renderMinimap(playerRoot)
	if not UI.minimapContainer then return end
	UI.minimapContainer.Visible = STATE.minimapVisible
	if not STATE.minimapVisible then return end
	if not playerRoot then return end

	local playerPos = playerRoot.Position
	local playerRot = playerYawForRotatingMinimap(playerRoot)
	local idx = 1

	UI.minimapCoords.Text = string.format("X: %d  Z: %d", math.floor(playerPos.X), math.floor(playerPos.Z))
	UI.minimapZoom.Text = string.format("Range: %dm", math.floor(STATE.minimapRange))

	if STATE.markerVisibility.Spawn and STATE.spawnPosition then
		local sx, sy = worldToMinimap(STATE.spawnPosition, playerPos, playerRot)
		if sx then
			UI.minimapSpawn.Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(sx, sy)
			UI.minimapSpawn.Visible = true
		else
			UI.minimapSpawn.Visible = false
		end
	else
		UI.minimapSpawn.Visible = false
	end

	if STATE.markerVisibility.Players then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player then
				local hrp = getCharacterRoot(plr)
				if hrp then
					local x, y = worldToMinimap(hrp.Position, playerPos, playerRot)
					if x then
						local blip = acquireMinimapBlip(idx)
						idx += 1
						blip.Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(x, y)
						blip.Size = UDim2.fromOffset(8, 8)
						blip.BackgroundColor3 = MapConfig.Colors.Teammate
						blip.Rotation = 0
						blip.Visible = true
					end
				end
			end
		end
	end

	for inst, data in pairs(WORLD.markersByInstance) do
		if inst.Parent then
			local group = normalizeMarkerType(data.markerType)
			if group and STATE.markerVisibility[group] then
				local pos = getObjectPosition(inst)
				if pos and isPositionExplored(pos) then
					local x, y = worldToMinimap(pos, playerPos, playerRot)
					if x then
						local blip = acquireMinimapBlip(idx)
						idx += 1
						blip.Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(x, y)
						blip.Size = UDim2.fromOffset(group == "Objectives" and 9 or 7, group == "Objectives" and 9 or 7)
						blip.BackgroundColor3 = colorForMarkerType(group)
						blip.Rotation = (group == "Objectives") and 45 or 0
						blip.Visible = true
					end
				end
			end
		end
	end

	for _, data in pairs(STATE.customBlips) do
		if typeof(data.position) == "Vector3" and isPositionExplored(data.position) then
			local x, y = worldToMinimap(data.position, playerPos, playerRot)
			if x then
				local blip = acquireMinimapBlip(idx)
				idx += 1
				blip.Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(x, y)
				blip.Size = UDim2.fromOffset(7, 7)
				blip.BackgroundColor3 = (typeof(data.color) == "Color3") and data.color or MapConfig.Colors.Objective
				blip.Rotation = 45
				blip.Visible = true
			end
		end
	end

	hideUnusedMinimapBlips(idx)

	UI.minimapPlayer.Rotation = 0
end

local function initSpawnCapture()
	local function onCharacter(character)
		task.defer(function()
			local hrp = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
			if hrp and not STATE.spawnPosition then
				STATE.spawnPosition = hrp.Position
				dprint("Spawn set", STATE.spawnPosition)
			end
		end)
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
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
end

local lastMinimapRender = 0
local lastFullRender = 0

local function update()
	local now = os.clock()
	local root = getCharacterRoot(player)
	if root then
		revealAround(root.Position)
	end

	if root and (now - lastMinimapRender) >= (MapConfig.Minimap.UpdateRate or 0.12) then
		lastMinimapRender = now
		renderMinimap(root)
	end

	if STATE.fullMapOpen and (now - lastFullRender) >= (MapConfig.Fullscreen.UpdateRate or 0.1) then
		lastFullRender = now
		renderFullscreen(root and root.Position or nil)
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
		UI.minimapContainer.Visible = STATE.minimapVisible
	end
end

function MinimapClient:Toggle()
	toggleFullMap()
end

function MinimapClient:ZoomIn()
	if STATE.fullMapOpen then
		applyFullZoom(1, UserInputService:GetMouseLocation())
	else
		applyMinimapZoom(1)
	end
end

function MinimapClient:ZoomOut()
	if STATE.fullMapOpen then
		applyFullZoom(-1, UserInputService:GetMouseLocation())
	else
		applyMinimapZoom(-1)
	end
end

function MinimapClient:SetZoom(range)
	if type(range) ~= "number" then return end
	STATE.minimapRange = math.clamp(range, MapConfig.Minimap.MinRange, MapConfig.Minimap.MaxRange)
end

function MinimapClient:SetRotateWithPlayer(rotate)
	MapConfig.Minimap.RotateWithPlayer = rotate == true
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
	createUI()
	initWorldBindings()
	initSpawnCapture()
	bindInput()

	RunService.RenderStepped:Connect(function(dt)
		applyGamepadPan(dt)
		update()
	end)

	dprint("Initialized", GENERATED_FOLDER_NAME)
end

init()

return MinimapClient
