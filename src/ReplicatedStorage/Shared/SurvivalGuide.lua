-- Advice uses the same biome, weather, armor and recipe definitions as gameplay.
local Shared = script.Parent
local Biomes = require(Shared.BiomeConfig)
local Survival = require(Shared.SurvivalConfig)
local Items = require(Shared.Items.ItemDatabase)
local Recipes = require(Shared.WorkbenchConfig)
local Guide = {}
Guide.Biomes = {
	Forest = { Summary = "Verdant Reach is your gathering window. Collect supplies and prepare heat protection before an early Desert shift.", Armor = { "ReedSunwrap" }, Tools = { "StoneHatchet", "StonePickaxe", "FieldClock" } },
	Desert = { Summary = "Sunscar Dunes steadily raises body temperature. Equip heat protection; heatwaves can overwhelm a starter Sunwrap.", Armor = { "ReedSunwrap", "DesertCloak" }, Tools = { "HeatTonic", "Bandage" } },
	Swamp = { Summary = "Mirefen is toxic and wet even under overcast skies. Toxins deal ongoing damage; resistance reduces it but does not make you immune.", Armor = { "SwampWaders" }, Tools = { "AntitoxinTonic", "Bandage" } },
	FrozenTundra = { Summary = "Frostfall rapidly lowers body temperature. Wetness makes cold worse; snowfall and whiteouts add both cold and wetness.", Armor = { "FrostParka" }, Tools = { "ColdTonic", "Bandage" } },
	Volcanic = { Summary = "Cinder Rift has severe baseline heat. Ashfall and emberstorms add toxins as well as heat; bring protection and healing.", Armor = { "VolcanicPlate" }, Tools = { "HeatTonic", "AntitoxinTonic", "Bandage" } },
	CrystalWastes = { Summary = "Prism Barrens is mild in calm weather, but haze and static storms introduce toxin exposure. Prepare for changing conditions.", Armor = { "CrystalWeave" }, Tools = { "AntitoxinTonic", "Bandage" } },
	AuroraVale = { Summary = "Aurora Vale switches between warm dawn surges and cold polar nights. Balanced heat and cold protection helps through both.", Armor = { "AuroraMantle" }, Tools = { "HeatTonic", "ColdTonic" } },
	StarfallCrater = { Summary = "Starfall Crater combines temperature shifts with toxic conditions. Strong all-round protection and healing are useful here.", Armor = { "StarforgedPlate", "AdaptiveSurvivalSuit" }, Tools = { "HeatTonic", "AntitoxinTonic", "Bandage" } },
}
function Guide.Name(id)
	local item = Items:Get(id)
	return item and item.Name or (tostring(id):gsub("(%l)(%u)", "%1 %2"))
end
function Guide.Weather(biome, id)
	for _, weather in ipairs(Survival.WEATHER_BY_BIOME[biome] or {}) do if weather.Id == id then return weather end end
	return nil
end
function Guide.Exposure(biome, weatherId)
	local metadata = Biomes.biome_metadata[biome]
	local base = metadata and metadata.env or {}
	local weather = Guide.Weather(biome, weatherId) or {}
	return { Temp = (base.Temp or 0) + (weather.Temp or 0), Toxin = (base.Toxin or 0) + (weather.Toxin or 0), Wet = (base.Wet or 0) + (weather.Wet or 0) }
end
function Guide.Hazards(exposure)
	local text = {}
	if exposure.Temp > 0 then table.insert(text, "Heat raises body temperature. Use heat-resistant armor.")
	elseif exposure.Temp < 0 then table.insert(text, "Cold lowers body temperature. Use cold-resistant armor.") end
	if exposure.Toxin > 0 then table.insert(text, "Toxins cause ongoing damage. Use toxin resistance and carry healing.") end
	if exposure.Wet > 0 then table.insert(text, "Wetness builds up and increases cold exposure. Wet-resistant gear slows the buildup.") end
	return #text > 0 and table.concat(text, "\n") or "No baseline heat, cold or toxin hazard in these conditions. Keep food and healing ready for enemies and events."
end
function Guide.ArmorText(id)
	local armor, parts = Survival.ARMOR[id], {}
	if not armor then return "No survival armor equipped." end
	for _, kind in ipairs({ "Heat", "Cold", "Toxin", "Wet" }) do
		local resistance = armor[kind .. "Resistance"] or 0
		if resistance > 0 then table.insert(parts, string.format("%s %d%%", kind, math.floor(resistance * 100 + .5))) end
	end
	return table.concat(parts, " / ") .. " exposure reduction"
end
function Guide.RecipeText(id)
	local recipe = Recipes.RECIPES[id]
	if not recipe then return "Open recipe and gathering guide" end
	local parts = {}
	for _, ingredient in ipairs(recipe.Ingredients) do table.insert(parts, ingredient.N .. " " .. Guide.Name(ingredient.Id)) end
	return table.concat(parts, " + ") .. "  |  " .. table.concat(recipe.AllowedStations or {}, ", ")
end
function Guide.Recommendations(biome, weatherId, conditions)
	local info = Guide.Biomes[biome]
	if not info then return {}, {} end
	local armor, tools = table.clone(info.Armor), table.clone(info.Tools)
	if conditions then
		local exposure = Guide.Exposure(biome, weatherId)
		local function add(list, id) if not table.find(list, id) then table.insert(list, id) end end
		if exposure.Temp > 0 then add(tools, "HeatTonic") end
		if exposure.Temp < 0 then add(tools, "ColdTonic"); add(armor, "FrostParka") end
		if exposure.Toxin > 0 then add(tools, "AntitoxinTonic"); add(armor, "SwampWaders") end
		if exposure.Wet > 0 then add(armor, "SwampWaders") end
	end
	return armor, tools
end
return Guide
