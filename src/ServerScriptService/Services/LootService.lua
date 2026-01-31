-- LootService.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local LootService = {}

-- Example pity-timer skeleton; you wire into bosses/objectives.
LootService._bossKillCount = 0
function LootService:OnBossKilled()
	self._bossKillCount += 1
	-- roll blueprint reward with pity
	local pity = (self._bossKillCount % 3 == 0)
	-- return selection so caller can grant actual item/blueprint
	local reward = { Type="Blueprint", Id="Repeater", Pity=pity }
	return reward
end

return LootService
