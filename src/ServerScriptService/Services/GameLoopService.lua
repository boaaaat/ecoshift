-- GameLoopService.lua
-- Handles terminal game-over flow on a full-party wipe.
local Players = game:GetService("Players")

local ProfileService = require(script.Parent.ProfileService)
local GameStateService = require(script.Parent.GameStateService)
local ObjectiveService = require(script.Parent.ObjectiveService)
local EventService = require(script.Parent.EventService)
local DayNightService = require(script.Parent.DayNightService)

local GameLoopService = {}
GameLoopService._gameEnded = false

function GameLoopService:_awardRunXP(elapsed)
	for _, plr in ipairs(Players:GetPlayers()) do
		local bonus = math.floor((elapsed or 0) / 10)
		if bonus > 0 then
			ProfileService:AddXP(plr, bonus)
		end
	end
end

function GameLoopService:_handleWipe(elapsed)
	if self._gameEnded then
		return
	end
	self._gameEnded = true
	self:_awardRunXP(elapsed)
	GameStateService:EndGame("Wipe", elapsed)
	ObjectiveService:EndAll("Cancelled", { SuppressThreat = true })
	EventService:EndAll()
	DayNightService:Pause()
end

function GameLoopService:Init()
	_G.Ecoshift = _G.Ecoshift or {}
	_G.Ecoshift.OnRoundEnd = function(elapsed)
		self:_handleWipe(elapsed)
	end
end

return GameLoopService
