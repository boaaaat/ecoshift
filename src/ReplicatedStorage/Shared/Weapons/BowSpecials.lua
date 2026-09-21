-- All damage factors are relative to the bow's normal, fully drawn shot.
return {
	HuntingBow = {
		Id="PiercingShot", Name="Piercing Shot", Cooldown=8, Stamina=20, Impact=1.35,
		MaxHits=10, Retention=.8,
		Description="135% impact damage. Pierces up to 10 enemies. Each penetration loses 20% of current damage and speed.",
	},
	MarshBow = {
		Id="SporeArrow", Name="Spore Arrow", Cooldown=12, Stamina=20, Impact=1.2,
		Radius=10, Duration=7, TickDamage=.18, Slow=.25,
		Description="120% impact damage. A 10-stud spore patch deals 18% damage per second for 7s and slows by 25% (half against bosses).",
	},
	DawnBow = {
		Id="FlareArrow", Name="Flare Arrow", Cooldown=14, Stamina=20, Impact=1.25,
		Radius=10, Delay=.8, Blast=1, StaggerRadius=5, Stagger=.65, Reveal=8,
		Description="125% impact damage, then a 100% blast after 0.8s within 10 studs. Reveals enemies for 8s; briefly staggers non-bosses near the center.",
	},
	StormBow = {
		Id="LightningRod", Name="Lightning Rod", Cooldown=16, Stamina=20, Impact=1,
		Radius=12, Duration=6, Pulses=3, Targets=4, PulseDamage=.45,
		Description="100% impact damage. Three lightning pulses over 6s each hit up to 4 enemies within 12 studs for 45% damage.",
	},
	IronwoodBow = {
		Id="VineTrap", Name="Vine Trap", Cooldown=16, Stamina=20, Impact=1,
		Length=24, Width=6, Duration=8, TrapDamage=.7, Root=2, BossSlow=.25,
		Description="100% impact damage. Grows a 24-by-6-stud thorn path for 8s. Crossing enemies take 70% damage once and are rooted for 2s; bosses are slowed 25%.",
	},
	StarBow = {
		Id="StarBarrage", Name="Star Barrage", Cooldown=24, Stamina=25, Impact=1.2,
		Radius=50, InnerRadius=9, Stars=8, StarsPerTarget=3, StarDamage=.45,
		FormationTime=.65, RainDuration=3, FlightTime=.45, FinaleDelay=.35,
		Blast=1, OuterBlast=.5, BossSlow=.2, SlowDuration=2, Lift=4,
		Description="120% comet impact. Eight stars descend over 3s for 45% damage each (max 3 per enemy). Shards detonate for 100% damage within 9 studs, 50% out to 50. Launches non-bosses; slows bosses 20% for 2s.",
	},
}
