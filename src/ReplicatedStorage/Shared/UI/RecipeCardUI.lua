local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local UIFactory = require(script.Parent.UIFactory)

local RecipeCard = {}

function RecipeCard.SetExpanded(card, expanded)
	card:SetAttribute("Expanded", expanded == true)
end

local function ingredientDisplay(parent, ingredient, recipeId, options)
	local colors, mobile = options.Colors, options.Theme.IsMobile()
	local needed = options.IngredientCost(ingredient)
	local have = options.GetItemCount(ingredient.Id)
	local item = options.Items:Get(ingredient.Id)
	local compact = options.Station == true
	local frame = UIFactory.Create("TextButton", parent, {
		Name = "Ingredient_" .. ingredient.Id, Text = "", AutoButtonColor = false,
		Size = UDim2.new(0, compact and 70 or 80, 0, compact and 36 or 44),
		BackgroundColor3 = colors.SlotEmpty, BackgroundTransparency = compact and .3 or .5,
		BorderSizePixel = 0, ZIndex = 13,
	})
	frame:SetAttribute("IngredientId", ingredient.Id)
	options.Theme.Corner(frame, compact and 4 or 6)
	UIFactory.Create("TextLabel", frame, {
		Name = "ItemName", Size = UDim2.new(1, -8, 0, 30), Position = UDim2.new(0, 2, 0, compact and 2 or 3),
		BackgroundTransparency = 1, Text = (item and item.Name or ingredient.Id) .. " ›",
		TextColor3 = have >= needed and colors.Text or colors.Danger, TextSize = mobile and 14 or 10,
		Font = Enum.Font.GothamBold, TextWrapped = true, ZIndex = 14,
	})
	UIFactory.Create("TextLabel", frame, {
		Name = "Count", Size = UDim2.new(1, -4, 0, compact and 14 or 18), Position = UDim2.new(0, 2, 0, 33),
		BackgroundTransparency = 1, Text = compact and string.format("%d / %d", have, needed) or string.format("%d/%d", have, needed),
		TextColor3 = have >= needed and colors.Success or colors.Warning,
		TextSize = compact and 10 or (mobile and 14 or 11), Font = Enum.Font.Gotham, ZIndex = 14,
	})
	frame.Activated:Connect(function() options.OpenIngredient(ingredient.Id, recipeId) end)
	return frame
end

function RecipeCard.Create(parent, recipeId, recipe, options)
	local theme, colors = options.Theme, options.Colors
	local ingredients = recipe.Ingredients or {}
	local output = recipe.Output or {Id = recipeId, N = 1}
	local item = options.Items:Get(output.Id)
	local station, mobile = options.Station == true, theme.IsMobile()
	local headerHeight = station and 52 or 44
	local columns = mobile and 2 or 3
	local ingredientsHeight = math.ceil(#ingredients / columns) * 54
	local card = UIFactory.Create("TextButton", parent, {
		Name = recipeId, Size = UDim2.new(1, -12, 0, headerHeight), ClipsDescendants = true,
		BackgroundColor3 = colors.SlotFilled, BorderSizePixel = 0, Text = "", AutoButtonColor = false,
		LayoutOrder = options.LayoutOrder or 0, ZIndex = 12,
	})
	RecipeCard.SetExpanded(card, options.IsSelected(recipeId))
	theme.Button(card)
	theme.Corner(card, 8)
	local stroke = UIFactory.Create("UIStroke", card, {Name="Stroke", Color=colors.Border, Thickness=1, Transparency=.5})
	UIFactory.Create("TextLabel", card, {
		Name="Name", Size=UDim2.new(1, station and -182 or -132, 0, 22),
		Position=UDim2.new(0, station and 48 or 10, 0, station and 8 or 6), BackgroundTransparency=1,
		Text=(output.N or 1)>1 and string.format("%s x%d", item and item.Name or output.Id, output.N) or (item and item.Name or output.Id),
		TextColor3=colors.Text, TextSize=14, Font=Enum.Font.GothamBold,
		TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=13,
	})
	if station then
		UIFactory.Create("TextLabel", card, {
			Name="Category", Size=UDim2.new(0,80,0,16), Position=UDim2.new(0,48,0,28), BackgroundTransparency=1,
			Text="Grade " .. (recipe.RequiredGrade or 1), TextColor3=options.GetTierColor(recipe), TextSize=10,
			Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13,
		})
		local host=UIFactory.Create("Frame",card,{Size=UDim2.fromOffset(28,28),Position=UDim2.fromOffset(12,10),BackgroundTransparency=1,ZIndex=13})
		local icon=theme.Icon(host,options.CategoryIcons[recipe.Category] or "Craft",24)
		for _,line in ipairs(icon:GetChildren()) do if line:IsA("Frame") then theme.Bind(line,"BackgroundColor3","Amber") end end
	end
	UIFactory.Create("TextLabel", card, {
		Name="Status", Size=UDim2.new(0,station and 90 or 80,0,station and 20 or 18), AnchorPoint=Vector2.new(1,0),
		Position=UDim2.new(1,station and -38 or -36,0,station and 10 or 8), BackgroundTransparency=1,
		Text=options.CanCraft(recipeId) and "READY" or "MISSING",
		TextColor3=options.CanCraft(recipeId) and colors.Success or colors.Danger,
		TextSize=station and 12 or 11, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Right, ZIndex=13,
	})
	local expandIndicator = UIFactory.Create("TextLabel", card, {
		Name="ExpandIndicator", Size=UDim2.fromOffset(20,22), Position=UDim2.new(1,-28,0,station and 8 or 6),
		BackgroundTransparency=1, Text="+", TextColor3=colors.TextMuted,
		TextSize=18, Font=Enum.Font.Gotham, ZIndex=13,
	})
	local ingredientFrame=UIFactory.Create("Frame",card,{
		Name="Ingredients",Size=UDim2.new(1,station and -24 or -20,0,ingredientsHeight),
		Position=UDim2.new(0,station and 12 or 10,0,headerHeight),BackgroundTransparency=1,
		ClipsDescendants=true,Visible=false,ZIndex=13,
	})
	local description
	if options.ShowDescription and item and item.Description and item.Description ~= "" then
		description = theme.Label(card, item.Description, UDim2.new(1,-20,0,0), UDim2.fromOffset(10,headerHeight), 12, colors.TextMuted)
		description.Name = "ItemDescription"
		description.TextWrapped, description.TextTruncate = true, Enum.TextTruncate.None
		description.TextYAlignment, description.Visible = Enum.TextYAlignment.Top, false
	end
	local grid = UIFactory.Create("UIGridLayout",ingredientFrame,{
		FillDirection=Enum.FillDirection.Horizontal,FillDirectionMaxCells=columns,
		CellSize=UDim2.new(1/columns,-4,0,mobile and 56 or 50),CellPadding=UDim2.fromOffset(4,4),
		SortOrder=Enum.SortOrder.LayoutOrder,
	})
	for _,ingredient in ipairs(ingredients) do ingredientDisplay(ingredientFrame,ingredient,recipeId,options) end
	local trackButton
	if options.TrackRecipe then
		trackButton=UIFactory.Create("TextButton",card,{
			Name="TrackRecipe",Size=UDim2.new(1,-24,0,44),Text="Track recipe on HUD",
			BackgroundColor3=colors.SlotEmpty,TextColor3=colors.Text,TextSize=14,
			Font=Enum.Font.GothamBold,BorderSizePixel=0,Visible=false,ZIndex=14,
		})
		theme.Button(trackButton)
		trackButton.Activated:Connect(function() options.TrackRecipe(recipeId) end)
	end
	local function layoutIngredients()
		local touch = theme.IsMobile()
		local scale, ancestor = 1, card
		while ancestor do
			for _, child in ipairs(ancestor:GetChildren()) do
				if child:IsA("UIScale") then scale *= child.Scale end
			end
			ancestor = ancestor.Parent
		end
		local width = math.max(80, card.AbsoluteSize.X / math.max(.01,scale) - (station and 24 or 20))
		local count = math.clamp(math.floor(width / 120), 1, touch and 4 or 3)
		local rowHeight = touch and 52 or 54
		local height = math.ceil(#ingredients / count) * rowHeight
		grid.FillDirectionMaxCells = count
		grid.CellSize = UDim2.new(1 / count, -4, 0, rowHeight - 4)
		ingredientFrame.Size = UDim2.new(1, station and -24 or -20, 0, height)
		local expanded = card:GetAttribute("Expanded") == true
		local ingredientsTop = headerHeight
		if description then
			description.Visible = expanded
			if expanded then
				local bounds = TextService:GetTextSize(description.Text, description.TextSize, description.Font, Vector2.new(width,10000))
				local descriptionHeight = math.ceil(bounds.Y) + 4
				description.Size = UDim2.new(1,-20,0,descriptionHeight)
				ingredientsTop += descriptionHeight + 6
			end
		end
		ingredientFrame.Position = UDim2.fromOffset(station and 12 or 10, ingredientsTop)
		ingredientFrame.Visible = expanded and #ingredients > 0
		expandIndicator.Text = expanded and "−" or "+"
		-- Selection and responsive reflow use the same height calculation, so
		-- hidden ingredient rows never reserve space in the recipe list.
		if trackButton then
			trackButton.Visible=expanded
			trackButton.Position=UDim2.fromOffset(12,ingredientsTop+height+4)
		end
		card.Size = UDim2.new(1,-12,0,expanded and (ingredientsTop + height + (trackButton and 56 or 8)) or headerHeight)
		for _, ingredient in ipairs(ingredientFrame:GetChildren()) do
			if ingredient:IsA("TextButton") then
				ingredient.ItemName.TextSize = touch and 12 or 10
				ingredient.ItemName.Size = UDim2.new(1, -8, 0, touch and 26 or 30)
				ingredient.Count.Position = UDim2.fromOffset(2, touch and 29 or 33)
				ingredient.Count.Size = UDim2.new(1, -4, 0, touch and 16 or (station and 14 or 18))
				ingredient.Count.TextSize = touch and 12 or (station and 10 or 11)
			end
		end
	end
	-- Reflow existing cards on rotation without rebuilding the selected recipe.
	local lastWidth
	card:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local width = card.AbsoluteSize.X
		if width == lastWidth then return end
		lastWidth = width
		layoutIngredients()
	end)
	card:GetAttributeChangedSignal("Expanded"):Connect(layoutIngredients)
	layoutIngredients()
	theme.BindResponsive(card, layoutIngredients)
	card.MouseEnter:Connect(function() TweenService:Create(card,TweenInfo.new(.12),{BackgroundColor3=colors.SlotHover}):Play() end)
	card.MouseLeave:Connect(function()
		TweenService:Create(card,TweenInfo.new(.12),{BackgroundColor3=options.IsSelected(recipeId) and colors.SlotSelected or colors.SlotFilled}):Play()
	end)
	card.Activated:Connect(function()
		if not options.IsBusy() then options.OnSelect(recipeId,card,stroke) end
	end)
	return card
end

return RecipeCard
