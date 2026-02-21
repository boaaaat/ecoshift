-- MinimapClient.client.lua
-- Circular minimap with fog of war exploration system
-- Shows player, teammates, enemies, resources, and structures
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local DEBUG = false

local function dprint(...)
	if DEBUG then
		print(...)
	end
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-------------------------------------------------------------------
-- CONFIGURATION
-------------------------------------------------------------------
local CONFIG = {
	-- Minimap size and position
	Size = 200, -- pixels (slightly larger for detail)
	Margin = 15, -- from screen edge
	Position = "TopRight", -- TopRight, TopLeft, BottomRight, BottomLeft
	
	-- Radar settings
	Range = 100, -- studs visible on minimap (default zoom)
	MinRange = 50, -- minimum zoom (zoomed in)
	MaxRange = 300, -- maximum zoom (zoomed out)
	ZoomStep = 25, -- studs per zoom step
	UpdateRate = 0.1, -- seconds between updates
	RotateWithPlayer = true, -- minimap rotates with player facing
	
	-- Fog of War settings
	FogEnabled = true,
	FogCellSize = 20, -- studs per grid cell
	ExploreRadius = 80, -- how far you reveal when walking (studs) - INCREASED
	FogColor = Color3.fromRGB(10, 12, 15),
	FogTransparency = 0.15, -- unexplored areas darker
	
	-- Visual settings
	BackgroundColor = Color3.fromRGB(20, 25, 30),
	BackgroundTransparency = 0.3,
	BorderColor = Color3.fromRGB(60, 70, 80),
	BorderWidth = 3,
	
	-- Blip colors
	PlayerColor = Color3.fromRGB(100, 200, 255), -- cyan for self
	TeammateColor = Color3.fromRGB(100, 255, 100), -- green
	EnemyColor = Color3.fromRGB(255, 80, 80), -- red
	ResourceColor = Color3.fromRGB(255, 200, 50), -- gold/yellow (default)
	TreeColor = Color3.fromRGB(34, 139, 34), -- forest green for trees
	RockColor = Color3.fromRGB(128, 128, 128), -- grey for rocks
	OreColor = Color3.fromRGB(180, 100, 255), -- purple for ore
	PlantColor = Color3.fromRGB(50, 205, 50), -- lime green for plants
	StructureColor = Color3.fromRGB(150, 200, 255), -- light blue
	ObjectiveColor = Color3.fromRGB(255, 150, 255), -- magenta
	NeutralColor = Color3.fromRGB(180, 180, 180), -- grey
	SpawnColor = Color3.fromRGB(255, 165, 0), -- orange for spawn point
	
	-- Spawn point marker
	ShowSpawnMarker = true,
	SpawnBlipSize = 10, -- larger for visibility
	
	-- Blip sizes
	PlayerBlipSize = 12,
	EntityBlipSize = 8,
	ResourceBlipSize = 6,
	StructureBlipSize = 7,
	
	-- What to show
	ShowTeammates = true,
	ShowEnemies = true,
	ShowResources = true,
	ShowStructures = true,
	ShowObjectives = true,
	MaxBlips = 200, -- increased for resources
	
	-- Resource scanning - scan ALL these folders
	ResourceFolderNames = {"Resources", "WorldGen", "Terrain", "Nodes", "Chunks", "World", "Map"},
	StructureFolderNames = {"Structures", "Buildings", "PlayerBuilds", "Builds"},
}

-------------------------------------------------------------------
-- STATE
-------------------------------------------------------------------
local minimapGui = nil
local minimapFrame = nil
local blipsContainer = nil
local fogContainer = nil
local playerBlip = nil
local compassLabels = {}
local blipPool = {} -- reusable blip instances
local activeBlips = {} -- currently visible blips
local updateConnection = nil

-- Fog of War state
local exploredCells = {} -- [cellKey] = true
local fogPixels = {} -- UI elements for fog
local cachedResources = {} -- Cache of discovered resources { [instance] = {pos, type, name} }
local cachedStructures = {} -- Cache of discovered structures
local lastResourceScan = 0
local RESOURCE_SCAN_INTERVAL = 2 -- seconds between full world scans

-- Spawn point tracking
local spawnPosition = nil -- Where the player spawned
local spawnMarkerBlip = nil -- Special blip for spawn point

-------------------------------------------------------------------
-- UI CREATION
-------------------------------------------------------------------
local function createMinimapUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MinimapUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 5
	
	-- Calculate position
	local posX, posY, anchorX, anchorY
	if CONFIG.Position == "TopRight" then
		posX, posY = 1, 0
		anchorX, anchorY = 1, 0
	elseif CONFIG.Position == "TopLeft" then
		posX, posY = 0, 0
		anchorX, anchorY = 0, 0
	elseif CONFIG.Position == "BottomRight" then
		posX, posY = 1, 1
		anchorX, anchorY = 1, 1
	else -- BottomLeft
		posX, posY = 0, 1
		anchorX, anchorY = 0, 1
	end
	
	-- Main container (for margin)
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(0, CONFIG.Size + CONFIG.Margin * 2, 0, CONFIG.Size + CONFIG.Margin * 2 + 45) -- Extra height for spawn distance
	container.Position = UDim2.new(posX, 0, posY, 0)
	container.AnchorPoint = Vector2.new(anchorX, anchorY)
	container.BackgroundTransparency = 1
	container.Parent = screenGui
	
	-- Minimap frame (circular)
	local mapFrame = Instance.new("Frame")
	mapFrame.Name = "MapFrame"
	mapFrame.Size = UDim2.new(0, CONFIG.Size, 0, CONFIG.Size)
	mapFrame.Position = UDim2.new(0.5, 0, 0, CONFIG.Margin)
	mapFrame.AnchorPoint = Vector2.new(0.5, 0)
	mapFrame.BackgroundColor3 = CONFIG.BackgroundColor
	mapFrame.BackgroundTransparency = CONFIG.BackgroundTransparency
	mapFrame.ClipsDescendants = true
	mapFrame.Parent = container
	
	-- Make it circular
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = mapFrame
	
	-- Border
	local stroke = Instance.new("UIStroke")
	stroke.Color = CONFIG.BorderColor
	stroke.Thickness = CONFIG.BorderWidth
	stroke.Parent = mapFrame
	
	-- Inner glow/ring effect
	local innerRing = Instance.new("Frame")
	innerRing.Name = "InnerRing"
	innerRing.Size = UDim2.new(1, -10, 1, -10)
	innerRing.Position = UDim2.new(0.5, 0, 0.5, 0)
	innerRing.AnchorPoint = Vector2.new(0.5, 0.5)
	innerRing.BackgroundTransparency = 1
	innerRing.Parent = mapFrame
	
	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(0.5, 0)
	innerCorner.Parent = innerRing
	
	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = Color3.fromRGB(40, 50, 60)
	innerStroke.Thickness = 1
	innerStroke.Transparency = 0.5
	innerStroke.Parent = innerRing
	
	-- Grid lines (crosshair style)
	local hLine = Instance.new("Frame")
	hLine.Name = "HLine"
	hLine.Size = UDim2.new(1, 0, 0, 1)
	hLine.Position = UDim2.new(0, 0, 0.5, 0)
	hLine.BackgroundColor3 = Color3.fromRGB(60, 70, 80)
	hLine.BackgroundTransparency = 0.7
	hLine.BorderSizePixel = 0
	hLine.Parent = mapFrame
	
	local vLine = Instance.new("Frame")
	vLine.Name = "VLine"
	vLine.Size = UDim2.new(0, 1, 1, 0)
	vLine.Position = UDim2.new(0.5, 0, 0, 0)
	vLine.BackgroundColor3 = Color3.fromRGB(60, 70, 80)
	vLine.BackgroundTransparency = 0.7
	vLine.BorderSizePixel = 0
	vLine.Parent = mapFrame
	
	-- Range rings
	for i = 1, 2 do
		local ring = Instance.new("Frame")
		ring.Name = "RangeRing" .. i
		local scale = i / 3
		ring.Size = UDim2.new(scale, 0, scale, 0)
		ring.Position = UDim2.new(0.5, 0, 0.5, 0)
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.BackgroundTransparency = 1
		ring.Parent = mapFrame
		
		local ringCorner = Instance.new("UICorner")
		ringCorner.CornerRadius = UDim.new(0.5, 0)
		ringCorner.Parent = ring
		
		local ringStroke = Instance.new("UIStroke")
		ringStroke.Color = Color3.fromRGB(50, 60, 70)
		ringStroke.Thickness = 1
		ringStroke.Transparency = 0.6
		ringStroke.Parent = ring
	end
	
	-- Blips container (rotates with player)
	local blips = Instance.new("Frame")
	blips.Name = "Blips"
	blips.Size = UDim2.new(1, 0, 1, 0)
	blips.Position = UDim2.new(0.5, 0, 0.5, 0)
	blips.AnchorPoint = Vector2.new(0.5, 0.5)
	blips.BackgroundTransparency = 1
	blips.Parent = mapFrame
	
	-- Player blip (center, always visible)
	local pBlip = Instance.new("Frame")
	pBlip.Name = "PlayerBlip"
	pBlip.Size = UDim2.new(0, CONFIG.PlayerBlipSize, 0, CONFIG.PlayerBlipSize)
	pBlip.Position = UDim2.new(0.5, 0, 0.5, 0)
	pBlip.AnchorPoint = Vector2.new(0.5, 0.5)
	pBlip.BackgroundColor3 = CONFIG.PlayerColor
	pBlip.BorderSizePixel = 0
	pBlip.ZIndex = 10
	pBlip.Parent = blips
	
	-- Player direction indicator (triangle)
	local dirIndicator = Instance.new("ImageLabel")
	dirIndicator.Name = "Direction"
	dirIndicator.Size = UDim2.new(0, 8, 0, 10)
	dirIndicator.Position = UDim2.new(0.5, 0, 0, -6)
	dirIndicator.AnchorPoint = Vector2.new(0.5, 1)
	dirIndicator.BackgroundTransparency = 1
	dirIndicator.Image = "rbxassetid://7072718362" -- triangle
	dirIndicator.ImageColor3 = CONFIG.PlayerColor
	dirIndicator.Parent = pBlip
	
	local pCorner = Instance.new("UICorner")
	pCorner.CornerRadius = UDim.new(0.5, 0)
	pCorner.Parent = pBlip
	
	-- Compass labels (now shows direction relative to player - "^" always at top = forward)
	local compassDirs = {
		{ label = "N", angle = 0 },
		{ label = "E", angle = 90 },
		{ label = "S", angle = 180 },
		{ label = "W", angle = 270 },
	}
	
	for _, dir in ipairs(compassDirs) do
		local label = Instance.new("TextLabel")
		label.Name = "Compass_" .. dir.label
		label.Size = UDim2.new(0, 20, 0, 15)
		label.BackgroundTransparency = 1
		label.Text = dir.label
		label.TextColor3 = Color3.fromRGB(150, 160, 170)
		label.TextSize = 11
		label.Font = Enum.Font.GothamBold
		label.ZIndex = 5
		label.Parent = mapFrame
		
		compassLabels[dir.label] = { frame = label, baseAngle = dir.angle }
	end
	
	-- Spawn point marker (special blip, always visible)
	local spawnBlip = Instance.new("Frame")
	spawnBlip.Name = "SpawnMarker"
	spawnBlip.Size = UDim2.new(0, CONFIG.SpawnBlipSize, 0, CONFIG.SpawnBlipSize)
	spawnBlip.AnchorPoint = Vector2.new(0.5, 0.5)
	spawnBlip.BackgroundColor3 = CONFIG.SpawnColor
	spawnBlip.BorderSizePixel = 0
	spawnBlip.Visible = false
	spawnBlip.ZIndex = 8 -- High priority
	spawnBlip.Parent = blips
	
	local spawnCorner = Instance.new("UICorner")
	spawnCorner.CornerRadius = UDim.new(0.5, 0)
	spawnCorner.Parent = spawnBlip
	
	-- Home icon indicator (diamond shape via rotation)
	local spawnIcon = Instance.new("Frame")
	spawnIcon.Name = "HomeIcon"
	spawnIcon.Size = UDim2.new(0, 6, 0, 6)
	spawnIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
	spawnIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	spawnIcon.BackgroundColor3 = Color3.new(1, 1, 1)
	spawnIcon.BorderSizePixel = 0
	spawnIcon.Rotation = 45 -- Diamond shape
	spawnIcon.Parent = spawnBlip
	
	-- Glow effect for spawn marker
	local spawnGlow = Instance.new("UIStroke")
	spawnGlow.Color = CONFIG.SpawnColor
	spawnGlow.Thickness = 2
	spawnGlow.Transparency = 0.3
	spawnGlow.Parent = spawnBlip
	
	spawnMarkerBlip = spawnBlip
	
	-- Title/coordinates display
	local titleFrame = Instance.new("Frame")
	titleFrame.Name = "TitleFrame"
	titleFrame.Size = UDim2.new(1, -20, 0, 50) -- Increased for spawn distance
	titleFrame.Position = UDim2.new(0.5, 0, 1, 5)
	titleFrame.AnchorPoint = Vector2.new(0.5, 0)
	titleFrame.BackgroundTransparency = 1
	titleFrame.Parent = container
	
	local coordsLabel = Instance.new("TextLabel")
	coordsLabel.Name = "Coords"
	coordsLabel.Size = UDim2.new(1, 0, 0, 15)
	coordsLabel.BackgroundTransparency = 1
	coordsLabel.Text = "X: 0 | Z: 0"
	coordsLabel.TextColor3 = Color3.fromRGB(150, 160, 170)
	coordsLabel.TextSize = 11
	coordsLabel.Font = Enum.Font.GothamMedium
	coordsLabel.Parent = titleFrame
	
	local zoomLabel = Instance.new("TextLabel")
	zoomLabel.Name = "Zoom"
	zoomLabel.Size = UDim2.new(1, 0, 0, 12)
	zoomLabel.Position = UDim2.new(0, 0, 0, 15)
	zoomLabel.BackgroundTransparency = 1
	zoomLabel.Text = "Zoom: 100m | +/- or scroll"
	zoomLabel.TextColor3 = Color3.fromRGB(120, 130, 140)
	zoomLabel.TextSize = 9
	zoomLabel.Font = Enum.Font.Gotham
	zoomLabel.Parent = titleFrame
	
	-- Spawn distance indicator
	local spawnDistLabel = Instance.new("TextLabel")
	spawnDistLabel.Name = "SpawnDist"
	spawnDistLabel.Size = UDim2.new(1, 0, 0, 12)
	spawnDistLabel.Position = UDim2.new(0, 0, 0, 27)
	spawnDistLabel.BackgroundTransparency = 1
	spawnDistLabel.Text = ""
	spawnDistLabel.TextColor3 = CONFIG.SpawnColor
	spawnDistLabel.TextSize = 9
	spawnDistLabel.Font = Enum.Font.GothamBold
	spawnDistLabel.Parent = titleFrame
	
	screenGui.Parent = playerGui
	
	minimapGui = screenGui
	minimapFrame = mapFrame
	blipsContainer = blips
	playerBlip = pBlip
	
	return screenGui
end

-------------------------------------------------------------------
-- BLIP MANAGEMENT
-------------------------------------------------------------------
local function createBlip()
	local blip = Instance.new("Frame")
	blip.Size = UDim2.new(0, CONFIG.EntityBlipSize, 0, CONFIG.EntityBlipSize)
	blip.AnchorPoint = Vector2.new(0.5, 0.5)
	blip.BackgroundColor3 = CONFIG.NeutralColor
	blip.BorderSizePixel = 0
	blip.Visible = false
	blip.Parent = blipsContainer
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = blip
	
	-- Glow effect
	local glow = Instance.new("UIStroke")
	glow.Color = Color3.new(1, 1, 1)
	glow.Thickness = 1
	glow.Transparency = 0.8
	glow.Parent = blip
	
	return blip
end

local function getBlipFromPool()
	for _, blip in ipairs(blipPool) do
		if not blip.Visible then
			return blip
		end
	end
	
	-- Create new blip if pool exhausted
	if #blipPool < CONFIG.MaxBlips then
		local newBlip = createBlip()
		table.insert(blipPool, newBlip)
		return newBlip
	end
	
	return nil -- At max capacity
end

local function hideAllBlips()
	for _, blip in ipairs(blipPool) do
		blip.Visible = false
	end
	activeBlips = {}
end

-------------------------------------------------------------------
-- WORLD SCANNING
-------------------------------------------------------------------
local function getPlayerPosition()
	local char = player.Character
	if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position or nil
end

local function getPlayerRotation()
	local char = player.Character
	if not char then return 0 end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return 0 end
	
	local lookVector = hrp.CFrame.LookVector
	return math.atan2(lookVector.X, lookVector.Z)
end

local function worldToMinimap(worldPos, playerPos, playerRotation, clampToEdge)
	-- Get offset from player
	local offset = worldPos - playerPos
	local dx = offset.X
	local dz = offset.Z
	
	-- Always rotate based on player facing so "up" = forward direction
	-- This makes the minimap oriented so top = where player is looking
	local cos = math.cos(-playerRotation)
	local sin = math.sin(-playerRotation)
	local newDx = dx * cos - dz * sin
	local newDz = dx * sin + dz * cos
	dx, dz = newDx, newDz
	
	-- Scale to minimap
	local scale = (CONFIG.Size / 2) / CONFIG.Range
	local mapX = dx * scale
	local mapY = -newDz * scale -- Negative Z = forward = UP on screen
	
	-- Check if within range (circular)
	local dist = math.sqrt(mapX * mapX + mapY * mapY)
	local maxDist = CONFIG.Size / 2 - 5
	
	if dist > maxDist then
		if clampToEdge then
			-- Clamp to edge of minimap (for spawn marker arrow)
			local factor = maxDist / dist
			mapX = mapX * factor
			mapY = mapY * factor
			return UDim2.new(0.5, mapX, 0.5, mapY), true -- true = clamped
		else
			return nil -- Outside minimap
		end
	end
	
	return UDim2.new(0.5, mapX, 0.5, mapY), false
end

-------------------------------------------------------------------
-- FOG OF WAR SYSTEM
-------------------------------------------------------------------
local function getCellKey(x, z)
	local cellX = math.floor(x / CONFIG.FogCellSize)
	local cellZ = math.floor(z / CONFIG.FogCellSize)
	return cellX .. "_" .. cellZ
end

local function getCellFromKey(key)
	local x, z = key:match("([%-?%d]+)_([%-?%d]+)")
	return tonumber(x) * CONFIG.FogCellSize, tonumber(z) * CONFIG.FogCellSize
end

local function isExplored(worldX, worldZ)
	if not CONFIG.FogEnabled then return true end
	return exploredCells[getCellKey(worldX, worldZ)] == true
end

local function exploreAroundPosition(pos)
	if not CONFIG.FogEnabled then return end
	
	local radius = CONFIG.ExploreRadius
	local cellSize = CONFIG.FogCellSize
	local cellsToExplore = math.ceil(radius / cellSize)
	
	local centerCellX = math.floor(pos.X / cellSize)
	local centerCellZ = math.floor(pos.Z / cellSize)
	
	for dx = -cellsToExplore, cellsToExplore do
		for dz = -cellsToExplore, cellsToExplore do
			local cellX = centerCellX + dx
			local cellZ = centerCellZ + dz
			
			-- Check if within circular radius
			local worldX = cellX * cellSize + cellSize / 2
			local worldZ = cellZ * cellSize + cellSize / 2
			local dist = math.sqrt((worldX - pos.X)^2 + (worldZ - pos.Z)^2)
			
			if dist <= radius then
				local key = cellX .. "_" .. cellZ
				exploredCells[key] = true
			end
		end
	end
end

-------------------------------------------------------------------
-- RESOURCE & STRUCTURE SCANNING
-------------------------------------------------------------------
local function classifyResource(name, parentName)
	local nameLower = name:lower()
	local parentLower = parentName and parentName:lower() or ""
	local combined = nameLower .. " " .. parentLower
	
	-- Trees (check name and parent folder)
	if combined:find("tree") or combined:find("palm") or combined:find("pine") 
		or combined:find("oak") or combined:find("birch") or combined:find("willow")
		or combined:find("redwood") or combined:find("spruce") or combined:find("maple")
		or combined:find("forest") then
		return "tree", CONFIG.TreeColor
	end
	
	-- Rocks/Stone
	if combined:find("rock") or combined:find("stone") or combined:find("boulder") 
		or combined:find("sandstone") or combined:find("granite") or combined:find("cliff") then
		return "rock", CONFIG.RockColor
	end
	
	-- Ores/Minerals
	if combined:find("ore") or combined:find("iron") or combined:find("gold") 
		or combined:find("copper") or combined:find("coal") or combined:find("crystal")
		or combined:find("gem") or combined:find("diamond") or combined:find("metal")
		or combined:find("mineral") or combined:find("vein") then
		return "ore", CONFIG.OreColor
	end
	
	-- Plants/Bushes/Vegetation
	if combined:find("bush") or combined:find("berry") or combined:find("plant")
		or combined:find("flower") or combined:find("herb") or combined:find("mushroom")
		or combined:find("cactus") or combined:find("fern") or combined:find("shrub")
		or combined:find("vegetation") or combined:find("flora") then
		return "plant", CONFIG.PlantColor
	end
	
	-- Default resource (yellow)
	return "resource", CONFIG.ResourceColor
end

local function getObjectPosition(obj)
	if obj:IsA("Model") then
		if obj.PrimaryPart then
			return obj.PrimaryPart.Position
		end
		-- Try to get any part position
		local part = obj:FindFirstChildWhichIsA("BasePart")
		if part then
			return part.Position
		end
		local success, pivot = pcall(function() return obj:GetPivot() end)
		if success then
			return pivot.Position
		end
	elseif obj:IsA("BasePart") then
		return obj.Position
	end
	return nil
end

local function isHarvestableObject(obj)
	-- Check for ProximityPrompt (most reliable)
	if obj:FindFirstChildOfClass("ProximityPrompt") then
		return true
	end
	if obj:IsA("Model") and obj:FindFirstChildWhichIsA("ProximityPrompt", true) then
		return true
	end
	
	-- Check attributes
	if obj:GetAttribute("Harvestable") or obj:GetAttribute("Resource") 
		or obj:GetAttribute("Mineable") or obj:GetAttribute("Choppable") then
		return true
	end
	
	-- Check if it looks like a resource by name patterns
	local nameLower = obj.Name:lower()
	local resourcePatterns = {
		"tree", "rock", "stone", "ore", "bush", "plant", "node",
		"resource", "deposit", "vein", "crystal", "mushroom", "cactus",
		"palm", "pine", "oak", "boulder", "iron", "gold", "copper"
	}
	for _, pattern in ipairs(resourcePatterns) do
		if nameLower:find(pattern) then
			return true
		end
	end
	
	return false
end

local function scanForResourcesInFolder(folder, depth)
	if not folder then return end
	depth = depth or 0
	if depth > 10 then return end -- Prevent infinite recursion
	
	for _, child in ipairs(folder:GetChildren()) do
		local pos = getObjectPosition(child)
		
		if pos and not cachedResources[child] then
			-- Check if it's a harvestable resource
			if isHarvestableObject(child) then
				local parentName = child.Parent and child.Parent.Name or ""
				local resourceType, color = classifyResource(child.Name, parentName)
				cachedResources[child] = {
					position = pos,
					type = resourceType,
					color = color,
					name = child.Name,
				}
			end
		end
		
		-- Recurse into models/folders
		if child:IsA("Model") or child:IsA("Folder") then
			scanForResourcesInFolder(child, depth + 1)
		end
	end
end

local function scanForStructuresInFolder(folder, results)
	if not folder then return end
	
	for _, child in ipairs(folder:GetChildren()) do
		local isStructure = child:GetAttribute("Structure") or child:GetAttribute("Building")
			or child:GetAttribute("Placeable") or child:GetAttribute("Built")
		
		if isStructure or child.Name:lower():find("structure") or child.Name:lower():find("build") then
			local pos = getObjectPosition(child)
			if pos and not cachedStructures[child] then
				cachedStructures[child] = {
					position = pos,
					type = "structure",
					color = CONFIG.StructureColor,
					name = child.Name,
				}
			end
		end
		
		-- Recurse
		if child:IsA("Model") or child:IsA("Folder") then
			scanForStructuresInFolder(child, results)
		end
	end
end

local function fullWorldScan()
	-- Scan workspace for resource folders
	for _, folderName in ipairs(CONFIG.ResourceFolderNames) do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			scanForResourcesInFolder(folder, 0)
		end
	end
	
	-- Scan ALL root folders that could contain resources
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("Folder") then
			-- Scan any folder that might have chunks/terrain/resources
			local nameLower = child.Name:lower()
			if nameLower:find("chunk") or nameLower:find("terrain") or nameLower:find("world")
				or nameLower:find("resource") or nameLower:find("node") or nameLower:find("biome")
				or nameLower:find("forest") or nameLower:find("desert") or nameLower:find("spawn") then
				scanForResourcesInFolder(child, 0)
			end
		end
	end
	
	-- Scan for structures
	for _, folderName in ipairs(CONFIG.StructureFolderNames) do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			scanForStructuresInFolder(folder, nil)
		end
	end
	
	-- Scan CollectionService tags
	for _, resource in ipairs(CollectionService:GetTagged("Resource")) do
		if not cachedResources[resource] then
			local pos = getObjectPosition(resource)
			if pos then
				local parentName = resource.Parent and resource.Parent.Name or ""
				local resourceType, color = classifyResource(resource.Name, parentName)
				cachedResources[resource] = {
					position = pos,
					type = resourceType,
					color = color,
					name = resource.Name,
				}
			end
		end
	end
	
	for _, resource in ipairs(CollectionService:GetTagged("Harvestable")) do
		if not cachedResources[resource] then
			local pos = getObjectPosition(resource)
			if pos then
				local parentName = resource.Parent and resource.Parent.Name or ""
				local resourceType, color = classifyResource(resource.Name, parentName)
				cachedResources[resource] = {
					position = pos,
					type = resourceType,
					color = color,
					name = resource.Name,
				}
			end
		end
	end
	
	-- Also scan ALL ProximityPrompts in workspace (catches everything)
	for _, prompt in ipairs(CollectionService:GetTagged("ProximityPrompt")) do
		-- Nope, can't tag prompts this way. Let's do a different approach below
	end
	
	-- Clean up destroyed resources
	for obj, _ in pairs(cachedResources) do
		if not obj.Parent then
			cachedResources[obj] = nil
		end
	end
	
	for obj, _ in pairs(cachedStructures) do
		if not obj.Parent then
			cachedStructures[obj] = nil
		end
	end
end

local function scanEntities(playerPos, playerRotation)
	local entities = {}
	
	-- Run full world scan periodically
	local now = tick()
	if now - lastResourceScan > RESOURCE_SCAN_INTERVAL then
		lastResourceScan = now
		fullWorldScan()
	end
	
	-- Scan other players (always visible, no fog)
	if CONFIG.ShowTeammates then
		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			if otherPlayer ~= player then
				local char = otherPlayer.Character
				if char then
					local hrp = char:FindFirstChild("HumanoidRootPart")
					local hum = char:FindFirstChildOfClass("Humanoid")
					if hrp and hum and hum.Health > 0 then
						table.insert(entities, {
							position = hrp.Position,
							type = "teammate",
							color = CONFIG.TeammateColor,
							name = otherPlayer.Name,
							ignoreFog = true, -- Always show teammates
						})
					end
				end
			end
		end
	end
	
	-- Scan enemies (tagged with "Enemy")
	if CONFIG.ShowEnemies then
		for _, enemy in ipairs(CollectionService:GetTagged("Enemy")) do
			local hrp = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChild("Root") or enemy.PrimaryPart
			local hum = enemy:FindFirstChildOfClass("Humanoid")
			if hrp and (not hum or hum.Health > 0) then
				local pos = hrp.Position
				-- Only show if explored
				if isExplored(pos.X, pos.Z) then
					table.insert(entities, {
						position = pos,
						type = "enemy",
						color = CONFIG.EnemyColor,
						name = enemy.Name,
					})
				end
			end
		end
	end
	
	-- Add cached resources (only if explored)
	if CONFIG.ShowResources then
		for obj, data in pairs(cachedResources) do
			if obj.Parent and data.position then
				if isExplored(data.position.X, data.position.Z) then
					table.insert(entities, {
						position = data.position,
						type = data.type,
						color = data.color,
						name = data.name,
					})
				end
			end
		end
	end
	
	-- Add cached structures (only if explored)
	if CONFIG.ShowStructures then
		for obj, data in pairs(cachedStructures) do
			if obj.Parent and data.position then
				if isExplored(data.position.X, data.position.Z) then
					table.insert(entities, {
						position = data.position,
						type = "structure",
						color = data.color,
						name = data.name,
					})
				end
			end
		end
	end
	
	-- Scan objectives (tagged with "Objective") - always visible like waypoints
	if CONFIG.ShowObjectives then
		for _, objective in ipairs(CollectionService:GetTagged("Objective")) do
			local pos = getObjectPosition(objective)
			if pos then
				table.insert(entities, {
					position = pos,
					type = "objective",
					color = CONFIG.ObjectiveColor,
					name = objective.Name,
					ignoreFog = true, -- Objectives always visible
				})
			end
		end
	end
	
	return entities
end

-------------------------------------------------------------------
-- UPDATE LOOP
-------------------------------------------------------------------
local lastUpdate = 0

local function updateMinimap()
	local now = tick()
	if now - lastUpdate < CONFIG.UpdateRate then return end
	lastUpdate = now
	
	local playerPos = getPlayerPosition()
	if not playerPos then return end
	
	local playerRotation = getPlayerRotation()
	
	-- Explore area around player (fog of war)
	exploreAroundPosition(playerPos)
	
	-- Update compass labels position (rotate with player so N moves based on facing)
	local compassRadius = CONFIG.Size / 2 - 12
	for dir, data in pairs(compassLabels) do
		-- Compass rotates opposite to player - if player faces East, N should be to the left
		local angle = math.rad(data.baseAngle) - playerRotation
		
		local x = math.sin(angle) * compassRadius
		local y = -math.cos(angle) * compassRadius
		
		data.frame.Position = UDim2.new(0.5, x - 10, 0.5, y - 7)
	end
	
	-- Update spawn marker position (always visible, clamped to edge if far)
	if CONFIG.ShowSpawnMarker and spawnPosition and spawnMarkerBlip then
		local spawnMapPos, isClamped = worldToMinimap(spawnPosition, playerPos, playerRotation, true)
		if spawnMapPos then
			spawnMarkerBlip.Position = spawnMapPos
			spawnMarkerBlip.Visible = true
			
			-- Make it pulse/glow more when clamped (far away)
			local stroke = spawnMarkerBlip:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Thickness = isClamped and 3 or 2
				stroke.Transparency = isClamped and 0 or 0.3
			end
			
			-- Calculate distance to spawn
			local distToSpawn = (spawnPosition - playerPos).Magnitude
			if distToSpawn < 15 then
				-- Hide when very close to spawn
				spawnMarkerBlip.Visible = false
			end
		else
			spawnMarkerBlip.Visible = false
		end
	end
	
	-- Update coordinates display
	local container = minimapGui:FindFirstChild("Container")
	if container then
		local titleFrame = container:FindFirstChild("TitleFrame")
		if titleFrame then
			local coordsLabel = titleFrame:FindFirstChild("Coords")
			if coordsLabel then
				coordsLabel.Text = string.format("X: %d | Z: %d", 
					math.floor(playerPos.X), math.floor(playerPos.Z))
			end
			
			local zoomLabel = titleFrame:FindFirstChild("Zoom")
			if zoomLabel then
				local resourceCount = 0
				for _ in pairs(cachedResources) do resourceCount = resourceCount + 1 end
				zoomLabel.Text = string.format("Range: %dm | %d resources", CONFIG.Range, resourceCount)
			end
			
			-- Update spawn distance display
			local spawnDistLabel = titleFrame:FindFirstChild("SpawnDist")
			if spawnDistLabel and spawnPosition then
				local distToSpawn = math.floor((spawnPosition - playerPos).Magnitude)
				if distToSpawn > 15 then
					spawnDistLabel.Text = string.format("🏠 Spawn: %dm", distToSpawn)
				else
					spawnDistLabel.Text = "🏠 At Spawn"
				end
			elseif spawnDistLabel then
				spawnDistLabel.Text = ""
			end
		end
	end
	
	-- Player blip direction indicator always points up (forward)
	-- The map rotates so player's forward = top, so we don't need to rotate the blip
	playerBlip.Rotation = 0
	
	-- Blips container doesn't rotate - positions are already calculated relative to player facing
	blipsContainer.Rotation = 0
	
	-- Hide all existing blips
	hideAllBlips()
	
	-- Scan and display entities
	local entities = scanEntities(playerPos, playerRotation)
	
	-- Sort by type priority, then distance (resources first, then others)
	table.sort(entities, function(a, b)
		-- Priority: resources < structures < enemies < teammates < objectives
		local priority = { tree = 1, rock = 1, ore = 1, plant = 1, resource = 1, 
			structure = 2, enemy = 3, teammate = 4, objective = 5 }
		local prioA = priority[a.type] or 0
		local prioB = priority[b.type] or 0
		if prioA ~= prioB then
			return prioA < prioB -- Lower priority drawn first (underneath)
		end
		-- Same priority: farther away drawn first
		local distA = (a.position - playerPos).Magnitude
		local distB = (b.position - playerPos).Magnitude
		return distA > distB
	end)
	
	-- Display blips
	for i, entity in ipairs(entities) do
		if i > CONFIG.MaxBlips then break end
		
		local mapPos = worldToMinimap(entity.position, playerPos, playerRotation)
		if mapPos then
			local blip = getBlipFromPool()
			if blip then
				blip.Position = mapPos
				blip.Visible = true
				
				-- Use entity's color if provided, else default by type
				local color = entity.color
				local size = CONFIG.ResourceBlipSize
				
				if entity.type == "teammate" then
					color = color or CONFIG.TeammateColor
					size = CONFIG.EntityBlipSize
				elseif entity.type == "enemy" then
					color = color or CONFIG.EnemyColor
					size = CONFIG.EntityBlipSize
				elseif entity.type == "tree" then
					color = color or CONFIG.TreeColor
					size = CONFIG.ResourceBlipSize
				elseif entity.type == "rock" then
					color = color or CONFIG.RockColor
					size = CONFIG.ResourceBlipSize
				elseif entity.type == "ore" then
					color = color or CONFIG.OreColor
					size = CONFIG.ResourceBlipSize
				elseif entity.type == "plant" or entity.type == "resource" then
					color = color or CONFIG.ResourceColor
					size = CONFIG.ResourceBlipSize
				elseif entity.type == "structure" then
					color = color or CONFIG.StructureColor
					size = CONFIG.StructureBlipSize
				elseif entity.type == "objective" then
					color = color or CONFIG.ObjectiveColor
					size = CONFIG.EntityBlipSize + 2
				else
					color = color or CONFIG.NeutralColor
					size = CONFIG.ResourceBlipSize
				end
				
				blip.BackgroundColor3 = color
				blip.Size = UDim2.new(0, size, 0, size)
				
				table.insert(activeBlips, blip)
			end
		end
	end
end

-------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------
local MinimapClient = {}

function MinimapClient:SetRange(range)
	CONFIG.Range = range
end

function MinimapClient:SetVisible(visible)
	if minimapGui then
		minimapGui.Enabled = visible
	end
end

function MinimapClient:Toggle()
	if minimapGui then
		minimapGui.Enabled = not minimapGui.Enabled
	end
end

function MinimapClient:ZoomIn()
	CONFIG.Range = math.max(CONFIG.MinRange, CONFIG.Range - CONFIG.ZoomStep)
	dprint("[Minimap] Zoom:", CONFIG.Range, "studs")
end

function MinimapClient:ZoomOut()
	CONFIG.Range = math.min(CONFIG.MaxRange, CONFIG.Range + CONFIG.ZoomStep)
	dprint("[Minimap] Zoom:", CONFIG.Range, "studs")
end

function MinimapClient:SetZoom(range)
	CONFIG.Range = math.clamp(range, CONFIG.MinRange, CONFIG.MaxRange)
end

function MinimapClient:SetRotateWithPlayer(rotate)
	CONFIG.RotateWithPlayer = rotate
end

function MinimapClient:SetFogEnabled(enabled)
	CONFIG.FogEnabled = enabled
end

function MinimapClient:RevealAll()
	-- Cheat/debug: reveal entire map
	CONFIG.FogEnabled = false
end

function MinimapClient:ResetExploration()
	-- Clear all explored areas
	exploredCells = {}
end

function MinimapClient:SetSpawnPoint(position)
	-- Set a custom spawn point
	spawnPosition = position
	dprint("[Minimap] Spawn point set to:", position)
end

function MinimapClient:GetSpawnPoint()
	return spawnPosition
end

function MinimapClient:GetExploredCount()
	local count = 0
	for _ in pairs(exploredCells) do count = count + 1 end
	return count
end

function MinimapClient:AddCustomBlip(name, worldPosition, color)
	-- For adding custom markers (waypoints, etc.)
	-- Implementation left for future expansion
end

function MinimapClient:ForceRescan()
	-- Force immediate resource scan
	lastResourceScan = 0
	fullWorldScan()
end

-- Helper function
local function tableSize(t)
	local count = 0
	for _ in pairs(t) do count = count + 1 end
	return count
end

-------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------
local function init()
	dprint("[MinimapClient] Initializing...")
	
	createMinimapUI()
	
	-- Pre-populate blip pool (larger pool for resources)
	for i = 1, 80 do
		local blip = createBlip()
		table.insert(blipPool, blip)
	end
	
	-- Initial world scan
	task.spawn(function()
		task.wait(1) -- Wait for world to load
		fullWorldScan()
		dprint("[MinimapClient] Initial scan found", 
			"resources:", tableSize(cachedResources), 
			"structures:", tableSize(cachedStructures))
	end)
	
	-- Start update loop
	updateConnection = RunService.Heartbeat:Connect(updateMinimap)
	
	-- Input handling
	local UserInputService = game:GetService("UserInputService")
	
	-- Toggle minimap with M, zoom with +/- or [ ]
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.M then
			MinimapClient:Toggle()
		elseif input.KeyCode == Enum.KeyCode.Equals or input.KeyCode == Enum.KeyCode.Plus 
			or input.KeyCode == Enum.KeyCode.RightBracket then
			-- Zoom in (decrease range)
			MinimapClient:ZoomIn()
		elseif input.KeyCode == Enum.KeyCode.Minus or input.KeyCode == Enum.KeyCode.LeftBracket then
			-- Zoom out (increase range)
			MinimapClient:ZoomOut()
		end
	end)
	
	-- Mouse wheel zoom when hovering over minimap
	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			-- Check if mouse is over minimap
			local mousePos = UserInputService:GetMouseLocation()
			if minimapFrame then
				local mapPos = minimapFrame.AbsolutePosition
				local mapSize = minimapFrame.AbsoluteSize
				
				if mousePos.X >= mapPos.X and mousePos.X <= mapPos.X + mapSize.X
					and mousePos.Y >= mapPos.Y and mousePos.Y <= mapPos.Y + mapSize.Y then
					if input.Position.Z > 0 then
						MinimapClient:ZoomIn()
					else
						MinimapClient:ZoomOut()
					end
				end
			end
		end
	end)
	
	-- Listen for new chunks/resources being added
	Workspace.DescendantAdded:Connect(function(descendant)
		-- Check if it's a harvestable resource (ProximityPrompt added)
		if descendant:IsA("ProximityPrompt") then
			local parent = descendant.Parent
			if parent and not cachedResources[parent] then
				local pos = getObjectPosition(parent)
				if pos then
					local parentName = parent.Parent and parent.Parent.Name or ""
					local resourceType, color = classifyResource(parent.Name, parentName)
					cachedResources[parent] = {
						position = pos,
						type = resourceType,
						color = color,
						name = parent.Name,
					}
				end
			end
		end
	end)
	
	-- Track spawn point when character is added
	local function onCharacterAdded(character)
		task.wait(0.1) -- Wait for character to be positioned
		local hrp = character:WaitForChild("HumanoidRootPart", 5)
		if hrp and not spawnPosition then
			-- Only set spawn on first spawn (or if manually reset)
			spawnPosition = hrp.Position
			dprint("[MinimapClient] Spawn point recorded:", spawnPosition)
		end
	end
	
	player.CharacterAdded:Connect(onCharacterAdded)
	
	-- Set initial spawn point if character already exists
	if player.Character then
		onCharacterAdded(player.Character)
	end
	
	dprint("[MinimapClient] Initialized - M=toggle | +/-=zoom | Scroll over map to zoom")
	dprint("[MinimapClient] Fog of war:", CONFIG.FogEnabled and "ON" or "OFF", "| Explore radius:", CONFIG.ExploreRadius)
	dprint("[MinimapClient] Spawn marker: ON - Orange marker always points to spawn")
end

init()

return MinimapClient
