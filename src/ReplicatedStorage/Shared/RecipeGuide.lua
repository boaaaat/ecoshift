-- Read-only recipe discovery. Source hints follow spawning/drop configuration,
-- never item tags; nearby stations mirror CraftingService's authoritative check.
local CollectionService = game:GetService("CollectionService")
local Shared = script.Parent
local Workbench = require(Shared.WorkbenchConfig)
local Items = require(Shared.Items.ItemDatabase)
local Config = require(Shared.Config)
local Cooking = require(Shared.CookingConfig)

local Guide = {}
local Catalog=require(Shared.OverhaulCatalog)
local recipesByOutput, sourcesByItem, stationIds = {}, {}, {}

local function readable(id)
	return (id:gsub("(%l)(%u)", "%1 %2"))
end

local function itemName(id)
	local item = Items:Get(id)
	return item and item.Name or readable(id)
end

local function addSource(id, text)
	if not Items:Get(id) then return end
	local sources = sourcesByItem[id] or {}
	if not table.find(sources, text) then table.insert(sources, text) end
	sourcesByItem[id] = sources
end

local function refreshRecipes()
 table.clear(recipesByOutput)
 for recipeId,recipe in pairs(Workbench.RECIPES) do
  local outputId=recipe.Output and recipe.Output.Id
  if outputId then
   recipesByOutput[outputId]=recipesByOutput[outputId] or {}
   table.insert(recipesByOutput[outputId],recipeId)
  end
 end
 for _,recipes in pairs(recipesByOutput) do table.sort(recipes) end
end
refreshRecipes()
for stationId in pairs(Workbench.STATIONS) do table.insert(stationIds, stationId) end
table.sort(stationIds, function(a, b)
	local aTier, bTier = Workbench.STATIONS[a].Tier or 0, Workbench.STATIONS[b].Tier or 0
	return aTier == bTier and a < b or aTier < bTier
end)

for id,resource in pairs(Catalog.Resources) do
 local method=resource.Duration and "Gather" or resource.Kind=="Animal" and "Hunt for" or "Break nodes for"
 addSource(id,method.." "..itemName(id).." in "..resource.Biome.." · region "..resource.Depth..".")
 if not resource.Duration and resource.Kind~="Animal" then addSource(id,"Mining/tool grade "..(resource.MiningGrade or 1).." required.") end
end
for _,id in ipairs(Catalog.Trophies) do addSource(id,"Complete the matching deep-region elite site (region E).") end
for id,def in pairs(Catalog.Items) do
 if def.Schematic then addSource(id,Catalog.Enchantments[def.Schematic.Id].Source) end
 if def.Scroll then addSource(id,"Extract this enchantment from owned gear at an Enchanting Table.") end
end
for _,id in ipairs({"AnyTrophy","DifferentTrophies"}) do
 for _,trophy in ipairs(Catalog.Trophies) do addSource(id,"Eligible: "..itemName(trophy)) end
end
for _, sources in pairs(sourcesByItem) do table.sort(sources) end

-- Recipes are recipe IDs, not item IDs: several outputs use a different key.
function Guide.GetEntry(itemId)
	if type(itemId) ~= "string" then return nil end
 refreshRecipes()
 local base,seasoning=Cooking.GetMeal(itemId)
 if base and seasoning then
  local baseEntry=Guide.GetEntry(base.Id)
  if baseEntry and baseEntry.Recipe then
   baseEntry.ItemId=itemId
   baseEntry.Name=base.Name.." / "..seasoning.Name
   baseEntry.Recipe=table.clone(baseEntry.Recipe)
   baseEntry.Recipe.Ingredients=table.clone(baseEntry.Recipe.Ingredients)
   table.insert(baseEntry.Recipe.Ingredients,{Id=seasoning.Id,N=1})
   return baseEntry
  end
 end
	local recipes = recipesByOutput[itemId] or {}
	local sources = sourcesByItem[itemId] or {}
	return {
		Kind = #recipes > 0 and "Recipe" or "Raw", ItemId = itemId,
		Name = itemName(itemId), RecipeId = recipes[1],
		Recipe = recipes[1] and Workbench.RECIPES[recipes[1]] or nil,
		Recipes = table.clone(recipes), Sources = table.clone(sources),
	}
end

function Guide.GetStations(recipeId, player)
 refreshRecipes()
	local result = {}
	if not Workbench.RECIPES[recipeId] then return result end
	local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local structures = CollectionService:GetTagged("Structure")
	for _, stationId in ipairs(stationIds) do
		if Workbench:CanCraftAt(recipeId, stationId) then
			local station = Workbench.STATIONS[stationId]
			local buildType = station.BuildType
			local buildItem = buildType and Config.BUILD.PlaceableItems[buildType] and Items:Get(buildType)
			local recipes = buildItem and recipesByOutput[buildItem.Id]
			local record = {
				Id = stationId, Name = station.Name, Nearby = stationId == "Hand", RequiredGrade=Workbench:GetRequiredGrade(recipeId), Grade=stationId=="Hand" and 1 or nil,
				BuildItemId = buildItem and buildItem.Id or nil,
				RecipeId = recipes and recipes[1] or nil,
			}
			if root and buildType then
				for _, structure in ipairs(structures) do
					local kind = structure:GetAttribute("BuildType") or structure:GetAttribute("StationType")
					if structure:IsDescendantOf(workspace) and (kind == buildType or kind == stationId) then
						local position
						if structure:IsA("Model") then position = structure:GetPivot().Position
						elseif structure:IsA("BasePart") then position = structure.Position end
						if position then
							local distance = (root.Position - position).Magnitude
							local candidateGrade=structure:GetAttribute("StationGrade") or station.Grade or 1
       local candidateQualified=candidateGrade>=record.RequiredGrade
       if distance <= (station.InteractRadius or 15) and (not record.Distance or (candidateQualified and not record.Nearby) or (candidateQualified==record.Nearby and distance<record.Distance)) then
								record.Grade=structure:GetAttribute("StationGrade") or station.Grade or 1
        record.Nearby, record.Distance = record.Grade>=record.RequiredGrade, distance
        record.UpgradeNeeded=record.Grade<record.RequiredGrade
        record.Instance=structure
							end
						end
					end
				end
			end
			table.insert(result, record)
		end
	end
	return result
end

function Guide.GetUsableStation(recipeId, player, preferredStationType)
	local fallback
	for _, station in ipairs(Guide.GetStations(recipeId, player)) do
		if station.Nearby and not Workbench:GetCampaignLock(recipeId) then
			if station.Id == preferredStationType then return station.Id end
			fallback = fallback or station.Id
		end
	end
	return fallback
end

return Guide
