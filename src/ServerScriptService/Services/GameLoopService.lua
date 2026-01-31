-- GameLoopService.lua
-- Handles round lifecycle and resets on wipe.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local InventoryService = require(script.Parent.InventoryService)
local ProfileService = require(script.Parent.ProfileService)
local WorldGenController = require(script.Parent.WorldGenController)
local BiomeService = require(script.Parent.BiomeService)

local GameLoopService = {}

function GameLoopService:ResetRound()
	-- reset inventories
	for _, plr in ipairs(Players:GetPlayers()) do
		InventoryService:Reset(plr)
	end
	-- regenerate world with current biome
	WorldGenController:GenerateBiome(BiomeService:GetCurrent())
	-- respawn everyone
	for _, plr in ipairs(Players:GetPlayers()) do
		plr:LoadCharacter()
	end
end

function GameLoopService:Init()
	_G.Ecoshift = _G.Ecoshift or {}
	_G.Ecoshift.OnRoundEnd = function(elapsed)
		for _, plr in ipairs(Players:GetPlayers()) do
			local bonus = math.floor((elapsed or 0) / 10)
			if bonus > 0 then
				ProfileService:AddXP(plr, bonus)
			end
		end
		self:ResetRound()
	end
end

return GameLoopService
