-- Prototype balance: resistance values are fractions of matching exposure removed.
-- Weather adds to the biome's Temp/Toxin/Wet; it does not replace that baseline.
local SurvivalConfig = {}

SurvivalConfig.ARMOR = {
	ReedSunwrap = { Armor = 4, HeatResistance = 0.70, ColdResistance = 0, ToxinResistance = 0, WetResistance = 0 },
	DesertCloak = { Armor = 12, HeatResistance = 0.85, ColdResistance = 0.10, ToxinResistance = 0.10, WetResistance = 0.20 },
	SwampWaders = { Armor = 16, HeatResistance = 0.15, ColdResistance = 0.20, ToxinResistance = 0.70, WetResistance = 0.85 },
	FrostParka = { Armor = 20, HeatResistance = 0.10, ColdResistance = 0.80, ToxinResistance = 0.10, WetResistance = 0.45 },
	VolcanicPlate = { Armor = 26, HeatResistance = 0.85, ColdResistance = 0.20, ToxinResistance = 0.45, WetResistance = 0.25 },
	CrystalWeave = { Armor = 24, HeatResistance = 0.40, ColdResistance = 0.40, ToxinResistance = 0.55, WetResistance = 0.55 },
	AdaptiveSurvivalSuit = { Armor = 34, HeatResistance = 0.75, ColdResistance = 0.75, ToxinResistance = 0.75, WetResistance = 0.75 },
	AuroraMantle = { Armor = 28, HeatResistance = 0.70, ColdResistance = 0.70, ToxinResistance = 0, WetResistance = 0.50 },
	StarforgedPlate = { Armor = 38, HeatResistance = 0.80, ColdResistance = 0.70, ToxinResistance = 0.70, WetResistance = 0.60 },
}

SurvivalConfig.WEATHER_BY_BIOME = {
	Forest = {
		{ Id = "Clear", Name = "Clear skies", Weight = 4, Temp = 0, Toxin = 0, Wet = 0 },
		{ Id = "Rain", Name = "Canopy rain", Weight = 2, Temp = -0.15, Toxin = 0, Wet = 0.6 },
		{ Id = "Fog", Name = "Morning mist", Weight = 1, Temp = -0.1, Toxin = 0, Wet = 0.2 },
	},
	Desert = {
		{ Id = "Clear", Name = "Dry skies", Weight = 4, Temp = 0, Toxin = 0, Wet = 0 },
		{ Id = "Heatwave", Name = "Heatwave", Weight = 2, Temp = 0.6, Toxin = 0, Wet = 0 },
		{ Id = "Sandstorm", Name = "Sandstorm", Weight = 1, Temp = 0.2, Toxin = 0.2, Wet = 0 },
	},
	Swamp = {
		{ Id = "Overcast", Name = "Heavy overcast", Weight = 4, Temp = 0, Toxin = 0, Wet = 0 },
		{ Id = "Rain", Name = "Marsh downpour", Weight = 2, Temp = -0.15, Toxin = 0, Wet = 0.8 },
		{ Id = "SporeFog", Name = "Spore fog", Weight = 1, Temp = 0, Toxin = 0.5, Wet = 0.2 },
	},
	FrozenTundra = {
		{ Id = "Clear", Name = "Still frost", Weight = 4, Temp = 0, Toxin = 0, Wet = 0 },
		{ Id = "Snow", Name = "Snowfall", Weight = 2, Temp = -0.25, Toxin = 0, Wet = 0.3 },
		{ Id = "Blizzard", Name = "Whiteout", Weight = 1, Temp = -0.7, Toxin = 0, Wet = 0.5 },
	},
	Volcanic = {
		{ Id = "Clear", Name = "Ember skies", Weight = 4, Temp = 0, Toxin = 0, Wet = 0 },
		{ Id = "Ashfall", Name = "Ashfall", Weight = 2, Temp = 0.2, Toxin = 0.3, Wet = 0 },
		{ Id = "Emberstorm", Name = "Emberstorm", Weight = 1, Temp = 0.6, Toxin = 0.2, Wet = 0 },
	},
	CrystalWastes = {
		{ Id = "Clear", Name = "Prismatic calm", Weight = 4, Temp = 0, Toxin = 0, Wet = 0 },
		{ Id = "CrystalHaze", Name = "Crystal haze", Weight = 2, Temp = -0.2, Toxin = 0.3, Wet = 0 },
		{ Id = "StaticStorm", Name = "Static storm", Weight = 1, Temp = 0.3, Toxin = 0.35, Wet = 0.2 },
	},
	AuroraVale = {
		{ Id = "Clear", Name = "Aurora calm", Weight = 4, Temp = 0, Toxin = 0, Wet = 0 },
		{ Id = "DawnSurge", Name = "Dawn surge", Weight = 2, Temp = 0.7, Toxin = 0, Wet = 0 },
		{ Id = "PolarNight", Name = "Polar night", Weight = 1, Temp = -0.8, Toxin = 0, Wet = 0.1 },
	},
	StarfallCrater = {
		{ Id = "Clear", Name = "Starfall calm", Weight = 4, Temp = 0.2, Toxin = 0, Wet = 0 },
		{ Id = "MeteorShower", Name = "Meteor shower", Weight = 2, Temp = 0.7, Toxin = 0.15, Wet = 0 },
		{ Id = "CosmicHaze", Name = "Cosmic haze", Weight = 1, Temp = -0.3, Toxin = 0.3, Wet = 0 },
	},
}

return SurvivalConfig
