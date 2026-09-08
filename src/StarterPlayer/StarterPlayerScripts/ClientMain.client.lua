if require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end
-- ClientMain.client.lua
-- OPTIMIZED: Non-blocking initialization
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

-- Disable default Roblox backpack/toolbar (we use custom inventory UI)
local function disableDefaultUI()
	local success, err = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	if not success then
		-- Retry after a short delay (sometimes fails on first frame)
		task.delay(0.5, function()
			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			end)
		end)
	end
end
disableDefaultUI()

local function disableShiftLock()
	local localPlayer = Players.LocalPlayer
	if not localPlayer then return end
	pcall(function()
		localPlayer.DevEnableMouseLock = false
	end)
end
-- Mouse lock is configured on StarterPlayer by the server.

-- OPTIMIZED: Defer config loading to not block script start
local Config, Util
task.spawn(function()
	Config = require(ReplicatedStorage.Shared.Config)
	Util = require(ReplicatedStorage.Shared.Util)
end)

-- Wait for modules to load (usually instant)
while not Config or not Util do
	task.wait()
end

-- OPTIMIZED: Try immediate lookup before waiting
local remotesFolder = Util.GetDescendant(Config.Paths.Remotes)
if not remotesFolder then
	remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 5)
end

local rBiome = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.BiomeChanged)
local rEvent = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.EventBroadcast)
local rObjective = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.ObjectiveUpdate)
local rPing = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.Ping)

-- SAFE HOOKS: we don't create UI; we just call hooks if present
local Hooks = {
	OnBiomeChanged = nil,     -- function(biomeName, biomeData) end
	OnEvent = nil,            -- function(kind, id, payload) end
	OnObjective = nil,        -- function(kind, id, data) end
}
local CachedState = {
	BiomeName = nil,
	BiomeData = nil,
	Events = {},
	Objectives = {},
}

-- Expose a simple bind so your UI scripts can attach
_G.EcoshiftClient = _G.EcoshiftClient or {}
_G.EcoshiftClient.Bind = function(tbl)
	for k,v in pairs(tbl) do
		if (k == "OnBiomeChanged" or k == "OnEvent" or k == "OnObjective") and type(v) == "function" then
			Hooks[k] = v
			if k == "OnBiomeChanged" and CachedState.BiomeName ~= nil then
				v(CachedState.BiomeName, CachedState.BiomeData)
			elseif k == "OnEvent" then
				for id, entry in pairs(CachedState.Events) do
					v(entry.Kind, id, entry.Payload)
				end
			elseif k == "OnObjective" then
				for id, entry in pairs(CachedState.Objectives) do
					v("Start", id, entry.StartData)
					v("Progress", id, entry.Progress or 0)
				end
			end
		end
	end
end

if rBiome then
	rBiome.OnClientEvent:Connect(function(biomeName, biomeData)
		CachedState.BiomeName = biomeName
		CachedState.BiomeData = biomeData
		if Hooks.OnBiomeChanged then
			Hooks.OnBiomeChanged(biomeName, biomeData)
		end
	end)
end

if rEvent then
	rEvent.OnClientEvent:Connect(function(kind, id, payload)
		if kind == "Minor_Start" or kind == "Major_Start" then
			CachedState.Events[id] = { Kind = kind, Payload = payload }
		elseif kind == "Minor_End" or kind == "Major_End" then
			CachedState.Events[id] = nil
		end
		if Hooks.OnEvent then Hooks.OnEvent(kind, id, payload) end
	end)
end

if rObjective then
	rObjective.OnClientEvent:Connect(function(kind, id, data)
		if kind == "Start" then
			CachedState.Objectives[id] = {
				StartData = data,
				Progress = data and data.Data and data.Data.Progress or 0,
			}
		elseif kind == "Progress" then
			local entry = CachedState.Objectives[id] or { StartData = nil, Progress = 0 }
			entry.Progress = data or 0
			CachedState.Objectives[id] = entry
		elseif kind == "End" then
			CachedState.Objectives[id] = nil
		end
		if Hooks.OnObjective then Hooks.OnObjective(kind, id, data) end
	end)
end

-- latency keepalive (optional)
if rPing then
	task.defer(function()
		while true do
			task.wait(10)
			pcall(function() rPing:FireServer(workspace:GetServerTimeNow()) end)
		end
	end)
end

-- Edge-case: if client joins mid-run and the server hasn't pushed state yet, we wait for first biome packet.
-- Your UI should handle "unknown" state gracefully until OnBiomeChanged fires.
