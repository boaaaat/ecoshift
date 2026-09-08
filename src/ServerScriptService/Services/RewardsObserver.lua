-- RewardsObserver.lua
-- Registers objective payouts; the reward service owns durable claims and delivery.
local ExpeditionRewards = require(script.Parent.ExpeditionRewardsService)

local RewardsObserver = {}
RewardsObserver._initialized = false

local REWARDS = {
	RelayRepair    = { {Id="SanditeIngot",N=4}, {Id="TemperedGlass",N=1} },
	InfectionPurge = { {Id="AntitoxinTonic",N=2}, {Id="ReedFiber",N=5} },
	CrystalHarvest = { {Id="PhaseQuartz",N=3}, {Id="CrystalShard",N=1} },
	LostResearcher = { {Id="FieldClock",N=1} },
	CommsUplink    = { {Id="PhaseCircuit",N=2} },
	BeastCull      = { {Id="WolfPelt",N=8}, {Id="DriedBone",N=6} },
	SupplyHeist    = { {Id="PhaseCircuit",N=1}, {Id="SanditeIngot",N=6} },
	DamSluice      = { {Id="StaminaRation",N=5}, {Id="SaltCrystal",N=4} },
}

-- hook from ObjectiveService (_G)
function RewardsObserver:Init()
	if self._initialized then return end
	self._initialized = true
	ExpeditionRewards:Init()
	_G.Ecoshift = _G.Ecoshift or {}
	task.spawn(function()
		for _ = 1, 200 do
			if type(_G.Ecoshift.OnObjectiveEndAdd) == "function" then
				_G.Ecoshift.OnObjectiveEndAdd(function(id, entry)
					if entry and entry.State == "Completed" then
						ExpeditionRewards:OnObjective(id, entry, REWARDS[id] or {})
					end
				end)
				return
			end
			task.wait(0.1)
		end
	end)
end

return RewardsObserver
