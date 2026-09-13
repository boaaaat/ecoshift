-- Shared station work: paid ingredients stay in escrow until a serving commits.
-- No operation between inventory debit and station-state commit yields.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Cooking = require(RS.Shared.CookingConfig)
local Items = require(RS.Shared.Items.ItemDatabase)
local Inventory = require(script.Parent.InventoryService)
local Codec = require(script.Parent.WorldSnapshotCodec)
local GameState = require(script.Parent.GameStateService)
local Service = { _stations = {}, _viewers = {}, _requests = {}, _limits = {} }
local OUTPUT_SLOTS, MAX_JOBS, MAX_QUANTITY, MAX_FUEL = 12, 3, 20, 3600

local function integer(value, minimum, maximum)
	return type(value) == "number" and value == value and value % 1 == 0 and value >= minimum and value <= maximum
end
local function alive(player)
	local character = player and player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	return player and player.Parent == Players and hum and hum.Health > 0 and not player:GetAttribute("IsDead")
		and not player:GetAttribute("WorldPlayerLoading") and not player:GetAttribute("WorldPlayerRestoring")
end
local function paused()
	return RS:GetAttribute("CookingEnabled") == false or RS:GetAttribute("WorldRestoring") or GameState:IsGameOver()
		or not Service:_crewLoaded()
end
function Service:_crewLoaded()
	for _, player in ipairs(Players:GetPlayers()) do
		if not player:GetAttribute("WorldPlayerLoading") and not player:GetAttribute("WorldPlayerRestoring") then return true end
	end
	return false
end
local function stationType(station)
	if typeof(station) ~= "Instance" or not (station:IsA("Model") or station:IsA("BasePart"))
		or not station:IsDescendantOf(workspace) or not CollectionService:HasTag(station, "Structure") then return nil end
	local kind = station:GetAttribute("BuildType")
	return Cooking.Stations[kind] and kind or nil
end
local function inReach(player, station)
	if not alive(player) or not stationType(station) then return false end
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	return root and (root.Position - station:GetPivot().Position).Magnitude <= 10
end
local function newState()
	local output = {}
	for i = 1, OUTPUT_SLOTS do output[i] = false end
	return { Version = 1, Jobs = {}, Output = output, FuelSeconds = 0, KeepWarm = false, Enabled = true }
end
local function outputSlot(state, itemId)
	local recipe = Cooking.GetMeal(itemId)
	local limit = math.min(Items:Get(itemId).StackSize, recipe.StackSize or 10)
	for i, slot in ipairs(state.Output) do if slot and slot.Id == itemId and slot.N < limit then return i end end
	for i, slot in ipairs(state.Output) do if not slot then return i end end
	return nil
end
local function addOutput(state, itemId, index)
	local slot = state.Output[index]
	if slot then slot.N += 1 else state.Output[index] = { Id = itemId, N = 1 } end
end
local function ingredients(recipe, seasoningId, quantity)
	local result = {}
	for _, entry in ipairs(recipe.Ingredients) do table.insert(result, { Id = entry.Id, N = entry.N * quantity }) end
	if seasoningId then table.insert(result, { Id = seasoningId, N = quantity }) end
	return result
end
function Service:_get(station)
	local state = self._stations[station]
	if not state then state = newState(); self._stations[station] = state end
	return state
end
function Service:_rate(job, station)
	local sponsor = job and Players:GetPlayerByUserId(job.OwnerUserId)
	if not alive(sponsor) then sponsor = nil end
	return self._abilities:GetCraftRate(sponsor, station)
end
function Service:_burning(station, enabled)
	if station:GetAttribute("CookingBurning") == enabled then return end
	station:SetAttribute("CookingBurning", enabled)
	for _, object in ipairs(station:GetDescendants()) do
		if object:IsA("Fire") or object:IsA("Smoke") or object:IsA("ParticleEmitter") or object:IsA("Light") then
			object.Enabled = enabled
		elseif object:IsA("BasePart") and (object.Name == "Flame" or object.Name == "FireGlow") then
			object.Transparency = enabled and 0.15 or 1
		end
	end
end
function Service:_status(station, state)
	if paused() then return "World paused" end
	if not state.Enabled then return "Paused" end
	if state.Jobs[1] then
		if not outputSlot(state, state.Jobs[1].OutputId) then return "Output full" end
		return state.FuelSeconds > 0 and "Cooking" or "Add fuel"
	end
	if state.KeepWarm and stationType(station) == "Campfire" then return state.FuelSeconds > 0 and "Keeping warm" or "Add fuel" end
	return "Idle"
end
function Service:_state(station)
	local state, jobs = self:_get(station), {}
	local total = 0
	for _, job in ipairs(state.Jobs) do
		local rate = self:_rate(job, station)
		local seconds = (job.Remaining * job.WorkRequired - job.Work) / rate
		total += seconds
		table.insert(jobs, { Id = job.Id, RecipeId = job.RecipeId, SeasoningId = job.SeasoningId,
			Quantity = job.Quantity, Remaining = job.Remaining, Work = job.Work, WorkRequired = job.WorkRequired,
			Rate = rate, RemainingSeconds = seconds, OwnerUserId = job.OwnerUserId })
	end
	return { Station = station, StationType = stationType(station), Jobs = jobs, Output = Codec.Copy(state.Output),
		FuelSeconds = state.FuelSeconds, KeepWarm = state.KeepWarm, Enabled = state.Enabled,
		Status = self:_status(station, state), RemainingSeconds = total }
end
function Service:Open(player, station, recipeId, seasoningId)
	if paused() or not inReach(player, station) then return false, "Move closer to a placed cooking station." end
	self._viewers[player] = station
	local state = self:_state(station)
	if type(recipeId) == "string" and Cooking.Recipes[recipeId] then
		state.RecipeId = recipeId
		if type(seasoningId) == "string" and Cooking.GetOutputId(recipeId, seasoningId) then state.SeasoningId = seasoningId end
	end
	self._remote:FireClient(player, "Open", state)
	return true, "Kitchen opened."
end
function Service:Queue(player, station, payload)
	local state = self:_get(station)
	if #state.Jobs >= MAX_JOBS then return false, "This station already has three queued jobs." end
	local recipe = type(payload.RecipeId) == "string" and Cooking.Recipes[payload.RecipeId]
	local seasoning = payload.SeasoningId
	if seasoning == "" or seasoning == false then seasoning = nil end
	if not recipe or recipe.Future or recipe.StationType ~= stationType(station) then return false, "Choose a recipe for this station." end
	if seasoning and (type(seasoning) ~= "string" or not Cooking.Seasonings[seasoning]
		or Cooking.Seasonings[seasoning].Future or recipe.Drink) then return false, "Choose one available seasoning for a meal." end
	if not integer(payload.Quantity, 1, MAX_QUANTITY) then return false, "Choose 1–20 servings." end
	local outputId = Cooking.GetOutputId(recipe.Id, seasoning)
	if not outputId or not Items:Get(outputId) then return false, "This meal is not available." end
	local cost = ingredients(recipe, seasoning, payload.Quantity)
	local job = { Id = HttpService:GenerateGUID(false), RecipeId = recipe.Id, SeasoningId = seasoning,
		RecipeVersion = 1, Quantity = payload.Quantity, Remaining = payload.Quantity,
		Work = 0, WorkRequired = recipe.WorkSeconds, OutputId = outputId,
		UnitCost = ingredients(recipe, seasoning, 1), OwnerUserId = player.UserId }
	if not Inventory:PayCost(player, cost, true) then return false, "Missing ingredients or seasoning." end
	table.insert(state.Jobs, job)
	Inventory:Sync(player)
	-- Preparing a real meal counts once; unattended station progress never credits activity.
	self._rewards:RecordActivity(player)
	return true, "Meals queued."
end
function Service:Cancel(player, station, jobId)
	if type(jobId) ~= "string" then return false, "Choose a queued job." end
	local state = self:_get(station)
	for index, job in ipairs(state.Jobs) do
		if job.Id == jobId then
			if job.OwnerUserId ~= player.UserId and station:GetAttribute("OwnerUserId") ~= player.UserId
				and Players:GetPlayerByUserId(job.OwnerUserId) then return false, "Only the cook or station owner can cancel this job." end
			local refund = {}
			for _, entry in ipairs(job.UnitCost) do table.insert(refund, { Id = entry.Id, N = entry.N * job.Remaining }) end
			local projected, overflow = Inventory:ProjectRefund(Inventory:CaptureWorldState(player), refund, false)
			if #overflow > 0 then return false, "Make room in your pack for the ingredient refund." end
			Inventory:RestoreWorldState(player, projected, true)
			table.remove(state.Jobs, index)
			Inventory:Sync(player)
			return true, "Unfinished ingredients and seasoning returned; spent fuel stays spent."
		end
	end
	return false, "That job already finished or was canceled."
end
function Service:Fuel(player, station, payload)
	local seconds = type(payload.ItemId) == "string" and Cooking.Fuels[payload.ItemId]
	if not seconds or not integer(payload.Quantity, 1, MAX_QUANTITY) then return false, "Choose wood, peat, or coal and a valid quantity." end
	local state = self:_get(station)
	local added = seconds * payload.Quantity
	if state.FuelSeconds + added > MAX_FUEL then return false, "Fuel reserve is limited to 60 minutes." end
	if not Inventory:PayCost(player, { { Id = payload.ItemId, N = payload.Quantity } }, true) then return false, "Not enough fuel in your pack." end
	state.FuelSeconds += added
	Inventory:Sync(player)
	return true, "Fuel added."
end
function Service:Collect(player, station, payload)
	if not integer(payload.Slot, 1, OUTPUT_SLOTS) then return false, "Choose a finished meal." end
	local state = self:_get(station)
	local slot = state.Output[payload.Slot]
	if not slot then return false, "That output was already collected." end
	if payload.ExpectedId and payload.ExpectedId ~= slot.Id then return false, "The output changed. Select it again." end
	local amount = payload.Quantity or slot.N
	if not integer(amount, 1, slot.N) then return false, "Invalid output quantity." end
	if Inventory:Give(player, slot.Id, amount, true, true) ~= amount then return false, "Make room in your pack for these meals." end
	slot.N -= amount
	if slot.N == 0 then state.Output[payload.Slot] = false end
	Inventory:Sync(player)
	return true, "Meals collected."
end
function Service:CanSalvage(station)
	local state = self._stations[station]
	if not state then return true end
	if #state.Jobs > 0 then return false, "CookingQueueNotEmpty" end
	for _, slot in ipairs(state.Output) do if slot then return false, "CookingOutputNotEmpty" end end
	return true
end
function Service:CaptureStation(station)
	if RS:GetAttribute("CookingEnabled") == false or not stationType(station) then return nil end
	return Codec.Copy(self:_get(station))
end
function Service:RestoreStation(station, saved)
	if not Cooking.Stations[station:GetAttribute("BuildType")] then return end
	local state = saved and Codec.Copy(saved) or newState()
	assert(state.Version == 1, "Unsupported cooking station snapshot")
	Codec.BoundedCount(state.Jobs, MAX_JOBS)
	assert(#state.Output == OUTPUT_SLOTS, "Invalid cooking output snapshot")
	Codec.Number(state.FuelSeconds, 0, MAX_FUEL)
	assert(type(state.KeepWarm) == "boolean" and type(state.Enabled) == "boolean", "Invalid cooking controls")
	local ids = {}
	for _, job in ipairs(state.Jobs) do
		Codec.Text(job.Id, 80)
		assert(not ids[job.Id], "Duplicate saved cooking job")
		ids[job.Id] = true
		local recipe = Cooking.Recipes[job.RecipeId]
		assert(recipe and recipe.StationType == station:GetAttribute("BuildType") and job.RecipeVersion == 1, "Saved cooking recipe unavailable")
		assert(integer(job.Quantity, 1, MAX_QUANTITY) and integer(job.Remaining, 1, job.Quantity), "Invalid saved servings")
		Codec.Number(job.WorkRequired, 0.05, 3600)
		Codec.Number(job.Work, 0, job.WorkRequired)
		Codec.Number(job.OwnerUserId, -1e12, 1e12)
		assert(job.OutputId == Cooking.GetOutputId(job.RecipeId, job.SeasoningId) and Items:Get(job.OutputId), "Invalid saved meal variant")
		assert(#job.UnitCost > 0 and #job.UnitCost <= 12, "Invalid cooking escrow")
		for _, entry in ipairs(job.UnitCost) do assert(Items:Get(entry.Id) and integer(entry.N, 1, 999), "Invalid cooking ingredient escrow") end
	end
	for _, slot in ipairs(state.Output) do
		if slot then
			assert(type(slot) == "table" and Cooking.GetMeal(slot.Id) and Items:Get(slot.Id)
				and integer(slot.N, 1, Items:Get(slot.Id).StackSize), "Invalid saved cooked output")
		end
	end
	self._stations[station] = state
	self:_burning(station, false)
end
function Service:_tick(dt)
	local stopped = paused()
	for station, state in pairs(self._stations) do
		if not stationType(station) then
			self._stations[station] = nil
		else
			local burning = false
			if not stopped and state.Enabled and state.FuelSeconds > 0 then
				local remaining = dt
				while remaining > 0 and state.FuelSeconds > 0 do
					local job = state.Jobs[1]
					if not job then
						if state.KeepWarm and stationType(station) == "Campfire" then
							state.FuelSeconds = math.max(0, state.FuelSeconds - remaining); burning = true
						end
						break
					end
					local index = outputSlot(state, job.OutputId)
					if not index then
						if state.KeepWarm and stationType(station) == "Campfire" then
							state.FuelSeconds = math.max(0, state.FuelSeconds - remaining); burning = true
						end
						break
					end
					local rate = self:_rate(job, station)
					local spent = math.min(remaining, state.FuelSeconds, math.max(0, (job.WorkRequired - job.Work) / rate))
					job.Work = math.min(job.WorkRequired, job.Work + spent * rate)
					state.FuelSeconds = math.max(0, state.FuelSeconds - spent)
					remaining -= spent
					burning = true
					if job.Work >= job.WorkRequired - 0.00001 then
						-- Output, work and ingredient escrow commit within this non-yielding step.
						addOutput(state, job.OutputId, index)
						job.Remaining -= 1
						job.Work = 0
						if job.Remaining == 0 then table.remove(state.Jobs, 1) end
					elseif spent <= 0 then break end
				end
			end
			self:_burning(station, burning and state.FuelSeconds > 0)
		end
	end
	for player, station in pairs(self._viewers) do
		if not inReach(player, station) then
			self._viewers[player] = nil
			if player.Parent == Players then self._remote:FireClient(player, "Closed", { Message = "You moved away from the kitchen." }) end
		else self._remote:FireClient(player, "State", self:_state(station)) end
	end
end
function Service:_dispatch(player, action, payload)
	if action == "Close" then self._viewers[player] = nil; return true, "Closed." end
	local station = payload.Station
	if paused() or not inReach(player, station) then return false, "Move closer to a placed cooking station while alive." end
	if action == "Open" then return self:Open(player, station, payload.RecipeId, payload.SeasoningId) end
	if action == "Queue" then return self:Queue(player, station, payload) end
	if action == "Fuel" then return self:Fuel(player, station, payload) end
	if action == "Collect" then return self:Collect(player, station, payload) end
	if action == "Cancel" then return self:Cancel(player, station, payload.JobId) end
	if action == "SetEnabled" and type(payload.Enabled) == "boolean" then
		self:_get(station).Enabled = payload.Enabled
		if not payload.Enabled then self:_burning(station, false) end
		return true, payload.Enabled and "Cooking resumed." or "Cooking paused."
	end
	if action == "KeepWarm" and stationType(station) == "Campfire" and type(payload.Enabled) == "boolean" then
		self:_get(station).KeepWarm = payload.Enabled
		return true, payload.Enabled and "Campfire will stay warm while fueled." or "Campfire will stop after cooking."
	end
	return false, "Unknown cooking action."
end
function Service:Init()
	if self._initialized then return end
	self._initialized = true
	self._abilities = require(script.Parent.ClassAbilityService)
	self._rewards = require(script.Parent.ExpeditionRewardsService)
	self._remote = RS:WaitForChild("Remotes"):WaitForChild("Cooking")
	self._remote.OnServerEvent:Connect(function(player, action, payload)
		if type(action) ~= "string" or type(payload) ~= "table" or type(payload.RequestId) ~= "string"
			or #payload.RequestId < 1 or #payload.RequestId > 80 then return end
		local requests = self._requests[player]
		if not requests then requests = { Order = {}, Results = {} }; self._requests[player] = requests end
		local previous = requests.Results[payload.RequestId]
		if previous then self._remote:FireClient(player, "Result", previous); return end
		local now = os.clock()
		local limit = self._limits[player]
		if not limit or now - limit.Start >= 1 then limit = { Start = now, Count = 0 }; self._limits[player] = limit end
		limit.Count += 1
		local success, message
		if limit.Count > 15 then success, message = false, "Too many requests. Try again in a moment."
		else success, message = self:_dispatch(player, action, payload) end
		local result = { RequestId = payload.RequestId, Success = success == true, Message = message }
		requests.Results[payload.RequestId] = result
		table.insert(requests.Order, payload.RequestId)
		if #requests.Order > 256 then requests.Results[table.remove(requests.Order, 1)] = nil end
		self._remote:FireClient(player, "Result", result)
		local station = self._viewers[player]
		if station and inReach(player, station) then self._remote:FireClient(player, "State", self:_state(station)) end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._viewers[player], self._requests[player], self._limits[player] = nil, nil, nil
	end)
	CollectionService:GetInstanceAddedSignal("Structure"):Connect(function(station)
		if RS:GetAttribute("CookingEnabled") ~= false and stationType(station) then self:_get(station); self:_burning(station, false) end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then return end
		local step = elapsed; elapsed = 0
		self:_tick(step)
	end)
end
return Service
