-- Provisional device balance. Devices are retained; only fuel is consumed.
return {
	VoteSeconds = 20,
	Order = { "Delay", "Advance", "Select" },
	Actions = {
		Delay = {
			Device = "ShiftStabilizer", Name = "Shift Stabilizer", Verb = "Stabilize",
			Description = "Add 60 seconds to the current biome. Once per shift.",
			Cooldown = 300, Fuel = { { Id = "Coal", N = 2 }, { Id = "SapResin", N = 2 } },
		},
		Advance = {
			Device = "ShiftTrigger", Name = "Shift Trigger", Verb = "Advance",
			Description = "Begin a 15-second shift warning. Available after the first minute.",
			Cooldown = 300, Fuel = { { Id = "SunShard", N = 1 }, { Id = "Coal", N = 2 } },
		},
		Select = {
			Device = "BiomeSelector", Name = "Biome Selector", Verb = "Set destination",
			Description = "Choose the next unlocked biome. Timing stays unchanged.",
			Cooldown = 600, Fuel = { { Id = "ResonantCrystal", N = 2 }, { Id = "BioGel", N = 1 } },
		},
	},
}
