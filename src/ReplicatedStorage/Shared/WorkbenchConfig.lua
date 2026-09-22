-- One station/recipe catalog for the complete campaign.
local Catalog=require(script.Parent.OverhaulCatalog)
local Config={RECIPES=Catalog.Recipes,STATIONS=table.clone(Catalog.Stations),STATION_TIERS={},STATION_GLOBAL_MODIFIERS={}}
Config.CRAFT_SPEED_MULTIPLIER=Catalog.CraftSpeedMultiplier or 1
Config.CATEGORIES={"Cooking","Structures","Materials","Tools","Weapons","Armor","Accessories","Consumables","Utility","Storage","Stations","Intel","Enchantments","Repair"}
for id,station in pairs(Config.STATIONS) do Config.STATION_TIERS[id]=station.Tier end
for _,entry in ipairs({{"AdvancedWorkbench",4,"Advanced Workbench"},{"MasterWorkbench",7,"Master Workbench"}}) do
 Config.STATIONS[entry[1]]={Name=entry[3],Tier=entry[2],Grade=entry[2],BuildType="Workbench",InteractRadius=15}
 Config.STATION_TIERS[entry[1]]=entry[2]
end
function Config:IngredientCost(ingredient,player)
 local count=math.max(1,math.floor(ingredient.N or 1))
 if ingredient.StructuralMaterial then count=math.max(1,math.ceil(count*(1-math.clamp(tonumber(player and player:GetAttribute("Class_BuildDiscount")) or 0,0,.18)))) end
 return count
end
function Config:CanCraftAt(recipeId,stationType)
 local recipe=self.RECIPES[recipeId]
 if not recipe or recipe.Future or not self.STATIONS[stationType] then return false end
 local actual=(stationType=="AdvancedWorkbench" or stationType=="MasterWorkbench") and "Workbench" or stationType
 local allowed=recipe.AllowedStations or {recipe.StationType}
 if actual=="Workbench" and table.find(allowed,"Hand") then return true end
 return table.find(allowed,actual)~=nil
end
function Config:GetRecipesForStation(stationType,stationGrade,campaignTier)
 local list={}
 for id,recipe in pairs(self.RECIPES) do
  local grade=recipe.RequiredGrade or recipe.Tier or 1
  local campaign=recipe.CampaignTier or recipe.Tier or 1
  if not recipe.Future and self:CanCraftAt(id,stationType)
   and (stationGrade==nil or grade<=stationGrade)
   and (campaignTier==nil or campaign<=campaignTier) then list[id]=recipe end
 end
 return list
end
function Config:GetHandRecipes() return self:GetRecipesForStation("Hand") end
function Config:GetMinimumStation(recipeId)
 local recipe=self.RECIPES[recipeId];if not recipe then return nil end
 return recipe.AllowedStations and recipe.AllowedStations[1] or recipe.StationType
end
function Config:GetEffectiveStationModifiers() return 1,0 end
function Config:GetClientCraftRate(player)
 return self.CRAFT_SPEED_MULTIPLIER*math.clamp(1+(player and player:GetAttribute("Class_CraftBonus") or 0),1,2)
end
function Config:GetCampaignLock(recipeId)
 local recipe=self.RECIPES[recipeId];if not recipe then return "Recipe unavailable" end
 if (recipe.CampaignTier or 1)>(workspace:GetAttribute("CampaignTier") or 1) then return "Campaign tier "..recipe.CampaignTier.." required" end
 if recipe.RequiresMilestone and not game:GetService("ReplicatedStorage"):GetAttribute("CampaignCompleted_"..recipe.RequiresMilestone) then
  return "Complete "..recipe.RequiresMilestone:gsub("(%l)(%u)","%1 %2").." to unlock this recipe"
 end
 return nil
end
function Config:GetRequiredGrade(recipeId)
 local recipe=self.RECIPES[recipeId];return recipe and (recipe.RequiredGrade or 1) or 1
end
return Config
