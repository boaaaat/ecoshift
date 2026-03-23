-- GameStateService.lua
-- Broadcasts lightweight game state to clients (timer, biome, match state).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local RoundService = require(script.Parent.RoundService)
local BiomeService = require(script.Parent.BiomeService)

local GameStateService = {}
GameStateService._remote = nil
GameStateService._initialized = false
GameStateService._callbacks = {}
GameStateService._state = {
	MatchState = "Active",
	EndReason = nil,
	FinalElapsed = nil,
	CanReturnToLobby = RunService:IsStudio(),
}

function GameStateService:_ensureRemote()
	if self._remote then
		return self._remote
	end
	local remotesFolder = Util.GetDescendant(Config.Paths.Remotes)
	if not remotesFolder then
		remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 5)
	end
	self._remote = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.GameStateUpdate)
	return self._remote
end

function GameStateService:_composePayload()
	return {
		Elapsed = RoundService:GetElapsed(),
		Biome = BiomeService:GetCurrent(),
		MatchState = self._state.MatchState,
		EndReason = self._state.EndReason,
		FinalElapsed = self._state.FinalElapsed,
		CanReturnToLobby = self._state.CanReturnToLobby == true,
	}
end

function GameStateService:_notifyCallbacks(state)
	for _, callback in ipairs(self._callbacks) do
		pcall(callback, state)
	end
end

function GameStateService:Broadcast()
	local remote = self:_ensureRemote()
	if remote then
		remote:FireAllClients(self:_composePayload())
	end
end

function GameStateService:SendToPlayer(plr)
	local remote = self:_ensureRemote()
	if remote and plr then
		remote:FireClient(plr, self:_composePayload())
	end
end

function GameStateService:GetState()
	return self:_composePayload()
end

function GameStateService:IsGameOver()
	return self._state.MatchState == "GameOver"
end

function GameStateService:EndGame(reason, finalElapsed)
	if self:IsGameOver() then
		return false
	end
	self._state.MatchState = "GameOver"
	self._state.EndReason = reason or "Unknown"
	self._state.FinalElapsed = tonumber(finalElapsed) or RoundService:GetElapsed()
	local state = self:_composePayload()
	self:_notifyCallbacks(state)
	self:Broadcast()
	return true
end

function GameStateService:OnStateChanged(callback)
	if type(callback) ~= "function" then
		return
	end
	table.insert(self._callbacks, callback)
	pcall(callback, self:GetState())
end

function GameStateService:Init()
	if self._initialized then return end
	self._initialized = true
	self:_ensureRemote()

	Players.PlayerAdded:Connect(function(plr)
		task.defer(function()
			self:SendToPlayer(plr)
		end)
	end)

	local updateInterval = (Config.UI and Config.UI.UpdateInterval) or 0.25
	task.spawn(function()
		while true do
			self:Broadcast()
			task.wait(updateInterval)
		end
	end)
end

return GameStateService
