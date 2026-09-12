local Settings = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ClientSettings"))
if require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end
-- ChestUI.client.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Theme = require(ReplicatedStorage.Shared.UI.UITheme)
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = Util.GetDescendant(Config.Paths.Remotes) or Util.WaitForDescendant(Config.Paths.Remotes, 15)
local chestRemote = nil
if remotesFolder then
	chestRemote = Util.GetRemote(remotesFolder, Config.RemoteNames.ChestEvent)
	if not chestRemote then
		chestRemote = remotesFolder:WaitForChild(Config.RemoteNames.ChestEvent, 15)
	end
end
if not chestRemote then
	warn("[ChestUI] Missing ChestEvent remote")
end

local COLORS = Theme.Colors

local SLOT_SIZE = 64
local SLOT_GAP = 6
local COLS = 5
local MARGIN = 16
local FIXED_SLOTS = 10

local CHEST_TAGS = { "Common_Chest", "Rare_Chest", "Legendary_Chest", "Celestial_Chest" }

local gui = Instance.new("ScreenGui")
gui.Name = "ChestUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 25
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local itemTooltip = require(ReplicatedStorage.Shared.UI.ItemTooltip).new(gui)
local hoveredChestIndex = nil

local panel = Instance.new("Frame")
panel.Name = "ChestPanel"
panel.Size = UDim2.new(0, (SLOT_SIZE + SLOT_GAP) * COLS + MARGIN * 2, 0, 220)
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(0.5, -12, 0.5, 0)
panel.BackgroundColor3 = COLORS.Panel
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = COLORS.Border
panelStroke.Thickness = 1
panelStroke.Transparency = 0.5
panelStroke.Parent = panel

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 42)
header.BackgroundTransparency = 1
header.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -90, 1, 0)
title.Position = UDim2.new(0, MARGIN, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = COLORS.Text
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Chest"
title.Parent = header

local transferStatusLabel = Instance.new("TextLabel")
transferStatusLabel.Name = "TransferStatus"
transferStatusLabel.Size = UDim2.new(1, -MARGIN * 2 - 70, 0, 14)
transferStatusLabel.AnchorPoint = Vector2.new(0, 1)
transferStatusLabel.Position = UDim2.new(0, MARGIN, 1, -2)
transferStatusLabel.BackgroundTransparency = 1
transferStatusLabel.Font = Enum.Font.Gotham
transferStatusLabel.TextSize = 11
transferStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
transferStatusLabel.TextColor3 = COLORS.TextMuted
transferStatusLabel.Text = ""
transferStatusLabel.Visible = false
transferStatusLabel.Parent = header

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 64, 0, 22)
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -MARGIN, 0.5, 0)
closeButton.BackgroundColor3 = COLORS.Moss
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 12
closeButton.TextColor3 = COLORS.Paper
closeButton.Text = "Close"
closeButton.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

local slotContainer = Instance.new("Frame")
slotContainer.Name = "Slots"
slotContainer.Size = UDim2.new(1, -MARGIN * 2, 1, -54)
slotContainer.Position = UDim2.new(0, MARGIN, 0, 46)
slotContainer.BackgroundTransparency = 1
slotContainer.Parent = panel

local slots = {}
local slotData = {}
local slotCount = FIXED_SLOTS
local currentChestId = nil
local lastOpenRequestAt = 0
local dragging = { Active = false, Source = nil, ChestIndex = nil, Inv = nil, Ghost = nil, InvFrames = nil, ChestFrames = nil, Input = nil, PendingIndex = nil, StartPos = nil }
local arrangeChest
local transferStatusToken = 0
local contextChestIndex = nil

local function isShiftDown()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

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

local contextMenu = Instance.new("Frame")
contextMenu.Name = "ContextMenu"
contextMenu.Size = UDim2.new(0, 128, 0, 92)
contextMenu.BackgroundColor3 = COLORS.Panel
contextMenu.BorderSizePixel = 0
contextMenu.Visible = false
contextMenu.ZIndex = 40
contextMenu.Parent = gui

local contextCorner = Instance.new("UICorner")
contextCorner.CornerRadius = UDim.new(0, 6)
contextCorner.Parent = contextMenu

local contextStroke = Instance.new("UIStroke")
contextStroke.Color = COLORS.Border
contextStroke.Thickness = 1
contextStroke.Parent = contextMenu

local function makeContextButton(text, order)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -8, 0, 24)
	btn.Position = UDim2.new(0, 4, 0, 4 + (order - 1) * 28)
	btn.BackgroundColor3 = COLORS.SlotEmpty
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.TextColor3 = COLORS.Text
	btn.Text = text
	btn.ZIndex = 41
	btn.Parent = contextMenu
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = btn
	return btn
end

local contextTake = makeContextButton("Take", 1)
local contextToHotbar = makeContextButton("To Hotbar", 2)
local contextToStorage = makeContextButton("To Storage", 3)

local function isChestTagged(inst)
	if typeof(inst) ~= "Instance" then return false end
	for _, tag in ipairs(CHEST_TAGS) do
		if CollectionService:HasTag(inst, tag) then
			return true
		end
	end
	return false
end

local function setInventoryChestState(open, chestId)
	local invGui = playerGui:FindFirstChild("InventoryUI")
	if invGui and invGui:IsA("ScreenGui") then
		invGui:SetAttribute("ChestOpen", open and true or false)
		invGui:SetAttribute("ForceOpen", open and true or false)
		invGui:SetAttribute("ChestId", open and chestId or nil)
	end
end

local function normalizeSlots(raw)
	local normalized = {}
	local maxIndex = 0
	if type(raw) ~= "table" then
		return normalized, 0
	end
	for k, v in pairs(raw) do
		local index = tonumber(k)
		if index and index >= 1 and index % 1 == 0 then
			if v and v ~= false and type(v) == "table" and v.Id and tonumber(v.N) and tonumber(v.N) > 0 then
				normalized[index] = { Id = v.Id, N = math.floor(tonumber(v.N)) }
			else
				normalized[index] = nil
			end
			if index > maxIndex then
				maxIndex = index
			end
		end
	end
	return normalized, maxIndex
end

local function getInventorySlots()
	local invGui = playerGui:FindFirstChild("InventoryUI")
	if not invGui then
		return {}
	end
	local list = {}
	for _, inst in ipairs(invGui:GetDescendants()) do
		if inst:IsA("Frame") and inst:GetAttribute("SlotType") then
			list[#list + 1] = inst
		end
	end
	return list
end

local function getChestSlotFrames()
	local frames = {}
	for _, slot in ipairs(slots) do
		frames[#frames + 1] = slot.Frame
	end
	return frames
end

local function slotAtPoint(point, frames, touch)
	local inset = GuiService:GetGuiInset()
	if touch then inset = Vector2.zero end
	local adjusted = Vector2.new(point.X - inset.X, point.Y - inset.Y)
	for _, frame in ipairs(frames) do
		local pos = frame.AbsolutePosition
		local size = frame.AbsoluteSize
		if adjusted.X >= pos.X and adjusted.X <= pos.X + size.X and adjusted.Y >= pos.Y and adjusted.Y <= pos.Y + size.Y then
			return frame
		end
	end
	return nil
end

local function isPointInsideGui(guiObject, point)
	if not guiObject then return false end
	local inset = GuiService:GetGuiInset()
	local adjusted = Vector2.new(point.X - inset.X, point.Y - inset.Y)
	local pos = guiObject.AbsolutePosition
	local size = guiObject.AbsoluteSize
	return adjusted.X >= pos.X
		and adjusted.X <= pos.X + size.X
		and adjusted.Y >= pos.Y
		and adjusted.Y <= pos.Y + size.Y
end

local function clearSlots()
	for _, slot in ipairs(slots) do
		slot.Frame:Destroy()
	end
	slots = {}
end

local function hideContextMenu()
	contextChestIndex = nil
	contextMenu.Visible = false
end

local function renderSlot(slot)
	local data = slotData[slot.Index]
	if hoveredChestIndex == slot.Index then
		itemTooltip:Show(data, "Drag to transfer • Shift-click takes stack • Right-click takes half")
	end
	if not data then
		slot.Icon.Image = ""
		slot.Icon.Visible = false
		slot.QtyBadge.Visible = false
		slot.ItemText.Visible = false
		slot.ItemText.Text = ""
		slot.Frame.BackgroundColor3 = COLORS.SlotEmpty
		slot.Frame:SetAttribute("HasItem", false)
		slot.Frame:SetAttribute("ItemId", "")
		slot.Frame:SetAttribute("Count", 0)
		return
	end

	local item = ItemDatabase:Get(data.Id)
	local icon = item and item.Icon or nil
	slot.Qty.Text = tostring(data.N)
	slot.QtyBadge.Visible = data.N > 1
	slot.Frame.BackgroundColor3 = COLORS.SlotFilled

	if icon and icon ~= "" then
		slot.Icon.Image = icon
		slot.Icon.ImageColor3 = Color3.new(1, 1, 1)
		slot.Icon.Visible = true
		slot.ItemText.Visible = false
		slot.ItemText.Text = ""
	else
		slot.Icon.Image = ""
		slot.Icon.Visible = false
		slot.ItemText.Text = (item and item.Name or data.Id):gsub(" ", "\n", 1)
		slot.ItemText.TextColor3 = hashColor(data.Id)
		slot.ItemText.Visible = true
	end
	slot.Frame:SetAttribute("HasItem", true)
	slot.Frame:SetAttribute("ItemId", data.Id)
	slot.Frame:SetAttribute("Count", data.N)
end

local function renderAll()
	for _, slot in ipairs(slots) do
		renderSlot(slot)
	end
end

local function takeFromChestSlot(index, targetFrame, amount)
	if not currentChestId or not chestRemote then return end
	local data = slotData[index]
	if not data then return end
	local payload = {
		ChestId = currentChestId,
		FromIndex = index,
		Amount = math.clamp(math.floor(tonumber(amount) or data.N), 1, data.N),
	}
	if targetFrame then
		payload.ToType = targetFrame:GetAttribute("SlotType")
		payload.ToIndex = targetFrame:GetAttribute("SlotIndex")
	end
	chestRemote:FireServer("Take", payload)
end

local function createGhost(itemId, count)
	local ghost = Instance.new("Frame")
	ghost.Size = UDim2.new(0, 40, 0, 40)
	ghost.BackgroundColor3 = COLORS.Panel
	ghost.BackgroundTransparency = 0.15
	ghost.BorderSizePixel = 0
	ghost.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = ghost

	local item = ItemDatabase:Get(itemId)
	local icon = item and item.Icon or nil
	if icon and icon ~= "" then
		local image = Instance.new("ImageLabel")
		image.Size = UDim2.new(0, 28, 0, 28)
		image.Position = UDim2.new(0.5, 0, 0.5, 0)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundTransparency = 1
		image.Image = icon
		image.ImageColor3 = Color3.new(1, 1, 1)
		image.Parent = ghost
	else
		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, -4, 1, -4)
		text.Position = UDim2.new(0, 2, 0, 2)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBold
		text.TextSize = 10
		text.TextWrapped = true
		text.TextColor3 = hashColor(itemId)
		text.Text = itemId
		text.Parent = ghost
	end

	if count > 1 then
		local qty = Instance.new("TextLabel")
		qty.Size = UDim2.new(0, 20, 0, 12)
		qty.AnchorPoint = Vector2.new(1, 1)
		qty.Position = UDim2.new(1, -2, 1, -2)
		qty.BackgroundTransparency = 1
		qty.Font = Enum.Font.GothamBold
		qty.TextSize = 10
		qty.TextColor3 = COLORS.Text
		qty.Text = tostring(count)
		qty.TextXAlignment = Enum.TextXAlignment.Right
		qty.Parent = ghost
	end

	return ghost
end

local function beginChestDrag(index)
	hoveredChestIndex = nil
	itemTooltip:Hide()
	local data = slotData[index]
	if not data then return end
	dragging.Active = true
	dragging.Source = "Chest"
	dragging.ChestIndex = index
	dragging.Inv = nil
	dragging.InvFrames = getInventorySlots()
	dragging.ChestFrames = getChestSlotFrames()
	dragging.Ghost = createGhost(data.Id, data.N)
end

local function endDrag(mousePoint, touch)
	if not dragging.Active then return end
	if dragging.Ghost then
		dragging.Ghost:Destroy()
	end

	local source = dragging.Source
	local fromChestIndex = dragging.ChestIndex
	local invFrames = dragging.InvFrames or {}
	local chestFrames = dragging.ChestFrames or {}

	dragging.Active = false
	dragging.Source = nil
	dragging.ChestIndex = nil
	dragging.Inv = nil
	dragging.Ghost = nil
	dragging.InvFrames = nil
	dragging.ChestFrames = nil
	dragging.Input, dragging.PendingIndex, dragging.StartPos = nil, nil, nil

	if not currentChestId or not chestRemote then return end

	local chestTarget = slotAtPoint(mousePoint, chestFrames, touch)
	local invTarget = slotAtPoint(mousePoint, invFrames, touch)

	if source == "Chest" and fromChestIndex then
		if chestTarget then
			local toIndex = tonumber(chestTarget:GetAttribute("ChestIndex"))
			if toIndex and toIndex ~= fromChestIndex then
				chestRemote:FireServer("Move", {
					ChestId = currentChestId,
					FromIndex = fromChestIndex,
					ToIndex = toIndex,
				})
				return
			end
		end
		if invTarget then
			takeFromChestSlot(fromChestIndex, invTarget)
		end
		return
	end

end

local function findInventoryTargetForItem(itemId, preferStorage)
	local frames = getInventorySlots()
	table.sort(frames, function(a, b)
		return (tonumber(a:GetAttribute("SlotIndex")) or math.huge) < (tonumber(b:GetAttribute("SlotIndex")) or math.huge)
	end)
	local maxStack = getItemStackSize(itemId)
	local function pickStack(slotType)
		for _, frame in ipairs(frames) do
			if frame:GetAttribute("SlotType") == slotType
				and frame:GetAttribute("HasItem") == true
				and frame:GetAttribute("ItemId") == itemId then
				local count = tonumber(frame:GetAttribute("Count")) or 0
				if count < maxStack then
					return frame
				end
			end
		end
		return nil
	end
	local function pickEmpty(slotType)
		for _, frame in ipairs(frames) do
			if frame:GetAttribute("SlotType") == slotType and frame:GetAttribute("HasItem") == false then
				return frame
			end
		end
		return nil
	end
	local order = preferStorage and { "Storage", "Hotbar" } or { "Hotbar", "Storage" }
	for _, slotType in ipairs(order) do
		local stackTarget = pickStack(slotType)
		if stackTarget then
			return stackTarget
		end
	end
	for _, slotType in ipairs(order) do
		local emptyTarget = pickEmpty(slotType)
		if emptyTarget then
			return emptyTarget
		end
	end
	return nil
end

local function chestSlotData(index)
	local data = slotData[index]
	if data and data.Id and tonumber(data.N) and tonumber(data.N) > 0 then
		return data
	end
	return nil
end

local function showContextMenu(index, position)
	if not chestSlotData(index) then return end
	contextChestIndex = index
	contextMenu.Position = UDim2.fromOffset(position.X + 6, position.Y + 6)
	contextMenu.Visible = true
end

local function quickTakeFromChest(index, preferStorage)
	local data = chestSlotData(index)
	if not data then return end
	local target = findInventoryTargetForItem(data.Id, preferStorage)
	takeFromChestSlot(index, target)
	if target then
		showTransferStatus("Moved to inventory", COLORS.Accent, 0.9)
	else
		showTransferStatus("No direct slot, auto-placing", COLORS.Warning, 1.1)
	end
end

local function splitTakeFromChest(index)
	local data = chestSlotData(index)
	if not data then return end
	local target = findInventoryTargetForItem(data.Id, true)
	if not target then
		showTransferStatus("No inventory room for split stack", COLORS.Warning, 1.1)
		return
	end
	takeFromChestSlot(index, target, math.ceil(data.N / 2))
	showTransferStatus("Moved half to inventory", COLORS.Accent, 0.9)
end

contextTake.MouseButton1Click:Connect(function()
	if not contextChestIndex then return end
	takeFromChestSlot(contextChestIndex, nil)
	showTransferStatus("Auto-placing in inventory", COLORS.Accent, 0.9)
	hideContextMenu()
end)

contextToHotbar.MouseButton1Click:Connect(function()
	if not contextChestIndex then return end
	quickTakeFromChest(contextChestIndex, false)
	hideContextMenu()
end)

contextToStorage.MouseButton1Click:Connect(function()
	if not contextChestIndex then return end
	quickTakeFromChest(contextChestIndex, true)
	hideContextMenu()
end)

local function createSlot(index, x, y)
	local slot = Instance.new("Frame")
	slot.Name = "ChestSlot_" .. index
	slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	slot.Position = UDim2.new(0, x, 0, y)
	slot.BackgroundColor3 = COLORS.SlotEmpty
	slot.BorderSizePixel = 0
	slot:SetAttribute("ChestIndex", index)
	slot:SetAttribute("HasItem", false)
	slot:SetAttribute("ItemId", "")
	slot:SetAttribute("Count", 0)
	slot.Parent = slotContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = slot

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Border
	stroke.Thickness = 1
	stroke.Transparency = 0.7
	stroke.Parent = slot

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, 40, 0, 40)
	icon.Position = UDim2.new(0.5, 0, 0.5, -4)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.Image = ""
	icon.Visible = false
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = slot

	local itemText = Instance.new("TextLabel")
	itemText.Size = UDim2.new(1, -8, 0, 40)
	itemText.Position = UDim2.new(0, 4, 0, 7)
	itemText.BackgroundTransparency = 1
	itemText.Font = Enum.Font.Gotham
	itemText.TextSize = 11
	itemText.TextColor3 = COLORS.TextMuted
	itemText.TextXAlignment = Enum.TextXAlignment.Left
	itemText.Text = ""
	itemText.Visible = false
	itemText.Parent = slot

	local qtyBadge = Instance.new("Frame")
	qtyBadge.Size = UDim2.new(0, 30, 0, 16)
	qtyBadge.Position = UDim2.new(1, -34, 1, -20)
	qtyBadge.BackgroundColor3 = COLORS.Accent
	qtyBadge.BackgroundTransparency = 0.2
	qtyBadge.BorderSizePixel = 0
	qtyBadge.Visible = false
	qtyBadge.Parent = slot

	local qtyCorner = Instance.new("UICorner")
	qtyCorner.CornerRadius = UDim.new(0, 4)
	qtyCorner.Parent = qtyBadge

	local qty = Instance.new("TextLabel")
	qty.Size = UDim2.new(1, 0, 1, 0)
	qty.BackgroundTransparency = 1
	qty.Font = Enum.Font.GothamBold
	qty.TextSize = 10
	qty.TextColor3 = COLORS.Paper
	qty.Text = "1"
	qty.Parent = qtyBadge

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = slot

	button.MouseEnter:Connect(function()
		if not currentChestId or dragging.Active then return end
		hoveredChestIndex = index
		itemTooltip:Show(slotData[index], "Drag to transfer • Shift-click takes stack • Right-click takes half")
	end)
	button.MouseLeave:Connect(function()
		if hoveredChestIndex == index then hoveredChestIndex = nil; itemTooltip:Hide() end
	end)
	button.InputBegan:Connect(function(input)
		if not currentChestId or dragging.Active or dragging.Input then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			hideContextMenu()
			splitTakeFromChest(index)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			hideContextMenu()
			if isShiftDown() then quickTakeFromChest(index, true); return end
			beginChestDrag(index)
		elseif input.UserInputType == Enum.UserInputType.Touch and chestSlotData(index) then
			hideContextMenu()
			dragging.Input, dragging.PendingIndex, dragging.StartPos = input, index, input.Position
		end
	end)

	return {
		Frame = slot,
		Icon = icon,
		ItemText = itemText,
		QtyBadge = qtyBadge,
		Qty = qty,
		Button = button,
		Index = index,
	}
end

local function ensureSlotCount(count)
	if #slots == count then
		return
	end
	clearSlots()
	local rows = math.max(1, math.ceil(count / COLS))
	panel.Size = UDim2.new(0, (SLOT_SIZE + SLOT_GAP) * COLS + MARGIN * 2, 0, 60 + rows * (SLOT_SIZE + SLOT_GAP))
	for i = 1, count do
		local row = math.floor((i - 1) / COLS)
		local col = (i - 1) % COLS
		local x = col * (SLOT_SIZE + SLOT_GAP)
		local y = row * (SLOT_SIZE + SLOT_GAP)
		slots[#slots + 1] = createSlot(i, x, y)
	end
	if arrangeChest then arrangeChest() end
end

local function closeChest(sendCloseEvent)
	hoveredChestIndex = nil
	itemTooltip:Hide()
	if dragging.Ghost then
		dragging.Ghost:Destroy()
	end
	dragging.Active = false
	dragging.Source = nil
	dragging.ChestIndex = nil
	dragging.Inv = nil
	dragging.Ghost = nil
	dragging.InvFrames = nil
	dragging.ChestFrames = nil
	dragging.Input, dragging.PendingIndex, dragging.StartPos = nil, nil, nil
	showTransferStatus(nil)
	hideContextMenu()
	panel.Visible = false
	currentChestId = nil
	setInventoryChestState(false, nil)
	if sendCloseEvent and chestRemote then
		chestRemote:FireServer("Close")
	end
end

closeButton.MouseButton1Click:Connect(function()
	closeChest(true)
end)

if chestRemote then
	chestRemote.OnClientEvent:Connect(function(action, payload)
		if action == "Open" then
			if type(payload) ~= "table" then return end
			showTransferStatus(nil)
			currentChestId = payload.ChestId
			title.Text = payload.Title or "Chest"
			slotData = normalizeSlots(payload.Slots or {})
			slotCount = tonumber(payload.SlotCount) or FIXED_SLOTS
			ensureSlotCount(slotCount)
			renderAll()
			panel.Visible = true
			setInventoryChestState(true, currentChestId)
		elseif action == "Update" then
			if type(payload) ~= "table" or payload.ChestId ~= currentChestId then return end
			slotData = normalizeSlots(payload.Slots or {})
			slotCount = tonumber(payload.SlotCount) or FIXED_SLOTS
			ensureSlotCount(slotCount)
			renderAll()
		elseif action == "Close" then
			closeChest(false)
		end
	end)
end

UserInputService.InputChanged:Connect(function(input)
	local touch = input == dragging.Input
	if touch and dragging.PendingIndex and dragging.StartPos and (input.Position - dragging.StartPos).Magnitude >= 10 then
		local index = dragging.PendingIndex
		dragging.PendingIndex = nil
		beginChestDrag(index)
	end
	if dragging.Active and (touch or (not dragging.Input and input.UserInputType == Enum.UserInputType.MouseMovement)) then
		if dragging.Ghost then
			local size = dragging.Ghost.AbsoluteSize
			local inset = GuiService:GetGuiInset()
			if touch then inset = Vector2.zero end
			dragging.Ghost.Position = UDim2.fromOffset(input.Position.X - inset.X - size.X * 0.5, input.Position.Y - inset.Y - size.Y * 0.5)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input == dragging.Input then
		local point = Vector2.new(input.Position.X, input.Position.Y)
		if dragging.Active then
			endDrag(point, true)
		else
			local index = dragging.PendingIndex
			local target = slotAtPoint(point, getChestSlotFrames(), true)
			dragging.Input, dragging.PendingIndex, dragging.StartPos = nil, nil, nil
			if index and target and target:GetAttribute("ChestIndex") == index then quickTakeFromChest(index, true) end
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not dragging.Input and dragging.Active then
		endDrag(UserInputService:GetMouseLocation())
	end
end)

UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and contextMenu.Visible and not isPointInsideGui(contextMenu, input.Position) then
		hideContextMenu()
	end
	if not Settings.Matches(input, "Pack") then return end
	if UserInputService:GetFocusedTextBox() then return end
	if currentChestId then
		closeChest(true)
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
	if playerWhoTriggered ~= player then return end
	if not chestRemote then return end
	local parent = prompt and prompt.Parent
	if not parent then return end

	local chest = parent:FindFirstAncestorOfClass("Model") or parent
	if not chest or not chest.Parent then return end
	if not isChestTagged(chest) then return end

	local now = os.clock()
	if now - lastOpenRequestAt < 0.1 then return end
	lastOpenRequestAt = now
	chestRemote:FireServer("Open", { Chest = chest })
end)

Theme.Panel(panel)
local chestScale = Instance.new("UIScale")
chestScale.Name, chestScale.Parent = "ViewportScale", panel
Theme.CaptureCursor(panel); Theme.AnimatePanel(panel)
Theme.Button(closeButton, true)
for _, button in ipairs({contextTake, contextToHotbar, contextToStorage}) do Theme.Button(button) end

arrangeChest = function()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local mobile = Theme.IsMobile()
	local viewport = camera.ViewportSize
	local topInset, bottomInset = GuiService:GetGuiInset()
	local width, height = viewport.X - topInset.X - bottomInset.X, viewport.Y - topInset.Y - bottomInset.Y
	local portrait = mobile and width < height
	local packWidth, packHeight = 446, mobile and 292 or 380
	local chestHeight = (mobile and 78 or 60) + math.max(1, math.ceil(slotCount / COLS)) * (SLOT_SIZE + SLOT_GAP)
	local hotbarScale = math.min(1.5, (width - 64) / 422)
	local bottomReserve = mobile and (portrait and 192 or 96) or (18 + 72 * hotbarScale + 24)
	local availableHeight = math.max(120, height - bottomReserve)
	local totalWidth = portrait and math.max(packWidth, 382) or packWidth + 382 + 24
	local totalHeight = portrait and (packHeight + chestHeight + 12) or math.max(packHeight, chestHeight)
	local scale = math.min(mobile and 1.65 or 2.5, (width - 24) / totalWidth, availableHeight / totalHeight)
	chestScale.Scale = scale
	chestScale:SetAttribute("TargetScale", scale)
	panel.Size = UDim2.fromOffset(382, chestHeight)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromOffset(width * 0.5 - (portrait and 0 or (packWidth + 24) * scale * 0.5), availableHeight * 0.5 + 8 - (portrait and (packHeight + 12) * scale * 0.5 or 0))
	title.TextSize = mobile and 22 or 20
	closeButton.Size = UDim2.fromOffset(mobile and 64 / scale or 64, mobile and 44 / scale or 40)
	closeButton.Text = mobile and "X" or "Close"
	closeButton.TextSize = mobile and 18 / scale or 12
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -MARGIN, 0, 4)
	transferStatusLabel.TextSize = mobile and 14 or 12
	transferStatusLabel.Position = UDim2.new(0, MARGIN, 1, 12)
	slotContainer.Position = UDim2.fromOffset(MARGIN, mobile and 76 or 58)
	for _, slot in ipairs(slots) do
		slot.ItemText.TextSize = mobile and 12 / scale or 12
		slot.ItemText.TextWrapped = false
		slot.ItemText.TextTruncate = Enum.TextTruncate.AtEnd
		slot.ItemText.Size = UDim2.new(1, -8, 0, mobile and 26 / scale or 40)
		slot.ItemText.Position = UDim2.fromOffset(4, mobile and 2 / scale or 7)
		slot.Qty.TextSize = mobile and 12 / scale or 12
		slot.QtyBadge.Size = UDim2.fromOffset(mobile and 30 / scale or 30, mobile and 16 / scale or 16)
		slot.QtyBadge.Position = UDim2.new(1, mobile and -32 / scale or -34, 1, mobile and -18 / scale or -20)
	end
	local invGui = playerGui:FindFirstChild("InventoryUI")
	if invGui then invGui:SetAttribute("ChestLayoutHeight", chestHeight) end
end

UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(arrangeChest)
local chestViewportConnection
local function bindChestViewport()
	if chestViewportConnection then chestViewportConnection:Disconnect() end
	if workspace.CurrentCamera then chestViewportConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(arrangeChest) end
	arrangeChest()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindChestViewport)
bindChestViewport()
