-- ExampleLootTable.lua
-- Demonstrates advanced loot table schema with rarity pools and tag entries.

return {
	Name = "ExampleLootTable",
	Rolls = { min = 2, max = 4 },
	Unique = false,
	AllowDuplicates = true,
	TierWeightMult = { [1] = 1.0, [2] = 1.3, [3] = 1.7, [4] = 2.1 },
	DropSpread = 4,
	DropHeight = 2,

	-- Legacy fields (used only if Rarities is omitted)
	Items = {
		{ Id = "ForestWood", Min = 2, Max = 5, Weight = 5 },
		{ Id = "ForestStone", Min = 1, Max = 4, Weight = 3 },
		{ Tag = "Resource", Min = 1, Max = 2, Weight = 2 },
		{ Id = "SanditeIngot", Min = 1, Max = 1, Weight = 0.4, MinTier = 3 },
	},
	Guaranteed = {
		{ Id = "Torch", Min = 1, Max = 1 },
	},

	Rarities = {
		Common = {
			Rolls = { min = 1, max = 3 },
			Unique = false,
			AllowDuplicates = true,
			Items = {
				{ Id = "ForestWood", Min = 2, Max = 6, Weight = 4 },
				{ Id = "ForestStone", Min = 1, Max = 4, Weight = 3 },
				{ Tag = "Resource", Min = 1, Max = 3, Weight = 2 },
				{ Tag = "Material", Min = 1, Max = 2, Weight = 1 },
			},
			Guaranteed = {
				{ Id = "Torch", Min = 1, Max = 1 },
			},
		},
		Rare = {
			Rolls = 2,
			Unique = true,
			AllowDuplicates = false,
			Items = {
				{ Id = "SanditeIngot", Min = 1, Max = 2, Weight = 2 },
				{ Id = "ResonantCrystal", Min = 1, Max = 2, Weight = 1 },
				{ Tag = "Weapon", Min = 1, Max = 1, Weight = 0.5 },
				{ Tag = "Armor", Min = 1, Max = 1, Weight = 0.3 },
			},
			Guaranteed = {
				{ Id = "StaminaRation", Min = 2, Max = 4 },
			},
		},
		Legendary = {
			Chance = 0.7,
			Rolls = { min = 1, max = 2 },
			Unique = true,
			AllowDuplicates = false,
			Items = {
				{ Id = "ResonantCrystal", Min = 1, Max = 2, Weight = 1 },
				{ Id = "CrystalBow", Min = 1, Max = 1, Weight = 0.6 },
				{ Tag = "Weapon", Min = 1, Max = 1, Weight = 0.3 },
			},
			Guaranteed = {
				{ Id = "ReinforcedRation", Min = 1, Max = 2 },
			},
		},
		Celestial = {
			Chance = 0.4,
			Rolls = 1,
			Unique = true,
			AllowDuplicates = false,
			Items = {
				{ Id = "AdaptiveSurvivalSuit", Min = 1, Max = 1, Weight = 1 },
				{ Id = "VoidEdge", Min = 1, Max = 1, Weight = 0.6 },
			},
			Guaranteed = {
				{ Id = "ResonantCrystal", Min = 2, Max = 4 },
			},
		},
	},
}
