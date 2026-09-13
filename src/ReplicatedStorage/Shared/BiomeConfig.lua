-- Current overhaul world configuration. All sixteen biomes ship together.
local Catalog=require(script.Parent.OverhaulBiomes)
local Config={seed=Random.new():NextInteger(10000,99999),world_radius=1500,center_exclusion_radius=200,base_y=0,chunk_size=240,spawn_folder_name="GeneratedWorld",biome_default="Forest",BIOME_DEFAULT="Forest",biomes={},BIOMES={},biome_metadata={},future_biomes={}}
Config.BIOME_SHIFT={MinSeconds=300,MaxSeconds=500};Config.biome_shift=Config.BIOME_SHIFT
Config.WORLD={WorldRadius=1500,CenterExclusionRadius=200,BaseY=0}
Config.TERRAIN={Thickness=160,MaterialByBiome={}}
for id,biome in pairs(Catalog.Biomes) do
 local meta={DisplayName=biome.DisplayName,Name=biome.DisplayName,Weight=1,UnlockTier=biome.UnlockTier,Temp=biome.Temp,Temperature=biome.Temp,env={Temp=biome.Temp/12,Toxin=0,Wet=0},Color=biome.Color,MapColor=biome.Color}
 if id=="AuroraVale" then meta.WeatherCycle={"Clear","DawnSurge","PolarNight"};meta.WeatherCycleSeconds=60 end
 Config.BIOMES[id]=meta;Config.biome_metadata[id]=meta;Config.TERRAIN.MaterialByBiome[id]=biome.Material
 local regions={}
 for _,r in ipairs(biome.Regions) do
  local resources={};for _,resource in ipairs(r.Resources) do resources[resource]={Weight=1} end
  table.insert(regions,{name=r.Name,resources=resources,props={},enemies={},Depth=r.Depth})
 end
 Config.biomes[id]={displayName=biome.DisplayName,weight=1,regions=regions,structures={},objectives={},chests={}}
end
return Config
