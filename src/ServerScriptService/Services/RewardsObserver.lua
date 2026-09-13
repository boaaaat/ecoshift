-- ObjectiveService delivers optional rewards through ExpeditionRewards' durable ledger.
local Service={}
function Service:Init() require(script.Parent.ExpeditionRewardsService):Init() end
return Service
