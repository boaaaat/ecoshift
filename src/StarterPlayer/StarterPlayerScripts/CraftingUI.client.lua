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
local CRAFT_MESSAGES = ResultMessages.Craft or {}

-- State
local isOpen = false
local inventorySnapshot = nil
local selectedRecipe = nil
local isCraftPending = false
local pendingRequestToken = 0
local statusToken = 0

-- Create main GUI
local gui = Instance.new("ScreenGui")
gui.Name = "CraftingUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 20
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
mainPanel.Size = UDim2.new(0, 452, 0, 530)
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
recipeContainer.Size = UDim2.new(1, -MARGIN * 2, 1, -130)
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

-- Craft button at bottom
local craftBtn = Instance.new("TextButton")
craftBtn.Name = "CraftButton"
craftBtn.Size = UDim2.new(1, -MARGIN * 2, 0, 50)
craftBtn.Position = UDim2.new(0, MARGIN, 1, -65)
craftBtn.AnchorPoint = Vector2.new(0, 0)
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

local inlineStatusLabel = Instance.new("TextLabel")
inlineStatusLabel.Name = "InlineStatus"
inlineStatusLabel.Size = UDim2.new(1, -MARGIN * 2, 0, 16)
inlineStatusLabel.AnchorPoint = Vector2.new(0, 1)
inlineStatusLabel.Position = UDim2.new(0, MARGIN, 1, -6)
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

local function beginCraftPending()
	isCraftPending = true
	pendingRequestToken += 1
	local token = pendingRequestToken
	craftBtn.Text = "Crafting..."
	craftBtn.TextColor3 = COLORS.Paper
	craftBtn.BackgroundColor3 = COLORS.Accent
	craftBtnStroke.Color = COLORS.Accent
	return token
end

local function getCraftRequestTimeout(recipeId)
	local recipe = recipeId and WorkbenchConfig.RECIPES[recipeId] or nil
	local baseTime = recipe and tonumber(recipe.BaseCraftTime) or 0
	return math.max(8, baseTime + 5)
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

local function canCraftRecipe(recipeId)
	local recipe = WorkbenchConfig.RECIPES[recipeId]
	if not recipe then return false end
	local craftMult = tonumber(player:GetAttribute("Role_Craft")) or 1.0
	for _, ingredient in ipairs(recipe.Ingredients or {}) do
		local needed = math.max(1, math.floor((ingredient.N or 1) / math.max(craftMult, 0.1)))
		local have = getItemCount(ingredient.Id)
		if have < needed then
			return false
		end
	end
	return true
end

local function createIngredientDisplay(ingredient, parent, craftMult)
	local needed = math.max(1, math.floor((ingredient.N or 1) / math.max(craftMult, 0.1)))
	local have = getItemCount(ingredient.Id)
	local item = ItemDatabase:Get(ingredient.Id)
	local name = item and item.Name or ingredient.Id
	local canAfford = have >= needed
	
	local frame = Instance.new("Frame")
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
	local craftMult = tonumber(player:GetAttribute("Role_Craft")) or 1.0
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
		createIngredientDisplay(ingredient, ingredientsFrame, craftMult)
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
		-- Deselect previous
		if selectedRecipe and recipeCards[selectedRecipe] then
			local prevCard = recipeCards[selectedRecipe]
			prevCard.Stroke.Color = COLORS.Border
			prevCard.Stroke.Thickness = 1
			prevCard.BackgroundColor3 = COLORS.SlotFilled
		end
		
		-- Select this one
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

function updateCraftButton()
	if isCraftPending then
		craftBtn.Text = "Crafting..."
		craftBtn.TextColor3 = COLORS.Paper
		craftBtn.BackgroundColor3 = COLORS.Accent
		craftBtnStroke.Color = COLORS.Accent
		return
	end
	
	if not selectedRecipe then
		craftBtn.Text = "Select a Recipe"
		craftBtn.TextColor3 = COLORS.TextMuted
		craftBtn.BackgroundColor3 = COLORS.SlotEmpty
		craftBtnStroke.Color = COLORS.Border
		return
	end
	
	-- Get recipe from WorkbenchConfig
	local recipe = WorkbenchConfig.RECIPES[selectedRecipe]
	local output = recipe and recipe.Output or { Id = selectedRecipe, N = 1 }
	local item = ItemDatabase:Get(output.Id or selectedRecipe)
	local name = item and item.Name or (output.Id or selectedRecipe)
	local canCraft = canCraftRecipe(selectedRecipe)
	
	if canCraft then
		craftBtn.Text = "Craft " .. name
		craftBtn.TextColor3 = COLORS.Paper
		craftBtn.BackgroundColor3 = COLORS.SuccessFill
		craftBtnStroke.Color = COLORS.Success
	else
		craftBtn.Text = "Missing Materials"
		craftBtn.TextColor3 = COLORS.Paper
		craftBtn.BackgroundColor3 = COLORS.DangerFill
		craftBtnStroke.Color = COLORS.Danger
	end
end

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
	if not canCraftRecipe(selectedRecipe) then return end
	if not rCraft then return end
	
	local requestToken = beginCraftPending()
	showInlineStatus("Crafting...", COLORS.Accent)
	
	-- Send craft request (Hand crafting)
	rCraft:FireServer(selectedRecipe, "Hand")
	
	task.delay(getCraftRequestTimeout(selectedRecipe), function()
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
		if kind ~= "Result" or type(payload) ~= "table" then return end
		if payload.StationType and payload.StationType ~= "Hand" then return end
		local success = payload.Success == true
		if isCraftPending then
			isCraftPending = false
			pendingRequestToken += 1
		end
		local reason = payload.Reason or (success and "Success" or "Unknown")
		showInlineStatus(messageForReason(reason), success and COLORS.Success or COLORS.Danger, success and 1.2 or 1.8)
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
Theme.Fit(mainPanel, 452, 530)
Theme.Button(closeBtn)
Theme.Button(craftBtn)
player:GetAttributeChangedSignal("FieldKitCraft"):Connect(function()
 if isOpen then closeCrafting() else openCrafting() end
end)
