-- Inventory-aware dependency plans. Shared inputs are totaled before rounding batches.
local Shared = script.Parent
local Guide = require(Shared.RecipeGuide)
local Workbench = require(Shared.WorkbenchConfig)
local Catalog = require(Shared.OverhaulCatalog)
local Ingredients = require(Shared.IngredientResolver)
local Plan = {}

function Plan.Build(target, snapshot, player, incoming)
	local nodes, order, visiting, demands = {}, {}, {}, {}
	local warnings = {}
	local function visit(id, recipeOverride)
		if visiting[id] then return false end
		if nodes[id] then return true end
		local entry = Guide.GetEntry(id)
		local node = {Id=id, Entry=entry, Recipe=recipeOverride or entry.Recipe}
		nodes[id], visiting[id] = node, true
		for _, ingredient in ipairs(node.Recipe and node.Recipe.Ingredients or {}) do
			for _, child in ipairs(ingredient.AnyOf or {ingredient.Id}) do
				if not visit(child) then
					warnings[id] = "Circular recipe dependency; obtain this item another way."
					node.Recipe = nil
				end
			end
		end
		visiting[id] = nil
		table.insert(order, id)
		return true
	end
	local rootId, rootRecipe, rootCount
	if target.Kind == "Upgrade" then
		local station = target.Station
		if not station or not station:IsDescendantOf(workspace) then
			return {Steps={{Kind="Blocked", Text="The tracked station is no longer available. Select another station upgrade."}}}
		end
		local grade = station:GetAttribute("StationGrade") or 1
		if grade >= target.Grade then return {Steps={}, Complete=true} end
		local costs, nextGrade = Catalog.GetStationUpgradeCost(target.StationType, grade)
		if not costs or nextGrade ~= target.Grade then
			return {Steps={{Kind="Blocked", Text="This upgrade is no longer available. Select its current upgrade again."}}}
		end
		rootId, rootCount = "@upgrade", 1
		rootRecipe = {Ingredients=costs, Output={Id=rootId,N=1}}
	else
		local entry = Guide.GetEntry(target.ItemId)
		rootId, rootCount = target.ItemId, target.Count
		rootRecipe = target.RecipeId == entry.RecipeId and entry.Recipe or Workbench.RECIPES[target.RecipeId]
		if Ingredients.Count(snapshot,rootId) >= rootCount then return {Steps={}, Complete=true} end
	end
	visit(rootId, rootRecipe)
	demands[rootId] = rootCount
	local gather, collect, crafts = {}, {}, {}
	local function demand(id, amount) demands[id] = (demands[id] or 0) + amount end
	-- Parents precede every dependency, including shared inputs reached through several branches.
	for index = #order, 1, -1 do
		local id = order[index]
		local node, needed = nodes[id], demands[id] or 0
		local owned = Ingredients.Count(snapshot,id)
		local deficit = math.max(0, needed-owned)
		for _, record in ipairs(incoming and incoming[id] or {}) do
			local used = math.min(deficit, record.Count)
			if used > 0 then
				table.insert(collect,{Kind="Collect",ItemId=id,Count=used,StationType=record.StationType,Working=record.Working})
				deficit -= used
			end
		end
		if deficit > 0 then
			local recipe = node.Recipe
			if recipe then
				local batches = math.ceil(deficit / (recipe.Output.N or 1))
				node.Batches = batches
				-- Reserve fixed requirements before choosing flexible trophy inputs.
				for _, ingredient in ipairs(recipe.Ingredients or {}) do
					if not ingredient.AnyOf then
						local cost = id == "@upgrade" and ingredient.N or Workbench:IngredientCost(ingredient,player)
						demand(ingredient.Id, cost*batches)
					end
				end
				for _, ingredient in ipairs(recipe.Ingredients or {}) do
					if ingredient.AnyOf then
						for _ = 1, batches do
							local remaining = Workbench:IngredientCost(ingredient,player)
							local choices = table.clone(ingredient.AnyOf)
							local function free(choice) return math.max(0,Ingredients.Count(snapshot,choice)-(demands[choice] or 0)) end
							table.sort(choices,function(a,b) local x,y=free(a),free(b);return x==y and a<b or x>y end)
							for choiceIndex, choice in ipairs(choices) do
								local amount = ingredient.Distinct and math.min(1,remaining) or math.min(free(choice),remaining)
								if not ingredient.Distinct and choiceIndex == #choices then amount=remaining end
								demand(choice,amount); remaining -= amount
								if remaining == 0 then break end
							end
						end
					end
				end
			else
				table.insert(gather,{Kind="Gather",ItemId=id,Count=deficit,Owned=owned,Needed=needed,Sources=node.Entry.Sources,Warning=warnings[id]})
			end
		end
	end
	for _, id in ipairs(order) do
		local node = nodes[id]
		if node.Batches then
			if id == "@upgrade" then
				table.insert(crafts,{Kind="Upgrade",StationType=target.StationType,Grade=target.Grade,Station=target.Station})
			else
				table.insert(crafts,{Kind="Craft",ItemId=id,RecipeId=id==rootId and target.RecipeId or node.Entry.RecipeId,
					Batches=node.Batches,Count=node.Batches*(node.Recipe.Output.N or 1),Recipe=node.Recipe})
			end
		end
	end
	table.sort(gather,function(a,b)return a.ItemId<b.ItemId end)
	local steps = {}
	for _, group in ipairs({gather,collect,crafts}) do for _, step in ipairs(group) do table.insert(steps,step) end end
	return {Steps=steps, Complete=false}
end

return Plan
