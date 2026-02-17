-- BuildingUI.client.lua
-- Allows players to place items from their inventory (workbenches, campfires, etc.)
-- Press B to open building mode, or right-click placeable items in inventory
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local BiomeConfig = require(ReplicatedStorage.Shared.BiomeConfig)
local Util = require(ReplicatedStorage.Shared.Util)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)
local ResultMessages = require(ReplicatedStorage.Shared.ResultMessages)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 5)
local rBuild = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.Build)
local rInventory = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.InventoryUpdate)
if not remotesFolder then
	warn("[BuildingUI] Missing remotes folder:", Config.Paths.Remotes)
elseif not rBuild then
	warn("[BuildingUI] Missing build remote:", Config.RemoteNames.Build)
end

-- UI Constants
local COLORS = {
	Background = Color3.fromRGB(18, 18, 22),
	Panel = Color3.fromRGB(28, 28, 35),
	SlotEmpty = Color3.fromRGB(38, 38, 48),
	SlotFilled = Color3.fromRGB(48, 48, 60),
	SlotHover = Color3.fromRGB(58, 58, 75),
	SlotSelected = Color3.fromRGB(80, 120, 200),
	Border = Color3.fromRGB(60, 60, 80),
	Text = Color3.fromRGB(240, 240, 245),
	TextMuted = Color3.fromRGB(160, 160, 175),
	Accent = Color3.fromRGB(100, 180, 255),
	Success = Color3.fromRGB(80, 200, 120),
	Warning = Color3.fromRGB(255, 180, 80),
	Danger = Color3.fromRGB(220, 80, 80),
	ValidPlacement = Color3.fromRGB(80, 200, 120),
	InvalidPlacement = Color3.fromRGB(220, 80, 80),
}

local GRID_SIZE = Config.GRID.Size or 6
local BUILD_MESSAGES = ResultMessages.Build or {}
local DEFAULT_HINT_TEXT = "Click to place • Right-click to cancel"

-- State
local isPlacementMode = false
local selectedItem = nil
local inventorySnapshot = nil
local previewPart = nil
local canPlace = false
local hintMessageToken = 0

-- Create GUI
local gui = Instance.new("ScreenGui")
gui.Name = "BuildingUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Placement mode indicator
local modeIndicator = Instance.new("Frame")
modeIndicator.Name = "ModeIndicator"
modeIndicator.Size = UDim2.new(0, 200, 0, 50)
modeIndicator.Position = UDim2.new(0.5, 0, 0, 20)
modeIndicator.AnchorPoint = Vector2.new(0.5, 0)
modeIndicator.BackgroundColor3 = COLORS.Panel
modeIndicator.BackgroundTransparency = 0.1
modeIndicator.BorderSizePixel = 0
modeIndicator.Visible = false
modeIndicator.ZIndex = 100
modeIndicator.Parent = gui

local indicatorCorner = Instance.new("UICorner")
indicatorCorner.CornerRadius = UDim.new(0, 10)
indicatorCorner.Parent = modeIndicator

local indicatorStroke = Instance.new("UIStroke")
indicatorStroke.Color = COLORS.Accent
indicatorStroke.Thickness = 2
indicatorStroke.Parent = modeIndicator

local indicatorLabel = Instance.new("TextLabel")
indicatorLabel.Name = "Label"
indicatorLabel.Size = UDim2.new(1, -20, 1, 0)
indicatorLabel.Position = UDim2.new(0, 10, 0, 0)
indicatorLabel.BackgroundTransparency = 1
indicatorLabel.Text = "🔨 Placing: Workbench"
indicatorLabel.TextColor3 = COLORS.Text
indicatorLabel.TextSize = 16
indicatorLabel.Font = Enum.Font.GothamBold
indicatorLabel.ZIndex = 101
indicatorLabel.Parent = modeIndicator

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Size = UDim2.new(0, 300, 0, 24)
hintLabel.Position = UDim2.new(0.5, 0, 0, 75)
hintLabel.AnchorPoint = Vector2.new(0.5, 0)
hintLabel.BackgroundTransparency = 1
hintLabel.Text = DEFAULT_HINT_TEXT
hintLabel.TextColor3 = COLORS.TextMuted
hintLabel.TextSize = 12
hintLabel.Font = Enum.Font.Gotham
hintLabel.Visible = false
hintLabel.ZIndex = 100
hintLabel.Parent = gui

local function showHintStatus(text, color, duration)
	hintMessageToken += 1
	local token = hintMessageToken
	hintLabel.Text = text
	hintLabel.TextColor3 = color
	hintLabel.Visible = true
	task.delay(duration or 1, function()
		if token ~= hintMessageToken then return end
		if isPlacementMode then
			hintLabel.Text = DEFAULT_HINT_TEXT
			hintLabel.TextColor3 = COLORS.TextMuted
			hintLabel.Visible = true
		else
			hintLabel.Visible = false
		end
	end)
end

-- Item selection panel (shows placeable items)
local selectionPanel = Instance.new("Frame")
selectionPanel.Name = "SelectionPanel"
selectionPanel.Size = UDim2.new(0, 320, 0, 180)
selectionPanel.Position = UDim2.new(0.5, 0, 1, -20)
selectionPanel.AnchorPoint = Vector2.new(0.5, 1)
selectionPanel.BackgroundColor3 = COLORS.Panel
selectionPanel.BackgroundTransparency = 0.05
selectionPanel.BorderSizePixel = 0
selectionPanel.Visible = false
selectionPanel.ZIndex = 90
selectionPanel.Parent = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = selectionPanel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = COLORS.Border
panelStroke.Thickness = 1
panelStroke.Parent = selectionPanel

local panelTitle = Instance.new("TextLabel")
panelTitle.Name = "Title"
panelTitle.Size = UDim2.new(1, 0, 0, 30)
panelTitle.BackgroundTransparency = 1
panelTitle.Text = "🏗️ Place Item (B to toggle)"
panelTitle.TextColor3 = COLORS.Text
panelTitle.TextSize = 14
panelTitle.Font = Enum.Font.GothamBold
panelTitle.ZIndex = 91
panelTitle.Parent = selectionPanel

local itemContainer = Instance.new("ScrollingFrame")
itemContainer.Name = "Items"
itemContainer.Size = UDim2.new(1, -20, 1, -40)
itemContainer.Position = UDim2.new(0, 10, 0, 35)
itemContainer.BackgroundTransparency = 1
itemContainer.BorderSizePixel = 0
itemContainer.ScrollBarThickness = 4
itemContainer.ScrollBarImageColor3 = COLORS.Border
itemContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
itemContainer.ZIndex = 91
itemContainer.Parent = selectionPanel

local itemLayout = Instance.new("UIGridLayout")
itemLayout.CellSize = UDim2.new(0, 70, 0, 70)
itemLayout.CellPadding = UDim2.new(0, 8, 0, 8)
itemLayout.SortOrder = Enum.SortOrder.Name
itemLayout.Parent = itemContainer

-- Helper: Get placeable items from inventory
local function getPlaceableItems()
	local items = {}
	if not inventorySnapshot then return items end
	
	local placeableTypes = Config.BUILD.PlaceableItems or {}
	
	local function checkSlots(slots)
		for _, slot in pairs(slots) do
			if slot and slot.Id and placeableTypes[slot.Id] then
				items[slot.Id] = (items[slot.Id] or 0) + slot.N
			end
		end
	end
	
	if inventorySnapshot.Hotbar then checkSlots(inventorySnapshot.Hotbar) end
	if inventorySnapshot.Storage then checkSlots(inventorySnapshot.Storage) end
	
	return items
end

-- Helper: Snap to grid
local function snapToGrid(position)
	local gx = math.floor((position.X / GRID_SIZE) + 0.5)
	local gz = math.floor((position.Z / GRID_SIZE) + 0.5)
	return Vector3.new(gx * GRID_SIZE, position.Y, gz * GRID_SIZE)
end

-- Helper: Raycast for placement
local function getPlacementPosition()
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	
	local unitRay = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {player.Character, previewPart}
	
	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 100, raycastParams)
	if result then
		return snapToGrid(result.Position + Vector3.new(0, GRID_SIZE / 2, 0))
	end
	return nil
end

-- Helper: Check if placement is valid
local function isValidPlacement(position)
	if not position then return false end
	
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	
	-- Distance check
	local distance = (root.Position - position).Magnitude
	if distance > (Config.GRID.BuildMaxDistance or 45) then
		return false
	end
	
	-- World bounds check
	local dist = math.sqrt(position.X * position.X + position.Z * position.Z)
	if dist > (BiomeConfig.WORLD.WorldRadius or 2200) then
		return false
	end
	
	return true
end

-- Create/update preview part
local function updatePreview()
	if not isPlacementMode or not selectedItem then
		if previewPart then
			previewPart:Destroy()
			previewPart = nil
		end
		return
	end
	
	local position = getPlacementPosition()
	if not position then
		if previewPart then
			previewPart.Transparency = 1
		end
		return
	end
	
	if not previewPart then
		previewPart = Instance.new("Part")
		previewPart.Name = "PlacementPreview"
		previewPart.Size = Vector3.new(GRID_SIZE - 0.5, GRID_SIZE - 0.5, GRID_SIZE - 0.5)
		previewPart.Anchored = true
		previewPart.CanCollide = false
		previewPart.Transparency = 0.5
		previewPart.Material = Enum.Material.SmoothPlastic
		previewPart.Parent = workspace
		
		-- Add selection box effect
		local selection = Instance.new("SelectionBox")
		selection.Adornee = previewPart
		selection.Color3 = COLORS.ValidPlacement
		selection.LineThickness = 0.05
		selection.Parent = previewPart
	end
	
	previewPart.Position = position
	previewPart.Transparency = 0.5
	
	canPlace = isValidPlacement(position)
	previewPart.Color = canPlace and COLORS.ValidPlacement or COLORS.InvalidPlacement
	
	local selection = previewPart:FindFirstChildOfClass("SelectionBox")
	if selection then
		selection.Color3 = canPlace and COLORS.ValidPlacement or COLORS.InvalidPlacement
	end
end

-- Create item button
local function createItemButton(itemId, count)
	local item = ItemDatabase:Get(itemId)
	local name = item and item.Name or itemId
	
	local btn = Instance.new("TextButton")
	btn.Name = itemId
	btn.Size = UDim2.new(0, 70, 0, 70)
	btn.BackgroundColor3 = selectedItem == itemId and COLORS.SlotSelected or COLORS.SlotFilled
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.ZIndex = 92
	btn.Parent = itemContainer
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = selectedItem == itemId and COLORS.Accent or COLORS.Border
	stroke.Thickness = selectedItem == itemId and 2 or 1
	stroke.Parent = btn
	
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -4, 0, 32)
	nameLabel.Position = UDim2.new(0, 2, 0, 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = name
	nameLabel.TextColor3 = COLORS.Text
	nameLabel.TextSize = 10
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextWrapped = true
	nameLabel.ZIndex = 93
	nameLabel.Parent = btn
	
	local countLabel = Instance.new("TextLabel")
	countLabel.Size = UDim2.new(1, -4, 0, 20)
	countLabel.Position = UDim2.new(0, 2, 1, -24)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = "x" .. count
	countLabel.TextColor3 = COLORS.TextMuted
	countLabel.TextSize = 12
	countLabel.Font = Enum.Font.Gotham
	countLabel.ZIndex = 93
	countLabel.Parent = btn
	
	btn.MouseButton1Click:Connect(function()
		selectedItem = itemId
		local itemData = ItemDatabase:Get(itemId)
		indicatorLabel.Text = "🔨 Placing: " .. (itemData and itemData.Name or itemId)
		isPlacementMode = true
		modeIndicator.Visible = true
		hintLabel.Visible = true
		hintLabel.Text = DEFAULT_HINT_TEXT
		hintLabel.TextColor3 = COLORS.TextMuted
		refreshItems()
	end)
	
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = COLORS.SlotHover}):Play()
	end)
	
	btn.MouseLeave:Connect(function()
		local color = selectedItem == itemId and COLORS.SlotSelected or COLORS.SlotFilled
		TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = color}):Play()
	end)
	
	return btn
end

-- Refresh item list
function refreshItems()
	-- Clear ALL gui children except the layout
	for _, child in ipairs(itemContainer:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	
	local placeableItems = getPlaceableItems()
	local hasItems = false
	
	for itemId, count in pairs(placeableItems) do
		createItemButton(itemId, count)
		hasItems = true
	end
	
	if not hasItems then
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Name = "EmptyLabel"
		emptyLabel.Size = UDim2.new(1, 0, 0, 50)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.Text = "No placeable items\nCraft a Workbench first! (Press C)"
		emptyLabel.TextColor3 = COLORS.TextMuted
		emptyLabel.TextSize = 12
		emptyLabel.Font = Enum.Font.Gotham
		emptyLabel.ZIndex = 92
		emptyLabel.Parent = itemContainer
	end
	
	task.defer(function()
		itemContainer.CanvasSize = UDim2.new(0, 0, 0, itemLayout.AbsoluteContentSize.Y)
	end)
end

-- Toggle selection panel
local function togglePanel()
	selectionPanel.Visible = not selectionPanel.Visible
	if selectionPanel.Visible then
		refreshItems()
	end
end

-- Cancel placement
local function cancelPlacement()
	isPlacementMode = false
	selectedItem = nil
	modeIndicator.Visible = false
	hintLabel.Visible = false
	if previewPart then
		previewPart:Destroy()
		previewPart = nil
	end
end

-- Place item
local function placeItem()
	if not isPlacementMode or not selectedItem or not canPlace then return end
	if not rBuild then return end
	
	local position = getPlacementPosition()
	if not position then return end
	
	-- Send build request to server
	rBuild:FireServer("Place", {
		Type = selectedItem,
		Position = position,
	})
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	
	if input.KeyCode == Enum.KeyCode.B then
		if isPlacementMode then
			cancelPlacement()
			selectionPanel.Visible = false
		else
			togglePanel()
		end
	elseif input.KeyCode == Enum.KeyCode.Escape and isPlacementMode then
		cancelPlacement()
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and isPlacementMode then
		placeItem()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 and isPlacementMode then
		cancelPlacement()
	end
end)

-- Update preview every frame
RunService.RenderStepped:Connect(function()
	updatePreview()
end)

-- Inventory sync
if rInventory then
	rInventory.OnClientEvent:Connect(function(kind, payload)
		if kind ~= "Snapshot" or type(payload) ~= "table" then return end
		
		if payload.Storage then
			local normalized = {}
			for k, v in pairs(payload.Storage) do
				local numKey = tonumber(k)
				if numKey and v then
					normalized[numKey] = v
				end
			end
			payload.Storage = normalized
		end
		if payload.Hotbar then
			local normalized = {}
			for k, v in pairs(payload.Hotbar) do
				local numKey = tonumber(k)
				if numKey and v then
					normalized[numKey] = v
				end
			end
			payload.Hotbar = normalized
		end
		
		inventorySnapshot = payload
		
		if selectionPanel.Visible then
			refreshItems()
		end
	end)
end

if rBuild then
	rBuild.OnClientEvent:Connect(function(kind, payload)
		if kind ~= "Result" or type(payload) ~= "table" then return end
		if payload.Action ~= "Place" and payload.Action ~= "Remove" then return end
		local success = payload.Success == true
		local reason = tostring(payload.Reason or (success and "Success" or "Unknown"))
		if success then
			showHintStatus(BUILD_MESSAGES.Success or "Build action complete.", COLORS.Success, 0.8)
		else
			showHintStatus(BUILD_MESSAGES[reason] or BUILD_MESSAGES.Unknown or "Build action failed.", COLORS.Danger, 1.2)
		end
		task.delay(0.2, refreshItems)
	end)
end

print("[BuildingUI] Ready - Press B to open building menu")
print("[BuildingUI] Craft workbenches (Press C) then place them!")
