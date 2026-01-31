-- WorldFoldersBootstrap.server.lua
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local function ensureFolder(path)
	local node = Workspace
	for seg in string.gmatch(path, "[^/]+") do
		local child = node:FindFirstChild(seg)
		if not child then
			child = Instance.new("Folder")
			child.Name = seg
			child.Parent = node
		end
		node = child
	end
	return node
end

ensureFolder("EnemySpawns")
ensureFolder("ResourceNodes")
ensureFolder("Objectives")
ensureFolder("Enemies")
