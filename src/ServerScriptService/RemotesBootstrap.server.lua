-- RemotesBootstrap.server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function ensureRemoteEvent(parent, name)
	local remote = parent:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = parent
	end
	return remote
end

local remotesFolder = ensureFolder(ReplicatedStorage, "Remotes")

for _, name in pairs(Config.RemoteNames) do
	ensureRemoteEvent(remotesFolder, name)
end

-- Extra remotes used by resource/harvest scripts
ensureRemoteEvent(remotesFolder, "ResourceInteract")
ensureRemoteEvent(remotesFolder, "ResourceCarry")
ensureRemoteEvent(remotesFolder, "GiveResourceEvent")

-- Extra remotes for UI systems
ensureRemoteEvent(remotesFolder, "InventoryUpdate")
ensureRemoteEvent(remotesFolder, "InventoryAction")
ensureRemoteEvent(remotesFolder, "ProfileUpdate")
ensureRemoteEvent(remotesFolder, "RoleUpdate")
ensureRemoteEvent(remotesFolder, "RoleSelect")
ensureRemoteEvent(remotesFolder, "GameStateUpdate")
ensureRemoteEvent(remotesFolder, "DropItem")
ensureRemoteEvent(remotesFolder, "ChestEvent")
