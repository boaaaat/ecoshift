-- Every event owns a visible activity, bounded lifetime and local consequences.
local C={Cadence={MinorCadence={180,300},MajorCadence={600,900}},Definitions={},BiomePools={}}
local function add(id,name,tier,kind,template,biomes,rewards,options)
 local d={Id=id,Name=name,DisplayName=name,Tier=tier,Type=kind,Template=template,Biomes=biomes,Rewards=rewards,Duration=150,EndOnBiomeChange=true,Harmful=kind=="Major",Warning=kind=="Major" and 15 or 0}
 for k,v in pairs(options or {}) do d[k]=v end
 C.Definitions[id]=d
end
add("FreshGrowth","Fresh Growth",1,"Minor","Gather",nil,{{Id="Mushroom",N=4},{Id="HealingHerb",N=3}})
add("SupplySignal","Supply Signal",1,"Minor","Recover",nil,{{Id="Bandage",N=2},{Id="Wood",N=8}})
add("LostExplorer","Lost Explorer",1,"Minor","Escort",nil,{{Id="Bandage",N=2},{Id="Water",N=3}},{Duration=240})
add("AnimalMigration","Animal Migration",2,"Minor","Survey",nil,{{Id="RawMeat",N=3},{Id="Bone",N=2}},{Wildlife=true})
add("BuriedCache","Buried Cache",2,"Minor","Break",{Desert=true},{{Id="IronBar",N=3},{Id="Glass",N=2}})
add("RisingWater","Rising Water",2,"Major","Drain",{SaltglassCoast=true,Swamp=true,SunkenArchive=true},{{Id="ShellPlate",N=3},{Id="Water",N=3}},{Exposure=0,Wet=true})
add("Whiteout","Whiteout",3,"Major","Shelter",{FrozenTundra=true},{{Id="IceCrystal",N=4},{Id="FrostBloom",N=2}},{Exposure=-.35})
add("SporeBloom","Spore Bloom",3,"Major","Vents",{Swamp=true,MyceliumHollow=true},{{Id="HerbalPaste",N=3},{Id="ThickSpores",N=3}},{Toxin=.15})
add("FallingStars","Falling Stars",4,"Major","Impact",{StarfallCrater=true},{{Id="MeteorOre",N=4},{Id="ImpactGlass",N=4}})
add("HeatSurge","Heat Surge",3,"Major","Shelter",{Desert=true,Volcanic=true},{{Id="Sunstone",N=3},{Id="BlackGlass",N=3}},{Exposure=.35})
add("CrystalEcho","Crystal Echo",4,"Minor","Puzzle",{CrystalWastes=true},{{Id="EnchantingDust",N=4}},{Schematic={"StrikeRhythm","OpenSeam","DryStep"}})
add("AuroraShift","Aurora Shift",4,"Major","Thermal",{AuroraVale=true},{{Id="AuroraStone",N=4},{Id="DawnFlower",N=3}},{Exposure=.3,Schematic={"WeatherMemory","HeatStore"}})
add("Thunderfront","Thunderfront",5,"Major","Lightning",{StormspireHighlands=true},{{Id="StormOre",N=4},{Id="CloudWool",N=4}},{Schematic={"StormLatch","ReturnShot"}})
add("RootOutbreak","Root Outbreak",5,"Minor","Break",{MyceliumHollow=true,IronrootBadlands=true},{{Id="LivingRoot",N=3},{Id="HerbalPaste",N=3}},{Harmful=true,Warning=15})
add("BrokenCrossing","Broken Crossing",5,"Minor","Repair",{CanopySea=true,SaltglassCoast=true},{{Id="StrongSilk",N=3},{Id="LiftSeed",N=2}},{Cost={{Id="Wood",N=6},{Id="Cord",N=4}},Schematic={"AirPocket","SurveyLink"}})
add("ArchiveAlarm","Archive Alarm",6,"Major","Disable",{SunkenArchive=true},{{Id="OldGear",N=4},{Id="PressureGlass",N=3}},{Schematic={"AirPocket","RescueReserve"}})
add("DeepRumbling","Deep Rumbling",6,"Major","Break",{UmbralDepths=true},{{Id="LightOre",N=4},{Id="EchoShell",N=2}},{Schematic={"PackWarning","LastThread"}})
add("GravityDrift","Gravity Drift",7,"Major","Survey",{ShattermoonExpanse=true},{{Id="MoonOre",N=3}},{Gravity=true,Schematic={"AirPocket","SurveyLink"}})
add("HuntingParty","Hunting Party",4,"Major","Clear",nil,{{Id="BlacksteelBar",N=3}},{Elite=true,Schematic={"StrikeRhythm","VentStrike"}})
add("CampWarning","Camp Warning",3,"Major","Defend",nil,{{Id="Bandage",N=2},{Id="SteelBar",N=3}})
return C
