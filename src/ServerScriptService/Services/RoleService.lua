-- Class selection is persisted before modifiers change, and is limited to the lobby.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.EconomyConfig)
local Classes = require(ReplicatedStorage.Shared.ClassConfig)
local Util = require(ReplicatedStorage.Shared.Util)
local ProfileService = require(script.Parent.ProfileService)

local RoleService = { _initialized = false, _runRoles = {} }

local function inLobby()
	return ReplicatedStorage:GetAttribute("PlaceMode") == "Lobby"
		or (Economy.AllowStudioRoleSelection == true and RunService:IsStudio())
end
local function applyAttributes(plr, roleId, level)
	local def = Classes.Definitions[roleId]
	if not def or plr.Parent ~= Players then return end
	level = math.clamp(math.floor(tonumber(level) or 1), 1, 5)
	local passive = Classes.GetPassives(roleId, level)
	-- Preserve unchanged modifiers; temporarily removing maximum HP would clamp health.
	for name in pairs(plr:GetAttributes()) do
		if name:sub(1, 6) == "Class_" and passive[name:sub(7)] == nil then plr:SetAttribute(name, nil) end
	end
	for name, value in pairs(passive) do plr:SetAttribute("Class_" .. name, value) end
	plr:SetAttribute("ClassLevel", level)
	plr:SetAttribute("Role", roleId)
	plr:SetAttribute("Role_Gather", 1)
	plr:SetAttribute("Role_Build", 1)
	plr:SetAttribute("Role_Combat", 1 + (passive.CombatBonus or 0))
	plr:SetAttribute("Role_Heal", 1 + (passive.HealBonus or 0))
	plr:SetAttribute("Role_Craft", 1 + (passive.CraftBonus or 0))
end

function RoleService:Init()
	if self._initialized then return end
	local remotes = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	if not remotes then return end
	self._initialized = true
	self._remote = Util.GetRemote(remotes, Config.RemoteNames.RoleUpdate)
	self._selectRemote = Util.GetRemote(remotes, Config.RemoteNames.RoleSelect)
	local selections, requests, connected = {}, {}, {}
	ProfileService:OnLoaded(function(plr) self:ApplyFromProfile(plr) end, true)
	ProfileService:OnChanged(function(plr)
		-- Also apply a selection whose write succeeded during a later retry.
		if inLobby() then self:ApplyFromProfile(plr) end
	end)
	if self._selectRemote then
		self._selectRemote.OnServerEvent:Connect(function(plr, roleId)
			if type(roleId) ~= "string" or #roleId > 40 then return end
			local ok, reason
			if os.clock() - (selections[plr] or -math.huge) < 1 then
				ok, reason = false, "RateLimited"
			else
				selections[plr] = os.clock()
				ok, reason = self:SetRole(plr, roleId)
			end
			if plr.Parent == Players then
				self._selectRemote:FireClient(plr, "Result", { Success = ok, Reason = reason, RoleId = roleId })
			end
		end)
	end
	if self._remote then
		self._remote.OnServerEvent:Connect(function(plr, action)
			if action ~= "RequestRole" or os.clock() - (requests[plr] or -math.huge) < 0.5 then return end
			requests[plr] = os.clock()
			self:SendToPlayer(plr)
		end)
	end
	local function bindPlayer(plr)
		if connected[plr] then return end
		connected[plr] = plr.CharacterAdded:Connect(function() self:ApplyFromProfile(plr) end)
		self:ApplyFromProfile(plr)
	end
	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(plr)
		self._runRoles[plr] = nil
		if connected[plr] then connected[plr]:Disconnect() end
		connected[plr], selections[plr], requests[plr] = nil, nil, nil
	end)
	for _, plr in ipairs(Players:GetPlayers()) do bindPlayer(plr) end
end

function RoleService:SendToPlayer(plr)
	if not plr or plr.Parent ~= Players then return nil end
	local roleId = plr:GetAttribute("Role")
	if type(roleId) ~= "string" or not Config.ROLES.Definitions[roleId] then
		local profile = ProfileService:GetProfile(plr)
		roleId = profile and profile.Role or Config.ROLES.Default
	end
	local profile = ProfileService:GetProfile(plr)
	local progress = profile and profile.ClassProgress and profile.ClassProgress[roleId]
	plr:SetAttribute("ClassActiveSeconds", progress and progress.ActiveSeconds or 0)
	plr:SetAttribute("PermanentClassLevel", progress and progress.Level or 1)
	if self._remote then self._remote:FireClient(plr, roleId) end
	return roleId
end

function RoleService:SetRole(plr, roleId)
	if not inLobby() then return false, "LobbyOnly" end
	if type(roleId) ~= "string" or not Config.ROLES.Definitions[roleId] then return false, "InvalidRole" end
	if not ProfileService:IsLoaded(plr) then return false, "ProfileUnavailable" end
	local ok, reason = ProfileService:SetRole(plr, roleId)
	if ok then self:ApplyFromProfile(plr) end
	return ok, reason
end
function RoleService:PurchaseRole(plr, roleId)
	if not inLobby() then return false, "LobbyOnly" end
	return ProfileService:PurchaseRole(plr, roleId)
end
function RoleService:UpgradeClass(plr, roleId, level)
	if not inLobby() then return false, "LobbyOnly" end
	local ok, reason = ProfileService:UpgradeClass(plr, roleId, level)
	if ok then self:ApplyFromProfile(plr) end
	return ok, reason
end
function RoleService:ApplyFromProfile(plr)
	local runRole = self._runRoles[plr]
	if runRole and ReplicatedStorage:GetAttribute("PlaceMode") ~= "Lobby" then
		applyAttributes(plr, runRole.Id, runRole.Level)
		self:SendToPlayer(plr)
		return runRole.Id
	end
	local profile = ProfileService:GetProfile(plr)
	local roleId = profile and profile.Role or Config.ROLES.Default
	if not Config.ROLES.Definitions[roleId] or (profile and not profile.UnlockedRoles[roleId]) then roleId = Config.ROLES.Default end
	applyAttributes(plr, roleId, profile and profile.ClassProgress[roleId].Level or 1)
	self:SendToPlayer(plr)
	return roleId
end

-- Trusted expedition assignment only; this does not change the profile selection.
function RoleService:ApplyRunRole(plr, roleId, level)
	assert(type(roleId) == "string" and Config.ROLES.Definitions[roleId], "Invalid saved run class")
	assert(ReplicatedStorage:GetAttribute("PlaceMode") ~= "Lobby", "Run classes belong to expeditions")
	self._runRoles[plr] = { Id = roleId, Level = level or 1 }
	applyAttributes(plr, roleId, level or 1)
	self:SendToPlayer(plr)
	return true
end

return RoleService
