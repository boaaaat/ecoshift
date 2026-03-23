-- RewardsObserver.lua
-- Grants simple rewards on objective completion via InventoryAdapter; no instance creation.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local InventoryAdapter = require(ReplicatedStorage.Shared.InventoryAdapter)
local ProfileService = require(script.Parent.ProfileService)

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

local function giveAll(rewardList)
	for _,plr in ipairs(Players:GetPlayers()) do
		local inv = InventoryAdapter.Provider(plr)
		for _,r in ipairs(rewardList) do inv.Give(r.Id, r.N) end
	end
end

-- hook from ObjectiveService (_G)
function RewardsObserver:Init()
	if self._initialized then return end
	self._initialized = true
	_G.Ecoshift = _G.Ecoshift or {}
	task.spawn(function()
		for _ = 1, 200 do
			if type(_G.Ecoshift.OnObjectiveEndAdd) == "function" then
				_G.Ecoshift.OnObjectiveEndAdd(function(id, entry)
					if entry and entry.State == "Completed" then
						local r = REWARDS[id]
						if r then pcall(giveAll, r) end
						for _, plr in ipairs(Players:GetPlayers()) do
							ProfileService:AddXP(plr, 15)
						end
					end
				end)
				return
			end
			task.wait(0.1)
		end
	end)
end

return RewardsObserver
