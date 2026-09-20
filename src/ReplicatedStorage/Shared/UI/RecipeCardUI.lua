local TweenService = game:GetService("TweenService")
local UIFactory = require(script.Parent.UIFactory)

local RecipeCard = {}

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
	local columns = mobile and 2 or 3
	local ingredientsHeight = math.max(1, math.ceil(#ingredients / columns)) * (mobile and 60 or 54)
	local card = UIFactory.Create("TextButton", parent, {
		Name = recipeId, Size = UDim2.new(1, -12, 0, (station and 52 or 38) + ingredientsHeight),
		BackgroundColor3 = colors.SlotFilled, BorderSizePixel = 0, Text = "", AutoButtonColor = false,
		LayoutOrder = options.LayoutOrder or 0, ZIndex = 12,
	})
	theme.Button(card)
	theme.Corner(card, 8)
	local stroke = UIFactory.Create("UIStroke", card, {Name="Stroke", Color=colors.Border, Thickness=1, Transparency=.5})
	UIFactory.Create("TextLabel", card, {
		Name="Name", Size=UDim2.new(1, station and -144 or -102, 0, 22),
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
		Position=UDim2.new(1,station and -12 or -10,0,station and 10 or 8), BackgroundTransparency=1,
		Text=options.CanCraft(recipeId) and "READY" or "MISSING",
		TextColor3=options.CanCraft(recipeId) and colors.Success or colors.Danger,
		TextSize=station and 12 or 11, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Right, ZIndex=13,
	})
	local ingredientFrame=UIFactory.Create("Frame",card,{
		Name="Ingredients",Size=UDim2.new(1,station and -24 or -20,0,ingredientsHeight),
		Position=UDim2.new(0,station and 12 or 10,0,station and 44 or 32),BackgroundTransparency=1,
		ClipsDescendants=station,ZIndex=13,
	})
	if options.MountDescription then options.MountDescription(card, item, ingredientFrame) end
	UIFactory.Create("UIGridLayout",ingredientFrame,{
		FillDirection=Enum.FillDirection.Horizontal,FillDirectionMaxCells=columns,
		CellSize=UDim2.new(1/columns,-4,0,mobile and 56 or 50),CellPadding=UDim2.fromOffset(4,4),
		SortOrder=Enum.SortOrder.LayoutOrder,
	})
	for _,ingredient in ipairs(ingredients) do ingredientDisplay(ingredientFrame,ingredient,recipeId,options) end
	card.MouseEnter:Connect(function() TweenService:Create(card,TweenInfo.new(.12),{BackgroundColor3=colors.SlotHover}):Play() end)
	card.MouseLeave:Connect(function()
		TweenService:Create(card,TweenInfo.new(.12),{BackgroundColor3=options.IsSelected(recipeId) and colors.SlotSelected or colors.SlotFilled}):Play()
	end)
	card.MouseButton1Click:Connect(function()
		if not options.IsBusy() then options.OnSelect(recipeId,card,stroke) end
	end)
	return card
end

return RecipeCard
