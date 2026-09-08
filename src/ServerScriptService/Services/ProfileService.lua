-- Write-through operations against fresh DataStore state; never merge stale balances.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.EconomyConfig)
local Util = require(ReplicatedStorage.Shared.Util)
local SettingsConfig = require(ReplicatedStorage.Shared.SettingsConfig)

local ProfileService = {
	_profiles = {}, _sessions = {}, _loadCallbacks = {}, _changeCallbacks = {},
	_store = DataStoreService:GetDataStore(Config.DATASTORE.ProfileStore),
}

local function integer(value, fallback, maximum)
	local n = tonumber(value)
	if not n or n ~= n or math.abs(n) == math.huge then return fallback end
	return math.clamp(math.floor(n), 0, maximum or Economy.MaxCurrency)
end
local function validAmount(value)
	return type(value) == "number" and value % 1 == 0 and value >= 0 and value <= Economy.MaxRewardAmount
end
local function validId(value)
	return type(value) == "string" and #value > 0 and #value <= 120
end
local function asSet(values)
	local result = {}
	if type(values) ~= "table" then return result end
	for key, value in pairs(values) do
		if type(key) == "number" and type(value) == "string" then result[value] = true
		elseif type(key) == "string" and value == true then result[key] = true end
	end
	return result
end
local function asArray(values)
	local result = {}
	for key, value in pairs(values) do if value then table.insert(result, key) end end
	table.sort(result)
	return result
end
local function levelForXP(xp)
	-- Retain the existing cumulative curve: level 2 at 175 XP, then 75/level.
	return math.max(1, math.floor((xp - 100) / 75) + 1)
end
local function decode(raw)
	if raw ~= nil and type(raw) ~= "table" then return nil, "InvalidStoredProfile" end
	if raw and (tonumber(raw.SchemaVersion) or 0) > Economy.SchemaVersion then return nil, "UnsupportedProfileVersion" end
	-- Missing fields migrate, but damaged money/receipt fields never become defaults.
	if raw and raw.Currency ~= nil and (type(raw.Currency) ~= "number" or raw.Currency % 1 ~= 0 or raw.Currency < 0 or raw.Currency > Economy.MaxCurrency) then
		return nil, "InvalidStoredBalance"
	end
	if raw and raw.RewardReceipts ~= nil and type(raw.RewardReceipts) ~= "table" then return nil, "InvalidRewardLedger" end
	local data = raw and Util.DeepCopy(raw) or {}
	data.SchemaVersion = Economy.SchemaVersion
	data.XP = integer(data.XP, 0)
	data.Level = math.max(1, integer(data.Level, 1), levelForXP(data.XP))
	data.Currency = integer(data.Currency, 0)
	-- Legacy arrays and sets are both preserved. Never unlock every definition.
	for _, field in ipairs({ "UnlockedRoles", "Perks", "Cosmetics", "Blueprints" }) do data[field] = asSet(data[field]) end
	data.UnlockedRoles[Config.ROLES.Default] = true
	if type(data.Role) ~= "string" or not Config.ROLES.Definitions[data.Role] or not data.UnlockedRoles[data.Role] then data.Role = Config.ROLES.Default end
	data.Preferences = type(data.Preferences) == "table" and data.Preferences or {}
	if data.Preferences.UITheme ~= "Light" and data.Preferences.UITheme ~= "Dark" then data.Preferences.UITheme = Economy.DefaultTheme end
	data.Preferences = SettingsConfig.Normalize(data.Preferences)
	data.RewardReceipts = type(data.RewardReceipts) == "table" and data.RewardReceipts or {}
	data.Revision = integer(data.Revision, 0)
	return data
end
local function encode(data)
	local result = Util.DeepCopy(data)
	for _, field in ipairs({ "UnlockedRoles", "Perks", "Cosmetics", "Blueprints" }) do result[field] = asArray(data[field]) end
	return result
end
local function publicProfile(data)
	return {
		XP = data.XP, Level = data.Level, Role = data.Role, Currency = data.Currency,
		CurrencyName = Economy.CurrencyName, UnlockedRoles = Util.DeepCopy(data.UnlockedRoles),
		Perks = Util.DeepCopy(data.Perks), Cosmetics = Util.DeepCopy(data.Cosmetics), Blueprints = Util.DeepCopy(data.Blueprints),
		Preferences = Util.DeepCopy(data.Preferences), UITheme = data.Preferences.UITheme,
	}
end
local function newOperation(kind, fields)
	local op = fields or {}
	op.Kind, op.Id = kind, HttpService:GenerateGUID(false)
	op.UpdatedAt = DateTime.now().UnixTimestampMillis
	return op
end

function ProfileService:_status(plr)
	local session = self._sessions[plr]
	if not session or session.Loading then return "Loading" end
	if not session.Loaded then return "Unavailable" end
	return #session.Pending > 0 and "PendingSave" or "Ready"
end
function ProfileService:_accept(plr, data)
	self._profiles[plr] = publicProfile(data)
	if plr.Parent == Players then
		plr:SetAttribute("UITheme", data.Preferences.UITheme)
		plr:SetAttribute("PersonalSettings", HttpService:JSONEncode(data.Preferences))
		plr:SetAttribute("FieldMarks", data.Currency)
	end
	for _, callback in ipairs(self._changeCallbacks) do
		task.defer(function() if self:IsLoaded(plr) then pcall(callback, plr, self._profiles[plr]) end end)
	end
end
function ProfileService:GetProfile(plr)
	return self._profiles[plr]
end
function ProfileService:IsLoaded(plr)
	local session = self._sessions[plr]
	return session ~= nil and session.Loaded == true
end
function ProfileService:OnLoaded(callback, replayExisting)
	if type(callback) ~= "function" then return end
	table.insert(self._loadCallbacks, callback)
	if replayExisting then
		for plr, profile in pairs(self._profiles) do
			task.defer(function() if self:IsLoaded(plr) then pcall(callback, plr, profile) end end)
		end
	end
end
function ProfileService:OnChanged(callback)
	if type(callback) == "function" then table.insert(self._changeCallbacks, callback) end
end
function ProfileService:Send(plr)
	if not self._remote or plr.Parent ~= Players then return end
	local status = self:_status(plr)
	local profile = Util.DeepCopy(self._profiles[plr] or publicProfile(decode(nil)))
	profile.Loaded, profile.PersistenceStatus = self:IsLoaded(plr), status
	plr:SetAttribute("ProfileLoaded", profile.Loaded)
	plr:SetAttribute("ProfileStatus", status)
	self._remote:FireClient(plr, profile)
end

function ProfileService:Load(plr)
	local session = self._sessions[plr]
	if session and session.Loading then
		while session.Loading and plr.Parent == Players do task.wait(0.05) end
		return self._profiles[plr]
	end
	if session and session.Loaded then return self._profiles[plr] end
	session = { Loading = true, Loaded = false, Pending = {}, ById = {} }
	self._sessions[plr] = session
	plr:SetAttribute("UITheme", Economy.DefaultTheme)
	plr:SetAttribute("ProfileLoaded", false)
	plr:SetAttribute("ProfileStatus", "Loading")
	local ok, raw
	for attempt = 1, Economy.DataStoreAttempts do
		ok, raw = pcall(function() return self._store:GetAsync(tostring(plr.UserId)) end)
		if ok then break end
		if attempt < Economy.DataStoreAttempts then task.wait(attempt) end
	end
	session.Loading = false
	if plr.Parent ~= Players then self._sessions[plr] = nil return nil end
	local data, reason
	if ok then data, reason = decode(raw) end
	if not data then
		self._profiles[plr] = nil
		warn("[ProfileService] Profile unavailable for " .. plr.UserId .. ": " .. tostring(reason or raw))
		self:Send(plr)
		return nil, "ProfileUnavailable"
	end
	session.Loaded = true
	self:_accept(plr, data)
	self:Send(plr)
	for _, callback in ipairs(self._loadCallbacks) do pcall(callback, plr, self._profiles[plr]) end
	return self._profiles[plr]
end

-- This reducer runs only inside UpdateAsync and never yields or calls game APIs.
local function reduce(data, op)
	if op.Kind == "Reward" then
		local fingerprint = tostring(op.Currency) .. ":" .. tostring(op.XP)
		local receipt = data.RewardReceipts[op.RewardId]
		if receipt ~= nil then
			return receipt == fingerprint, receipt == fingerprint and "AlreadyApplied" or "RewardIdConflict", false
		end
		local count = 0
		for _ in pairs(data.RewardReceipts) do count += 1 end
		if count >= Economy.MaxRewardReceipts then return false, "RewardLedgerFull", false end
		if data.Currency + op.Currency > Economy.MaxCurrency or data.XP + op.XP > Economy.MaxCurrency then return false, "BalanceLimit", false end
		data.Currency += op.Currency
		data.XP += op.XP
		data.Level = math.max(data.Level, levelForXP(data.XP))
		data.RewardReceipts[op.RewardId] = fingerprint
	elseif op.Kind == "PurchaseRole" then
		if data.UnlockedRoles[op.Role] then return true, "AlreadyOwned", false end
		if data.Currency < op.Price then return false, "InsufficientCurrency", false end
		data.Currency -= op.Price
		data.UnlockedRoles[op.Role] = true
	elseif op.Kind == "UnlockRole" then
		if data.UnlockedRoles[op.Role] then return true, "AlreadyOwned", false end
		data.UnlockedRoles[op.Role] = true
	elseif op.Kind == "SetRole" then
		if not data.UnlockedRoles[op.Role] then return false, "RoleLocked", false end
		if (tonumber(data.RoleUpdatedAt) or 0) > op.UpdatedAt then return true, "Superseded", false end
		data.Role, data.RoleUpdatedAt = op.Role, op.UpdatedAt
	elseif op.Kind == "SetSettings" then
		data.PreferenceUpdatedAt = type(data.PreferenceUpdatedAt) == "table" and data.PreferenceUpdatedAt or {}
		local effective = {}
		for key, value in pairs(op.Patch) do
			if (tonumber(data.PreferenceUpdatedAt[key]) or 0) <= op.UpdatedAt then
				effective[key] = value
			end
		end
		if not next(effective) then return true, "Superseded", false end
		if not SettingsConfig.ValidatePatch(effective, data.Preferences) then return false, "InvalidSettings", false end
		for key, value in pairs(effective) do data.Preferences[key], data.PreferenceUpdatedAt[key] = value, op.UpdatedAt end
	elseif op.Kind == "SetTheme" then
		if (tonumber(data.ThemeUpdatedAt) or 0) > op.UpdatedAt then return true, "Superseded", false end
		data.Preferences.UITheme, data.ThemeUpdatedAt = op.Theme, op.UpdatedAt
	else return false, "UnknownOperation", false end
	data.Revision += 1
	return true, "Saved", true
end

function ProfileService:_execute(plr, op)
	for attempt = 1, Economy.DataStoreAttempts do
		local observed, outcome, reason
		local ok, result = pcall(function()
			return self._store:UpdateAsync(tostring(plr.UserId), function(raw)
				observed, outcome, reason = nil, nil, nil
				local data, decodeReason = decode(raw)
				if not data then outcome, reason = false, decodeReason return nil end
				outcome, reason = reduce(data, op)
				observed = data
				if not outcome then return nil end
				return encode(data)
			end)
		end)
		if ok then
			-- A cancelled reduction can still refresh our view from its latest input.
			local committed = result ~= nil and decode(result) or observed
			if committed then self:_accept(plr, committed) end
			return true, outcome == true, reason or "UpdateCancelled"
		end
		if attempt < Economy.DataStoreAttempts then task.wait(attempt) end
		if attempt == Economy.DataStoreAttempts then warn("[ProfileService] Operation pending for " .. plr.UserId .. ": " .. tostring(result)) end
	end
	return false, false, "SavePending"
end

function ProfileService:Save(plr)
	local session = self._sessions[plr]
	if not session or not session.Loaded then return false, "ProfileUnavailable" end
	while session.Flushing do task.wait(0.05) end
	session.Flushing = true
	local allSaved = true
	local ok, err = pcall(function()
		while #session.Pending > 0 do
			local op = session.Pending[1]
			local completed, success, reason = self:_execute(plr, op)
			if not completed then allSaved = false break end
			op.Done, op.Success, op.Reason = true, success, reason
			table.remove(session.Pending, 1)
			session.ById[op.Id] = nil
		end
	end)
	session.Flushing = false
	if not ok then allSaved = false warn("[ProfileService] Flush pending: " .. tostring(err)) end
	self:Send(plr)
	if allSaved and session.Leaving and self._sessions[plr] == session then
		self._profiles[plr], self._sessions[plr] = nil, nil
	end
	return allSaved, allSaved and "Saved" or "SavePending"
end
function ProfileService:_submit(plr, op)
	local session = self._sessions[plr]
	if not session or not session.Loaded then return false, "ProfileUnavailable" end
	local queued = session.ById[op.Id]
	if queued and (queued.Currency ~= op.Currency or queued.XP ~= op.XP) then return false, "RewardIdConflict" end
	if not queued then
		if #session.Pending >= Economy.MaxPendingOperations then return false, "PendingQueueFull" end
		table.insert(session.Pending, op)
		session.ById[op.Id] = op
	else op = queued end
	self:Send(plr)
	self:Save(plr)
	return op.Done and op.Success or false, op.Reason or "SavePending"
end

function ProfileService:GrantReward(plr, rewardId, reward)
	if not validId(rewardId) or type(reward) ~= "table" then return false, "InvalidReward" end
	local currency, xp = reward.Currency or 0, reward.XP or 0
	if not validAmount(currency) or not validAmount(xp) or currency + xp == 0 then return false, "InvalidReward" end
	return self:_submit(plr, { Id = "reward:" .. rewardId, Kind = "Reward", RewardId = rewardId, Currency = currency, XP = xp })
end
function ProfileService:AddCurrency(plr, amount, rewardId)
	return self:GrantReward(plr, rewardId, { Currency = amount })
end
function ProfileService:AddXP(plr, amount, rewardId)
	amount = tonumber(amount)
	if not amount or amount ~= amount or math.abs(amount) == math.huge then return false, "InvalidReward" end
	return self:GrantReward(plr, rewardId or ("xp:" .. HttpService:GenerateGUID(false)), { XP = math.floor(amount) })
end
function ProfileService:SetRole(plr, roleId)
	if type(roleId) ~= "string" or not Config.ROLES.Definitions[roleId] then return false, "InvalidRole" end
	return self:_submit(plr, newOperation("SetRole", { Role = roleId }))
end
function ProfileService:UnlockRole(plr, roleId)
	if type(roleId) ~= "string" or not Config.ROLES.Definitions[roleId] then return false, "InvalidRole" end
	return self:_submit(plr, newOperation("UnlockRole", { Role = roleId }))
end
function ProfileService:PurchaseRole(plr, roleId)
	if type(roleId) ~= "string" or not Config.ROLES.Definitions[roleId] then return false, "InvalidRole" end
	if not self:IsLoaded(plr) then return false, "ProfileUnavailable" end
	local price = Economy.ClassPrices[roleId]
	if roleId == Config.ROLES.Default then return true, "AlreadyOwned" end
	if not validAmount(price) or price <= 0 then return false, "RoleNotForSale" end
	return self:_submit(plr, newOperation("PurchaseRole", { Role = roleId, Price = price }))
end
function ProfileService:SetUITheme(plr, theme)
	if theme ~= "Dark" and theme ~= "Light" then return false, "InvalidTheme" end
	return self:_submit(plr, newOperation("SetTheme", { Theme = theme }))
end

function ProfileService:Init()
	if self._initialized then return end
	self._initialized = true
	local remotes = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	if not remotes then self._initialized = false return end
	local function ensureRemote(name)
		local remote = remotes:FindFirstChild(name) or Instance.new("RemoteEvent")
		remote.Name, remote.Parent = name, remotes
		return remote
	end
	self._remote = ensureRemote(Config.RemoteNames.ProfileUpdate)
	self._preferenceRemote = ensureRemote("ProfilePreference")
	local requests, preferences = {}, {}
	self._remote.OnServerEvent:Connect(function(plr, action)
		if action ~= "RequestProfile" or os.clock() - (requests[plr] or -math.huge) < 0.5 then return end
		requests[plr] = os.clock()
		self:Send(plr)
	end)
	self._preferenceRemote.OnServerEvent:Connect(function(plr, action, theme, requestId)
		if action == "SetSettings" then
			if type(requestId) ~= "number" or requestId % 1 ~= 0 or requestId < 1 or requestId > 1e9 then return end
			local profile = self:GetProfile(plr)
			local ok, reason = false, "InvalidSettings"
			if not profile or not self:IsLoaded(plr) then reason = "ProfileUnavailable"
			elseif os.clock() - (preferences[plr] or -math.huge) < 0.75 then reason = "RateLimited"
			elseif SettingsConfig.ValidatePatch(theme, profile.Preferences) then
				preferences[plr] = os.clock()
				ok, reason = self:_submit(plr, newOperation("SetSettings", { Patch = Util.DeepCopy(theme) }))
			end
			if plr.Parent == Players then
				local updated = self:GetProfile(plr)
				self._preferenceRemote:FireClient(plr, "Result", { Success = ok, Reason = reason, RequestId = requestId, Preferences = updated and updated.Preferences })
			end
			return
		end
		if action ~= "SetTheme" or (theme ~= "Dark" and theme ~= "Light") then return end
		local ok, reason
		if os.clock() - (preferences[plr] or -math.huge) < 0.75 then
			ok, reason = false, "RateLimited"
		else
			preferences[plr] = os.clock()
			ok, reason = self:SetUITheme(plr, theme)
		end
		if plr.Parent == Players then
			self._preferenceRemote:FireClient(plr, "Result", { Success = ok, Reason = reason, RequestedTheme = theme, UITheme = plr:GetAttribute("UITheme") })
		end
	end)
	Players.PlayerAdded:Connect(function(plr) task.spawn(function() self:Load(plr) end) end)
	for _, plr in ipairs(Players:GetPlayers()) do task.spawn(function() self:Load(plr) end) end
	Players.PlayerRemoving:Connect(function(plr)
		local session = self._sessions[plr]
		if session then session.Leaving = true end
		self:Save(plr)
		-- Keep failed writes retryable after departure for this server's lifetime.
		if not session or not session.Loaded then self._profiles[plr], self._sessions[plr] = nil, nil end
		requests[plr], preferences[plr] = nil, nil
	end)
	game:BindToClose(function()
		local pending = 0
		for plr in pairs(self._sessions) do
			pending += 1
			task.spawn(function() pcall(function() self:Save(plr) end) pending -= 1 end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do task.wait(0.1) end
	end)
	task.spawn(function()
		while self._initialized do
			task.wait(Config.DATASTORE.AutosaveInterval or 60)
			for plr, session in pairs(self._sessions) do
				if session.Loaded and not session.Flushing and #session.Pending > 0 then task.spawn(function() self:Save(plr) end) end
			end
		end
	end)
end

return ProfileService
