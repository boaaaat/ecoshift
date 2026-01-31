-- InventoryUI.client.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
local rInventory = Util.GetRemote(remotesFolder, Config.RemoteNames.InventoryUpdate)
local rInventoryAction = Util.GetRemote(remotesFolder, Config.RemoteNames.InventoryAction)
local rDrop = Util.GetRemote(remotesFolder, Config.RemoteNames.DropItem)

local gui = Instance.new("ScreenGui")
gui.Name = "InventoryUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local panel = Instance.new("Frame")
local SLOT_W, SLOT_H = 70, 40
local GAP_X, GAP_Y = 8, 8
local MARGIN_X, MARGIN_Y = 10, 10
local TITLE_Y = 6
local TITLE_H = 22
local HOTBAR_Y = TITLE_Y + TITLE_H + 6
local STORAGE_Y = HOTBAR_Y + SLOT_H + GAP_Y
local STORAGE_COLS = 5
local STORAGE_ROWS = 2
local PANEL_W = MARGIN_X * 2 + (SLOT_W * STORAGE_COLS) + (GAP_X * (STORAGE_COLS - 1))
local PANEL_H = STORAGE_Y + (SLOT_H * STORAGE_ROWS) + (GAP_Y * (STORAGE_ROWS - 1)) + MARGIN_Y

panel.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -16, 1, -16)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 0
panel.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -12, 0, 22)
title.Position = UDim2.new(0, MARGIN_X, 0, TITLE_Y)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(235, 235, 235)
title.Text = "Inventory"
title.Parent = panel

local dropButton = Instance.new("TextButton")
dropButton.Size = UDim2.new(0, 70, 0, 22)
dropButton.AnchorPoint = Vector2.new(1, 0)
dropButton.Position = UDim2.new(1, -MARGIN_X, 0, TITLE_Y)
dropButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
dropButton.BorderSizePixel = 0
dropButton.Font = Enum.Font.GothamBold
dropButton.TextSize = 12
dropButton.TextColor3 = Color3.fromRGB(230, 230, 230)
dropButton.Text = "Drop"
dropButton.Parent = panel

local function makeSlot(parent, x, y)
	local slot = Instance.new("Frame")
	slot.Size = UDim2.new(0, SLOT_W, 0, SLOT_H)
	slot.Position = UDim2.new(0, x, 0, y)
	slot.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	slot.BorderSizePixel = 0
	slot.Parent = parent

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, 28, 0, 28)
	icon.Position = UDim2.new(0, 6, 0, 6)
	icon.BackgroundTransparency = 1
	icon.Image = ""
	icon.Parent = slot

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -40, 1, -6)
	text.Position = UDim2.new(0, 38, 0, 3)
	text.BackgroundTransparency = 1
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.Font = Enum.Font.Gotham
	text.TextSize = 12
	text.TextColor3 = Color3.fromRGB(220, 220, 220)
	text.Text = ""
	text.Parent = slot

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 1, 0)
	button.Position = UDim2.new(0, 0, 0, 0)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = slot

	return slot, icon, text, button
end

local slots = {}
local function registerSlot(slotType, index, frame, icon, label, button)
	slots[#slots + 1] = {
		Type = slotType,
		Index = index,
		Frame = frame,
		Icon = icon,
		Label = label,
		Button = button,
	}
end

local hotbarY = HOTBAR_Y
for i = 1, 4 do
	local frame, icon, label, button = makeSlot(panel, MARGIN_X + (i - 1) * (SLOT_W + GAP_X), hotbarY)
	registerSlot("Hotbar", i, frame, icon, label, button)
end

local storageY = STORAGE_Y
for i = 1, 10 do
	local row = math.floor((i - 1) / 5)
	local col = (i - 1) % 5
	local frame, icon, label, button = makeSlot(panel, MARGIN_X + col * (SLOT_W + GAP_X), storageY + row * (SLOT_H + GAP_Y))
	registerSlot("Storage", i, frame, icon, label, button)
end

local armorFrame, armorIcon, armorLabel, armorButton = makeSlot(panel, MARGIN_X + 4 * (SLOT_W + GAP_X), hotbarY)
registerSlot("Armor", 1, armorFrame, armorIcon, armorLabel, armorButton)
armorLabel.Text = "Armor"

local inventorySnapshot = nil
local selectedSlot = nil

local function hashColor(id)
	local hash = 0
	for i = 1, #id do
		hash = (hash * 33 + string.byte(id, i)) % 360
	end
	return Color3.fromHSV(hash / 360, 0.55, 0.95)
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

local function renderSlot(slot)
	local data = getSlotData(slot.Type, slot.Index)
	if not data then
		slot.Icon.Image = ""
		slot.Label.Text = ""
		return
	end
	local item = ItemDatabase:Get(data.Id)
	local icon = item and item.Icon
	local iconColor = item and item.IconColor
	if icon and icon ~= "" then
		slot.Icon.Image = icon
		slot.Icon.ImageColor3 = Color3.new(1, 1, 1)
		slot.Label.Text = string.format("x%d", data.N)
		return
	end
	local placeholder = (Config.UI and Config.UI.PlaceholderIcon) or ""
	if placeholder ~= "" then
		slot.Icon.Image = placeholder
		slot.Icon.ImageColor3 = iconColor or hashColor(data.Id)
	else
		slot.Icon.Image = ""
	end
	slot.Label.Text = string.format("%s\n x%d", data.Id, data.N)
end

local function renderAll()
	for _, slot in ipairs(slots) do
		renderSlot(slot)
	end
end

local DRAG_THRESHOLD = 6
local dragging = { Active = false, Pending = false, From = nil, Ghost = nil, StartPos = nil }

local function beginDrag(slot)
	local data = getSlotData(slot.Type, slot.Index)
	if not data then return end
	selectedSlot = slot
	dragging.Active = true
	dragging.Pending = false
	dragging.From = slot
	local ghost = Instance.new("ImageLabel")
	ghost.Size = UDim2.new(0, 32, 0, 32)
	ghost.BackgroundTransparency = 1
	local item = ItemDatabase:Get(data.Id)
	local icon = item and item.Icon
	local iconColor = item and item.IconColor
	if icon and icon ~= "" then
		ghost.Image = icon
		ghost.ImageColor3 = Color3.new(1, 1, 1)
	else
		local placeholder = (Config.UI and Config.UI.PlaceholderIcon) or ""
		ghost.Image = placeholder
		ghost.ImageColor3 = iconColor or hashColor(data.Id)
	end
	ghost.Parent = gui
	dragging.Ghost = ghost
end

local function endDrag(targetSlot)
	if not dragging.Active then return end
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
	for _, slot in ipairs(slots) do
		local pos = slot.Frame.AbsolutePosition
		local size = slot.Frame.AbsoluteSize
		if point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y then
			return slot
		end
	end
	return nil
end

UserInputService.InputChanged:Connect(function(input)
	if dragging.Pending and input.UserInputType == Enum.UserInputType.MouseMovement then
		if dragging.StartPos then
			local delta = (input.Position - dragging.StartPos)
			if delta.Magnitude >= DRAG_THRESHOLD and dragging.From then
				beginDrag(dragging.From)
			end
		end
	end
	if dragging.Active and input.UserInputType == Enum.UserInputType.MouseMovement then
		if dragging.Ghost then
			dragging.Ghost.Position = UDim2.fromOffset(input.Position.X + 4, input.Position.Y + 4)
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
			if rInventoryAction and selectedSlot.Type == "Hotbar" then
				rInventoryAction:FireServer("Equip", {
					SlotType = selectedSlot.Type,
					SlotIndex = selectedSlot.Index,
				})
			end
		end
		dragging.Active = false
		dragging.Pending = false
		dragging.From = nil
		dragging.StartPos = nil
	end
end)

for _, slot in ipairs(slots) do
	slot.Button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		dragging.Pending = true
		dragging.Active = false
		dragging.From = slot
		dragging.StartPos = input.Position
	end)
end

dropButton.MouseButton1Click:Connect(function()
	if not selectedSlot then return end
	local data = getSlotData(selectedSlot.Type, selectedSlot.Index)
	if not data then return end
	if rDrop then
		rDrop:FireServer({
			SlotType = selectedSlot.Type,
			SlotIndex = selectedSlot.Index,
			Amount = data.N,
		})
	end
end)

if rInventory then
	rInventory.OnClientEvent:Connect(function(kind, payload)
		if kind ~= "Snapshot" or type(payload) ~= "table" then return end
		inventorySnapshot = payload
		renderAll()
	end)
end
