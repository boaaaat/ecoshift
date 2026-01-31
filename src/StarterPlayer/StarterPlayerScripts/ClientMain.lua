-- ClientMain.client.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
local rBiome = Util.GetRemote(remotesFolder, Config.RemoteNames.BiomeChanged)
local rEvent = Util.GetRemote(remotesFolder, Config.RemoteNames.EventBroadcast)
local rObjective = Util.GetRemote(remotesFolder, Config.RemoteNames.ObjectiveUpdate)
local rPing = Util.GetRemote(remotesFolder, Config.RemoteNames.Ping)

-- SAFE HOOKS: we don't create UI; we just call hooks if present
local Hooks = {
	OnBiomeChanged = nil,     -- function(biomeName, biomeData) end
	OnEvent = nil,            -- function(kind, id, payload) end
	OnObjective = nil,        -- function(kind, id, data) end
}

-- Expose a simple bind so your UI scripts can attach
_G.EcoshiftClient = _G.EcoshiftClient or {}
_G.EcoshiftClient.Bind = function(tbl)
	for k,v in pairs(tbl) do
		if Hooks[k] ~= nil and type(v) == "function" then Hooks[k] = v end
	end
end

if rBiome then
	rBiome.OnClientEvent:Connect(function(biomeName, biomeData)
		if Hooks.OnBiomeChanged then
			Hooks.OnBiomeChanged(biomeName, biomeData)
		end
	end)
end

if rEvent then
	rEvent.OnClientEvent:Connect(function(kind, id, payload)
		if Hooks.OnEvent then Hooks.OnEvent(kind, id, payload) end
	end)
end

if rObjective then
	rObjective.OnClientEvent:Connect(function(kind, id, data)
		if Hooks.OnObjective then Hooks.OnObjective(kind, id, data) end
	end)
end

-- latency keepalive (optional)
if rPing then
	task.spawn(function()
		while task.wait(10) do
			pcall(function() rPing:FireServer(workspace:GetServerTimeNow()) end)
		end
	end)
end

-- Edge-case: if client joins mid-run and the server hasn't pushed state yet, we wait for first biome packet.
-- Your UI should handle "unknown" state gracefully until OnBiomeChanged fires.
