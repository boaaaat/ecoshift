-- ChestUI.client.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
local chestRemote = Util.GetRemote(remotesFolder, Config.RemoteNames.ChestEvent)

local gui = Instance.new("ScreenGui")
gui.Name = "ChestUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 360, 0, 240)
panel.Position = UDim2.new(0, 16, 1, -256)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 0, 22)
title.Position = UDim2.new(0, 8, 0, 6)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(235, 235, 235)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Chest"
title.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 52, 0, 22)
closeButton.Position = UDim2.new(1, -60, 0, 6)
closeButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 12
closeButton.TextColor3 = Color3.fromRGB(230, 230, 230)
closeButton.Text = "Close"
closeButton.Parent = panel

local SLOT_SIZE = 64
local SLOT_GAP = 8
local COLS = 4
local START_X = 8
local START_Y = 36

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
	local frame = Instance.new("Frame")
	frame.Name = "ChestSlot_" .. index
	frame.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	frame.Position = UDim2.new(0, x, 0, y)
	frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	frame.BorderSizePixel = 0
	frame.Parent = panel

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, 36, 0, 36)
	icon.Position = UDim2.new(0.5, 0, 0.5, -6)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.Image = ""
	icon.Parent = frame

	local qty = Instance.new("TextLabel")
	qty.Size = UDim2.new(1, -6, 0, 14)
	qty.Position = UDim2.new(0, 4, 1, -18)
	qty.BackgroundTransparency = 1
	qty.Font = Enum.Font.GothamBold
	qty.TextSize = 10
	qty.TextColor3 = Color3.fromRGB(220, 220, 220)
	qty.TextXAlignment = Enum.TextXAlignment.Left
	qty.Text = ""
	qty.Parent = frame

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = frame

	return { Frame = frame, Icon = icon, Qty = qty, Button = button, Index = index }
end

local function renderSlot(slot)
	local data = slotData[slot.Index]
	if not data then
		slot.Icon.Image = ""
		slot.Icon.ImageColor3 = Color3.new(1, 1, 1)
		slot.Qty.Text = ""
		return
	end
	local item = ItemDatabase:Get(data.Id)
	if item and item.Icon and item.Icon ~= "" then
		slot.Icon.Image = item.Icon
		slot.Icon.ImageColor3 = Color3.new(1, 1, 1)
	else
		slot.Icon.Image = (Config.UI and Config.UI.PlaceholderIcon) or ""
		slot.Icon.ImageColor3 = hashColor(data.Id)
	end
	slot.Qty.Text = "x" .. tostring(data.N)
end

local function renderAll()
	for _, slot in ipairs(slots) do
		renderSlot(slot)
	end
end

local function ensureSlotCount(count)
	clearSlots()
	local rows = math.ceil(count / COLS)
	panel.Size = UDim2.new(0, 360, 0, 36 + rows * (SLOT_SIZE + SLOT_GAP) + 8)
	for i = 1, count do
		local row = math.floor((i - 1) / COLS)
		local col = (i - 1) % COLS
		local x = START_X + col * (SLOT_SIZE + SLOT_GAP)
		local y = START_Y + row * (SLOT_SIZE + SLOT_GAP)
		local slot = createSlot(i, x, y)
		table.insert(slots, slot)
	end
end

local function getInventorySlots()
	local invGui = playerGui:FindFirstChild("InventoryUI")
	if not invGui then return {} end
	local list = {}
	for _, inst in ipairs(invGui:GetDescendants()) do
		if inst:IsA("Frame") and inst:GetAttribute("SlotType") then
			list[#list + 1] = inst
		end
	end
	return list
end

local function slotAtPoint(point, frames)
	for _, frame in ipairs(frames) do
		local pos = frame.AbsolutePosition
		local size = frame.AbsoluteSize
		if point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y then
			return frame
		end
	end
	return nil
end

local dragging = { Active = false, From = nil, Ghost = nil, InvSlots = nil }

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
		if action == "Open" then
			currentChestId = payload.ChestId
			slotData = payload.Slots or {}
			title.Text = payload.Title or "Chest"
			ensureSlotCount(math.max(8, #slotData))
			bindSlotButtons()
			renderAll()
			panel.Visible = true
		elseif action == "Update" then
			if not payload or payload.ChestId ~= currentChestId then return end
			slotData = payload.Slots or {}
			ensureSlotCount(math.max(8, #slotData))
			bindSlotButtons()
			renderAll()
		elseif action == "Close" then
			panel.Visible = false
			currentChestId = nil
		end
	end)
end
