-- Version-2 world catalog. Legacy biome identifiers deliberately remain stable.
local C = { Order = {"Forest","Desert","Swamp","FrozenTundra","Volcanic","CrystalWastes","AuroraVale","StarfallCrater","SaltglassCoast","StormspireHighlands","MyceliumHollow","IronrootBadlands","CanopySea","SunkenArchive","UmbralDepths","ShattermoonExpanse"}, Biomes = {}, Creatures = {} }
C.Creatures["Wolf"] = { Name = "Wolf", Role = "L", Behavior = "flanking bite and short committed lunge", Biome = "Forest" }
C.Creatures["Boar"] = { Name = "Boar", Role = "H", Behavior = "straight charge with long recovery", Biome = "Forest" }
C.Creatures["BarkSpider"] = { Name = "Bark Spider", Role = "O", Behavior = "ground-level web snare followed by a short bite", Biome = "Forest" }
C.Creatures["Deer"] = { Name = "Deer", Role = "N", Behavior = "cautious herd animal that flees danger", Biome = "Forest" }
C.Biomes["Forest"] = { Id="Forest", DisplayName="Woodlands", UnlockTier=1, Material="Grass", Color=Color3.fromRGB(95, 136, 74), Landform="Forest", Temp=0, Creatures={"Wolf","Boar","BarkSpider","Deer"}, Regions={
{Id="ForestA",Name="Open Meadows",Depth=1,Description="Rolling grassland, streams, open sight lines; learn gathering and establish a route home",RewardDescription="Wood, stone, fiber, mushrooms and berries",Resources={"Wood","Fiber","Mushroom","Berries","RootVegetable","WildHerb"},Weights={15,10,5,70},GroupMin=1,GroupMax=1,Mixed=0.0},
{Id="ForestB",Name="Birch Woods",Depth=2,Description="White-trunk stands, fallen-log routes, small clearings",RewardDescription="Resin, herbs, wolves and warm fur",Resources={"Resin","HealingHerb","Berries","RootVegetable","Wood","Fiber","Mushroom"},Weights={45,15,25,15},GroupMin=1,GroupMax=2,Mixed=0.0},
{Id="ForestC",Name="Old Forest",Depth=3,Description="Dense broad trunks, abandoned ranger platforms",RewardDescription="Deep Resin; wood/medicine schematics",Resources={"DeepResin"},Weights={30,20,40,10},GroupMin=1,GroupMax=3,Mixed=0.1},
{Id="ForestD",Name="Root Caves",Depth=4,Description="Root-supported chambers and underground streams",RewardDescription="Enchanting crystals, supply rooms, difficult ambushes",Resources={"ClearCrystal"},Weights={20,10,65,5},GroupMin=2,GroupMax=3,Mixed=0.15},
{Id="ForestE",Name="Giant Tree Grove",Depth=5,Description="Enormous trees, root bridges, hollow-trunk arenas",RewardDescription="Ancient Seed elite reward; strongest growth discoveries",Resources={"DeepResin"},Weights={30,40,20,10},GroupMin=2,GroupMax=4,Mixed=0.2},
}}
C.Creatures["Scorpion"] = { Name = "Scorpion", Role = "O", Behavior = "visible pincer/tail windups", Biome = "Desert" }
C.Creatures["SandSerpent"] = { Name = "Sand Serpent", Role = "H", Behavior = "visible moving sand trail before emergence", Biome = "Desert" }
C.Creatures["DuneBeetle"] = { Name = "Dune Beetle", Role = "L", Behavior = "short rolling rush, exposed while recovering", Biome = "Desert" }
C.Creatures["DesertFox"] = { Name = "Desert Fox", Role = "N", Behavior = "scavenger that retreats between rock shelters", Biome = "Desert" }
C.Biomes["Desert"] = { Id="Desert", DisplayName="Dunes", UnlockTier=1, Material="Sand", Color=Color3.fromRGB(202, 164, 94), Landform="Dunes", Temp=24, Creatures={"Scorpion","SandSerpent","DuneBeetle","DesertFox"}, Regions={
{Id="DesertA",Name="Sandy Flats",Depth=1,Description="Low dunes, scattered rock shelves, readable paths",RewardDescription="Sand, coal, shallow iron seams",Resources={"Sand","Stone","Coal","IronOre","CoolMint"},Weights={20,5,35,40},GroupMin=1,GroupMax=1,Mixed=0.0},
{Id="DesertB",Name="Cactus Valley",Depth=2,Description="Sheltered channels, cactus groves, small water pockets",RewardDescription="Cactus, iron; first heat supplies",Resources={"Cactus","IronOre"},Weights={35,10,20,35},GroupMin=1,GroupMax=2,Mixed=0.0},
{Id="DesertC",Name="Red Canyons",Depth=3,Description="Winding red walls, natural bridges, exposed ledges",RewardDescription="Sunstone, rich ore, scorpion encounters",Resources={"Sunstone"},Weights={45,30,20,5},GroupMin=1,GroupMax=2,Mixed=0.1},
{Id="DesertD",Name="Buried City",Depth=4,Description="Roofs emerging from sand; accessible underground streets",RewardDescription="Enchanting discoveries and recovered machine parts",Resources={"IronOre"},Weights={30,35,30,5},GroupMin=2,GroupMax=3,Mixed=0.15},
{Id="DesertE",Name="Glass Dunes",Depth=5,Description="Fused-glass ridges, hot vents, dangerous reflections",RewardDescription="Sun Heart elite reward; advanced heat effects",Resources={"Sunstone"},Weights={20,50,25,5},GroupMin=2,GroupMax=4,Mixed=0.2},
}}
C.Creatures["Leech"] = { Name = "Leech", Role = "L", Behavior = "slow approach and interruptible drain contact", Biome = "Swamp" }
C.Creatures["BogToad"] = { Name = "Bog Toad", Role = "H", Behavior = "aimed tongue shot and recovery pause", Biome = "Swamp" }
C.Creatures["MarshSnake"] = { Name = "Marsh Snake", Role = "O", Behavior = "swims between banks, pauses visibly before striking", Biome = "Swamp" }
C.Creatures["Heron"] = { Name = "Heron", Role = "N", Behavior = "shallow-water feeder that flies away from danger", Biome = "Swamp" }
C.Biomes["Swamp"] = { Id="Swamp", DisplayName="Marsh", UnlockTier=2, Material="Mud", Color=Color3.fromRGB(73, 102, 77), Landform="Wetland", Temp=5, Creatures={"Leech","BogToad","MarshSnake","Heron"}, Regions={
{Id="SwampA",Name="Reed Marsh",Depth=1,Description="Shallow water with connected raised banks",RewardDescription="Reeds, herbs, safe wetness introduction",Resources={"Reeds","HealingHerb","Berries","RootVegetable","BitterSeed"},Weights={35,10,15,40},GroupMin=1,GroupMax=2,Mixed=0.0},
{Id="SwampB",Name="Willow Pools",Depth=2,Description="Tree-root islands and slow streams",RewardDescription="Peat, glowcaps, leech venom",Resources={"Peat","Glowcap"},Weights={45,20,15,20},GroupMin=1,GroupMax=3,Mixed=0.05},
{Id="SwampC",Name="Mushroom Bog",Depth=3,Description="Large mushrooms, drifting spores, clear dry routes",RewardDescription="Bog King entrance, antidote/enchanting discoveries",Resources={"Glowcap"},Weights={20,40,30,10},GroupMin=1,GroupMax=3,Mixed=0.1},
{Id="SwampD",Name="Sunken Village",Depth=4,Description="Flooded houses and narrow raised walkways",RewardDescription="Advanced supplies, venom specialists",Resources={"Reeds"},Weights={30,25,40,5},GroupMin=2,GroupMax=4,Mixed=0.2},
{Id="SwampE",Name="Blackwater Basin",Depth=5,Description="Dark pools divided by root islands",RewardDescription="Marsh Heart elite reward; strongest toxin discoveries",Resources={"Peat"},Weights={25,45,25,5},GroupMin=2,GroupMax=4,Mixed=0.2},
}}
C.Creatures["FrostWolf"] = { Name = "Frost Wolf", Role = "L", Behavior = "flank and short-lived cold patch", Biome = "FrozenTundra" }
C.Creatures["IceWraith"] = { Name = "Ice Wraith", Role = "O", Behavior = "windup dash followed by a vulnerable pause", Biome = "FrozenTundra" }
C.Creatures["IceBear"] = { Name = "Ice Bear", Role = "H", Behavior = "slow swipe and telegraphed ground slam", Biome = "FrozenTundra" }
C.Creatures["SnowHare"] = { Name = "Snow Hare", Role = "N", Behavior = "small prey animal using snow shelters", Biome = "FrozenTundra" }
C.Biomes["FrozenTundra"] = { Id="FrozenTundra", DisplayName="Tundra", UnlockTier=2, Material="Snow", Color=Color3.fromRGB(166, 192, 202), Landform="Alpine", Temp=-24, Creatures={"FrostWolf","IceWraith","IceBear","SnowHare"}, Regions={
{Id="FrozenTundraA",Name="Snowfields",Depth=1,Description="Gentle slopes, sparse snow, visible shelter",RewardDescription="Common supplies, basic cold introduction",Resources={"Stone","Fiber","WarmPepper"},Weights={20,10,5,65},GroupMin=1,GroupMax=1,Mixed=0.0},
{Id="FrozenTundraB",Name="Frozen Woods",Depth=2,Description="Snow-covered pines, windbreaks, shallow ice caves",RewardDescription="Warm fur, ice crystals",Resources={"IceCrystal","Wood"},Weights={45,10,15,30},GroupMin=1,GroupMax=2,Mixed=0.05},
{Id="FrozenTundraC",Name="Frozen Lake",Depth=3,Description="Broad ice with visible cracks and safe shore routes",RewardDescription="Frost Bloom, ice discoveries",Resources={"FrostBloom"},Weights={25,30,25,20},GroupMin=1,GroupMax=3,Mixed=0.1},
{Id="FrozenTundraD",Name="Ice Caves",Depth=4,Description="Translucent chambers, hanging ice, narrow passes",RewardDescription="Concentrated crystals, frost enchantments",Resources={"IceCrystal"},Weights={20,55,20,5},GroupMin=1,GroupMax=2,Mixed=0.1},
{Id="FrozenTundraE",Name="Whiteout Peaks",Depth=5,Description="Wind-exposed ridges and summit shelters",RewardDescription="Frost Heart elite reward",Resources={"FrostBloom"},Weights={30,35,30,5},GroupMin=2,GroupMax=3,Mixed=0.15},
}}
C.Creatures["AshHound"] = { Name = "Ash Hound", Role = "L", Behavior = "fast approach and committed bite", Biome = "Volcanic" }
C.Creatures["LavaGolem"] = { Name = "Lava Golem", Role = "H", Behavior = "slow slam with a marked ground area", Biome = "Volcanic" }
C.Creatures["CinderCrab"] = { Name = "Cinder Crab", Role = "O", Behavior = "sideways approach and brief hot ground behind it", Biome = "Volcanic" }
C.Creatures["AshLizard"] = { Name = "Ash Lizard", Role = "N", Behavior = "hides in cooled rock cracks", Biome = "Volcanic" }
C.Biomes["Volcanic"] = { Id="Volcanic", DisplayName="Volcanic Plains", UnlockTier=3, Material="Basalt", Color=Color3.fromRGB(76, 65, 67), Landform="Volcanic", Temp=30, Creatures={"AshHound","LavaGolem","CinderCrab","AshLizard"}, Regions={
{Id="VolcanicA",Name="Ash Plains",Depth=1,Description="Rolling ash beds with safe exposed stone",RewardDescription="Ash Fiber, coal",Resources={"AshFiber","Coal","EmberPepper"},Weights={30,5,25,40},GroupMin=1,GroupMax=1,Mixed=0.0},
{Id="VolcanicB",Name="Black Rock Fields",Depth=2,Description="Basalt shelves, cooled flows, sheltered gullies",RewardDescription="Black Glass, sulfur; Old Forge approach",Resources={"BlackGlass","Sulfur"},Weights={25,20,30,25},GroupMin=1,GroupMax=2,Mixed=0.05},
{Id="VolcanicC",Name="Lava Channels",Depth=3,Description="Slow visible lava channels with solid crossings",RewardDescription="Heat schematics and richer black glass",Resources={"BlackGlass"},Weights={40,25,25,10},GroupMin=1,GroupMax=3,Mixed=0.15},
{Id="VolcanicD",Name="Furnace Ruins",Depth=4,Description="Stone foundries integrated into cliffs",RewardDescription="Fire Core, forge/enchanting discoveries",Resources={"FireCore"},Weights={20,45,30,5},GroupMin=1,GroupMax=2,Mixed=0.1},
{Id="VolcanicE",Name="Volcano Heart",Depth=5,Description="Caldera walls and a controlled central arena",RewardDescription="Greater Fire Core elite reward",Resources={"FireCore"},Weights={25,50,20,5},GroupMin=2,GroupMax=3,Mixed=0.2},
}}
C.Creatures["CrystalStalker"] = { Name = "Crystal Stalker", Role = "O", Behavior = "visible sidestep before attacking", Biome = "CrystalWastes" }
C.Creatures["PrismGuard"] = { Name = "Prism Guard", Role = "H", Behavior = "slow beam with an obvious tracking line", Biome = "CrystalWastes" }
C.Creatures["ShardMite"] = { Name = "Shard Mite", Role = "L", Behavior = "short hops and brittle close-range attacks", Biome = "CrystalWastes" }
C.Creatures["CrystalGrazer"] = { Name = "Crystal Grazer", Role = "N", Behavior = "moves between mineral outcrops and flees", Biome = "CrystalWastes" }
C.Biomes["CrystalWastes"] = { Id="CrystalWastes", DisplayName="Crystal Basin", UnlockTier=3, Material="Slate", Color=Color3.fromRGB(115, 105, 152), Landform="Crystal", Temp=-4, Creatures={"CrystalStalker","PrismGuard","ShardMite","CrystalGrazer"}, Regions={
{Id="CrystalWastesA",Name="Crystal Fields",Depth=1,Description="Low crystal fans and open stony ground",RewardDescription="Clear Crystal",Resources={"ClearCrystal","CrystalBasil"},Weights={20,5,35,40},GroupMin=1,GroupMax=2,Mixed=0.0},
{Id="CrystalWastesB",Name="Broken Stone Flats",Depth=2,Description="Split shelves, shallow ravines, obvious crossings",RewardDescription="Crystal Thread, common minerals",Resources={"CrystalThread","Stone"},Weights={35,15,25,25},GroupMin=1,GroupMax=2,Mixed=0.05},
{Id="CrystalWastesC",Name="Mirror Canyon",Depth=3,Description="Reflective walls and branching routes",RewardDescription="Dark Dust, beam-routing discoveries",Resources={"DarkDust"},Weights={45,25,20,10},GroupMin=2,GroupMax=3,Mixed=0.15},
{Id="CrystalWastesD",Name="Crystal Caves",Depth=4,Description="Large crystal chambers with resonating hazards",RewardDescription="Advanced enchantments and crystal caches",Resources={"ClearCrystal"},Weights={30,30,35,5},GroupMin=2,GroupMax=4,Mixed=0.2},
{Id="CrystalWastesE",Name="Shattered Spire",Depth=5,Description="Broken vertical tower with stable approach routes",RewardDescription="Crystal Heart elite reward",Resources={"DarkDust"},Weights={25,50,20,5},GroupMin=2,GroupMax=4,Mixed=0.2},
}}
C.Creatures["AuroraStag"] = { Name = "Aurora Stag", Role = "O", Behavior = "straight antler charge, territorial rather than long pursuit", Biome = "AuroraVale" }
C.Creatures["SnowOwl"] = { Name = "Snow Owl", Role = "L", Behavior = "low swoop with a reachable landing recovery", Biome = "AuroraVale" }
C.Creatures["SpringBear"] = { Name = "Spring Bear", Role = "H", Behavior = "guards warm pools, slow two-swipe attack", Biome = "AuroraVale" }
C.Creatures["ValleyHare"] = { Name = "Valley Hare", Role = "N", Behavior = "grazes sheltered warm patches", Biome = "AuroraVale" }
C.Biomes["AuroraVale"] = { Id="AuroraVale", DisplayName="Northern Valley", UnlockTier=4, Material="Snow", Color=Color3.fromRGB(106, 151, 157), Landform="Alpine", Temp=-12, Creatures={"AuroraStag","SnowOwl","SpringBear","ValleyHare"}, Regions={
{Id="AuroraValeA",Name="Frosted Meadows",Depth=1,Description="Light frost, colored sky, broad paths",RewardDescription="Glow Fiber",Resources={"GlowFiber","DawnFlower"},Weights={15,5,5,75},GroupMin=1,GroupMax=1,Mixed=0.0},
{Id="AuroraValeB",Name="Dawn Woods",Depth=2,Description="Glowing foliage and sheltered sunrise clearings",RewardDescription="Dawn Flower",Resources={"DawnFlower"},Weights={30,20,10,40},GroupMin=1,GroupMax=2,Mixed=0.05},
{Id="AuroraValeC",Name="Hot Spring Valley",Depth=3,Description="Warm pools separated by cold rock terraces",RewardDescription="Aurora Stone; thermal-management discoveries",Resources={"AuroraStone"},Weights={25,20,30,25},GroupMin=1,GroupMax=3,Mixed=0.1},
{Id="AuroraValeD",Name="Northern Cliffs",Depth=4,Description="High paths, warming shelters, strong wind",RewardDescription="Advanced cloth/enchantment caches",Resources={"GlowFiber"},Weights={25,40,25,10},GroupMin=1,GroupMax=2,Mixed=0.15},
{Id="AuroraValeE",Name="Aurora Ridge",Depth=5,Description="Aurora-lit summit and exposed arena",RewardDescription="Dawn Heart elite reward",Resources={"DawnFlower"},Weights={35,35,25,5},GroupMin=2,GroupMax=3,Mixed=0.2},
}}
C.Creatures["RockCrawler"] = { Name = "Rock Crawler", Role = "H", Behavior = "armored front and exposed rear", Biome = "StarfallCrater" }
C.Creatures["StarBeetle"] = { Name = "Star Beetle", Role = "O", Behavior = "arcing projectile with a visible landing marker", Biome = "StarfallCrater" }
C.Creatures["DustMite"] = { Name = "Dust Mite", Role = "L", Behavior = "short burrowing rush with a visible trail", Biome = "StarfallCrater" }
C.Creatures["CraterLizard"] = { Name = "Crater Lizard", Role = "N", Behavior = "ground scavenger sheltering beneath debris", Biome = "StarfallCrater" }
C.Biomes["StarfallCrater"] = { Id="StarfallCrater", DisplayName="Meteor Crater", UnlockTier=4, Material="Rock", Color=Color3.fromRGB(108, 105, 118), Landform="Crater", Temp=8, Creatures={"RockCrawler","StarBeetle","DustMite","CraterLizard"}, Regions={
{Id="StarfallCraterA",Name="Dust Plains",Depth=1,Description="Low dust ridges and scattered impact debris",RewardDescription="Impact Glass",Resources={"ImpactGlass","StarSeed"},Weights={10,20,30,40},GroupMin=1,GroupMax=1,Mixed=0.0},
{Id="StarfallCraterB",Name="Fallen Rock Fields",Depth=2,Description="Large embedded meteor fragments and sheltered gaps",RewardDescription="Meteor Ore",Resources={"MeteorOre"},Weights={30,20,25,25},GroupMin=1,GroupMax=2,Mixed=0.05},
{Id="StarfallCraterC",Name="Crater Lakes",Depth=3,Description="Nested crater basins, flooded rims, ruined instruments",RewardDescription="Star Core; Fallen Star entrance",Resources={"StarCore"},Weights={30,40,20,10},GroupMin=2,GroupMax=3,Mixed=0.15},
{Id="StarfallCraterD",Name="Meteor Tunnels",Depth=4,Description="Passages through shattered impact rock",RewardDescription="Advanced metal/enchantment deposits",Resources={"MeteorOre"},Weights={40,20,35,5},GroupMin=1,GroupMax=3,Mixed=0.2},
{Id="StarfallCraterE",Name="Impact Core",Depth=5,Description="Central impact chamber with falling-debris warnings",RewardDescription="Greater Star Core elite reward",Resources={"StarCore"},Weights={50,25,20,5},GroupMin=2,GroupMax=4,Mixed=0.2},
}}
C.Creatures["TideCrab"] = { Name = "Tide Crab", Role = "O", Behavior = "sideways approach with shell-front defense", Biome = "SaltglassCoast" }
C.Creatures["ReefEel"] = { Name = "Reef Eel", Role = "L", Behavior = "water-only rush preceded by a ripple", Biome = "SaltglassCoast" }
C.Creatures["Shellback"] = { Name = "Shellback", Role = "H", Behavior = "territorial turtle with a slow head thrust; short chase", Biome = "SaltglassCoast" }
C.Creatures["Sandpiper"] = { Name = "Sandpiper", Role = "N", Behavior = "beach-feeding bird that retreats from combat", Biome = "SaltglassCoast" }
C.Biomes["SaltglassCoast"] = { Id="SaltglassCoast", DisplayName="Coast", UnlockTier=2, Material="Sand", Color=Color3.fromRGB(172, 176, 129), Landform="Coast", Temp=3, Creatures={"TideCrab","ReefEel","Shellback","Sandpiper"}, Regions={
{Id="SaltglassCoastA",Name="Shell Beach",Depth=1,Description="Curved shore, dunes, driftwood",RewardDescription="Shell Plate, salt",Resources={"ShellPlate","Salt","Wood"},Weights={30,0,10,60},GroupMin=1,GroupMax=2,Mixed=0.0},
{Id="SaltglassCoastB",Name="Tide Pools",Depth=2,Description="Shallow pools, rock steps, kelp beds",RewardDescription="Kelp, coastal food",Resources={"Kelp"},Weights={35,30,15,20},GroupMin=1,GroupMax=3,Mixed=0.05},
{Id="SaltglassCoastC",Name="Sea Cliffs",Depth=3,Description="Sea-facing paths, arches, sheltered coves",RewardDescription="Waterproofing and traversal discoveries",Resources={"Salt"},Weights={35,5,30,30},GroupMin=1,GroupMax=2,Mixed=0.05},
{Id="SaltglassCoastD",Name="Shipwreck Cove",Depth=4,Description="Grounded ships, cargo holds, short diving routes",RewardDescription="Pearl, recovered parts",Resources={"Pearl","OldGear"},Weights={30,45,20,5},GroupMin=2,GroupMax=3,Mixed=0.15},
{Id="SaltglassCoastE",Name="Storm Reef",Depth=5,Description="Exposed reef islands with readable wave lanes",RewardDescription="Tide Heart elite reward",Resources={"ShellPlate"},Weights={35,35,25,5},GroupMin=2,GroupMax=4,Mixed=0.2},
}}
C.Creatures["GaleRaptor"] = { Name = "Gale Raptor", Role = "L", Behavior = "low jumping attack with grounded recovery", Biome = "StormspireHighlands" }
C.Creatures["ThunderRam"] = { Name = "Thunder Ram", Role = "H", Behavior = "committed charge at last aimed position", Biome = "StormspireHighlands" }
C.Creatures["CliffSpider"] = { Name = "Cliff Spider", Role = "O", Behavior = "short web shot across a path, then approaches", Biome = "StormspireHighlands" }
C.Creatures["MountainGoat"] = { Name = "Mountain Goat", Role = "N", Behavior = "climbs authored safe ledges and avoids danger", Biome = "StormspireHighlands" }
C.Biomes["StormspireHighlands"] = { Id="StormspireHighlands", DisplayName="Highlands", UnlockTier=4, Material="Grass", Color=Color3.fromRGB(130, 163, 146), Landform="Highlands", Temp=-12, Creatures={"GaleRaptor","ThunderRam","CliffSpider","MountainGoat"}, Regions={
{Id="StormspireHighlandsA",Name="Windy Hills",Depth=1,Description="Rounded hills and stone windbreaks",RewardDescription="Cloud Wool",Resources={"CloudWool"},Weights={20,10,10,60},GroupMin=1,GroupMax=1,Mixed=0.0},
{Id="StormspireHighlandsB",Name="Cloud Meadows",Depth=2,Description="Elevated plateaus with safe connecting passes",RewardDescription="Storm Ore",Resources={"StormOre"},Weights={20,20,15,45},GroupMin=1,GroupMax=2,Mixed=0.05},
{Id="StormspireHighlandsC",Name="Thunder Pass",Depth=3,Description="Sheltered gorge and charged outcrops",RewardDescription="Weather Tower entrance and storm discoveries",Resources={"StormOre"},Weights={35,35,20,10},GroupMin=1,GroupMax=3,Mixed=0.1},
{Id="StormspireHighlandsD",Name="Lightning Fields",Depth=4,Description="Telegraph-marked strike zones among grounding rocks",RewardDescription="Storm Core",Resources={"StormCore"},Weights={30,40,25,5},GroupMin=2,GroupMax=3,Mixed=0.15},
{Id="StormspireHighlandsE",Name="Storm Summit",Depth=5,Description="Tall central peak and sheltered approach",RewardDescription="Greater Storm Core elite reward",Resources={"StormCore"},Weights={40,40,15,5},GroupMin=2,GroupMax=3,Mixed=0.2},
}}
C.Creatures["SporeMite"] = { Name = "Spore Mite", Role = "S", Behavior = "weak short-range attacker in small swarms", Biome = "MyceliumHollow" }
C.Creatures["RootGuardian"] = { Name = "Root Guardian", Role = "H", Behavior = "stationary warning pulse and root strike", Biome = "MyceliumHollow" }
C.Creatures["CapBeetle"] = { Name = "Cap Beetle", Role = "O", Behavior = "slow shove followed by a visible spore puff", Biome = "MyceliumHollow" }
C.Creatures["MossSnail"] = { Name = "Moss Snail", Role = "N", Behavior = "slow grazer along damp ground", Biome = "MyceliumHollow" }
C.Biomes["MyceliumHollow"] = { Id="MyceliumHollow", DisplayName="Mushroom Forest", UnlockTier=3, Material="LeafyGrass", Color=Color3.fromRGB(101, 114, 127), Landform="Mushroom", Temp=3, Creatures={"SporeMite","RootGuardian","CapBeetle","MossSnail"}, Regions={
{Id="MyceliumHollowA",Name="Mushroom Fields",Depth=1,Description="Low caps, soft hills, edible patches",RewardDescription="Glow Mushroom",Resources={"GlowMushroom"},Weights={25,5,20,50},GroupMin=1,GroupMax=2,Mixed=0.0},
{Id="MyceliumHollowB",Name="Moss Woods",Depth=2,Description="Moss-coated trunks and damp hollows",RewardDescription="Thick Spores, herbs",Resources={"ThickSpores","HealingHerb"},Weights={35,10,25,30},GroupMin=2,GroupMax=3,Mixed=0.05},
{Id="MyceliumHollowC",Name="Giant Cap Forest",Depth=3,Description="Enormous caps and root-lined paths",RewardDescription="Living Root",Resources={"LivingRoot"},Weights={30,25,30,15},GroupMin=2,GroupMax=3,Mixed=0.15},
{Id="MyceliumHollowD",Name="Spore Caves",Depth=4,Description="Ventilated chambers with visible spore pulses",RewardDescription="Advanced medicine/enchantment supplies",Resources={"ThickSpores"},Weights={45,30,20,5},GroupMin=2,GroupMax=4,Mixed=0.15},
{Id="MyceliumHollowE",Name="Root Chamber",Depth=5,Description="Huge living root chamber",RewardDescription="Growth Heart elite reward",Resources={"LivingRoot"},Weights={30,45,20,5},GroupMin=3,GroupMax=5,Mixed=0.2},
}}
C.Creatures["Rustback"] = { Name = "Rustback", Role = "H", Behavior = "armored beast with vulnerable sides", Biome = "IronrootBadlands" }
C.Creatures["Burrower"] = { Name = "Burrower", Role = "O", Behavior = "tunnel trail and delayed emergence", Biome = "IronrootBadlands" }
C.Creatures["ThornJackal"] = { Name = "Thorn Jackal", Role = "L", Behavior = "circles once before a committed bite", Biome = "IronrootBadlands" }
C.Creatures["RockHare"] = { Name = "Rock Hare", Role = "N", Behavior = "small prey using rocky cover", Biome = "IronrootBadlands" }
C.Biomes["IronrootBadlands"] = { Id="IronrootBadlands", DisplayName="Badlands", UnlockTier=3, Material="CrackedLava", Color=Color3.fromRGB(151, 92, 70), Landform="Canyon", Temp=14, Creatures={"Rustback","Burrower","ThornJackal","RockHare"}, Regions={
{Id="IronrootBadlandsA",Name="Red Flats",Depth=1,Description="Cracked clay terraces and gullies",RewardDescription="Ironwood stands",Resources={"Ironwood","RootVegetable"},Weights={5,15,20,60},GroupMin=1,GroupMax=1,Mixed=0.0},
{Id="IronrootBadlandsB",Name="Thorn Scrub",Depth=2,Description="Tough low vegetation and stone shelter",RewardDescription="Red Ore, Tough Hide",Resources={"RedOre"},Weights={10,20,35,35},GroupMin=1,GroupMax=2,Mixed=0.05},
{Id="IronrootBadlandsC",Name="Ironwood Forest",Depth=3,Description="Dense heavy trunks and narrow sight lines",RewardDescription="Rich Ironwood and strength discoveries",Resources={"Ironwood"},Weights={30,20,40,10},GroupMin=1,GroupMax=3,Mixed=0.1},
{Id="IronrootBadlandsD",Name="Abandoned Mines",Depth=4,Description="Mine tracks and supported underground chambers",RewardDescription="Ironback entrance; advanced ore deposits",Resources={"RedOre"},Weights={30,50,15,5},GroupMin=2,GroupMax=3,Mixed=0.15},
{Id="IronrootBadlandsE",Name="Rust Fortress",Depth=5,Description="Layered ruined fortification and courtyard arena",RewardDescription="Iron Heart elite reward",Resources={"Ironwood"},Weights={50,25,20,5},GroupMin=2,GroupMax=4,Mixed=0.2},
}}
C.Creatures["BranchCat"] = { Name = "Branch Cat", Role = "O", Behavior = "stalks connected routes and leaps short gaps", Biome = "CanopySea" }
C.Creatures["GiantMoth"] = { Name = "Giant Moth", Role = "L", Behavior = "dust cone with a long recovery window", Biome = "CanopySea" }
C.Creatures["VineSnake"] = { Name = "Vine Snake", Role = "L", Behavior = "visible hanging posture before dropping onto a route", Biome = "CanopySea" }
C.Creatures["CanopyDeer"] = { Name = "Canopy Deer", Role = "N", Behavior = "moves along broad root platforms", Biome = "CanopySea" }
C.Biomes["CanopySea"] = { Id="CanopySea", DisplayName="Rainforest", UnlockTier=2, Material="Grass", Color=Color3.fromRGB(56, 112, 70), Landform="Canopy", Temp=8, Creatures={"BranchCat","GiantMoth","VineSnake","CanopyDeer"}, Regions={
{Id="CanopySeaA",Name="Forest Floor",Depth=1,Description="Large trunks, clear floor routes, fallen branches",RewardDescription="Common wood and fiber",Resources={"Wood","Fiber","Berries"},Weights={20,10,20,50},GroupMin=1,GroupMax=2,Mixed=0.0},
{Id="CanopySeaB",Name="Low Canopy",Depth=2,Description="Gradual root ramps and low platforms",RewardDescription="Strong Silk",Resources={"StrongSilk"},Weights={25,30,25,20},GroupMin=1,GroupMax=3,Mixed=0.05},
{Id="CanopySeaC",Name="Hanging Gardens",Depth=3,Description="Suspended vegetation and optional glide routes",RewardDescription="Lift Seed",Resources={"LiftSeed"},Weights={20,45,25,10},GroupMin=2,GroupMax=3,Mixed=0.1},
{Id="CanopySeaD",Name="Broken Bridges",Depth=4,Description="Connected branch platforms and repairable crossings",RewardDescription="Heartwood",Resources={"Heartwood"},Weights={30,25,40,5},GroupMin=2,GroupMax=3,Mixed=0.2},
{Id="CanopySeaE",Name="Crown Canopy",Depth=5,Description="High crowns above the cloud line",RewardDescription="Sky Heart elite reward",Resources={"Heartwood"},Weights={40,35,20,5},GroupMin=2,GroupMax=4,Mixed=0.2},
}}
C.Creatures["LanternEel"] = { Name = "Lantern Eel", Role = "L", Behavior = "water-only light lure and short rush", Biome = "SunkenArchive" }
C.Creatures["ArchiveGuard"] = { Name = "Archive Guard", Role = "H", Behavior = "slow patrol and visible pressure blast", Biome = "SunkenArchive" }
C.Creatures["CanalCrab"] = { Name = "Canal Crab", Role = "O", Behavior = "hides beside rubble and makes a short pincer attack", Biome = "SunkenArchive" }
C.Creatures["Silverfish"] = { Name = "Silverfish", Role = "N", Behavior = "small shoaling fish restricted to water", Biome = "SunkenArchive" }
C.Biomes["SunkenArchive"] = { Id="SunkenArchive", DisplayName="Flooded Ruins", UnlockTier=4, Material="Slate", Color=Color3.fromRGB(90, 124, 136), Landform="Ruins", Temp=0, Creatures={"LanternEel","ArchiveGuard","CanalCrab","Silverfish"}, Regions={
{Id="SunkenArchiveA",Name="Flooded Courtyard",Depth=1,Description="Raised walkways around shallow flooded plazas",RewardDescription="Old Gear",Resources={"OldGear"},Weights={10,10,25,55},GroupMin=1,GroupMax=2,Mixed=0.0},
{Id="SunkenArchiveB",Name="Canal District",Depth=2,Description="Canals, bridges, dry maintenance rooms",RewardDescription="Pressure Glass",Resources={"PressureGlass"},Weights={20,15,30,35},GroupMin=1,GroupMax=3,Mixed=0.05},
{Id="SunkenArchiveC",Name="Drowned Library",Depth=3,Description="Submerged shelves and frequent air pockets",RewardDescription="Survey/enchantment schematics",Resources={"OldGear"},Weights={30,25,25,20},GroupMin=1,GroupMax=3,Mixed=0.1},
{Id="SunkenArchiveD",Name="Sealed Vaults",Depth=4,Description="Pressure doors and bounded diving chambers",RewardDescription="Pearl; Deep Archive project entrance",Resources={"Pearl"},Weights={25,45,25,5},GroupMin=2,GroupMax=3,Mixed=0.15},
{Id="SunkenArchiveE",Name="Deep Archive",Depth=5,Description="Large underwater vault with permanent interior air rooms",RewardDescription="Archive Heart elite reward",Resources={"PressureGlass"},Weights={35,45,15,5},GroupMin=2,GroupMax=4,Mixed=0.2},
}}
C.Creatures["EchoHunter"] = { Name = "Echo Hunter", Role = "O", Behavior = "reacts to noise and telegraphs its rush", Biome = "UmbralDepths" }
C.Creatures["CaveGrazer"] = { Name = "Cave Grazer", Role = "N", Behavior = "neutral animal moving between light patches", Biome = "UmbralDepths" }
C.Creatures["CaveBat"] = { Name = "Cave Bat", Role = "L", Behavior = "low flight pass followed by a perch recovery", Biome = "UmbralDepths" }
C.Creatures["Stoneback"] = { Name = "Stoneback", Role = "H", Behavior = "slow armored lizard with exposed flanks", Biome = "UmbralDepths" }
C.Biomes["UmbralDepths"] = { Id="UmbralDepths", DisplayName="Caverns", UnlockTier=4, Material="Rock", Color=Color3.fromRGB(68, 77, 101), Landform="Cavern", Temp=-7, Creatures={"EchoHunter","CaveGrazer","CaveBat","Stoneback"}, Regions={
{Id="UmbralDepthsA",Name="Cave Mouths",Depth=1,Description="Large open entrances with natural light shafts",RewardDescription="Dark Moss",Resources={"DarkMoss"},Weights={10,65,20,5},GroupMin=1,GroupMax=2,Mixed=0.0},
{Id="UmbralDepthsB",Name="Glowmoss Caverns",Depth=2,Description="Broad lit chambers and clear routes",RewardDescription="Light Ore",Resources={"LightOre"},Weights={20,45,25,10},GroupMin=1,GroupMax=3,Mixed=0.05},
{Id="UmbralDepthsC",Name="Echo Tunnels",Depth=3,Description="Branching passages and sound-sensitive encounters",RewardDescription="Echo Shell",Resources={"EchoShell"},Weights={35,20,35,10},GroupMin=2,GroupMax=3,Mixed=0.15},
{Id="UmbralDepthsD",Name="Underground Lake",Depth=4,Description="Shore routes, boats as scenery, optional dive pockets",RewardDescription="Advanced light/enchantment caches",Resources={"LightOre"},Weights={25,20,20,35},GroupMin=1,GroupMax=2,Mixed=0.1},
{Id="UmbralDepthsE",Name="Lightless Chasm",Depth=5,Description="Deep ledges, persistent darkness, sheltered platforms",RewardDescription="Night Heart elite reward",Resources={"EchoShell"},Weights={40,5,30,25},GroupMin=2,GroupMax=4,Mixed=0.2},
}}
C.Creatures["MoonCrawler"] = { Name = "Moon Crawler", Role = "H", Behavior = "grounded pursuit and slow slam", Biome = "ShattermoonExpanse" }
C.Creatures["RiftHopper"] = { Name = "Rift Hopper", Role = "O", Behavior = "visible destination before short displacement", Biome = "ShattermoonExpanse" }
C.Creatures["MoonMite"] = { Name = "Moon Mite", Role = "L", Behavior = "short low-gravity hop with a long landing pause", Biome = "ShattermoonExpanse" }
C.Creatures["DustGrazer"] = { Name = "Dust Grazer", Role = "N", Behavior = "neutral ground animal browsing mineral dust", Biome = "ShattermoonExpanse" }
C.Biomes["ShattermoonExpanse"] = { Id="ShattermoonExpanse", DisplayName="Moon Surface", UnlockTier=4, Material="Limestone", Color=Color3.fromRGB(154, 151, 169), Landform="Moon", Temp=-10, Creatures={"MoonCrawler","RiftHopper","MoonMite","DustGrazer"}, Regions={
{Id="ShattermoonExpanseA",Name="Moon Flats",Depth=1,Description="Broad low craters and stable gravity",RewardDescription="Moon Rock",Resources={"MoonRock"},Weights={15,10,25,50},GroupMin=1,GroupMax=1,Mixed=0.0},
{Id="ShattermoonExpanseB",Name="Silver Ridges",Depth=2,Description="Low silvery ridges and sheltered cracks",RewardDescription="Moon Thread",Resources={"MoonThread"},Weights={20,25,25,30},GroupMin=1,GroupMax=2,Mixed=0.05},
{Id="ShattermoonExpanseC",Name="Floating Stone Fields",Depth=3,Description="Clearly bounded low-gravity pockets; ordinary bypasses",RewardDescription="Gravity/traversal discoveries",Resources={"MoonRock"},Weights={25,35,25,15},GroupMin=2,GroupMax=3,Mixed=0.15},
{Id="ShattermoonExpanseD",Name="Broken Observatory",Depth=4,Description="Damaged instruments and supported crater tunnels",RewardDescription="Moon Ore",Resources={"MoonOre"},Weights={40,30,25,5},GroupMin=1,GroupMax=3,Mixed=0.15},
{Id="ShattermoonExpanseE",Name="Gravity Well",Depth=5,Description="Floating rocks surrounding a stable arena",RewardDescription="Gravity Shard; Moon Warden entrance",Resources={"GravityShard"},Weights={40,40,15,5},GroupMin=2,GroupMax=4,Mixed=0.2},
}}
function C.EligibleRegions(biome, tier, visits)
 local result = {}
 for _, region in ipairs(C.Biomes[biome].Regions) do
  if region.Depth <= 2 or (tier >= ({[3]=4,[4]=6,[5]=8})[region.Depth] and visits >= region.Depth-2) then table.insert(result,region) end
 end
 return result
end
function C.PlanRegionTypes(biome,tier,visits,count,rng)
 local eligible=C.EligibleRegions(biome,tier,visits)
 local result=table.clone(eligible)
 -- Every unlocked resource-bearing region must exist on a visit. Weighted
 -- repeats add variety after coverage, rather than occasionally deleting Resin/ore regions.
 local weights={3,3,2,1.5,1}
 local total=0;for _,region in ipairs(eligible) do total+=weights[region.Depth] end
 while #result<math.max(count,#eligible) do
  local roll=rng:NextNumber()*total
  for _,region in ipairs(eligible) do
   roll-=weights[region.Depth]
   if roll<=0 then table.insert(result,region);break end
  end
 end
 return result
end
return C
