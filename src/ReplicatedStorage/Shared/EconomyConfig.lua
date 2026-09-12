-- Initial tuning; rewards are issued only by authoritative expedition systems.
return {
	SchemaVersion = 3,
	CurrencyName = "Field Marks",
	DefaultTheme = "Dark",
	ClassPrices = { Gatherer=400, Builder=500, Hunter=500, Medic=600, Engineer=800, Scout=400, Cook=400, Botanist=600, Prospector=600, Warden=600, Climatologist=800 },
	MaxCurrency = 1000000000000,
	MaxRewardAmount = 1000000,
	-- Never evict receipts and silently allow an old reward to be paid twice.
	-- Fail closed at this bound; a future archival migration can raise capacity.
	MaxRewardReceipts = 10000,
	MaxPendingOperations = 100,
	DataStoreAttempts = 3,
	AllowStudioRoleSelection = false,
	-- Initial earned progression tuning; all grants originate from server gameplay.
	Rewards = {
		SurvivalSeconds = 300,
		Survival = { Currency = 20, XP = 25 },
		Objective = { Currency = 15, XP = 15 },
		Revive = { Currency = 5, XP = 10 },
		RevivesPerMilestone = 2,
		RetrySeconds = 15,
		MaxClaims = 10000,
	},
}
