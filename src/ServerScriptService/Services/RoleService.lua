-- Class selection is persisted before modifiers change, and is limited to the lobby.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.EconomyConfig)
local Util = require(ReplicatedStorage.Shared.Util)
local ProfileService = require(script.Parent.ProfileService)

local RoleService = { _initialized = false, _runRoles = {} }

local function inLobby()
	return ReplicatedStorage:GetAttribute("PlaceMode") == "Lobby"
		or (Economy.AllowStudioRoleSelection == true and RunService:IsStudio())
end
local function applyAttributes(plr, roleId)
	local def = Config.ROLES.Definitions[roleId]
	if not def or plr.Parent ~= Players then return end
	plr:SetAttribute("Role", roleId)
	plr:SetAttribute("Role_Gather", def.Gather or 1)
	plr:SetAttribute("Role_Build", def.Build or 1)
	plr:SetAttribute("Role_Combat", def.Combat or 1)
	plr:SetAttribute("Role_Heal", def.Heal or 1)
	plr:SetAttribute("Role_Craft", def.Craft or 1)
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
function RoleService:ApplyFromProfile(plr)
	local runRole = self._runRoles[plr]
	if runRole and ReplicatedStorage:GetAttribute("PlaceMode") ~= "Lobby" then
		applyAttributes(plr, runRole)
		self:SendToPlayer(plr)
		return runRole
	end
	local profile = ProfileService:GetProfile(plr)
	local roleId = profile and profile.Role or Config.ROLES.Default
	if not Config.ROLES.Definitions[roleId] or (profile and not profile.UnlockedRoles[roleId]) then roleId = Config.ROLES.Default end
	applyAttributes(plr, roleId)
	self:SendToPlayer(plr)
	return roleId
end

-- Trusted expedition assignment only; this does not change the profile selection.
function RoleService:ApplyRunRole(plr, roleId)
	assert(type(roleId) == "string" and Config.ROLES.Definitions[roleId], "Invalid saved run class")
	assert(ReplicatedStorage:GetAttribute("PlaceMode") ~= "Lobby", "Run classes belong to expeditions")
	self._runRoles[plr] = roleId
	applyAttributes(plr, roleId)
	self:SendToPlayer(plr)
	return true
end

return RoleService
