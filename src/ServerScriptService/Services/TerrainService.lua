-- Terrain generation is owned by the streamed surface planner.
local Service={}
function Service:Generate(biome) return require(script.Parent.WorldGenController):GenerateBiome(biome) end
return Service
