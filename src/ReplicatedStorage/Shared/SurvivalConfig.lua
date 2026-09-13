-- Prototype balance: resistance values are fractions of matching exposure removed.
-- Weather adds to the biome's Temp/Toxin/Wet; it does not replace that baseline.
local SurvivalConfig = {}

SurvivalConfig.ARMOR = {}
for id,gear in pairs(require(script.Parent.OverhaulCatalog).Gear) do
 if gear.Kind=="Armor" then
  local armor={Armor=gear.Defense*100}
  for channel,value in pairs(gear.Resistance or {}) do armor[channel.."Resistance"]=value end
  SurvivalConfig.ARMOR[id]=armor
 end
end

SurvivalConfig.WEATHER_BY_BIOME = {
	Forest = {
		{ Id = "Clear", Name = "Clear skies", Weight = 4, Temp = 0, Toxin = 0, Wet = 0 },
		{ Id = "Rain", Name = "Canopy rain", Weight = 2, MinElapsed = 5 * 60, Temp = -0.15, Toxin = 0, Wet = 0.6 },
		{ Id = "Fog", Name = "Morning mist", Weight = 1, Temp = -0.1, Toxin = 0, Wet = 0.2 },
	},
	Desert = {
		{ Id = "Clear", Name = "Dry skies", Weight = 4, Temp = 0, Toxin = 0, Wet = 0 },
		{ Id = "Heatwave", Name = "Heatwave", Weight = 2, MinElapsed = 20 * 60, Temp = 0.6, Toxin = 0, Wet = 0 },
		{ Id = "Sandstorm", Name = "Sandstorm", Weight = 1, MinElapsed = 35 * 60, Temp = 0.2, Toxin = 0.2, Wet = 0 },
	},
	Swamp = {
		{ Id = "Overcast", Name = "Heavy overcast", Weight = 4, Temp = 0, Toxin = 0, Wet = 0 },
		{ Id = "Rain", Name = "Marsh downpour", Weight = 2, MinElapsed = 15 * 60, Temp = -0.15, Toxin = 0, Wet = 0.8 },
		{ Id = "SporeFog", Name = "Spore fog", Weight = 1, MinElapsed = 30 * 60, Temp = 0, Toxin = 0.5, Wet = 0.2 },
	},
	FrozenTundra = {
		{ Id = "Clear", Name = "Still frost", Weight = 4, Temp = 0, Toxin = 0, Wet = 0 },
		{ Id = "Snow", Name = "Snowfall", Weight = 2, Temp = -0.25, Toxin = 0, Wet = 0.3 },
		{ Id = "Blizzard", Name = "Whiteout", Weight = 1, MinElapsed = 45 * 60, Temp = -0.7, Toxin = 0, Wet = 0.5 },
	},
	Volcanic = {
		{ Id = "Clear", Name = "Ember skies", Weight = 4, Temp = 0, Toxin = 0, Wet = 0 },
		{ Id = "Ashfall", Name = "Ashfall", Weight = 2, Temp = 0.2, Toxin = 0.3, Wet = 0 },
		{ Id = "Emberstorm", Name = "Emberstorm", Weight = 1, MinElapsed = 50 * 60, Temp = 0.6, Toxin = 0.2, Wet = 0 },
	},
	CrystalWastes = {
		{ Id = "Clear", Name = "Prismatic calm", Weight = 4, Temp = 0, Toxin = 0, Wet = 0 },
		{ Id = "CrystalHaze", Name = "Crystal haze", Weight = 2, Temp = -0.2, Toxin = 0.3, Wet = 0 },
		{ Id = "StaticStorm", Name = "Static storm", Weight = 1, MinElapsed = 60 * 60, Temp = 0.3, Toxin = 0.35, Wet = 0.2 },
	},
	AuroraVale = {
		{ Id = "Clear", Name = "Aurora calm", Weight = 4, Temp = 0, Toxin = 0, Wet = 0 },
		{ Id = "DawnSurge", Name = "Dawn surge", Weight = 2, Temp = 0.7, Toxin = 0, Wet = 0 },
		{ Id = "PolarNight", Name = "Polar night", Weight = 1, MinElapsed = 60 * 60, Temp = -0.8, Toxin = 0, Wet = 0.1 },
	},
	StarfallCrater = {
		{ Id = "Clear", Name = "Starfall calm", Weight = 4, Temp = 0.2, Toxin = 0, Wet = 0 },
		{ Id = "MeteorShower", Name = "Meteor shower", Weight = 2, Temp = 0.7, Toxin = 0.15, Wet = 0 },
		{ Id = "CosmicHaze", Name = "Cosmic haze", Weight = 1, MinElapsed = 75 * 60, Temp = -0.3, Toxin = 0.3, Wet = 0 },
	},
}

local extra={
 SaltglassCoast={{"Clear","Sea breeze",0,0,0},{"Rain","Coastal rain",-.15,0,.7},{"SeaFog","Salt fog",-.1,0,.3}},
 StormspireHighlands={{"Clear","Highland winds",-.1,0,0},{"Rain","Mountain rain",-.3,0,.8},{"Thunderstorm","Thunderstorm",-.2,0,.9}},
 MyceliumHollow={{"Clear","Spore glimmer",0,0,0},{"Rain","Forest drizzle",0,0,.4},{"SporeFog","Spore cloud",0,.4,.2}},
 IronrootBadlands={{"Clear","Dry winds",.1,0,0},{"DustWind","Rust dust",.2,.2,0},{"DryStorm","Dust storm",.3,.3,0}},
 CanopySea={{"Clear","Canopy light",.1,0,0},{"Rain","Tropical rain",.1,0,.8},{"Monsoon","Monsoon",0,0,1}},
 SunkenArchive={{"Clear","Still water",-.1,0,.1},{"Rain","River rain",-.2,0,.6},{"FloodMist","Cold mist",-.3,0,.5}},
 UmbralDepths={{"Clear","Cave stillness",-.1,0,0},{"CaveDrip","Cave condensation",-.2,0,.4},{"DeepMist","Deep mist",-.2,.3,.3}},
 ShattermoonExpanse={{"Clear","Moonlight",-.1,0,0},{"MoonDust","Moon dust",-.2,.15,0},{"SilverHaze","Silver haze",-.3,.25,0}},
}
for id,rows in pairs(extra) do
 SurvivalConfig.WEATHER_BY_BIOME[id]={}
 for i,row in ipairs(rows) do
  table.insert(SurvivalConfig.WEATHER_BY_BIOME[id],{Id=row[1],Name=row[2],Temp=row[3],Toxin=row[4],Wet=row[5],Weight=({4,2,1})[i],MinTier=i==3 and 3 or 1,MinVisits=i==3 and 2 or 0})
 end
end
-- Severe weather follows campaign progression, rather than minutes spent in a safe early tier.
for _,pool in pairs(SurvivalConfig.WEATHER_BY_BIOME) do
 for _,weather in ipairs(pool) do
  if weather.MinElapsed then weather.MinElapsed=nil;weather.MinTier=weather.Weight==1 and 3 or 2;weather.MinVisits=weather.Weight==1 and 2 or 0 end
 end
end

return SurvivalConfig
