-- CraftingService.lua
-- Server-side crafting with workbench tier support
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local WorkbenchConfig = require(ReplicatedStorage.Shared.WorkbenchConfig)
local InventoryService = require(script.Parent.InventoryService)

local CraftingService = {}
CraftingService._initialized = false

local function resolveRecipe(recipeId)
	return WorkbenchConfig.RECIPES[recipeId]
end

local function adjustedIngredientsForPlayer(plr, ingredients)
	local craftMult = tonumber(plr:GetAttribute("Role_Craft")) or 1.0
	local adjusted = {}
	for _, entry in ipairs(ingredients or {}) do
		local n = math.max(1, math.floor((entry.N or 1) / math.max(craftMult, 0.1)))
		adjusted[#adjusted + 1] = { Id = entry.Id, N = n }
	end
	return adjusted
end

-- Find nearest workbench of a specific type within range
function CraftingService:FindNearbyStation(plr, stationType)
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	
	local station = WorkbenchConfig.STATIONS[stationType]
	if not station then return nil end
	
	local buildType = station.BuildType
	if not buildType then return nil end  -- Hand crafting, no station needed
	
	local interactRadius = station.InteractRadius or 8
	local nearestStation = nil
	local nearestDist = interactRadius + 1
	
	-- Search for placed structures with matching BuildType
	for _, structure in ipairs(CollectionService:GetTagged("Structure")) do
		local structType = structure:GetAttribute("BuildType") or structure:GetAttribute("StationType")
		if structType == buildType or structType == stationType then
			local pos
			if structure:IsA("Model") then
				pos = structure:GetPivot().Position
			elseif structure:IsA("BasePart") then
				pos = structure.Position
			end
			
			if pos then
				local dist = (root.Position - pos).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearestStation = structure
				end
			end
		end
	end
	
	return nearestStation
end

-- Get the station type the player is currently near
function CraftingService:GetPlayerStation(plr, requestedStation)
	-- If no specific station requested, check what's nearby
	if not requestedStation or requestedStation == "Hand" then
		return "Hand", nil
	end
	
	local station = self:FindNearbyStation(plr, requestedStation)
	if station then
		return requestedStation, station
	end
	
	return nil, nil  -- Not near the required station
end

-- Check if player can craft a recipe (with station validation)
function CraftingService:CanCraft(plr, recipeId, stationType)
	local recipe = resolveRecipe(recipeId)
	
	if not recipe then 
		print("[CraftingService] No recipe found for:", recipeId)
		return false, "NoRecipe" 
	end
	
	-- Determine effective station type
	local effectiveStation = stationType or "Hand"
	
	-- Validate station requirement
	if not WorkbenchConfig:CanCraftAt(recipeId, effectiveStation) then
		local minStation = WorkbenchConfig:GetMinimumStation(recipeId)
		print(string.format("[CraftingService] %s requires %s station", recipeId, tostring(minStation)))
		return false, "WrongStation", minStation
	end
	
	-- If not hand crafting, verify player is near the station
	if effectiveStation ~= "Hand" then
		local foundStation = self:FindNearbyStation(plr, effectiveStation)
		if not foundStation then
			print(string.format("[CraftingService] Player not near %s", effectiveStation))
			return false, "NotNearStation", effectiveStation
		end
	end
	
	-- Get ingredients
	local ingredients = recipe.Ingredients or recipe
	
	-- Calculate adjusted costs with craft multiplier
	local adjusted = adjustedIngredientsForPlayer(plr, ingredients)
	
	-- Check if player can afford
	if not InventoryService:CanAfford(plr, adjusted) then
		print("[CraftingService] Player cannot afford recipe:", recipeId)
		return false, "MissingItems"
	end
	
	return true
end

-- Craft an item
function CraftingService:Craft(plr, recipeId, stationType)
	print(string.format("[CraftingService] %s attempting to craft: %s at %s", 
		plr.Name, tostring(recipeId), tostring(stationType or "Hand")))
	
	local ok, reason, extra = self:CanCraft(plr, recipeId, stationType)
	if not ok then 
		print("[CraftingService] Craft failed:", reason)
		return false, reason, extra
	end
	
	local recipe = resolveRecipe(recipeId)
	if not recipe then
		return false, "NoRecipe"
	end
	
	local ingredients = recipe.Ingredients or recipe
	local output = recipe.Output or { Id = recipeId, N = 1 }
	
	local adjusted = adjustedIngredientsForPlayer(plr, ingredients)
	
	-- Pay the cost
	if not InventoryService:PayCost(plr, adjusted) then
		print("[CraftingService] PayCost failed")
		return false, "ConsumeFailed"
	end
	
	-- Give the output item(s)
	local outputId = output.Id or recipeId
	local outputCount = math.max(1, math.floor(tonumber(output.N) or 1))
	local added = InventoryService:Give(plr, outputId, outputCount, true)
	if added ~= outputCount then
		-- Roll back consumed ingredients (best effort) so crafting cannot eat items.
		for _, entry in ipairs(adjusted) do
			InventoryService:Give(plr, entry.Id, entry.N)
		end
		warn(string.format("[CraftingService] Output grant failed for %s (%s x%d). Rolled back ingredients.",
			plr.Name, tostring(outputId), outputCount))
		return false, "InventoryFull"
	end

	print(string.format("[CraftingService] Crafted %s x%d for %s", outputId, outputCount, plr.Name))
	
	return true, "Success"
end

-- Get all recipes available at a station
function CraftingService:GetAvailableRecipes(stationType)
	return WorkbenchConfig:GetRecipesForStation(stationType or "Hand")
end

function CraftingService:Init()
	if self._initialized then return end
	self._initialized = true
	
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	local rCraft = Util.GetRemote(remotesFolder, Config.RemoteNames.Craft)
	
	if rCraft then
		rCraft.OnServerEvent:Connect(function(plr, recipeId, stationType)
			print(string.format("[CraftingService] Received craft request from %s for %s at %s", 
				plr.Name, tostring(recipeId), tostring(stationType or "Hand")))
			local ok, reason, extra = self:Craft(plr, recipeId, stationType)
			local normalizedReason = reason or (ok and "Success" or "Unknown")
			rCraft:FireClient(plr, "Result", {
				Success = ok == true,
				RecipeId = recipeId,
				Reason = normalizedReason,
				Extra = extra,
				StationType = stationType or "Hand",
			})
			if not ok then
				warn(string.format("[CraftingService] Craft failed for %s: %s (%s)", 
					plr.Name, tostring(normalizedReason), tostring(extra)))
			end
		end)
		print("[CraftingService] Initialized - listening for craft requests")
	else
		warn("[CraftingService] Could not find Craft remote!")
	end
end

return CraftingService
