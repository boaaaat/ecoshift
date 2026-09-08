-- Read-only recipe discovery. Source hints follow spawning/drop configuration,
-- never item tags; nearby stations mirror CraftingService's authoritative check.
local CollectionService = game:GetService("CollectionService")
local Shared = script.Parent
local Workbench = require(Shared.WorkbenchConfig)
local Items = require(Shared.Items.ItemDatabase)
local Biomes = require(Shared.BiomeConfig)
local ResourceMap = require(Shared.ResourceItemMap)
local Loot = require(Shared.ExpeditionLootConfig)
local MonsterDrops = require(Shared.MonsterDropConfig)
local Config = require(Shared.Config)

local Guide = {}
local recipesByOutput, sourcesByItem, stationIds = {}, {}, {}
local monsterBiomes = {}

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

local function weightedEntries(entries, visit)
	for key, value in pairs(entries or {}) do
		local name = type(key) == "string" and key
			or (type(value) == "string" and value)
			or (type(value) == "table" and (value.Name or value.name))
		local weight = type(value) == "number" and value
			or (type(value) == "table" and (value.Weight or value.weight)) or 1
		if name and weight > 0 then visit(name) end
	end
end

for recipeId, recipe in pairs(Workbench.RECIPES) do
	local outputId = recipe.Output and recipe.Output.Id
	if outputId then
		local recipes = recipesByOutput[outputId] or {}
		table.insert(recipes, recipeId)
		recipesByOutput[outputId] = recipes
	end
end
for _, recipes in pairs(recipesByOutput) do table.sort(recipes) end
for stationId in pairs(Workbench.STATIONS) do table.insert(stationIds, stationId) end
table.sort(stationIds, function(a, b)
	local aTier, bTier = Workbench.STATIONS[a].Tier or 0, Workbench.STATIONS[b].Tier or 0
	return aTier == bTier and a < b or aTier < bTier
end)

for biomeId, biome in pairs(Biomes.biomes) do
	local metadata = Biomes.biome_metadata[biomeId]
	local biomeName = metadata and metadata.DisplayName or readable(biomeId)
	for _, region in pairs(biome.regions or {}) do
		weightedEntries(region.resources, function(name)
			local id = ResourceMap.Normalize(name)
			addSource(id, "Gather " .. itemName(id) .. " in " .. biomeName .. ".")
		end)
		weightedEntries(region.enemies, function(name)
			local locations = monsterBiomes[name] or {}
			if not table.find(locations, biomeName) then table.insert(locations, biomeName) end
			monsterBiomes[name] = locations
		end)
	end
	if Loot.CacheMaterials[biomeId] then
		for _, rarity in pairs(Loot.CacheTable(biomeId).Rarities) do
			for _, drop in ipairs(rarity.Items or {}) do
				if (drop.Weight or 1) > 0 and (drop.Chance or 1) > 0 then
					addSource(drop.Id, "Can be found in supply caches in " .. biomeName .. ".")
				end
			end
			for _, drop in ipairs(rarity.Guaranteed or {}) do
				if (drop.Chance or 1) > 0 then
					addSource(drop.Id, "Can be found in supply caches in " .. biomeName .. ".")
				end
			end
		end
	end
end
for monsterId, monster in pairs(MonsterDrops.Monsters) do
	local locations = monsterBiomes[monsterId] or {}
	table.sort(locations)
	local locationHint = #locations > 0 and (" in " .. table.concat(locations, " or ")) or ""
	for _, drop in ipairs(monster.Drops or {}) do
		if (drop.Chance or 1) > 0 then
			addSource(drop.ItemId, "Defeat " .. readable(monsterId) .. locationHint .. " for a chance to collect this material.")
		end
	end
end
for _, sources in pairs(sourcesByItem) do table.sort(sources) end

-- Recipes are recipe IDs, not item IDs: several outputs use a different key.
function Guide.GetEntry(itemId)
	if type(itemId) ~= "string" then return nil end
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
				Id = stationId, Name = station.Name, Nearby = stationId == "Hand",
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
							if distance <= (station.InteractRadius or 8) and (not record.Distance or distance < record.Distance) then
								record.Nearby, record.Distance = true, distance
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
		if station.Nearby then
			if station.Id == preferredStationType then return station.Id end
			fallback = fallback or station.Id
		end
	end
	return fallback
end

return Guide
