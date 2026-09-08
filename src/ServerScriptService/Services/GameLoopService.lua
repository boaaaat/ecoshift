-- GameLoopService.lua
-- Handles terminal game-over flow on a full-party wipe.
local Players = game:GetService("Players")

local GameStateService = require(script.Parent.GameStateService)
local ObjectiveService = require(script.Parent.ObjectiveService)
local EventService = require(script.Parent.EventService)
local DayNightService = require(script.Parent.DayNightService)
local BiomeService = require(script.Parent.BiomeService)

local GameLoopService = {}
GameLoopService._gameEnded = false

function GameLoopService:_handleWipe(elapsed)
	if self._gameEnded then
		return
	end
	self._gameEnded = true
	GameStateService:EndGame("Wipe", elapsed)
	ObjectiveService:EndAll("Cancelled", { SuppressThreat = true })
	EventService:EndAll()
	DayNightService:Pause()
	BiomeService:Pause()
end

function GameLoopService:Init()
	_G.Ecoshift = _G.Ecoshift or {}
	_G.Ecoshift.OnRoundEnd = function(elapsed)
		self:_handleWipe(elapsed)
	end
end

return GameLoopService
