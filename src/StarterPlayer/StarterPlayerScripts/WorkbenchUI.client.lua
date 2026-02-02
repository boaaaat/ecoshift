-- WorkbenchUI.client.lua
-- Crafting interface for placed workbenches and crafting stations
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)
local WorkbenchConfig = require(ReplicatedStorage.Shared.WorkbenchConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = Util.GetDescendant(Config.Paths.Remotes) 
	or Util.WaitForDescendant(Config.Paths.Remotes, 5)
local rCraft = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.Craft)
local rInventory = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.InventoryUpdate)

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
	Tier1 = Color3.fromRGB(150, 150, 150),  -- Basic workbench
	Tier2 = Color3.fromRGB(100, 180, 255),  -- Advanced
	Tier3 = Color3.fromRGB(255, 200, 80),   -- Master
	Special = Color3.fromRGB(180, 100, 255), -- Furnace, Anvil, etc.
}

local MARGIN = 16
local RECIPE_HEIGHT = 90

-- State
local isOpen = false
local inventorySnapshot = nil
local selectedRecipe = nil
local currentStation = nil
local currentStationType = nil

-- Create main GUI
local gui = Instance.new("ScreenGui")
gui.Name = "WorkbenchUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Backdrop
local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 1
backdrop.BorderSizePixel = 0
backdrop.Visible = false
backdrop.ZIndex = 1
backdrop.Parent = gui

-- Main panel
local mainPanel = Instance.new("CanvasGroup")
mainPanel.Name = "MainPanel"
mainPanel.Size = UDim2.new(0, 500, 0, 550)
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

-- Header
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 60)
header.BackgroundTransparency = 1
header.ZIndex = 11
header.Parent = mainPanel

local stationIcon = Instance.new("TextLabel")
stationIcon.Name = "Icon"
stationIcon.Size = UDim2.new(0, 40, 0, 40)
stationIcon.Position = UDim2.new(0, MARGIN, 0.5, 0)
stationIcon.AnchorPoint = Vector2.new(0, 0.5)
stationIcon.BackgroundTransparency = 1
stationIcon.Text = "🔨"
stationIcon.TextColor3 = COLORS.Text
stationIcon.TextSize = 28
stationIcon.Font = Enum.Font.GothamBold
stationIcon.ZIndex = 11
stationIcon.Parent = header

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -120, 0, 24)
titleLabel.Position = UDim2.new(0, MARGIN + 48, 0, 10)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Workbench"
titleLabel.TextColor3 = COLORS.Text
titleLabel.TextSize = 20
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 11
titleLabel.Parent = header

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Name = "Subtitle"
subtitleLabel.Size = UDim2.new(1, -120, 0, 18)
subtitleLabel.Position = UDim2.new(0, MARGIN + 48, 0, 34)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Text = "Craft tools and equipment"
subtitleLabel.TextColor3 = COLORS.TextMuted
subtitleLabel.TextSize = 12
subtitleLabel.Font = Enum.Font.Gotham
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
subtitleLabel.ZIndex = 11
subtitleLabel.Parent = header

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.AnchorPoint = Vector2.new(1, 0.5)
closeBtn.Position = UDim2.new(1, -MARGIN, 0.5, 0)
closeBtn.BackgroundColor3 = COLORS.SlotEmpty
closeBtn.BorderSizePixel = 0
closeBtn.Text = "✕"
closeBtn.TextColor3 = COLORS.TextMuted
closeBtn.TextSize = 18
closeBtn.Font = Enum.Font.GothamBold
closeBtn.ZIndex = 12
closeBtn.Parent = header

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 8)
closeBtnCorner.Parent = closeBtn

-- Category tabs
local categoryBar = Instance.new("Frame")
categoryBar.Name = "CategoryBar"
categoryBar.Size = UDim2.new(1, -MARGIN * 2, 0, 32)
categoryBar.Position = UDim2.new(0, MARGIN, 0, 65)
categoryBar.BackgroundTransparency = 1
categoryBar.ZIndex = 11
categoryBar.Parent = mainPanel

local categoryLayout = Instance.new("UIListLayout")
categoryLayout.FillDirection = Enum.FillDirection.Horizontal
categoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
categoryLayout.Padding = UDim.new(0, 4)
categoryLayout.Parent = categoryBar

local selectedCategory = "All"
local categoryButtons = {}

-- Recipe list container
local recipeContainer = Instance.new("ScrollingFrame")
recipeContainer.Name = "RecipeList"
recipeContainer.Size = UDim2.new(1, -MARGIN * 2, 1, -180)
recipeContainer.Position = UDim2.new(0, MARGIN, 0, 105)
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

-- Craft button
local craftBtn = Instance.new("TextButton")
craftBtn.Name = "CraftButton"
craftBtn.Size = UDim2.new(1, -MARGIN * 2, 0, 50)
craftBtn.Position = UDim2.new(0, MARGIN, 1, -65)
craftBtn.BackgroundColor3 = COLORS.SlotEmpty
craftBtn.BorderSizePixel = 0
craftBtn.Text = "Select a Recipe"
craftBtn.TextColor3 = COLORS.TextMuted
craftBtn.TextSize = 16
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

-- Helper functions
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

local function canCraftRecipe(recipeId)
	local recipe = WorkbenchConfig.RECIPES[recipeId]
	if not recipe then return false end
	
	local craftMult = tonumber(player:GetAttribute("Role_Craft")) or 1.0
	local ingredients = recipe.Ingredients or {}
	
	for _, ingredient in ipairs(ingredients) do
		local needed = math.max(1, math.floor((ingredient.N or 1) / math.max(craftMult, 0.1)))
		local have = getItemCount(ingredient.Id)
		if have < needed then
			return false
		end
	end
	return true
end

local function getTierColor(recipe)
	if recipe.StationType then
		return COLORS.Special
	end
	local tier = recipe.StationTier or 0
	if tier <= 0 then return COLORS.TextMuted end
	if tier == 1 then return COLORS.Tier1 end
	if tier == 2 then return COLORS.Tier2 end
	return COLORS.Tier3
end

local function createIngredientDisplay(ingredient, parent, craftMult)
	local needed = math.max(1, math.floor((ingredient.N or 1) / math.max(craftMult, 0.1)))
	local have = getItemCount(ingredient.Id)
	local item = ItemDatabase:Get(ingredient.Id)
	local name = item and item.Name or ingredient.Id
	local canAfford = have >= needed
	
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 70, 0, 36)
	frame.BackgroundColor3 = COLORS.SlotEmpty
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.ZIndex = 13
	frame.Parent = parent
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = frame
	
	local itemLabel = Instance.new("TextLabel")
	itemLabel.Size = UDim2.new(1, -4, 0, 16)
	itemLabel.Position = UDim2.new(0, 2, 0, 2)
	itemLabel.BackgroundTransparency = 1
	itemLabel.Text = name
	itemLabel.TextColor3 = canAfford and COLORS.Text or COLORS.Danger
	itemLabel.TextSize = 10
	itemLabel.Font = Enum.Font.GothamBold
	itemLabel.TextTruncate = Enum.TextTruncate.AtEnd
	itemLabel.ZIndex = 14
	itemLabel.Parent = frame
	
	local countLabel = Instance.new("TextLabel")
	countLabel.Size = UDim2.new(1, -4, 0, 14)
	countLabel.Position = UDim2.new(0, 2, 0, 18)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = string.format("%d / %d", have, needed)
	countLabel.TextColor3 = canAfford and COLORS.Success or COLORS.Warning
	countLabel.TextSize = 10
	countLabel.Font = Enum.Font.Gotham
	countLabel.ZIndex = 14
	countLabel.Parent = frame
	
	return frame
end

local recipeCards = {}

local function createRecipeCard(recipeId, recipe)
	local output = recipe.Output or { Id = recipeId, N = 1 }
	local item = ItemDatabase:Get(output.Id)
	local name = item and item.Name or output.Id
	local canCraft = canCraftRecipe(recipeId)
	local craftMult = tonumber(player:GetAttribute("Role_Craft")) or 1.0
	local outputCount = output.N or 1
	
	local card = Instance.new("TextButton")
	card.Name = recipeId
	card.Size = UDim2.new(1, -12, 0, RECIPE_HEIGHT)
	card.BackgroundColor3 = COLORS.SlotFilled
	card.BorderSizePixel = 0
	card.Text = ""
	card.AutoButtonColor = false
	card.ZIndex = 12
	card.Parent = recipeContainer
	
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card
	
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Name = "Stroke"
	cardStroke.Color = COLORS.Border
	cardStroke.Thickness = 1
	cardStroke.Transparency = 0.5
	cardStroke.Parent = card
	
	-- Output item name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(0.6, 0, 0, 22)
	nameLabel.Position = UDim2.new(0, 12, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = outputCount > 1 and string.format("%s x%d", name, outputCount) or name
	nameLabel.TextColor3 = COLORS.Text
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 13
	nameLabel.Parent = card
	
	-- Category tag
	local categoryTag = Instance.new("TextLabel")
	categoryTag.Name = "Category"
	categoryTag.Size = UDim2.new(0, 80, 0, 16)
	categoryTag.Position = UDim2.new(0, 12, 0, 28)
	categoryTag.BackgroundTransparency = 1
	categoryTag.Text = recipe.Category or "Misc"
	categoryTag.TextColor3 = getTierColor(recipe)
	categoryTag.TextSize = 10
	categoryTag.Font = Enum.Font.Gotham
	categoryTag.TextXAlignment = Enum.TextXAlignment.Left
	categoryTag.ZIndex = 13
	categoryTag.Parent = card
	
	-- Status indicator
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(0, 90, 0, 20)
	statusLabel.AnchorPoint = Vector2.new(1, 0)
	statusLabel.Position = UDim2.new(1, -12, 0, 10)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = canCraft and "✓ Ready" or "✗ Missing"
	statusLabel.TextColor3 = canCraft and COLORS.Success or COLORS.Danger
	statusLabel.TextSize = 12
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextXAlignment = Enum.TextXAlignment.Right
	statusLabel.ZIndex = 13
	statusLabel.Parent = card
	
	-- Ingredients container
	local ingredientsFrame = Instance.new("Frame")
	ingredientsFrame.Name = "Ingredients"
	ingredientsFrame.Size = UDim2.new(1, -24, 0, 40)
	ingredientsFrame.Position = UDim2.new(0, 12, 0, 44)
	ingredientsFrame.BackgroundTransparency = 1
	ingredientsFrame.ClipsDescendants = true
	ingredientsFrame.ZIndex = 13
	ingredientsFrame.Parent = card
	
	local ingredientLayout = Instance.new("UIListLayout")
	ingredientLayout.FillDirection = Enum.FillDirection.Horizontal
	ingredientLayout.SortOrder = Enum.SortOrder.LayoutOrder
	ingredientLayout.Padding = UDim.new(0, 4)
	ingredientLayout.Parent = ingredientsFrame
	
	for _, ingredient in ipairs(recipe.Ingredients or {}) do
		createIngredientDisplay(ingredient, ingredientsFrame, craftMult)
	end
	
	-- Interactions
	card.MouseEnter:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.12), {BackgroundColor3 = COLORS.SlotHover}):Play()
	end)
	
	card.MouseLeave:Connect(function()
		local isSelected = selectedRecipe == recipeId
		TweenService:Create(card, TweenInfo.new(0.12), {
			BackgroundColor3 = isSelected and COLORS.SlotSelected or COLORS.SlotFilled
		}):Play()
	end)
	
	card.MouseButton1Click:Connect(function()
		if selectedRecipe and recipeCards[selectedRecipe] then
			local prevCard = recipeCards[selectedRecipe]
			prevCard.Stroke.Color = COLORS.Border
			prevCard.Stroke.Thickness = 1
			prevCard.BackgroundColor3 = COLORS.SlotFilled
		end
		
		selectedRecipe = recipeId
		cardStroke.Color = COLORS.SlotSelected
		cardStroke.Thickness = 2
		card.BackgroundColor3 = COLORS.SlotSelected
		
		updateCraftButton()
	end)
	
	recipeCards[recipeId] = card
	return card
end

local function createCategoryButton(category, layoutOrder)
	local isAll = category == "All"
	local isSelected = selectedCategory == category
	
	local btn = Instance.new("TextButton")
	btn.Name = category
	btn.Size = UDim2.new(0, isAll and 50 or 70, 1, 0)
	btn.LayoutOrder = layoutOrder
	btn.BackgroundColor3 = isSelected and COLORS.Accent or COLORS.SlotEmpty
	btn.BorderSizePixel = 0
	btn.Text = category
	btn.TextColor3 = isSelected and COLORS.Text or COLORS.TextMuted
	btn.TextSize = 11
	btn.Font = Enum.Font.GothamBold
	btn.AutoButtonColor = false
	btn.ZIndex = 12
	btn.Parent = categoryBar
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn
	
	btn.MouseButton1Click:Connect(function()
		if selectedCategory == category then return end
		
		-- Deselect previous
		if categoryButtons[selectedCategory] then
			local prev = categoryButtons[selectedCategory]
			prev.BackgroundColor3 = COLORS.SlotEmpty
			prev.TextColor3 = COLORS.TextMuted
		end
		
		selectedCategory = category
		btn.BackgroundColor3 = COLORS.Accent
		btn.TextColor3 = COLORS.Text
		
		refreshRecipes()
	end)
	
	categoryButtons[category] = btn
	return btn
end

function updateCraftButton()
	if not selectedRecipe then
		craftBtn.Text = "Select a Recipe"
		craftBtn.TextColor3 = COLORS.TextMuted
		craftBtn.BackgroundColor3 = COLORS.SlotEmpty
		craftBtnStroke.Color = COLORS.Border
		return
	end
	
	local recipe = WorkbenchConfig.RECIPES[selectedRecipe]
	if not recipe then return end
	
	local output = recipe.Output or { Id = selectedRecipe, N = 1 }
	local item = ItemDatabase:Get(output.Id)
	local name = item and item.Name or output.Id
	local canCraft = canCraftRecipe(selectedRecipe)
	
	if canCraft then
		craftBtn.Text = "Craft " .. name
		craftBtn.TextColor3 = COLORS.Text
		craftBtn.BackgroundColor3 = COLORS.Success
		craftBtnStroke.Color = COLORS.Success
	else
		craftBtn.Text = "Missing Materials"
		craftBtn.TextColor3 = COLORS.Text
		craftBtn.BackgroundColor3 = COLORS.Danger
		craftBtnStroke.Color = COLORS.Danger
	end
end

function refreshRecipes()
	-- Clear existing cards
	for _, card in pairs(recipeCards) do
		card:Destroy()
	end
	recipeCards = {}
	
	if not currentStationType then return end
	
	-- Get recipes for this station
	local recipes = WorkbenchConfig:GetRecipesForStation(currentStationType)
	
	-- Filter by category
	for recipeId, recipe in pairs(recipes) do
		local matchesCategory = selectedCategory == "All" or recipe.Category == selectedCategory
		if matchesCategory then
			createRecipeCard(recipeId, recipe)
		end
	end
	
	task.defer(function()
		recipeContainer.CanvasSize = UDim2.new(0, 0, 0, recipeLayout.AbsoluteContentSize.Y + 12)
	end)
	
	updateCraftButton()
end

local function setupCategories()
	-- Clear existing
	for _, btn in pairs(categoryButtons) do
		btn:Destroy()
	end
	categoryButtons = {}
	
	-- Add "All" category
	createCategoryButton("All", 0)
	
	-- Add other categories
	for i, category in ipairs(WorkbenchConfig.CATEGORIES) do
		createCategoryButton(category, i)
	end
end

local function openWorkbench(station, stationType)
	if isOpen then return end
	
	currentStation = station
	currentStationType = stationType
	
	local stationDef = WorkbenchConfig.STATIONS[stationType]
	if stationDef then
		stationIcon.Text = stationDef.Icon or "🔨"
		titleLabel.Text = stationDef.Name or stationType
		subtitleLabel.Text = stationDef.Description or "Craft items"
		mainStroke.Color = getTierColor({ StationTier = stationDef.Tier, StationType = stationDef.Tier >= 10 and stationType or nil })
	end
	
	isOpen = true
	selectedRecipe = nil
	selectedCategory = "All"
	
	backdrop.Visible = true
	mainPanel.Visible = true
	
	backdrop.BackgroundTransparency = 1
	mainPanel.Position = UDim2.new(0.5, 0, 0.5, 30)
	mainPanel.GroupTransparency = 1
	
	TweenService:Create(backdrop, TweenInfo.new(0.2), {BackgroundTransparency = 0.5}):Play()
	TweenService:Create(mainPanel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		GroupTransparency = 0
	}):Play()
	
	setupCategories()
	refreshRecipes()
end

local function closeWorkbench()
	if not isOpen then return end
	isOpen = false
	selectedRecipe = nil
	currentStation = nil
	currentStationType = nil
	
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
closeBtn.MouseButton1Click:Connect(closeWorkbench)
backdrop.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		closeWorkbench()
	end
end)

craftBtn.MouseButton1Click:Connect(function()
	if not selectedRecipe then return end
	if not canCraftRecipe(selectedRecipe) then return end
	if not rCraft then return end
	
	-- Send craft request with station type
	rCraft:FireServer(selectedRecipe, currentStationType)
	
	-- Visual feedback
	craftBtn.BackgroundColor3 = COLORS.Accent
	task.delay(0.15, function()
		if canCraftRecipe(selectedRecipe) then
			craftBtn.BackgroundColor3 = COLORS.Success
		else
			craftBtn.BackgroundColor3 = COLORS.Danger
		end
	end)
end)

-- Escape to close
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape and isOpen then
		closeWorkbench()
	end
end)

-- Handle proximity prompts for workbenches
ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
	if playerWhoTriggered ~= player then return end
	
	local parent = prompt.Parent
	if not parent then return end
	
	-- Check if this is a crafting station
	local model = parent:FindFirstAncestorOfClass("Model") or parent
	local stationType = model:GetAttribute("StationType") or parent:GetAttribute("StationType")
	
	if stationType and WorkbenchConfig.STATIONS[stationType] then
		openWorkbench(model, stationType)
	end
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
		
		if isOpen then
			refreshRecipes()
		end
	end)
end

print("[WorkbenchUI] Ready - interact with placed workbenches to craft")
