-- Meals debit only after eating completes. Persist remaining active time, never wall time.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Cooking = require(RS.Shared.CookingConfig)
local Food = {}
local gameState
local states = setmetatable({}, {__mode = "k"})
local MODIFIERS = {"HungerDrainReduction","HeatReduction","PoisonDamageReduction","ColdReduction","MonsterDamageBonus","ResourcePowerBonus","ExposureRecoveryBonus","SprintDrainReduction","WetnessReduction","StaminaRecoveryBonus","GatherDurationReduction","MonsterDamageReduction","DodgeDrainReduction","SwimSpeedBonus","AirDrainReduction","SpecialDrainReduction"}

local function state(player)
	if not states[player] then states[player] = {Thermal = {}, FoodCooldown = 0, DrinkCooldown = 0} end
	return states[player]
end

local function living(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return player.Parent == Players and not player:GetAttribute("IsDead") and humanoid and humanoid.Health > 0
end

local function ready(player)
	return living(player) and gameState and not gameState:IsGameOver() and not RS:GetAttribute("WorldRestoring") and not player:GetAttribute("WorldPlayerRestoring") and not player:GetAttribute("WorldPlayerLoading")
end

local function meal(id)
	if type(id) ~= "string" then return nil end
	local recipe, seasoning = Cooking.GetMeal(id)
	return recipe or (Cooking.Snacks or {})[id], seasoning
end

local function publish(player, entry)
	local seasoning = entry.Seasoning and Cooking.Seasonings[entry.Seasoning.Id]
	for _, key in ipairs(MODIFIERS) do player:SetAttribute("Food_" .. key, seasoning and seasoning.Modifiers[key] or 0) end
	player:SetAttribute("FoodSeasoning", seasoning and entry.Seasoning.Id or nil)
	player:SetAttribute("FoodSeasoningRemaining", entry.Seasoning and math.ceil(entry.Seasoning.Remaining) or 0)
	for _, channel in ipairs({"Heat", "Cold"}) do
		player:SetAttribute("FoodThermal_" .. channel, entry.Thermal[channel] and entry.Thermal[channel].Reduction or 0)
	end
end

function Food:CanConsume(id)
	local recipe, seasoning = meal(id)
	return RS:GetAttribute("CookingEnabled") == true and recipe ~= nil
end

function Food:Consume(player, slotType, slotIndex, callback)
	local Inventory = require(script.Parent.InventoryService)
	local slot = Inventory:PeekSlot(player, slotType, slotIndex)
	local recipe, seasoning = meal(slot and slot.Id)
	if not recipe or not self:CanConsume(slot.Id) or not ready(player) then return false, "You cannot eat this right now." end
	local entry = state(player)
	local channel = recipe.Drink and "DrinkCooldown" or "FoodCooldown"
	if entry.Pending then return false, "Finish eating first." end
	if entry[channel] > 0 then return false, "Wait " .. math.ceil(entry[channel]) .. "s before " .. (recipe.Drink and "drinking." or "eating.") end
	local itemId, character = slot.Id, player.Character
	local token = {}
	entry.Pending = token
	player:SetAttribute("FoodEating", true)
	local function finish(success, message)
		if entry.Pending == token then entry.Pending = nil; player:SetAttribute("FoodEating", false) end
		if player.Parent == Players and callback then callback(success, message) end
	end
	task.delay(recipe.Drink and 0 or 2, function()
		if entry.Pending ~= token then return end
		local Stats = require(script.Parent.StatsService)
		local Rewards = require(script.Parent.ExpeditionRewardsService)
		-- Requires may initialize dependencies; revalidate after their possible yields.
		if entry.Pending ~= token then return end
		if not ready(player) or player.Character ~= character or RS:GetAttribute("CookingEnabled") ~= true then
			finish(false, "Eating cancelled; your food was kept."); return
		end
		-- No yielding between the debit and its benefit.
		local removed = Inventory:TakeFromSlot(player, slotType, slotIndex, 1, {ExpectedId = itemId, DeferSync = true})
		if not removed then finish(false, "The item moved; nothing was consumed."); return end
		local bonus = 1 + (player:GetAttribute("Class_FoodBonus") or 0)
		local temperature = Stats:GetBase(player, "Temperature") or 0
		local oldTemperature=temperature
		local overflow=math.max(0,(Stats:GetBase(player,"Hunger") or 0)+(recipe.Hunger or 0)*bonus-(Stats:GetStat(player,"MaxHunger") or 100))
		local relief = recipe.ExposureRelief or {}
		if temperature > 0 then temperature = math.max(0, temperature - ((relief.Heat or 0)+(recipe.Drink and require(script.Parent.GearService):GetModifiers(player).WaterExposureBonus or 0)))
		elseif temperature < 0 then temperature = math.min(0, temperature + (relief.Cold or 0)) end
		Stats:SetBaseStats(player, {
			Hunger = math.min(Stats:GetStat(player, "MaxHunger") or 100, (Stats:GetBase(player, "Hunger") or 0) + (recipe.Hunger or 0) * bonus),
			Stamina = math.min(Stats:GetStat(player, "MaxStamina") or 100, (Stats:GetBase(player, "Stamina") or 0) + (recipe.Stamina or 0) * bonus),
			Temperature = temperature,
		})
		require(script.Parent.GearService):OnConsumable(player,oldTemperature,overflow,recipe.Drink)
		if seasoning then entry.Seasoning = {Id = seasoning.Id, Remaining = seasoning.Duration or 240} end
		local thermal = recipe.Thermal
		if thermal and (thermal.Channel == "Heat" or thermal.Channel == "Cold") then
			entry.Thermal = {[thermal.Channel] = {Reduction = thermal.Reduction, Remaining = thermal.Duration}}
		end
		entry[channel] = recipe.Drink and 3 or 5
		publish(player, entry)
		Inventory:Sync(player)
		Rewards:RecordActivity(player)
		finish(true, (recipe.Name or itemId) .. (seasoning and (" · " .. seasoning.Name .. " active for 4 minutes") or " consumed."))
	end)
	return true, recipe.Drink and "Drinking…" or "Eating… (2s)"
end

function Food:CapturePlayer(player)
	local entry = state(player)
	local result = {FoodCooldown = entry.FoodCooldown, DrinkCooldown = entry.DrinkCooldown, Thermal = {}}
	if entry.Seasoning then result.Seasoning = table.clone(entry.Seasoning) end
	for key, value in pairs(entry.Thermal) do result.Thermal[key] = table.clone(value) end
	return result
end

local function bounded(value, maximum)
	return type(value) == "number" and value == value and math.clamp(value, 0, maximum) or 0
end

function Food:RestorePlayer(player, saved)
	if states[player] then states[player].Pending = nil end
	local entry = {Thermal = {}, FoodCooldown = 0, DrinkCooldown = 0}
	states[player] = entry
	player:SetAttribute("FoodEating", false)
	if type(saved) == "table" then
		entry.FoodCooldown = bounded(saved.FoodCooldown, 5)
		entry.DrinkCooldown = bounded(saved.DrinkCooldown, 3)
		local s = saved.Seasoning
		local definition = type(s) == "table" and Cooking.Seasonings[s.Id]
		if definition and bounded(s.Remaining, 240) > 0 then entry.Seasoning = {Id = s.Id, Remaining = bounded(s.Remaining, 240)} end
		for _, key in ipairs({"Heat", "Cold"}) do
			local value = type(saved.Thermal) == "table" and saved.Thermal[key]
			if type(value) == "table" and bounded(value.Remaining, 120) > 0 then
				entry.Thermal[key] = {Reduction = bounded(value.Reduction, .35), Remaining = bounded(value.Remaining, 120)}
				break
			end
		end
	end
	publish(player, entry)
end

function Food:Init()
	if self._initialized then return end
	self._initialized = true
	local function bind(player)
		player:GetAttributeChangedSignal("IsDead"):Connect(function()
			if player:GetAttribute("IsDead") then self:RestorePlayer(player, nil) end
		end)
	end
	Players.PlayerAdded:Connect(bind)
	for _, player in ipairs(Players:GetPlayers()) do bind(player) end
	Players.PlayerRemoving:Connect(function(player)
		-- Snapshot listeners may run after this signal; keep effects readable until then.
		local entry = states[player]
		if entry then entry.Pending = nil end
	end)
	local elapsed = 0
	gameState = require(script.Parent.GameStateService)
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < .25 then return end
		local step = elapsed; elapsed = 0
		for player, entry in pairs(states) do
			if gameState:IsGameOver() and (entry.Seasoning or next(entry.Thermal) or entry.Pending) then
				self:RestorePlayer(player, nil)
			elseif ready(player) then
				entry.FoodCooldown = math.max(0, entry.FoodCooldown - step)
				entry.DrinkCooldown = math.max(0, entry.DrinkCooldown - step)
				if entry.Seasoning then entry.Seasoning.Remaining -= step; if entry.Seasoning.Remaining <= 0 then entry.Seasoning = nil end end
				for key, value in pairs(entry.Thermal) do value.Remaining -= step; if value.Remaining <= 0 then entry.Thermal[key] = nil end end
				publish(player, entry)
			elseif player:GetAttribute("IsDead") and (entry.Seasoning or next(entry.Thermal)) then self:RestorePlayer(player, nil) end
		end
	end)
end

return Food
