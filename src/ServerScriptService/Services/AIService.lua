-- Location: ServerScriptService/Services/AIService.lua
-- (CORRECTED VERSION)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local BiomeService = require(script.Parent.BiomeService)
local ThreatService = require(script.Parent.ThreatService)

local AIService = {}

-- Example: who to target next (utility-style choice)
function AIService:SelectTarget(npc)
	local players = Players:GetPlayers()
	local best, bestScore = nil, -1
	for _, plr in ipairs(players) do
		if plr.Character and plr.Character.Parent then
			local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")

			if humanoid and humanoid.Health > 0 then
				local hp = humanoid.Health
				local score = 100 - (hp / humanoid.MaxHealth * 100) -- prefer lowest HP as a percentage
				if score > bestScore then
					bestScore = score
					best = plr
				end
			end
			-- =================================================================

		end
	end
	return best
end

-- Example: tell spawner what to spawn now (delegates to SpawnService via _G)
function AIService:GetWaveComposition()
	local f = _G.Ecoshift and _G.Ecoshift.ComputeEnemyWave
	return f and f() or {}
end

return AIService