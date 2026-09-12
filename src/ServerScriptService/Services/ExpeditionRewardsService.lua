-- World snapshots retain earned claims; profile receipts make their payment idempotent.
-- There are no client grant remotes. Studio never sends these grants to live profiles.
-- Crash boundary: an unacknowledged claim newer than the last published world
-- snapshot can roll back; this service does not provide a separate durable outbox.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Economy = require(RS.Shared.EconomyConfig)
local Classes = require(RS.Shared.ClassConfig)
local Config = Economy.Rewards
-- Schema1 worlds predate pinned tuning. These are their original grant amounts.
local LEGACY_TUNING = {
	SurvivalSeconds = 300, Survival = { Currency = 20, XP = 25 },
	Objective = { Currency = 15, XP = 15 }, Revive = { Currency = 5, XP = 10 }, RevivesPerMilestone = 2,
}
local Util = require(RS.Shared.Util)
local Profile = require(script.Parent.ProfileService)
local Inventory = require(script.Parent.InventoryService)
local Round = require(script.Parent.RoundService)
local GameState = require(script.Parent.GameStateService)
local Service = { _players = {}, _objectives = {}, _deaths = {}, _pending = {}, _samples = {}, _flushing = {}, _delivering = {}, _activity = {}, _classSettled = {} }
local function validId(value)
	return type(value) == "string" and #value > 0 and #value <= 48 and value:match("^[%w_:%-]+$") ~= nil
end
local function number(value, maximum)
	return type(value) == "number" and value == value and value >= 0 and value <= (maximum or 1e9)
end
local function integer(value, maximum) return number(value, maximum) and value % 1 == 0 end
local function readTuning(raw)
	if type(raw) ~= "table" or not integer(raw.SurvivalSeconds, 86400) or raw.SurvivalSeconds < 1
		or not integer(raw.RevivesPerMilestone, 1000) then return nil end
	local result = { SurvivalSeconds = raw.SurvivalSeconds, RevivesPerMilestone = raw.RevivesPerMilestone }
	for _, kind in ipairs({ "Survival", "Objective", "Revive" }) do
		local reward = raw[kind]
		if type(reward) ~= "table" or not integer(reward.Currency, Economy.MaxRewardAmount)
			or not integer(reward.XP, Economy.MaxRewardAmount) or reward.Currency + reward.XP <= 0 then return nil end
		result[kind] = { Currency = reward.Currency, XP = reward.XP }
	end
	return result
end
local function userId(value)
	return type(value) == "number" and value % 1 == 0 and value ~= 0 and math.abs(value) <= 9007199254740991
end
local function userKey(value)
	return type(value) == "string" and userId(tonumber(value)) and tostring(tonumber(value)) == value
end
local function ownsLease()
	-- Client-local attribute edits do not change these server values. Studio only previews.
	if RunService:IsStudio() then return true end
	local deadline = RS:GetAttribute("WorldLeaseUntil")
	return RS:GetAttribute("WorldLeaseOwned") == true and type(deadline) == "number"
		and deadline == deadline and deadline < math.huge and deadline > os.time()
end
local function activeWorld()
	return RS:GetAttribute("PlaceMode") == "Expedition" and not RS:GetAttribute("WorldRestoring")
		and ownsLease() and not GameState:IsGameOver() and not Round:IsEnded()
end
local function participant(player)
	return player.Parent == Players and not player:GetAttribute("WorldPlayerLoading") and not player:GetAttribute("WorldPlayerRestoring")
end
local function alive(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return participant(player) and not player:GetAttribute("IsDead") and hum ~= nil and hum.Health > 0
end
local function count(map) local n = 0 for _ in pairs(map) do n += 1 end return n end
local function rewardsEnabled() return workspace:GetAttribute("WorldType") ~= "Creative" end

function Service:_world()
	local id = RS:GetAttribute("WorldId")
	if not validId(id) and RunService:IsStudio() then
		self._studioId = self._studioId or ("studio-" .. HttpService:GenerateGUID(false))
		id = self._studioId
	end
	if not validId(id) or (self._worldId and self._worldId ~= id) then return nil end
	self._worldId = id
	self._tuning = self._tuning or assert(readTuning(Config), "Invalid expedition reward tuning")
	return id
end
function Service:_player(userId)
	local key = tostring(userId)
	local data = self._players[key]
	if not data then
		data = { SurvivedSeconds = 0, Milestones = 0, ReviveBucket = 0, RevivesInBucket = 0,
			EarnedCurrency = 0, EarnedXP = 0, TotalsComplete = true, ClassSeconds = {} }
		self._players[key] = data
	end
	return data
end
function Service:GetSummary(playerOrId)
	if typeof(playerOrId) == "Instance" and not playerOrId:IsA("Player") then return nil end
	local id = typeof(playerOrId) == "Instance" and playerOrId.UserId or playerOrId
	if not userId(id) then return nil end
	local data = self:_player(id)
	local pending, currency, xp = 0, 0, 0
	for _, claim in pairs(self._pending) do
		if claim.UserId == id then pending += 1; currency += claim.Currency; xp += claim.XP end
	end
	return { UserId = id, ClassSeconds = Util.DeepCopy(data.ClassSeconds or {}), EarnedCurrency = data.EarnedCurrency, EarnedXP = data.EarnedXP,
		PendingCurrency = currency, PendingXP = xp, PendingClaims = pending,
		SettledCurrency = RunService:IsStudio() and 0 or math.max(0, data.EarnedCurrency - currency),
		SettledXP = RunService:IsStudio() and 0 or math.max(0, data.EarnedXP - xp),
		TotalsComplete = data.TotalsComplete, Preview = RunService:IsStudio() }
end
function Service:GetTeamSummary()
	local result = { CurrencyName = Economy.CurrencyName, Preview = RunService:IsStudio(), RewardsEnabled = rewardsEnabled(), Players = {} }
	for key in pairs(self._players) do table.insert(result.Players, self:GetSummary(tonumber(key))) end
	table.sort(result.Players, function(a, b) return a.UserId < b.UserId end)
	return result
end
function Service:_scheduleSummary()
	if self._summaryScheduled or not self._summaryRemote then return end
	self._summaryScheduled = true
	task.defer(function()
		self._summaryScheduled = false
		self._summaryRemote:FireAllClients("Summary", self:GetTeamSummary())
	end)
end
function Service:_status(player)
	local summary = self:GetSummary(player)
	if player.Parent == Players then
		player:SetAttribute("ExpeditionRewardsPending", summary.PendingClaims)
		player:SetAttribute("RunFieldMarksEarned", summary.EarnedCurrency)
		local role = player:GetAttribute("Role") or "Generalist"
		player:SetAttribute("RunClassSecondsEarned", (summary.ClassSeconds or {})[role] or 0)
		local profile = Profile:GetProfile(player)
		local progress = profile and profile.ClassProgress and profile.ClassProgress[role]
		player:SetAttribute("ClassActiveSeconds", progress and progress.ActiveSeconds or 0)
		player:SetAttribute("RunXPEarned", summary.EarnedXP)
		player:SetAttribute("RunFieldMarksPending", summary.PendingCurrency)
		player:SetAttribute("RunXPPending", summary.PendingXP)
		player:SetAttribute("RunRewardsPreview", summary.Preview)
		player:SetAttribute("RunRewardTotalsComplete", summary.TotalsComplete)
	end
	self:_scheduleSummary()
end
function Service:_queue(player, kind, occurrenceId, reward)
	if not rewardsEnabled() then return false, "CreativeRewardsDisabled" end
	if not ownsLease() then return false, "WorldLeaseLost" end
	local worldId = self:_world()
	if not worldId then return false, "MissingWorldId" end
	local id = "world:" .. worldId .. ":" .. kind .. ":" .. occurrenceId
	local key = tostring(player.UserId) .. ":" .. id
	if not self._pending[key] then
		self._pending[key] = { UserId = player.UserId, Id = id, Currency = reward.Currency, XP = reward.XP }
		local data = self:_player(player.UserId)
		data.EarnedCurrency += reward.Currency
		data.EarnedXP += reward.XP
	end
	self:_status(player)
	return true
end

function Service:_flush(player, forceClass)
	if not rewardsEnabled() then return end
	-- Pending claims were authorized when queued (or in a fenced saved world).
	-- They may settle after lease loss, but not while a replacement ledger is staged.
	if self._flushing[player] or self._pendingRestore then return end
	self._flushing[player] = true
	local processed = 0
	for key, claim in pairs(self._pending) do
		if claim.UserId == player.UserId then
			if player.Parent ~= Players then break end
			local ok, paid, reason
			if RunService:IsStudio() then
				ok, paid, reason = true, true, "StudioPreview"
			elseif Profile:IsLoaded(player) then
				ok, paid, reason = pcall(Profile.GrantReward, Profile, player, claim.Id, { Currency = claim.Currency, XP = claim.XP })
			else break end
			if ok and paid then
				-- A concurrent restore may have replaced this claim table; never clear its replacement.
				if self._pending[key] == claim then self._pending[key] = nil end
			elseif not ok then warn("[ExpeditionRewards] Payment deferred:", paid)
			elseif reason ~= "SavePending" and reason ~= "ProfileUnavailable" then warn("[ExpeditionRewards] Payment pending:", reason) end
			processed += 1
			if processed >= 8 then break end
		end
	end
	local worldId = self:_world()
	if worldId and not RunService:IsStudio() and Profile:IsLoaded(player) then
		local settled = self._classSettled[player] or {}
		self._classSettled[player] = settled
		for role, seconds in pairs(self:_player(player.UserId).ClassSeconds or {}) do
			if seconds > (settled[role] or 0) and (forceClass or os.clock() - (settled.At or -math.huge) >= 60) then
				local ok, paid = pcall(Profile.GrantClassTime, Profile, player, worldId, role, seconds)
				if ok and paid then settled[role], settled.At = seconds, os.clock() end
			end
		end
	end
	self._flushing[player] = nil
	self:_status(player)
end

function Service:_deliverItems(player)
	if self._delivering[player] or not participant(player) or RS:GetAttribute("WorldRestoring") then return end
	self._delivering[player] = true
	local generation = self._generation
	for _, objective in pairs(self._objectives) do
		if self._generation ~= generation then break end
		local receipt = objective.Recipients[tostring(player.UserId)]
		if receipt then
			for index = receipt.InventoryIndex + 1, #objective.Items do
				if self._generation ~= generation or not participant(player) or RS:GetAttribute("WorldRestoring") then break end
				-- Inventory mutates before Sync callbacks; claiming first prevents replay if one yields.
				receipt.InventoryIndex = index
				local item = objective.Items[index]
				local ok, err = pcall(Inventory.Give, Inventory, player, item.Id, item.N)
				if not ok then warn("[ExpeditionRewards] Objective item delivery failed:", err) end
			end
		end
	end
	self._delivering[player] = nil
end

-- Server-side successful gameplay hooks call this; client input is never trusted.
function Service:RecordActivity(player)
	if activeWorld() and alive(player) then
		local entry = self._activity[player] or {}
		entry.LastAction = os.clock()
		self._activity[player] = entry
	end
end
function Service:_sample(player)
	local stamp = os.clock()
	local eligible = activeWorld() and alive(player) and self:_world() ~= nil
	local sample = self._samples[player]
	local activity = self._activity[player] or { LastAction = stamp }
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local delta = activity.Position and (root.Position - activity.Position)
		local distance = delta and Vector3.new(delta.X, 0, delta.Z).Magnitude or 0
		if distance >= 0.75 and distance < 120 then
			activity.LastAction = stamp
		end
		activity.Position = root.Position
	end
	self._activity[player] = activity
	local classEligible = rewardsEnabled() and eligible and stamp - (activity.LastAction or stamp) <= 120
	if sample and sample.Eligible and eligible then
		local data = self:_player(player.UserId)
		data.SurvivedSeconds += math.max(0, stamp - sample.At)
		local due = math.floor(data.SurvivedSeconds / self._tuning.SurvivalSeconds)
		while data.Milestones < due do
			data.Milestones += 1
			self:_queue(player, "survival", tostring(data.Milestones), self._tuning.Survival)
		end
	end
	if sample and sample.ClassEligible and classEligible then
		local role = player:GetAttribute("Role")
		if Classes.Definitions[role] then
			local data = self:_player(player.UserId)
			data.ClassSeconds = data.ClassSeconds or {}
			data.ClassSeconds[role] = (data.ClassSeconds[role] or 0) + math.max(0, stamp - sample.At)
			player:SetAttribute("RunClassSecondsEarned", data.ClassSeconds[role])
		end
	end
	self._samples[player] = { At = stamp, Eligible = eligible, ClassEligible = classEligible }
end

function Service:OnObjective(id, entry, items)
	if not activeWorld() or not self:_world() or type(entry) ~= "table" or entry.State ~= "Completed" or not validId(entry.InstanceId) then return false end
	if self._objectives[entry.InstanceId] then return false, "AlreadyClaimed" end
	if count(self._objectives) >= Config.MaxClaims then return false, "RewardLedgerFull" end
	local objective = { Id = id, Items = Util.DeepCopy(items or {}), Recipients = {} }
	self._objectives[entry.InstanceId] = objective
	for _, player in ipairs(Players:GetPlayers()) do
		if participant(player) then
			self:RecordActivity(player)
			objective.Recipients[tostring(player.UserId)] = { InventoryIndex = 0 }
			self:_queue(player, "objective", entry.InstanceId, self._tuning.Objective)
			task.defer(function() self:_deliverItems(player); self:_flush(player) end)
		end
	end
	return true
end

function Service:OnRevive(helper, target, deathId)
	if not activeWorld() or not self:_world() or not validId(deathId) or helper == target
		or typeof(helper) ~= "Instance" or not helper:IsA("Player") or typeof(target) ~= "Instance" or not target:IsA("Player")
		or not participant(helper) or not participant(target) then return false, "InvalidRevive" end
	if self._deaths[deathId] then return false, "AlreadyClaimed" end
	if count(self._deaths) >= Config.MaxClaims then return false, "RewardLedgerFull" end
	-- Even a capped occurrence is settled; it cannot be replayed in a later bucket.
	self._deaths[deathId] = { Helper = helper.UserId, Target = target.UserId }
	local data = self:_player(helper.UserId)
	local bucket = math.floor(Round:GetElapsed() / self._tuning.SurvivalSeconds)
	if data.ReviveBucket ~= bucket then data.ReviveBucket, data.RevivesInBucket = bucket, 0 end
	if data.RevivesInBucket >= self._tuning.RevivesPerMilestone then return false, "ReviveRewardLimit" end
	self:RecordActivity(helper)
	data.RevivesInBucket += 1
	self:_queue(helper, "revive", deathId, self._tuning.Revive)
	task.defer(function() self:_flush(helper) end)
	return true
end

function Service:CaptureState()
	if self._pendingRestore then return Util.DeepCopy(self._pendingRestore) end
	assert(self:_world(), "Stable WorldId required before capturing rewards")
	for _, player in ipairs(Players:GetPlayers()) do self:_sample(player) end
	return { SchemaVersion = 3, WorldId = self._worldId, Tuning = Util.DeepCopy(self._tuning), Players = Util.DeepCopy(self._players),
		Objectives = Util.DeepCopy(self._objectives), Deaths = Util.DeepCopy(self._deaths), Pending = Util.DeepCopy(self._pending) }
end

function Service:RestoreState(state)
	if type(state) ~= "table" or (state.SchemaVersion ~= 1 and state.SchemaVersion ~= 2 and state.SchemaVersion ~= 3) or not validId(state.WorldId)
		or type(state.Players) ~= "table" or type(state.Objectives) ~= "table" or type(state.Deaths) ~= "table" or type(state.Pending) ~= "table"
		or count(state.Players) > 100 or count(state.Objectives) > Config.MaxClaims or count(state.Deaths) > Config.MaxClaims or count(state.Pending) > Config.MaxClaims then return false, "InvalidRewardSnapshot" end
	local currentWorld = RS:GetAttribute("WorldId")
	if validId(currentWorld) and currentWorld ~= state.WorldId then return false, "RewardWorldMismatch" end
	local tuning = readTuning(state.Tuning or (state.SchemaVersion == 1 and LEGACY_TUNING))
	if not tuning then return false, "InvalidRewardTuning" end
	local restored = { SchemaVersion = 3, WorldId = state.WorldId, Tuning = tuning, Players = {}, Objectives = {}, Deaths = {}, Pending = {} }
	for key, data in pairs(state.Players) do
		if not userKey(key) or type(data) ~= "table" or not number(data.SurvivedSeconds) or not integer(data.Milestones)
			or data.Milestones ~= math.floor(data.SurvivedSeconds / tuning.SurvivalSeconds) or not integer(data.ReviveBucket)
			or not integer(data.RevivesInBucket, tuning.RevivesPerMilestone) then return false, "InvalidRewardSnapshot" end
		if state.SchemaVersion >= 2 and (not integer(data.EarnedCurrency, Economy.MaxCurrency) or not integer(data.EarnedXP, Economy.MaxCurrency)
			or type(data.TotalsComplete) ~= "boolean") then return false, "InvalidRewardTotals" end
		restored.Players[key] = { SurvivedSeconds = data.SurvivedSeconds, Milestones = data.Milestones, ReviveBucket = data.ReviveBucket,
			RevivesInBucket = data.RevivesInBucket, EarnedCurrency = data.EarnedCurrency or 0, EarnedXP = data.EarnedXP or 0, TotalsComplete = data.TotalsComplete ~= false, ClassSeconds = {} }
		if data.ClassSeconds ~= nil then
			if type(data.ClassSeconds) ~= "table" then return false, "InvalidClassTime" end
			for role, seconds in pairs(data.ClassSeconds) do
				if not Classes.Definitions[role] or not number(seconds) then return false, "InvalidClassTime" end
				restored.Players[key].ClassSeconds[role] = seconds
			end
		end
	end
	for id, objective in pairs(state.Objectives) do
		if not validId(id) or type(objective) ~= "table" or type(objective.Id) ~= "string" or type(objective.Items) ~= "table" or #objective.Items > 20
			or type(objective.Recipients) ~= "table" or count(objective.Recipients) > 100 then return false, "InvalidRewardSnapshot" end
		local copy = { Id = objective.Id, Items = {}, Recipients = {} }
		for index, item in ipairs(objective.Items) do
			if type(item) ~= "table" or type(item.Id) ~= "string" or not integer(item.N, 1000000) or item.N < 1 then return false, "InvalidRewardSnapshot" end
			copy.Items[index] = { Id = item.Id, N = item.N }
		end
		for key, receipt in pairs(objective.Recipients) do
			if not userKey(key) or type(receipt) ~= "table" or not integer(receipt.InventoryIndex, #copy.Items) then return false, "InvalidRewardSnapshot" end
			copy.Recipients[key] = { InventoryIndex = receipt.InventoryIndex }
		end
		restored.Objectives[id] = copy
	end
	for id, receipt in pairs(state.Deaths) do
		if not validId(id) or type(receipt) ~= "table" or not userId(receipt.Helper) or not userId(receipt.Target) then return false, "InvalidRewardSnapshot" end
		restored.Deaths[id] = { Helper = receipt.Helper, Target = receipt.Target }
	end
	for key, claim in pairs(state.Pending) do
		if type(key) ~= "string" or type(claim) ~= "table" or type(claim.Id) ~= "string" or #claim.Id > 120
			or not userId(claim.UserId) or key ~= tostring(claim.UserId) .. ":" .. claim.Id
			or claim.Id:sub(1, #state.WorldId + 7) ~= "world:" .. state.WorldId .. ":"
			or not integer(claim.Currency, Economy.MaxRewardAmount) or not integer(claim.XP, Economy.MaxRewardAmount) then return false, "InvalidRewardSnapshot" end
		restored.Pending[key] = { UserId = claim.UserId, Id = claim.Id, Currency = claim.Currency, XP = claim.XP }
	end
	if state.SchemaVersion == 1 then
		-- V1 kept objective recipients and survival counts, but only the latest
		-- revive bucket. Reconstruct the known minimum instead of inventing old payouts.
		local function legacyPlayer(key)
			restored.Players[key] = restored.Players[key] or { SurvivedSeconds = 0, Milestones = 0, ReviveBucket = 0,
				RevivesInBucket = 0, EarnedCurrency = 0, EarnedXP = 0, TotalsComplete = true, ClassSeconds = {} }
			return restored.Players[key]
		end
		for _, objective in pairs(restored.Objectives) do for key in pairs(objective.Recipients) do legacyPlayer(key) end end
		for _, claim in pairs(restored.Pending) do legacyPlayer(tostring(claim.UserId)) end
		for _, receipt in pairs(restored.Deaths) do legacyPlayer(tostring(receipt.Helper)) end
		for key, data in pairs(restored.Players) do
			local objectives, deaths, pendingRevives, pendingCurrency, pendingXP = 0, 0, 0, 0, 0
			for _, objective in pairs(restored.Objectives) do if objective.Recipients[key] then objectives += 1 end end
			for _, receipt in pairs(restored.Deaths) do if tostring(receipt.Helper) == key then deaths += 1 end end
			for _, claim in pairs(restored.Pending) do
				if tostring(claim.UserId) == key then
					pendingCurrency += claim.Currency; pendingXP += claim.XP
					if claim.Id:sub(#state.WorldId + 8, #state.WorldId + 14) == "revive:" then pendingRevives += 1 end
				end
			end
			local revives = math.max(data.RevivesInBucket, pendingRevives)
			data.EarnedCurrency = math.max(pendingCurrency, data.Milestones * tuning.Survival.Currency + objectives * tuning.Objective.Currency + revives * tuning.Revive.Currency)
			data.EarnedXP = math.max(pendingXP, data.Milestones * tuning.Survival.XP + objectives * tuning.Objective.XP + revives * tuning.Revive.XP)
			data.TotalsComplete = deaths <= revives
		end
	end
	if count(restored.Players) > 100 then return false, "InvalidRewardSnapshot" end
	local pendingTotals = {}
	for _, claim in pairs(restored.Pending) do
		local key = tostring(claim.UserId)
		if not restored.Players[key] then return false, "InvalidRewardTotals" end
		local total = pendingTotals[key] or { Currency = 0, XP = 0 }
		total.Currency += claim.Currency; total.XP += claim.XP
		pendingTotals[key] = total
	end
	for key, data in pairs(restored.Players) do
		local pending = pendingTotals[key]
		if not integer(data.EarnedCurrency, Economy.MaxCurrency) or not integer(data.EarnedXP, Economy.MaxCurrency)
			or (pending and (pending.Currency > data.EarnedCurrency or pending.XP > data.EarnedXP)) then return false, "InvalidRewardTotals" end
	end
	self._pendingRestore = restored
	if not RS:GetAttribute("WorldRestoring") then return self:CompleteWorldRestore() end
	return true
end

function Service:CompleteWorldRestore()
	local state = self._pendingRestore
	self._generation = (self._generation or 0) + 1
	if state then
		self._worldId, self._players, self._objectives, self._deaths, self._pending = state.WorldId, state.Players, state.Objectives, state.Deaths, state.Pending
		self._tuning = state.Tuning
		self._pendingRestore = nil
	end
	if RunService:IsStudio() and not validId(RS:GetAttribute("WorldId")) then self._studioId = self._worldId end
	self._samples, self._classSettled, self._activity = {}, {}, {}
	for _, player in ipairs(Players:GetPlayers()) do
		self:_sample(player)
		self:_status(player)
		task.defer(function() self:_deliverItems(player); self:_flush(player) end)
	end
	return true
end

function Service:Init()
	if self._started then return end
	self._started = true
	local remotes = RS:WaitForChild("Remotes", 10)
	if remotes then
		local remote = remotes:FindFirstChild("ExpeditionRewards") or Instance.new("RemoteEvent")
		remote.Name, remote.Parent = "ExpeditionRewards", remotes
		self._summaryRemote = remote
		local requested = {}
		remote.OnServerEvent:Connect(function(player, action)
			if action ~= "RequestSummary" or os.clock() - (requested[player] or -math.huge) < 1 then return end
			requested[player] = os.clock()
			remote:FireClient(player, "Summary", self:GetTeamSummary())
		end)
		Players.PlayerRemoving:Connect(function(player) requested[player] = nil end)
	end
	local connections = {}
	local function bind(player)
		if connections[player] then return end
		connections[player] = {}
		local function changed() self:_sample(player) end
		for _, attribute in ipairs({ "IsDead", "WorldPlayerLoading", "WorldPlayerRestoring" }) do
			table.insert(connections[player], player:GetAttributeChangedSignal(attribute):Connect(changed))
		end
		local function character(char)
			changed()
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then table.insert(connections[player], hum.HealthChanged:Connect(changed)) end
		end
		table.insert(connections[player], player.CharacterAdded:Connect(character))
		table.insert(connections[player], player.CharacterRemoving:Connect(function() self._samples[player] = { At = os.clock(), Eligible = false } end))
		if player.Character then character(player.Character) else changed() end
		self:_status(player)
	end
	Players.PlayerAdded:Connect(bind)
	Players.PlayerRemoving:Connect(function(player)
		self:_sample(player)
		for _, connection in ipairs(connections[player] or {}) do connection:Disconnect() end
		task.spawn(function() self:_flush(player) end)
		connections[player], self._samples[player], self._activity[player] = nil, nil, nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do bind(player) end
	RS:GetAttributeChangedSignal("WorldRestoring"):Connect(function()
		for _, player in ipairs(Players:GetPlayers()) do self:_sample(player) end
	end)
	Profile:OnLoaded(function(player) task.defer(function() self:_flush(player) end) end, true)
	Profile:OnDeparture(function(player)
		self:_sample(player)
		while self._flushing[player] do task.wait() end
		self:_flush(player, true)
	end)
	task.spawn(function()
		local retryAt = 0
		while self._started do
			for _, player in ipairs(Players:GetPlayers()) do
				self:_sample(player)
				if os.clock() >= retryAt then task.spawn(function() self:_deliverItems(player); self:_flush(player) end) end
			end
			if os.clock() >= retryAt then retryAt = os.clock() + Config.RetrySeconds end
			task.wait(1)
		end
	end)
end

return Service
