-- ProfileService.lua
-- Persistent meta progression using DataStore.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local ProfileService = {}
ProfileService._profiles = {}
ProfileService._store = DataStoreService:GetDataStore(Config.DATASTORE.ProfileStore)
ProfileService._remote = nil

local function defaultProfile()
	local unlocked = {}
	for roleId in pairs(Config.ROLES.Definitions or {}) do
		unlocked[roleId] = true
	end
	return {
		XP = 0,
		Level = 1,
		Role = Config.ROLES.Default,
		UnlockedRoles = unlocked,
		Perks = {},
		Cosmetics = {},
		Blueprints = {},
	}
end

local function toArray(setTable)
	local out = {}
	for k, v in pairs(setTable or {}) do
		if v then
			out[#out + 1] = k
		end
	end
	return out
end

local function fromArray(list)
	local out = {}
	for _, v in ipairs(list or {}) do
		out[v] = true
	end
	return out
end

local function sanitize(data)
	if type(data) ~= "table" then
		return defaultProfile()
	end
	data.XP = tonumber(data.XP) or 0
	data.Level = tonumber(data.Level) or 1
	data.Role = data.Role or Config.ROLES.Default
	data.UnlockedRoles = fromArray(data.UnlockedRoles)
	for roleId in pairs(Config.ROLES.Definitions or {}) do
		if data.UnlockedRoles[roleId] == nil then
			data.UnlockedRoles[roleId] = true
		end
	end
	data.Perks = fromArray(data.Perks)
	data.Cosmetics = fromArray(data.Cosmetics)
	data.Blueprints = fromArray(data.Blueprints)
	if not data.UnlockedRoles[data.Role] then
		data.UnlockedRoles[data.Role] = true
	end
	return data
end

local function toSaveData(profile)
	return {
		XP = profile.XP,
		Level = profile.Level,
		Role = profile.Role,
		UnlockedRoles = toArray(profile.UnlockedRoles),
		Perks = toArray(profile.Perks),
		Cosmetics = toArray(profile.Cosmetics),
		Blueprints = toArray(profile.Blueprints),
	}
end

function ProfileService:Init()
	if self._remote then return end
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	self._remote = Util.GetRemote(remotesFolder, Config.RemoteNames.ProfileUpdate)
end

function ProfileService:GetProfile(plr)
	return self._profiles[plr]
end

function ProfileService:Send(plr)
	self:Init()
	local profile = self._profiles[plr]
	if not profile or not self._remote then return end
	self._remote:FireClient(plr, profile)
end

function ProfileService:Load(plr)
	local key = tostring(plr.UserId)
	local data
	local ok, err = pcall(function()
		data = self._store:GetAsync(key)
	end)
	if not ok then
		warn("[ProfileService] Load failed:", err)
		data = nil
	end
	local profile = sanitize(data)
	self._profiles[plr] = profile
	self:Send(plr)
	return profile
end

function ProfileService:Save(plr)
	local profile = self._profiles[plr]
	if not profile then return end
	local key = tostring(plr.UserId)
	local payload = toSaveData(profile)
	local ok, err = pcall(function()
		self._store:SetAsync(key, payload)
	end)
	if not ok then
		warn("[ProfileService] Save failed:", err)
	end
end

function ProfileService:AddXP(plr, amount)
	local profile = self._profiles[plr]
	if not profile then return end
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return end
	profile.XP += amount
	-- simple leveling curve
	local function xpForLevel(level)
		return 100 + (level - 1) * 75
	end
	while profile.XP >= xpForLevel(profile.Level + 1) do
		profile.Level += 1
	end
	self:Send(plr)
end

function ProfileService:SetRole(plr, roleId)
	local profile = self._profiles[plr]
	if not profile then return false end
	if not Config.ROLES.Definitions[roleId] then return false end
	profile.Role = roleId
	profile.UnlockedRoles[roleId] = true
	self:Send(plr)
	return true
end

function ProfileService:UnlockRole(plr, roleId)
	local profile = self._profiles[plr]
	if not profile then return end
	if Config.ROLES.Definitions[roleId] then
		profile.UnlockedRoles[roleId] = true
		self:Send(plr)
	end
end

local function autosaveLoop()
	while true do
		task.wait(Config.DATASTORE.AutosaveInterval or 60)
		for _, plr in ipairs(Players:GetPlayers()) do
			local ok = pcall(function() ProfileService:Save(plr) end)
			if not ok then end
		end
	end
end

Players.PlayerAdded:Connect(function(plr)
	ProfileService:Load(plr)
end)

Players.PlayerRemoving:Connect(function(plr)
	ProfileService:Save(plr)
	ProfileService._profiles[plr] = nil
end)

game:BindToClose(function()
	for _, plr in ipairs(Players:GetPlayers()) do
		pcall(function() ProfileService:Save(plr) end)
	end
end)

task.spawn(autosaveLoop)

return ProfileService
