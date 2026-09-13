-- Encounters are selected and saved by EnemySpawner, using region metadata.
local Service={}
function Service:ComputeEnemyWave() return {} end
function Service:GetSpawnPoints() return {} end
function Service:GetActiveResourceTags()
 local tags={};local world=require(script.Parent.OverhaulWorldService)
 for _,region in ipairs(world:GetRegions()) do for _,id in ipairs(region.Resources) do tags[id]=true end end
 return tags
end
function Service:Init() end
function Service:Bind() end
return Service
