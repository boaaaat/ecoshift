-- CraftingService.lua
-- Server-side crafting with station validation, timed processing, and station modifiers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local WorkbenchConfig = require(ReplicatedStorage.Shared.WorkbenchConfig)
local InventoryService = require(script.Parent.InventoryService)
local GameStateService = require(script.Parent.GameStateService)
local ItemDropService = require(script.Parent.ItemDropService)

local CraftingService = {}
CraftingService._initialized = false
CraftingService._remote = nil
CraftingService._activeCrafts = {} -- [player] = { Token, RecipeId, EndsAt }
CraftingService._tokenCounter = 0

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

local function nextToken(self)
	self._tokenCounter += 1
	return tostring(self._tokenCounter)
end

local function emitResult(self, plr, recipeId, stationType, success, reason, extra)
	local remote = self._remote
	if not remote or not plr then return end
	remote:FireClient(plr, "Result", {
		Success = success == true,
		RecipeId = recipeId,
		Reason = reason or (success and "Success" or "Unknown"),
		Extra = extra,
		StationType = stationType or "Hand",
	})
end

local function refundIngredients(plr, ingredients, dropPosition)
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	local basePos = dropPosition or (root and root.Position)
	for _, entry in ipairs(ingredients or {}) do
		local itemId = entry and entry.Id
		local amount = math.max(0, math.floor(tonumber(entry and entry.N) or 0))
		if itemId and amount > 0 then
			local added = dropPosition and 0 or InventoryService:Give(plr, itemId, amount)
			local remaining = amount - added
			if remaining > 0 and basePos then
				ItemDropService:SpawnDrop(itemId, remaining, basePos + Vector3.new(0, 2, 0))
			end
		end
	end
end

-- Find nearest workbench of a specific type within range
function CraftingService:FindNearbyStation(plr, stationType)
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local station = WorkbenchConfig.STATIONS[stationType]
	if not station then return nil end

	local buildType = station.BuildType
	if not buildType then return nil end

	local interactRadius = station.InteractRadius or 8
	local nearestStation = nil
	local nearestDist = interactRadius

	for _, structure in ipairs(CollectionService:GetTagged("Structure")) do
		local structType = structure:GetAttribute("BuildType") or structure:GetAttribute("StationType")
		if structure:IsDescendantOf(workspace) and (structType == buildType or structType == stationType) then
			local pos
			if structure:IsA("Model") then
				pos = structure:GetPivot().Position
			elseif structure:IsA("BasePart") then
				pos = structure.Position
			end

			if pos then
				local dist = (root.Position - pos).Magnitude
				if dist <= nearestDist then
					nearestDist = dist
					nearestStation = structure
				end
			end
		end
	end

	return nearestStation
end

function CraftingService:CanCraft(plr, recipeId, stationType)
	if type(recipeId) ~= "string" or (stationType ~= nil and type(stationType) ~= "string") then
		return false, "InvalidRequest"
	end
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or plr:GetAttribute("IsDead") then
		return false, "NotAlive"
	end
	if GameStateService:IsGameOver() then
		return false, "GameOver"
	end
	local recipe = resolveRecipe(recipeId)
	if not recipe then
		return false, "NoRecipe"
	end

	local effectiveStation = stationType or "Hand"
	if not WorkbenchConfig:CanCraftAt(recipeId, effectiveStation) then
		local minStation = WorkbenchConfig:GetMinimumStation(recipeId)
		return false, "WrongStation", minStation
	end

	if effectiveStation ~= "Hand" then
		local foundStation = self:FindNearbyStation(plr, effectiveStation)
		if not foundStation then
			return false, "NotNearStation", effectiveStation
		end
	end

	local ingredients = recipe.Ingredients or recipe
	local adjusted = adjustedIngredientsForPlayer(plr, ingredients)
	if not InventoryService:CanAfford(plr, adjusted) then
		return false, "MissingItems"
	end

	if self._activeCrafts[plr] then
		return false, "CraftInProgress"
	end

	return true
end

function CraftingService:_completeCraft(plr, context)
	if not plr or not context then return end
	local active = self._activeCrafts[plr]
	if not active or active.Token ~= context.Token then
		return
	end
	self._activeCrafts[plr] = nil
	if plr.Parent ~= Players then return end
	local hum = context.Character and context.Character:FindFirstChildOfClass("Humanoid")
	if plr.Character ~= context.Character or not hum or hum.Health <= 0 or plr:GetAttribute("IsDead") then
		refundIngredients(plr, context.Ingredients, context.Position)
		emitResult(self, plr, context.RecipeId, context.StationType, false, "NotAlive")
		return
	end
	if GameStateService:IsGameOver() then
		refundIngredients(plr, context.Ingredients)
		emitResult(self, plr, context.RecipeId, context.StationType, false, "GameOver")
		return
	end

	local outputCount = math.max(1, math.floor(tonumber(context.OutputCount) or 1))
	if (tonumber(context.ExtraYieldChance) or 0) > 0 then
		if math.random() <= context.ExtraYieldChance then
			outputCount += 1
		end
	end

	local added = InventoryService:Give(plr, context.OutputId, outputCount, true)
	if added ~= outputCount then
		refundIngredients(plr, context.Ingredients)
		emitResult(self, plr, context.RecipeId, context.StationType, false, "InventoryFull")
		return
	end

	emitResult(self, plr, context.RecipeId, context.StationType, true, "Success", {
		OutputId = context.OutputId,
		OutputCount = outputCount,
		Duration = context.Duration,
	})
end

function CraftingService:Craft(plr, recipeId, stationType)
	local ok, reason, extra = self:CanCraft(plr, recipeId, stationType)
	if not ok then
		return false, reason, extra
	end

	local recipe = resolveRecipe(recipeId)
	if not recipe then
		return false, "NoRecipe"
	end

	local effectiveStation = stationType or "Hand"
	local ingredients = adjustedIngredientsForPlayer(plr, recipe.Ingredients or recipe)
	local output = recipe.Output or { Id = recipeId, N = 1 }
	local outputId = output.Id or recipeId
	local outputCount = math.max(1, math.floor(tonumber(output.N) or 1))

	if not InventoryService:PayCost(plr, ingredients) then
		return false, "ConsumeFailed"
	end

	local baseTime = tonumber(recipe.BaseCraftTime) or 0
	local timeMult, extraYieldChance = WorkbenchConfig:GetEffectiveStationModifiers(recipe, effectiveStation)
	local duration = math.max(0.05, baseTime * timeMult)

	local token = nextToken(self)
	self._activeCrafts[plr] = {
		Token = token,
		RecipeId = recipeId,
		EndsAt = os.clock() + duration,
	}

	local context = {
		Character = plr.Character,
		Position = plr.Character:GetPivot().Position,
		Token = token,
		RecipeId = recipeId,
		StationType = effectiveStation,
		Ingredients = ingredients,
		OutputId = outputId,
		OutputCount = outputCount,
		ExtraYieldChance = extraYieldChance,
		Duration = duration,
	}

	task.delay(duration, function()
		local completed, err = pcall(function()
			CraftingService:_completeCraft(plr, context)
		end)
		if not completed then
			warn("[CraftingService] Craft completion failed:", err)
		end
	end)

	return true, "Queued", { Duration = duration }
end

function CraftingService:GetAvailableRecipes(stationType)
	return WorkbenchConfig:GetRecipesForStation(stationType or "Hand")
end

function CraftingService:Init()
	if self._initialized then return end
	self._initialized = true

	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	local rCraft = Util.GetRemote(remotesFolder, Config.RemoteNames.Craft)
	self._remote = rCraft

	if rCraft then
		rCraft.OnServerEvent:Connect(function(plr, recipeId, stationType)
			local success, resultReason, extra = self:Craft(plr, recipeId, stationType)
			if success and resultReason == "Queued" then
				return
			end
			emitResult(self, plr, recipeId, stationType or "Hand", success == true, resultReason, extra)
		end)
	else
		warn("[CraftingService] Could not find Craft remote!")
	end

	Players.PlayerRemoving:Connect(function(plr)
		self._activeCrafts[plr] = nil
	end)
end

return CraftingService
