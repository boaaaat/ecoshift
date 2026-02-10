-- OffsetMeasurer plugin
-- Adjusts only Y offset and writes it to a NumberValue named "Offset".

local Selection = game:GetService("Selection")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TOOLBAR_NAME = "Ecoshift"
local BUTTON_NAME = "OffsetMeasurer"
local BUTTON_TOOLTIP = "Preview Y Offset on a selected biome terrain patch"
local WIDGET_ID = "Ecoshift_OffsetMeasurerWidget"

local PATCH_SIZE_XZ = 28
local TERRAIN_RESOLUTION = 4
local CAMERA_LOOK_AHEAD = 20
local DEFAULT_STEP = 0.25
local PREVIEW_FOLDER_NAME = "_OffsetMeasurerPreview"

local toolbar = plugin:CreateToolbar(TOOLBAR_NAME)
local button = toolbar:CreateButton(BUTTON_NAME, BUTTON_TOOLTIP, "")
button.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	true,
	false,
	340,
	290,
	240,
	220
)
local widget = plugin:CreateDockWidgetPluginGui(WIDGET_ID, widgetInfo)
widget.Title = "Offset Measurer"

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
root.BorderSizePixel = 0
root.Parent = widget

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = root

local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Vertical
list.HorizontalAlignment = Enum.HorizontalAlignment.Left
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0, 6)
list.Parent = root

local function makeLabel(text, sizeY, order)
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, sizeY)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.SourceSans
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(235, 235, 235)
	label.Text = text
	label.Parent = root
	return label
end

local titleLabel = makeLabel("Select model, choose biome, tune Y offset.", 22, 1)
titleLabel.TextSize = 17
titleLabel.Font = Enum.Font.SourceSansSemibold

local statusLabel = makeLabel("Idle", 20, 2)
statusLabel.TextColor3 = Color3.fromRGB(155, 210, 255)

local function makeBiomeRow(order)
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 30)
	row.BackgroundTransparency = 1
	row.Parent = root

	local rowList = Instance.new("UIListLayout")
	rowList.FillDirection = Enum.FillDirection.Horizontal
	rowList.VerticalAlignment = Enum.VerticalAlignment.Center
	rowList.Padding = UDim.new(0, 6)
	rowList.Parent = row

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 42, 1, 0)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.SourceSansBold
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(240, 240, 240)
	label.Text = "Biome"
	label.Parent = row

	local prev = Instance.new("TextButton")
	prev.Size = UDim2.new(0, 28, 0, 24)
	prev.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
	prev.BorderSizePixel = 0
	prev.Font = Enum.Font.SourceSansBold
	prev.TextSize = 18
	prev.TextColor3 = Color3.fromRGB(230, 230, 230)
	prev.Text = "<"
	prev.AutoButtonColor = true
	prev.Parent = row

	local value = Instance.new("TextLabel")
	value.Size = UDim2.new(1, -116, 0, 24)
	value.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	value.BorderSizePixel = 0
	value.TextXAlignment = Enum.TextXAlignment.Center
	value.Font = Enum.Font.Code
	value.TextSize = 15
	value.TextColor3 = Color3.fromRGB(240, 240, 240)
	value.Text = "Forest"
	value.Parent = row

	local next = Instance.new("TextButton")
	next.Size = UDim2.new(0, 28, 0, 24)
	next.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
	next.BorderSizePixel = 0
	next.Font = Enum.Font.SourceSansBold
	next.TextSize = 18
	next.TextColor3 = Color3.fromRGB(230, 230, 230)
	next.Text = ">"
	next.AutoButtonColor = true
	next.Parent = row

	return row, value, prev, next
end

local function makeOffsetRow(order)
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 30)
	row.BackgroundTransparency = 1
	row.Parent = root

	local rowList = Instance.new("UIListLayout")
	rowList.FillDirection = Enum.FillDirection.Horizontal
	rowList.VerticalAlignment = Enum.VerticalAlignment.Center
	rowList.Padding = UDim.new(0, 6)
	rowList.Parent = row

	local axisLabel = Instance.new("TextLabel")
	axisLabel.Size = UDim2.new(0, 20, 1, 0)
	axisLabel.BackgroundTransparency = 1
	axisLabel.TextXAlignment = Enum.TextXAlignment.Left
	axisLabel.Font = Enum.Font.SourceSansBold
	axisLabel.TextSize = 16
	axisLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
	axisLabel.Text = "Y"
	axisLabel.Parent = row

	local minus = Instance.new("TextButton")
	minus.Size = UDim2.new(0, 26, 0, 24)
	minus.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
	minus.BorderSizePixel = 0
	minus.Font = Enum.Font.SourceSansBold
	minus.TextSize = 18
	minus.TextColor3 = Color3.fromRGB(230, 230, 230)
	minus.Text = "-"
	minus.AutoButtonColor = true
	minus.Parent = row

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -116, 0, 24)
	box.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	box.BorderSizePixel = 0
	box.Font = Enum.Font.Code
	box.TextSize = 15
	box.TextColor3 = Color3.fromRGB(240, 240, 240)
	box.ClearTextOnFocus = false
	box.Text = "0"
	box.Parent = row

	local plus = Instance.new("TextButton")
	plus.Size = UDim2.new(0, 26, 0, 24)
	plus.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
	plus.BorderSizePixel = 0
	plus.Font = Enum.Font.SourceSansBold
	plus.TextSize = 18
	plus.TextColor3 = Color3.fromRGB(230, 230, 230)
	plus.Text = "+"
	plus.AutoButtonColor = true
	plus.Parent = row

	return row, box, minus, plus
end

local biomeRow, biomeValueLabel, biomePrevButton, biomeNextButton = makeBiomeRow(3)
local yRow, yBox, yMinus, yPlus = makeOffsetRow(4)

local stepRow = Instance.new("Frame")
stepRow.LayoutOrder = 5
stepRow.Size = UDim2.new(1, 0, 0, 30)
stepRow.BackgroundTransparency = 1
stepRow.Parent = root

local stepList = Instance.new("UIListLayout")
stepList.FillDirection = Enum.FillDirection.Horizontal
stepList.VerticalAlignment = Enum.VerticalAlignment.Center
stepList.Padding = UDim.new(0, 6)
stepList.Parent = stepRow

local stepLabel = Instance.new("TextLabel")
stepLabel.Size = UDim2.new(0, 58, 1, 0)
stepLabel.BackgroundTransparency = 1
stepLabel.TextXAlignment = Enum.TextXAlignment.Left
stepLabel.Font = Enum.Font.SourceSansBold
stepLabel.TextSize = 16
stepLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
stepLabel.Text = "Step"
stepLabel.Parent = stepRow

local stepBox = Instance.new("TextBox")
stepBox.Size = UDim2.new(0, 90, 0, 24)
stepBox.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
stepBox.BorderSizePixel = 0
stepBox.Font = Enum.Font.Code
stepBox.TextSize = 15
stepBox.TextColor3 = Color3.fromRGB(240, 240, 240)
stepBox.ClearTextOnFocus = false
stepBox.Text = tostring(DEFAULT_STEP)
stepBox.Parent = stepRow

local resetButton = Instance.new("TextButton")
resetButton.LayoutOrder = 6
resetButton.Size = UDim2.new(1, 0, 0, 30)
resetButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
resetButton.BorderSizePixel = 0
resetButton.Font = Enum.Font.SourceSansSemibold
resetButton.TextSize = 16
resetButton.TextColor3 = Color3.fromRGB(235, 235, 235)
resetButton.Text = "Reset Y Offset"
resetButton.Parent = root

local valueLabel = makeLabel("Offset NumberValue: 0", 22, 7)
valueLabel.Font = Enum.Font.Code
valueLabel.TextSize = 15
valueLabel.TextColor3 = Color3.fromRGB(210, 210, 210)

local terrainInfoLabel = makeLabel("Terrain: -", 20, 8)
terrainInfoLabel.Font = Enum.Font.Code
terrainInfoLabel.TextSize = 14
terrainInfoLabel.TextColor3 = Color3.fromRGB(180, 220, 180)

local biomeConfigCache = nil

local state = {
	enabled = false,
	source = nil,
	offsetOwner = nil,
	offsetValue = nil,
	offsetConn = nil,
	suppressOffsetSignal = false,
	previewModel = nil,
	basePivot = CFrame.new(),
	offsetY = 0,
	biomeNames = {},
	biomeIndex = 1,
	terrainBackup = nil,
	terrainPatchCenter = nil,
	terrainPatchSize = nil,
}

local function formatNumber(v)
	local text = string.format("%.3f", v)
	text = text:gsub("%.?0+$", "")
	if text == "-0" then
		return "0"
	end
	return text
end

local function materialToName(material)
	local raw = tostring(material)
	return raw:gsub("^Enum%.Material%.", "")
end

local function ensurePreviewFolder()
	local folder = Workspace:FindFirstChild(PREVIEW_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = PREVIEW_FOLDER_NAME
		folder.Parent = Workspace
	end
	return folder
end

local function restoreTerrainPatch()
	local backup = state.terrainBackup
	local patchCenter = state.terrainPatchCenter
	local patchSize = state.terrainPatchSize
	if not backup then
		state.terrainPatchCenter = nil
		state.terrainPatchSize = nil
		if patchCenter and patchSize then
			pcall(function()
				Workspace.Terrain:FillBlock(CFrame.new(patchCenter), patchSize, Enum.Material.Air)
			end)
		end
		return
	end
	state.terrainBackup = nil
	state.terrainPatchCenter = nil
	state.terrainPatchSize = nil
	pcall(function()
		Workspace.Terrain:WriteVoxels(backup.Region, TERRAIN_RESOLUTION, backup.Materials, backup.Occupancy)
	end)
end

local function clearPreview()
	if state.previewModel then
		state.previewModel:Destroy()
		state.previewModel = nil
	end
	restoreTerrainPatch()
	local folder = Workspace:FindFirstChild(PREVIEW_FOLDER_NAME)
	if folder and #folder:GetChildren() == 0 then
		folder:Destroy()
	end
end

local function disconnectOffsetSignal()
	if state.offsetConn then
		state.offsetConn:Disconnect()
		state.offsetConn = nil
	end
end

local function getFirstBasePart(instance)
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		if instance.PrimaryPart then
			return instance.PrimaryPart
		end
		for _, d in ipairs(instance:GetDescendants()) do
			if d:IsA("BasePart") then
				return d
			end
		end
	end
	return nil
end

local function asModel(instance)
	if instance:IsA("Model") then
		return instance
	end
	if instance:IsA("BasePart") then
		local model = Instance.new("Model")
		model.Name = instance.Name
		instance.Parent = model
		model.PrimaryPart = instance
		return model
	end
	return nil
end

local function resolveSelectionTarget()
	local selected = Selection:Get()
	if #selected == 0 then
		return nil
	end

	local target = selected[1]
	if target:IsA("Model") or target:IsA("BasePart") then
		return target
	end

	local ancestorModel = target:FindFirstAncestorOfClass("Model")
	if ancestorModel then
		return ancestorModel
	end

	local ancestorPart = target:FindFirstAncestorWhichIsA("BasePart")
	if ancestorPart then
		return ancestorPart
	end

	return nil
end

local function resolveOffsetOwner(target)
	if not target then
		return nil
	end
	if target:IsA("Model") then
		local rootModel = target
		while rootModel.Parent and rootModel.Parent:IsA("Model") do
			rootModel = rootModel.Parent
		end
		return rootModel
	end
	if target:IsA("BasePart") then
		local ancestorModel = target:FindFirstAncestorOfClass("Model")
		if not ancestorModel then
			return target
		end
		local rootModel = ancestorModel
		while rootModel.Parent and rootModel.Parent:IsA("Model") do
			rootModel = rootModel.Parent
		end
		return rootModel
	end
	return nil
end

local function getOrCreateOffsetValue(owner)
	if not owner then
		return nil, "No owner for Offset value.", false
	end

	local existing = owner:FindFirstChild("Offset", true)
	if existing then
		if existing:IsA("NumberValue") then
			return existing, nil, false
		end
		return nil, "Offset exists but is not a NumberValue.", false
	end

	local value = Instance.new("NumberValue")
	value.Name = "Offset"
	value.Value = 0
	value.Parent = owner
	return value, nil, true
end

local function sanitizePreviewModel(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") then
			d:Destroy()
		elseif d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = false
			d.Transparency = math.min(0.75, d.Transparency + 0.2)
		end
	end
end

local function getBiomeConfig()
	if biomeConfigCache then
		return biomeConfigCache
	end
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local configModule = shared and shared:FindFirstChild("BiomeConfig")
	if configModule and configModule:IsA("ModuleScript") then
		local ok, config = pcall(require, configModule)
		if ok and type(config) == "table" then
			biomeConfigCache = config
			return biomeConfigCache
		end
	end
	biomeConfigCache = {}
	return biomeConfigCache
end

local function getTerrainBaseY(config)
	local world = config and config.WORLD
	local fromWorld = world and tonumber(world.BaseY)
	if fromWorld ~= nil then
		return fromWorld
	end
	local fromLegacy = config and (tonumber(config.base_y) or tonumber(config.baseY))
	if fromLegacy ~= nil then
		return fromLegacy
	end
	return 0
end

local function getTerrainThickness(config)
	local terrain = config and config.TERRAIN
	local thickness = terrain and tonumber(terrain.Thickness)
	if thickness and thickness > 0 then
		return thickness
	end
	return 24
end

local function materialFromName(name)
	if typeof(name) == "EnumItem" then
		return name
	end
	if type(name) ~= "string" then
		return Enum.Material.Grass
	end
	local ok, material = pcall(function()
		return Enum.Material[name]
	end)
	if ok and material then
		return material
	end
	return Enum.Material.Grass
end

local function getAssetOverride(config, assetName)
	local overrides = config and config.asset_overrides
	if type(overrides) ~= "table" or type(assetName) ~= "string" or assetName == "" then
		return nil
	end
	local override = overrides[assetName]
	if type(override) == "table" then
		return override
	end
	return nil
end

local function getMaterialForBiome(config, biomeName)
	local terrain = config and config.TERRAIN
	local map = terrain and terrain.MaterialByBiome
	if type(map) == "table" then
		return materialFromName(map[biomeName])
	end
	return Enum.Material.Grass
end

local function getAssetYOffset(config, assetName)
	local override = getAssetOverride(config, assetName)
	if type(override) ~= "table" then
		return 0
	end
	return tonumber(override.yOffset or override.YOffset or override.offsetY or override.OffsetY) or 0
end

local function getAssetScale(config, assetName)
	local override = getAssetOverride(config, assetName)
	if type(override) ~= "table" then
		return nil
	end
	local scale = tonumber(override.scale or override.Scale)
	if not scale or scale <= 0 or math.abs(scale - 1) < 0.0001 then
		return nil
	end
	return scale
end

local function shouldApplyScaleOverride(source)
	return source and not source:IsDescendantOf(Workspace)
end

local function tryApplyScaleOverride(instance, config, assetName)
	local scale = getAssetScale(config, assetName)
	if not scale then
		return
	end
	pcall(function()
		if instance:IsA("Model") then
			instance:ScaleTo(scale)
		elseif instance:IsA("BasePart") then
			instance.Size = instance.Size * scale
		end
	end)
end

local function collectBiomeNames(config)
	local seen = {}
	local names = {}

	local function addName(name)
		if type(name) ~= "string" or name == "" or seen[name] then
			return
		end
		seen[name] = true
		table.insert(names, name)
	end

	if type(config.BIOMES) == "table" then
		for name in pairs(config.BIOMES) do
			addName(name)
		end
	end
	if type(config.biomes) == "table" then
		for name in pairs(config.biomes) do
			addName(name)
		end
	end

	local terrain = config and config.TERRAIN
	local map = terrain and terrain.MaterialByBiome
	if type(map) == "table" then
		for name in pairs(map) do
			addName(name)
		end
	end

	if #names == 0 then
		addName("Forest")
	end

	table.sort(names)
	return names
end

local function getCurrentBiomeName()
	if #state.biomeNames == 0 then
		return "Forest"
	end
	local index = math.clamp(state.biomeIndex, 1, #state.biomeNames)
	return state.biomeNames[index]
end

local function updateBiomeLabel()
	biomeValueLabel.Text = getCurrentBiomeName()
end

local function initializeBiomeSelection()
	local config = getBiomeConfig()
	state.biomeNames = collectBiomeNames(config)
	state.biomeIndex = 1

	local preferred = config.BIOME_DEFAULT or config.biome_default
	if type(preferred) == "string" and preferred ~= "" then
		for i, name in ipairs(state.biomeNames) do
			if name == preferred then
				state.biomeIndex = i
				break
			end
		end
	end
	updateBiomeLabel()
end

local function getPatchXZPosition()
	local camera = Workspace.CurrentCamera
	if camera then
		local lookPoint = camera.CFrame.Position + (camera.CFrame.LookVector * CAMERA_LOOK_AHEAD)
		return lookPoint.X, lookPoint.Z
	end
	return 0, 0
end

local function simulateBiomeTerrainPatch(biomeName)
	local config = getBiomeConfig()
	local baseY = getTerrainBaseY(config)
	local thickness = getTerrainThickness(config)
	local material = getMaterialForBiome(config, biomeName)

	local x, z = getPatchXZPosition()
	local center = Vector3.new(x, baseY - (thickness * 0.5), z)
	local size = Vector3.new(PATCH_SIZE_XZ, thickness, PATCH_SIZE_XZ)
	state.terrainPatchCenter = center
	state.terrainPatchSize = size
	local half = size * 0.5
	local region = Region3.new(center - half, center + half):ExpandToGrid(TERRAIN_RESOLUTION)

	local terrain = Workspace.Terrain
	local okRead, mats, occ = pcall(function()
		return terrain:ReadVoxels(region, TERRAIN_RESOLUTION)
	end)
	if okRead and mats and occ then
		state.terrainBackup = {
			Region = region,
			Materials = mats,
			Occupancy = occ,
		}
	end

	terrain:FillBlock(CFrame.new(center), size, material)
	return center, baseY, thickness, material
end

local function updateOffsetLabel()
	valueLabel.Text = "Offset NumberValue: " .. formatNumber(state.offsetY)
end

local function setBoxFromOffset()
	yBox.Text = formatNumber(state.offsetY)
	updateOffsetLabel()
end

local function applyOffsetToPreview()
	if not state.previewModel then
		updateOffsetLabel()
		return
	end
	state.previewModel:PivotTo(state.basePivot * CFrame.new(0, state.offsetY, 0))
	updateOffsetLabel()
end

local function writeOffsetValue()
	if not state.offsetValue or not state.offsetValue.Parent then
		return
	end
	state.suppressOffsetSignal = true
	state.offsetValue.Value = state.offsetY
	state.suppressOffsetSignal = false
end

local function syncFromOffsetValue()
	if not state.offsetValue or not state.offsetValue.Parent then
		return
	end
	state.offsetY = tonumber(state.offsetValue.Value) or 0
	setBoxFromOffset()
	applyOffsetToPreview()
end

local function connectOffsetSignal()
	disconnectOffsetSignal()
	if not state.offsetValue then
		return
	end
	state.offsetConn = state.offsetValue:GetPropertyChangedSignal("Value"):Connect(function()
		if state.suppressOffsetSignal then
			return
		end
		syncFromOffsetValue()
	end)
end

local function rebuildPreview()
	clearPreview()
	disconnectOffsetSignal()
	state.offsetOwner = nil
	state.offsetValue = nil
	terrainInfoLabel.Text = "Terrain: -"

	local target = resolveSelectionTarget()
	state.source = target
	if not target then
		statusLabel.Text = "Select one Model or BasePart."
		state.offsetY = 0
		setBoxFromOffset()
		return
	end

	local owner = resolveOffsetOwner(target)
	state.offsetOwner = owner
	if not owner then
		statusLabel.Text = "Unable to resolve Offset owner."
		return
	end

	local offsetValue, err, created = getOrCreateOffsetValue(owner)
	if not offsetValue then
		statusLabel.Text = err or "Offset value setup failed."
		return
	end
	state.offsetValue = offsetValue
	connectOffsetSignal()
	syncFromOffsetValue()

	local previewSource = owner
	local config = getBiomeConfig()
	local assetName = previewSource.Name
	local clone = previewSource:Clone()
	local previewModel = asModel(clone)
	if not previewModel then
		statusLabel.Text = "Selected object is not previewable."
		return
	end
	if shouldApplyScaleOverride(previewSource) then
		tryApplyScaleOverride(previewModel, config, assetName)
	end
	sanitizePreviewModel(previewModel)
	if not getFirstBasePart(previewModel) then
		previewModel:Destroy()
		statusLabel.Text = "Selection has no BasePart to preview."
		return
	end

	local biomeName = getCurrentBiomeName()
	local patchCenter, terrainBaseY, _, material = simulateBiomeTerrainPatch(biomeName)
	local configuredAssetYOffset = getAssetYOffset(config, assetName)
	local assetYOffset = configuredAssetYOffset
	local calibratedFromWorld = false
	if previewSource:IsDescendantOf(Workspace) then
		local okPivot, pivot = pcall(function()
			return previewSource:GetPivot()
		end)
		if okPivot and pivot then
			local observedAssetYOffset = pivot.Position.Y - terrainBaseY - state.offsetY
			if math.abs(observedAssetYOffset - configuredAssetYOffset) > 0.01 then
				assetYOffset = observedAssetYOffset
				calibratedFromWorld = true
			end
		end
	end

	local baseY = terrainBaseY + assetYOffset
	state.basePivot = CFrame.new(patchCenter.X, baseY, patchCenter.Z)

	local parentFolder = ensurePreviewFolder()
	previewModel.Name = previewSource.Name .. "_OffsetPreview"
	previewModel.Parent = parentFolder

	state.previewModel = previewModel
	applyOffsetToPreview()

	if calibratedFromWorld then
		terrainInfoLabel.Text = string.format(
			"Terrain: %s | BaseY=%s | AssetY=%s (cfg %s) | Mat=%s",
			biomeName,
			formatNumber(terrainBaseY),
			formatNumber(assetYOffset),
			formatNumber(configuredAssetYOffset),
			materialToName(material)
		)
	else
		terrainInfoLabel.Text = string.format(
			"Terrain: %s | BaseY=%s | AssetY=%s | Mat=%s",
			biomeName,
			formatNumber(terrainBaseY),
			formatNumber(assetYOffset),
			materialToName(material)
		)
	end

	if created then
		statusLabel.Text = "Preview: " .. previewSource.Name .. " (created Offset NumberValue)"
	else
		statusLabel.Text = "Preview: " .. previewSource.Name
	end
end

local function parseYOffsetFromBox()
	local y = tonumber(yBox.Text)
	if not y then
		return
	end
	state.offsetY = y
	writeOffsetValue()
	applyOffsetToPreview()
end

local function getStepValue()
	local value = tonumber(stepBox.Text)
	if not value then
		return DEFAULT_STEP
	end
	return math.max(0.001, math.abs(value))
end

local function nudgeY(sign)
	local step = getStepValue() * sign
	state.offsetY = state.offsetY + step
	setBoxFromOffset()
	writeOffsetValue()
	applyOffsetToPreview()
end

local function cycleBiome(delta)
	if #state.biomeNames == 0 then
		return
	end
	state.biomeIndex = state.biomeIndex + delta
	if state.biomeIndex < 1 then
		state.biomeIndex = #state.biomeNames
	elseif state.biomeIndex > #state.biomeNames then
		state.biomeIndex = 1
	end
	updateBiomeLabel()
	if state.enabled then
		rebuildPreview()
	end
end

local function setEnabled(enabled)
	state.enabled = enabled
	if widget.Enabled ~= enabled then
		widget.Enabled = enabled
	end
	button:SetActive(enabled)
	if enabled then
		rebuildPreview()
	else
		clearPreview()
		disconnectOffsetSignal()
		state.offsetOwner = nil
		state.offsetValue = nil
		terrainInfoLabel.Text = "Terrain: -"
		statusLabel.Text = "Idle"
	end
end

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not widget.Enabled and state.enabled then
		setEnabled(false)
	elseif widget.Enabled and not state.enabled then
		setEnabled(true)
	end
end)

button.Click:Connect(function()
	setEnabled(not state.enabled)
end)

Selection.SelectionChanged:Connect(function()
	if state.enabled then
		rebuildPreview()
	end
end)

biomePrevButton.MouseButton1Click:Connect(function()
	cycleBiome(-1)
end)

biomeNextButton.MouseButton1Click:Connect(function()
	cycleBiome(1)
end)

yBox:GetPropertyChangedSignal("Text"):Connect(parseYOffsetFromBox)
yMinus.MouseButton1Click:Connect(function() nudgeY(-1) end)
yPlus.MouseButton1Click:Connect(function() nudgeY(1) end)

resetButton.MouseButton1Click:Connect(function()
	state.offsetY = 0
	setBoxFromOffset()
	writeOffsetValue()
	applyOffsetToPreview()
end)

plugin.Unloading:Connect(function()
	clearPreview()
	disconnectOffsetSignal()
	local folder = Workspace:FindFirstChild(PREVIEW_FOLDER_NAME)
	if folder then
		folder:Destroy()
	end
end)

initializeBiomeSelection()
setBoxFromOffset()
widget.Enabled = false
