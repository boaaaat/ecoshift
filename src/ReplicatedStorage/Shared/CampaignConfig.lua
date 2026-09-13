local C = {}
C.Damage = {18,36,72,144,288,576,1152,2304}
C.MonsterDamage = {8,12,18,27,41,62,93,140}
C.Milestones = {
 {Id="FieldRelay",Name="Field Relay",Facts={Antenna=true},Cost={Plank=12,IronBar=4,Cloth=4},Defense=60},
 {Id="BogKing",Name="Bog King",Facts={BogDen=true},Boss="BogKing"},
 {Id="OldForge",Name="Old Forge",Facts={Cooling=true,Focus=true},Cost={SteelBar=12,BlackGlass=8,Glass=6},Defense=90},
 {Id="FallenStar",Name="Fallen Star",Facts={CraterInstrument=true},Cost={MeteorBar=8,AuroraStone=4},Boss="FallenStar"},
 {Id="WeatherTower",Name="Weather Tower",Instruments=3,Cost={StormBar=12,Gears=8,StormCloth=6},Defense=120},
 {Id="Ironback",Name="Ironback",Facts={MineArena=true},Boss="Ironback"},
 {Id="DeepArchive",Name="Deep Archive",Facts={ArchiveRoute=true,ArchiveRecord1=true,ArchiveRecord2=true,ArchiveRecord3=true},Cost={DeepMetal=10,PressureGlass=8,SailCloth=6},Interior="DeepArchive"},
 {Id="MoonWarden",Name="Moon Warden",Facts={MoonArena=true},Boss="MoonWarden"},
}
-- A clue is world-owned progress: picking it up never leaves a quest item on one player.
C.Clues = {
 {Id="Antenna",Name="Recover relay antenna",Tier=1,Biomes={Forest=true,Desert=true},Depth=1},
 {Id="BogDen",Name="Locate the Bog King's den",Tier=2,Biomes={Swamp=true},Depth=2},
 {Id="Cooling",Name="Restore forge cooling",Tier=3,Biomes={FrozenTundra=true},Depth=2},
 {Id="Focus",Name="Recover focusing crystal",Tier=3,Biomes={CrystalWastes=true},Depth=2},
 {Id="CraterInstrument",Name="Recover crater instrument",Tier=4,Biomes={StarfallCrater=true},Depth=3},
 {Id="CalibratedInstrument",Name="Recover calibrated instrument",Tier=5,Depth=3,DistinctBiomes=true},
 {Id="MineArena",Name="Open the abandoned mine",Tier=6,Biomes={IronrootBadlands=true},Depth=4},
 {Id="ArchiveRoute",Name="Open the archive route",Tier=7,Biomes={SunkenArchive=true},Depth=4},
 {Id="MoonArena",Name="Chart the Warden's arena",Tier=8,Biomes={ShattermoonExpanse=true},Depth=5},
}
C.Bosses = {
 BogKing={Name="Bog King",Tier=2,Color=Color3.fromRGB(79,115,58),Rooms=2,Trophy="MarshHeart"},
 BogKingEnhanced={Name="Deep Bog King",Tier=4,Color=Color3.fromRGB(108,75,125),Rooms=2,Trophy="MarshHeart"},
 FallenStar={Name="Fallen Star",Tier=4,Color=Color3.fromRGB(120,155,176),Rooms=0,Trophy="GreaterStarCore"},
 Ironback={Name="Ironback",Tier=6,Color=Color3.fromRGB(136,82,57),Rooms=0,Trophy="IronHeart"},
 MoonWarden={Name="Moon Warden",Tier=8,Color=Color3.fromRGB(182,190,218),Rooms=0,Trophy="GravityShard"},
}
return C
