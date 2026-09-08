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
local Codec = require(script.Parent.WorldSnapshotCodec)

local CraftingService = {}
CraftingService._initialized = false
CraftingService._remote = nil
CraftingService._activeCrafts = {} -- Paid ingredients remain escrowed until output/refund commits.
CraftingService._tokenCounter = 0
local MAX_QUANTITY = 99

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
	if not remote or not plr or plr.Parent ~= Players then return end
	remote:FireClient(plr, "Result", {
		Success = success == true,
		RecipeId = recipeId,
		Reason = reason or (success and "Success" or "Unknown"),
		Extra = extra,
		StationType = stationType or "Hand",
	})
end

local function validQuantity(quantity)
	return type(quantity) == "number" and quantity == quantity and quantity % 1 == 0 and quantity >= 1 and quantity <= MAX_QUANTITY
end

local function prepareRefund(inventory, refund)
	assert(type(refund) == "table" and type(refund.DropOnly) == "boolean", "Invalid craft refund")
	local position = Codec.ReadCFrame(refund.Transform).Position
	local projected, overflow = InventoryService:ProjectRefund(inventory, refund.Ingredients, refund.DropOnly)
	local prepared = {}
	local ok, err = pcall(function()
		for _, entry in ipairs(overflow) do
			local drop = ItemDropService:SpawnDrop(entry.Id, entry.N, position + Vector3.new(0, 2, 0), {PendingPickup = true})
			assert(drop, "Craft refund drop preparation failed")
			table.insert(prepared, drop)
		end
	end)
	if not ok then for _, drop in ipairs(prepared) do drop:Destroy() end; error(err) end
	return projected, prepared
end

local function unlockRefundDrops(prepared)
	for _, drop in ipairs(prepared) do drop:SetAttribute("PickupPending", nil) end
end

function CraftingService:CaptureRefund(plr)
	local context = self._activeCrafts[plr]
	if not context then return nil end
	local hum = context.Character and context.Character:FindFirstChildOfClass("Humanoid")
	return {Ingredients = Codec.Copy(context.Ingredients), Transform = Codec.CFrame(CFrame.new(context.Position)),
		DropOnly = context.DropOnly == true or plr.Character ~= context.Character or not hum or hum.Health <= 0 or plr:GetAttribute("IsDead") == true}
end

-- Checkpoints preserve paid materials, never a ticking craft. Restoring always
-- cancels that craft; overflow belongs only to this player escrow until committed.
function CraftingService:RestoreRefund(plr, state)
	if not state.CraftRefund then return end
	local projected, prepared = prepareRefund(state.Inventory, state.CraftRefund)
	InventoryService:RestoreWorldState(plr, projected, true)
	-- Cache the committed inventory before callbacks: a later restore retry cannot
	-- revert the refund or produce these ground drops twice.
	state.Inventory, state.CraftRefund = projected, nil
	unlockRefundDrops(prepared)
	InventoryService:Sync(plr)
end

function CraftingService:_refundCraft(plr, context, reason)
	context.CancelReason = reason
	local projected, prepared = prepareRefund(InventoryService:CaptureWorldState(plr), self:CaptureRefund(plr))
	InventoryService:RestoreWorldState(plr, projected, true)
	self._activeCrafts[plr] = nil
	unlockRefundDrops(prepared)
	InventoryService:Sync(plr)
	emitResult(self, plr, context.RecipeId, context.StationType, false, reason)
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

function CraftingService:CanCraft(plr, recipeId, stationType, quantity)
	if type(recipeId) ~= "string" or (stationType ~= nil and type(stationType) ~= "string") then
		return false, "InvalidRequest"
	end
	quantity = quantity == nil and 1 or quantity
	if not validQuantity(quantity) then return false, "InvalidQuantity" end
	if ReplicatedStorage:GetAttribute("WorldRestoring") or plr:GetAttribute("WorldPlayerRestoring") or plr:GetAttribute("WorldPlayerLoading") then return false, "WorldLoading" end
	if self._activeCrafts[plr] then return false, "CraftInProgress" end
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
	for _, entry in ipairs(adjusted) do entry.N *= quantity end
	if not InventoryService:CanAfford(plr, adjusted) then
		return false, "MissingItems"
	end

	return true
end

function CraftingService:_completeCraft(plr, context)
	if not plr or not context then return end
	local active = self._activeCrafts[plr]
	if not active or active.Token ~= context.Token then
		return
	end
	if plr.Parent ~= Players then return end
	if ReplicatedStorage:GetAttribute("WorldRestoring") or plr:GetAttribute("WorldPlayerRestoring") or plr:GetAttribute("WorldPlayerLoading") then
		context.CancelReason = context.CancelReason or "WorldLoading"
		self:_scheduleCompletion(plr, context, 1)
		return
	end
	if context.CancelReason then self:_refundCraft(plr, context, context.CancelReason); return end
	local hum = context.Character and context.Character:FindFirstChildOfClass("Humanoid")
	if plr.Character ~= context.Character or not hum or hum.Health <= 0 or plr:GetAttribute("IsDead") then
		context.DropOnly = true
		self:_refundCraft(plr, context, "NotAlive")
		return
	end
	if GameStateService:IsGameOver() then
		self:_refundCraft(plr, context, "GameOver")
		return
	end

	local outputCount = math.max(1, math.floor(tonumber(context.OutputCount) or 1))
	if (tonumber(context.ExtraYieldChance) or 0) > 0 then
		for _ = 1, context.Quantity do
			if math.random() <= context.ExtraYieldChance then outputCount += 1 end
		end
	end

	local added = InventoryService:Give(plr, context.OutputId, outputCount, true, true)
	if added ~= outputCount then
		self:_refundCraft(plr, context, "InventoryFull")
		return
	end
	self._activeCrafts[plr] = nil
	InventoryService:Sync(plr)

	emitResult(self, plr, context.RecipeId, context.StationType, true, "Success", {
		OutputId = context.OutputId,
		OutputCount = outputCount,
		Duration = context.Duration,
		Quantity = context.Quantity,
	})
end

function CraftingService:_scheduleCompletion(plr, context, duration)
	task.delay(duration, function()
		local completed, err = pcall(self._completeCraft, self, plr, context)
		if not completed then
			warn("[CraftingService] Craft completion failed:", err)
			if self._activeCrafts[plr] == context and plr.Parent == Players then
				context.CancelReason = context.CancelReason or "RefundPending"
				self:_scheduleCompletion(plr, context, 2)
			end
		end
	end)
end

function CraftingService:Craft(plr, recipeId, stationType, quantity)
	quantity = quantity == nil and 1 or quantity
	local ok, reason, extra = self:CanCraft(plr, recipeId, stationType, quantity)
	if not ok then
		return false, reason, extra
	end

	local recipe = resolveRecipe(recipeId)
	if not recipe then
		return false, "NoRecipe"
	end

	local effectiveStation = stationType or "Hand"
	local ingredients = adjustedIngredientsForPlayer(plr, recipe.Ingredients or recipe)
	for _, entry in ipairs(ingredients) do entry.N *= quantity end
	local output = recipe.Output or { Id = recipeId, N = 1 }
	local outputId = output.Id or recipeId
	local outputCount = math.max(1, math.floor(tonumber(output.N) or 1)) * quantity

	local baseTime = tonumber(recipe.BaseCraftTime) or 0
	local timeMult, extraYieldChance = WorkbenchConfig:GetEffectiveStationModifiers(recipe, effectiveStation)
	local duration = math.max(0.05, baseTime * timeMult) * quantity

	local token = nextToken(self)
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
		Quantity = quantity,
		EndsAt = os.clock() + duration,
	}
	-- No callback can observe paid ingredients without their refund escrow.
	if not InventoryService:PayCost(plr, ingredients, true) then return false, "ConsumeFailed" end
	self._activeCrafts[plr] = context
	self:_scheduleCompletion(plr, context, duration)
	local started = {RecipeId = recipeId, StationType = effectiveStation, Duration = duration, Quantity = quantity, OutputId = outputId, OutputCount = outputCount}
	if self._remote and plr.Parent == Players then self._remote:FireClient(plr, "Started", started) end
	InventoryService:Sync(plr)
	return true, "Queued", started
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
		rCraft.OnServerEvent:Connect(function(plr, recipeId, stationType, quantity)
			local success, resultReason, extra = self:Craft(plr, recipeId, stationType, quantity)
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
