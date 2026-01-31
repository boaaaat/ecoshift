-- GameStateService.lua
-- Broadcasts lightweight game state to clients (timer, biome, wave info).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local RoundService = require(script.Parent.RoundService)
local BiomeService = require(script.Parent.BiomeService)

local GameStateService = {}
GameStateService._remote = nil
GameStateService._next = 0

function GameStateService:Init()
	if self._remote then return end
	-- OPTIMIZED: Try immediate lookup first
	local remotesFolder = Util.GetDescendant(Config.Paths.Remotes)
	if not remotesFolder then
		remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 5)
	end
	self._remote = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.GameStateUpdate)
	if not self._remote then return end
	
	-- OPTIMIZED: Use task.spawn with controlled loop instead of Heartbeat
	local updateInterval = (Config.UI and Config.UI.UpdateInterval) or 0.25
	task.spawn(function()
		while true do
			if self._remote then
				self._remote:FireAllClients({
					Elapsed = RoundService:GetElapsed(),
					Biome = BiomeService:GetCurrent(),
				})
			end
			task.wait(updateInterval)
		end
	end)
end

return GameStateService
