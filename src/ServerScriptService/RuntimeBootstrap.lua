-- Shared synchronous bootstrap: service order must never depend on Script scheduling.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Bootstrap = {}
function Bootstrap:Init()
	if self._ready then return end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then remotes = Instance.new("Folder"); remotes.Name = "Remotes"; remotes.Parent = ReplicatedStorage end
	for _, name in pairs(Config.RemoteNames) do
		if not remotes:FindFirstChild(name) then
			local event = Instance.new("RemoteEvent"); event.Name = name; event.Parent = remotes
		end
	end
	for _, name in ipairs({"EnemySpawns", "ResourceNodes", "Objectives", "Enemies"}) do
		if not workspace:FindFirstChild(name) then
			local f = Instance.new("Folder"); f.Name = name; f.Parent = workspace
		end
	end
	self._ready = true
end
return Bootstrap
