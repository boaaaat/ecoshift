-- Advice uses the same biome, weather, armor and recipe definitions as gameplay.
local Shared = script.Parent
local Biomes = require(Shared.BiomeConfig)
local Survival = require(Shared.SurvivalConfig)
local Items = require(Shared.Items.ItemDatabase)
local Recipes = require(Shared.WorkbenchConfig)
local Guide = {}
local Catalog=require(Shared.OverhaulCatalog)
local World=require(Shared.OverhaulBiomes)
Guide.Biomes={}
local families={Forest="Trail",Desert="Dune",Swamp="Marsh",FrozenTundra="Frost",Volcanic="Ash",CrystalWastes="Crystal",AuroraVale="Aurora",StarfallCrater="Meteor",SaltglassCoast="Coast",StormspireHighlands="Storm",MyceliumHollow="Garden",IronrootBadlands="Iron",CanopySea="Canopy",SunkenArchive="Diver",UmbralDepths="Lantern",ShattermoonExpanse="Moon"}
for id,biome in pairs(World.Biomes) do
 local armors={}
 for item,gear in pairs(Catalog.Gear) do if gear.Kind=="Armor" and gear.Set==families[id] and gear.Slot=="Chest" then table.insert(armors,item) end end
 table.sort(armors)
 local advice=biome.Temp>5 and "Carry Water and Cooling Drinks. Shade slows heat buildup; return to safe shelter to recover." or biome.Temp< -5 and "Carry Warming Drinks and dry clothing. Cold gets more severe on later visits and in deeper regions." or "Watch local conditions, carry food and medical supplies, and prepare before entering deeper regions."
 Guide.Biomes[id]={Summary=biome.DisplayName..": "..advice,Armor=armors,Tools={"Water","Bandage","FieldClock","WeatherScanner"}}
end
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
		if exposure.Temp > 0 then add(tools, "CoolingDrink") end
		if exposure.Temp < 0 then add(tools, "WarmingDrink"); add(armor, "FrostCoat") end
		if exposure.Toxin > 0 then add(tools, "Antidote"); add(armor, "MarshCoat") end
		if exposure.Wet > 0 then add(armor, "MarshCoat") end
	end
	return armor, tools
end
return Guide
