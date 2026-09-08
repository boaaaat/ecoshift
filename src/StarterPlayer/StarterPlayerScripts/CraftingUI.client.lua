if require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end
-- CraftingUI.client.lua
-- Inventory crafting interface (Hand crafting only - basic recipes)
-- For advanced crafting, place and interact with workbenches
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.UI.UITheme)
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)
local WorkbenchConfig = require(ReplicatedStorage.Shared.WorkbenchConfig)
local ResultMessages = require(ReplicatedStorage.Shared.ResultMessages)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 5)
local rCraft = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.Craft)
local rInventory = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.InventoryUpdate)
if not remotesFolder then
	warn("[CraftingUI] Missing remotes folder:", Config.Paths.Remotes)
elseif not rCraft then
	warn("[CraftingUI] Missing craft remote:", Config.RemoteNames.Craft)
end

-- UI Constants (matching inventory style)
local COLORS = Theme.Colors

local MARGIN = 16
local MAX_CRAFT_QUANTITY = 99
local CRAFT_MESSAGES = ResultMessages.Craft or {}

-- State
local isOpen = false
local inventorySnapshot = nil
local selectedRecipe = nil
local isCraftPending = false
local pendingRequestToken = 0
local statusToken = 0
local craftQuantity = 1
local pendingOutput = ""
local pendingQuantity = 1
local pendingDuration = 0
local pendingStartedAt = 0
local pendingConfirmed = false
local pendingRecipeId = nil
local pendingStationType = nil

-- Create main GUI
local gui = Instance.new("ScreenGui")
gui.Name = "CraftingUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
-- Crafting modals shade the HUD and crew shortcut (orders 5–50), while
-- world ballots, death screens, and settings retain their higher priority.
gui.DisplayOrder = 60
gui.Parent = playerGui

-- Backdrop (dims screen when open)
local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = COLORS.Night
backdrop.BackgroundTransparency = 1
backdrop.BorderSizePixel = 0
backdrop.Visible = false
backdrop.ZIndex = 1
backdrop.Parent = gui

-- Main panel (CanvasGroup for GroupTransparency animation)
local mainPanel = Instance.new("CanvasGroup")
mainPanel.Name = "MainPanel"
mainPanel.Size = UDim2.new(0, 452, 0, 610)
mainPanel.AnchorPoint = Vector2.new(0.5, 0.5)
mainPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
mainPanel.BackgroundColor3 = COLORS.Panel
mainPanel.BackgroundTransparency = 0.02
mainPanel.BorderSizePixel = 0
mainPanel.Visible = false
mainPanel.ZIndex = 10
mainPanel.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainPanel

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = COLORS.Border
mainStroke.Thickness = 1
mainStroke.Parent = mainPanel

-- Shadow
local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.Size = UDim2.new(1, 40, 1, 40)
shadow.Position = UDim2.new(0, -20, 0, -15)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://5554236805"
shadow.ImageColor3 = Color3.new(0, 0, 0)
shadow.ImageTransparency = 0.5
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(23, 23, 277, 277)
shadow.ZIndex = 9
shadow.Parent = mainPanel
shadow.Visible = false

-- Header
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundTransparency = 1
header.ZIndex = 11
header.Parent = mainPanel

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -80, 1, 0)
titleLabel.Position = UDim2.new(0, MARGIN, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Field crafting"
titleLabel.TextColor3 = COLORS.Text
titleLabel.TextSize = 20
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 11
titleLabel.Parent = header

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.AnchorPoint = Vector2.new(1, 0.5)
closeBtn.Position = UDim2.new(1, -MARGIN, 0.5, 0)
closeBtn.BackgroundColor3 = COLORS.SlotEmpty
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.TextColor3 = COLORS.TextMuted
closeBtn.TextSize = 16
closeBtn.Font = Enum.Font.GothamBold
closeBtn.ZIndex = 12
closeBtn.Parent = header

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 8)
closeBtnCorner.Parent = closeBtn

-- Recipe list container
local recipeContainer = Instance.new("ScrollingFrame")
recipeContainer.Name = "RecipeList"
recipeContainer.Size = UDim2.new(1, -MARGIN * 2, 1, -230)
recipeContainer.Position = UDim2.new(0, MARGIN, 0, 55)
recipeContainer.BackgroundColor3 = COLORS.Background
recipeContainer.BackgroundTransparency = 0.5
recipeContainer.BorderSizePixel = 0
recipeContainer.ScrollBarThickness = 4
recipeContainer.ScrollBarImageColor3 = COLORS.Border
recipeContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
recipeContainer.ZIndex = 11
recipeContainer.Parent = mainPanel

local recipeCorner = Instance.new("UICorner")
recipeCorner.CornerRadius = UDim.new(0, 8)
recipeCorner.Parent = recipeContainer

local recipeLayout = Instance.new("UIListLayout")
recipeLayout.SortOrder = Enum.SortOrder.Name
recipeLayout.Padding = UDim.new(0, 6)
recipeLayout.Parent = recipeContainer

local recipePadding = Instance.new("UIPadding")
recipePadding.PaddingTop = UDim.new(0, 6)
recipePadding.PaddingBottom = UDim.new(0, 6)
recipePadding.PaddingLeft = UDim.new(0, 6)
recipePadding.PaddingRight = UDim.new(0, 6)
recipePadding.Parent = recipeContainer

-- Keep batch input outside refreshed recipe cards so typing survives snapshots.
local quantityBar = Instance.new("Frame")
quantityBar.Name = "QuantityControls"
quantityBar.Size = UDim2.new(1, -MARGIN * 2, 0, 38)
quantityBar.Position = UDim2.new(0, MARGIN, 1, -164)
quantityBar.BackgroundTransparency = 1
quantityBar.ZIndex = 12
quantityBar.Parent = mainPanel

local quantityLabel = Instance.new("TextLabel")
quantityLabel.Size = UDim2.fromOffset(78, 38)
quantityLabel.BackgroundTransparency = 1
quantityLabel.Text = "Batches"
quantityLabel.TextColor3 = COLORS.Text
quantityLabel.TextSize = 15
quantityLabel.Font = Enum.Font.GothamBold
quantityLabel.TextXAlignment = Enum.TextXAlignment.Left
quantityLabel.ZIndex = 12
quantityLabel.Parent = quantityBar

local function quantityButton(name, text, x, width)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = UDim2.fromOffset(x, 0)
	button.Size = UDim2.fromOffset(width, 38)
	button.BackgroundColor3 = COLORS.SlotEmpty
	button.TextColor3 = COLORS.Text
	button.Text = text
	button.TextSize = 16
	button.Font = Enum.Font.GothamBold
	button.ZIndex = 13
	button.Parent = quantityBar
	Theme.Button(button)
	return button
end
local decreaseBtn = quantityButton("DecreaseQuantity", "−", 78, 36)
local increaseBtn = quantityButton("IncreaseQuantity", "+", 186, 36)
local maxBtn = quantityButton("MaxQuantity", "Max (0)", 232, 100)
maxBtn.Size = UDim2.new(1, -232, 0, 38)
maxBtn.TextSize = 14

local quantityBox = Instance.new("TextBox")
quantityBox.Name = "QuantityInput"
quantityBox.Position = UDim2.fromOffset(120, 0)
quantityBox.Size = UDim2.fromOffset(60, 38)
quantityBox.BackgroundColor3 = COLORS.Background
quantityBox.BorderSizePixel = 0
quantityBox.TextColor3 = COLORS.Text
quantityBox.TextSize = 17
quantityBox.Font = Enum.Font.GothamBold
quantityBox.Text = "1"
quantityBox.PlaceholderText = "1–99"
quantityBox.ClearTextOnFocus = false
quantityBox.ZIndex = 13
quantityBox.Parent = quantityBar
Theme.Corner(quantityBox, 6)
local quantityStroke = Instance.new("UIStroke")
quantityStroke.Color = COLORS.Border
quantityStroke.Parent = quantityBox

local batchSummary = Instance.new("TextLabel")
batchSummary.Name = "BatchSummary"
batchSummary.Size = UDim2.new(1, -MARGIN * 2, 0, 20)
batchSummary.Position = UDim2.new(0, MARGIN, 1, -120)
batchSummary.BackgroundTransparency = 1
batchSummary.Text = "Choose a recipe to set its batch size"
batchSummary.TextColor3 = COLORS.Text
batchSummary.TextSize = 14
batchSummary.Font = Enum.Font.GothamBold
batchSummary.TextXAlignment = Enum.TextXAlignment.Left
batchSummary.TextTruncate = Enum.TextTruncate.AtEnd
batchSummary.ZIndex = 12
batchSummary.Parent = mainPanel
local batchTime = batchSummary:Clone()
batchTime.Name = "BatchTime"
batchTime.Position = UDim2.new(0, MARGIN, 1, -100)
batchTime.Text = ""
batchTime.TextSize = 13
batchTime.Font = Enum.Font.Gotham
batchTime.TextColor3 = COLORS.TextMuted
batchTime.Parent = mainPanel

-- Craft button at bottom
local craftBtn = Instance.new("TextButton")
craftBtn.Name = "CraftButton"
craftBtn.Size = UDim2.new(1, -MARGIN * 2, 0, 48)
craftBtn.Position = UDim2.new(0, MARGIN, 1, -76)
craftBtn.AnchorPoint = Vector2.new(0, 0)
craftBtn.BackgroundColor3 = COLORS.SlotEmpty
craftBtn.BorderSizePixel = 0
craftBtn.Text = "Select a Recipe"
craftBtn.TextColor3 = COLORS.TextMuted
craftBtn.TextSize = 16
craftBtn.TextWrapped = true
craftBtn.Font = Enum.Font.GothamBold
craftBtn.ZIndex = 12
craftBtn.AutoButtonColor = false
craftBtn.Parent = mainPanel

local craftBtnCorner = Instance.new("UICorner")
craftBtnCorner.CornerRadius = UDim.new(0, 10)
craftBtnCorner.Parent = craftBtn

local craftBtnStroke = Instance.new("UIStroke")
craftBtnStroke.Name = "Stroke"
craftBtnStroke.Color = COLORS.Border
craftBtnStroke.Thickness = 1
craftBtnStroke.Parent = craftBtn

local progressTrack = Instance.new("Frame")
progressTrack.Name = "CraftProgress"
progressTrack.AnchorPoint = Vector2.new(0, 1)
progressTrack.Position = UDim2.new(0, 8, 1, -4)
progressTrack.Size = UDim2.new(1, -16, 0, 4)
progressTrack.BackgroundColor3 = COLORS.Night
progressTrack.BackgroundTransparency = 0.3
progressTrack.BorderSizePixel = 0
progressTrack.ClipsDescendants = true
progressTrack.Visible = false
progressTrack.ZIndex = 14
progressTrack.Parent = craftBtn
Theme.Corner(progressTrack, 2)
local progressFill = Instance.new("Frame")
progressFill.Name = "Fill"
progressFill.Size = UDim2.fromScale(0, 1)
progressFill.BackgroundColor3 = COLORS.Paper
progressFill.BorderSizePixel = 0
progressFill.ZIndex = 15
progressFill.Parent = progressTrack
Theme.Corner(progressFill, 2)

local inlineStatusLabel = Instance.new("TextLabel")
inlineStatusLabel.Name = "InlineStatus"
inlineStatusLabel.Size = UDim2.new(1, -MARGIN * 2, 0, 16)
inlineStatusLabel.AnchorPoint = Vector2.new(0, 1)
inlineStatusLabel.Position = UDim2.new(0, MARGIN, 1, -8)
inlineStatusLabel.BackgroundTransparency = 1
inlineStatusLabel.Text = ""
inlineStatusLabel.TextColor3 = COLORS.TextMuted
inlineStatusLabel.TextSize = 12
inlineStatusLabel.Font = Enum.Font.Gotham
inlineStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
inlineStatusLabel.Visible = false
inlineStatusLabel.ZIndex = 12
inlineStatusLabel.Parent = mainPanel

local function messageForReason(reason)
	local key = tostring(reason or "Unknown")
	return CRAFT_MESSAGES[key] or CRAFT_MESSAGES.Unknown or "Crafting failed."
end

local function showInlineStatus(text, color, duration)
	statusToken += 1
	local token = statusToken
	inlineStatusLabel.Text = text or ""
	inlineStatusLabel.TextColor3 = color or COLORS.TextMuted
	inlineStatusLabel.Visible = text ~= nil and text ~= ""
	if duration and duration > 0 then
		task.delay(duration, function()
			if token ~= statusToken then return end
			inlineStatusLabel.Visible = false
			inlineStatusLabel.Text = ""
		end)
	end
end

local function getItemCount(itemId)
	if not inventorySnapshot then return 0 end
	local count = 0
	if inventorySnapshot.Hotbar then
		for _, slot in pairs(inventorySnapshot.Hotbar) do
			if slot and slot.Id == itemId then
				count = count + slot.N
			end
		end
	end
	if inventorySnapshot.Storage then
		for _, slot in pairs(inventorySnapshot.Storage) do
			if slot and slot.Id == itemId then
				count = count + slot.N
			end
		end
	end
	return count
end

local function ingredientCost(ingredient)
	local craftMult = tonumber(player:GetAttribute("Role_Craft")) or 1
	return math.max(1, math.floor((ingredient.N or 1) / math.max(craftMult, 0.1)))
end

local function maxAffordable(recipeId)
	local recipe = recipeId and WorkbenchConfig.RECIPES[recipeId]
	if not recipe or not inventorySnapshot then return 0 end
	local costs = {}
	for _, ingredient in ipairs(recipe.Ingredients or {}) do
		costs[ingredient.Id] = (costs[ingredient.Id] or 0) + ingredientCost(ingredient)
	end
	local maximum = MAX_CRAFT_QUANTITY
	for id, cost in pairs(costs) do
		maximum = math.min(maximum, math.floor(getItemCount(id) / cost))
	end
	return maximum
end

local function canCraftRecipe(recipeId, quantity)
	quantity = quantity or 1
	return quantity >= 1 and quantity <= MAX_CRAFT_QUANTITY
		and quantity % 1 == 0 and quantity <= maxAffordable(recipeId)
end

local function craftDuration(recipeId, quantity)
	local recipe = recipeId and WorkbenchConfig.RECIPES[recipeId]
	if not recipe then return 0 end
	local multiplier = WorkbenchConfig:GetEffectiveStationModifiers(recipe, "Hand")
	return math.max(0.05, (tonumber(recipe.BaseCraftTime) or 0) * multiplier) * quantity
end

local function formatDuration(seconds)
	if seconds < 60 then return string.format("%.1fs", seconds) end
	local rounded = math.floor(seconds + 0.5)
	return string.format("%dm %02ds", math.floor(rounded / 60), rounded % 60)
end

local function outputDescription(recipeId, quantity)
	local recipe = WorkbenchConfig.RECIPES[recipeId]
	local output = recipe and recipe.Output or { Id = recipeId, N = 1 }
	local item = ItemDatabase:Get(output.Id)
	return string.format("%d × %s", (output.N or 1) * quantity, item and item.Name or output.Id)
end

local function createIngredientDisplay(ingredient, parent)
	local needed = ingredientCost(ingredient)
	local have = getItemCount(ingredient.Id)
	local item = ItemDatabase:Get(ingredient.Id)
	local name = item and item.Name or ingredient.Id
	local canAfford = have >= needed
	
	local frame = Instance.new("Frame")
	frame:SetAttribute("IngredientId", ingredient.Id)
	frame.Size = UDim2.new(0, 80, 0, 44)
	frame.BackgroundColor3 = COLORS.SlotEmpty
	frame.BackgroundTransparency = 0.5
	frame.BorderSizePixel = 0
	frame.ZIndex = 13
	frame.Parent = parent
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame
	
	-- Item name/icon
	local itemLabel = Instance.new("TextLabel")
	itemLabel.Name = "ItemName"
	itemLabel.Size = UDim2.new(1, -8, 0, 30)
	itemLabel.Position = UDim2.new(0, 2, 0, 3)
	itemLabel.BackgroundTransparency = 1
	itemLabel.Text = name
	itemLabel.TextColor3 = canAfford and COLORS.Text or COLORS.Danger
	itemLabel.TextSize = 10
	itemLabel.Font = Enum.Font.GothamBold
	itemLabel.TextWrapped = true
	itemLabel.ZIndex = 14
	itemLabel.Parent = frame
	
	-- Count display
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "Count"
	countLabel.Size = UDim2.new(1, -4, 0, 18)
	countLabel.Position = UDim2.new(0, 2, 0, 33)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = string.format("%d/%d", have, needed)
	countLabel.TextColor3 = canAfford and COLORS.Success or COLORS.Warning
	countLabel.TextSize = 11
	countLabel.Font = Enum.Font.Gotham
	countLabel.ZIndex = 14
	countLabel.Parent = frame
	
	return frame
end

local recipeCards = {}

local function createRecipeCard(recipeId, recipeData)
	local ingredients = recipeData.Ingredients or {}
	local output = recipeData.Output or { Id = recipeId, N = 1 }
	
	local item = ItemDatabase:Get(output.Id)
	local name = item and item.Name or output.Id
	local canCraft = canCraftRecipe(recipeId)
	local outputCount = output.N or 1
	
	local card = Instance.new("TextButton")
	card.Name = recipeId
	card.Size = UDim2.new(1, -12, 0, 38 + math.max(1, math.ceil(#ingredients / 3)) * 54)
	card.BackgroundColor3 = COLORS.SlotFilled
	card.BorderSizePixel = 0
	card.Text = ""
	card.AutoButtonColor = false
	card.ZIndex = 12
	card.Parent = recipeContainer
	Theme.Button(card)
	
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card
	
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Name = "Stroke"
	cardStroke.Color = COLORS.Border
	cardStroke.Thickness = 1
	cardStroke.Transparency = 0.5
	cardStroke.Parent = card
	
	-- Result item name (with output count if > 1)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, -102, 0, 22)
	nameLabel.Position = UDim2.new(0, 10, 0, 6)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = outputCount > 1 and string.format("%s x%d", name, outputCount) or name
	nameLabel.TextColor3 = COLORS.Text
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.ZIndex = 13
	nameLabel.Parent = card
	
	-- Craftable indicator
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(0, 80, 0, 18)
	statusLabel.AnchorPoint = Vector2.new(1, 0)
	statusLabel.Position = UDim2.new(1, -10, 0, 8)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = canCraft and "READY" or "MISSING"
	statusLabel.TextColor3 = canCraft and COLORS.Success or COLORS.Danger
	statusLabel.TextSize = 11
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextXAlignment = Enum.TextXAlignment.Right
	statusLabel.ZIndex = 13
	statusLabel.Parent = card
	
	-- Ingredients container
	local ingredientsFrame = Instance.new("Frame")
	ingredientsFrame.Name = "Ingredients"
	ingredientsFrame.Size = UDim2.new(1, -20, 0, math.max(1, math.ceil(#ingredients / 3)) * 54)
	ingredientsFrame.Position = UDim2.new(0, 10, 0, 32)
	ingredientsFrame.BackgroundTransparency = 1
	ingredientsFrame.ZIndex = 13
	ingredientsFrame.Parent = card
	
	local ingredientLayout = Instance.new("UIGridLayout")
	ingredientLayout.FillDirection = Enum.FillDirection.Horizontal
	ingredientLayout.FillDirectionMaxCells = 3
	ingredientLayout.CellSize = UDim2.new(1 / 3, -4, 0, 50)
	ingredientLayout.CellPadding = UDim2.fromOffset(4, 4)
	ingredientLayout.SortOrder = Enum.SortOrder.LayoutOrder
	ingredientLayout.Parent = ingredientsFrame
	
	-- Add ingredient displays
	for _, ingredient in ipairs(ingredients) do
		createIngredientDisplay(ingredient, ingredientsFrame)
	end
	
	-- Interactions
	card.MouseEnter:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.12), {BackgroundColor3 = COLORS.SlotHover}):Play()
	end)
	
	card.MouseLeave:Connect(function()
		local isSelected = selectedRecipe == recipeId
		local targetColor = isSelected and COLORS.SlotSelected or COLORS.SlotFilled
		TweenService:Create(card, TweenInfo.new(0.12), {BackgroundColor3 = targetColor}):Play()
	end)
	
	card.MouseButton1Click:Connect(function()
		if isCraftPending then return end
		-- Deselect previous
		if selectedRecipe and recipeCards[selectedRecipe] then
			local prevCard = recipeCards[selectedRecipe]
			prevCard.Stroke.Color = COLORS.Border
			prevCard.Stroke.Thickness = 1
			prevCard.BackgroundColor3 = COLORS.SlotFilled
		end
		
		-- Select this one
		if selectedRecipe ~= recipeId then
			craftQuantity = 1
			quantityBox.Text = "1"
		end
		selectedRecipe = recipeId
		cardStroke.Color = COLORS.SlotSelected
		cardStroke.Thickness = 2
		card.BackgroundColor3 = COLORS.SlotSelected
		
		-- Update craft button
		updateCraftButton()
	end)
	
	recipeCards[recipeId] = card
	return card
end

local function updateRecipeCard(card, recipeId)
	local recipe = WorkbenchConfig.RECIPES[recipeId]
	local quantity = 1
	if selectedRecipe == recipeId then quantity = craftQuantity end
	local affordable = quantity ~= nil and canCraftRecipe(recipeId, quantity)
	card:FindFirstChild("Name").Text = outputDescription(recipeId, quantity or 1)
	card.Status.Text = quantity == nil and "SET BATCHES" or (affordable and "READY" or "MISSING")
	card.Status.TextColor3 = affordable and COLORS.Success or COLORS.Danger
	for _, frame in ipairs(card.Ingredients:GetChildren()) do
		local id = frame:GetAttribute("IngredientId")
		if id then
			local cost = 0
			for _, ingredient in ipairs(recipe.Ingredients or {}) do
				if ingredient.Id == id then cost += ingredientCost(ingredient) end
			end
			local needed = cost * (quantity or 1)
			local have = getItemCount(id)
			frame.ItemName.TextColor3 = have >= needed and COLORS.Text or COLORS.Danger
			frame.Count.Text = string.format("%d / %d", have, needed)
			frame.Count.TextColor3 = have >= needed and COLORS.Success or COLORS.Warning
		end
	end
	local selected = selectedRecipe == recipeId
	card.Stroke.Color = selected and COLORS.SlotSelected or COLORS.Border
	card.Stroke.Thickness = selected and 2 or 1
	card.BackgroundColor3 = selected and COLORS.SlotSelected or COLORS.SlotFilled
end

local function setControlEnabled(button, enabled)
	button.Active = enabled
	button.Selectable = enabled
	button.TextColor3 = enabled and COLORS.Text or COLORS.TextMuted
	button.BackgroundTransparency = enabled and 0 or 0.5
end

local function updateCraftProgress()
	if not isCraftPending then return end
	if not pendingConfirmed then
		progressFill.Size = UDim2.fromScale(0, 1)
		batchTime.Text = string.format("%d %s · %s total · preparing…", pendingQuantity,
			pendingQuantity == 1 and "batch" or "batches", formatDuration(pendingDuration))
		return
	end
	local elapsed = math.max(0, os.clock() - pendingStartedAt)
	local progress = math.clamp(elapsed / math.max(0.05, pendingDuration), 0, 1)
	progressFill.Size = UDim2.fromScale(progress, 1)
	local remaining = math.max(0, pendingDuration - elapsed)
	batchTime.Text = string.format("%d %s · %s / %s%s", pendingQuantity, pendingQuantity == 1 and "batch" or "batches",
		formatDuration(math.min(elapsed, pendingDuration)), formatDuration(pendingDuration),
		remaining == 0 and " · finishing…" or "")
end

function updateCraftButton()
	local available = maxAffordable(selectedRecipe)
	local editable = selectedRecipe ~= nil and not isCraftPending
	quantityBox.TextEditable = editable
	quantityBox.TextColor3 = editable and COLORS.Text or COLORS.TextMuted
	quantityStroke.Color = craftQuantity == nil and COLORS.Danger or COLORS.Border
	setControlEnabled(decreaseBtn, editable and (craftQuantity == nil or craftQuantity > 1))
	setControlEnabled(increaseBtn, editable and craftQuantity ~= nil and craftQuantity < available)
	setControlEnabled(maxBtn, editable and available > 0)
	maxBtn.Text = string.format("Max (%d)", available)
	for recipeId, card in pairs(recipeCards) do updateRecipeCard(card, recipeId) end
	craftBtn.Active = false
	craftBtn.Selectable = false
	progressTrack.Visible = isCraftPending
	if not isCraftPending then progressFill.Size = UDim2.fromScale(0, 1) end
	if isCraftPending then
		craftBtn.Text = (pendingConfirmed and "Crafting " or "Preparing ") .. pendingOutput
		craftBtn.TextColor3 = COLORS.Paper
		craftBtn.BackgroundColor3 = COLORS.Accent
		craftBtnStroke.Color = COLORS.Accent
		batchSummary.Text = "Output: " .. pendingOutput
		updateCraftProgress()
		return
	end
	if not selectedRecipe then
		craftBtn.Text = "Select a Recipe"
		craftBtn.TextColor3 = COLORS.TextMuted
		craftBtn.BackgroundColor3 = COLORS.SlotEmpty
		craftBtnStroke.Color = COLORS.Border
		batchSummary.Text = "Choose a recipe to set its batch size"
		batchTime.Text = "Each batch repeats the recipe once"
		return
	end
	if not craftQuantity then
		craftBtn.Text = "Enter 1–99 whole batches"
		craftBtn.TextColor3 = COLORS.TextMuted
		craftBtn.BackgroundColor3 = COLORS.SlotEmpty
		craftBtnStroke.Color = COLORS.Danger
		batchSummary.Text = "Batch size must be a whole number from 1 to 99"
		batchTime.Text = ""
		return
	end
	local output = outputDescription(selectedRecipe, craftQuantity)
	local recipe = WorkbenchConfig.RECIPES[selectedRecipe]
	local _, bonus = WorkbenchConfig:GetEffectiveStationModifiers(recipe, "Hand")
	batchSummary.Text = "Output: " .. output
	batchTime.Text = string.format("%d %s · %s total%s", craftQuantity, craftQuantity == 1 and "batch" or "batches",
		formatDuration(craftDuration(selectedRecipe, craftQuantity)), bonus > 0 and " · bonus yield possible" or "")
	local affordable = canCraftRecipe(selectedRecipe, craftQuantity)
	craftBtn.Active = affordable
	craftBtn.Selectable = affordable
	craftBtn.Text = affordable and ("Craft " .. output) or "Missing Materials"
	craftBtn.TextColor3 = COLORS.Paper
	craftBtn.BackgroundColor3 = affordable and COLORS.SuccessFill or COLORS.DangerFill
	craftBtnStroke.Color = affordable and COLORS.Success or COLORS.Danger
end

quantityBox:GetPropertyChangedSignal("Text"):Connect(function()
	local parsed = tonumber(quantityBox.Text)
	craftQuantity = parsed and parsed >= 1 and parsed <= MAX_CRAFT_QUANTITY and parsed % 1 == 0 and parsed or nil
	updateCraftButton()
end)
local function setQuantity(quantity)
	if isCraftPending or not selectedRecipe then return end
	quantityBox.Text = tostring(math.clamp(quantity, 1, MAX_CRAFT_QUANTITY))
	updateCraftButton()
end
decreaseBtn.Activated:Connect(function()
	if decreaseBtn.Active then setQuantity((craftQuantity or 2) - 1) end
end)
increaseBtn.Activated:Connect(function()
	if increaseBtn.Active then setQuantity((craftQuantity or 1) + 1) end
end)
maxBtn.Activated:Connect(function()
	if maxBtn.Active then setQuantity(maxAffordable(selectedRecipe)) end
end)
quantityBox.FocusLost:Connect(function()
	if craftQuantity then quantityBox.Text = tostring(craftQuantity) end
end)
player:GetAttributeChangedSignal("Role_Craft"):Connect(updateCraftButton)
local progressTick = 0
game:GetService("RunService").Heartbeat:Connect(function(delta)
	progressTick += delta
	if progressTick < 0.05 then return end
	progressTick = 0
	if isOpen and isCraftPending then updateCraftProgress() end
end)

local function refreshRecipes()
	-- Clear existing cards
	for _, card in pairs(recipeCards) do
		card:Destroy()
	end
	recipeCards = {}
	
	-- Debug: Check if recipes exist
	print("[CraftingUI] Refreshing hand-crafting recipes...")
	local recipeCount = 0
	
	-- Get hand-craftable recipes from WorkbenchConfig (tier 0 only)
	local handRecipes = WorkbenchConfig:GetHandRecipes()
	for recipeId, recipe in pairs(handRecipes) do
		recipeCount = recipeCount + 1
		print(string.format("[CraftingUI] Found hand recipe: %s", recipeId))
		createRecipeCard(recipeId, recipe)
	end
	
	print(string.format("[CraftingUI] Total hand recipes: %d", recipeCount))
	print("[CraftingUI] Tip: Build a Workbench for more recipes!")
	
	-- Update canvas size after a frame to let layout calculate
	task.defer(function()
		recipeContainer.CanvasSize = UDim2.new(0, 0, 0, recipeLayout.AbsoluteContentSize.Y + 12)
	end)
	
	-- Update craft button
	updateCraftButton()
end

local function openCrafting()
	if isOpen then return end
	isOpen = true
	if isCraftPending then
		selectedRecipe = pendingRecipeId
		craftQuantity = pendingQuantity
		quantityBox.Text = tostring(pendingQuantity)
	end
	
	backdrop.Visible = true
	mainPanel.Visible = true
	
	-- Animate in
	backdrop.BackgroundTransparency = 1
	mainPanel.Position = UDim2.new(0.5, 0, 0.5, 30)
	mainPanel.GroupTransparency = 1
	
	TweenService:Create(backdrop, TweenInfo.new(0.2), {BackgroundTransparency = 0.5}):Play()
	TweenService:Create(mainPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		GroupTransparency = 0
	}):Play()
	
	refreshRecipes()
	if isCraftPending then
		showInlineStatus("Crafting...", COLORS.Accent)
	else
		showInlineStatus(nil)
	end
end

local function closeCrafting()
	if not isOpen then return end
	isOpen = false
	selectedRecipe = nil
	
	-- Animate out
	TweenService:Create(backdrop, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
	local closeTween = TweenService:Create(mainPanel, TweenInfo.new(0.15), {
		Position = UDim2.new(0.5, 0, 0.5, 20),
		GroupTransparency = 1
	})
	closeTween:Play()
	closeTween.Completed:Connect(function()
		if not isOpen then
			backdrop.Visible = false
			mainPanel.Visible = false
		end
	end)
end

-- Button events
closeBtn.MouseButton1Click:Connect(closeCrafting)
backdrop.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		closeCrafting()
	end
end)

craftBtn.MouseButton1Click:Connect(function()
	if isCraftPending then return end
	if not selectedRecipe then return end
	if not craftQuantity or not canCraftRecipe(selectedRecipe, craftQuantity) then return end
	if not rCraft then return end
	
	isCraftPending = true
	pendingRequestToken += 1
	local requestToken = pendingRequestToken
	pendingRecipeId = selectedRecipe
	pendingStationType = "Hand"
	pendingQuantity = craftQuantity
	pendingOutput = outputDescription(selectedRecipe, craftQuantity)
	pendingDuration = craftDuration(selectedRecipe, craftQuantity)
	pendingStartedAt = os.clock()
	pendingConfirmed = false
	updateCraftButton()
	showInlineStatus("Crafting...", COLORS.Accent)
	
	-- Send craft request (Hand crafting)
	rCraft:FireServer(selectedRecipe, "Hand", craftQuantity)
	
	task.delay(math.max(8, pendingDuration + 8), function()
		if not isCraftPending then return end
		if requestToken ~= pendingRequestToken then return end
		isCraftPending = false
		pendingRequestToken += 1
		updateCraftButton()
		showInlineStatus("Request timed out", COLORS.Warning, 2)
	end)
end)

-- Keyboard toggle (C key)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.C then
		if isOpen then
			closeCrafting()
		else
			openCrafting()
		end
	elseif input.KeyCode == Enum.KeyCode.Escape and isOpen then
		closeCrafting()
	end
end)

if rCraft then
	rCraft.OnClientEvent:Connect(function(kind, payload)
		if type(payload) ~= "table" then return end
		if not isCraftPending or payload.RecipeId ~= pendingRecipeId or payload.StationType ~= pendingStationType then return end
		if kind == "Started" then
			pendingConfirmed = true
			if type(payload.Duration) == "number" then pendingDuration = payload.Duration end
			pendingStartedAt = os.clock()
			showInlineStatus("Crafting...", COLORS.Accent)
			updateCraftButton()
			return
		end
		if kind ~= "Result" then return end
		if payload.StationType and payload.StationType ~= "Hand" then return end
		local success = payload.Success == true
		if isCraftPending then
			isCraftPending = false
			pendingRequestToken += 1
		end
		updateCraftButton()
		local reason = payload.Reason or (success and "Success" or "Unknown")
		local resultMessage = messageForReason(reason)
		if success and type(payload.Extra) == "table" and type(payload.Extra.OutputCount) == "number" then
			local outputItem = ItemDatabase:Get(payload.Extra.OutputId)
			resultMessage = string.format("Crafted %d × %s", payload.Extra.OutputCount,
				outputItem and outputItem.Name or tostring(payload.Extra.OutputId))
		end
		showInlineStatus(resultMessage, success and COLORS.Success or COLORS.Danger, success and 1.2 or 1.8)
		if isOpen then
			refreshRecipes()
		end
	end)
end

-- Inventory sync - MUST be set up early to catch initial snapshot
if rInventory then
	rInventory.OnClientEvent:Connect(function(kind, payload)
		if kind ~= "Snapshot" or type(payload) ~= "table" then return end
		
		-- Normalize keys (Roblox can convert numeric keys to strings)
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
		print("[CraftingUI] Inventory snapshot received")
		
		if isOpen then
			refreshRecipes()
		end
	end)
	print("[CraftingUI] Listening for inventory updates")
	task.defer(function()
		pcall(function()
			rInventory:FireServer("RequestSnapshot")
		end)
	end)
end

print("[CraftingUI] Ready - Press C for hand crafting (basic items)")
print("[CraftingUI] Place workbenches for advanced recipes!")

Theme.Panel(mainPanel)
Theme.Fit(mainPanel, 452, 610)
Theme.Button(closeBtn)
Theme.Button(craftBtn)
updateCraftButton()
player:GetAttributeChangedSignal("FieldKitCraft"):Connect(function()
 if isOpen then closeCrafting() else openCrafting() end
end)
