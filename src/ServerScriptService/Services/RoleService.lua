-- RoleService.lua
-- Applies role modifiers to players and syncs to clients.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local ProfileService = require(script.Parent.ProfileService)

local RoleService = {}
RoleService._remote = nil
RoleService._selectRemoteConn = nil
RoleService._initialized = false
RoleService._profileLoadedHooked = false

local function applyAttributes(plr, roleId)
	local def = Config.ROLES.Definitions[roleId]
	if not def then return end
	plr:SetAttribute("Role", roleId)
	plr:SetAttribute("Role_Gather", def.Gather or 1)
	plr:SetAttribute("Role_Build", def.Build or 1)
	plr:SetAttribute("Role_Combat", def.Combat or 1)
	plr:SetAttribute("Role_Heal", def.Heal or 1)
	plr:SetAttribute("Role_Craft", def.Craft or 1)
end

function RoleService:Init()
	if self._initialized then return end
	self._initialized = true
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	self._remote = Util.GetRemote(remotesFolder, Config.RemoteNames.RoleUpdate)
	self._selectRemote = Util.GetRemote(remotesFolder, Config.RemoteNames.RoleSelect)
	if not self._profileLoadedHooked then
		self._profileLoadedHooked = true
		ProfileService:OnLoaded(function(plr)
			self:ApplyFromProfile(plr)
		end, true)
	end
	if self._selectRemote then
		self._selectRemoteConn = self._selectRemote.OnServerEvent:Connect(function(plr, roleId)
			local profile = ProfileService:GetProfile(plr)
			if not profile then return end
			if profile.UnlockedRoles and profile.UnlockedRoles[roleId] then
				self:SetRole(plr, roleId)
			end
		end)
	end
end

function RoleService:SetRole(plr, roleId)
	if not Config.ROLES.Definitions[roleId] then return false end
	ProfileService:SetRole(plr, roleId)
	applyAttributes(plr, roleId)
	if self._remote then
		self._remote:FireClient(plr, roleId)
	end
	return true
end

function RoleService:ApplyFromProfile(plr)
	local profile = ProfileService:GetProfile(plr)
	local tries = 0
	while not profile and tries < 10 do
		tries += 1
		task.wait(0.1)
		profile = ProfileService:GetProfile(plr)
	end
	local roleId = profile and profile.Role or Config.ROLES.Default
	applyAttributes(plr, roleId)
	if self._remote then
		self._remote:FireClient(plr, roleId)
	end
end

Players.PlayerAdded:Connect(function(plr)
	RoleService:ApplyFromProfile(plr)
	plr.CharacterAdded:Connect(function()
		RoleService:ApplyFromProfile(plr)
	end)
end)

return RoleService
