-- GameStateService.lua
-- Broadcasts lightweight game state to clients (timer, biome, wave info).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local RoundService = require(script.Parent.RoundService)
local BiomeService = require(script.Parent.BiomeService)

local GameStateService = {}
GameStateService._remote = nil
GameStateService._next = 0

function GameStateService:Init()
	if self._remote then return end
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	self._remote = Util.GetRemote(remotesFolder, Config.RemoteNames.GameStateUpdate)
	if not self._remote then return end
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		if t < self._next then return end
		self._next = t + (Config.UI.UpdateInterval or 0.25)
		self._remote:FireAllClients({
			Elapsed = RoundService:GetElapsed(),
			Biome = BiomeService:GetCurrent(),
		})
	end)
end

return GameStateService
