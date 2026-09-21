-- Requires the world factory only; never calls Init, builds terrain, or mutates
-- live service state. Each scenario has an isolated receiver and explicit tier.
local options = ... or {}
local World = options.World or require(game.ServerScriptService.Services.OverhaulWorldService)
local Biomes = options.Biomes or require(game.ReplicatedStorage.Shared.OverhaulBiomes)
local seeds = options.Seeds or {31337,104729,8675309}
local result = {Scenarios=0,Chunks=0,Candidates=0,UnderwaterCandidates=0,EligibleResources=0,Failures={},Cases={},PlacementFailures={}}
local submergedIds={Stone=true,Kelp=true,ShellPlate=true,Pearl=true,OldGear=true}
local function hash(text,seed)
	local n=seed
	for i=1,#text do n=(n*33+string.byte(text,i))%2147483647 end
	return n
end
for _,biome in ipairs(options.BiomeIds or Biomes.Order) do
	for _,seed in ipairs(seeds) do
		for _,tier in ipairs({1,8}) do for _,visits in ipairs({0,4}) do
			local state=setmetatable({_seed=seed,_biome=biome,_previousVisits=visits,
				_visitSeed=hash(biome..":"..(visits+1),seed),_regions={},_landmarks={}},{__index=World})
			state:_plan(tier)
			local wanted,counts,regionCounts={}, {}, {}
			for _,region in ipairs(Biomes.EligibleRegions(biome,tier,visits)) do
				for _,id in ipairs(region.Resources) do wanted[id]=true end
			end
			wanted.Stone=true
			local total=0
			for cx=-7,6 do for cz=-7,6 do
				local candidates=state:_candidates(cx,cz)
				result.Chunks+=1
				for _,entry in ipairs(candidates) do
					counts[entry.Id]=(counts[entry.Id] or 0)+1
					regionCounts[entry.Region.TypeId]=(regionCounts[entry.Region.TypeId] or 0)+1
					total+=1
					local water=state:GetWaterLevel(entry.Position.X,entry.Position.Z)
					if water and entry.Position.Y<water+.5 then
						result.UnderwaterCandidates+=1
						if Biomes.Biomes[biome].Landform~="Coast" or not submergedIds[entry.Id] then
							table.insert(result.PlacementFailures,{Biome=biome,Seed=seed,Tier=tier,Visits=visits,Id=entry.Id,Key=entry.Key})
						end
					end
				end
			end end
			local missing={}
			for id in pairs(wanted) do
				result.EligibleResources+=1
				if not counts[id] then table.insert(missing,id) end
			end
			table.sort(missing)
			local case={Biome=biome,Seed=seed,VisitSeed=state._visitSeed,Tier=tier,Visits=visits,Candidates=total,Counts=counts,RegionCounts=regionCounts,Missing=missing}
			table.insert(result.Cases,case)
			if #missing>0 then table.insert(result.Failures,case) end
			result.Scenarios+=1;result.Candidates+=total
			-- Leave the live simulation responsive during the numerical sweep.
			task.wait()
		end end
	end
end
result.Passed=#result.Failures==0 and #result.PlacementFailures==0
return result
