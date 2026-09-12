local Settings = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ClientSettings"))
if require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end
-- InventoryUI.client.lua
-- Polished inventory system with modern UI
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Theme = require(ReplicatedStorage.Shared.UI.UITheme)
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)
local DEBUG = false

local function dprint(...)
	if DEBUG then
		print(...)
	end
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- OPTIMIZED: Try immediate lookup first, use shorter timeout
local remotesFolder = Util.GetDescendant(Config.Paths.Remotes) 
	or Util.WaitForDescendant(Config.Paths.Remotes, 5)
local rInventory = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.InventoryUpdate)
local rInventoryAction = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.InventoryAction)
local rDrop = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.DropItem)
local rChest = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.ChestEvent)

-- UI Constants
local COLORS = Theme.Colors

local SLOT_SIZE = 64
local HOTBAR_SLOT_SIZE = 60
local SLOT_GAP = 6
local HOTBAR_SLOTS = 6
local STORAGE_COLS = 6
local STORAGE_ROWS = 3
local MARGIN = 16
local HEADER_HEIGHT = 44
local STORAGE_WIDTH = (SLOT_SIZE * STORAGE_COLS) + (SLOT_GAP * (STORAGE_COLS - 1))
local STORAGE_HEIGHT = (SLOT_SIZE * STORAGE_ROWS) + (SLOT_GAP * (STORAGE_ROWS - 1))
local ARMOR_SECTION_HEIGHT = SLOT_SIZE + 22
local STORAGE_SECTION_HEIGHT = STORAGE_HEIGHT + 22
local MAIN_HEIGHT = HEADER_HEIGHT + ARMOR_SECTION_HEIGHT + STORAGE_SECTION_HEIGHT + MARGIN + 8

-- Create main GUI
local gui = Instance.new("ScreenGui")
gui.Name = "InventoryUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 20
gui.Parent = playerGui

local dragOverlay = Instance.new("ScreenGui")
dragOverlay.Name = "InventoryDragOverlay"
dragOverlay.ResetOnSpawn = false
dragOverlay.IgnoreGuiInset = true
dragOverlay.DisplayOrder = 200
dragOverlay.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
dragOverlay.Parent = playerGui

-- Main container
local mainContainer = Instance.new("Frame")
mainContainer.Name = "MainContainer"
mainContainer.Size = UDim2.new(0, STORAGE_WIDTH + MARGIN * 2, 0, MAIN_HEIGHT)
mainContainer.AnchorPoint = Vector2.new(0.5, 0.5)
mainContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
mainContainer.BackgroundColor3 = COLORS.Panel
mainContainer.BackgroundTransparency = 0.05
mainContainer.BorderSizePixel = 0
mainContainer.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainContainer

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = COLORS.Border
mainStroke.Thickness = 1
mainStroke.Transparency = 0.5
mainStroke.Parent = mainContainer

mainContainer.Visible = false

-- Shadow effect
local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.Size = UDim2.new(1, 30, 1, 30)
shadow.Position = UDim2.new(0, -15, 0, -10)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://5554236805"
shadow.ImageColor3 = Color3.new(0, 0, 0)
shadow.ImageTransparency = 0.6
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(23, 23, 277, 277)
shadow.ZIndex = -1
shadow.Parent = mainContainer

-- Header
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundTransparency = 1
header.Parent = mainContainer

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(0, 230, 1, 0)
titleLabel.Position = UDim2.new(0, MARGIN, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Field pack"
titleLabel.TextColor3 = COLORS.Text
titleLabel.TextSize = 18
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

-- Capacity indicator
local capacityLabel = Instance.new("TextLabel")
capacityLabel.Name = "Capacity"
capacityLabel.Size = UDim2.new(0, 80, 0, 20)
capacityLabel.AnchorPoint = Vector2.new(1, 0.5)
capacityLabel.Position = UDim2.new(1, -MARGIN - 36, 0.5, 0)
capacityLabel.BackgroundTransparency = 1
capacityLabel.Text = string.format("0/%d", HOTBAR_SLOTS + STORAGE_COLS * STORAGE_ROWS)
capacityLabel.TextColor3 = COLORS.TextMuted
capacityLabel.TextSize = 12
capacityLabel.Font = Enum.Font.Gotham
capacityLabel.TextXAlignment = Enum.TextXAlignment.Right
capacityLabel.Parent = header

local transferStatusLabel = Instance.new("TextLabel")
transferStatusLabel.Name = "TransferStatus"
transferStatusLabel.Size = UDim2.new(0, 240, 0, 14)
transferStatusLabel.AnchorPoint = Vector2.new(1, 1)
transferStatusLabel.Position = UDim2.new(1, -MARGIN, 1, -4)
transferStatusLabel.BackgroundTransparency = 1
transferStatusLabel.Text = ""
transferStatusLabel.TextColor3 = COLORS.TextMuted
transferStatusLabel.TextSize = 11
transferStatusLabel.Font = Enum.Font.Gotham
transferStatusLabel.TextXAlignment = Enum.TextXAlignment.Right
transferStatusLabel.Visible = false
transferStatusLabel.Parent = header

-- Armor section (inside inventory)
local armorSection = Instance.new("Frame")
armorSection.Name = "ArmorSection"
armorSection.Size = UDim2.new(1, -MARGIN * 2, 0, ARMOR_SECTION_HEIGHT)
armorSection.Position = UDim2.new(0, MARGIN, 0, HEADER_HEIGHT)
armorSection.BackgroundTransparency = 1
armorSection.Parent = mainContainer

local armorLabel = Instance.new("TextLabel")
armorLabel.Size = UDim2.new(1, 0, 0, 14)
armorLabel.BackgroundTransparency = 1
armorLabel.Text = "ARMOR"
armorLabel.TextColor3 = COLORS.TextMuted
armorLabel.TextSize = 10
armorLabel.Font = Enum.Font.GothamBold
armorLabel.TextXAlignment = Enum.TextXAlignment.Left
armorLabel.Parent = armorSection

local armorContainer = Instance.new("Frame")
armorContainer.Name = "Slots"
armorContainer.Size = UDim2.new(1, 0, 0, SLOT_SIZE)
armorContainer.Position = UDim2.new(0, 0, 0, 16)
armorContainer.BackgroundTransparency = 1
armorContainer.Parent = armorSection

-- Storage section
local storageSection = Instance.new("Frame")
storageSection.Name = "StorageSection"
storageSection.Size = UDim2.new(1, -MARGIN * 2, 0, STORAGE_SECTION_HEIGHT)
storageSection.Position = UDim2.new(0, MARGIN, 0, HEADER_HEIGHT + ARMOR_SECTION_HEIGHT + 8)
storageSection.BackgroundTransparency = 1
storageSection.Parent = mainContainer

local storageLabel = Instance.new("TextLabel")
storageLabel.Size = UDim2.new(1, 0, 0, 14)
storageLabel.BackgroundTransparency = 1
storageLabel.Text = "STORAGE"
storageLabel.TextColor3 = COLORS.TextMuted
storageLabel.TextSize = 10
storageLabel.Font = Enum.Font.GothamBold
storageLabel.TextXAlignment = Enum.TextXAlignment.Left
storageLabel.Parent = storageSection

local storageContainer = Instance.new("Frame")
storageContainer.Name = "Slots"
storageContainer.Size = UDim2.new(1, 0, 0, STORAGE_HEIGHT)
storageContainer.Position = UDim2.new(0, 0, 0, 16)
storageContainer.BackgroundTransparency = 1
storageContainer.Parent = storageSection

-- Hotbar (always visible, bottom center)
local hotbarRoot = Instance.new("Frame")
hotbarRoot.Name = "HotbarRoot"
hotbarRoot.Size = UDim2.new(0, (HOTBAR_SLOT_SIZE * HOTBAR_SLOTS) + (SLOT_GAP * (HOTBAR_SLOTS - 1)) + MARGIN * 2, 0, HOTBAR_SLOT_SIZE + 12)
hotbarRoot.AnchorPoint = Vector2.new(0.5, 1)
hotbarRoot.Position = UDim2.new(0.5, 0, 1, -18)
hotbarRoot.BackgroundTransparency = 1
hotbarRoot.Parent = gui

local hotbarPanel = Instance.new("Frame")
hotbarPanel.Name = "HotbarPanel"
hotbarPanel.Size = UDim2.new(1, 0, 1, 0)
hotbarPanel.BackgroundColor3 = COLORS.Panel
hotbarPanel.BackgroundTransparency = 0.1
hotbarPanel.BorderSizePixel = 0
hotbarPanel.Parent = hotbarRoot

local hotbarCorner = Instance.new("UICorner")
hotbarCorner.CornerRadius = UDim.new(0, 10)
hotbarCorner.Parent = hotbarPanel

local hotbarStroke = Instance.new("UIStroke")
hotbarStroke.Color = COLORS.Border
hotbarStroke.Thickness = 1
hotbarStroke.Transparency = 0.5
hotbarStroke.Parent = hotbarPanel

local hotbarContainer = Instance.new("Frame")
hotbarContainer.Name = "Slots"
hotbarContainer.Size = UDim2.new(0, (HOTBAR_SLOT_SIZE * HOTBAR_SLOTS) + (SLOT_GAP * (HOTBAR_SLOTS - 1)), 0, HOTBAR_SLOT_SIZE)
hotbarContainer.AnchorPoint = Vector2.new(0.5, 0.5)
hotbarContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
hotbarContainer.BackgroundTransparency = 1
hotbarContainer.Parent = hotbarPanel

-- Inventory and chests share the same readable hover details.
local itemTooltip = require(ReplicatedStorage.Shared.UI.ItemTooltip).new(gui)
local tooltip = itemTooltip.Frame

-- Slot creation helper
local function createSlot(parent, x, y, slotType, index, slotSize)
	slotSize = slotSize or SLOT_SIZE
	local iconSize = math.floor(slotSize * 0.62)
	local keySize = math.max(16, math.floor(slotSize * 0.25))
	local badgeW = math.max(24, math.floor(slotSize * 0.4))
	local badgeH = math.max(14, math.floor(slotSize * 0.22))

	local slot = Instance.new("Frame")
	slot.Name = slotType .. "_" .. index
	slot:SetAttribute("SlotType", slotType)
	slot:SetAttribute("SlotIndex", index)
	slot:SetAttribute("HasItem", false)
	slot:SetAttribute("ItemId", "")
	slot:SetAttribute("Count", 0)
	slot.Size = UDim2.new(0, slotSize, 0, slotSize)
	slot.Position = UDim2.new(0, x, 0, y)
	slot.BackgroundColor3 = COLORS.SlotEmpty
	slot.BorderSizePixel = 0
	slot.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = slot

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Color = COLORS.Border
	stroke.Thickness = 1
	stroke.Transparency = 0.7
	stroke.Parent = slot

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, iconSize, 0, iconSize)
	icon.Position = UDim2.new(0.5, 0, 0.5, -2)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.Image = ""
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = slot

	-- Text label for items without icons
	local itemText = Instance.new("TextLabel")
	itemText.Name = "ItemText"
	itemText.Size = UDim2.new(1, -8, 0, 32)
	itemText.Position = UDim2.new(0.5, 0, 0.5, -2)
	itemText.AnchorPoint = Vector2.new(0.5, 0.5)
	itemText.BackgroundTransparency = 1
	itemText.TextColor3 = COLORS.Text
	itemText.TextSize = 10
	itemText.Font = Enum.Font.GothamBold
	itemText.TextWrapped = false
	itemText.TextTruncate = Enum.TextTruncate.AtEnd
	itemText.Text = ""
	itemText.Visible = false
	itemText.ZIndex = 3
	itemText.Parent = slot

	-- Quantity badge
	local qtyBadge = Instance.new("Frame")
	qtyBadge.Name = "QtyBadge"
	qtyBadge.Size = UDim2.new(0, badgeW, 0, badgeH)
	qtyBadge.Position = UDim2.new(1, -(badgeW + 2), 1, -(badgeH + 2))
	qtyBadge.BackgroundColor3 = COLORS.Background
	qtyBadge.BackgroundTransparency = 0.4
	qtyBadge.BorderSizePixel = 0
	qtyBadge.Visible = false
	qtyBadge.ZIndex = 5
	qtyBadge.Parent = slot

	local qtyCorner = Instance.new("UICorner")
	qtyCorner.CornerRadius = UDim.new(0, 4)
	qtyCorner.Parent = qtyBadge

	local qtyLabel = Instance.new("TextLabel")
	qtyLabel.Name = "Label"
	qtyLabel.Size = UDim2.new(1, 0, 1, 0)
	qtyLabel.BackgroundTransparency = 1
	qtyLabel.TextColor3 = COLORS.Text
	qtyLabel.TextSize = 10
	qtyLabel.Font = Enum.Font.GothamBold
	qtyLabel.Text = "99"
	qtyLabel.ZIndex = 6
	qtyLabel.Parent = qtyBadge

	-- Keybind indicator for hotbar
	if slotType == "Hotbar" then
		local keybind = Instance.new("TextLabel")
		keybind.Name = "Keybind"
		keybind.Size = UDim2.new(0, keySize, 0, keySize)
		keybind.Position = UDim2.new(0, 4, 0, 4)
		keybind.BackgroundColor3 = COLORS.Background
		keybind.BackgroundTransparency = 0.5
		keybind.BorderSizePixel = 0
		keybind.TextColor3 = COLORS.TextMuted
		keybind.TextSize = 10
		keybind.Font = Enum.Font.GothamBold
		keybind.Text = tostring(index)
		keybind.ZIndex = 5
		keybind.Parent = slot

		local keybindCorner = Instance.new("UICorner")
		keybindCorner.CornerRadius = UDim.new(0, 4)
		keybindCorner.Parent = keybind
	end

	-- Armor badge
	if slotType == "Armor" then
		local armorBadge = Instance.new("TextLabel")
		armorBadge.Name = "ArmorBadge"
		armorBadge.Size = UDim2.new(0, 18, 0, 14)
		armorBadge.Position = UDim2.new(0, 4, 0, 4)
		armorBadge.BackgroundColor3 = COLORS.Warning
		armorBadge.BackgroundTransparency = 0.3
		armorBadge.BorderSizePixel = 0
		armorBadge.TextColor3 = COLORS.Paper
		armorBadge.TextSize = 9
		armorBadge.Font = Enum.Font.GothamBold
		armorBadge.Text = "A"
		armorBadge.ZIndex = 5
		armorBadge.Parent = slot

		local armorBadgeCorner = Instance.new("UICorner")
		armorBadgeCorner.CornerRadius = UDim.new(0, 4)
		armorBadgeCorner.Parent = armorBadge
		
		stroke.Color = COLORS.Warning
		stroke.Transparency = 0.5
	end

	-- Invisible button for interactions
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.ZIndex = 10
	button.Parent = slot

	return {
		Frame = slot,
		Icon = icon,
		ItemText = itemText,
		QtyBadge = qtyBadge,
		QtyLabel = qtyLabel,
		Stroke = stroke,
		Button = button,
		Type = slotType,
		Index = index,
	}
end

-- Create all slots
local slots = {}

-- Hotbar slots
for i = 1, HOTBAR_SLOTS do
	local x = (i - 1) * (HOTBAR_SLOT_SIZE + SLOT_GAP)
	local slot = createSlot(hotbarContainer, x, 0, "Hotbar", i, HOTBAR_SLOT_SIZE)
	table.insert(slots, slot)
end

-- Armor slot (inside inventory)
local armorSlot = createSlot(armorContainer, 0, 0, "Armor", 1, SLOT_SIZE)
table.insert(slots, armorSlot)

-- Storage slots
for i = 1, STORAGE_COLS * STORAGE_ROWS do
	local row = math.floor((i - 1) / STORAGE_COLS)
	local col = (i - 1) % STORAGE_COLS
	local x = col * (SLOT_SIZE + SLOT_GAP)
	local y = row * (SLOT_SIZE + SLOT_GAP)
	local slot = createSlot(storageContainer, x, y, "Storage", i, SLOT_SIZE)
	table.insert(slots, slot)
end

-- State
local inventorySnapshot = nil
local selectedSlot = nil
local hoveredSlot = nil
local inventoryOpen = false
local contextMenu = nil
local equippedToolName = nil
local characterConnections = {}
local INVENTORY_TOGGLE_ACTION = "EcoshiftToggleInventory"
local inventoryToggleActionBound = false
local transferStatusToken = 0
local cancelDrag = nil
local clearSplitCursor = nil

local function showTransferStatus(text, color, duration)
	transferStatusToken += 1
	local token = transferStatusToken
	if type(text) ~= "string" or text == "" then
		transferStatusLabel.Visible = false
		transferStatusLabel.Text = ""
		return
	end
	transferStatusLabel.Text = text
	transferStatusLabel.TextColor3 = color or COLORS.TextMuted
	transferStatusLabel.Visible = true
	task.delay(tonumber(duration) or 1.0, function()
		if token ~= transferStatusToken then return end
		transferStatusLabel.Visible = false
		transferStatusLabel.Text = ""
	end)
end

-- Consumable feedback remains visible when using the hotbar with inventory closed.
local useNotice = Instance.new("Frame")
useNotice.Name, useNotice.Size = "ItemUseNotice", UDim2.fromOffset(380, 48)
useNotice.AnchorPoint, useNotice.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -116)
useNotice.Visible, useNotice.Parent = false, gui
Theme.Panel(useNotice, false)
Theme.Fit(useNotice, 380, 48, nil, true)
Theme.AnimatePanel(useNotice)
local useNoticeText = Theme.Label(useNotice, "", UDim2.new(1, -24, 1, -12), UDim2.fromOffset(12, 6), 14, COLORS.Text, true)
useNoticeText.TextWrapped = true
local useNoticeToken = 0
if rInventoryAction then
	rInventoryAction.OnClientEvent:Connect(function(action, payload)
		if action ~= "UseResult" or type(payload) ~= "table" or type(payload.Message) ~= "string" then return end
		useNoticeToken += 1
		local token = useNoticeToken
		useNoticeText.Text = payload.Message
		useNoticeText.TextColor3 = payload.Success and COLORS.Success or COLORS.Warning
		useNotice.Visible = true
		task.delay(3, function() if token == useNoticeToken then useNotice.Visible = false end end)
	end)
end

local function isChestTransferLockActive()
	return gui:GetAttribute("ChestOpen") == true
end

local function setInventoryOpen(open, force)
	if not force and isChestTransferLockActive() and not open then
		return
	end
	inventoryOpen = open and true or false
	mainContainer.Visible = inventoryOpen
	if not inventoryOpen then
		if tooltip then tooltip.Visible = false end
		if contextMenu then contextMenu.Visible = false end
		showTransferStatus(nil)
		if cancelDrag then
			cancelDrag()
		end
		if clearSplitCursor then clearSplitCursor() end
	end
end

local function bindInventoryToggleAction()
	ContextActionService:UnbindAction(INVENTORY_TOGGLE_ACTION)
	local priority = Enum.ContextActionPriority.High.Value + 200
	local ok = pcall(function()
		ContextActionService:BindActionAtPriority(INVENTORY_TOGGLE_ACTION, function(_, inputState)
			if player:GetAttribute("IsDead") then return Enum.ContextActionResult.Pass end
			if inputState ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Sink
			end
			if isChestTransferLockActive() then
				return Enum.ContextActionResult.Sink
			end
			if not Settings.CanInput() then
				return Enum.ContextActionResult.Sink
			end
			setInventoryOpen(not inventoryOpen)
			return Enum.ContextActionResult.Sink
		end, false, priority, Settings.Key("Pack"))
	end)
	inventoryToggleActionBound = ok
end

bindInventoryToggleAction()

gui:GetAttributeChangedSignal("ForceOpen"):Connect(function()
	local v = gui:GetAttribute("ForceOpen")
	if typeof(v) == "boolean" then
		setInventoryOpen(v, true)
	end
end)

gui:GetAttributeChangedSignal("ChestOpen"):Connect(function()
	if gui:GetAttribute("ChestOpen") == true then
		setInventoryOpen(true, true)
	else
		showTransferStatus(nil)
		if cancelDrag then
			cancelDrag()
		end
	end
end)

-- Helper functions
local function hashColor(id)
	local hash = 0
	for i = 1, #id do
		hash = (hash * 33 + string.byte(id, i)) % 360
	end
	return COLORS.Text
end

local function getItemStackSize(itemId)
	local item = ItemDatabase:Get(itemId)
	return (item and tonumber(item.StackSize)) or 99
end

local function isPlaceableItem(itemId)
	return Config.BUILD.PlaceableItems and Config.BUILD.PlaceableItems[itemId] == true
end


local function getSlotData(slotType, index)
	if not inventorySnapshot then return nil end
	if slotType == "Hotbar" then
		return inventorySnapshot.Hotbar and inventorySnapshot.Hotbar[index]
	elseif slotType == "Storage" then
		return inventorySnapshot.Storage and inventorySnapshot.Storage[index]
	elseif slotType == "Armor" then
		return inventorySnapshot.Armor
	end
	return nil
end

local function updateCapacity()
	if not inventorySnapshot then return end
	local count = 0
	local total = HOTBAR_SLOTS + STORAGE_COLS * STORAGE_ROWS
	for i = 1, HOTBAR_SLOTS do
		if inventorySnapshot.Hotbar and inventorySnapshot.Hotbar[i] then count = count + 1 end
	end
	for i = 1, STORAGE_COLS * STORAGE_ROWS do
		if inventorySnapshot.Storage and inventorySnapshot.Storage[i] then count = count + 1 end
	end
	capacityLabel.Text = string.format("%d/%d", count, total)
	if count >= total then
		capacityLabel.TextColor3 = COLORS.Danger
	elseif count >= total * 0.8 then
		capacityLabel.TextColor3 = COLORS.Warning
	else
		capacityLabel.TextColor3 = COLORS.TextMuted
	end
end

local function showTooltip(slot, data)
	itemTooltip:Show(data, "Drag to move • Right-click to split • Q drops one")
end

local function hideTooltip()
	tooltip.Visible = false
end

local function isPointInsideGui(guiObject, point, touch)
	if not guiObject or not guiObject.Visible then return false end
	local inset = GuiService:GetGuiInset()
	if touch then inset = Vector2.zero end
	local adjustedPoint = Vector2.new(point.X - inset.X, point.Y - inset.Y)
	local pos = guiObject.AbsolutePosition
	local size = guiObject.AbsoluteSize
	return adjustedPoint.X >= pos.X
		and adjustedPoint.X <= pos.X + size.X
		and adjustedPoint.Y >= pos.Y
		and adjustedPoint.Y <= pos.Y + size.Y
end

local function getEquippedHotbarIndex()
	if not inventorySnapshot or not equippedToolName then
		return nil
	end
	local hotbar = inventorySnapshot.Hotbar or {}
	for i = 1, HOTBAR_SLOTS do
		local slot = hotbar[i]
		if slot and slot.Id == equippedToolName then
			return i
		end
	end
	return nil
end

local function setSlotSelected(slot, selected)
	local shouldSelect = selected
	if slot.Type == "Hotbar" then
		shouldSelect = getEquippedHotbarIndex() == slot.Index
	end
	if shouldSelect then
		slot.Stroke.Color = COLORS.SlotSelected
		slot.Stroke.Thickness = 2
		slot.Stroke.Transparency = 0
	elseif slot.Type == "Armor" then
		slot.Stroke.Color = COLORS.Warning
		slot.Stroke.Thickness = 1
		slot.Stroke.Transparency = 0.5
	else
		slot.Stroke.Color = COLORS.Border
		slot.Stroke.Thickness = 1
		slot.Stroke.Transparency = 0.7
	end
end

local function setSlotHovered(slot, hovered)
	local data = getSlotData(slot.Type, slot.Index)
	local targetColor = hovered and COLORS.SlotHover or (data and COLORS.SlotFilled or COLORS.SlotEmpty)
	TweenService:Create(slot.Frame, TweenInfo.new(0.12), {BackgroundColor3 = targetColor}):Play()
end

local function renderSlot(slot)
	local data = getSlotData(slot.Type, slot.Index)
	if slot.HarvestGlyph then slot.HarvestGlyph.Visible = false end
	
	if not data then
		slot.Icon.Image = ""
		slot.Icon.Visible = false
		slot.ItemText.Visible = false
		slot.ItemText.Text = ""
		slot.QtyBadge.Visible = false
		slot.Frame.BackgroundColor3 = COLORS.SlotEmpty
		slot.Frame:SetAttribute("HasItem", false)
		slot.Frame:SetAttribute("ItemId", "")
		slot.Frame:SetAttribute("Count", 0)
		return
	end
	
	local item = ItemDatabase:Get(data.Id)
	local icon = item and item.Icon
	local iconColor = item and item.IconColor
	local name = item and item.Name or data.Id
	
	if icon and icon ~= "" then
		-- Has icon - show image, hide text
		slot.Icon.Image = icon
		slot.Icon.ImageColor3 = Color3.new(1, 1, 1)
		slot.Icon.Visible = true
		slot.ItemText.Visible = false
	else
		-- No icon - show text label instead
		slot.Icon.Image = ""
		slot.Icon.Visible = false
		-- Break at a word boundary; long single words truncate instead of wrapping
		-- their last letters into an unreadable second line on phone hotbars.
		slot.ItemText.Text = name:gsub(" ", "\n", 1)
		slot.ItemText.TextColor3 = COLORS.Text
		slot.ItemText.Visible = true
		if Theme.IsMobile() and slot.Type == "Hotbar" and not mainContainer.Visible and data.Id == "Harvester" then
			if not slot.HarvestGlyph then slot.HarvestGlyph = Theme.Icon(slot.Frame, "Harvest", 30) end
			slot.HarvestGlyph.Visible = true
			slot.ItemText.Visible = false
		end
	end
	
	if data.N > 1 then
		slot.QtyBadge.Visible = true
		slot.QtyLabel.Text = tostring(data.N)
	else
		slot.QtyBadge.Visible = false
	end
	
	slot.Frame.BackgroundColor3 = COLORS.SlotFilled
	slot.Frame:SetAttribute("HasItem", true)
	slot.Frame:SetAttribute("ItemId", data.Id)
	slot.Frame:SetAttribute("Count", data.N)
end

local function renderAll()
	for _, slot in ipairs(slots) do
		renderSlot(slot)
		setSlotSelected(slot, selectedSlot == slot)
	end
	updateCapacity()
end

local function disconnectCharacterConnections()
	for _, conn in ipairs(characterConnections) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(characterConnections)
end

local function syncEquippedToolName()
	local nextName = nil
	local char = player.Character
	if char then
		for _, child in ipairs(char:GetChildren()) do
			if child:IsA("Tool") then
				nextName = child.Name
				break
			end
		end
	end
	if equippedToolName ~= nextName then
		equippedToolName = nextName
		renderAll()
	end
end

local function bindCharacter(char)
	disconnectCharacterConnections()
	if not char then
		equippedToolName = nil
		renderAll()
		return
	end
	characterConnections[#characterConnections + 1] = char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.defer(syncEquippedToolName)
		end
	end)
	characterConnections[#characterConnections + 1] = char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			task.defer(syncEquippedToolName)
		end
	end)
	task.defer(syncEquippedToolName)
end

local function isShiftDown()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

local function findEmptySlot(slotType)
	if not inventorySnapshot then return nil end
	if slotType == "Hotbar" then
		local hotbar = inventorySnapshot.Hotbar or {}
		for i = 1, HOTBAR_SLOTS do
			if not hotbar[i] then
				return i
			end
		end
	elseif slotType == "Storage" then
		local storage = inventorySnapshot.Storage or {}
		for i = 1, STORAGE_COLS * STORAGE_ROWS do
			if not storage[i] then
				return i
			end
		end
	end
	return nil
end

local function isSameSlot(fromSlot, slotType, index)
	return fromSlot and fromSlot.Type == slotType and fromSlot.Index == index
end

local function findStackSlot(slotType, itemId, fromSlot)
	if not inventorySnapshot then return nil end
	local maxStack = getItemStackSize(itemId)
	if slotType == "Hotbar" then
		local hotbar = inventorySnapshot.Hotbar or {}
		for i = 1, HOTBAR_SLOTS do
			local slotData = hotbar[i]
			if slotData and slotData.Id == itemId and slotData.N < maxStack and not isSameSlot(fromSlot, slotType, i) then
				return i
			end
		end
	elseif slotType == "Storage" then
		local storage = inventorySnapshot.Storage or {}
		for i = 1, STORAGE_COLS * STORAGE_ROWS do
			local slotData = storage[i]
			if slotData and slotData.Id == itemId and slotData.N < maxStack and not isSameSlot(fromSlot, slotType, i) then
				return i
			end
		end
	end
	return nil
end

local function findBestInventoryTarget(fromSlot, itemId)
	local order = { "Storage", "Hotbar" }
	if fromSlot and fromSlot.Type == "Storage" then
		order = { "Hotbar", "Storage" }
	end
	for _, slotType in ipairs(order) do
		local stackIndex = findStackSlot(slotType, itemId, fromSlot)
		if stackIndex then
			return slotType, stackIndex
		end
		local emptyIndex = findEmptySlot(slotType)
		if emptyIndex then
			return slotType, emptyIndex
		end
	end
	return nil, nil
end

local function getOpenChestSlotsContainer()
	if gui:GetAttribute("ChestOpen") ~= true then
		return nil, nil
	end
	local chestId = gui:GetAttribute("ChestId")
	if type(chestId) ~= "string" or chestId == "" then
		return nil, nil
	end
	local chestGui = playerGui:FindFirstChild("ChestUI")
	if not chestGui then return nil, nil end
	local chestPanel = chestGui:FindFirstChild("ChestPanel")
	if not chestPanel or not chestPanel:IsA("Frame") or not chestPanel.Visible then
		return nil, nil
	end
	local chestSlots = chestPanel:FindFirstChild("Slots")
	if not chestSlots then return nil, nil end
	return chestId, chestSlots
end

local function findChestTargetSlot(itemId)
	local _, chestSlots = getOpenChestSlotsContainer()
	if not chestSlots then return nil end
	local maxStack = getItemStackSize(itemId)
	local stackTarget = nil
	local emptyTarget = nil
	for _, frame in ipairs(chestSlots:GetChildren()) do
		if frame:IsA("Frame") then
			local index = tonumber(frame:GetAttribute("ChestIndex"))
			if index then
				if frame:GetAttribute("HasItem") == true then
					local frameItem = frame:GetAttribute("ItemId")
					local count = tonumber(frame:GetAttribute("Count")) or 0
					if frameItem == itemId and count < maxStack and (not stackTarget or index < stackTarget) then
						stackTarget = index
					end
				elseif not emptyTarget or index < emptyTarget then
					emptyTarget = index
				end
			end
		end
	end
	return stackTarget or emptyTarget
end

local swapLocalSlots

local function shiftMove(slot, chestOnly)
	local data = getSlotData(slot.Type, slot.Index)
	if not data then return end
	local item = ItemDatabase:Get(data.Id)
	if not chestOnly and slot.Type ~= "Armor" and item and item:HasTag("Armor") then
		if not rInventoryAction then return end
		-- Move atomically returns the old armor to this same slot, even with a
		-- full inventory. Armor equip takes priority over open-chest transfers.
		rInventoryAction:FireServer("Move", {
			FromType = slot.Type,
			FromIndex = slot.Index,
			ToType = "Armor",
			ToIndex = 1,
		})
		showTransferStatus("Equipping armor...", COLORS.Accent, 0.9)
		return
	end
	local chestAttempted = false
	if rChest then
		local chestId = getOpenChestSlotsContainer()
		if chestId then
			chestAttempted = true
			local chestTarget = findChestTargetSlot(data.Id)
			if chestTarget then
				rChest:FireServer("Put", {
					ChestId = chestId,
					FromType = slot.Type,
					FromIndex = slot.Index,
					ToIndex = chestTarget,
					Amount = data.N,
				})
				showTransferStatus("Moved to chest", COLORS.Accent, 0.9)
				return
			end
		end
	end
	if chestOnly then
		showTransferStatus("Chest has no room for this item", COLORS.Warning, 1.5)
		return
	end
	if not rInventoryAction then return end
	local targetType, targetIndex = findBestInventoryTarget(slot, data.Id)
	if not targetType or not targetIndex then
		if chestAttempted then
			showTransferStatus("Chest full and no inventory slot", COLORS.Warning, 1.2)
		else
			showTransferStatus("No valid inventory slot", COLORS.Warning, 1.0)
		end
		return
	end
	rInventoryAction:FireServer("Move", {
		FromType = slot.Type,
		FromIndex = slot.Index,
		ToType = targetType,
		ToIndex = targetIndex,
	})
	if chestAttempted then
		showTransferStatus("Chest full for item, moved in inventory", COLORS.Warning, 1.1)
	end
end

-- Context menu
contextMenu = Instance.new("Frame")
contextMenu.Name = "ContextMenu"
contextMenu.Size = UDim2.new(0, 120, 0, 120)
contextMenu.BackgroundColor3 = COLORS.Background
contextMenu.BorderSizePixel = 0
contextMenu.Visible = false
contextMenu.ZIndex = 200
contextMenu.Parent = gui

local contextCorner = Instance.new("UICorner")
contextCorner.CornerRadius = UDim.new(0, 6)
contextCorner.Parent = contextMenu

local contextStroke = Instance.new("UIStroke")
contextStroke.Color = COLORS.Border
contextStroke.Thickness = 1
contextStroke.Parent = contextMenu

local function makeMenuButton(text, order)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -8, 0, 24)
	btn.Position = UDim2.new(0, 4, 0, 4 + (order - 1) * 28)
	btn.BackgroundColor3 = COLORS.Panel
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.TextColor3 = COLORS.Text
	btn.Text = text
	btn.ZIndex = 201
	btn.Parent = contextMenu
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = btn
	return btn
end

local contextUse = makeMenuButton("Use", 1)
local contextDrop = makeMenuButton("Drop", 2)
local contextSplit = makeMenuButton("Split", 3)
local contextPlace = makeMenuButton("Equip", 4)
local contextSlot = nil

local function showContextMenu(slot, position, touch)
	contextSlot = slot
	local inset = GuiService:GetGuiInset()
	if touch then inset = Vector2.zero end
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
	local menuSize = contextMenu.AbsoluteSize
	contextMenu.Position = UDim2.fromOffset(math.clamp(position.X - inset.X + 6, 4, math.max(4, viewport.X - menuSize.X - 8)), math.clamp(position.Y - inset.Y + 6, 4, math.max(4, viewport.Y - inset.Y - menuSize.Y - 8)))
	local data = getSlotData(slot.Type, slot.Index)
	local item = data and ItemDatabase:Get(data.Id) or nil
	local canUse = item and (item:HasTag("Food") or item:HasTag("Consumable")) or false
	local canPlace = data and isPlaceableItem(data.Id) and not isChestTransferLockActive() or false
	contextUse.Visible = canUse
	contextPlace.Visible = canPlace
	contextPlace.Text = slot.Type == "Hotbar" and "Equip" or "To hotbar"
	contextMenu.Visible = true
end

local function hideContextMenu()
	contextSlot = nil
	contextMenu.Visible = false
end

contextDrop.MouseButton1Click:Connect(function()
	if not contextSlot then return end
	local data = getSlotData(contextSlot.Type, contextSlot.Index)
	if not data or not rDrop then return end
	rDrop:FireServer({
		SlotType = contextSlot.Type,
		SlotIndex = contextSlot.Index,
		Amount = data.N,
	})
	hideContextMenu()
end)

contextSplit.MouseButton1Click:Connect(function()
	if not contextSlot then return end
	local data = getSlotData(contextSlot.Type, contextSlot.Index)
	if not data or not rInventoryAction then return end
	if data.N < 2 then return end
	rInventoryAction:FireServer("Split", {
		FromType = contextSlot.Type,
		FromIndex = contextSlot.Index,
	})
	hideContextMenu()
end)

contextUse.MouseButton1Click:Connect(function()
	if not contextSlot then return end
	local data = getSlotData(contextSlot.Type, contextSlot.Index)
	if not data or not rInventoryAction then return end
	rInventoryAction:FireServer("Use", {
		SlotType = contextSlot.Type,
		SlotIndex = contextSlot.Index,
	})
	hideContextMenu()
end)

contextPlace.MouseButton1Click:Connect(function()
	if not contextSlot then return end
	local data = getSlotData(contextSlot.Type, contextSlot.Index)
	if not data or not isPlaceableItem(data.Id) then return end
	if contextSlot.Type == "Hotbar" then
		rInventoryAction:FireServer("Equip", {SlotType="Hotbar", SlotIndex=contextSlot.Index})
		setInventoryOpen(false)
	else
		shiftMove(contextSlot)
	end
	hideContextMenu()
end)

local function getLocalSlot(slotType, index)
	if not inventorySnapshot then return nil end
	if slotType == "Hotbar" then
		inventorySnapshot.Hotbar = inventorySnapshot.Hotbar or {}
		return inventorySnapshot.Hotbar[index]
	elseif slotType == "Storage" then
		inventorySnapshot.Storage = inventorySnapshot.Storage or {}
		return inventorySnapshot.Storage[index]
	elseif slotType == "Armor" then
		return inventorySnapshot.Armor
	end
	return nil
end

local function setLocalSlot(slotType, index, value)
	if not inventorySnapshot then return end
	if slotType == "Hotbar" then
		inventorySnapshot.Hotbar = inventorySnapshot.Hotbar or {}
		inventorySnapshot.Hotbar[index] = value
	elseif slotType == "Storage" then
		inventorySnapshot.Storage = inventorySnapshot.Storage or {}
		inventorySnapshot.Storage[index] = value
	elseif slotType == "Armor" then
		inventorySnapshot.Armor = value
	end
end

swapLocalSlots = function(from, to)
	if not inventorySnapshot then return end
	local a = getLocalSlot(from.Type, from.Index)
	local b = getLocalSlot(to.Type, to.Index)
	setLocalSlot(from.Type, from.Index, b)
	setLocalSlot(to.Type, to.Index, a)
	renderAll()
end

local function mergeLocalSlots(from, to)
	if not inventorySnapshot then return false end
	local a = getLocalSlot(from.Type, from.Index)
	local b = getLocalSlot(to.Type, to.Index)
	if not a or not b or a.Id ~= b.Id then return false end
	local item = ItemDatabase:Get(a.Id)
	local maxStack = (item and item.StackSize) or 99
	local space = math.max(0, maxStack - b.N)
	if space <= 0 then return false end
	local move = math.min(space, a.N)
	b.N += move
	a.N -= move
	if a.N <= 0 then
		setLocalSlot(from.Type, from.Index, nil)
	else
		setLocalSlot(from.Type, from.Index, a)
	end
	setLocalSlot(to.Type, to.Index, b)
	renderAll()
	return true
end

-- Drag and drop
local DRAG_THRESHOLD = 6
local dragging = { Active = false, Pending = false, From = nil, Ghost = nil, StartPos = nil, Input = nil }

local function createDragGhost(slot, data)
	local size = slot.Frame.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		size = Vector2.new(SLOT_SIZE, SLOT_SIZE)
	end
	local iconSize = math.floor(size.X * 0.62)
	local ghost = Instance.new("Frame")
	ghost.Name = "DragGhost"
	ghost.Size = UDim2.new(0, size.X, 0, size.Y)
	ghost.BackgroundColor3 = COLORS.SlotSelected
	ghost.BackgroundTransparency = 0.3
	ghost.BorderSizePixel = 0
	ghost.ZIndex = 500
	ghost.Parent = dragOverlay
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = ghost
	
	local item = ItemDatabase:Get(data.Id)
	local itemIcon = item and item.Icon
	local iconColor = item and item.IconColor
	if itemIcon and itemIcon ~= "" then
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(0, iconSize, 0, iconSize)
		icon.Position = UDim2.new(0.5, 0, 0.5, 0)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.ZIndex = 501
		icon.Parent = ghost
		icon.Image = itemIcon
		icon.ImageColor3 = Color3.new(1, 1, 1)
	else
		local nameText = item and item.Name or data.Id
		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, -8, 1, -8)
		text.Position = UDim2.new(0.5, 0, 0.5, 0)
		text.AnchorPoint = Vector2.new(0.5, 0.5)
		text.BackgroundTransparency = 1
		text.TextWrapped = true
		text.TextScaled = true
		text.Font = Enum.Font.GothamBold
		text.TextColor3 = iconColor or hashColor(data.Id)
		text.Text = nameText
		text.ZIndex = 501
		text.Parent = ghost
	end

	if data.N > 1 then
		local qty = Instance.new("TextLabel")
		qty.Name = "Quantity"
		qty.Size = UDim2.new(0, 28, 0, 16)
		qty.AnchorPoint = Vector2.new(1, 1)
		qty.Position = UDim2.new(1, -4, 1, -4)
		qty.BackgroundTransparency = 1
		qty.Font = Enum.Font.GothamBold
		qty.TextSize = 11
		qty.TextColor3 = COLORS.Text
		qty.TextXAlignment = Enum.TextXAlignment.Right
		qty.Text = tostring(data.N)
		qty.ZIndex = 502
		qty.Parent = ghost
	end
	
	return ghost
end

-- Desktop stack splitting behaves like a cursor-held half stack. The server
-- keeps ownership until each placement succeeds, so closing the pack cannot
-- delete or duplicate items.
local splitCursor = { From = nil, Id = nil, Remaining = 0, Ghost = nil, Pending = false, RequestId = nil }
local splitSerial = 0

clearSplitCursor = function()
	if splitCursor.Ghost then splitCursor.Ghost:Destroy() end
	splitCursor.From, splitCursor.Id, splitCursor.Remaining = nil, nil, 0
	splitCursor.Ghost, splitCursor.Pending, splitCursor.RequestId = nil, false, nil
end

local function positionSplitGhost(position)
	if not splitCursor.Ghost then return end
	local size = splitCursor.Ghost.AbsoluteSize
	splitCursor.Ghost.Position = UDim2.fromOffset(position.X - size.X / 2, position.Y - size.Y / 2)
end

local function updateSplitGhost()
	local label = splitCursor.Ghost and splitCursor.Ghost:FindFirstChild("Quantity")
	if label then label.Text = tostring(splitCursor.Remaining) end
end

local function beginSplitCursor(slot)
	if not mainContainer.Visible and not isChestTransferLockActive() then return end
	local data = getSlotData(slot.Type, slot.Index)
	if not data or data.N < 2 or splitCursor.From then return end
	splitCursor.From = slot
	splitCursor.Id = data.Id
	splitCursor.Remaining = math.ceil(data.N / 2)
	splitCursor.Ghost = createDragGhost(slot, {Id=data.Id, N=splitCursor.Remaining})
	positionSplitGhost(UserInputService:GetMouseLocation())
	showTransferStatus(string.format("Holding %d · right-click places one", splitCursor.Remaining), COLORS.Accent, 1.2)
end

local function placeSplitCursor(target, amount)
	if not splitCursor.From or splitCursor.Pending or not rInventoryAction then return end
	if target == splitCursor.From then clearSplitCursor(); return end
	local targetData = getSlotData(target.Type, target.Index)
	if targetData and targetData.Id ~= splitCursor.Id then
		showTransferStatus("That slot contains a different item", COLORS.Warning, 1.0)
		return
	end
	splitSerial += 1
	local requestId = string.format("split:%d:%d", splitSerial, math.floor(os.clock() * 1000))
	splitCursor.Pending, splitCursor.RequestId = true, requestId
	rInventoryAction:FireServer("MoveAmount", {
		RequestId = requestId,
		FromType = splitCursor.From.Type,
		FromIndex = splitCursor.From.Index,
		ToType = target.Type,
		ToIndex = target.Index,
		Amount = math.min(amount, splitCursor.Remaining),
		ExpectedId = splitCursor.Id,
	})
end

if rInventoryAction then
	rInventoryAction.OnClientEvent:Connect(function(action, payload)
		if action ~= "MoveAmountResult" or type(payload) ~= "table" or payload.RequestId ~= splitCursor.RequestId then return end
		splitCursor.Pending, splitCursor.RequestId = false, nil
		local moved = math.max(0, math.floor(tonumber(payload.Moved) or 0))
		if moved <= 0 then
			showTransferStatus("Stack changed or target is full", COLORS.Warning, 1.2)
			clearSplitCursor()
			return
		end
		splitCursor.Remaining -= moved
		if splitCursor.Remaining <= 0 then
			clearSplitCursor()
		else
			updateSplitGhost()
			showTransferStatus(string.format("Holding %d", splitCursor.Remaining), COLORS.Accent, 0.7)
		end
	end)
end

cancelDrag = function()
	if dragging.From then
		dragging.From.Frame.BackgroundTransparency = 0
	end
	if dragging.Ghost then
		dragging.Ghost:Destroy()
	end
	dragging.Active = false
	dragging.Pending = false
	dragging.From = nil
	dragging.Ghost = nil
	dragging.StartPos = nil
	dragging.Input = nil
end

local function beginDrag(slot)
	local data = getSlotData(slot.Type, slot.Index)
	if not data then return end
	
	showTransferStatus(nil)
	selectedSlot = slot
	dragging.Active = true
	dragging.Pending = false
	dragging.From = slot
	dragging.Ghost = createDragGhost(slot, data)
	
	slot.Frame.BackgroundTransparency = 0.5
end

local function endDrag(targetSlot, dropOutside)
	if not dragging.Active then return end

	local from = dragging.From
	cancelDrag()
	if dropOutside and from and rDrop then
		local data = getSlotData(from.Type, from.Index)
		if data then rDrop:FireServer({SlotType=from.Type, SlotIndex=from.Index, Amount=data.N, ExpectedId=data.Id}) end
		return
	end
	if not targetSlot or targetSlot == from then return end
	if not rInventoryAction then return end
	
	rInventoryAction:FireServer("Move", {
		FromType = from.Type,
		FromIndex = from.Index,
		ToType = targetSlot.Type,
		ToIndex = targetSlot.Index,
	})
	-- Optimistic UI update
	if not mergeLocalSlots(from, targetSlot) then
		swapLocalSlots(from, targetSlot)
	end
end

local function chestSlotFrameAtPoint(point, touch)
	local _, chestSlots = getOpenChestSlotsContainer()
	if not chestSlots then return nil end

	local inset = GuiService:GetGuiInset()
	if touch then inset = Vector2.zero end
	local adjustedPoint = Vector2.new(point.X - inset.X, point.Y - inset.Y)
	for _, frame in ipairs(chestSlots:GetChildren()) do
		if frame:IsA("Frame") and tonumber(frame:GetAttribute("ChestIndex")) then
			local pos = frame.AbsolutePosition
			local size = frame.AbsoluteSize
			if adjustedPoint.X >= pos.X and adjustedPoint.X <= pos.X + size.X and adjustedPoint.Y >= pos.Y and adjustedPoint.Y <= pos.Y + size.Y then
				return frame
			end
		end
	end
	return nil
end

local function endDragToChest(chestFrame)
	if not dragging.Active then return end

	local from = dragging.From
	cancelDrag()
	if not from or not chestFrame or not rChest then return end
	local chestId = gui:GetAttribute("ChestId")
	if type(chestId) ~= "string" or chestId == "" then return end

	local toIndex = tonumber(chestFrame:GetAttribute("ChestIndex"))
	if not toIndex then return end
	local data = getSlotData(from.Type, from.Index)
	if not data then return end

	rChest:FireServer("Put", {
		ChestId = chestId,
		FromType = from.Type,
		FromIndex = from.Index,
		ToIndex = toIndex,
		Amount = data.N,
	})
	showTransferStatus("Moved to chest", COLORS.Accent, 0.9)
end

local function slotAtPoint(point, touch)
	-- Mouse location includes the top inset; touch InputObject positions already
	-- share the slot AbsolutePosition coordinate space.
	local inset = GuiService:GetGuiInset()
	if touch then inset = Vector2.zero end
	local adjustedPoint = Vector2.new(point.X - inset.X, point.Y - inset.Y)
	
	for _, slot in ipairs(slots) do
		if not (slot.Frame:IsDescendantOf(mainContainer) and not mainContainer.Visible) then
			local pos = slot.Frame.AbsolutePosition
			local size = slot.Frame.AbsoluteSize
			if adjustedPoint.X >= pos.X and adjustedPoint.X <= pos.X + size.X and adjustedPoint.Y >= pos.Y and adjustedPoint.Y <= pos.Y + size.Y then
				return slot
			end
		end
	end
	return nil
end

-- Input handling
UserInputService.InputChanged:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseMovement and not (dragging.Input and dragging.Input.UserInputType == Enum.UserInputType.Touch))
		or input == dragging.Input then
		if tooltip.Visible then
			itemTooltip:Move()
		end
		
		if dragging.Pending and dragging.StartPos then
			local delta = (input.Position - dragging.StartPos)
			if delta.Magnitude >= DRAG_THRESHOLD and dragging.From then
				beginDrag(dragging.From)
			end
		end
		
		if dragging.Active and dragging.Ghost then
			local gSize = dragging.Ghost.AbsoluteSize
			dragging.Ghost.Position = UDim2.fromOffset(
				input.Position.X - gSize.X / 2,
				input.Position.Y - gSize.Y / 2
			)
		end
		positionSplitGhost(Vector2.new(input.Position.X, input.Position.Y))
	end
end)

UserInputService.InputEnded:Connect(function(input)
	local touch = input.UserInputType == Enum.UserInputType.Touch
	if ((touch and input == dragging.Input) or (input.UserInputType == Enum.UserInputType.MouseButton1 and dragging.Input and dragging.Input.UserInputType == Enum.UserInputType.MouseButton1)) and (dragging.Active or dragging.Pending) then
		local mouseLocation = touch and Vector2.new(input.Position.X, input.Position.Y) or UserInputService:GetMouseLocation()
		local target = slotAtPoint(mouseLocation, touch)
		if dragging.Active then
			if target then
				endDrag(target)
			else
				local chestTarget = chestSlotFrameAtPoint(mouseLocation, touch)
				if chestTarget then
					endDragToChest(chestTarget)
				else
					local chestGui = playerGui:FindFirstChild("ChestUI")
					local chestPanel = chestGui and chestGui:FindFirstChild("ChestPanel")
					local outside = mainContainer.Visible
						and not isPointInsideGui(mainContainer, mouseLocation, touch)
						and not isPointInsideGui(hotbarRoot, mouseLocation, touch)
						and not isPointInsideGui(chestPanel, mouseLocation, touch)
					endDrag(nil, outside)
				end
			end
		elseif dragging.Pending and dragging.From then
			local fromSlot = dragging.From
			if touch and target ~= fromSlot then cancelDrag(); return end
			if touch and isChestTransferLockActive() then
				shiftMove(fromSlot, true)
				cancelDrag()
				return
			end
			if touch and fromSlot.Type ~= "Hotbar" and getSlotData(fromSlot.Type, fromSlot.Index) then
				showContextMenu(fromSlot, mouseLocation, true)
				cancelDrag()
				return
			end
			-- Only send Equip for Hotbar slots (empty or filled)
			if rInventoryAction and fromSlot.Type == "Hotbar" then
				selectedSlot = nil
				renderAll()
				rInventoryAction:FireServer("Equip", {
					SlotType = fromSlot.Type,
					SlotIndex = fromSlot.Index,
				})
			else
				selectedSlot = fromSlot
				renderAll()
			end
			cancelDrag()
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.Escape and splitCursor.From then
		clearSplitCursor()
		return
	end
	if input.KeyCode == Enum.KeyCode.Q and mainContainer.Visible and hoveredSlot and Settings.CanInput() and not player:GetAttribute("IsDead") then
		if splitCursor.From then clearSplitCursor(); return end
		local data = getSlotData(hoveredSlot.Type, hoveredSlot.Index)
		if data and rDrop then
			local whole = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
			rDrop:FireServer({SlotType=hoveredSlot.Type, SlotIndex=hoveredSlot.Index, Amount=whole and data.N or 1, ExpectedId=data.Id})
		end
		return
	end
	if Settings.Matches(input, "Pack") and not inventoryToggleActionBound then
		if not Settings.CanInput() then return end
		if isChestTransferLockActive() then return end
		setInventoryOpen(not inventoryOpen)
		return
	end
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		-- Hide context menu when clicking elsewhere
		if contextMenu.Visible and not isPointInsideGui(contextMenu, input.Position) then
			hideContextMenu()
		end
	end
end)

-- Slot interactions
for _, slot in ipairs(slots) do
	slot.Button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			if splitCursor.From then placeSplitCursor(slot, 1)
			else beginSplitCursor(slot) end
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if input.UserInputType == Enum.UserInputType.MouseButton1 and splitCursor.From then
				placeSplitCursor(slot, splitCursor.Remaining)
				return
			end
			if dragging.Pending or dragging.Active then return end
			hideContextMenu()
			if isShiftDown() then
				shiftMove(slot)
				return
			end
			dragging.Pending = true
			dragging.Active = false
			dragging.From = slot
			dragging.StartPos = input.Position
			dragging.Input = input
		end
	end)
	
	slot.Button.MouseEnter:Connect(function()
		hoveredSlot = slot
		setSlotHovered(slot, true)
		local data = getSlotData(slot.Type, slot.Index)
		if data then
			showTooltip(slot, data)
		end
	end)
	
	slot.Button.MouseLeave:Connect(function()
		if hoveredSlot == slot then
			hoveredSlot = nil
		end
		setSlotHovered(slot, false)
		hideTooltip()
	end)
end

-- Hotbar keybinds (1-6)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local keyNum = nil
	if input.KeyCode == Enum.KeyCode.One then keyNum = 1
	elseif input.KeyCode == Enum.KeyCode.Two then keyNum = 2
	elseif input.KeyCode == Enum.KeyCode.Three then keyNum = 3
	elseif input.KeyCode == Enum.KeyCode.Four then keyNum = 4
	elseif input.KeyCode == Enum.KeyCode.Five then keyNum = 5
	elseif input.KeyCode == Enum.KeyCode.Six then keyNum = 6
	end
	if keyNum and rInventoryAction then
		selectedSlot = nil
		renderAll()
		rInventoryAction:FireServer("Equip", {
			SlotType = "Hotbar",
			SlotIndex = keyNum,
		})
	end
end)

-- Remote event handling
if rInventory then
	rInventory.OnClientEvent:Connect(function(kind, payload)
		if kind ~= "Snapshot" or type(payload) ~= "table" then return end
		
		-- FIXED: Server now sends false for empty slots to preserve array structure
		-- Convert false back to nil for consistent local handling
		if payload.Storage then
			local normalized = {}
			for i = 1, STORAGE_COLS * STORAGE_ROWS do -- STORAGE_SLOTS
				local slot = payload.Storage[i]
				-- Treat false as nil (empty slot)
				if slot and slot ~= false and type(slot) == "table" then
					normalized[i] = slot
				else
					normalized[i] = nil
				end
			end
			payload.Storage = normalized
		end
		if payload.Hotbar then
			local normalized = {}
			for i = 1, HOTBAR_SLOTS do
				local slot = payload.Hotbar[i]
				-- Treat false as nil (empty slot)
				if slot and slot ~= false and type(slot) == "table" then
					normalized[i] = slot
				else
					normalized[i] = nil
				end
			end
			payload.Hotbar = normalized
		end
		-- Handle Armor (can be false for empty)
		if payload.Armor == false then
			payload.Armor = nil
		end
		
		inventorySnapshot = payload
		
		-- Debug: Log storage contents
		dprint("[InventoryUI] Snapshot received:")
		if payload.Storage then
			for i = 1, STORAGE_COLS * STORAGE_ROWS do
				local slot = payload.Storage[i]
				if slot then
					dprint(string.format("  Storage[%d]: %s x%d", i, slot.Id, slot.N))
				end
			end
		end
		if payload.Hotbar then
			for i = 1, HOTBAR_SLOTS do
				local slot = payload.Hotbar[i]
				if slot then
					dprint(string.format("  Hotbar[%d]: %s x%d", i, slot.Id, slot.N))
				end
			end
		end
		
		renderAll()
	end)
	task.defer(function()
		pcall(function()
			rInventory:FireServer("RequestSnapshot")
		end)
	end)
end

dprint("[InventoryUI] Polished inventory ready")

if player.Character then
	bindCharacter(player.Character)
else
	syncEquippedToolName()
end
player.CharacterAdded:Connect(bindCharacter)

-- Paper pack and shared field-kit navigation.
Theme.Panel(mainContainer)
local packScale = Instance.new("UIScale")
packScale.Name, packScale.Parent = "ViewportScale", mainContainer
Theme.CaptureCursor(mainContainer); Theme.AnimatePanel(mainContainer)
Theme.Panel(hotbarPanel)
local hotbarScale = Instance.new("UIScale")
hotbarScale.Name, hotbarScale.Parent = "ViewportScale", hotbarRoot
shadow.Visible = false
local armorHelp = Theme.Label(armorSection, "Weather protection goes here.\nDrag armor into the equipment slot.", UDim2.fromOffset(280, 42), UDim2.fromOffset(80, 27), 14, COLORS.TextMuted)
local closePack = Instance.new("TextButton")
closePack.Name = "ClosePack"
closePack.Size = UDim2.fromOffset(28, 28)
closePack.Position = UDim2.new(1, -44, 0, 8)
closePack.Text = "X"
closePack.TextSize = 12
closePack.Font = Enum.Font.GothamBold
closePack.Parent = header
Theme.Button(closePack, false)
closePack.Activated:Connect(function() setInventoryOpen(false) end)
player:GetAttributeChangedSignal("FieldKitPack"):Connect(function() setInventoryOpen(not inventoryOpen) end)
local function arrangePack()
 local camera = workspace.CurrentCamera
 if not camera then return end
 local mobile = Theme.IsMobile()
 local viewport = camera.ViewportSize
 local topInset, bottomInset = GuiService:GetGuiInset()
 local width, height = viewport.X - topInset.X - bottomInset.X, viewport.Y - topInset.Y - bottomInset.Y
 local chestOpen = gui:GetAttribute("ChestOpen") == true
 hotbarRoot.Visible = not mobile or (playerGui:GetAttribute("MenuCursorOpen") ~= true or mainContainer.Visible or chestOpen)
 local portrait = mobile and width < height
 local widePack = mobile and not portrait and not chestOpen
 local columns = widePack and 9 or STORAGE_COLS
 local packWidth = columns * SLOT_SIZE + (columns - 1) * SLOT_GAP + MARGIN * 2
 local packHeight = mobile and (widePack and 224 or 292) or MAIN_HEIGHT
 local chestHeight = tonumber(gui:GetAttribute("ChestLayoutHeight")) or 200
 local maxScale = mobile and 1.65 or 2.5
	hotbarScale.Scale = math.min(mobile and 0.8 or 1.5, (width - 64) / 422)
 -- Keep the last storage row above the hotbar, including short PC windows.
 local bottomReserve = mobile and (portrait and 192 or 96) or (18 + (HOTBAR_SLOT_SIZE + 12) * hotbarScale.Scale + 24)
 local availableHeight = math.max(120, height - bottomReserve)
 hotbarRoot.BackgroundTransparency = 1
 hotbarRoot.BorderSizePixel = 0
 hotbarPanel.BackgroundTransparency = mobile and .48 or .04
 hotbarRoot.Position = UDim2.new(0.5, 0, 1, mobile and (portrait and -104 or -8) or -18)
 local totalWidth = chestOpen and not portrait and (packWidth + 382 + 24) or packWidth
 local totalHeight = chestOpen and (portrait and (packHeight + chestHeight + 12) or math.max(packHeight, chestHeight)) or packHeight
 local scale = math.min(maxScale, (width - 24) / totalWidth, availableHeight / totalHeight)
 packScale.Scale = scale
 packScale:SetAttribute("TargetScale", scale)
 mainContainer.Size = UDim2.fromOffset(packWidth, packHeight)
 mainContainer.AnchorPoint = Vector2.new(0.5, 0.5)
 local centerY = availableHeight * 0.5 + 8
 local x = width * 0.5 + (chestOpen and not portrait and (382 + 24) * scale * 0.5 or 0)
 local y = centerY + (chestOpen and portrait and (chestHeight + 12) * scale * 0.5 or 0)
 mainContainer.Position = UDim2.fromOffset(x, y)
 closePack.Visible = not chestOpen
 local closeSize = mobile and 44 / scale or 40
 closePack.Size = UDim2.fromOffset(closeSize, closeSize)
 closePack.Position = UDim2.new(1, -closeSize - 8, 0, 5)
 titleLabel.TextSize = mobile and 22 or 20
 titleLabel.Size = UDim2.fromOffset(mobile and 200 or 230, 44)
 capacityLabel.Visible = not mobile
 armorLabel.Visible = not mobile
 armorHelp.Visible = not mobile
 armorSection.Position = mobile and UDim2.fromOffset(258, 4) or UDim2.fromOffset(MARGIN, HEADER_HEIGHT)
 armorSection.Size = mobile and UDim2.fromOffset(130, 64) or UDim2.new(1, -MARGIN * 2, 0, ARMOR_SECTION_HEIGHT)
 armorContainer.Position = UDim2.fromOffset(0, mobile and 0 or 16)
 armorSlot.Frame.Size = UDim2.fromOffset(mobile and 56 or SLOT_SIZE, mobile and 56 or SLOT_SIZE)
 storageSection.Position = UDim2.fromOffset(MARGIN, mobile and 68 or HEADER_HEIGHT + ARMOR_SECTION_HEIGHT + 8)
 storageLabel.Text = mobile and (chestOpen and "TAP TO STORE · DRAG TO ARRANGE" or "TAP FOR ACTIONS · DRAG TO ARRANGE") or "STORAGE"
 storageLabel.TextSize = mobile and 13 or 12
 transferStatusLabel.Size = UDim2.fromOffset(mobile and 236 or 240, 18)
 transferStatusLabel.Position = mobile and UDim2.new(0, MARGIN, 0, 63) or UDim2.new(1, -MARGIN, 1, -4)
 transferStatusLabel.AnchorPoint = mobile and Vector2.new(0, 1) or Vector2.new(1, 1)
 transferStatusLabel.TextSize = mobile and 14 or 12
 transferStatusLabel.TextXAlignment = mobile and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
 for _, slot in ipairs(slots) do
  local slotScale = slot.Type == "Hotbar" and hotbarScale.Scale or scale
  slot.Frame.BackgroundTransparency = mobile and slot.Type == "Hotbar" and not mainContainer.Visible and .4 or 0
  slot.ItemText.TextSize = mobile and 12 / slotScale or 12
  slot.QtyLabel.TextSize = mobile and 12 / slotScale or 12
  if mobile then
   slot.QtyBadge.Size = UDim2.fromOffset(30 / slotScale, 16 / slotScale)
   slot.QtyBadge.Position = UDim2.new(1, -32 / slotScale, 1, -18 / slotScale)
  else
   slot.QtyBadge.Size = UDim2.fromOffset(26, 14)
   slot.QtyBadge.Position = UDim2.new(1, -28, 1, -16)
  end
  slot.ItemText.Size = UDim2.new(1, -8, 0, mobile and 26 / slotScale or 32)
  slot.ItemText.Position = mobile and UDim2.new(0.5, 0, 0, 2 / slotScale) or UDim2.new(0.5, 0, 0.5, -2)
  slot.ItemText.AnchorPoint = mobile and Vector2.new(0.5, 0) or Vector2.new(0.5, 0.5)
  local keybind = slot.Frame:FindFirstChild("Keybind")
  if keybind then keybind.Visible = not mobile end
  if slot.Type == "Storage" then
   local index = slot.Index - 1
   slot.Frame.Position = UDim2.fromOffset((index % columns) * (SLOT_SIZE + SLOT_GAP), math.floor(index / columns) * (SLOT_SIZE + SLOT_GAP))
  end
 end
 contextMenu.Size = UDim2.fromOffset(mobile and 180 or 140, mobile and 196 or 136)
 for index, button in ipairs({contextUse, contextDrop, contextSplit, contextPlace}) do
  button.Size = UDim2.new(1, -8, 0, mobile and 44 or 28)
  button.Position = UDim2.fromOffset(4, 4 + (index - 1) * (mobile and 48 or 32))
  button.TextSize = mobile and 17 or 14
 end
 renderAll()
end
gui:GetAttributeChangedSignal("ChestOpen"):Connect(arrangePack)
gui:GetAttributeChangedSignal("ChestLayoutHeight"):Connect(arrangePack)
playerGui:GetAttributeChangedSignal("MenuCursorOpen"):Connect(arrangePack)
playerGui:GetAttributeChangedSignal("BuildPlacementActive"):Connect(arrangePack)
mainContainer:GetPropertyChangedSignal("Visible"):Connect(arrangePack)
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(arrangePack)
local packViewportConnection
local function bindPackViewport()
 if packViewportConnection then packViewportConnection:Disconnect() end
 if workspace.CurrentCamera then packViewportConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(arrangePack) end
 arrangePack()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindPackViewport)
bindPackViewport()
for _, button in ipairs({ contextUse, contextDrop, contextSplit, contextPlace }) do Theme.Button(button) end

Settings.Changed:Connect(bindInventoryToggleAction)
