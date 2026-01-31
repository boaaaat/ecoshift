-- RewardsObserver.lua
-- Grants simple rewards on objective completion via InventoryAdapter; no instance creation.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local InventoryAdapter = require(ReplicatedStorage.Shared.InventoryAdapter)
local ProfileService = require(script.Parent.ProfileService)

local RewardsObserver = {}

local REWARDS = {
	RelayRepair    = { {Id="Steel",N=4}, {Id="Gear",N=1} },
	InfectionPurge = { {Id="Potion_Antidote",N=2}, {Id="Reed",N=5} },
	CrystalHarvest = { {Id="VoidQuartz",N=3}, {Id="PrismShard",N=1} },
	LostResearcher = { {Id="PerkToken",N=1} },
	CommsUplink    = { {Id="FavorToken",N=3} },
	BeastCull      = { {Id="Hide",N=8}, {Id="Bone",N=6} },
	SupplyHeist    = { {Id="Circuit",N=1}, {Id="Steel",N=6} },
	DamSluice      = { {Id="Fish",N=5}, {Id="Salt",N=4} },
}

local function giveAll(rewardList)
	for _,plr in ipairs(Players:GetPlayers()) do
		local inv = InventoryAdapter.Provider(plr)
		for _,r in ipairs(rewardList) do inv.Give(r.Id, r.N) end
	end
end

-- hook from ObjectiveService (_G)
_G.Ecoshift = _G.Ecoshift or {}
task.spawn(function()
	for _ = 1, 50 do
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
			break
		end
		task.wait(0.1)
	end
end)

return RewardsObserver
