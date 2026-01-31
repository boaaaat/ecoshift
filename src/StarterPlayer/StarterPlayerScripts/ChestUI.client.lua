-- ChestUI.client.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = Util.GetDescendant(Config.Paths.Remotes) or Util.WaitForDescendant(Config.Paths.Remotes, 5)
local chestRemote = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.ChestEvent)
if not chestRemote then
	warn("[ChestUI] Missing ChestEvent remote")
end

-- UI constants (match InventoryUI)
local COLORS = {
	Background = Color3.fromRGB(18, 18, 22),
	Panel = Color3.fromRGB(28, 28, 35),
	SlotEmpty = Color3.fromRGB(38, 38, 48),
	SlotFilled = Color3.fromRGB(48, 48, 60),
	SlotHover = Color3.fromRGB(58, 58, 75),
	Border = Color3.fromRGB(60, 60, 80),
	Text = Color3.fromRGB(240, 240, 245),
	TextMuted = Color3.fromRGB(160, 160, 175),
	Accent = Color3.fromRGB(100, 180, 255),
}

local SLOT_SIZE = 64
local SLOT_GAP = 6
local COLS = 5
local MARGIN = 16

local gui = Instance.new("ScreenGui")
gui.Name = "ChestUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "ChestPanel"
panel.Size = UDim2.new(0, (SLOT_SIZE + SLOT_GAP) * COLS + MARGIN * 2, 0, 220)
panel.AnchorPoint = Vector2.new(0, 1)
panel.Position = UDim2.new(0, 20, 1, -20)
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
title.Text = "🧰 Chest"
title.Parent = header

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 64, 0, 22)
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -MARGIN, 0.5, 0)
closeButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 12
closeButton.TextColor3 = Color3.fromRGB(230, 230, 230)
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
local currentChestId = nil

local function hashColor(id)
	local hash = 0
	for i = 1, #id do
		hash = (hash * 33 + string.byte(id, i)) % 360
	end
	return Color3.fromHSV(hash / 360, 0.55, 0.85)
end

local function clearSlots()
	for _, s in ipairs(slots) do
		s.Frame:Destroy()
	end
	slots = {}
end

local function createSlot(index, x, y)
	local slot = Instance.new("Frame")
	slot.Name = "ChestSlot_" .. index
	slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	slot.Position = UDim2.new(0, x, 0, y)
	slot.BackgroundColor3 = COLORS.SlotEmpty
	slot.BorderSizePixel = 0
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
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = slot

	local itemText = Instance.new("TextLabel")
	itemText.Size = UDim2.new(1, -8, 0, 18)
	itemText.Position = UDim2.new(0, 4, 1, -20)
	itemText.BackgroundTransparency = 1
	itemText.Font = Enum.Font.Gotham
	itemText.TextSize = 11
	itemText.TextColor3 = COLORS.TextMuted
	itemText.TextXAlignment = Enum.TextXAlignment.Left
	itemText.Text = ""
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
	qty.TextColor3 = COLORS.Text
	qty.Text = "1"
	qty.Parent = qtyBadge

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = slot

	return { Frame = slot, Icon = icon, ItemText = itemText, QtyBadge = qtyBadge, Qty = qty, Button = button, Index = index }
end

local function normalizeSlots(raw)
	if type(raw) ~= "table" then return {} end
	local numeric = {}
	local maxIndex = 0
	for k, v in pairs(raw) do
		if type(k) == "number" then
			numeric[k] = v
			if k > maxIndex then maxIndex = k end
		end
	end
	if maxIndex > 0 then
		local list = {}
		for i = 1, maxIndex do
			if numeric[i] then
				list[#list + 1] = numeric[i]
			end
		end
		return list
	end
	local list = {}
	for _, v in pairs(raw) do
		list[#list + 1] = v
	end
	return list
end

local function renderSlot(slot)
	local data = slotData[slot.Index]
	if not data then
		slot.Icon.Image = ""
		slot.Icon.ImageColor3 = Color3.new(1, 1, 1)
		slot.QtyBadge.Visible = false
		if slot.ItemText then
			slot.ItemText.Text = ""
		end
		return
	end
	local item = ItemDatabase:Get(data.Id)
	if item and item.Icon and item.Icon ~= "" then
		slot.Icon.Image = item.Icon
		slot.Icon.ImageColor3 = Color3.new(1, 1, 1)
		if slot.ItemText then
			slot.ItemText.Text = "x" .. tostring(data.N)
		end
	else
		slot.Icon.Image = (Config.UI and Config.UI.PlaceholderIcon) or ""
		slot.Icon.ImageColor3 = hashColor(data.Id)
		if slot.ItemText then
			slot.ItemText.Text = string.format("%s x%d", data.Id, data.N)
		end
	end
	slot.Qty.Text = tostring(data.N)
	slot.QtyBadge.Visible = data.N > 1
end

local function renderAll()
	for _, slot in ipairs(slots) do
		renderSlot(slot)
	end
end

local function ensureSlotCount(count)
	clearSlots()
	local rows = math.max(1, math.ceil(count / COLS))
	panel.Size = UDim2.new(0, (SLOT_SIZE + SLOT_GAP) * COLS + MARGIN * 2, 0, 60 + rows * (SLOT_SIZE + SLOT_GAP))
	for i = 1, count do
		local row = math.floor((i - 1) / COLS)
		local col = (i - 1) % COLS
		local x = col * (SLOT_SIZE + SLOT_GAP)
		local y = row * (SLOT_SIZE + SLOT_GAP)
		local slot = createSlot(i, x, y)
		table.insert(slots, slot)
	end
end

local function getInventorySlots()
	local invGui = playerGui:FindFirstChild("InventoryUI")
	if not invGui then
		warn("[ChestUI] InventoryUI not found")
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

local function slotAtPoint(point, frames)
	local inset = GuiService:GetGuiInset()
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

local dragging = { Active = false, From = nil, Ghost = nil, InvSlots = nil }

local function isShiftDown()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

local function findEmptyInventorySlot(preferStorage)
	local invGui = playerGui:FindFirstChild("InventoryUI")
	if not invGui then return nil end
	local candidates = {}
	for _, frame in ipairs(invGui:GetDescendants()) do
		if frame:IsA("Frame") and frame:GetAttribute("SlotType") then
			candidates[#candidates + 1] = frame
		end
	end
	local function pick(slotType)
		for _, frame in ipairs(candidates) do
			if frame:GetAttribute("SlotType") == slotType and frame:GetAttribute("HasItem") == false then
				return frame
			end
		end
		return nil
	end
	if preferStorage then
		return pick("Storage") or pick("Hotbar")
	end
	return pick("Hotbar") or pick("Storage")
end

local function beginDrag(slot)
	if not slotData[slot.Index] then return end
	dragging.Active = true
	dragging.From = slot
	dragging.InvSlots = getInventorySlots()
	local ghost = Instance.new("ImageLabel")
	ghost.Size = UDim2.new(0, 32, 0, 32)
	ghost.BackgroundTransparency = 1
	local item = ItemDatabase:Get(slotData[slot.Index].Id)
	if item and item.Icon and item.Icon ~= "" then
		ghost.Image = item.Icon
		ghost.ImageColor3 = Color3.new(1, 1, 1)
	else
		ghost.Image = (Config.UI and Config.UI.PlaceholderIcon) or ""
		ghost.ImageColor3 = hashColor(slotData[slot.Index].Id)
	end
	ghost.Parent = gui
	dragging.Ghost = ghost
end

local function endDrag(targetFrame)
	if not dragging.Active then return end
	if dragging.Ghost then dragging.Ghost:Destroy() end
	local from = dragging.From
	dragging.Active = false
	dragging.From = nil
	dragging.Ghost = nil
	if not targetFrame or not currentChestId then return end
	local slotType = targetFrame:GetAttribute("SlotType")
	local slotIndex = targetFrame:GetAttribute("SlotIndex")
	if not slotType or not slotIndex then return end
	local data = slotData[from.Index]
	if not data then return end
	print(string.format("[ChestUI] Take %s x%d -> %s[%s]", data.Id, data.N, slotType, tostring(slotIndex)))
	if chestRemote then
		chestRemote:FireServer("Take", {
			ChestId = currentChestId,
			FromIndex = from.Index,
			ToType = slotType,
			ToIndex = slotIndex,
			Amount = data.N,
		})
	end
end

UserInputService.InputChanged:Connect(function(input)
	if dragging.Active and input.UserInputType == Enum.UserInputType.MouseMovement then
		if dragging.Ghost then
			dragging.Ghost.Position = UDim2.fromOffset(input.Position.X + 4, input.Position.Y + 4)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging.Active then
		local target = slotAtPoint(UserInputService:GetMouseLocation(), dragging.InvSlots or {})
		endDrag(target)
	end
end)

local function bindSlotButtons()
	for _, slot in ipairs(slots) do
		slot.Button.MouseButton1Down:Connect(function()
			if isShiftDown() then
				if not currentChestId then return end
				local data = slotData[slot.Index]
				if not data then return end
				local target = findEmptyInventorySlot(true)
				if not target then return end
				local slotType = target:GetAttribute("SlotType")
				local slotIndex = target:GetAttribute("SlotIndex")
				print(string.format("[ChestUI] Shift take %s x%d -> %s[%s]", data.Id, data.N, tostring(slotType), tostring(slotIndex)))
				if chestRemote then
					chestRemote:FireServer("Take", {
						ChestId = currentChestId,
						FromIndex = slot.Index,
						ToType = slotType,
						ToIndex = slotIndex,
						Amount = data.N,
					})
				end
				return
			end
			beginDrag(slot)
		end)
	end
end

closeButton.MouseButton1Click:Connect(function()
	panel.Visible = false
	currentChestId = nil
	if chestRemote then
		chestRemote:FireServer("Close")
	end
end)

if chestRemote then
	chestRemote.OnClientEvent:Connect(function(action, payload)
		print(string.format("[ChestUI] Event %s", tostring(action)))
		if action == "Open" then
			currentChestId = payload.ChestId
			slotData = normalizeSlots(payload.Slots or {})
			title.Text = payload.Title or "Chest"
			ensureSlotCount(math.max(8, #slotData))
			bindSlotButtons()
			renderAll()
			panel.Visible = true
			print(string.format("[ChestUI] Open %s slots=%d", tostring(payload.ChestId), #slotData))
		elseif action == "Update" then
			if not payload or payload.ChestId ~= currentChestId then return end
			slotData = normalizeSlots(payload.Slots or {})
			ensureSlotCount(math.max(8, #slotData))
			bindSlotButtons()
			renderAll()
			print(string.format("[ChestUI] Update slots=%d", #slotData))
		elseif action == "Close" then
			panel.Visible = false
			currentChestId = nil
		end
	end)
end
