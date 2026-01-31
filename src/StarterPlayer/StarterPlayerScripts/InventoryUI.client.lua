-- InventoryUI.client.lua
-- Polished inventory system with modern UI
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
local rInventory = Util.GetRemote(remotesFolder, Config.RemoteNames.InventoryUpdate)
local rInventoryAction = Util.GetRemote(remotesFolder, Config.RemoteNames.InventoryAction)
local rDrop = Util.GetRemote(remotesFolder, Config.RemoteNames.DropItem)

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
	Warning = Color3.fromRGB(255, 180, 80),
	Danger = Color3.fromRGB(220, 80, 80),
}

local SLOT_SIZE = 64
local SLOT_GAP = 6
local HOTBAR_SLOTS = 4
local STORAGE_COLS = 5
local STORAGE_ROWS = 2
local MARGIN = 16

-- Create main GUI
local gui = Instance.new("ScreenGui")
gui.Name = "InventoryUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Main container
local mainContainer = Instance.new("Frame")
mainContainer.Name = "MainContainer"
mainContainer.Size = UDim2.new(0, (SLOT_SIZE + SLOT_GAP) * STORAGE_COLS + MARGIN * 2, 0, 290)
mainContainer.AnchorPoint = Vector2.new(1, 1)
mainContainer.Position = UDim2.new(1, -20, 1, -20)
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
titleLabel.Size = UDim2.new(0, 150, 1, 0)
titleLabel.Position = UDim2.new(0, MARGIN, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "⚔️ Inventory"
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
capacityLabel.Position = UDim2.new(1, -MARGIN, 0.5, 0)
capacityLabel.BackgroundTransparency = 1
capacityLabel.Text = "0/14"
capacityLabel.TextColor3 = COLORS.TextMuted
capacityLabel.TextSize = 12
capacityLabel.Font = Enum.Font.Gotham
capacityLabel.TextXAlignment = Enum.TextXAlignment.Right
capacityLabel.Parent = header

-- Hotbar section
local hotbarSection = Instance.new("Frame")
hotbarSection.Name = "HotbarSection"
hotbarSection.Size = UDim2.new(1, -MARGIN * 2, 0, SLOT_SIZE + 22)
hotbarSection.Position = UDim2.new(0, MARGIN, 0, 44)
hotbarSection.BackgroundTransparency = 1
hotbarSection.Parent = mainContainer

local hotbarLabel = Instance.new("TextLabel")
hotbarLabel.Size = UDim2.new(1, 0, 0, 14)
hotbarLabel.BackgroundTransparency = 1
hotbarLabel.Text = "HOTBAR"
hotbarLabel.TextColor3 = COLORS.TextMuted
hotbarLabel.TextSize = 10
hotbarLabel.Font = Enum.Font.GothamBold
hotbarLabel.TextXAlignment = Enum.TextXAlignment.Left
hotbarLabel.Parent = hotbarSection

local hotbarContainer = Instance.new("Frame")
hotbarContainer.Name = "Slots"
hotbarContainer.Size = UDim2.new(1, 0, 0, SLOT_SIZE)
hotbarContainer.Position = UDim2.new(0, 0, 0, 16)
hotbarContainer.BackgroundTransparency = 1
hotbarContainer.Parent = hotbarSection

-- Storage section
local storageSection = Instance.new("Frame")
storageSection.Name = "StorageSection"
storageSection.Size = UDim2.new(1, -MARGIN * 2, 0, SLOT_SIZE * STORAGE_ROWS + SLOT_GAP + 22)
storageSection.Position = UDim2.new(0, MARGIN, 0, 44 + SLOT_SIZE + 32)
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
storageContainer.Size = UDim2.new(1, 0, 0, SLOT_SIZE * STORAGE_ROWS + SLOT_GAP)
storageContainer.Position = UDim2.new(0, 0, 0, 16)
storageContainer.BackgroundTransparency = 1
storageContainer.Parent = storageSection

-- Tooltip
local tooltip = Instance.new("Frame")
tooltip.Name = "Tooltip"
tooltip.Size = UDim2.new(0, 180, 0, 90)
tooltip.BackgroundColor3 = COLORS.Background
tooltip.BackgroundTransparency = 0.05
tooltip.BorderSizePixel = 0
tooltip.Visible = false
tooltip.ZIndex = 100
tooltip.Parent = gui

local tooltipCorner = Instance.new("UICorner")
tooltipCorner.CornerRadius = UDim.new(0, 8)
tooltipCorner.Parent = tooltip

local tooltipStroke = Instance.new("UIStroke")
tooltipStroke.Color = COLORS.Border
tooltipStroke.Thickness = 1
tooltipStroke.Parent = tooltip

local tooltipName = Instance.new("TextLabel")
tooltipName.Name = "ItemName"
tooltipName.Size = UDim2.new(1, -16, 0, 22)
tooltipName.Position = UDim2.new(0, 8, 0, 8)
tooltipName.BackgroundTransparency = 1
tooltipName.TextColor3 = COLORS.Text
tooltipName.TextSize = 14
tooltipName.Font = Enum.Font.GothamBold
tooltipName.TextXAlignment = Enum.TextXAlignment.Left
tooltipName.Text = "Item Name"
tooltipName.ZIndex = 101
tooltipName.Parent = tooltip

local tooltipTags = Instance.new("TextLabel")
tooltipTags.Name = "Tags"
tooltipTags.Size = UDim2.new(1, -16, 0, 16)
tooltipTags.Position = UDim2.new(0, 8, 0, 30)
tooltipTags.BackgroundTransparency = 1
tooltipTags.TextColor3 = COLORS.Accent
tooltipTags.TextSize = 11
tooltipTags.Font = Enum.Font.Gotham
tooltipTags.TextXAlignment = Enum.TextXAlignment.Left
tooltipTags.Text = "Resource • Organic"
tooltipTags.ZIndex = 101
tooltipTags.Parent = tooltip

local tooltipQty = Instance.new("TextLabel")
tooltipQty.Name = "Quantity"
tooltipQty.Size = UDim2.new(1, -16, 0, 16)
tooltipQty.Position = UDim2.new(0, 8, 0, 50)
tooltipQty.BackgroundTransparency = 1
tooltipQty.TextColor3 = COLORS.TextMuted
tooltipQty.TextSize = 11
tooltipQty.Font = Enum.Font.Gotham
tooltipQty.TextXAlignment = Enum.TextXAlignment.Left
tooltipQty.Text = "Quantity: 1"
tooltipQty.ZIndex = 101
tooltipQty.Parent = tooltip

local tooltipHint = Instance.new("TextLabel")
tooltipHint.Name = "Hint"
tooltipHint.Size = UDim2.new(1, -16, 0, 14)
tooltipHint.Position = UDim2.new(0, 8, 0, 68)
tooltipHint.BackgroundTransparency = 1
tooltipHint.TextColor3 = Color3.fromRGB(120, 120, 130)
tooltipHint.TextSize = 10
tooltipHint.Font = Enum.Font.Gotham
tooltipHint.TextXAlignment = Enum.TextXAlignment.Left
tooltipHint.Text = "Click to select • Drag to move"
tooltipHint.ZIndex = 101
tooltipHint.Parent = tooltip

-- Slot creation helper
local function createSlot(parent, x, y, slotType, index)
	local slot = Instance.new("Frame")
	slot.Name = slotType .. "_" .. index
	slot:SetAttribute("SlotType", slotType)
	slot:SetAttribute("SlotIndex", index)
	slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
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
	icon.Size = UDim2.new(0, 40, 0, 40)
	icon.Position = UDim2.new(0.5, 0, 0.5, -4)
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
	itemText.TextWrapped = true
	itemText.Text = ""
	itemText.Visible = false
	itemText.ZIndex = 3
	itemText.Parent = slot

	-- Quantity badge
	local qtyBadge = Instance.new("Frame")
	qtyBadge.Name = "QtyBadge"
	qtyBadge.Size = UDim2.new(0, 24, 0, 14)
	qtyBadge.Position = UDim2.new(1, -26, 1, -16)
	qtyBadge.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
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
		keybind.Size = UDim2.new(0, 16, 0, 16)
		keybind.Position = UDim2.new(0, 4, 0, 4)
		keybind.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
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
		armorBadge.TextColor3 = COLORS.Text
		armorBadge.TextSize = 9
		armorBadge.Font = Enum.Font.GothamBold
		armorBadge.Text = "🛡️"
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
	local x = (i - 1) * (SLOT_SIZE + SLOT_GAP)
	local slot = createSlot(hotbarContainer, x, 0, "Hotbar", i)
	table.insert(slots, slot)
end

-- Armor slot (next to hotbar)
local armorSlot = createSlot(hotbarContainer, (SLOT_SIZE + SLOT_GAP) * HOTBAR_SLOTS + SLOT_GAP * 2, 0, "Armor", 1)
table.insert(slots, armorSlot)

-- Storage slots
for i = 1, STORAGE_COLS * STORAGE_ROWS do
	local row = math.floor((i - 1) / STORAGE_COLS)
	local col = (i - 1) % STORAGE_COLS
	local x = col * (SLOT_SIZE + SLOT_GAP)
	local y = row * (SLOT_SIZE + SLOT_GAP)
	local slot = createSlot(storageContainer, x, y, "Storage", i)
	table.insert(slots, slot)
end

-- State
local inventorySnapshot = nil
local selectedSlot = nil
local hoveredSlot = nil

-- Helper functions
local function hashColor(id)
	local hash = 0
	for i = 1, #id do
		hash = (hash * 33 + string.byte(id, i)) % 360
	end
	return Color3.fromHSV(hash / 360, 0.55, 0.85)
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
	if not data then return end
	local item = ItemDatabase:Get(data.Id)
	local name = item and item.Name or data.Id
	local tags = item and item.Tags or {}
	
	tooltipName.Text = name
	tooltipTags.Text = #tags > 0 and table.concat(tags, " • ") or "Unknown"
	tooltipQty.Text = "Quantity: " .. tostring(data.N)
	
	local mousePos = UserInputService:GetMouseLocation()
	tooltip.Position = UDim2.fromOffset(mousePos.X + 15, mousePos.Y + 15)
	tooltip.Visible = true
end

local function hideTooltip()
	tooltip.Visible = false
end

local function setSlotSelected(slot, selected)
	if selected then
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
	
	if not data then
		slot.Icon.Image = ""
		slot.Icon.Visible = false
		slot.ItemText.Visible = false
		slot.ItemText.Text = ""
		slot.QtyBadge.Visible = false
		slot.Frame.BackgroundColor3 = COLORS.SlotEmpty
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
		slot.ItemText.Text = name
		slot.ItemText.TextColor3 = iconColor or hashColor(data.Id)
		slot.ItemText.Visible = true
	end
	
	if data.N > 1 then
		slot.QtyBadge.Visible = true
		slot.QtyLabel.Text = tostring(data.N)
	else
		slot.QtyBadge.Visible = false
	end
	
	slot.Frame.BackgroundColor3 = COLORS.SlotFilled
end

local function renderAll()
	for _, slot in ipairs(slots) do
		renderSlot(slot)
		setSlotSelected(slot, selectedSlot == slot)
	end
	updateCapacity()
end

-- Drag and drop
local DRAG_THRESHOLD = 6
local dragging = { Active = false, Pending = false, From = nil, Ghost = nil, StartPos = nil }

local function createDragGhost(slot, data)
	local ghost = Instance.new("Frame")
	ghost.Name = "DragGhost"
	ghost.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	ghost.BackgroundColor3 = COLORS.SlotSelected
	ghost.BackgroundTransparency = 0.3
	ghost.BorderSizePixel = 0
	ghost.ZIndex = 50
	ghost.Parent = gui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = ghost
	
	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, 40, 0, 40)
	icon.Position = UDim2.new(0.5, 0, 0.5, 0)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.ZIndex = 51
	icon.Parent = ghost
	
	local item = ItemDatabase:Get(data.Id)
	local itemIcon = item and item.Icon
	local iconColor = item and item.IconColor
	if itemIcon and itemIcon ~= "" then
		icon.Image = itemIcon
		icon.ImageColor3 = Color3.new(1, 1, 1)
	else
		local placeholder = (Config.UI and Config.UI.PlaceholderIcon) or ""
		icon.Image = placeholder
		icon.ImageColor3 = iconColor or hashColor(data.Id)
	end
	
	return ghost
end

local function beginDrag(slot)
	local data = getSlotData(slot.Type, slot.Index)
	if not data then return end
	
	selectedSlot = slot
	dragging.Active = true
	dragging.Pending = false
	dragging.From = slot
	dragging.Ghost = createDragGhost(slot, data)
	
	slot.Frame.BackgroundTransparency = 0.5
end

local function endDrag(targetSlot)
	if not dragging.Active then return end
	
	if dragging.From then
		dragging.From.Frame.BackgroundTransparency = 0
	end
	
	if dragging.Ghost then
		dragging.Ghost:Destroy()
	end
	
	local from = dragging.From
	dragging.Active = false
	dragging.From = nil
	dragging.Ghost = nil
	
	if not targetSlot or targetSlot == from then return end
	if not rInventoryAction then return end
	
	rInventoryAction:FireServer("Move", {
		FromType = from.Type,
		FromIndex = from.Index,
		ToType = targetSlot.Type,
		ToIndex = targetSlot.Index,
	})
end

local function slotAtPoint(point)
	-- GetMouseLocation includes GUI inset, AbsolutePosition doesn't
	-- Subtract the inset to align coordinate systems
	local inset = GuiService:GetGuiInset()
	local adjustedPoint = Vector2.new(point.X - inset.X, point.Y - inset.Y)
	
	for _, slot in ipairs(slots) do
		local pos = slot.Frame.AbsolutePosition
		local size = slot.Frame.AbsoluteSize
		if adjustedPoint.X >= pos.X and adjustedPoint.X <= pos.X + size.X and adjustedPoint.Y >= pos.Y and adjustedPoint.Y <= pos.Y + size.Y then
			return slot
		end
	end
	return nil
end

-- Input handling
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		if tooltip.Visible then
			tooltip.Position = UDim2.fromOffset(input.Position.X + 15, input.Position.Y + 15)
		end
		
		if dragging.Pending and dragging.StartPos then
			local delta = (input.Position - dragging.StartPos)
			if delta.Magnitude >= DRAG_THRESHOLD and dragging.From then
				beginDrag(dragging.From)
			end
		end
		
		if dragging.Active and dragging.Ghost then
			dragging.Ghost.Position = UDim2.fromOffset(
				input.Position.X - SLOT_SIZE / 2,
				input.Position.Y - SLOT_SIZE / 2
			)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and (dragging.Active or dragging.Pending) then
		local target = slotAtPoint(UserInputService:GetMouseLocation())
		if dragging.Active then
			endDrag(target)
		elseif dragging.Pending and dragging.From then
			selectedSlot = dragging.From
			renderAll()
			-- Only send Equip for Hotbar slots (empty or filled)
			if rInventoryAction and dragging.From.Type == "Hotbar" then
				rInventoryAction:FireServer("Equip", {
					SlotType = dragging.From.Type,
					SlotIndex = dragging.From.Index,
				})
			end
		end
		dragging.Active = false
		dragging.Pending = false
		dragging.From = nil
		dragging.StartPos = nil
	end
end)

-- Slot interactions
for _, slot in ipairs(slots) do
	slot.Button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging.Pending = true
			dragging.Active = false
			dragging.From = slot
			dragging.StartPos = input.Position
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

-- Hotbar keybinds (1-4)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local keyNum = nil
	if input.KeyCode == Enum.KeyCode.One then keyNum = 1
	elseif input.KeyCode == Enum.KeyCode.Two then keyNum = 2
	elseif input.KeyCode == Enum.KeyCode.Three then keyNum = 3
	elseif input.KeyCode == Enum.KeyCode.Four then keyNum = 4
	end
	if keyNum and rInventoryAction then
		rInventoryAction:FireServer("Equip", {
			SlotType = "Hotbar",
			SlotIndex = keyNum,
		})
		for _, slot in ipairs(slots) do
			if slot.Type == "Hotbar" and slot.Index == keyNum then
				selectedSlot = slot
				renderAll()
				break
			end
		end
	end
end)

-- Remote event handling
if rInventory then
	rInventory.OnClientEvent:Connect(function(kind, payload)
		if kind ~= "Snapshot" or type(payload) ~= "table" then return end
		
		-- Fix: Roblox RemoteEvents can convert numeric keys to strings
		-- Normalize keys to be numeric for consistent indexing
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
		
		-- Debug: Log storage contents
		print("[InventoryUI] Snapshot received:")
		if payload.Storage then
			for i, slot in pairs(payload.Storage) do
				if slot then
					print(string.format("  Storage[%d]: %s x%d", i, slot.Id, slot.N))
				end
			end
		end
		if payload.Hotbar then
			for i, slot in pairs(payload.Hotbar) do
				if slot then
					print(string.format("  Hotbar[%d]: %s x%d", i, slot.Id, slot.N))
				end
			end
		end
		
		renderAll()
	end)
end

print("[InventoryUI] Polished inventory ready")
