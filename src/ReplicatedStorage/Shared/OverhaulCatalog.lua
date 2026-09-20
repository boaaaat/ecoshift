-- Complete campaign content catalog. Retired-world content is intentionally absent.
-- Gameplay services and recipe UI consume the same item/grade/source definitions.
local C = {}
C.Items = {
 ["Wood"] = {["Id"]="Wood",["Name"]="Wood",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Raw","Wood"},["Description"]="Wood resource. Found in Common, region A."},
 ["Stone"] = {["Id"]="Stone",["Name"]="Stone",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Common, region A."},
 ["Fiber"] = {["Id"]="Fiber",["Name"]="Fiber",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Common, region A."},
 ["Resin"] = {["Id"]="Resin",["Name"]="Resin",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Raw","Wood"},["Description"]="Wood resource. Found in Common, region A."},
 ["HealingHerb"] = {["Id"]="HealingHerb",["Name"]="Healing Herb",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Common, region A."},
 ["Mushroom"] = {["Id"]="Mushroom",["Name"]="Mushroom",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Common, region A."},
 ["Water"] = {["Id"]="Water",["Name"]="Water",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Raw","Liquid"},["Description"]="Collected from rivers with a held Bucket or Water Flask; used for cooking and medicine."},
 ["DirtyWater"] = {["Id"]="DirtyWater",["Name"]="Dirty Water",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Raw","Liquid"},["Description"]="Unsafe water recovered from weather devices and old containers; filter before use."},
 ["Bucket"] = {["Id"]="Bucket",["Name"]="Wooden Bucket",["Grade"]=1,["Tier"]=1,["StackSize"]=1,["Tags"]={"Utility","Holdable","Container"},["Description"]="Hold beside a river and press F to collect up to three Water."},
 ["Coal"] = {["Id"]="Coal",["Name"]="Coal",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Common, region A."},
 ["RawMeat"] = {["Id"]="RawMeat",["Name"]="Raw Meat",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Raw","Animal"},["Description"]="Animal resource. Found in Common, region A."},
 ["Bone"] = {["Id"]="Bone",["Name"]="Bone",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Raw","Animal"},["Description"]="Animal resource. Found in Common, region A."},
 ["WarmFur"] = {["Id"]="WarmFur",["Name"]="Warm Fur",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Raw","Animal"},["Description"]="Animal resource. Found in Common, region A."},
 ["Berries"] = {["Id"]="Berries",["Name"]="Berries",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Common, region A."},
 ["RootVegetable"] = {["Id"]="RootVegetable",["Name"]="Root Vegetable",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Common, region A."},
 ["DeepResin"] = {["Id"]="DeepResin",["Name"]="Deep Resin",["Grade"]=5,["Tier"]=5,["StackSize"]=99,["Tags"]={"Resource","Raw","Wood"},["Description"]="Wood resource. Found in Woodlands, region C."},
 ["IronOre"] = {["Id"]="IronOre",["Name"]="Iron Ore",["Grade"]=2,["Tier"]=2,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Dunes, region A."},
 ["Sand"] = {["Id"]="Sand",["Name"]="Sand",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Dunes, region A."},
 ["Cactus"] = {["Id"]="Cactus",["Name"]="Cactus",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Raw","Wood"},["Description"]="Wood resource. Found in Dunes, region B."},
 ["Sunstone"] = {["Id"]="Sunstone",["Name"]="Sunstone",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Dunes, region C."},
 ["Reeds"] = {["Id"]="Reeds",["Name"]="Reeds",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Marsh, region A."},
 ["Peat"] = {["Id"]="Peat",["Name"]="Peat",["Grade"]=2,["Tier"]=2,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Marsh, region B."},
 ["Glowcap"] = {["Id"]="Glowcap",["Name"]="Glowcap",["Grade"]=2,["Tier"]=2,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Marsh, region B."},
 ["VenomGland"] = {["Id"]="VenomGland",["Name"]="Venom Gland",["Grade"]=2,["Tier"]=2,["StackSize"]=99,["Tags"]={"Resource","Raw","Animal"},["Description"]="Animal resource. Found in Marsh, region A."},
 ["IceCrystal"] = {["Id"]="IceCrystal",["Name"]="Ice Crystal",["Grade"]=2,["Tier"]=2,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Tundra, region B."},
 ["FrostBloom"] = {["Id"]="FrostBloom",["Name"]="Frost Bloom",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Tundra, region C."},
 ["BlackGlass"] = {["Id"]="BlackGlass",["Name"]="Black Glass",["Grade"]=3,["Tier"]=3,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Volcanic Plains, region B."},
 ["AshFiber"] = {["Id"]="AshFiber",["Name"]="Ash Fiber",["Grade"]=3,["Tier"]=3,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Volcanic Plains, region A."},
 ["Sulfur"] = {["Id"]="Sulfur",["Name"]="Sulfur",["Grade"]=3,["Tier"]=3,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Volcanic Plains, region B."},
 ["FireCore"] = {["Id"]="FireCore",["Name"]="Fire Core",["Grade"]=6,["Tier"]=6,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Volcanic Plains, region D."},
 ["ClearCrystal"] = {["Id"]="ClearCrystal",["Name"]="Clear Crystal",["Grade"]=3,["Tier"]=3,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Crystal Basin, region A."},
 ["CrystalThread"] = {["Id"]="CrystalThread",["Name"]="Crystal Thread",["Grade"]=3,["Tier"]=3,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Crystal Basin, region B."},
 ["DarkDust"] = {["Id"]="DarkDust",["Name"]="Dark Dust",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Crystal Basin, region C."},
 ["GlowFiber"] = {["Id"]="GlowFiber",["Name"]="Glow Fiber",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Northern Valley, region A."},
 ["DawnFlower"] = {["Id"]="DawnFlower",["Name"]="Dawn Flower",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Northern Valley, region B."},
 ["AuroraStone"] = {["Id"]="AuroraStone",["Name"]="Aurora Stone",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Northern Valley, region C."},
 ["ImpactGlass"] = {["Id"]="ImpactGlass",["Name"]="Impact Glass",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Meteor Crater, region A."},
 ["MeteorOre"] = {["Id"]="MeteorOre",["Name"]="Meteor Ore",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Meteor Crater, region B."},
 ["StarCore"] = {["Id"]="StarCore",["Name"]="Star Core",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Meteor Crater, region C."},
 ["ShellPlate"] = {["Id"]="ShellPlate",["Name"]="Shell Plate",["Grade"]=2,["Tier"]=2,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Coast, region A."},
 ["Salt"] = {["Id"]="Salt",["Name"]="Salt",["Grade"]=2,["Tier"]=2,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Coast, region A."},
 ["Kelp"] = {["Id"]="Kelp",["Name"]="Kelp",["Grade"]=2,["Tier"]=2,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Coast, region B."},
 ["Pearl"] = {["Id"]="Pearl",["Name"]="Pearl",["Grade"]=6,["Tier"]=6,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Coast, region D."},
 ["CloudWool"] = {["Id"]="CloudWool",["Name"]="Cloud Wool",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Highlands, region A."},
 ["StormOre"] = {["Id"]="StormOre",["Name"]="Storm Ore",["Grade"]=5,["Tier"]=5,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Highlands, region B."},
 ["StormCore"] = {["Id"]="StormCore",["Name"]="Storm Core",["Grade"]=6,["Tier"]=6,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Highlands, region D."},
 ["GlowMushroom"] = {["Id"]="GlowMushroom",["Name"]="Glow Mushroom",["Grade"]=3,["Tier"]=3,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Mushroom Forest, region A."},
 ["ThickSpores"] = {["Id"]="ThickSpores",["Name"]="Thick Spores",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Mushroom Forest, region B."},
 ["LivingRoot"] = {["Id"]="LivingRoot",["Name"]="Living Root",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Mushroom Forest, region C."},
 ["Ironwood"] = {["Id"]="Ironwood",["Name"]="Ironwood",["Grade"]=3,["Tier"]=3,["StackSize"]=99,["Tags"]={"Resource","Raw","Wood"},["Description"]="Wood resource. Found in Badlands, region A."},
 ["RedOre"] = {["Id"]="RedOre",["Name"]="Red Ore",["Grade"]=6,["Tier"]=6,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Badlands, region B."},
 ["ToughHide"] = {["Id"]="ToughHide",["Name"]="Tough Hide",["Grade"]=3,["Tier"]=3,["StackSize"]=99,["Tags"]={"Resource","Raw","Animal"},["Description"]="Animal resource. Found in Badlands, region A."},
 ["StrongSilk"] = {["Id"]="StrongSilk",["Name"]="Strong Silk",["Grade"]=2,["Tier"]=2,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Rainforest, region B."},
 ["LiftSeed"] = {["Id"]="LiftSeed",["Name"]="Lift Seed",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Rainforest, region C."},
 ["Heartwood"] = {["Id"]="Heartwood",["Name"]="Heartwood",["Grade"]=6,["Tier"]=6,["StackSize"]=99,["Tags"]={"Resource","Raw","Wood"},["Description"]="Wood resource. Found in Rainforest, region D."},
 ["OldGear"] = {["Id"]="OldGear",["Name"]="Old Gear",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Flooded Ruins, region A."},
 ["PressureGlass"] = {["Id"]="PressureGlass",["Name"]="Pressure Glass",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Flooded Ruins, region B."},
 ["DarkMoss"] = {["Id"]="DarkMoss",["Name"]="Dark Moss",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Caverns, region A."},
 ["LightOre"] = {["Id"]="LightOre",["Name"]="Light Ore",["Grade"]=7,["Tier"]=7,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Caverns, region B."},
 ["EchoShell"] = {["Id"]="EchoShell",["Name"]="Echo Shell",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Caverns, region C."},
 ["MoonRock"] = {["Id"]="MoonRock",["Name"]="Moon Rock",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Moon Surface, region A."},
 ["MoonThread"] = {["Id"]="MoonThread",["Name"]="Moon Thread",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Raw","Plant"},["Description"]="Plant resource. Found in Moon Surface, region B."},
 ["MoonOre"] = {["Id"]="MoonOre",["Name"]="Moon Ore",["Grade"]=8,["Tier"]=8,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Moon Surface, region D."},
 ["GravityShard"] = {["Id"]="GravityShard",["Name"]="Gravity Shard",["Grade"]=8,["Tier"]=8,["StackSize"]=99,["Tags"]={"Resource","Raw","Mineral"},["Description"]="Mineral resource. Found in Moon Surface, region E."},
 ["AncientSeed"] = {["Id"]="AncientSeed",["Name"]="Ancient Seed",["Grade"]=8,["Tier"]=8,["StackSize"]=30,["Tags"]={"Resource","Trophy"},["Description"]="Reward from a completed deep-region elite site. Used for awakening and signature enchantments."},
 ["SunHeart"] = {["Id"]="SunHeart",["Name"]="Sun Heart",["Grade"]=8,["Tier"]=8,["StackSize"]=30,["Tags"]={"Resource","Trophy"},["Description"]="Reward from a completed deep-region elite site. Used for awakening and signature enchantments."},
 ["MarshHeart"] = {["Id"]="MarshHeart",["Name"]="Marsh Heart",["Grade"]=8,["Tier"]=8,["StackSize"]=30,["Tags"]={"Resource","Trophy"},["Description"]="Reward from a completed deep-region elite site. Used for awakening and signature enchantments."},
 ["FrostHeart"] = {["Id"]="FrostHeart",["Name"]="Frost Heart",["Grade"]=8,["Tier"]=8,["StackSize"]=30,["Tags"]={"Resource","Trophy"},["Description"]="Reward from a completed deep-region elite site. Used for awakening and signature enchantments."},
 ["GreaterFireCore"] = {["Id"]="GreaterFireCore",["Name"]="Greater Fire Core",["Grade"]=8,["Tier"]=8,["StackSize"]=30,["Tags"]={"Resource","Trophy"},["Description"]="Reward from a completed deep-region elite site. Used for awakening and signature enchantments."},
 ["CrystalHeart"] = {["Id"]="CrystalHeart",["Name"]="Crystal Heart",["Grade"]=8,["Tier"]=8,["StackSize"]=30,["Tags"]={"Resource","Trophy"},["Description"]="Reward from a completed deep-region elite site. Used for awakening and signature enchantments."},
 ["DawnHeart"] = {["Id"]="DawnHeart",["Name"]="Dawn Heart",["Grade"]=8,["Tier"]=8,["StackSize"]=30,["Tags"]={"Resource","Trophy"},["Description"]="Reward from a completed deep-region elite site. Used for awakening and signature enchantments."},
 ["GreaterStarCore"] = {["Id"]="GreaterStarCore",["Name"]="Greater Star Core",["Grade"]=8,["Tier"]=8,["StackSize"]=30,["Tags"]={"Resource","Trophy"},["Description"]="Reward from a completed deep-region elite site. Used for awakening and signature enchantments."},
 ["TideHeart"] = {["Id"]="TideHeart",["Name"]="Tide Heart",["Grade"]=8,["Tier"]=8,["StackSize"]=30,["Tags"]={"Resource","Trophy"},["Description"]="Reward from a completed deep-region elite site. Used for awakening and signature enchantments."},
 ["GreaterStormCore"] = {["Id"]="GreaterStormCore",["Name"]="Greater Storm Core",["Grade"]=8,["Tier"]=8,["StackSize"]=30,["Tags"]={"Resource","Trophy"},["Description"]="Reward from a completed deep-region elite site. Used for awakening and signature enchantments."},
 ["GrowthHeart"] = {["Id"]="GrowthHeart",["Name"]="Growth Heart",["Grade"]=8,["Tier"]=8,["StackSize"]=30,["Tags"]={"Resource","Trophy"},["Description"]="Reward from a completed deep-region elite site. Used for awakening and signature enchantments."},
 ["IronHeart"] = {["Id"]="IronHeart",["Name"]="Iron Heart",["Grade"]=8,["Tier"]=8,["StackSize"]=30,["Tags"]={"Resource","Trophy"},["Description"]="Reward from a completed deep-region elite site. Used for awakening and signature enchantments."},
 ["SkyHeart"] = {["Id"]="SkyHeart",["Name"]="Sky Heart",["Grade"]=8,["Tier"]=8,["StackSize"]=30,["Tags"]={"Resource","Trophy"},["Description"]="Reward from a completed deep-region elite site. Used for awakening and signature enchantments."},
 ["ArchiveHeart"] = {["Id"]="ArchiveHeart",["Name"]="Archive Heart",["Grade"]=8,["Tier"]=8,["StackSize"]=30,["Tags"]={"Resource","Trophy"},["Description"]="Reward from a completed deep-region elite site. Used for awakening and signature enchantments."},
 ["NightHeart"] = {["Id"]="NightHeart",["Name"]="Night Heart",["Grade"]=8,["Tier"]=8,["StackSize"]=30,["Tags"]={"Resource","Trophy"},["Description"]="Reward from a completed deep-region elite site. Used for awakening and signature enchantments."},
 ["Plank"] = {["Id"]="Plank",["Name"]="Plank",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["Cloth"] = {["Id"]="Cloth",["Name"]="Cloth",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["Cord"] = {["Id"]="Cord",["Name"]="Cord",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["IronBar"] = {["Id"]="IronBar",["Name"]="Iron Bar",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["Glass"] = {["Id"]="Glass",["Name"]="Glass",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["HerbalPaste"] = {["Id"]="HerbalPaste",["Name"]="Herbal Paste",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["PlantOil"] = {["Id"]="PlantOil",["Name"]="Plant Oil",["Grade"]=3,["Tier"]=3,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["Gears"] = {["Id"]="Gears",["Name"]="Gears",["Grade"]=2,["Tier"]=2,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["EnchantingDust"] = {["Id"]="EnchantingDust",["Name"]="Enchanting Dust",["Grade"]=3,["Tier"]=3,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["SteelBar"] = {["Id"]="SteelBar",["Name"]="Steel Bar",["Grade"]=2,["Tier"]=2,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["BlacksteelBar"] = {["Id"]="BlacksteelBar",["Name"]="Blacksteel Bar",["Grade"]=3,["Tier"]=3,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["MeteorBar"] = {["Id"]="MeteorBar",["Name"]="Meteor Bar",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["StormBar"] = {["Id"]="StormBar",["Name"]="Storm Bar",["Grade"]=5,["Tier"]=5,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["ReinforcedBar"] = {["Id"]="ReinforcedBar",["Name"]="Reinforced Bar",["Grade"]=6,["Tier"]=6,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["DeepMetal"] = {["Id"]="DeepMetal",["Name"]="Deep Metal",["Grade"]=7,["Tier"]=7,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["MoonBar"] = {["Id"]="MoonBar",["Name"]="Moon Bar",["Grade"]=8,["Tier"]=8,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["WarmCloth"] = {["Id"]="WarmCloth",["Name"]="Warm Cloth",["Grade"]=2,["Tier"]=2,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["FireCloth"] = {["Id"]="FireCloth",["Name"]="Fire Cloth",["Grade"]=3,["Tier"]=3,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["GlowCloth"] = {["Id"]="GlowCloth",["Name"]="Glow Cloth",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["StormCloth"] = {["Id"]="StormCloth",["Name"]="Storm Cloth",["Grade"]=5,["Tier"]=5,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["ToughCloth"] = {["Id"]="ToughCloth",["Name"]="Tough Cloth",["Grade"]=6,["Tier"]=6,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["SailCloth"] = {["Id"]="SailCloth",["Name"]="Sail Cloth",["Grade"]=7,["Tier"]=7,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["NightCloth"] = {["Id"]="NightCloth",["Name"]="Night Cloth",["Grade"]=8,["Tier"]=8,["StackSize"]=99,["Tags"]={"Resource","Processed"},["Description"]=""},
 ["Arrow"] = {["Id"]="Arrow",["Name"]="Arrow",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Ammunition"},["Description"]=""},
 ["Workbench"] = {["Id"]="Workbench",["Name"]="Workbench",["Grade"]=1,["Tier"]=1,["StackSize"]=1,["Tags"]={"Placeable","Station","Holdable"},["Description"]="Tools, utility, structural items, assembly; inherits hand recipes"},
 ["Campfire"] = {["Id"]="Campfire",["Name"]="Campfire",["Grade"]=1,["Tier"]=1,["StackSize"]=1,["Tags"]={"Placeable","Station","Holdable"},["Description"]="Simple roasting and actual warmth"},
 ["Furnace"] = {["Id"]="Furnace",["Name"]="Furnace",["Grade"]=1,["Tier"]=1,["StackSize"]=1,["Tags"]={"Placeable","Station","Holdable"},["Description"]="Ore, glass, and higher-grade metal batches"},
 ["Loom"] = {["Id"]="Loom",["Name"]="Loom",["Grade"]=1,["Tier"]=1,["StackSize"]=1,["Tags"]={"Placeable","Station","Holdable"},["Description"]="Cloth, wearable pieces, packs, patches"},
 ["Stove"] = {["Id"]="Stove",["Name"]="Stove",["Grade"]=2,["Tier"]=2,["StackSize"]=1,["Tags"]={"Placeable","Station","Holdable"},["Description"]="Soups, drinks, rations, and mixed meals"},
 ["Oven"] = {["Id"]="Oven",["Name"]="Oven",["Grade"]=3,["Tier"]=3,["StackSize"]=1,["Tags"]={"Placeable","Station","Holdable"},["Description"]="Baked meals, dried food, and later expedition meals"},
 ["Anvil"] = {["Id"]="Anvil",["Name"]="Anvil",["Grade"]=2,["Tier"]=2,["StackSize"]=1,["Tags"]={"Placeable","Station","Holdable"},["Description"]="Metal equipment, full weapon/tool repairs"},
 ["MedicineTable"] = {["Id"]="MedicineTable",["Name"]="Medicine Table",["Grade"]=2,["Tier"]=2,["StackSize"]=1,["Tags"]={"Placeable","Station","Holdable"},["Description"]="Advanced medical items and brewing"},
 ["SurveyDesk"] = {["Id"]="SurveyDesk",["Name"]="Survey Desk",["Grade"]=2,["Tier"]=2,["StackSize"]=1,["Tags"]={"Placeable","Station","Holdable"},["Description"]="Instruments, maps, and world-control devices"},
 ["EnchantingTable"] = {["Id"]="EnchantingTable",["Name"]="Enchanting Table",["Grade"]=3,["Tier"]=3,["StackSize"]=1,["Tags"]={"Placeable","Station","Holdable"},["Description"]="Apply, upgrade, extract, and transfer enchantments"},
 ["RepairBench"] = {["Id"]="RepairBench",["Name"]="Repair Bench",["Grade"]=4,["Tier"]=4,["StackSize"]=1,["Tags"]={"Placeable","Station","Holdable"},["Description"]="Crew repair queue and consolidated gear-maintenance page; uses normal Anvil/Loom repair costs"},
 ["Floor"] = {["Id"]="Floor",["Name"]="Floor",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Placeable","Holdable","Structure"},["Description"]="8×8 stud foundation panel"},
 ["Wall"] = {["Id"]="Wall",["Name"]="Wall",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Placeable","Holdable","Structure"},["Description"]="8 studs wide, 8 tall; blocks ordinary physical movement"},
 ["Roof"] = {["Id"]="Roof",["Name"]="Roof",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Placeable","Holdable","Structure"},["Description"]="8×8 panel; contributes shade/rain shelter"},
 ["Ramp"] = {["Id"]="Ramp",["Name"]="Ramp",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Placeable","Holdable","Structure"},["Description"]="8×8 run/rise connection"},
 ["Door"] = {["Id"]="Door",["Name"]="Door",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Placeable","Holdable","Structure"},["Description"]="Player-operated 4-stud opening; F/touch toggle"},
 ["Gate"] = {["Id"]="Gate",["Name"]="Gate",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Placeable","Holdable","Structure"},["Description"]="Player-operated 8-stud opening"},
 ["Stairs"] = {["Id"]="Stairs",["Name"]="Stairs",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Placeable","Holdable","Structure"},["Description"]="8-stud story connection"},
 ["Ladder"] = {["Id"]="Ladder",["Name"]="Ladder",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Placeable","Holdable","Structure"},["Description"]="8-stud vertical connection"},
 ["Watchtower"] = {["Id"]="Watchtower",["Name"]="Watchtower",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Placeable","Holdable","Structure"},["Description"]="8×8, approximately 16 high, accessible ladder"},
 ["Chest"] = {["Id"]="Chest",["Name"]="Chest",["Grade"]=1,["Tier"]=1,["StackSize"]=1,["Tags"]={"Placeable","Holdable","Structure"},["Description"]="24 shared item slots"},
 ["LargeChest"] = {["Id"]="LargeChest",["Name"]="Large Chest",["Grade"]=4,["Tier"]=4,["StackSize"]=1,["Tags"]={"Placeable","Holdable","Structure"},["Description"]="48 shared slots"},
 ["Torch"] = {["Id"]="Torch",["Name"]="Torch",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Placeable","Holdable","Structure"},["Description"]="Placeable light; no heat protection"},
 ["StandingLamp"] = {["Id"]="StandingLamp",["Name"]="Standing Lamp",["Grade"]=3,["Tier"]=3,["StackSize"]=99,["Tags"]={"Placeable","Holdable","Structure"},["Description"]="Larger camp light, no ongoing fuel"},
 ["RainCollector"] = {["Id"]="RainCollector",["Name"]="Rain Collector",["Grade"]=2,["Tier"]=2,["StackSize"]=99,["Tags"]={"Placeable","Holdable","Structure"},["Description"]="Produces one Water/minute during rain, stores up to 10; no offline production"},
 ["WaterFilter"] = {["Id"]="WaterFilter",["Name"]="Water Filter",["Grade"]=4,["Tier"]=4,["StackSize"]=99,["Tags"]={"Placeable","Holdable","Structure"},["Description"]="Dirty Water ×1 becomes Water ×1 in 10s; consumes one Coal per 10 batches"},
 ["Bedroll"] = {["Id"]="Bedroll",["Name"]="Bedroll",["Grade"]=2,["Tier"]=2,["StackSize"]=99,["Tags"]={"Placeable","Holdable","Structure"},["Description"]="Stationary recovery: +1 stamina/s and +0.2 exposure recovery/s; no passive HP or respawn"},
 ["SpikeTrap"] = {["Id"]="SpikeTrap",["Name"]="Spike Trap",["Grade"]=2,["Tier"]=2,["StackSize"]=99,["Tags"]={"Placeable","Holdable","Structure"},["Description"]="Upgradeable grade; deals 0.8D to one monster crossing it, 3s reset; consumes 1 Bone per 10 triggers"},
 ["CampMarker"] = {["Id"]="CampMarker",["Name"]="Camp Marker",["Grade"]=1,["Tier"]=1,["StackSize"]=99,["Tags"]={"Placeable","Holdable","Structure"},["Description"]="Visible named crew map marker"},
 ["Bandage"] = {["Id"]="Bandage",["Name"]="Bandage",["Grade"]=1,["Tier"]=1,["StackSize"]=30,["Tags"]={"Consumable","Medicine"},["Description"]=""},
 ["HealingWrap"] = {["Id"]="HealingWrap",["Name"]="Healing Wrap",["Grade"]=2,["Tier"]=2,["StackSize"]=30,["Tags"]={"Consumable","Medicine"},["Description"]=""},
 ["FirstAidKit"] = {["Id"]="FirstAidKit",["Name"]="First Aid Kit",["Grade"]=6,["Tier"]=6,["StackSize"]=30,["Tags"]={"Consumable","Medicine"},["Description"]=""},
 ["RevivalKit"] = {["Id"]="RevivalKit",["Name"]="Revival Kit",["Grade"]=1,["Tier"]=1,["StackSize"]=30,["Tags"]={"Consumable","Medicine"},["Description"]=""},
 ["Antidote"] = {["Id"]="Antidote",["Name"]="Antidote",["Grade"]=2,["Tier"]=2,["StackSize"]=30,["Tags"]={"Consumable","Medicine"},["Description"]=""},
 ["DryingSalve"] = {["Id"]="DryingSalve",["Name"]="Drying Salve",["Grade"]=3,["Tier"]=3,["StackSize"]=30,["Tags"]={"Consumable","Medicine"},["Description"]=""},
 ["RecoveryTonic"] = {["Id"]="RecoveryTonic",["Name"]="Recovery Tonic",["Grade"]=4,["Tier"]=4,["StackSize"]=30,["Tags"]={"Consumable","Medicine"},["Description"]=""},
 ["FieldRepairKit"] = {["Id"]="FieldRepairKit",["Name"]="Field Repair Kit",["Grade"]=1,["Tier"]=1,["StackSize"]=20,["Tags"]={"Consumable","Repair"},["Description"]=""},
 ["ArmorPatch"] = {["Id"]="ArmorPatch",["Name"]="Armor Patch",["Grade"]=1,["Tier"]=1,["StackSize"]=20,["Tags"]={"Consumable","Repair"},["Description"]=""},
 ["FieldRepairKit2"] = {["Id"]="FieldRepairKit2",["Name"]="Field Repair Kit Grade 2",["Grade"]=2,["Tier"]=2,["StackSize"]=20,["Tags"]={"Consumable","Repair"},["Description"]=""},
 ["ArmorPatch2"] = {["Id"]="ArmorPatch2",["Name"]="Armor Patch Grade 2",["Grade"]=2,["Tier"]=2,["StackSize"]=20,["Tags"]={"Consumable","Repair"},["Description"]=""},
 ["FieldRepairKit3"] = {["Id"]="FieldRepairKit3",["Name"]="Field Repair Kit Grade 3",["Grade"]=3,["Tier"]=3,["StackSize"]=20,["Tags"]={"Consumable","Repair"},["Description"]=""},
 ["ArmorPatch3"] = {["Id"]="ArmorPatch3",["Name"]="Armor Patch Grade 3",["Grade"]=3,["Tier"]=3,["StackSize"]=20,["Tags"]={"Consumable","Repair"},["Description"]=""},
 ["FieldRepairKit4"] = {["Id"]="FieldRepairKit4",["Name"]="Field Repair Kit Grade 4",["Grade"]=4,["Tier"]=4,["StackSize"]=20,["Tags"]={"Consumable","Repair"},["Description"]=""},
 ["ArmorPatch4"] = {["Id"]="ArmorPatch4",["Name"]="Armor Patch Grade 4",["Grade"]=4,["Tier"]=4,["StackSize"]=20,["Tags"]={"Consumable","Repair"},["Description"]=""},
 ["FieldRepairKit5"] = {["Id"]="FieldRepairKit5",["Name"]="Field Repair Kit Grade 5",["Grade"]=5,["Tier"]=5,["StackSize"]=20,["Tags"]={"Consumable","Repair"},["Description"]=""},
 ["ArmorPatch5"] = {["Id"]="ArmorPatch5",["Name"]="Armor Patch Grade 5",["Grade"]=5,["Tier"]=5,["StackSize"]=20,["Tags"]={"Consumable","Repair"},["Description"]=""},
 ["FieldRepairKit6"] = {["Id"]="FieldRepairKit6",["Name"]="Field Repair Kit Grade 6",["Grade"]=6,["Tier"]=6,["StackSize"]=20,["Tags"]={"Consumable","Repair"},["Description"]=""},
 ["ArmorPatch6"] = {["Id"]="ArmorPatch6",["Name"]="Armor Patch Grade 6",["Grade"]=6,["Tier"]=6,["StackSize"]=20,["Tags"]={"Consumable","Repair"},["Description"]=""},
 ["FieldRepairKit7"] = {["Id"]="FieldRepairKit7",["Name"]="Field Repair Kit Grade 7",["Grade"]=7,["Tier"]=7,["StackSize"]=20,["Tags"]={"Consumable","Repair"},["Description"]=""},
 ["ArmorPatch7"] = {["Id"]="ArmorPatch7",["Name"]="Armor Patch Grade 7",["Grade"]=7,["Tier"]=7,["StackSize"]=20,["Tags"]={"Consumable","Repair"},["Description"]=""},
 ["FieldRepairKit8"] = {["Id"]="FieldRepairKit8",["Name"]="Field Repair Kit Grade 8",["Grade"]=8,["Tier"]=8,["StackSize"]=20,["Tags"]={"Consumable","Repair"},["Description"]=""},
 ["ArmorPatch8"] = {["Id"]="ArmorPatch8",["Name"]="Armor Patch Grade 8",["Grade"]=8,["Tier"]=8,["StackSize"]=20,["Tags"]={"Consumable","Repair"},["Description"]=""},
 ["FieldClock"] = {["Id"]="FieldClock",["Name"]="Field Clock",["Grade"]=1,["Tier"]=1,["StackSize"]=1,["Tags"]={"Utility","Intel"},["Description"]="Reveals current shift countdown"},
 ["ThreatGauge"] = {["Id"]="ThreatGauge",["Name"]="Threat Gauge",["Grade"]=2,["Tier"]=2,["StackSize"]=1,["Tags"]={"Utility","Intel"},["Description"]="Shows campaign tier, bounded pressure, and nearby region danger"},
 ["ResourceCompass"] = {["Id"]="ResourceCompass",["Name"]="Resource Compass",["Grade"]=3,["Tier"]=3,["StackSize"]=1,["Tags"]={"Utility","Intel"},["Description"]="Select a known resource and point toward nearest discovered matching site within 300 studs; no unexplored map reveal"},
 ["WeatherScanner"] = {["Id"]="WeatherScanner",["Name"]="Weather Scanner",["Grade"]=3,["Tier"]=3,["StackSize"]=1,["Tags"]={"Utility","Intel"},["Description"]="Shows current region's measured hazards, recovery sources, and preparation advice; does not forecast the next biome"},
 ["BiomePredictor"] = {["Id"]="BiomePredictor",["Name"]="Biome Predictor",["Grade"]=4,["Tier"]=4,["StackSize"]=1,["Tags"]={"Utility","Intel"},["Description"]="Shows next main biome and current shift countdown"},
 ["WeatherPredictor"] = {["Id"]="WeatherPredictor",["Name"]="Weather Predictor",["Grade"]=4,["Tier"]=4,["StackSize"]=1,["Tags"]={"Utility","Intel"},["Description"]="Adds next visit's base weather; keeps clock/biome information"},
 ["EventDetector"] = {["Id"]="EventDetector",["Name"]="Event Detector",["Grade"]=5,["Tier"]=5,["StackSize"]=1,["Tags"]={"Utility","Intel"},["Description"]="Warns of a scheduled major surface event 45s before start and marks its discovered origin"},
 ["TrailBeacon"] = {["Id"]="TrailBeacon",["Name"]="Trail Beacon",["Grade"]=3,["Tier"]=3,["StackSize"]=1,["Tags"]={"Utility","Intel","Placeable","Holdable"},["Description"]="Placeable temporary named return marker outside camp; 15-minute lifetime; no teleport"},
 ["FieldJournal"] = {["Id"]="FieldJournal",["Name"]="Field Journal",["Grade"]=5,["Tier"]=5,["StackSize"]=1,["Tags"]={"Utility","Intel"},["Description"]="Combines owned Clock/Gauge/Compass/Scanner/forecast functions into one carried item; event module can be inserted later"},
 ["ShiftStabilizer"] = {["Id"]="ShiftStabilizer",["Name"]="Shift Stabilizer",["Grade"]=2,["Tier"]=2,["StackSize"]=1,["Tags"]={"Utility","WorldControl"},["Description"]="Reusable majority-voted world control. Requires visible fuel and eligibility."},
 ["ShiftTrigger"] = {["Id"]="ShiftTrigger",["Name"]="Shift Trigger",["Grade"]=2,["Tier"]=2,["StackSize"]=1,["Tags"]={"Utility","WorldControl"},["Description"]="Reusable majority-voted world control. Requires visible fuel and eligibility."},
 ["WorldDial"] = {["Id"]="WorldDial",["Name"]="World Dial",["Grade"]=4,["Tier"]=4,["StackSize"]=1,["Tags"]={"Utility","WorldControl"},["Description"]="Reusable majority-voted world control. Requires visible fuel and eligibility."},
 ["WorldAnchor"] = {["Id"]="WorldAnchor",["Name"]="World Anchor",["Grade"]=8,["Tier"]=8,["StackSize"]=1,["Tags"]={"Utility","WorldControl"},["Description"]="Reusable majority-voted world control. Requires visible fuel and eligibility."},
 ["AnyTrophy"] = {["Id"]="AnyTrophy",["Name"]="Any Trophy",["Grade"]=8,["Tier"]=8,["StackSize"]=99,["Tags"]={"RecipeRequirement"},["Description"]="Choose one deep-region trophy; the station lists eligible items."},
 ["DifferentTrophies"] = {["Id"]="DifferentTrophies",["Name"]="Different Trophies",["Grade"]=8,["Tier"]=8,["StackSize"]=99,["Tags"]={"RecipeRequirement"},["Description"]="Choose four different deep-region trophies; duplicates do not count."},
}
C.Recipes = {
 ["Plank"] = {["Id"]="Plank",["Ingredients"]={{["Id"]="Wood",["N"]=2}},["Output"]={["Id"]="Plank",["N"]=4},["AllowedStations"]={"Workbench"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1,["FuelWorkSeconds"]=0},
 ["Cloth"] = {["Id"]="Cloth",["Ingredients"]={{["Id"]="Fiber",["N"]=3}},["Output"]={["Id"]="Cloth",["N"]=2},["AllowedStations"]={"Hand","Loom"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1,["FuelWorkSeconds"]=0},
 ["Cord"] = {["Id"]="Cord",["Ingredients"]={{["Id"]="Fiber",["N"]=2}},["Output"]={["Id"]="Cord",["N"]=2},["AllowedStations"]={"Hand","Loom"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1,["FuelWorkSeconds"]=0},
 ["IronBar"] = {["Id"]="IronBar",["Ingredients"]={{["Id"]="IronOre",["N"]=3}},["Output"]={["Id"]="IronBar",["N"]=2},["AllowedStations"]={"Furnace"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1,["FuelWorkSeconds"]=6},
 ["Glass"] = {["Id"]="Glass",["Ingredients"]={{["Id"]="Sand",["N"]=3}},["Output"]={["Id"]="Glass",["N"]=2},["AllowedStations"]={"Furnace"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1,["FuelWorkSeconds"]=6},
 ["HerbalPaste"] = {["Id"]="HerbalPaste",["Ingredients"]={{["Id"]="HealingHerb",["N"]=2},{["Id"]="Mushroom",["N"]=1}},["Output"]={["Id"]="HerbalPaste",["N"]=2},["AllowedStations"]={"Hand","MedicineTable"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1,["FuelWorkSeconds"]=0},
 ["PlantOil"] = {["Id"]="PlantOil",["Ingredients"]={{["Id"]="GlowMushroom",["N"]=2},{["Id"]="Resin",["N"]=1}},["Output"]={["Id"]="PlantOil",["N"]=2},["AllowedStations"]={"MedicineTable"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=3,["CampaignTier"]=3,["FuelWorkSeconds"]=0},
 ["Gears"] = {["Id"]="Gears",["Ingredients"]={{["Id"]="SteelBar",["N"]=2},{["Id"]="Resin",["N"]=1}},["Output"]={["Id"]="Gears",["N"]=2},["AllowedStations"]={"Anvil"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=2,["CampaignTier"]=2,["FuelWorkSeconds"]=0},
 ["EnchantingDust"] = {["Id"]="EnchantingDust",["Ingredients"]={{["Id"]="ClearCrystal",["N"]=2},{["Id"]="DarkDust",["N"]=1}},["Output"]={["Id"]="EnchantingDust",["N"]=4},["AllowedStations"]={"EnchantingTable"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=3,["CampaignTier"]=3,["FuelWorkSeconds"]=0},
 ["SteelBar"] = {["Id"]="SteelBar",["Ingredients"]={{["Id"]="IronBar",["N"]=2},{["Id"]="Coal",["N"]=1}},["Output"]={["Id"]="SteelBar",["N"]=2},["AllowedStations"]={"Furnace"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=2,["CampaignTier"]=2,["FuelWorkSeconds"]=6},
 ["BlacksteelBar"] = {["Id"]="BlacksteelBar",["Ingredients"]={{["Id"]="SteelBar",["N"]=2},{["Id"]="BlackGlass",["N"]=2},{["Id"]="ClearCrystal",["N"]=1}},["Output"]={["Id"]="BlacksteelBar",["N"]=2},["AllowedStations"]={"Furnace"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=3,["CampaignTier"]=3,["FuelWorkSeconds"]=6},
 ["MeteorBar"] = {["Id"]="MeteorBar",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=2},{["Id"]="MeteorOre",["N"]=3},{["Id"]="IceCrystal",["N"]=1}},["Output"]={["Id"]="MeteorBar",["N"]=2},["AllowedStations"]={"Furnace"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=4,["CampaignTier"]=4,["FuelWorkSeconds"]=6},
 ["StormBar"] = {["Id"]="StormBar",["Ingredients"]={{["Id"]="MeteorBar",["N"]=2},{["Id"]="StormOre",["N"]=3},{["Id"]="DeepResin",["N"]=1}},["Output"]={["Id"]="StormBar",["N"]=2},["AllowedStations"]={"Furnace"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=5,["CampaignTier"]=5,["FuelWorkSeconds"]=6},
 ["ReinforcedBar"] = {["Id"]="ReinforcedBar",["Ingredients"]={{["Id"]="StormBar",["N"]=2},{["Id"]="RedOre",["N"]=3},{["Id"]="LivingRoot",["N"]=1}},["Output"]={["Id"]="ReinforcedBar",["N"]=2},["AllowedStations"]={"Furnace"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=6,["CampaignTier"]=6,["FuelWorkSeconds"]=6},
 ["DeepMetal"] = {["Id"]="DeepMetal",["Ingredients"]={{["Id"]="ReinforcedBar",["N"]=2},{["Id"]="LightOre",["N"]=3},{["Id"]="Pearl",["N"]=1}},["Output"]={["Id"]="DeepMetal",["N"]=2},["AllowedStations"]={"Furnace"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=7,["CampaignTier"]=7,["FuelWorkSeconds"]=6},
 ["MoonBar"] = {["Id"]="MoonBar",["Ingredients"]={{["Id"]="DeepMetal",["N"]=8},{["Id"]="MoonOre",["N"]=12},{["Id"]="GravityShard",["N"]=1}},["Output"]={["Id"]="MoonBar",["N"]=8},["AllowedStations"]={"Furnace"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=8,["CampaignTier"]=8,["FuelWorkSeconds"]=6},
 ["WarmCloth"] = {["Id"]="WarmCloth",["Ingredients"]={{["Id"]="Cloth",["N"]=2},{["Id"]="Reeds",["N"]=2},{["Id"]="WarmFur",["N"]=2}},["Output"]={["Id"]="WarmCloth",["N"]=2},["AllowedStations"]={"Loom"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=2,["CampaignTier"]=2,["FuelWorkSeconds"]=0},
 ["FireCloth"] = {["Id"]="FireCloth",["Ingredients"]={{["Id"]="WarmCloth",["N"]=2},{["Id"]="AshFiber",["N"]=3},{["Id"]="Resin",["N"]=1}},["Output"]={["Id"]="FireCloth",["N"]=2},["AllowedStations"]={"Loom"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=3,["CampaignTier"]=3,["FuelWorkSeconds"]=0},
 ["GlowCloth"] = {["Id"]="GlowCloth",["Ingredients"]={{["Id"]="FireCloth",["N"]=2},{["Id"]="GlowFiber",["N"]=3},{["Id"]="ClearCrystal",["N"]=1}},["Output"]={["Id"]="GlowCloth",["N"]=2},["AllowedStations"]={"Loom"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=4,["CampaignTier"]=4,["FuelWorkSeconds"]=0},
 ["StormCloth"] = {["Id"]="StormCloth",["Ingredients"]={{["Id"]="GlowCloth",["N"]=2},{["Id"]="CloudWool",["N"]=3},{["Id"]="Kelp",["N"]=1}},["Output"]={["Id"]="StormCloth",["N"]=2},["AllowedStations"]={"Loom"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=5,["CampaignTier"]=5,["FuelWorkSeconds"]=0},
 ["ToughCloth"] = {["Id"]="ToughCloth",["Ingredients"]={{["Id"]="StormCloth",["N"]=2},{["Id"]="ToughHide",["N"]=3},{["Id"]="PlantOil",["N"]=1}},["Output"]={["Id"]="ToughCloth",["N"]=2},["AllowedStations"]={"Loom"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=6,["CampaignTier"]=6,["FuelWorkSeconds"]=0},
 ["SailCloth"] = {["Id"]="SailCloth",["Ingredients"]={{["Id"]="ToughCloth",["N"]=2},{["Id"]="StrongSilk",["N"]=3},{["Id"]="PressureGlass",["N"]=1}},["Output"]={["Id"]="SailCloth",["N"]=2},["AllowedStations"]={"Loom"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=7,["CampaignTier"]=7,["FuelWorkSeconds"]=0},
 ["NightCloth"] = {["Id"]="NightCloth",["Ingredients"]={{["Id"]="SailCloth",["N"]=2},{["Id"]="MoonThread",["N"]=3},{["Id"]="DarkMoss",["N"]=1}},["Output"]={["Id"]="NightCloth",["N"]=2},["AllowedStations"]={"Loom"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=8,["CampaignTier"]=8,["FuelWorkSeconds"]=0},
 ["RecoveredGears"] = {["Id"]="RecoveredGears",["Ingredients"]={{["Id"]="OldGear",["N"]=1}},["Output"]={["Id"]="Gears",["N"]=2},["AllowedStations"]={"Workbench"},["Category"]="Materials",["BaseCraftTime"]=6,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["StoneSpear"] = {["Id"]="StoneSpear",["Ingredients"]={{["Id"]="Stone",["N"]=4},{["Id"]="Wood",["N"]=2},{["Id"]="Cord",["N"]=2}},["Output"]={["Id"]="StoneSpear",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["HuntingBow"] = {["Id"]="HuntingBow",["Ingredients"]={{["Id"]="Stone",["N"]=2},{["Id"]="Wood",["N"]=4},{["Id"]="Cord",["N"]=3}},["Output"]={["Id"]="HuntingBow",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["BoneKnife"] = {["Id"]="BoneKnife",["Ingredients"]={{["Id"]="Bone",["N"]=3},{["Id"]="Wood",["N"]=2},{["Id"]="Cord",["N"]=2}},["Output"]={["Id"]="BoneKnife",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["SteelSword"] = {["Id"]="SteelSword",["Ingredients"]={{["Id"]="SteelBar",["N"]=4},{["Id"]="Wood",["N"]=2},{["Id"]="Cord",["N"]=2},{["Id"]="IceCrystal",["N"]=2}},["Output"]={["Id"]="SteelSword",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["FrostSpear"] = {["Id"]="FrostSpear",["Ingredients"]={{["Id"]="SteelBar",["N"]=4},{["Id"]="Wood",["N"]=2},{["Id"]="Cord",["N"]=2},{["Id"]="IceCrystal",["N"]=2}},["Output"]={["Id"]="FrostSpear",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["MarshBow"] = {["Id"]="MarshBow",["Ingredients"]={{["Id"]="SteelBar",["N"]=2},{["Id"]="Wood",["N"]=4},{["Id"]="Cord",["N"]=3},{["Id"]="IceCrystal",["N"]=2}},["Output"]={["Id"]="MarshBow",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["EmberAxe"] = {["Id"]="EmberAxe",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=4},{["Id"]="Wood",["N"]=2},{["Id"]="Cord",["N"]=2},{["Id"]="BlackGlass",["N"]=2}},["Output"]={["Id"]="EmberAxe",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["CrystalStaff"] = {["Id"]="CrystalStaff",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=4},{["Id"]="Wood",["N"]=2},{["Id"]="ClearCrystal",["N"]=2},{["Id"]="BlackGlass",["N"]=2}},["Output"]={["Id"]="CrystalStaff",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["BlacksteelSword"] = {["Id"]="BlacksteelSword",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=4},{["Id"]="Wood",["N"]=2},{["Id"]="Cord",["N"]=2},{["Id"]="BlackGlass",["N"]=2}},["Output"]={["Id"]="BlacksteelSword",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["MeteorPike"] = {["Id"]="MeteorPike",["Ingredients"]={{["Id"]="MeteorBar",["N"]=4},{["Id"]="Wood",["N"]=2},{["Id"]="Cord",["N"]=2},{["Id"]="ImpactGlass",["N"]=2}},["Output"]={["Id"]="MeteorPike",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["DawnBow"] = {["Id"]="DawnBow",["Ingredients"]={{["Id"]="MeteorBar",["N"]=2},{["Id"]="Wood",["N"]=4},{["Id"]="CrystalThread",["N"]=3},{["Id"]="ImpactGlass",["N"]=2}},["Output"]={["Id"]="DawnBow",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["CraterHammer"] = {["Id"]="CraterHammer",["Ingredients"]={{["Id"]="MeteorBar",["N"]=4},{["Id"]="Wood",["N"]=2},{["Id"]="Cord",["N"]=2},{["Id"]="ImpactGlass",["N"]=2}},["Output"]={["Id"]="CraterHammer",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["ThunderHammer"] = {["Id"]="ThunderHammer",["Ingredients"]={{["Id"]="StormBar",["N"]=4},{["Id"]="Ironwood",["N"]=2},{["Id"]="Cord",["N"]=2},{["Id"]="StormOre",["N"]=2}},["Output"]={["Id"]="ThunderHammer",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=5,["CampaignTier"]=5},
 ["TideSpear"] = {["Id"]="TideSpear",["Ingredients"]={{["Id"]="StormBar",["N"]=4},{["Id"]="Ironwood",["N"]=2},{["Id"]="Cord",["N"]=2},{["Id"]="StormOre",["N"]=2}},["Output"]={["Id"]="TideSpear",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=5,["CampaignTier"]=5},
 ["StormBow"] = {["Id"]="StormBow",["Ingredients"]={{["Id"]="StormBar",["N"]=2},{["Id"]="Ironwood",["N"]=4},{["Id"]="StrongSilk",["N"]=3},{["Id"]="StormOre",["N"]=2}},["Output"]={["Id"]="StormBow",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=5,["CampaignTier"]=5},
 ["ThornBlade"] = {["Id"]="ThornBlade",["Ingredients"]={{["Id"]="ReinforcedBar",["N"]=4},{["Id"]="Ironwood",["N"]=2},{["Id"]="Cord",["N"]=2},{["Id"]="ThickSpores",["N"]=2}},["Output"]={["Id"]="ThornBlade",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=6,["CampaignTier"]=6},
 ["IronwoodBow"] = {["Id"]="IronwoodBow",["Ingredients"]={{["Id"]="ReinforcedBar",["N"]=2},{["Id"]="Ironwood",["N"]=4},{["Id"]="StrongSilk",["N"]=3},{["Id"]="ThickSpores",["N"]=2}},["Output"]={["Id"]="IronwoodBow",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=6,["CampaignTier"]=6},
 ["RootStaff"] = {["Id"]="RootStaff",["Ingredients"]={{["Id"]="ReinforcedBar",["N"]=4},{["Id"]="Ironwood",["N"]=2},{["Id"]="ClearCrystal",["N"]=2},{["Id"]="ThickSpores",["N"]=2}},["Output"]={["Id"]="RootStaff",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=6,["CampaignTier"]=6},
 ["DeepsteelSword"] = {["Id"]="DeepsteelSword",["Ingredients"]={{["Id"]="DeepMetal",["N"]=4},{["Id"]="Heartwood",["N"]=2},{["Id"]="Cord",["N"]=2},{["Id"]="EchoShell",["N"]=2}},["Output"]={["Id"]="DeepsteelSword",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=7,["CampaignTier"]=7},
 ["LanternStaff"] = {["Id"]="LanternStaff",["Ingredients"]={{["Id"]="DeepMetal",["N"]=4},{["Id"]="Heartwood",["N"]=2},{["Id"]="ClearCrystal",["N"]=2},{["Id"]="EchoShell",["N"]=2}},["Output"]={["Id"]="LanternStaff",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=7,["CampaignTier"]=7},
 ["SkySpear"] = {["Id"]="SkySpear",["Ingredients"]={{["Id"]="DeepMetal",["N"]=4},{["Id"]="Heartwood",["N"]=2},{["Id"]="Cord",["N"]=2},{["Id"]="EchoShell",["N"]=2}},["Output"]={["Id"]="SkySpear",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=7,["CampaignTier"]=7},
 ["Moonblade"] = {["Id"]="Moonblade",["Ingredients"]={{["Id"]="MoonBar",["N"]=4},{["Id"]="Heartwood",["N"]=2},{["Id"]="Cord",["N"]=2},{["Id"]="MoonRock",["N"]=2}},["Output"]={["Id"]="Moonblade",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=8,["CampaignTier"]=8},
 ["StarBow"] = {["Id"]="StarBow",["Ingredients"]={{["Id"]="MoonBar",["N"]=2},{["Id"]="Heartwood",["N"]=4},{["Id"]="StrongSilk",["N"]=3},{["Id"]="MoonRock",["N"]=2}},["Output"]={["Id"]="StarBow",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=8,["CampaignTier"]=8},
 ["GravityHammer"] = {["Id"]="GravityHammer",["Ingredients"]={{["Id"]="MoonBar",["N"]=4},{["Id"]="Heartwood",["N"]=2},{["Id"]="Cord",["N"]=2},{["Id"]="MoonRock",["N"]=2}},["Output"]={["Id"]="GravityHammer",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Weapons",["BaseCraftTime"]=12,["RequiredGrade"]=8,["CampaignTier"]=8},
 ["Arrow"] = {["Id"]="Arrow",["Ingredients"]={{["Id"]="Wood",["N"]=1},{["Id"]="Stone",["N"]=1},{["Id"]="Fiber",["N"]=1}},["Output"]={["Id"]="Arrow",["N"]=20},["AllowedStations"]={"Hand"},["Category"]="Weapons",["BaseCraftTime"]=4,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["StoneAxe"] = {["Id"]="StoneAxe",["Ingredients"]={{["Id"]="Stone",["N"]=3},{["Id"]="Wood",["N"]=2},{["Id"]="Cord",["N"]=1}},["Output"]={["Id"]="StoneAxe",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Tools",["BaseCraftTime"]=12,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["StonePickaxe"] = {["Id"]="StonePickaxe",["Ingredients"]={{["Id"]="Stone",["N"]=3},{["Id"]="Wood",["N"]=2},{["Id"]="Cord",["N"]=1}},["Output"]={["Id"]="StonePickaxe",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Tools",["BaseCraftTime"]=12,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["SteelAxe"] = {["Id"]="SteelAxe",["Ingredients"]={{["Id"]="SteelBar",["N"]=3},{["Id"]="Wood",["N"]=2},{["Id"]="Cord",["N"]=1}},["Output"]={["Id"]="SteelAxe",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Tools",["BaseCraftTime"]=12,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["SteelPickaxe"] = {["Id"]="SteelPickaxe",["Ingredients"]={{["Id"]="SteelBar",["N"]=3},{["Id"]="Wood",["N"]=2},{["Id"]="Cord",["N"]=1}},["Output"]={["Id"]="SteelPickaxe",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Tools",["BaseCraftTime"]=12,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["BlacksteelAxe"] = {["Id"]="BlacksteelAxe",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=3},{["Id"]="Wood",["N"]=2},{["Id"]="Cord",["N"]=1}},["Output"]={["Id"]="BlacksteelAxe",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Tools",["BaseCraftTime"]=12,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["BlacksteelPickaxe"] = {["Id"]="BlacksteelPickaxe",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=3},{["Id"]="Wood",["N"]=2},{["Id"]="Cord",["N"]=1}},["Output"]={["Id"]="BlacksteelPickaxe",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Tools",["BaseCraftTime"]=12,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["MeteorAxe"] = {["Id"]="MeteorAxe",["Ingredients"]={{["Id"]="MeteorBar",["N"]=3},{["Id"]="Wood",["N"]=2},{["Id"]="Cord",["N"]=1}},["Output"]={["Id"]="MeteorAxe",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Tools",["BaseCraftTime"]=12,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["MeteorPickaxe"] = {["Id"]="MeteorPickaxe",["Ingredients"]={{["Id"]="MeteorBar",["N"]=3},{["Id"]="Wood",["N"]=2},{["Id"]="Cord",["N"]=1}},["Output"]={["Id"]="MeteorPickaxe",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Tools",["BaseCraftTime"]=12,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["StormAxe"] = {["Id"]="StormAxe",["Ingredients"]={{["Id"]="StormBar",["N"]=3},{["Id"]="Ironwood",["N"]=2},{["Id"]="Cord",["N"]=1}},["Output"]={["Id"]="StormAxe",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Tools",["BaseCraftTime"]=12,["RequiredGrade"]=5,["CampaignTier"]=5},
 ["StormPickaxe"] = {["Id"]="StormPickaxe",["Ingredients"]={{["Id"]="StormBar",["N"]=3},{["Id"]="Ironwood",["N"]=2},{["Id"]="Cord",["N"]=1}},["Output"]={["Id"]="StormPickaxe",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Tools",["BaseCraftTime"]=12,["RequiredGrade"]=5,["CampaignTier"]=5},
 ["IronwoodAxe"] = {["Id"]="IronwoodAxe",["Ingredients"]={{["Id"]="ReinforcedBar",["N"]=3},{["Id"]="Ironwood",["N"]=2},{["Id"]="Cord",["N"]=1}},["Output"]={["Id"]="IronwoodAxe",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Tools",["BaseCraftTime"]=12,["RequiredGrade"]=6,["CampaignTier"]=6},
 ["ReinforcedPickaxe"] = {["Id"]="ReinforcedPickaxe",["Ingredients"]={{["Id"]="ReinforcedBar",["N"]=3},{["Id"]="Ironwood",["N"]=2},{["Id"]="Cord",["N"]=1}},["Output"]={["Id"]="ReinforcedPickaxe",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Tools",["BaseCraftTime"]=12,["RequiredGrade"]=6,["CampaignTier"]=6},
 ["DeepAxe"] = {["Id"]="DeepAxe",["Ingredients"]={{["Id"]="DeepMetal",["N"]=3},{["Id"]="Heartwood",["N"]=2},{["Id"]="Cord",["N"]=1}},["Output"]={["Id"]="DeepAxe",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Tools",["BaseCraftTime"]=12,["RequiredGrade"]=7,["CampaignTier"]=7},
 ["DeepPickaxe"] = {["Id"]="DeepPickaxe",["Ingredients"]={{["Id"]="DeepMetal",["N"]=3},{["Id"]="Heartwood",["N"]=2},{["Id"]="Cord",["N"]=1}},["Output"]={["Id"]="DeepPickaxe",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Tools",["BaseCraftTime"]=12,["RequiredGrade"]=7,["CampaignTier"]=7},
 ["MoonAxe"] = {["Id"]="MoonAxe",["Ingredients"]={{["Id"]="MoonBar",["N"]=3},{["Id"]="Heartwood",["N"]=2},{["Id"]="Cord",["N"]=1}},["Output"]={["Id"]="MoonAxe",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Tools",["BaseCraftTime"]=12,["RequiredGrade"]=8,["CampaignTier"]=8},
 ["MoonPickaxe"] = {["Id"]="MoonPickaxe",["Ingredients"]={{["Id"]="MoonBar",["N"]=3},{["Id"]="Heartwood",["N"]=2},{["Id"]="Cord",["N"]=1}},["Output"]={["Id"]="MoonPickaxe",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Tools",["BaseCraftTime"]=12,["RequiredGrade"]=8,["CampaignTier"]=8},
 ["GardenSickle"] = {["Id"]="GardenSickle",["Ingredients"]={{["Id"]="SteelBar",["N"]=2},{["Id"]="Wood",["N"]=2},{["Id"]="Reeds",["N"]=2}},["Output"]={["Id"]="GardenSickle",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Tools",["BaseCraftTime"]=12,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["FieldSickle"] = {["Id"]="FieldSickle",["Ingredients"]={{["Id"]="GardenSickle",["N"]=1},{["Id"]="StormBar",["N"]=3},{["Id"]="LivingRoot",["N"]=2}},["Output"]={["Id"]="FieldSickle",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Tools",["BaseCraftTime"]=12,["RequiredGrade"]=5,["CampaignTier"]=5},
 ["ExpeditionTool"] = {["Id"]="ExpeditionTool",["Ingredients"]={{["Id"]="MoonAxe",["N"]=1},{["Id"]="MoonPickaxe",["N"]=1},{["Id"]="FieldSickle",["N"]=1},{["Id"]="Gears",["N"]=4}},["Output"]={["Id"]="ExpeditionTool",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Tools",["BaseCraftTime"]=12,["RequiredGrade"]=8,["CampaignTier"]=8},
 ["Harvester"] = {["Id"]="Harvester",["Ingredients"]={{["Id"]="Wood",["N"]=2},{["Id"]="Stone",["N"]=2}},["Output"]={["Id"]="Harvester",["N"]=1},["AllowedStations"]={"Hand"},["Category"]="Tools",["BaseCraftTime"]=12,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["TrailHood"] = {["Id"]="TrailHood",["Ingredients"]={{["Id"]="Stone",["N"]=2},{["Id"]="Cloth",["N"]=3},{["Id"]="Resin",["N"]=1}},["Output"]={["Id"]="TrailHood",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["TrailCoat"] = {["Id"]="TrailCoat",["Ingredients"]={{["Id"]="Stone",["N"]=4},{["Id"]="Cloth",["N"]=5},{["Id"]="Resin",["N"]=2}},["Output"]={["Id"]="TrailCoat",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["TrailTrousers"] = {["Id"]="TrailTrousers",["Ingredients"]={{["Id"]="Stone",["N"]=3},{["Id"]="Cloth",["N"]=4},{["Id"]="Resin",["N"]=2}},["Output"]={["Id"]="TrailTrousers",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["TrailBoots"] = {["Id"]="TrailBoots",["Ingredients"]={{["Id"]="Stone",["N"]=2},{["Id"]="Cloth",["N"]=2},{["Id"]="Resin",["N"]=1}},["Output"]={["Id"]="TrailBoots",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["DuneHood"] = {["Id"]="DuneHood",["Ingredients"]={{["Id"]="Stone",["N"]=2},{["Id"]="Cloth",["N"]=3},{["Id"]="Cactus",["N"]=1}},["Output"]={["Id"]="DuneHood",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["DuneCoat"] = {["Id"]="DuneCoat",["Ingredients"]={{["Id"]="Stone",["N"]=4},{["Id"]="Cloth",["N"]=5},{["Id"]="Cactus",["N"]=2}},["Output"]={["Id"]="DuneCoat",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["DuneTrousers"] = {["Id"]="DuneTrousers",["Ingredients"]={{["Id"]="Stone",["N"]=3},{["Id"]="Cloth",["N"]=4},{["Id"]="Cactus",["N"]=2}},["Output"]={["Id"]="DuneTrousers",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["DuneBoots"] = {["Id"]="DuneBoots",["Ingredients"]={{["Id"]="Stone",["N"]=2},{["Id"]="Cloth",["N"]=2},{["Id"]="Cactus",["N"]=1}},["Output"]={["Id"]="DuneBoots",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["MarshHood"] = {["Id"]="MarshHood",["Ingredients"]={{["Id"]="SteelBar",["N"]=2},{["Id"]="WarmCloth",["N"]=3},{["Id"]="Reeds",["N"]=1}},["Output"]={["Id"]="MarshHood",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["MarshCoat"] = {["Id"]="MarshCoat",["Ingredients"]={{["Id"]="SteelBar",["N"]=4},{["Id"]="WarmCloth",["N"]=5},{["Id"]="Reeds",["N"]=2}},["Output"]={["Id"]="MarshCoat",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["MarshTrousers"] = {["Id"]="MarshTrousers",["Ingredients"]={{["Id"]="SteelBar",["N"]=3},{["Id"]="WarmCloth",["N"]=4},{["Id"]="Reeds",["N"]=2}},["Output"]={["Id"]="MarshTrousers",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["MarshBoots"] = {["Id"]="MarshBoots",["Ingredients"]={{["Id"]="SteelBar",["N"]=2},{["Id"]="WarmCloth",["N"]=2},{["Id"]="Reeds",["N"]=1}},["Output"]={["Id"]="MarshBoots",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["FrostHood"] = {["Id"]="FrostHood",["Ingredients"]={{["Id"]="SteelBar",["N"]=2},{["Id"]="WarmCloth",["N"]=3},{["Id"]="WarmFur",["N"]=1}},["Output"]={["Id"]="FrostHood",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["FrostCoat"] = {["Id"]="FrostCoat",["Ingredients"]={{["Id"]="SteelBar",["N"]=4},{["Id"]="WarmCloth",["N"]=5},{["Id"]="WarmFur",["N"]=2}},["Output"]={["Id"]="FrostCoat",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["FrostTrousers"] = {["Id"]="FrostTrousers",["Ingredients"]={{["Id"]="SteelBar",["N"]=3},{["Id"]="WarmCloth",["N"]=4},{["Id"]="WarmFur",["N"]=2}},["Output"]={["Id"]="FrostTrousers",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["FrostBoots"] = {["Id"]="FrostBoots",["Ingredients"]={{["Id"]="SteelBar",["N"]=2},{["Id"]="WarmCloth",["N"]=2},{["Id"]="WarmFur",["N"]=1}},["Output"]={["Id"]="FrostBoots",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["AshHood"] = {["Id"]="AshHood",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=2},{["Id"]="FireCloth",["N"]=3},{["Id"]="BlackGlass",["N"]=1}},["Output"]={["Id"]="AshHood",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["AshCoat"] = {["Id"]="AshCoat",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=4},{["Id"]="FireCloth",["N"]=5},{["Id"]="BlackGlass",["N"]=2}},["Output"]={["Id"]="AshCoat",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["AshTrousers"] = {["Id"]="AshTrousers",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=3},{["Id"]="FireCloth",["N"]=4},{["Id"]="BlackGlass",["N"]=2}},["Output"]={["Id"]="AshTrousers",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["AshBoots"] = {["Id"]="AshBoots",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=2},{["Id"]="FireCloth",["N"]=2},{["Id"]="BlackGlass",["N"]=1}},["Output"]={["Id"]="AshBoots",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["CrystalHood"] = {["Id"]="CrystalHood",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=2},{["Id"]="FireCloth",["N"]=3},{["Id"]="ClearCrystal",["N"]=1}},["Output"]={["Id"]="CrystalHood",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["CrystalCoat"] = {["Id"]="CrystalCoat",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=4},{["Id"]="FireCloth",["N"]=5},{["Id"]="ClearCrystal",["N"]=2}},["Output"]={["Id"]="CrystalCoat",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["CrystalTrousers"] = {["Id"]="CrystalTrousers",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=3},{["Id"]="FireCloth",["N"]=4},{["Id"]="ClearCrystal",["N"]=2}},["Output"]={["Id"]="CrystalTrousers",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["CrystalBoots"] = {["Id"]="CrystalBoots",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=2},{["Id"]="FireCloth",["N"]=2},{["Id"]="ClearCrystal",["N"]=1}},["Output"]={["Id"]="CrystalBoots",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["AuroraHood"] = {["Id"]="AuroraHood",["Ingredients"]={{["Id"]="MeteorBar",["N"]=2},{["Id"]="GlowCloth",["N"]=3},{["Id"]="GlowFiber",["N"]=1}},["Output"]={["Id"]="AuroraHood",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["AuroraCoat"] = {["Id"]="AuroraCoat",["Ingredients"]={{["Id"]="MeteorBar",["N"]=4},{["Id"]="GlowCloth",["N"]=5},{["Id"]="GlowFiber",["N"]=2}},["Output"]={["Id"]="AuroraCoat",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["AuroraTrousers"] = {["Id"]="AuroraTrousers",["Ingredients"]={{["Id"]="MeteorBar",["N"]=3},{["Id"]="GlowCloth",["N"]=4},{["Id"]="GlowFiber",["N"]=2}},["Output"]={["Id"]="AuroraTrousers",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["AuroraBoots"] = {["Id"]="AuroraBoots",["Ingredients"]={{["Id"]="MeteorBar",["N"]=2},{["Id"]="GlowCloth",["N"]=2},{["Id"]="GlowFiber",["N"]=1}},["Output"]={["Id"]="AuroraBoots",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["MeteorHood"] = {["Id"]="MeteorHood",["Ingredients"]={{["Id"]="MeteorBar",["N"]=2},{["Id"]="GlowCloth",["N"]=3},{["Id"]="ImpactGlass",["N"]=1}},["Output"]={["Id"]="MeteorHood",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["MeteorCoat"] = {["Id"]="MeteorCoat",["Ingredients"]={{["Id"]="MeteorBar",["N"]=4},{["Id"]="GlowCloth",["N"]=5},{["Id"]="ImpactGlass",["N"]=2}},["Output"]={["Id"]="MeteorCoat",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["MeteorTrousers"] = {["Id"]="MeteorTrousers",["Ingredients"]={{["Id"]="MeteorBar",["N"]=3},{["Id"]="GlowCloth",["N"]=4},{["Id"]="ImpactGlass",["N"]=2}},["Output"]={["Id"]="MeteorTrousers",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["MeteorBoots"] = {["Id"]="MeteorBoots",["Ingredients"]={{["Id"]="MeteorBar",["N"]=2},{["Id"]="GlowCloth",["N"]=2},{["Id"]="ImpactGlass",["N"]=1}},["Output"]={["Id"]="MeteorBoots",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["CoastHood"] = {["Id"]="CoastHood",["Ingredients"]={{["Id"]="SteelBar",["N"]=2},{["Id"]="WarmCloth",["N"]=3},{["Id"]="ShellPlate",["N"]=1}},["Output"]={["Id"]="CoastHood",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["CoastCoat"] = {["Id"]="CoastCoat",["Ingredients"]={{["Id"]="SteelBar",["N"]=4},{["Id"]="WarmCloth",["N"]=5},{["Id"]="ShellPlate",["N"]=2}},["Output"]={["Id"]="CoastCoat",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["CoastTrousers"] = {["Id"]="CoastTrousers",["Ingredients"]={{["Id"]="SteelBar",["N"]=3},{["Id"]="WarmCloth",["N"]=4},{["Id"]="ShellPlate",["N"]=2}},["Output"]={["Id"]="CoastTrousers",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["CoastBoots"] = {["Id"]="CoastBoots",["Ingredients"]={{["Id"]="SteelBar",["N"]=2},{["Id"]="WarmCloth",["N"]=2},{["Id"]="ShellPlate",["N"]=1}},["Output"]={["Id"]="CoastBoots",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["StormHood"] = {["Id"]="StormHood",["Ingredients"]={{["Id"]="MeteorBar",["N"]=2},{["Id"]="GlowCloth",["N"]=3},{["Id"]="CloudWool",["N"]=1}},["Output"]={["Id"]="StormHood",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["StormCoat"] = {["Id"]="StormCoat",["Ingredients"]={{["Id"]="MeteorBar",["N"]=4},{["Id"]="GlowCloth",["N"]=5},{["Id"]="CloudWool",["N"]=2}},["Output"]={["Id"]="StormCoat",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["StormTrousers"] = {["Id"]="StormTrousers",["Ingredients"]={{["Id"]="MeteorBar",["N"]=3},{["Id"]="GlowCloth",["N"]=4},{["Id"]="CloudWool",["N"]=2}},["Output"]={["Id"]="StormTrousers",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["StormBoots"] = {["Id"]="StormBoots",["Ingredients"]={{["Id"]="MeteorBar",["N"]=2},{["Id"]="GlowCloth",["N"]=2},{["Id"]="CloudWool",["N"]=1}},["Output"]={["Id"]="StormBoots",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["GardenHood"] = {["Id"]="GardenHood",["Ingredients"]={{["Id"]="MeteorBar",["N"]=2},{["Id"]="GlowCloth",["N"]=3},{["Id"]="LivingRoot",["N"]=1}},["Output"]={["Id"]="GardenHood",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["GardenCoat"] = {["Id"]="GardenCoat",["Ingredients"]={{["Id"]="MeteorBar",["N"]=4},{["Id"]="GlowCloth",["N"]=5},{["Id"]="LivingRoot",["N"]=2}},["Output"]={["Id"]="GardenCoat",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["GardenTrousers"] = {["Id"]="GardenTrousers",["Ingredients"]={{["Id"]="MeteorBar",["N"]=3},{["Id"]="GlowCloth",["N"]=4},{["Id"]="LivingRoot",["N"]=2}},["Output"]={["Id"]="GardenTrousers",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["GardenBoots"] = {["Id"]="GardenBoots",["Ingredients"]={{["Id"]="MeteorBar",["N"]=2},{["Id"]="GlowCloth",["N"]=2},{["Id"]="LivingRoot",["N"]=1}},["Output"]={["Id"]="GardenBoots",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["IronHood"] = {["Id"]="IronHood",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=2},{["Id"]="FireCloth",["N"]=3},{["Id"]="ToughHide",["N"]=1}},["Output"]={["Id"]="IronHood",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["IronCoat"] = {["Id"]="IronCoat",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=4},{["Id"]="FireCloth",["N"]=5},{["Id"]="ToughHide",["N"]=2}},["Output"]={["Id"]="IronCoat",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["IronTrousers"] = {["Id"]="IronTrousers",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=3},{["Id"]="FireCloth",["N"]=4},{["Id"]="ToughHide",["N"]=2}},["Output"]={["Id"]="IronTrousers",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["IronBoots"] = {["Id"]="IronBoots",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=2},{["Id"]="FireCloth",["N"]=2},{["Id"]="ToughHide",["N"]=1}},["Output"]={["Id"]="IronBoots",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["CanopyHood"] = {["Id"]="CanopyHood",["Ingredients"]={{["Id"]="SteelBar",["N"]=2},{["Id"]="WarmCloth",["N"]=3},{["Id"]="StrongSilk",["N"]=1}},["Output"]={["Id"]="CanopyHood",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["CanopyCoat"] = {["Id"]="CanopyCoat",["Ingredients"]={{["Id"]="SteelBar",["N"]=4},{["Id"]="WarmCloth",["N"]=5},{["Id"]="StrongSilk",["N"]=2}},["Output"]={["Id"]="CanopyCoat",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["CanopyTrousers"] = {["Id"]="CanopyTrousers",["Ingredients"]={{["Id"]="SteelBar",["N"]=3},{["Id"]="WarmCloth",["N"]=4},{["Id"]="StrongSilk",["N"]=2}},["Output"]={["Id"]="CanopyTrousers",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["CanopyBoots"] = {["Id"]="CanopyBoots",["Ingredients"]={{["Id"]="SteelBar",["N"]=2},{["Id"]="WarmCloth",["N"]=2},{["Id"]="StrongSilk",["N"]=1}},["Output"]={["Id"]="CanopyBoots",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["DiverHood"] = {["Id"]="DiverHood",["Ingredients"]={{["Id"]="MeteorBar",["N"]=2},{["Id"]="GlowCloth",["N"]=3},{["Id"]="PressureGlass",["N"]=1}},["Output"]={["Id"]="DiverHood",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["DiverCoat"] = {["Id"]="DiverCoat",["Ingredients"]={{["Id"]="MeteorBar",["N"]=4},{["Id"]="GlowCloth",["N"]=5},{["Id"]="PressureGlass",["N"]=2}},["Output"]={["Id"]="DiverCoat",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["DiverTrousers"] = {["Id"]="DiverTrousers",["Ingredients"]={{["Id"]="MeteorBar",["N"]=3},{["Id"]="GlowCloth",["N"]=4},{["Id"]="PressureGlass",["N"]=2}},["Output"]={["Id"]="DiverTrousers",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["DiverBoots"] = {["Id"]="DiverBoots",["Ingredients"]={{["Id"]="MeteorBar",["N"]=2},{["Id"]="GlowCloth",["N"]=2},{["Id"]="PressureGlass",["N"]=1}},["Output"]={["Id"]="DiverBoots",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["LanternHood"] = {["Id"]="LanternHood",["Ingredients"]={{["Id"]="MeteorBar",["N"]=2},{["Id"]="GlowCloth",["N"]=3},{["Id"]="DarkMoss",["N"]=1}},["Output"]={["Id"]="LanternHood",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["LanternCoat"] = {["Id"]="LanternCoat",["Ingredients"]={{["Id"]="MeteorBar",["N"]=4},{["Id"]="GlowCloth",["N"]=5},{["Id"]="DarkMoss",["N"]=2}},["Output"]={["Id"]="LanternCoat",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["LanternTrousers"] = {["Id"]="LanternTrousers",["Ingredients"]={{["Id"]="MeteorBar",["N"]=3},{["Id"]="GlowCloth",["N"]=4},{["Id"]="DarkMoss",["N"]=2}},["Output"]={["Id"]="LanternTrousers",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["LanternBoots"] = {["Id"]="LanternBoots",["Ingredients"]={{["Id"]="MeteorBar",["N"]=2},{["Id"]="GlowCloth",["N"]=2},{["Id"]="DarkMoss",["N"]=1}},["Output"]={["Id"]="LanternBoots",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["MoonHood"] = {["Id"]="MoonHood",["Ingredients"]={{["Id"]="MeteorBar",["N"]=2},{["Id"]="GlowCloth",["N"]=3},{["Id"]="MoonThread",["N"]=1}},["Output"]={["Id"]="MoonHood",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["MoonCoat"] = {["Id"]="MoonCoat",["Ingredients"]={{["Id"]="MeteorBar",["N"]=4},{["Id"]="GlowCloth",["N"]=5},{["Id"]="MoonThread",["N"]=2}},["Output"]={["Id"]="MoonCoat",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["MoonTrousers"] = {["Id"]="MoonTrousers",["Ingredients"]={{["Id"]="MeteorBar",["N"]=3},{["Id"]="GlowCloth",["N"]=4},{["Id"]="MoonThread",["N"]=2}},["Output"]={["Id"]="MoonTrousers",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["MoonBoots"] = {["Id"]="MoonBoots",["Ingredients"]={{["Id"]="MeteorBar",["N"]=2},{["Id"]="GlowCloth",["N"]=2},{["Id"]="MoonThread",["N"]=1}},["Output"]={["Id"]="MoonBoots",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["SunVest"] = {["Id"]="SunVest",["Ingredients"]={{["Id"]="Fiber",["N"]=6},{["Id"]="HealingHerb",["N"]=2},{["Id"]="Resin",["N"]=2}},["Output"]={["Id"]="SunVest",["N"]=1},["AllowedStations"]={"Hand"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["DesertCoat"] = {["Id"]="DesertCoat",["Ingredients"]={{["Id"]="SteelBar",["N"]=2},{["Id"]="Cloth",["N"]=3},{["Id"]="Cactus",["N"]=4}},["Output"]={["Id"]="DesertCoat",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Armor",["BaseCraftTime"]=15,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["WarmScarf"] = {["Id"]="WarmScarf",["Ingredients"]={{["Id"]="Cloth",["N"]=3},{["Id"]="WarmFur",["N"]=2}},["Output"]={["Id"]="WarmScarf",["N"]=1},["AllowedStations"]={"Hand"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["RainCape"] = {["Id"]="RainCape",["Ingredients"]={{["Id"]="Cloth",["N"]=3},{["Id"]="Resin",["N"]=2}},["Output"]={["Id"]="RainCape",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["WaterFlask"] = {["Id"]="WaterFlask",["Ingredients"]={{["Id"]="Glass",["N"]=2},{["Id"]="Cord",["N"]=1}},["Output"]={["Id"]="WaterFlask",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["Bucket"] = {["Id"]="Bucket",["Ingredients"]={{["Id"]="Wood",["N"]=4},{["Id"]="Fiber",["N"]=2}},["Output"]={["Id"]="Bucket",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Utility",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["FilterMask"] = {["Id"]="FilterMask",["Ingredients"]={{["Id"]="WarmCloth",["N"]=2},{["Id"]="Coal",["N"]=2},{["Id"]="Resin",["N"]=1}},["Output"]={["Id"]="FilterMask",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["IceCleats"] = {["Id"]="IceCleats",["Ingredients"]={{["Id"]="SteelBar",["N"]=2},{["Id"]="Cloth",["N"]=1}},["Output"]={["Id"]="IceCleats",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["ClimbingGloves"] = {["Id"]="ClimbingGloves",["Ingredients"]={{["Id"]="WarmCloth",["N"]=2},{["Id"]="SteelBar",["N"]=1}},["Output"]={["Id"]="ClimbingGloves",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["SmallPack"] = {["Id"]="SmallPack",["Ingredients"]={{["Id"]="WarmCloth",["N"]=4},{["Id"]="Cord",["N"]=2}},["Output"]={["Id"]="SmallPack",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["SpringBootsCharm"] = {["Id"]="SpringBootsCharm",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=2},{["Id"]="CrystalThread",["N"]=2}},["Output"]={["Id"]="SpringBootsCharm",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["HeatShield"] = {["Id"]="HeatShield",["Ingredients"]={{["Id"]="BlackGlass",["N"]=3},{["Id"]="FireCloth",["N"]=2}},["Output"]={["Id"]="HeatShield",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["GatherersPouch"] = {["Id"]="GatherersPouch",["Ingredients"]={{["Id"]="FireCloth",["N"]=3},{["Id"]="Resin",["N"]=2}},["Output"]={["Id"]="GatherersPouch",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["SteadyGrip"] = {["Id"]="SteadyGrip",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=2},{["Id"]="WarmFur",["N"]=2}},["Output"]={["Id"]="SteadyGrip",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["Glider"] = {["Id"]="Glider",["Ingredients"]={{["Id"]="GlowCloth",["N"]=4},{["Id"]="StrongSilk",["N"]=3},{["Id"]="LiftSeed",["N"]=2}},["Output"]={["Id"]="Glider",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["AirTank"] = {["Id"]="AirTank",["Ingredients"]={{["Id"]="MeteorBar",["N"]=3},{["Id"]="PressureGlass",["N"]=3}},["Output"]={["Id"]="AirTank",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["BrightLantern"] = {["Id"]="BrightLantern",["Ingredients"]={{["Id"]="LightOre",["N"]=2},{["Id"]="Glass",["N"]=2},{["Id"]="MeteorBar",["N"]=1}},["Output"]={["Id"]="BrightLantern",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["LargePack"] = {["Id"]="LargePack",["Ingredients"]={{["Id"]="SmallPack",["N"]=1},{["Id"]="GlowCloth",["N"]=4},{["Id"]="Gears",["N"]=2}},["Output"]={["Id"]="LargePack",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["CoolingRing"] = {["Id"]="CoolingRing",["Ingredients"]={{["Id"]="StormBar",["N"]=2},{["Id"]="IceCrystal",["N"]=3}},["Output"]={["Id"]="CoolingRing",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=5,["CampaignTier"]=5},
 ["WarmingRing"] = {["Id"]="WarmingRing",["Ingredients"]={{["Id"]="StormBar",["N"]=2},{["Id"]="DawnFlower",["N"]=3}},["Output"]={["Id"]="WarmingRing",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=5,["CampaignTier"]=5},
 ["HuntersCharm"] = {["Id"]="HuntersCharm",["Ingredients"]={{["Id"]="StormBar",["N"]=2},{["Id"]="Bone",["N"]=4}},["Output"]={["Id"]="HuntersCharm",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=5,["CampaignTier"]=5},
 ["GroundingBelt"] = {["Id"]="GroundingBelt",["Ingredients"]={{["Id"]="StormBar",["N"]=3},{["Id"]="ShellPlate",["N"]=2}},["Output"]={["Id"]="GroundingBelt",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=5,["CampaignTier"]=5},
 ["RepairPouch"] = {["Id"]="RepairPouch",["Ingredients"]={{["Id"]="ToughCloth",["N"]=3},{["Id"]="LivingRoot",["N"]=2}},["Output"]={["Id"]="RepairPouch",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=6,["CampaignTier"]=6},
 ["RescueCharm"] = {["Id"]="RescueCharm",["Ingredients"]={{["Id"]="ReinforcedBar",["N"]=2},{["Id"]="LivingRoot",["N"]=2}},["Output"]={["Id"]="RescueCharm",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=6,["CampaignTier"]=6},
 ["StrongGlider"] = {["Id"]="StrongGlider",["Ingredients"]={{["Id"]="Glider",["N"]=1},{["Id"]="SailCloth",["N"]=4},{["Id"]="Heartwood",["N"]=2}},["Output"]={["Id"]="StrongGlider",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=7,["CampaignTier"]=7},
 ["DeepAirTank"] = {["Id"]="DeepAirTank",["Ingredients"]={{["Id"]="AirTank",["N"]=1},{["Id"]="DeepMetal",["N"]=3},{["Id"]="Pearl",["N"]=2}},["Output"]={["Id"]="DeepAirTank",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=7,["CampaignTier"]=7},
 ["ExpeditionPack"] = {["Id"]="ExpeditionPack",["Ingredients"]={{["Id"]="LargePack",["N"]=1},{["Id"]="SailCloth",["N"]=4},{["Id"]="Heartwood",["N"]=2}},["Output"]={["Id"]="ExpeditionPack",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=7,["CampaignTier"]=7},
 ["EchoCharm"] = {["Id"]="EchoCharm",["Ingredients"]={{["Id"]="EchoShell",["N"]=3},{["Id"]="DeepMetal",["N"]=2}},["Output"]={["Id"]="EchoCharm",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=7,["CampaignTier"]=7},
 ["GravityBelt"] = {["Id"]="GravityBelt",["Ingredients"]={{["Id"]="MoonBar",["N"]=3},{["Id"]="MoonRock",["N"]=3}},["Output"]={["Id"]="GravityBelt",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=8,["CampaignTier"]=8},
 ["SurvivorsCharm"] = {["Id"]="SurvivorsCharm",["Ingredients"]={{["Id"]="MoonBar",["N"]=2},{["Id"]="LivingRoot",["N"]=2},{["Id"]="AnyTrophy",["N"]=1,["AnyOf"]={"AncientSeed","SunHeart","MarshHeart","FrostHeart","GreaterFireCore","CrystalHeart","DawnHeart","GreaterStarCore","TideHeart","GreaterStormCore","GrowthHeart","IronHeart","SkyHeart","ArchiveHeart","NightHeart","GravityShard"}}},["Output"]={["Id"]="SurvivorsCharm",["N"]=1},["AllowedStations"]={"Anvil"},["Category"]="Accessories",["BaseCraftTime"]=12,["RequiredGrade"]=8,["CampaignTier"]=8},
 ["Workbench"] = {["Id"]="Workbench",["Ingredients"]={{["Id"]="Wood",["N"]=8},{["Id"]="Stone",["N"]=4}},["Output"]={["Id"]="Workbench",["N"]=1},["AllowedStations"]={"Hand"},["Category"]="Stations",["BaseCraftTime"]=20,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["Campfire"] = {["Id"]="Campfire",["Ingredients"]={{["Id"]="Stone",["N"]=6},{["Id"]="Wood",["N"]=4}},["Output"]={["Id"]="Campfire",["N"]=1},["AllowedStations"]={"Hand"},["Category"]="Stations",["BaseCraftTime"]=20,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["Furnace"] = {["Id"]="Furnace",["Ingredients"]={{["Id"]="Stone",["N"]=12},{["Id"]="Wood",["N"]=6}},["Output"]={["Id"]="Furnace",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Stations",["BaseCraftTime"]=20,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["Loom"] = {["Id"]="Loom",["Ingredients"]={{["Id"]="Wood",["N"]=6},{["Id"]="Fiber",["N"]=4}},["Output"]={["Id"]="Loom",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Stations",["BaseCraftTime"]=20,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["Stove"] = {["Id"]="Stove",["Ingredients"]={{["Id"]="Stone",["N"]=8},{["Id"]="IronBar",["N"]=4},{["Id"]="Plank",["N"]=4}},["Output"]={["Id"]="Stove",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Stations",["BaseCraftTime"]=20,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["Oven"] = {["Id"]="Oven",["Ingredients"]={{["Id"]="Stone",["N"]=16},{["Id"]="SteelBar",["N"]=4},{["Id"]="Plank",["N"]=4}},["Output"]={["Id"]="Oven",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Stations",["BaseCraftTime"]=20,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["Anvil"] = {["Id"]="Anvil",["Ingredients"]={{["Id"]="IronBar",["N"]=4},{["Id"]="Stone",["N"]=8}},["Output"]={["Id"]="Anvil",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Stations",["BaseCraftTime"]=20,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["MedicineTable"] = {["Id"]="MedicineTable",["Ingredients"]={{["Id"]="Plank",["N"]=6},{["Id"]="Glass",["N"]=2},{["Id"]="HerbalPaste",["N"]=2}},["Output"]={["Id"]="MedicineTable",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Stations",["BaseCraftTime"]=20,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["SurveyDesk"] = {["Id"]="SurveyDesk",["Ingredients"]={{["Id"]="Plank",["N"]=6},{["Id"]="IronBar",["N"]=2},{["Id"]="Glass",["N"]=2}},["Output"]={["Id"]="SurveyDesk",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Stations",["BaseCraftTime"]=20,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["EnchantingTable"] = {["Id"]="EnchantingTable",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=4},{["Id"]="ClearCrystal",["N"]=4},{["Id"]="CrystalThread",["N"]=2}},["Output"]={["Id"]="EnchantingTable",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Stations",["BaseCraftTime"]=20,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["RepairBench"] = {["Id"]="RepairBench",["Ingredients"]={{["Id"]="MeteorBar",["N"]=3},{["Id"]="Plank",["N"]=6},{["Id"]="Gears",["N"]=2}},["Output"]={["Id"]="RepairBench",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Stations",["BaseCraftTime"]=20,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["Floor"] = {["Id"]="Floor",["Ingredients"]={{["Id"]="Plank",["N"]=2,["StructuralMaterial"]=true}},["Output"]={["Id"]="Floor",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Structures",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["Wall"] = {["Id"]="Wall",["Ingredients"]={{["Id"]="Plank",["N"]=2,["StructuralMaterial"]=true}},["Output"]={["Id"]="Wall",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Structures",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["Roof"] = {["Id"]="Roof",["Ingredients"]={{["Id"]="Plank",["N"]=2,["StructuralMaterial"]=true},{["Id"]="Fiber",["N"]=1,["StructuralMaterial"]=true}},["Output"]={["Id"]="Roof",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Structures",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["Ramp"] = {["Id"]="Ramp",["Ingredients"]={{["Id"]="Plank",["N"]=3,["StructuralMaterial"]=true}},["Output"]={["Id"]="Ramp",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Structures",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["Door"] = {["Id"]="Door",["Ingredients"]={{["Id"]="Plank",["N"]=2,["StructuralMaterial"]=true},{["Id"]="Resin",["N"]=1,["StructuralMaterial"]=true}},["Output"]={["Id"]="Door",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Structures",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["Gate"] = {["Id"]="Gate",["Ingredients"]={{["Id"]="Plank",["N"]=4,["StructuralMaterial"]=true},{["Id"]="IronBar",["N"]=1,["StructuralMaterial"]=true}},["Output"]={["Id"]="Gate",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Structures",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["Stairs"] = {["Id"]="Stairs",["Ingredients"]={{["Id"]="Plank",["N"]=3,["StructuralMaterial"]=true}},["Output"]={["Id"]="Stairs",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Structures",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["Ladder"] = {["Id"]="Ladder",["Ingredients"]={{["Id"]="Wood",["N"]=3,["StructuralMaterial"]=true},{["Id"]="Cord",["N"]=1,["StructuralMaterial"]=true}},["Output"]={["Id"]="Ladder",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Structures",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["Watchtower"] = {["Id"]="Watchtower",["Ingredients"]={{["Id"]="Plank",["N"]=10,["StructuralMaterial"]=true},{["Id"]="Stone",["N"]=6,["StructuralMaterial"]=true}},["Output"]={["Id"]="Watchtower",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Structures",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["Chest"] = {["Id"]="Chest",["Ingredients"]={{["Id"]="Plank",["N"]=4},{["Id"]="Resin",["N"]=2}},["Output"]={["Id"]="Chest",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Structures",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["LargeChest"] = {["Id"]="LargeChest",["Ingredients"]={{["Id"]="Chest",["N"]=1},{["Id"]="Ironwood",["N"]=4},{["Id"]="Gears",["N"]=2}},["Output"]={["Id"]="LargeChest",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Structures",["BaseCraftTime"]=6,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["Torch"] = {["Id"]="Torch",["Ingredients"]={{["Id"]="Wood",["N"]=1},{["Id"]="Resin",["N"]=1}},["Output"]={["Id"]="Torch",["N"]=2},["AllowedStations"]={"Workbench"},["Category"]="Structures",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["StandingLamp"] = {["Id"]="StandingLamp",["Ingredients"]={{["Id"]="IronBar",["N"]=2},{["Id"]="Glass",["N"]=2},{["Id"]="ClearCrystal",["N"]=1}},["Output"]={["Id"]="StandingLamp",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Structures",["BaseCraftTime"]=6,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["RainCollector"] = {["Id"]="RainCollector",["Ingredients"]={{["Id"]="Plank",["N"]=4},{["Id"]="Cloth",["N"]=3},{["Id"]="Resin",["N"]=2}},["Output"]={["Id"]="RainCollector",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Structures",["BaseCraftTime"]=6,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["WaterFilter"] = {["Id"]="WaterFilter",["Ingredients"]={{["Id"]="MeteorBar",["N"]=2},{["Id"]="Coal",["N"]=2},{["Id"]="Glass",["N"]=2}},["Output"]={["Id"]="WaterFilter",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Structures",["BaseCraftTime"]=6,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["Bedroll"] = {["Id"]="Bedroll",["Ingredients"]={{["Id"]="WarmCloth",["N"]=3},{["Id"]="Fiber",["N"]=4}},["Output"]={["Id"]="Bedroll",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Structures",["BaseCraftTime"]=6,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["SpikeTrap"] = {["Id"]="SpikeTrap",["Ingredients"]={{["Id"]="SteelBar",["N"]=2},{["Id"]="Plank",["N"]=2},{["Id"]="Bone",["N"]=2}},["Output"]={["Id"]="SpikeTrap",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Structures",["BaseCraftTime"]=6,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["CampMarker"] = {["Id"]="CampMarker",["Ingredients"]={{["Id"]="Wood",["N"]=2},{["Id"]="Cloth",["N"]=1}},["Output"]={["Id"]="CampMarker",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Structures",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["Bandage"] = {["Id"]="Bandage",["Ingredients"]={{["Id"]="Cloth",["N"]=1},{["Id"]="HerbalPaste",["N"]=1}},["Output"]={["Id"]="Bandage",["N"]=1},["AllowedStations"]={"Hand"},["Category"]="Consumables",["BaseCraftTime"]=5,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["HealingWrap"] = {["Id"]="HealingWrap",["Ingredients"]={{["Id"]="WarmCloth",["N"]=1},{["Id"]="HerbalPaste",["N"]=2}},["Output"]={["Id"]="HealingWrap",["N"]=1},["AllowedStations"]={"MedicineTable"},["Category"]="Consumables",["BaseCraftTime"]=5,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["FirstAidKit"] = {["Id"]="FirstAidKit",["Ingredients"]={{["Id"]="ToughCloth",["N"]=1},{["Id"]="LivingRoot",["N"]=1},{["Id"]="HerbalPaste",["N"]=2}},["Output"]={["Id"]="FirstAidKit",["N"]=1},["AllowedStations"]={"MedicineTable"},["Category"]="Consumables",["BaseCraftTime"]=5,["RequiredGrade"]=6,["CampaignTier"]=6},
 ["RevivalKit"] = {["Id"]="RevivalKit",["Ingredients"]={{["Id"]="Cloth",["N"]=3},{["Id"]="HerbalPaste",["N"]=2},{["Id"]="Resin",["N"]=2}},["Output"]={["Id"]="RevivalKit",["N"]=1},["AllowedStations"]={"Hand"},["Category"]="Consumables",["BaseCraftTime"]=5,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["Antidote"] = {["Id"]="Antidote",["Ingredients"]={{["Id"]="HealingHerb",["N"]=2},{["Id"]="VenomGland",["N"]=1},{["Id"]="Water",["N"]=1}},["Output"]={["Id"]="Antidote",["N"]=1},["AllowedStations"]={"MedicineTable"},["Category"]="Consumables",["BaseCraftTime"]=5,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["DryingSalve"] = {["Id"]="DryingSalve",["Ingredients"]={{["Id"]="PlantOil",["N"]=1},{["Id"]="Cloth",["N"]=1}},["Output"]={["Id"]="DryingSalve",["N"]=1},["AllowedStations"]={"MedicineTable"},["Category"]="Consumables",["BaseCraftTime"]=5,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["RecoveryTonic"] = {["Id"]="RecoveryTonic",["Ingredients"]={{["Id"]="DawnFlower",["N"]=2},{["Id"]="FrostBloom",["N"]=1},{["Id"]="Water",["N"]=1}},["Output"]={["Id"]="RecoveryTonic",["N"]=1},["AllowedStations"]={"MedicineTable"},["Category"]="Consumables",["BaseCraftTime"]=5,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["FieldRepairKit"] = {["Id"]="FieldRepairKit",["Ingredients"]={{["Id"]="Stone",["N"]=1},{["Id"]="Resin",["N"]=1},{["Id"]="Cloth",["N"]=1}},["Output"]={["Id"]="FieldRepairKit",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Consumables",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["ArmorPatch"] = {["Id"]="ArmorPatch",["Ingredients"]={{["Id"]="Cloth",["N"]=2},{["Id"]="Resin",["N"]=1}},["Output"]={["Id"]="ArmorPatch",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Consumables",["BaseCraftTime"]=6,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["FieldRepairKit2"] = {["Id"]="FieldRepairKit2",["Ingredients"]={{["Id"]="SteelBar",["N"]=1},{["Id"]="Resin",["N"]=1},{["Id"]="WarmCloth",["N"]=1}},["Output"]={["Id"]="FieldRepairKit2",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Consumables",["BaseCraftTime"]=6,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["ArmorPatch2"] = {["Id"]="ArmorPatch2",["Ingredients"]={{["Id"]="WarmCloth",["N"]=2},{["Id"]="Resin",["N"]=1}},["Output"]={["Id"]="ArmorPatch2",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Consumables",["BaseCraftTime"]=6,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["FieldRepairKit3"] = {["Id"]="FieldRepairKit3",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=1},{["Id"]="Resin",["N"]=1},{["Id"]="FireCloth",["N"]=1}},["Output"]={["Id"]="FieldRepairKit3",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Consumables",["BaseCraftTime"]=6,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["ArmorPatch3"] = {["Id"]="ArmorPatch3",["Ingredients"]={{["Id"]="FireCloth",["N"]=2},{["Id"]="Resin",["N"]=1}},["Output"]={["Id"]="ArmorPatch3",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Consumables",["BaseCraftTime"]=6,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["FieldRepairKit4"] = {["Id"]="FieldRepairKit4",["Ingredients"]={{["Id"]="MeteorBar",["N"]=1},{["Id"]="Resin",["N"]=1},{["Id"]="GlowCloth",["N"]=1}},["Output"]={["Id"]="FieldRepairKit4",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Consumables",["BaseCraftTime"]=6,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["ArmorPatch4"] = {["Id"]="ArmorPatch4",["Ingredients"]={{["Id"]="GlowCloth",["N"]=2},{["Id"]="Resin",["N"]=1}},["Output"]={["Id"]="ArmorPatch4",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Consumables",["BaseCraftTime"]=6,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["FieldRepairKit5"] = {["Id"]="FieldRepairKit5",["Ingredients"]={{["Id"]="StormBar",["N"]=1},{["Id"]="Resin",["N"]=1},{["Id"]="StormCloth",["N"]=1}},["Output"]={["Id"]="FieldRepairKit5",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Consumables",["BaseCraftTime"]=6,["RequiredGrade"]=5,["CampaignTier"]=5},
 ["ArmorPatch5"] = {["Id"]="ArmorPatch5",["Ingredients"]={{["Id"]="StormCloth",["N"]=2},{["Id"]="Resin",["N"]=1}},["Output"]={["Id"]="ArmorPatch5",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Consumables",["BaseCraftTime"]=6,["RequiredGrade"]=5,["CampaignTier"]=5},
 ["FieldRepairKit6"] = {["Id"]="FieldRepairKit6",["Ingredients"]={{["Id"]="ReinforcedBar",["N"]=1},{["Id"]="Resin",["N"]=1},{["Id"]="ToughCloth",["N"]=1}},["Output"]={["Id"]="FieldRepairKit6",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Consumables",["BaseCraftTime"]=6,["RequiredGrade"]=6,["CampaignTier"]=6},
 ["ArmorPatch6"] = {["Id"]="ArmorPatch6",["Ingredients"]={{["Id"]="ToughCloth",["N"]=2},{["Id"]="Resin",["N"]=1}},["Output"]={["Id"]="ArmorPatch6",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Consumables",["BaseCraftTime"]=6,["RequiredGrade"]=6,["CampaignTier"]=6},
 ["FieldRepairKit7"] = {["Id"]="FieldRepairKit7",["Ingredients"]={{["Id"]="DeepMetal",["N"]=1},{["Id"]="Resin",["N"]=1},{["Id"]="SailCloth",["N"]=1}},["Output"]={["Id"]="FieldRepairKit7",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Consumables",["BaseCraftTime"]=6,["RequiredGrade"]=7,["CampaignTier"]=7},
 ["ArmorPatch7"] = {["Id"]="ArmorPatch7",["Ingredients"]={{["Id"]="SailCloth",["N"]=2},{["Id"]="Resin",["N"]=1}},["Output"]={["Id"]="ArmorPatch7",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Consumables",["BaseCraftTime"]=6,["RequiredGrade"]=7,["CampaignTier"]=7},
 ["FieldRepairKit8"] = {["Id"]="FieldRepairKit8",["Ingredients"]={{["Id"]="MoonBar",["N"]=1},{["Id"]="Resin",["N"]=1},{["Id"]="NightCloth",["N"]=1}},["Output"]={["Id"]="FieldRepairKit8",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Consumables",["BaseCraftTime"]=6,["RequiredGrade"]=8,["CampaignTier"]=8},
 ["ArmorPatch8"] = {["Id"]="ArmorPatch8",["Ingredients"]={{["Id"]="NightCloth",["N"]=2},{["Id"]="Resin",["N"]=1}},["Output"]={["Id"]="ArmorPatch8",["N"]=1},["AllowedStations"]={"Loom"},["Category"]="Consumables",["BaseCraftTime"]=6,["RequiredGrade"]=8,["CampaignTier"]=8},
 ["FieldClock"] = {["Id"]="FieldClock",["Ingredients"]={{["Id"]="Glass",["N"]=2},{["Id"]="IronBar",["N"]=1},{["Id"]="Plank",["N"]=2}},["Output"]={["Id"]="FieldClock",["N"]=1},["AllowedStations"]={"Workbench"},["Category"]="Intel",["BaseCraftTime"]=20,["RequiredGrade"]=1,["CampaignTier"]=1},
 ["ThreatGauge"] = {["Id"]="ThreatGauge",["Ingredients"]={{["Id"]="IronBar",["N"]=2},{["Id"]="Glass",["N"]=2},{["Id"]="Coal",["N"]=1}},["Output"]={["Id"]="ThreatGauge",["N"]=1},["AllowedStations"]={"SurveyDesk"},["Category"]="Intel",["BaseCraftTime"]=20,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["ResourceCompass"] = {["Id"]="ResourceCompass",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=2},{["Id"]="ClearCrystal",["N"]=2},{["Id"]="Resin",["N"]=1}},["Output"]={["Id"]="ResourceCompass",["N"]=1},["AllowedStations"]={"SurveyDesk"},["Category"]="Intel",["BaseCraftTime"]=20,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["WeatherScanner"] = {["Id"]="WeatherScanner",["Ingredients"]={{["Id"]="Glass",["N"]=3},{["Id"]="BlacksteelBar",["N"]=2},{["Id"]="IceCrystal",["N"]=1}},["Output"]={["Id"]="WeatherScanner",["N"]=1},["AllowedStations"]={"SurveyDesk"},["Category"]="Intel",["BaseCraftTime"]=20,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["BiomePredictor"] = {["Id"]="BiomePredictor",["Ingredients"]={{["Id"]="FieldClock",["N"]=1},{["Id"]="MeteorBar",["N"]=2},{["Id"]="AuroraStone",["N"]=2}},["Output"]={["Id"]="BiomePredictor",["N"]=1},["AllowedStations"]={"SurveyDesk"},["Category"]="Intel",["BaseCraftTime"]=20,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["WeatherPredictor"] = {["Id"]="WeatherPredictor",["Ingredients"]={{["Id"]="BiomePredictor",["N"]=1},{["Id"]="WeatherScanner",["N"]=1},{["Id"]="ClearCrystal",["N"]=3}},["Output"]={["Id"]="WeatherPredictor",["N"]=1},["AllowedStations"]={"SurveyDesk"},["Category"]="Intel",["BaseCraftTime"]=20,["RequiredGrade"]=4,["CampaignTier"]=4},
 ["EventDetector"] = {["Id"]="EventDetector",["Ingredients"]={{["Id"]="StormBar",["N"]=2},{["Id"]="Gears",["N"]=2},{["Id"]="Sunstone",["N"]=2}},["Output"]={["Id"]="EventDetector",["N"]=1},["AllowedStations"]={"SurveyDesk"},["Category"]="Intel",["BaseCraftTime"]=20,["RequiredGrade"]=5,["CampaignTier"]=5},
 ["TrailBeacon"] = {["Id"]="TrailBeacon",["Ingredients"]={{["Id"]="BlacksteelBar",["N"]=1},{["Id"]="ClearCrystal",["N"]=1},{["Id"]="Cloth",["N"]=1}},["Output"]={["Id"]="TrailBeacon",["N"]=1},["AllowedStations"]={"SurveyDesk"},["Category"]="Intel",["BaseCraftTime"]=20,["RequiredGrade"]=3,["CampaignTier"]=3},
 ["FieldJournal"] = {["Id"]="FieldJournal",["Ingredients"]={{["Id"]="StormBar",["N"]=2}},["Output"]={["Id"]="FieldJournal",["N"]=1},["AllowedStations"]={"SurveyDesk"},["Category"]="Intel",["BaseCraftTime"]=20,["RequiredGrade"]=5,["CampaignTier"]=5,["InstallModules"]=true},
 ["ShiftStabilizer"] = {["Id"]="ShiftStabilizer",["Ingredients"]={{["Id"]="SteelBar",["N"]=4},{["Id"]="Glass",["N"]=2},{["Id"]="Resin",["N"]=3}},["Output"]={["Id"]="ShiftStabilizer",["N"]=1},["AllowedStations"]={"SurveyDesk"},["Category"]="Intel",["BaseCraftTime"]=20,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["ShiftTrigger"] = {["Id"]="ShiftTrigger",["Ingredients"]={{["Id"]="SteelBar",["N"]=4},{["Id"]="IceCrystal",["N"]=2},{["Id"]="Gears",["N"]=2}},["Output"]={["Id"]="ShiftTrigger",["N"]=1},["AllowedStations"]={"SurveyDesk"},["Category"]="Intel",["BaseCraftTime"]=20,["RequiredGrade"]=2,["CampaignTier"]=2},
 ["WorldDial"] = {["Id"]="WorldDial",["Ingredients"]={{["Id"]="MeteorBar",["N"]=6},{["Id"]="StarCore",["N"]=2},{["Id"]="AuroraStone",["N"]=2},{["Id"]="Gears",["N"]=4}},["Output"]={["Id"]="WorldDial",["N"]=1},["AllowedStations"]={"SurveyDesk"},["Category"]="Intel",["BaseCraftTime"]=20,["RequiredGrade"]=4,["CampaignTier"]=4,["RequiresMilestone"]="FallenStar"},
 ["WorldAnchor"] = {["Id"]="WorldAnchor",["Ingredients"]={{["Id"]="WorldDial",["N"]=1},{["Id"]="MoonBar",["N"]=6},{["Id"]="PressureGlass",["N"]=4},{["Id"]="DifferentTrophies",["N"]=4,["AnyOf"]={"AncientSeed","SunHeart","MarshHeart","FrostHeart","GreaterFireCore","CrystalHeart","DawnHeart","GreaterStarCore","TideHeart","GreaterStormCore","GrowthHeart","IronHeart","SkyHeart","ArchiveHeart","NightHeart","GravityShard"},["Distinct"]=true}},["Output"]={["Id"]="WorldAnchor",["N"]=1},["AllowedStations"]={"SurveyDesk"},["Category"]="Intel",["BaseCraftTime"]=20,["RequiredGrade"]=8,["CampaignTier"]=8},
}
C.Gear = {
 ["StoneSpear"] = {["Kind"]="Weapon",["Grade"]=1,["Durability"]=400,["DamageFactor"]=1,["AttackCycle"]=1,["Reach"]=9,["Special"]="Lunge",["SpecialFactor"]=1.5,["SpecialTargets"]=1,["WeaponFamily"]="Spear",["Family"]="Spear",["StandardDamage"]=18,["Damage"]=18,["SpecialDamage"]=27.0,["SpecialStamina"]=20,["SpecialCooldown"]=8},
 ["HuntingBow"] = {["Kind"]="Weapon",["Grade"]=1,["Durability"]=400,["DamageFactor"]=1.2,["AttackCycle"]=1.3,["Reach"]=1000,["Special"]="PiercingShot",["SpecialFactor"]=1.6,["SpecialTargets"]=2,["Ammo"]="Arrow",["WeaponFamily"]="Bow",["Family"]="Bow",["StandardDamage"]=18,["Damage"]=21.6,["SpecialDamage"]=28.8,["SpecialStamina"]=20,["SpecialCooldown"]=8},
 ["BoneKnife"] = {["Kind"]="Weapon",["Grade"]=1,["Durability"]=400,["DamageFactor"]=0.55,["AttackCycle"]=0.55,["Reach"]=6.5,["Special"]="QuickCut",["SpecialFactor"]=1.5,["SpecialTargets"]=1,["Slow"]=0.2,["SlowSeconds"]=3,["WeaponFamily"]="Dagger",["Family"]="Dagger",["StandardDamage"]=18,["Damage"]=9.9,["SpecialDamage"]=27.0,["SpecialStamina"]=20,["SpecialCooldown"]=8},
 ["SteelSword"] = {["Kind"]="Weapon",["Grade"]=2,["Durability"]=440,["DamageFactor"]=0.85,["AttackCycle"]=0.85,["Reach"]=8,["Special"]="Sweep",["SpecialFactor"]=1.1,["SpecialTargets"]=3,["WeaponFamily"]="Sword",["Family"]="Sword",["StandardDamage"]=36,["Damage"]=30.6,["SpecialDamage"]=39.6,["SpecialStamina"]=20,["SpecialCooldown"]=8},
 ["FrostSpear"] = {["Kind"]="Weapon",["Grade"]=2,["Durability"]=440,["DamageFactor"]=1,["AttackCycle"]=1,["Reach"]=9,["Special"]="FrostThrust",["SpecialFactor"]=1.5,["SpecialTargets"]=1,["WeaponFamily"]="Spear",["Family"]="Spear",["StandardDamage"]=36,["Damage"]=36,["SpecialDamage"]=54.0,["SpecialStamina"]=20,["SpecialCooldown"]=8,["Slow"]=0.2,["SlowSeconds"]=3},
 ["MarshBow"] = {["Kind"]="Weapon",["Grade"]=2,["Durability"]=440,["DamageFactor"]=1.2,["AttackCycle"]=1.3,["Reach"]=1000,["Special"]="PiercingShot",["SpecialFactor"]=1.6,["SpecialTargets"]=2,["Ammo"]="Arrow",["WeaponFamily"]="Bow",["Family"]="Bow",["StandardDamage"]=36,["Damage"]=43.2,["SpecialDamage"]=57.6,["SpecialStamina"]=20,["SpecialCooldown"]=8},
 ["EmberAxe"] = {["Kind"]="Weapon",["Grade"]=3,["Durability"]=480,["DamageFactor"]=1.2,["AttackCycle"]=1.2,["Reach"]=8,["Special"]="HeavyCleave",["SpecialFactor"]=1.6,["SpecialTargets"]=2,["Stagger"]=0.5,["WeaponFamily"]="Axe",["Family"]="Axe",["StandardDamage"]=72,["Damage"]=86.4,["SpecialDamage"]=115.2,["SpecialStamina"]=20,["SpecialCooldown"]=8,["SpecialDirectFactor"]=1.2,["DotFactor"]=0.4,["DotSeconds"]=4,["Dot"]="Burn"},
 ["CrystalStaff"] = {["Kind"]="Weapon",["Grade"]=3,["Durability"]=480,["DamageFactor"]=1,["AttackCycle"]=1.1,["Reach"]=50,["Special"]="Burst",["SpecialFactor"]=1.25,["SpecialTargets"]=6,["SpecialRadius"]=7,["BasicStamina"]=3,["WeaponFamily"]="Staff",["Family"]="Staff",["StandardDamage"]=72,["Damage"]=72,["SpecialDamage"]=90.0,["SpecialStamina"]=20,["SpecialCooldown"]=8},
 ["BlacksteelSword"] = {["Kind"]="Weapon",["Grade"]=3,["Durability"]=480,["DamageFactor"]=0.85,["AttackCycle"]=0.85,["Reach"]=8,["Special"]="Sweep",["SpecialFactor"]=1.1,["SpecialTargets"]=3,["WeaponFamily"]="Sword",["Family"]="Sword",["StandardDamage"]=72,["Damage"]=61.2,["SpecialDamage"]=79.2,["SpecialStamina"]=20,["SpecialCooldown"]=8},
 ["MeteorPike"] = {["Kind"]="Weapon",["Grade"]=4,["Durability"]=520,["DamageFactor"]=1,["AttackCycle"]=1,["Reach"]=9,["Special"]="Lunge",["SpecialFactor"]=1.5,["SpecialTargets"]=1,["WeaponFamily"]="Spear",["Family"]="Spear",["StandardDamage"]=144,["Damage"]=144,["SpecialDamage"]=216.0,["SpecialStamina"]=20,["SpecialCooldown"]=8},
 ["DawnBow"] = {["Kind"]="Weapon",["Grade"]=4,["Durability"]=520,["DamageFactor"]=1.2,["AttackCycle"]=1.3,["Reach"]=1000,["Special"]="PiercingShot",["SpecialFactor"]=1.6,["SpecialTargets"]=2,["Ammo"]="Arrow",["WeaponFamily"]="Bow",["Family"]="Bow",["StandardDamage"]=144,["Damage"]=172.8,["SpecialDamage"]=230.4,["SpecialStamina"]=20,["SpecialCooldown"]=8},
 ["CraterHammer"] = {["Kind"]="Weapon",["Grade"]=4,["Durability"]=520,["DamageFactor"]=1.65,["AttackCycle"]=1.65,["Reach"]=8,["Special"]="GroundSlam",["SpecialFactor"]=1.3,["SpecialTargets"]=6,["SpecialRadius"]=10,["Stagger"]=0.7,["WeaponFamily"]="Hammer",["Family"]="Hammer",["StandardDamage"]=144,["Damage"]=237.6,["SpecialDamage"]=187.2,["SpecialStamina"]=20,["SpecialCooldown"]=8},
 ["ThunderHammer"] = {["Kind"]="Weapon",["Grade"]=5,["Durability"]=560,["DamageFactor"]=1.65,["AttackCycle"]=1.65,["Reach"]=8,["Special"]="GroundSlam",["SpecialFactor"]=1.3,["SpecialTargets"]=6,["SpecialRadius"]=10,["Stagger"]=0.7,["WeaponFamily"]="Hammer",["Family"]="Hammer",["StandardDamage"]=288,["Damage"]=475.2,["SpecialDamage"]=374.4,["SpecialStamina"]=20,["SpecialCooldown"]=8},
 ["TideSpear"] = {["Kind"]="Weapon",["Grade"]=5,["Durability"]=560,["DamageFactor"]=1,["AttackCycle"]=1,["Reach"]=9,["Special"]="Lunge",["SpecialFactor"]=1.5,["SpecialTargets"]=1,["WeaponFamily"]="Spear",["Family"]="Spear",["StandardDamage"]=288,["Damage"]=288,["SpecialDamage"]=432.0,["SpecialStamina"]=20,["SpecialCooldown"]=8},
 ["StormBow"] = {["Kind"]="Weapon",["Grade"]=5,["Durability"]=560,["DamageFactor"]=1.2,["AttackCycle"]=1.3,["Reach"]=1000,["Special"]="PiercingShot",["SpecialFactor"]=1.6,["SpecialTargets"]=2,["Ammo"]="Arrow",["WeaponFamily"]="Bow",["Family"]="Bow",["StandardDamage"]=288,["Damage"]=345.6,["SpecialDamage"]=460.8,["SpecialStamina"]=20,["SpecialCooldown"]=8,["SpecialDirectFactor"]=1.2,["ChainFactor"]=0.4,["ChainTargets"]=1},
 ["ThornBlade"] = {["Kind"]="Weapon",["Grade"]=6,["Durability"]=600,["DamageFactor"]=0.85,["AttackCycle"]=0.85,["Reach"]=8,["Special"]="Sweep",["SpecialFactor"]=1.1,["SpecialTargets"]=3,["WeaponFamily"]="Sword",["Family"]="Sword",["StandardDamage"]=576,["Damage"]=489.6,["SpecialDamage"]=633.6,["SpecialStamina"]=20,["SpecialCooldown"]=8,["SpecialDirectFactor"]=0.8,["DotFactor"]=0.3,["DotSeconds"]=3,["Dot"]="Bleed"},
 ["IronwoodBow"] = {["Kind"]="Weapon",["Grade"]=6,["Durability"]=600,["DamageFactor"]=1.2,["AttackCycle"]=1.3,["Reach"]=1000,["Special"]="PiercingShot",["SpecialFactor"]=1.6,["SpecialTargets"]=2,["Ammo"]="Arrow",["WeaponFamily"]="Bow",["Family"]="Bow",["StandardDamage"]=576,["Damage"]=691.2,["SpecialDamage"]=921.6,["SpecialStamina"]=20,["SpecialCooldown"]=8},
 ["RootStaff"] = {["Kind"]="Weapon",["Grade"]=6,["Durability"]=600,["DamageFactor"]=1,["AttackCycle"]=1.1,["Reach"]=50,["Special"]="Burst",["SpecialFactor"]=1.25,["SpecialTargets"]=6,["SpecialRadius"]=7,["BasicStamina"]=3,["WeaponFamily"]="Staff",["Family"]="Staff",["StandardDamage"]=576,["Damage"]=576,["SpecialDamage"]=720.0,["SpecialStamina"]=20,["SpecialCooldown"]=8,["Slow"]=0.2,["SlowSeconds"]=3},
 ["DeepsteelSword"] = {["Kind"]="Weapon",["Grade"]=7,["Durability"]=640,["DamageFactor"]=0.85,["AttackCycle"]=0.85,["Reach"]=8,["Special"]="Sweep",["SpecialFactor"]=1.1,["SpecialTargets"]=3,["WeaponFamily"]="Sword",["Family"]="Sword",["StandardDamage"]=1152,["Damage"]=979.2,["SpecialDamage"]=1267.2,["SpecialStamina"]=20,["SpecialCooldown"]=8},
 ["LanternStaff"] = {["Kind"]="Weapon",["Grade"]=7,["Durability"]=640,["DamageFactor"]=1,["AttackCycle"]=1.1,["Reach"]=50,["Special"]="Burst",["SpecialFactor"]=1.25,["SpecialTargets"]=6,["SpecialRadius"]=7,["BasicStamina"]=3,["WeaponFamily"]="Staff",["Family"]="Staff",["StandardDamage"]=1152,["Damage"]=1152,["SpecialDamage"]=1440.0,["SpecialStamina"]=20,["SpecialCooldown"]=8,["IlluminateSeconds"]=8},
 ["SkySpear"] = {["Kind"]="Weapon",["Grade"]=7,["Durability"]=640,["DamageFactor"]=1,["AttackCycle"]=1,["Reach"]=9,["Special"]="Lunge",["SpecialFactor"]=1.5,["SpecialTargets"]=1,["WeaponFamily"]="Spear",["Family"]="Spear",["StandardDamage"]=1152,["Damage"]=1152,["SpecialDamage"]=1728.0,["SpecialStamina"]=20,["SpecialCooldown"]=8},
 ["Moonblade"] = {["Kind"]="Weapon",["Grade"]=8,["Durability"]=680,["DamageFactor"]=0.85,["AttackCycle"]=0.85,["Reach"]=8,["Special"]="Sweep",["SpecialFactor"]=1.1,["SpecialTargets"]=3,["WeaponFamily"]="Sword",["Family"]="Sword",["StandardDamage"]=2304,["Damage"]=1958.4,["SpecialDamage"]=2534.4,["SpecialStamina"]=20,["SpecialCooldown"]=8},
 ["StarBow"] = {["Kind"]="Weapon",["Grade"]=8,["Durability"]=680,["DamageFactor"]=1.2,["AttackCycle"]=1.3,["Reach"]=1000,["Special"]="PiercingShot",["SpecialFactor"]=1.6,["SpecialTargets"]=2,["Ammo"]="Arrow",["WeaponFamily"]="Bow",["Family"]="Bow",["StandardDamage"]=2304,["Damage"]=2764.8,["SpecialDamage"]=3686.4,["SpecialStamina"]=20,["SpecialCooldown"]=8},
 ["GravityHammer"] = {["Kind"]="Weapon",["Grade"]=8,["Durability"]=680,["DamageFactor"]=1.65,["AttackCycle"]=1.65,["Reach"]=8,["Special"]="GroundSlam",["SpecialFactor"]=1.3,["SpecialTargets"]=6,["SpecialRadius"]=10,["Stagger"]=0.7,["WeaponFamily"]="Hammer",["Family"]="Hammer",["StandardDamage"]=2304,["Damage"]=3801.6,["SpecialDamage"]=2995.2,["SpecialStamina"]=20,["SpecialCooldown"]=8,["PullStuds"]=2},
 ["StoneAxe"] = {["Kind"]="Tool",["Grade"]=1,["Durability"]=300,["ToolFamily"]="Axe",["Family"]="Axe",["Power"]=40,["AttackCycle"]=0.55,["Damage"]=6,["Reach"]=8},
 ["StonePickaxe"] = {["Kind"]="Tool",["Grade"]=1,["Durability"]=300,["ToolFamily"]="Pickaxe",["Family"]="Pickaxe",["Power"]=40,["AttackCycle"]=0.55,["Damage"]=6,["Reach"]=8},
 ["SteelAxe"] = {["Kind"]="Tool",["Grade"]=2,["Durability"]=340,["ToolFamily"]="Axe",["Family"]="Axe",["Power"]=80,["AttackCycle"]=0.55,["Damage"]=6,["Reach"]=8},
 ["SteelPickaxe"] = {["Kind"]="Tool",["Grade"]=2,["Durability"]=340,["ToolFamily"]="Pickaxe",["Family"]="Pickaxe",["Power"]=80,["AttackCycle"]=0.55,["Damage"]=6,["Reach"]=8},
 ["BlacksteelAxe"] = {["Kind"]="Tool",["Grade"]=3,["Durability"]=380,["ToolFamily"]="Axe",["Family"]="Axe",["Power"]=160,["AttackCycle"]=0.55,["Damage"]=6,["Reach"]=8},
 ["BlacksteelPickaxe"] = {["Kind"]="Tool",["Grade"]=3,["Durability"]=380,["ToolFamily"]="Pickaxe",["Family"]="Pickaxe",["Power"]=160,["AttackCycle"]=0.55,["Damage"]=6,["Reach"]=8},
 ["MeteorAxe"] = {["Kind"]="Tool",["Grade"]=4,["Durability"]=420,["ToolFamily"]="Axe",["Family"]="Axe",["Power"]=320,["AttackCycle"]=0.55,["Damage"]=6,["Reach"]=8},
 ["MeteorPickaxe"] = {["Kind"]="Tool",["Grade"]=4,["Durability"]=420,["ToolFamily"]="Pickaxe",["Family"]="Pickaxe",["Power"]=320,["AttackCycle"]=0.55,["Damage"]=6,["Reach"]=8},
 ["StormAxe"] = {["Kind"]="Tool",["Grade"]=5,["Durability"]=460,["ToolFamily"]="Axe",["Family"]="Axe",["Power"]=640,["AttackCycle"]=0.55,["Damage"]=6,["Reach"]=8},
 ["StormPickaxe"] = {["Kind"]="Tool",["Grade"]=5,["Durability"]=460,["ToolFamily"]="Pickaxe",["Family"]="Pickaxe",["Power"]=640,["AttackCycle"]=0.55,["Damage"]=6,["Reach"]=8},
 ["IronwoodAxe"] = {["Kind"]="Tool",["Grade"]=6,["Durability"]=500,["ToolFamily"]="Axe",["Family"]="Axe",["Power"]=1280,["AttackCycle"]=0.55,["Damage"]=6,["Reach"]=8},
 ["ReinforcedPickaxe"] = {["Kind"]="Tool",["Grade"]=6,["Durability"]=500,["ToolFamily"]="Pickaxe",["Family"]="Pickaxe",["Power"]=1280,["AttackCycle"]=0.55,["Damage"]=6,["Reach"]=8},
 ["DeepAxe"] = {["Kind"]="Tool",["Grade"]=7,["Durability"]=540,["ToolFamily"]="Axe",["Family"]="Axe",["Power"]=2560,["AttackCycle"]=0.55,["Damage"]=6,["Reach"]=8},
 ["DeepPickaxe"] = {["Kind"]="Tool",["Grade"]=7,["Durability"]=540,["ToolFamily"]="Pickaxe",["Family"]="Pickaxe",["Power"]=2560,["AttackCycle"]=0.55,["Damage"]=6,["Reach"]=8},
 ["MoonAxe"] = {["Kind"]="Tool",["Grade"]=8,["Durability"]=580,["ToolFamily"]="Axe",["Family"]="Axe",["Power"]=5120,["AttackCycle"]=0.55,["Damage"]=6,["Reach"]=8},
 ["MoonPickaxe"] = {["Kind"]="Tool",["Grade"]=8,["Durability"]=580,["ToolFamily"]="Pickaxe",["Family"]="Pickaxe",["Power"]=5120,["AttackCycle"]=0.55,["Damage"]=6,["Reach"]=8},
 ["GardenSickle"] = {["Kind"]="Tool",["Grade"]=2,["Durability"]=340,["ToolFamily"]="Sickle",["Family"]="Sickle",["Power"]=20,["GatherDurationReduction"]=0.15,["HandGatherReduction"]=0.15,["AttackCycle"]=0.55,["Damage"]=6,["Reach"]=8},
 ["FieldSickle"] = {["Kind"]="Tool",["Grade"]=5,["Durability"]=460,["ToolFamily"]="Sickle",["Family"]="Sickle",["Power"]=20,["GatherDurationReduction"]=0.25,["HandGatherReduction"]=0.25,["AttackCycle"]=0.55,["Damage"]=6,["Reach"]=8},
 ["ExpeditionTool"] = {["Kind"]="Tool",["Grade"]=8,["Durability"]=580,["ToolFamily"]="Universal",["Family"]="Universal",["Power"]=5120,["GatherDurationReduction"]=0.25,["HandGatherReduction"]=0.25,["AttackCycle"]=0.55,["Damage"]=6,["Reach"]=8},
 ["Harvester"] = {["Kind"]="Tool",["Grade"]=1,["Durability"]=300,["ToolFamily"]="Universal",["Family"]="Universal",["Power"]=20,["AttackCycle"]=0.6,["Damage"]=6,["Reach"]=8,["Starter"]=true},
 ["TrailHood"] = {["Kind"]="Armor",["Grade"]=1,["Durability"]=180,["Slot"]="Head",["Set"]="Trail",["Family"]="Trail",["PieceShare"]=0.2,["Resistance"]={["Wet"]=0.06},["Defense"]=0.016,["MaterialCost"]=2,["ClothCost"]=3},
 ["TrailCoat"] = {["Kind"]="Armor",["Grade"]=1,["Durability"]=180,["Slot"]="Chest",["Set"]="Trail",["Family"]="Trail",["PieceShare"]=0.35,["Resistance"]={["Wet"]=0.105},["Defense"]=0.028,["MaterialCost"]=4,["ClothCost"]=5},
 ["TrailTrousers"] = {["Kind"]="Armor",["Grade"]=1,["Durability"]=180,["Slot"]="Legs",["Set"]="Trail",["Family"]="Trail",["PieceShare"]=0.3,["Resistance"]={["Wet"]=0.09},["Defense"]=0.024,["MaterialCost"]=3,["ClothCost"]=4},
 ["TrailBoots"] = {["Kind"]="Armor",["Grade"]=1,["Durability"]=180,["Slot"]="Boots",["Set"]="Trail",["Family"]="Trail",["PieceShare"]=0.15,["Resistance"]={["Wet"]=0.045},["Defense"]=0.012,["MaterialCost"]=2,["ClothCost"]=2},
 ["DuneHood"] = {["Kind"]="Armor",["Grade"]=1,["Durability"]=180,["Slot"]="Head",["Set"]="Dune",["Family"]="Dune",["PieceShare"]=0.2,["Resistance"]={["Heat"]=0.17,["Wet"]=0.020000000000000004},["Defense"]=0.016,["MaterialCost"]=2,["ClothCost"]=3},
 ["DuneCoat"] = {["Kind"]="Armor",["Grade"]=1,["Durability"]=180,["Slot"]="Chest",["Set"]="Dune",["Family"]="Dune",["PieceShare"]=0.35,["Resistance"]={["Heat"]=0.2975,["Wet"]=0.034999999999999996},["Defense"]=0.028,["MaterialCost"]=4,["ClothCost"]=5},
 ["DuneTrousers"] = {["Kind"]="Armor",["Grade"]=1,["Durability"]=180,["Slot"]="Legs",["Set"]="Dune",["Family"]="Dune",["PieceShare"]=0.3,["Resistance"]={["Heat"]=0.255,["Wet"]=0.03},["Defense"]=0.024,["MaterialCost"]=3,["ClothCost"]=4},
 ["DuneBoots"] = {["Kind"]="Armor",["Grade"]=1,["Durability"]=180,["Slot"]="Boots",["Set"]="Dune",["Family"]="Dune",["PieceShare"]=0.15,["Resistance"]={["Heat"]=0.1275,["Wet"]=0.015},["Defense"]=0.012,["MaterialCost"]=2,["ClothCost"]=2},
 ["MarshHood"] = {["Kind"]="Armor",["Grade"]=2,["Durability"]=205,["Slot"]="Head",["Set"]="Marsh",["Family"]="Marsh",["PieceShare"]=0.2,["Resistance"]={["Toxin"]=0.16000000000000003,["Wet"]=0.17},["Defense"]=0.036,["MaterialCost"]=2,["ClothCost"]=3},
 ["MarshCoat"] = {["Kind"]="Armor",["Grade"]=2,["Durability"]=205,["Slot"]="Chest",["Set"]="Marsh",["Family"]="Marsh",["PieceShare"]=0.35,["Resistance"]={["Toxin"]=0.27999999999999997,["Wet"]=0.2975},["Defense"]=0.063,["MaterialCost"]=4,["ClothCost"]=5},
 ["MarshTrousers"] = {["Kind"]="Armor",["Grade"]=2,["Durability"]=205,["Slot"]="Legs",["Set"]="Marsh",["Family"]="Marsh",["PieceShare"]=0.3,["Resistance"]={["Toxin"]=0.24,["Wet"]=0.255},["Defense"]=0.054,["MaterialCost"]=3,["ClothCost"]=4},
 ["MarshBoots"] = {["Kind"]="Armor",["Grade"]=2,["Durability"]=205,["Slot"]="Boots",["Set"]="Marsh",["Family"]="Marsh",["PieceShare"]=0.15,["Resistance"]={["Toxin"]=0.12,["Wet"]=0.1275},["Defense"]=0.027,["MaterialCost"]=2,["ClothCost"]=2},
 ["FrostHood"] = {["Kind"]="Armor",["Grade"]=2,["Durability"]=205,["Slot"]="Head",["Set"]="Frost",["Family"]="Frost",["PieceShare"]=0.2,["Resistance"]={["Cold"]=0.17,["Wet"]=0.08000000000000002},["Defense"]=0.036,["MaterialCost"]=2,["ClothCost"]=3},
 ["FrostCoat"] = {["Kind"]="Armor",["Grade"]=2,["Durability"]=205,["Slot"]="Chest",["Set"]="Frost",["Family"]="Frost",["PieceShare"]=0.35,["Resistance"]={["Cold"]=0.2975,["Wet"]=0.13999999999999999},["Defense"]=0.063,["MaterialCost"]=4,["ClothCost"]=5},
 ["FrostTrousers"] = {["Kind"]="Armor",["Grade"]=2,["Durability"]=205,["Slot"]="Legs",["Set"]="Frost",["Family"]="Frost",["PieceShare"]=0.3,["Resistance"]={["Cold"]=0.255,["Wet"]=0.12},["Defense"]=0.054,["MaterialCost"]=3,["ClothCost"]=4},
 ["FrostBoots"] = {["Kind"]="Armor",["Grade"]=2,["Durability"]=205,["Slot"]="Boots",["Set"]="Frost",["Family"]="Frost",["PieceShare"]=0.15,["Resistance"]={["Cold"]=0.1275,["Wet"]=0.06},["Defense"]=0.027,["MaterialCost"]=2,["ClothCost"]=2},
 ["AshHood"] = {["Kind"]="Armor",["Grade"]=3,["Durability"]=230,["Slot"]="Head",["Set"]="Ash",["Family"]="Ash",["PieceShare"]=0.2,["Resistance"]={["Heat"]=0.17,["Toxin"]=0.08000000000000002},["Defense"]=0.06,["MaterialCost"]=2,["ClothCost"]=3},
 ["AshCoat"] = {["Kind"]="Armor",["Grade"]=3,["Durability"]=230,["Slot"]="Chest",["Set"]="Ash",["Family"]="Ash",["PieceShare"]=0.35,["Resistance"]={["Heat"]=0.2975,["Toxin"]=0.13999999999999999},["Defense"]=0.105,["MaterialCost"]=4,["ClothCost"]=5},
 ["AshTrousers"] = {["Kind"]="Armor",["Grade"]=3,["Durability"]=230,["Slot"]="Legs",["Set"]="Ash",["Family"]="Ash",["PieceShare"]=0.3,["Resistance"]={["Heat"]=0.255,["Toxin"]=0.12},["Defense"]=0.09,["MaterialCost"]=3,["ClothCost"]=4},
 ["AshBoots"] = {["Kind"]="Armor",["Grade"]=3,["Durability"]=230,["Slot"]="Boots",["Set"]="Ash",["Family"]="Ash",["PieceShare"]=0.15,["Resistance"]={["Heat"]=0.1275,["Toxin"]=0.06},["Defense"]=0.045,["MaterialCost"]=2,["ClothCost"]=2},
 ["CrystalHood"] = {["Kind"]="Armor",["Grade"]=3,["Durability"]=230,["Slot"]="Head",["Set"]="Crystal",["Family"]="Crystal",["PieceShare"]=0.2,["Resistance"]={["Heat"]=0.08000000000000002,["Cold"]=0.08000000000000002,["Toxin"]=0.1},["Defense"]=0.06,["MaterialCost"]=2,["ClothCost"]=3},
 ["CrystalCoat"] = {["Kind"]="Armor",["Grade"]=3,["Durability"]=230,["Slot"]="Chest",["Set"]="Crystal",["Family"]="Crystal",["PieceShare"]=0.35,["Resistance"]={["Heat"]=0.13999999999999999,["Cold"]=0.13999999999999999,["Toxin"]=0.175},["Defense"]=0.105,["MaterialCost"]=4,["ClothCost"]=5},
 ["CrystalTrousers"] = {["Kind"]="Armor",["Grade"]=3,["Durability"]=230,["Slot"]="Legs",["Set"]="Crystal",["Family"]="Crystal",["PieceShare"]=0.3,["Resistance"]={["Heat"]=0.12,["Cold"]=0.12,["Toxin"]=0.15},["Defense"]=0.09,["MaterialCost"]=3,["ClothCost"]=4},
 ["CrystalBoots"] = {["Kind"]="Armor",["Grade"]=3,["Durability"]=230,["Slot"]="Boots",["Set"]="Crystal",["Family"]="Crystal",["PieceShare"]=0.15,["Resistance"]={["Heat"]=0.06,["Cold"]=0.06,["Toxin"]=0.075},["Defense"]=0.045,["MaterialCost"]=2,["ClothCost"]=2},
 ["AuroraHood"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Head",["Set"]="Aurora",["Family"]="Aurora",["PieceShare"]=0.2,["Resistance"]={["Heat"]=0.13999999999999999,["Cold"]=0.13999999999999999,["Wet"]=0.08000000000000002},["Defense"]=0.084,["MaterialCost"]=2,["ClothCost"]=3},
 ["AuroraCoat"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Chest",["Set"]="Aurora",["Family"]="Aurora",["PieceShare"]=0.35,["Resistance"]={["Heat"]=0.24499999999999997,["Cold"]=0.24499999999999997,["Wet"]=0.13999999999999999},["Defense"]=0.147,["MaterialCost"]=4,["ClothCost"]=5},
 ["AuroraTrousers"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Legs",["Set"]="Aurora",["Family"]="Aurora",["PieceShare"]=0.3,["Resistance"]={["Heat"]=0.21,["Cold"]=0.21,["Wet"]=0.12},["Defense"]=0.126,["MaterialCost"]=3,["ClothCost"]=4},
 ["AuroraBoots"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Boots",["Set"]="Aurora",["Family"]="Aurora",["PieceShare"]=0.15,["Resistance"]={["Heat"]=0.105,["Cold"]=0.105,["Wet"]=0.06},["Defense"]=0.063,["MaterialCost"]=2,["ClothCost"]=2},
 ["MeteorHood"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Head",["Set"]="Meteor",["Family"]="Meteor",["PieceShare"]=0.2,["Resistance"]={["Heat"]=0.15000000000000002,["Cold"]=0.08000000000000002,["Wet"]=0.08000000000000002},["Defense"]=0.084,["MaterialCost"]=2,["ClothCost"]=3},
 ["MeteorCoat"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Chest",["Set"]="Meteor",["Family"]="Meteor",["PieceShare"]=0.35,["Resistance"]={["Heat"]=0.26249999999999996,["Cold"]=0.13999999999999999,["Wet"]=0.13999999999999999},["Defense"]=0.147,["MaterialCost"]=4,["ClothCost"]=5},
 ["MeteorTrousers"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Legs",["Set"]="Meteor",["Family"]="Meteor",["PieceShare"]=0.3,["Resistance"]={["Heat"]=0.22499999999999998,["Cold"]=0.12,["Wet"]=0.12},["Defense"]=0.126,["MaterialCost"]=3,["ClothCost"]=4},
 ["MeteorBoots"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Boots",["Set"]="Meteor",["Family"]="Meteor",["PieceShare"]=0.15,["Resistance"]={["Heat"]=0.11249999999999999,["Cold"]=0.06,["Wet"]=0.06},["Defense"]=0.063,["MaterialCost"]=2,["ClothCost"]=2},
 ["CoastHood"] = {["Kind"]="Armor",["Grade"]=2,["Durability"]=205,["Slot"]="Head",["Set"]="Coast",["Family"]="Coast",["PieceShare"]=0.2,["Resistance"]={["Wet"]=0.17,["Cold"]=0.06999999999999999},["Defense"]=0.036,["MaterialCost"]=2,["ClothCost"]=3},
 ["CoastCoat"] = {["Kind"]="Armor",["Grade"]=2,["Durability"]=205,["Slot"]="Chest",["Set"]="Coast",["Family"]="Coast",["PieceShare"]=0.35,["Resistance"]={["Wet"]=0.2975,["Cold"]=0.12249999999999998},["Defense"]=0.063,["MaterialCost"]=4,["ClothCost"]=5},
 ["CoastTrousers"] = {["Kind"]="Armor",["Grade"]=2,["Durability"]=205,["Slot"]="Legs",["Set"]="Coast",["Family"]="Coast",["PieceShare"]=0.3,["Resistance"]={["Wet"]=0.255,["Cold"]=0.105},["Defense"]=0.054,["MaterialCost"]=3,["ClothCost"]=4},
 ["CoastBoots"] = {["Kind"]="Armor",["Grade"]=2,["Durability"]=205,["Slot"]="Boots",["Set"]="Coast",["Family"]="Coast",["PieceShare"]=0.15,["Resistance"]={["Wet"]=0.1275,["Cold"]=0.0525},["Defense"]=0.027,["MaterialCost"]=2,["ClothCost"]=2},
 ["StormHood"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Head",["Set"]="Storm",["Family"]="Storm",["PieceShare"]=0.2,["Resistance"]={["Wet"]=0.16000000000000003,["Cold"]=0.11000000000000001},["Defense"]=0.084,["MaterialCost"]=2,["ClothCost"]=3},
 ["StormCoat"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Chest",["Set"]="Storm",["Family"]="Storm",["PieceShare"]=0.35,["Resistance"]={["Wet"]=0.27999999999999997,["Cold"]=0.1925},["Defense"]=0.147,["MaterialCost"]=4,["ClothCost"]=5},
 ["StormTrousers"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Legs",["Set"]="Storm",["Family"]="Storm",["PieceShare"]=0.3,["Resistance"]={["Wet"]=0.24,["Cold"]=0.165},["Defense"]=0.126,["MaterialCost"]=3,["ClothCost"]=4},
 ["StormBoots"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Boots",["Set"]="Storm",["Family"]="Storm",["PieceShare"]=0.15,["Resistance"]={["Wet"]=0.12,["Cold"]=0.0825},["Defense"]=0.063,["MaterialCost"]=2,["ClothCost"]=2},
 ["GardenHood"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Head",["Set"]="Garden",["Family"]="Garden",["PieceShare"]=0.2,["Resistance"]={["Toxin"]=0.16000000000000003,["Wet"]=0.12},["Defense"]=0.084,["MaterialCost"]=2,["ClothCost"]=3},
 ["GardenCoat"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Chest",["Set"]="Garden",["Family"]="Garden",["PieceShare"]=0.35,["Resistance"]={["Toxin"]=0.27999999999999997,["Wet"]=0.21},["Defense"]=0.147,["MaterialCost"]=4,["ClothCost"]=5},
 ["GardenTrousers"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Legs",["Set"]="Garden",["Family"]="Garden",["PieceShare"]=0.3,["Resistance"]={["Toxin"]=0.24,["Wet"]=0.18},["Defense"]=0.126,["MaterialCost"]=3,["ClothCost"]=4},
 ["GardenBoots"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Boots",["Set"]="Garden",["Family"]="Garden",["PieceShare"]=0.15,["Resistance"]={["Toxin"]=0.12,["Wet"]=0.09},["Defense"]=0.063,["MaterialCost"]=2,["ClothCost"]=2},
 ["IronHood"] = {["Kind"]="Armor",["Grade"]=3,["Durability"]=230,["Slot"]="Head",["Set"]="Iron",["Family"]="Iron",["PieceShare"]=0.2,["Resistance"]={["Heat"]=0.09000000000000001,["Toxin"]=0.06999999999999999},["Defense"]=0.06,["MaterialCost"]=2,["ClothCost"]=3},
 ["IronCoat"] = {["Kind"]="Armor",["Grade"]=3,["Durability"]=230,["Slot"]="Chest",["Set"]="Iron",["Family"]="Iron",["PieceShare"]=0.35,["Resistance"]={["Heat"]=0.1575,["Toxin"]=0.12249999999999998},["Defense"]=0.105,["MaterialCost"]=4,["ClothCost"]=5},
 ["IronTrousers"] = {["Kind"]="Armor",["Grade"]=3,["Durability"]=230,["Slot"]="Legs",["Set"]="Iron",["Family"]="Iron",["PieceShare"]=0.3,["Resistance"]={["Heat"]=0.135,["Toxin"]=0.105},["Defense"]=0.09,["MaterialCost"]=3,["ClothCost"]=4},
 ["IronBoots"] = {["Kind"]="Armor",["Grade"]=3,["Durability"]=230,["Slot"]="Boots",["Set"]="Iron",["Family"]="Iron",["PieceShare"]=0.15,["Resistance"]={["Heat"]=0.0675,["Toxin"]=0.0525},["Defense"]=0.045,["MaterialCost"]=2,["ClothCost"]=2},
 ["CanopyHood"] = {["Kind"]="Armor",["Grade"]=2,["Durability"]=205,["Slot"]="Head",["Set"]="Canopy",["Family"]="Canopy",["PieceShare"]=0.2,["Resistance"]={["Wet"]=0.13,["Cold"]=0.05},["Defense"]=0.036,["MaterialCost"]=2,["ClothCost"]=3},
 ["CanopyCoat"] = {["Kind"]="Armor",["Grade"]=2,["Durability"]=205,["Slot"]="Chest",["Set"]="Canopy",["Family"]="Canopy",["PieceShare"]=0.35,["Resistance"]={["Wet"]=0.22749999999999998,["Cold"]=0.0875},["Defense"]=0.063,["MaterialCost"]=4,["ClothCost"]=5},
 ["CanopyTrousers"] = {["Kind"]="Armor",["Grade"]=2,["Durability"]=205,["Slot"]="Legs",["Set"]="Canopy",["Family"]="Canopy",["PieceShare"]=0.3,["Resistance"]={["Wet"]=0.195,["Cold"]=0.075},["Defense"]=0.054,["MaterialCost"]=3,["ClothCost"]=4},
 ["CanopyBoots"] = {["Kind"]="Armor",["Grade"]=2,["Durability"]=205,["Slot"]="Boots",["Set"]="Canopy",["Family"]="Canopy",["PieceShare"]=0.15,["Resistance"]={["Wet"]=0.0975,["Cold"]=0.0375},["Defense"]=0.027,["MaterialCost"]=2,["ClothCost"]=2},
 ["DiverHood"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Head",["Set"]="Diver",["Family"]="Diver",["PieceShare"]=0.2,["Resistance"]={["Wet"]=0.18000000000000002,["Cold"]=0.12},["Defense"]=0.084,["MaterialCost"]=2,["ClothCost"]=3},
 ["DiverCoat"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Chest",["Set"]="Diver",["Family"]="Diver",["PieceShare"]=0.35,["Resistance"]={["Wet"]=0.315,["Cold"]=0.21},["Defense"]=0.147,["MaterialCost"]=4,["ClothCost"]=5},
 ["DiverTrousers"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Legs",["Set"]="Diver",["Family"]="Diver",["PieceShare"]=0.3,["Resistance"]={["Wet"]=0.27,["Cold"]=0.18},["Defense"]=0.126,["MaterialCost"]=3,["ClothCost"]=4},
 ["DiverBoots"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Boots",["Set"]="Diver",["Family"]="Diver",["PieceShare"]=0.15,["Resistance"]={["Wet"]=0.135,["Cold"]=0.09},["Defense"]=0.063,["MaterialCost"]=2,["ClothCost"]=2},
 ["LanternHood"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Head",["Set"]="Lantern",["Family"]="Lantern",["PieceShare"]=0.2,["Resistance"]={["Cold"]=0.13,["Toxin"]=0.1},["Defense"]=0.084,["MaterialCost"]=2,["ClothCost"]=3},
 ["LanternCoat"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Chest",["Set"]="Lantern",["Family"]="Lantern",["PieceShare"]=0.35,["Resistance"]={["Cold"]=0.22749999999999998,["Toxin"]=0.175},["Defense"]=0.147,["MaterialCost"]=4,["ClothCost"]=5},
 ["LanternTrousers"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Legs",["Set"]="Lantern",["Family"]="Lantern",["PieceShare"]=0.3,["Resistance"]={["Cold"]=0.195,["Toxin"]=0.15},["Defense"]=0.126,["MaterialCost"]=3,["ClothCost"]=4},
 ["LanternBoots"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Boots",["Set"]="Lantern",["Family"]="Lantern",["PieceShare"]=0.15,["Resistance"]={["Cold"]=0.0975,["Toxin"]=0.075},["Defense"]=0.063,["MaterialCost"]=2,["ClothCost"]=2},
 ["MoonHood"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Head",["Set"]="Moon",["Family"]="Moon",["PieceShare"]=0.2,["Resistance"]={["Heat"]=0.12,["Cold"]=0.12,["Wet"]=0.05},["Defense"]=0.084,["MaterialCost"]=2,["ClothCost"]=3},
 ["MoonCoat"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Chest",["Set"]="Moon",["Family"]="Moon",["PieceShare"]=0.35,["Resistance"]={["Heat"]=0.21,["Cold"]=0.21,["Wet"]=0.0875},["Defense"]=0.147,["MaterialCost"]=4,["ClothCost"]=5},
 ["MoonTrousers"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Legs",["Set"]="Moon",["Family"]="Moon",["PieceShare"]=0.3,["Resistance"]={["Heat"]=0.18,["Cold"]=0.18,["Wet"]=0.075},["Defense"]=0.126,["MaterialCost"]=3,["ClothCost"]=4},
 ["MoonBoots"] = {["Kind"]="Armor",["Grade"]=4,["Durability"]=255,["Slot"]="Boots",["Set"]="Moon",["Family"]="Moon",["PieceShare"]=0.15,["Resistance"]={["Heat"]=0.09,["Cold"]=0.09,["Wet"]=0.0375},["Defense"]=0.063,["MaterialCost"]=2,["ClothCost"]=2},
 ["SunVest"] = {["Kind"]="Armor",["Grade"]=1,["Durability"]=180,["Slot"]="Chest",["Resistance"]={["Heat"]=0.75},["Defense"]=0.02,["MaterialCost"]=0,["ClothCost"]=0},
 ["DesertCoat"] = {["Kind"]="Armor",["Grade"]=2,["Durability"]=205,["Slot"]="Chest",["Resistance"]={["Heat"]=0.85},["Defense"]=0.06,["MaterialCost"]=2,["ClothCost"]=3},
 ["WarmScarf"] = {["Kind"]="Accessory",["Grade"]=1,["Durability"]=0,["Family"]="WarmScarf",["Modifiers"]={["ColdResistance"]=0.3,["EarlyColdException"]=true},["Description"]="+30 percentage points cold resistance for early preparation; special early item exception to the usual +15 accessory cap"},
 ["RainCape"] = {["Kind"]="Accessory",["Grade"]=1,["Durability"]=0,["Family"]="RainCape",["Modifiers"]={["WetResistance"]=0.15},["Description"]="+15 points wet resistance; reduces wetness buildup"},
 ["WaterFlask"] = {["Kind"]="Accessory",["Grade"]=1,["Durability"]=0,["Family"]="WaterFlask",["Modifiers"]={["WaterUses"]=5},["Description"]="Holds 5 Water uses. Hold it beside a river and press F to refill."},
 ["FilterMask"] = {["Kind"]="Accessory",["Grade"]=2,["Durability"]=0,["Family"]="FilterMask",["Modifiers"]={["ToxinResistance"]=0.15},["Description"]="+15 points toxin resistance"},
 ["IceCleats"] = {["Kind"]="Accessory",["Grade"]=2,["Durability"]=0,["Family"]="IceCleats",["Modifiers"]={["IceGrip"]=true},["Description"]="Prevent ordinary ice sliding; no protection from visibly breaking ice"},
 ["ClimbingGloves"] = {["Kind"]="Accessory",["Grade"]=2,["Durability"]=0,["Family"]="ClimbingGloves",["Modifiers"]={["Climb"]=true,["ClimbDrain"]=8},["Description"]="Climb authored rough surfaces/ropes; costs 8 stamina/s"},
 ["SmallPack"] = {["Kind"]="Accessory",["Grade"]=2,["Durability"]=0,["Family"]="Pack",["Modifiers"]={["StorageSlots"]=6},["Description"]="+6 storage slots"},
 ["SpringBootsCharm"] = {["Kind"]="Accessory",["Grade"]=3,["Durability"]=0,["Family"]="SpringBootsCharm",["Modifiers"]={["DodgeCostReduction"]=5},["Description"]="Dodge costs 20 rather than 25 stamina"},
 ["HeatShield"] = {["Kind"]="Accessory",["Grade"]=3,["Durability"]=0,["Family"]="HeatShield",["Modifiers"]={["HeatResistance"]=0.15},["Description"]="+15 points heat resistance"},
 ["GatherersPouch"] = {["Kind"]="Accessory",["Grade"]=3,["Durability"]=0,["Family"]="GatherersPouch",["Modifiers"]={["PrimaryHarvestChance"]=0.1},["Description"]="+10% common primary harvest quantity, one roll per node; excludes rare drops"},
 ["SteadyGrip"] = {["Kind"]="Accessory",["Grade"]=3,["Durability"]=0,["Family"]="SteadyGrip",["Modifiers"]={["WeaponWearReduction"]=0.15},["Description"]="Weapon durability loss -15%"},
 ["Glider"] = {["Kind"]="Accessory",["Grade"]=4,["Durability"]=0,["Family"]="Glider",["Modifiers"]={["Glide"]=true,["GlideDrain"]=6},["Description"]="Controlled descent; never upward flight; 6 stamina/s"},
 ["AirTank"] = {["Kind"]="Accessory",["Grade"]=4,["Durability"]=0,["Family"]="AirTank",["Modifiers"]={["AirSeconds"]=120},["Description"]="120 seconds additional underwater air; refill at camp for Water ×1 + Coal ×1 and 10s work"},
 ["BrightLantern"] = {["Kind"]="Accessory",["Grade"]=4,["Durability"]=0,["Family"]="BrightLantern",["Modifiers"]={["LightRadius"]=24},["Description"]="Hands-free 24-stud light, no fuel; does not reveal unexplored map"},
 ["LargePack"] = {["Kind"]="Accessory",["Grade"]=4,["Durability"]=0,["Family"]="Pack",["Modifiers"]={["StorageSlots"]=12},["Description"]="+12 storage slots, replaces Small Pack"},
 ["CoolingRing"] = {["Kind"]="Accessory",["Grade"]=5,["Durability"]=0,["Family"]="CoolingRing",["Modifiers"]={["HeatRecoveryBonus"]=0.15},["Description"]="Natural heat recovery +15%"},
 ["WarmingRing"] = {["Kind"]="Accessory",["Grade"]=5,["Durability"]=0,["Family"]="WarmingRing",["Modifiers"]={["ColdRecoveryBonus"]=0.15},["Description"]="Natural cold recovery +15%"},
 ["HuntersCharm"] = {["Kind"]="Accessory",["Grade"]=5,["Durability"]=0,["Family"]="HuntersCharm",["Modifiers"]={["MonsterDamageBonus"]=0.08},["Description"]="+8% monster damage"},
 ["GroundingBelt"] = {["Kind"]="Accessory",["Grade"]=5,["Durability"]=0,["Family"]="GroundingBelt",["Modifiers"]={["LightningDamageReduction"]=0.2},["Description"]="Lightning damage -20%; combines multiplicatively with Storm set"},
 ["RepairPouch"] = {["Kind"]="Accessory",["Grade"]=6,["Durability"]=0,["Family"]="RepairPouch",["Modifiers"]={["FieldRepairBonus"]=0.1},["Description"]="Field repair restores 35% instead of 25% durability"},
 ["RescueCharm"] = {["Kind"]="Accessory",["Grade"]=6,["Durability"]=0,["Family"]="RescueCharm",["Modifiers"]={["ReviveDurationReduction"]=0.1},["Description"]="Revival Kit interaction 10% faster, respecting existing combined duration floor"},
 ["StrongGlider"] = {["Kind"]="Accessory",["Grade"]=7,["Durability"]=0,["Family"]="Glider",["Modifiers"]={["Glide"]=true,["GlideDrain"]=4,["GlideTurnBonus"]=0.25},["Description"]="Replaces Glider; stamina cost 4/s, improved turning"},
 ["DeepAirTank"] = {["Kind"]="Accessory",["Grade"]=7,["Durability"]=0,["Family"]="AirTank",["Modifiers"]={["AirSeconds"]=240},["Description"]="Replaces Air Tank; 240 seconds additional air"},
 ["ExpeditionPack"] = {["Kind"]="Accessory",["Grade"]=7,["Durability"]=0,["Family"]="Pack",["Modifiers"]={["StorageSlots"]=18},["Description"]="+18 storage slots, replaces Large Pack"},
 ["EchoCharm"] = {["Kind"]="Accessory",["Grade"]=7,["Durability"]=0,["Family"]="EchoCharm",["Modifiers"]={["AttackWarning"]=true},["Description"]="Brief on-screen direction cue when a nearby unseen monster makes an attack windup; no wall targeting"},
 ["GravityBelt"] = {["Kind"]="Accessory",["Grade"]=8,["Durability"]=0,["Family"]="GravityBelt",["Modifiers"]={["FallDamageReduction"]=0.4,["LowGravityControlBonus"]=0.35},["Description"]="Fall damage -40%; stabilizes low-gravity drift, no flight"},
 ["SurvivorsCharm"] = {["Kind"]="Accessory",["Grade"]=8,["Durability"]=0,["Family"]="SurvivorsCharm",["Modifiers"]={["SurvivorHeal"]=10,["SurvivorHealSeconds"]=5,["SurvivorCooldown"]=180,["SurvivorThreshold"]=25},["Description"]="Once per 180s, a nonlethal hit leaving HP below 25 restores 10 HP over 5s; cannot prevent death or revive"},
}
local gearNameOverrides={GatherersPouch="Gatherer's Pouch",HuntersCharm="Hunter's Charm",SurvivorsCharm="Survivor's Charm"}
for id,gear in pairs(C.Gear) do
 local kind=gear.Kind
 local tags=kind=="Weapon" and {"Weapon","Equipment","Holdable"} or kind=="Tool" and {"Tool","Equipment","Holdable"} or kind=="Armor" and {"Armor","Equipment"} or {"Accessory","Equipment"}
 C.Items[id]={Id=id,Name=gearNameOverrides[id] or id:gsub("(%l)(%u)","%1 %2"),Grade=gear.Grade,Tier=gear.Grade,StackSize=1,Tags=tags,Description=gear.Description or string.format("Grade %d %s.",gear.Grade,string.lower(kind)),Gear=gear}
end
C.Resources = {
 ["Wood"] = {["Id"]="Wood",["Kind"]="Wood",["Grade"]=1,["MiningGrade"]=1,["Biome"]="Common",["Depth"]="A",["Min"]=4,["Max"]=8,["Health"]=160,["LargeHealth"]=280},
 ["Stone"] = {["Id"]="Stone",["Kind"]="Mineral",["Grade"]=1,["MiningGrade"]=1,["Biome"]="Common",["Depth"]="A",["Min"]=4,["Max"]=8,["Health"]=200},
 ["Fiber"] = {["Id"]="Fiber",["Kind"]="Plant",["Grade"]=1,["MiningGrade"]=1,["Biome"]="Common",["Depth"]="A",["Min"]=4,["Max"]=8,["Duration"]=1.5},
 ["Resin"] = {["Id"]="Resin",["Kind"]="Wood",["Grade"]=1,["MiningGrade"]=1,["Biome"]="Common",["Depth"]="A",["Min"]=4,["Max"]=8,["Health"]=200},
 ["HealingHerb"] = {["Id"]="HealingHerb",["Kind"]="Plant",["Grade"]=1,["MiningGrade"]=1,["Biome"]="Common",["Depth"]="A",["Min"]=4,["Max"]=8,["Duration"]=1.5},
 ["Mushroom"] = {["Id"]="Mushroom",["Kind"]="Plant",["Grade"]=1,["MiningGrade"]=1,["Biome"]="Common",["Depth"]="A",["Min"]=4,["Max"]=8,["Duration"]=1.5},
 ["Water"] = {["Id"]="Water",["Kind"]="Liquid",["Grade"]=1,["MiningGrade"]=1,["Biome"]="Common",["Depth"]="A",["Min"]=4,["Max"]=8,["Duration"]=1},
 ["DirtyWater"] = {["Id"]="DirtyWater",["Kind"]="Liquid",["Grade"]=1,["MiningGrade"]=1,["Biome"]="Common",["Depth"]="A",["Min"]=4,["Max"]=8,["Duration"]=1},
 ["Coal"] = {["Id"]="Coal",["Kind"]="Mineral",["Grade"]=1,["MiningGrade"]=1,["Biome"]="Common",["Depth"]="A",["Min"]=4,["Max"]=8,["Health"]=200},
 ["RawMeat"] = {["Id"]="RawMeat",["Kind"]="Animal",["Grade"]=1,["MiningGrade"]=1,["Biome"]="Common",["Depth"]="A",["Min"]=4,["Max"]=8,["Health"]=200},
 ["Bone"] = {["Id"]="Bone",["Kind"]="Animal",["Grade"]=1,["MiningGrade"]=1,["Biome"]="Common",["Depth"]="A",["Min"]=4,["Max"]=8,["Health"]=200},
 ["WarmFur"] = {["Id"]="WarmFur",["Kind"]="Animal",["Grade"]=1,["MiningGrade"]=1,["Biome"]="Common",["Depth"]="A",["Min"]=4,["Max"]=8,["Health"]=200},
 ["Berries"] = {["Id"]="Berries",["Kind"]="Plant",["Grade"]=1,["MiningGrade"]=1,["Biome"]="Common",["Depth"]="A",["Min"]=4,["Max"]=8,["Duration"]=1.5},
 ["RootVegetable"] = {["Id"]="RootVegetable",["Kind"]="Plant",["Grade"]=1,["MiningGrade"]=1,["Biome"]="Common",["Depth"]="A",["Min"]=4,["Max"]=8,["Duration"]=1.5},
 ["DeepResin"] = {["Id"]="DeepResin",["Kind"]="Wood",["Grade"]=5,["MiningGrade"]=4,["Biome"]="Woodlands",["Depth"]="C",["Min"]=2,["Max"]=4,["Health"]=3200},
 ["IronOre"] = {["Id"]="IronOre",["Kind"]="Mineral",["Grade"]=2,["MiningGrade"]=1,["Biome"]="Dunes",["Depth"]="A",["Min"]=2,["Max"]=4,["Health"]=400},
 ["Sand"] = {["Id"]="Sand",["Kind"]="Mineral",["Grade"]=1,["MiningGrade"]=1,["Biome"]="Dunes",["Depth"]="A",["Min"]=2,["Max"]=4,["Health"]=200},
 ["Cactus"] = {["Id"]="Cactus",["Kind"]="Wood",["Grade"]=1,["MiningGrade"]=1,["Biome"]="Dunes",["Depth"]="B",["Min"]=2,["Max"]=4,["Health"]=160,["ContactDamage"]=4,["ContactCooldown"]=1},
 ["Sunstone"] = {["Id"]="Sunstone",["Kind"]="Mineral",["Grade"]=4,["MiningGrade"]=3,["Biome"]="Dunes",["Depth"]="C",["Min"]=2,["Max"]=4,["Health"]=1600},
 ["Reeds"] = {["Id"]="Reeds",["Kind"]="Plant",["Grade"]=1,["MiningGrade"]=1,["Biome"]="Marsh",["Depth"]="A",["Min"]=2,["Max"]=4,["Duration"]=2},
 ["Peat"] = {["Id"]="Peat",["Kind"]="Mineral",["Grade"]=2,["MiningGrade"]=1,["Biome"]="Marsh",["Depth"]="B",["Min"]=2,["Max"]=4,["Health"]=400},
 ["Glowcap"] = {["Id"]="Glowcap",["Kind"]="Plant",["Grade"]=2,["MiningGrade"]=1,["Biome"]="Marsh",["Depth"]="B",["Min"]=2,["Max"]=4,["Duration"]=1.5},
 ["VenomGland"] = {["Id"]="VenomGland",["Kind"]="Animal",["Grade"]=2,["MiningGrade"]=1,["Biome"]="Marsh",["Depth"]="A",["Min"]=2,["Max"]=4,["Health"]=400},
 ["IceCrystal"] = {["Id"]="IceCrystal",["Kind"]="Mineral",["Grade"]=2,["MiningGrade"]=1,["Biome"]="Tundra",["Depth"]="B",["Min"]=2,["Max"]=4,["Health"]=400},
 ["FrostBloom"] = {["Id"]="FrostBloom",["Kind"]="Plant",["Grade"]=4,["MiningGrade"]=3,["Biome"]="Tundra",["Depth"]="C",["Min"]=2,["Max"]=4,["Duration"]=2.5},
 ["BlackGlass"] = {["Id"]="BlackGlass",["Kind"]="Mineral",["Grade"]=3,["MiningGrade"]=2,["Biome"]="Volcanic Plains",["Depth"]="B",["Min"]=2,["Max"]=4,["Health"]=800},
 ["AshFiber"] = {["Id"]="AshFiber",["Kind"]="Plant",["Grade"]=3,["MiningGrade"]=2,["Biome"]="Volcanic Plains",["Depth"]="A",["Min"]=2,["Max"]=4,["Duration"]=1.5},
 ["Sulfur"] = {["Id"]="Sulfur",["Kind"]="Mineral",["Grade"]=3,["MiningGrade"]=2,["Biome"]="Volcanic Plains",["Depth"]="B",["Min"]=2,["Max"]=4,["Health"]=800},
 ["FireCore"] = {["Id"]="FireCore",["Kind"]="Mineral",["Grade"]=6,["MiningGrade"]=5,["Biome"]="Volcanic Plains",["Depth"]="D",["Min"]=2,["Max"]=4,["Health"]=6400},
 ["ClearCrystal"] = {["Id"]="ClearCrystal",["Kind"]="Mineral",["Grade"]=3,["MiningGrade"]=2,["Biome"]="Crystal Basin",["Depth"]="A",["Min"]=2,["Max"]=4,["Health"]=800},
 ["CrystalThread"] = {["Id"]="CrystalThread",["Kind"]="Plant",["Grade"]=3,["MiningGrade"]=2,["Biome"]="Crystal Basin",["Depth"]="B",["Min"]=2,["Max"]=4,["Duration"]=1.5},
 ["DarkDust"] = {["Id"]="DarkDust",["Kind"]="Mineral",["Grade"]=4,["MiningGrade"]=3,["Biome"]="Crystal Basin",["Depth"]="C",["Min"]=2,["Max"]=4,["Health"]=1600},
 ["GlowFiber"] = {["Id"]="GlowFiber",["Kind"]="Plant",["Grade"]=4,["MiningGrade"]=3,["Biome"]="Northern Valley",["Depth"]="A",["Min"]=2,["Max"]=4,["Duration"]=1.5},
 ["DawnFlower"] = {["Id"]="DawnFlower",["Kind"]="Plant",["Grade"]=4,["MiningGrade"]=3,["Biome"]="Northern Valley",["Depth"]="B",["Min"]=2,["Max"]=4,["Duration"]=2.5},
 ["AuroraStone"] = {["Id"]="AuroraStone",["Kind"]="Mineral",["Grade"]=4,["MiningGrade"]=3,["Biome"]="Northern Valley",["Depth"]="C",["Min"]=2,["Max"]=4,["Health"]=1600},
 ["ImpactGlass"] = {["Id"]="ImpactGlass",["Kind"]="Mineral",["Grade"]=4,["MiningGrade"]=3,["Biome"]="Meteor Crater",["Depth"]="A",["Min"]=2,["Max"]=4,["Health"]=1600},
 ["MeteorOre"] = {["Id"]="MeteorOre",["Kind"]="Mineral",["Grade"]=4,["MiningGrade"]=3,["Biome"]="Meteor Crater",["Depth"]="B",["Min"]=2,["Max"]=4,["Health"]=1600},
 ["StarCore"] = {["Id"]="StarCore",["Kind"]="Mineral",["Grade"]=4,["MiningGrade"]=3,["Biome"]="Meteor Crater",["Depth"]="C",["Min"]=2,["Max"]=4,["Health"]=1600},
 ["ShellPlate"] = {["Id"]="ShellPlate",["Kind"]="Mineral",["Grade"]=2,["MiningGrade"]=1,["Biome"]="Coast",["Depth"]="A",["Min"]=2,["Max"]=4,["Health"]=400},
 ["Salt"] = {["Id"]="Salt",["Kind"]="Mineral",["Grade"]=2,["MiningGrade"]=1,["Biome"]="Coast",["Depth"]="A",["Min"]=2,["Max"]=4,["Health"]=400},
 ["Kelp"] = {["Id"]="Kelp",["Kind"]="Plant",["Grade"]=2,["MiningGrade"]=1,["Biome"]="Coast",["Depth"]="B",["Min"]=2,["Max"]=4,["Duration"]=2},
 ["Pearl"] = {["Id"]="Pearl",["Kind"]="Mineral",["Grade"]=6,["MiningGrade"]=5,["Biome"]="Coast",["Depth"]="D",["Min"]=2,["Max"]=4,["Health"]=6400},
 ["CloudWool"] = {["Id"]="CloudWool",["Kind"]="Plant",["Grade"]=4,["MiningGrade"]=3,["Biome"]="Highlands",["Depth"]="A",["Min"]=2,["Max"]=4,["Duration"]=1.5},
 ["StormOre"] = {["Id"]="StormOre",["Kind"]="Mineral",["Grade"]=5,["MiningGrade"]=4,["Biome"]="Highlands",["Depth"]="B",["Min"]=2,["Max"]=4,["Health"]=3200},
 ["StormCore"] = {["Id"]="StormCore",["Kind"]="Mineral",["Grade"]=6,["MiningGrade"]=5,["Biome"]="Highlands",["Depth"]="D",["Min"]=2,["Max"]=4,["Health"]=6400},
 ["GlowMushroom"] = {["Id"]="GlowMushroom",["Kind"]="Plant",["Grade"]=3,["MiningGrade"]=2,["Biome"]="Mushroom Forest",["Depth"]="A",["Min"]=2,["Max"]=4,["Duration"]=1.5},
 ["ThickSpores"] = {["Id"]="ThickSpores",["Kind"]="Plant",["Grade"]=4,["MiningGrade"]=3,["Biome"]="Mushroom Forest",["Depth"]="B",["Min"]=2,["Max"]=4,["Duration"]=1.5},
 ["LivingRoot"] = {["Id"]="LivingRoot",["Kind"]="Plant",["Grade"]=4,["MiningGrade"]=3,["Biome"]="Mushroom Forest",["Depth"]="C",["Min"]=2,["Max"]=4,["Duration"]=1.5},
 ["Ironwood"] = {["Id"]="Ironwood",["Kind"]="Wood",["Grade"]=3,["MiningGrade"]=2,["Biome"]="Badlands",["Depth"]="A",["Min"]=2,["Max"]=4,["Health"]=800},
 ["RedOre"] = {["Id"]="RedOre",["Kind"]="Mineral",["Grade"]=6,["MiningGrade"]=5,["Biome"]="Badlands",["Depth"]="B",["Min"]=2,["Max"]=4,["Health"]=6400},
 ["ToughHide"] = {["Id"]="ToughHide",["Kind"]="Animal",["Grade"]=3,["MiningGrade"]=2,["Biome"]="Badlands",["Depth"]="A",["Min"]=2,["Max"]=4,["Health"]=800},
 ["StrongSilk"] = {["Id"]="StrongSilk",["Kind"]="Plant",["Grade"]=2,["MiningGrade"]=1,["Biome"]="Rainforest",["Depth"]="B",["Min"]=2,["Max"]=4,["Duration"]=1.5},
 ["LiftSeed"] = {["Id"]="LiftSeed",["Kind"]="Plant",["Grade"]=4,["MiningGrade"]=3,["Biome"]="Rainforest",["Depth"]="C",["Min"]=2,["Max"]=4,["Duration"]=1.5},
 ["Heartwood"] = {["Id"]="Heartwood",["Kind"]="Wood",["Grade"]=6,["MiningGrade"]=5,["Biome"]="Rainforest",["Depth"]="D",["Min"]=2,["Max"]=4,["Health"]=6400},
 ["OldGear"] = {["Id"]="OldGear",["Kind"]="Mineral",["Grade"]=4,["MiningGrade"]=3,["Biome"]="Flooded Ruins",["Depth"]="A",["Min"]=2,["Max"]=4,["Health"]=1600},
 ["PressureGlass"] = {["Id"]="PressureGlass",["Kind"]="Mineral",["Grade"]=4,["MiningGrade"]=3,["Biome"]="Flooded Ruins",["Depth"]="B",["Min"]=2,["Max"]=4,["Health"]=1600},
 ["DarkMoss"] = {["Id"]="DarkMoss",["Kind"]="Plant",["Grade"]=4,["MiningGrade"]=3,["Biome"]="Caverns",["Depth"]="A",["Min"]=2,["Max"]=4,["Duration"]=1.5},
 ["LightOre"] = {["Id"]="LightOre",["Kind"]="Mineral",["Grade"]=7,["MiningGrade"]=6,["Biome"]="Caverns",["Depth"]="B",["Min"]=2,["Max"]=4,["Health"]=12800},
 ["EchoShell"] = {["Id"]="EchoShell",["Kind"]="Mineral",["Grade"]=4,["MiningGrade"]=3,["Biome"]="Caverns",["Depth"]="C",["Min"]=2,["Max"]=4,["Health"]=1600},
 ["MoonRock"] = {["Id"]="MoonRock",["Kind"]="Mineral",["Grade"]=4,["MiningGrade"]=3,["Biome"]="Moon Surface",["Depth"]="A",["Min"]=2,["Max"]=4,["Health"]=1600},
 ["MoonThread"] = {["Id"]="MoonThread",["Kind"]="Plant",["Grade"]=4,["MiningGrade"]=3,["Biome"]="Moon Surface",["Depth"]="B",["Min"]=2,["Max"]=4,["Duration"]=1.5},
 ["MoonOre"] = {["Id"]="MoonOre",["Kind"]="Mineral",["Grade"]=8,["MiningGrade"]=7,["Biome"]="Moon Surface",["Depth"]="D",["Min"]=2,["Max"]=4,["Health"]=25600},
 ["GravityShard"] = {["Id"]="GravityShard",["Kind"]="Mineral",["Grade"]=8,["MiningGrade"]=7,["Biome"]="Moon Surface",["Depth"]="E",["Min"]=2,["Max"]=4,["Health"]=25600},
}
C.ArmorFamilies = {
 ["Trail"] = {["Grade"]=1,["Signature"]="Resin",["Resistance"]={["Wet"]=0.3},["SetBonuses"]={["Two"]={["HungerDrainReduction"]=0.05},["Four"]={["MedicalHealingBonus"]=0.1}},["TwoDescription"]="Hunger drains 5% slower",["FourDescription"]="Medical consumables restore +10% HP",["Trophy"]="AncientSeed",["Station"]="Loom"},
 ["Dune"] = {["Grade"]=1,["Signature"]="Cactus",["Resistance"]={["Heat"]=0.85,["Wet"]=0.1},["SetBonuses"]={["Two"]={["WaterExposureBonus"]=5},["Four"]={["DrinkMoveBonus"]=0.1,["DrinkMoveDuration"]=5,["DrinkMoveCooldown"]=20}},["TwoDescription"]="Water removes +5 exposure",["FourDescription"]="After drinking, +10% movement for 5s; 20s cooldown",["Trophy"]="SunHeart",["Station"]="Loom"},
 ["Marsh"] = {["Grade"]=2,["Signature"]="Reeds",["Resistance"]={["Toxin"]=0.8,["Wet"]=0.85},["SetBonuses"]={["Two"]={["MudPenaltyReduction"]=0.5},["Four"]={["PoisonDurationReduction"]=0.3}},["TwoDescription"]="Mud movement penalty halved",["FourDescription"]="Poison duration reduced 30%",["Trophy"]="MarshHeart",["Station"]="Loom"},
 ["Frost"] = {["Grade"]=2,["Signature"]="WarmFur",["Resistance"]={["Cold"]=0.85,["Wet"]=0.4},["SetBonuses"]={["Two"]={["SnowPenaltyReduction"]=0.5},["Four"]={["HeatSourceRecoveryBonus"]=0.25}},["TwoDescription"]="Snow movement penalty halved",["FourDescription"]="Warmth recovery near heat sources +25%",["Trophy"]="FrostHeart",["Station"]="Loom"},
 ["Ash"] = {["Grade"]=3,["Signature"]="BlackGlass",["Resistance"]={["Heat"]=0.85,["Toxin"]=0.4},["SetBonuses"]={["Two"]={["AshVisibilityReduction"]=0.5},["Four"]={["BurnDurationReduction"]=0.4}},["TwoDescription"]="Ash visibility penalty reduced",["FourDescription"]="Burn duration reduced 40%; no lava immunity",["Trophy"]="GreaterFireCore",["Station"]="Anvil"},
 ["Crystal"] = {["Grade"]=3,["Signature"]="ClearCrystal",["Resistance"]={["Heat"]=0.4,["Cold"]=0.4,["Toxin"]=0.5},["SetBonuses"]={["Two"]={["SpecialCostReduction"]=0.05},["Four"]={["SpecialCooldownReduction"]=0.1}},["TwoDescription"]="Special stamina cost -5%",["FourDescription"]="Weapon-special cooldown -10%",["Trophy"]="CrystalHeart",["Station"]="Anvil"},
 ["Aurora"] = {["Grade"]=4,["Signature"]="GlowFiber",["Resistance"]={["Heat"]=0.7,["Cold"]=0.7,["Wet"]=0.4},["SetBonuses"]={["Two"]={["ExposureRecovery"]=0.1},["Four"]={["TemperatureTransitionRecoveryBonus"]=0.15,["TemperatureTransitionSeconds"]=8,["TemperatureTransitionCooldown"]=30}},["TwoDescription"]="Exposure recovery +10%",["FourDescription"]="Changing between hot/cold regions grants 8s of +15% recovery; 30s cooldown",["Trophy"]="DawnHeart",["Station"]="Loom"},
 ["Meteor"] = {["Grade"]=4,["Signature"]="ImpactGlass",["Resistance"]={["Heat"]=0.75,["Cold"]=0.4,["Wet"]=0.4},["SetBonuses"]={["Two"]={["StaggerReduction"]=0.1},["Four"]={["FirstHitReduction"]=0.2,["FirstHitCooldown"]=20}},["TwoDescription"]="Stagger duration -10%",["FourDescription"]="First monster hit after 20s without taking damage deals 20% less damage",["Trophy"]="GreaterStarCore",["Station"]="Anvil"},
 ["Coast"] = {["Grade"]=2,["Signature"]="ShellPlate",["Resistance"]={["Wet"]=0.85,["Cold"]=0.35},["SetBonuses"]={["Two"]={["SwimDrainReduction"]=0.1},["Four"]={["AirDrainReduction"]=0.2}},["TwoDescription"]="Swimming stamina cost -10%",["FourDescription"]="Air supply lasts 25% longer",["Trophy"]="TideHeart",["Station"]="Loom"},
 ["Storm"] = {["Grade"]=4,["Signature"]="CloudWool",["Resistance"]={["Wet"]=0.8,["Cold"]=0.55},["SetBonuses"]={["Two"]={["WindPenaltyReduction"]=0.5},["Four"]={["LightningDamageReduction"]=0.35}},["TwoDescription"]="Wind movement penalty halved",["FourDescription"]="Telegraph-marked lightning damage reduced 35%",["Trophy"]="GreaterStormCore",["Station"]="Loom"},
 ["Garden"] = {["Grade"]=4,["Signature"]="LivingRoot",["Resistance"]={["Toxin"]=0.8,["Wet"]=0.6},["SetBonuses"]={["Two"]={["MedicalUseTimeReduction"]=0.1},["Four"]={["MedicalHotBonus"]=0.15}},["TwoDescription"]="Medical item use time -10%",["FourDescription"]="Healing over time on wearer restores +15%; abilities unchanged",["Trophy"]="GrowthHeart",["Station"]="Loom"},
 ["Iron"] = {["Grade"]=3,["Signature"]="ToughHide",["Resistance"]={["Heat"]=0.45,["Toxin"]=0.35},["SetBonuses"]={["Two"]={["StaggerReduction"]=0.15},["Four"]={["ArmorWearReduction"]=0.2}},["TwoDescription"]="Stagger duration -15%",["FourDescription"]="Lose 20% less armor durability",["Trophy"]="IronHeart",["Station"]="Anvil"},
 ["Canopy"] = {["Grade"]=2,["Signature"]="StrongSilk",["Resistance"]={["Wet"]=0.65,["Cold"]=0.25},["SetBonuses"]={["Two"]={["ClimbDrainReduction"]=0.1},["Four"]={["GlideDrainReduction"]=0.2}},["TwoDescription"]="Climbing stamina cost -10%",["FourDescription"]="Glider stamina cost -20%",["Trophy"]="SkyHeart",["Station"]="Loom"},
 ["Diver"] = {["Grade"]=4,["Signature"]="PressureGlass",["Resistance"]={["Wet"]=0.9,["Cold"]=0.6},["SetBonuses"]={["Two"]={["SwimSpeedBonus"]=0.1},["Four"]={["PressureAirReduction"]=0.3}},["TwoDescription"]="Swimming speed +10%",["FourDescription"]="Pressure-zone air consumption reduced 30%",["Trophy"]="ArchiveHeart",["Station"]="Anvil"},
 ["Lantern"] = {["Grade"]=4,["Signature"]="DarkMoss",["Resistance"]={["Cold"]=0.65,["Toxin"]=0.5},["SetBonuses"]={["Two"]={["LightRadiusBonus"]=0.15},["Four"]={["HearingReduction"]=0.2}},["TwoDescription"]="Own carried light radius +15%",["FourDescription"]="Movement-generated monster hearing radius -20%",["Trophy"]="NightHeart",["Station"]="Loom"},
 ["Moon"] = {["Grade"]=4,["Signature"]="MoonThread",["Resistance"]={["Heat"]=0.6,["Cold"]=0.6,["Wet"]=0.25},["SetBonuses"]={["Two"]={["LandingRecoveryReduction"]=0.25},["Four"]={["LowGravityControlBonus"]=0.25,["FallDamageReduction"]=0.25}},["TwoDescription"]="Landing recovery shortened",["FourDescription"]="Low-gravity movement control improved; fall damage -25%",["Trophy"]="GravityShard",["Station"]="Anvil"},
}
C.Enchantments = {
 ["DrawForce"] = {["Name"]="Draw Force",["Grades"]={3,4,5,7,8},["Values"]={0.08,0.16,0.24,0.32,0.40},["MaxLevel"]=5,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Bow"},["Theme"]="Bone",["Trophy"]="AnyTrophy",["Family"]="",["ConflictGroups"]={"WeaponDamagePattern"},["Description"]="Every normal and special bow shot deals 8/16/24/32/40% more bow damage. It does not affect other weapon families.",["Source"]="Bone; hunting sites; any E trophy for rank V"},
 ["HeldBreath"] = {["Name"]="Held Breath",["Grades"]={3,5,7},["Values"]={0.20,0.35,0.50},["GravityValues"]={0.15,0.25,0.35},["MaxLevel"]=3,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Bow"},["Theme"]="StrongSilk",["Trophy"]="",["Family"]="",["Description"]="Arrows released at 90% draw travel 20/35/50% faster and receive 15/25/35% less gravity.",["Source"]="Strong Silk; ranged combat sites"},
 ["SplitFlight"] = {["Name"]="Split Flight",["Grades"]={5,7,8},["Values"]={0.18,0.24,0.30},["TargetValues"]={1,1,2},["RadiusValues"]={10,12,14},["MaxLevel"]=3,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Bow"},["Theme"]="ClearCrystal",["Trophy"]="DawnHeart",["Family"]="",["Description"]="A fully drawn hit sends fragments to 1/1/2 other visible monsters within 10/12/14 studs for 18/24/30% damage. Fragments cannot split.",["Source"]="Clear Crystal; ranged combat sites; Dawn Heart for rank III"},
 ["MeasuredEdge"] = {["Name"]="Measured Edge",["Grades"]={3,5,7,8},["Values"]={0.10,0.15,0.20,0.26},["MaxLevel"]=4,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Sword"},["Theme"]="BlackGlass",["Trophy"]="AnyTrophy",["Family"]="",["ConflictGroups"]={"WeaponDamagePattern"},["Description"]="The second basic sword hit landed within 2.5 seconds deals 10/15/20/26% more damage and uses a wider hit arc. Missing or changing weapons resets the pair.",["Source"]="Black Glass; sword combat sites; any trophy for rank IV"},
 ["WideCut"] = {["Name"]="Wide Cut",["Grades"]={4,6,8},["Values"]={0.25,0.35,0.45},["MaxLevel"]=3,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Sword"},["Theme"]="DeepMetal",["Trophy"]="",["Family"]="",["Description"]="A basic sword hit also strikes the nearest second monster in the forward arc for 25/35/45% damage.",["Source"]="Metal; sword combat sites"},
 ["GuardReturn"] = {["Name"]="Guard Return",["Grades"]={5,7,8},["Values"]={0.25,0.35,0.45},["DamageValues"]={0.12,0.18,0.25},["MaxLevel"]=3,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Sword"},["Theme"]="ToughHide",["Trophy"]="IronHeart",["Family"]="",["Description"]="A timed sword special reduces the next monster hit by 25/35/45% and empowers the next basic strike by 12/18/25%.",["Source"]="Tough Hide; defense sites; Iron Heart for rank III"},
 ["SetPoint"] = {["Name"]="Set Point",["Grades"]={3,5,7,8},["Values"]={0.08,0.13,0.19,0.26},["SlowValues"]={0.10,0.14,0.18,0.22},["MaxLevel"]=4,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Spear"},["Theme"]="Bone",["Trophy"]="AnyTrophy",["Family"]="",["ConflictGroups"]={"WeaponDamagePattern"},["Description"]="Spear hits begun at least 8 studs away deal 8/13/19/26% more damage and briefly slow their target by 10/14/18/22%; bosses receive half slow.",["Source"]="Bone; spear combat sites; any trophy for rank IV"},
 ["DrivingLine"] = {["Name"]="Driving Line",["Grades"]={4,6,8},["Values"]={0.45,0.60,0.75},["TargetValues"]={1,1,2},["MaxLevel"]=3,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Spear"},["Theme"]="StrongSilk",["Trophy"]="",["Family"]="",["Description"]="A spear special continues through 1/1/2 additional monsters in its line for 45/60/75% damage.",["Source"]="Strong Silk; spear combat sites"},
 ["Brace"] = {["Name"]="Brace",["Grades"]={5,7},["Values"]={0.6,0.9},["MaxLevel"]=2,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Spear"},["Theme"]="ToughHide",["Trophy"]="",["Family"]="",["Description"]="After holding position for 0.6 seconds, the next spear hit staggers a non-boss for 0.6/0.9 seconds. Eight-second per-target cooldown.",["Source"]="Tough Hide; defensive combat sites"},
 ["SplitArc"] = {["Name"]="Split Arc",["Grades"]={3,5,7},["Values"]={0.35,0.50,0.65},["MaxLevel"]=3,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Axe"},["Theme"]="BlackGlass",["Trophy"]="",["Family"]="",["Description"]="A basic weapon-axe swing strikes one additional monster in its arc for 35/50/65% damage.",["Source"]="Black Glass; axe combat sites"},
 ["DeepBite"] = {["Name"]="Deep Bite",["Grades"]={4,6,8},["Values"]={1,2,3},["DamageValues"]={0.08,0.08,0.08},["MaxLevel"]=3,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Axe"},["Theme"]="DeepMetal",["Trophy"]="",["Family"]="",["ConflictGroups"]={"WeaponDamagePattern"},["Description"]="Basic hits store up to 1/2/3 wounds for four seconds. An axe special consumes them for 8% weapon damage per wound over three seconds.",["Source"]="Deep Metal; axe combat sites"},
 ["FellThrough"] = {["Name"]="Fell Through",["Grades"]={5,7},["Values"]={0.20,0.35},["MaxLevel"]=2,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Axe"},["Theme"]="Resin",["Trophy"]="",["Family"]="",["Description"]="An axe-special kill refunds 20/35% of that special's cooldown. One refund per cast.",["Source"]="Resin; axe combat sites"},
 ["Blindside"] = {["Name"]="Blindside",["Grades"]={3,5,7,8},["Values"]={0.08,0.14,0.20,0.28},["MaxLevel"]=4,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Dagger"},["Theme"]="Bone",["Trophy"]="AnyTrophy",["Family"]="",["ConflictGroups"]={"WeaponDamagePattern"},["Description"]="Dagger hits from behind deal 8/14/20/28% more damage. Bosses receive half the bonus.",["Source"]="Bone; hunting sites; any trophy for rank IV"},
 ["SlipCut"] = {["Name"]="Slip Cut",["Grades"]={4,6,8},["Values"]={0.15,0.25,0.35},["MaxLevel"]=3,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Dagger"},["Theme"]="StrongSilk",["Trophy"]="",["Family"]="",["Description"]="A confirmed dodge followed by a dagger hit within two seconds adds a second cut for 15/25/35% damage. Six-second cooldown.",["Source"]="Strong Silk; traversal combat sites"},
 ["QuickExit"] = {["Name"]="Quick Exit",["Grades"]={5,7},["Values"]={0.10,0.16},["MaxLevel"]=2,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Dagger"},["Theme"]="EchoShell",["Trophy"]="",["Family"]="",["Description"]="A dagger kill grants 10/16% movement speed for three seconds. Further kills refresh rather than stack it.",["Source"]="Echo Shell; dagger combat sites"},
 ["HeavyEcho"] = {["Name"]="Heavy Echo",["Grades"]={3,5,7},["Values"]={0.20,0.30,0.40},["MaxLevel"]=3,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Hammer"},["Theme"]="ImpactGlass",["Trophy"]="",["Family"]="",["ConflictGroups"]={"WeaponDamagePattern"},["Description"]="A ground slam repeats after 0.65 seconds for 20/30/40% damage in 70% of the original radius.",["Source"]="Impact Glass; hammer combat sites"},
 ["Crumple"] = {["Name"]="Crumple",["Grades"]={4,6,8},["Values"]={0.12,0.20,0.30},["MaxLevel"]=3,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Hammer"},["Theme"]="ToughHide",["Trophy"]="",["Family"]="",["Description"]="Hammer hits increase stagger received by 12/20/30% for four seconds. The strongest value applies.",["Source"]="Tough Hide; hammer combat sites"},
 ["GroundClaim"] = {["Name"]="Ground Claim",["Grades"]={5,7},["Values"]={0.18,0.28},["DurationValues"]={3,5},["MaxLevel"]=2,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Hammer"},["Theme"]="LivingRoot",["Trophy"]="",["Family"]="",["Description"]="A ground slam leaves a 3/5-second zone that slows non-boss monsters by 18/28%. One zone per owner.",["Source"]="Living Root; hammer combat sites"},
 ["EchoCast"] = {["Name"]="Echo Cast",["Grades"]={3,5,7,8},["Values"]={0.15,0.22,0.30,0.38},["MaxLevel"]=4,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Staff"},["Theme"]="ClearCrystal",["Trophy"]="AnyTrophy",["Family"]="",["ConflictGroups"]={"WeaponDamagePattern"},["Description"]="A staff special repeats after 0.7 seconds for 15/22/30/38% damage with 60% of the original radius.",["Source"]="Clear Crystal; staff combat sites; any trophy for rank IV"},
 ["Conduit"] = {["Name"]="Conduit",["Grades"]={4,6,8},["Values"]={4,7,10},["MaxLevel"]=3,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Staff"},["Theme"]="GlowFiber",["Trophy"]="",["Family"]="",["Description"]="The first monster hit by a staff special restores 4/7/10 stamina to living crew within 12 studs. Once per cast.",["Source"]="Glow Fiber; support sites"},
 ["FocusLine"] = {["Name"]="Focus Line",["Grades"]={5,7},["Values"]={0.15,0.25},["MaxLevel"]=2,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Staff"},["Theme"]="ClearCrystal",["Trophy"]="",["Family"]="",["Description"]="Three consecutive basic staff hits on one target increase the next staff special's radius by 15/25%. Focus expires after six seconds.",["Source"]="Clear Crystal; staff combat sites"},
 ["OpenSeam"] = {["Name"]="Open Seam",["Grades"]={3,5,6,8},["Values"]={0.15,0.25,0.35,0.45},["MaxLevel"]=4,["AllowedKinds"]={"Tool"},["AllowedSlots"]={},["AllowedFamilies"]={"Axe","Pickaxe","Universal"},["Theme"]="Resin",["Trophy"]="SunHeart",["Family"]="",["Description"]="On the same resource node, every third successful hit gains 15/25/35/45% normal breaking power. Visible crack cue; change target or wait 4s to lose the chain. Does not bypass mining grade.",["Source"]="Resin for rank I, Deep Resin for later ranks; mineral/root sites; Sun Heart for rank IV",["Themes"]={"Resin","DeepResin","DeepResin","DeepResin"}},
 ["CleanCut"] = {["Name"]="Clean Cut",["Grades"]={3,5,7},["Values"]={0.1,0.15,0.2},["MaxLevel"]=3,["AllowedKinds"]={"Tool"},["AllowedSlots"]={},["AllowedFamilies"]={"Sickle","Universal"},["Theme"]="Reeds",["Trophy"]="",["Family"]="",["Description"]="After completing a plant harvest, the next plant gather started within 5s takes 10/15/20% less time. At most one stored benefit; no extra rare drops.",["Source"]="Reeds; wetland/plant sites"},
 ["QuickStow"] = {["Name"]="Quick Stow",["Grades"]={4,6},["Values"]={6,10},["MaxLevel"]=2,["AllowedKinds"]={"Tool"},["AllowedSlots"]={},["AllowedFamilies"]={},["Theme"]="Resin",["Trophy"]="",["Family"]="",["Description"]="On node completion, automatically collect that node's normal drops within 6/10 studs if space exists. Overflow stays on the ground; no loot through walls, from other players, or from chests.",["Source"]="Resin; field-supply sites"},
 ["HeatStore"] = {["Name"]="Heat Store",["Grades"]={4,6},["Values"]={8,12},["MaxLevel"]=2,["AllowedKinds"]={"Armor"},["AllowedSlots"]={"Chest"},["AllowedFamilies"]={},["Theme"]="IceCrystal",["Trophy"]="",["Family"]="",["Description"]="An actual reduction of at least 20 heat or cold exposure by a consumable stores an 8/12-point buffer against the same temperature direction for 90s. Buffer absorbs new exposure, not HP damage. One buffer; cannot charge from its own absorption or neutral-player item use.",["Source"]="Ice Crystal; thermal sites"},
 ["WeatherMemory"] = {["Name"]="Weather Memory",["Grades"]={4,6,8},["Values"]={30,45,60},["MaxLevel"]=3,["AllowedKinds"]={"Armor"},["AllowedSlots"]={"Head"},["AllowedFamilies"]={},["Theme"]="AuroraStone",["Trophy"]="DawnHeart",["Family"]="",["Description"]="After qualifying for a biome visit while worn, remember its dominant environmental channel. On a later visit to that biome, reduce that channel's buildup 15% for the first 30/45/60s. One memory per biome; no bonus before discovery or prediction of an unvisited biome.",["Source"]="Aurora Stone; weather sites; Dawn Heart for rank III"},
 ["DryStep"] = {["Name"]="Dry Step",["Grades"]={3,5,7},["Values"]={0.2,0.35,0.5},["MaxLevel"]=3,["AllowedKinds"]={"Armor"},["AllowedSlots"]={"Boots"},["AllowedFamilies"]={},["Theme"]="Kelp",["Trophy"]="",["Family"]="",["Description"]="After leaving water/rain for dry shelter, wetness clears 20/35/50% faster for 10s. Entering water/rain ends it; does not erase wetness instantly.",["Source"]="Kelp; coastal sites; unavailable until its content release"},
 ["SharedCover"] = {["Name"]="Shared Cover",["Grades"]={5,7},["Values"]={0.08,0.12},["MaxLevel"]=2,["AllowedKinds"]={"Armor"},["AllowedSlots"]={"Chest"},["AllowedFamilies"]={},["Theme"]="ShellPlate",["Trophy"]="",["Family"]="",["Description"]="While wearer and a living teammate are under the same valid roof within 10 studs, both receive 8/12% less environmental buildup. Strongest aura only; no added protection through separate floors or walls.",["Source"]="Shell Plate; shelter/defense sites"},
 ["CampStitch"] = {["Name"]="Camp Stitch",["Grades"]={3,5,7},["Values"]={0.04,0.07,0.1},["MaxLevel"]=3,["AllowedKinds"]={"Armor"},["AllowedSlots"]={},["AllowedFamilies"]={},["Theme"]="Resin",["Trophy"]="",["Family"]="",["Description"]="After 10s at a suitable camp repair station, offer a quick repair consuming Resin x1 to restore 4/7/10% durability to that enchanted piece. Explicit confirmation; once per item per visit; no repair if already full.",["Source"]="Resin; repair sites; Anvil or Loom works before Repair Bench unlock"},
 ["LastThread"] = {["Name"]="Last Thread",["Grades"]={7},["Values"]={8},["MaxLevel"]=1,["AllowedKinds"]={"Armor"},["AllowedSlots"]={},["AllowedFamilies"]={},["Theme"]="ToughHide",["Trophy"]="",["Family"]="",["Description"]="Once per user per visit, a durability loss that would break an enchanted piece leaves it at 1 durability for 8s. Further wear is ignored during that window; it then becomes broken unless repaired. Does not prevent HP death.",["Source"]="Tough Hide; advanced repair sites"},
 ["RescueReserve"] = {["Name"]="Rescue Reserve",["Grades"]={5},["Values"]={15},["MaxLevel"]=1,["AllowedKinds"]={"Accessory"},["AllowedSlots"]={},["AllowedFamilies"]={},["Theme"]="HealingHerb",["Trophy"]="",["Family"]="",["Description"]="After personally completing a teammate revival, restore 15 of the rescuer's stamina and remove 15 heat/cold exposure toward zero. 60s cooldown. Does not alter the revived player's established reset values.",["Source"]="Healing Herb; rescue objectives"},
 ["SavedMeal"] = {["Name"]="Saved Meal",["Grades"]={5,7},["Values"]={10,20},["MaxLevel"]=2,["AllowedKinds"]={"Accessory"},["AllowedSlots"]={},["AllowedFamilies"]={},["Theme"]="GlowMushroom",["Trophy"]="",["Family"]="",["Description"]="Capture up to 10/20 hunger that would otherwise be wasted by eating above maximum hunger. Once hunger falls below 50, release the saved amount at 1 hunger/s. No charge from class abilities, admin restoration, or consuming the reserve itself.",["Source"]="Glow Mushroom; cooking/supply sites"},
 ["AirPocket"] = {["Name"]="Air Pocket",["Grades"]={4,6,8},["Values"]={15,25,35},["MaxLevel"]=3,["AllowedKinds"]={"Armor"},["AllowedSlots"]={"Head"},["AllowedFamilies"]={},["Theme"]="PressureGlass",["Trophy"]="ArchiveHeart",["Family"]="",["Description"]="When remaining air first falls below 25%, release 15/25/35 extra seconds from a reserve. Recharges only at a camp air-refill station after a full refill; merely surfacing, re-equipping, or reconnecting does not refill it.",["Source"]="Pressure Glass; underwater sites; Archive Heart for rank III"},
 ["PackWarning"] = {["Name"]="Pack Warning",["Grades"]={4,6},["Values"]={3,5},["MaxLevel"]=2,["AllowedKinds"]={"Armor"},["AllowedSlots"]={"Head"},["AllowedFamilies"]={},["Theme"]="EchoShell",["Trophy"]="",["Family"]="",["Description"]="After receiving a monster hit, show local map warnings for up to 3/5 nearby monsters of that species within 40 studs for 8s. 20s cooldown; does not reveal terrain or permit targeting through cover.",["Source"]="Echo Shell; tracking/cave sites"},
 ["SurveyLink"] = {["Name"]="Survey Link",["Grades"]={5,7},["Values"]={12,20},["MaxLevel"]=2,["AllowedKinds"]={"Accessory"},["AllowedSlots"]={},["AllowedFamilies"]={},["Theme"]="ClearCrystal",["Trophy"]="",["Family"]="",["Description"]="First personal entry into an already generated sub-biome footprint reveals an extra 12/20-stud terrain radius around the entry point on the shared map. Once per user per footprint per visit; no resource/loot duplication or distant chunk activation.",["Source"]="Clear Crystal; survey projects"},
 ["ReturnShot"] = {["Name"]="Return Shot",["Grades"]={4,5,7,8},["Values"]={0.1,0.15,0.2,0.25},["MaxLevel"]=4,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Bow"},["Theme"]="StrongSilk",["Trophy"]="SkyHeart",["Family"]="",["Description"]="A dodge that actually avoids a server-confirmed monster attack primes the next accepted bow shot within 3 seconds for 10/15/20/25% more damage. Eight-second cooldown.",["Source"]="Strong Silk; traversal combat sites; Sky Heart for rank IV"},
 ["VentStrike"] = {["Name"]="Vent Strike",["Grades"]={4,6,8},["Values"]={4,7,10},["MaxLevel"]=3,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={},["AllowedItems"]={"FrostSpear","EmberAxe","CrystalStaff","RootStaff","LanternStaff"},["Theme"]="FrostBloom",["Trophy"]="FrostHeart",["Family"]="SpecialResponse",["Description"]="A special hit removes 4/7/10 exposure toward zero when magnitude is at least 25. One trigger per cast.",["Source"]="Frost Bloom; thermal combat sites; Frost Heart for rank III"},
 ["StormLatch"] = {["Name"]="Storm Latch",["Grades"]={6,8},["Values"]={0.12,0.2},["MaxLevel"]=2,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={},["AllowedItems"]={"StormBow","ThunderHammer","TideSpear","SkySpear"},["Theme"]="StormCore",["Trophy"]="GreaterStormCore",["Family"]="SpecialResponse",["Description"]="After 30 seconds outdoors in rain or a storm, the next special hit deals 12/20% more damage. The stored charge expires after 60 seconds.",["Source"]="Storm Core; storm sites; Greater Storm Core for rank II"},
 ["ForkedCurrent"] = {["Name"]="Forked Current",["Grades"]={6,8},["Values"]={0.25,0.35},["TargetValues"]={1,2},["MaxLevel"]=2,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Bow"},["AllowedItems"]={"StormBow"},["Theme"]="StormOre",["Trophy"]="GreaterStormCore",["Family"]="",["Signature"]=true,["SignatureItemName"]="Storm Bow",["Description"]="The Storm Bow's special chains to 1/2 additional visible monsters for 25/35% damage. Chain hits cannot chain again.",["Source"]="Storm sites; Greater Storm Core for rank II"},
 ["RootPin"] = {["Name"]="Root Pin",["Grades"]={6,8},["Values"]={0.75,1.25},["MaxLevel"]=2,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Bow"},["AllowedItems"]={"IronwoodBow"},["Theme"]="LivingRoot",["Trophy"]="GrowthHeart",["Family"]="",["Signature"]=true,["SignatureItemName"]="Ironwood Bow",["Description"]="A fully drawn hit roots a non-boss for 0.75/1.25 seconds. Bosses are slowed 15/25% for 1.5 seconds. Six-second per-target cooldown.",["Source"]="Living Root; Growth Heart for rank II"},
 ["StarfallTrace"] = {["Name"]="Starfall Trace",["Grades"]={8},["Values"]={0.25},["MaxLevel"]=1,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Bow"},["AllowedItems"]={"StarBow"},["Theme"]="MoonRock",["Trophy"]="GravityShard",["Family"]="",["Signature"]=true,["SignatureItemName"]="Star Bow",["Description"]="A fully drawn hit marks its impact. After 0.6 seconds, a star pulse deals 25% arrow damage within six studs. Four-second cooldown.",["Source"]="Moon Rock; Gravity Shard"},
 ["RollingCharge"] = {["Name"]="Rolling Charge",["Grades"]={6,8},["Values"]={0.20,0.30},["TargetValues"]={1,2},["MaxLevel"]=2,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Hammer"},["AllowedItems"]={"ThunderHammer"},["Theme"]="StormOre",["Trophy"]="GreaterStormCore",["Family"]="",["Signature"]=true,["SignatureItemName"]="Thunder Hammer",["Description"]="Staggering a monster arcs 20/30% weapon damage to 1/2 nearby monsters. Each target is struck once per trigger.",["Source"]="Storm sites; Greater Storm Core for rank II"},
 ["OrbitBreak"] = {["Name"]="Orbit Break",["Grades"]={8},["Values"]={10},["MaxLevel"]=1,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Hammer"},["AllowedItems"]={"GravityHammer"},["Theme"]="MoonRock",["Trophy"]="GravityShard",["Family"]="",["Signature"]=true,["SignatureItemName"]="Gravity Hammer",["Description"]="Ground slam pulls non-boss monsters within ten studs toward its impact. Bosses receive a short 15% slow instead.",["Source"]="Moon Rock; Gravity Shard"},
 ["Undertow"] = {["Name"]="Undertow",["Grades"]={6,8},["Values"]={2,3},["MaxLevel"]=2,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Spear"},["AllowedItems"]={"TideSpear"},["Theme"]="ShellPlate",["Trophy"]="TideHeart",["Family"]="",["Signature"]=true,["SignatureItemName"]="Tide Spear",["Description"]="A special hit pulls nearby non-boss monsters 2/3 studs toward the spear's impact line.",["Source"]="Coastal sites; Tide Heart for rank II"},
 ["TailwindLine"] = {["Name"]="Tailwind Line",["Grades"]={7,8},["Values"]={0.10,0.15},["CostValues"]={0.25,0.40},["MaxLevel"]=2,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Spear"},["AllowedItems"]={"SkySpear"},["Theme"]="EchoShell",["Trophy"]="SkyHeart",["Family"]="",["Signature"]=true,["SignatureItemName"]="Sky Spear",["Description"]="A long-range spear hit grants 10/15% movement for three seconds and reduces the next spear-special stamina cost by 25/40%.",["Source"]="Echo Shell; Sky Heart for rank II"},
 ["BriarDebt"] = {["Name"]="Briar Debt",["Grades"]={6,8},["Values"]={0.10,0.18},["CapValues"]={0.25,0.45},["MaxLevel"]=2,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Sword"},["AllowedItems"]={"ThornBlade"},["Theme"]="ThickSpores",["Trophy"]="GrowthHeart",["Family"]="",["Signature"]=true,["SignatureItemName"]="Thorn Blade",["Description"]="Stores 10/18% of monster damage received, capped at 25/45% of one normal sword hit. The next successful special releases it.",["Source"]="Thick Spores; Growth Heart for rank II"},
 ["PressureCut"] = {["Name"]="Pressure Cut",["Grades"]={7,8},["Values"]={0.08,0.12},["HitValues"]={3,2},["MaxLevel"]=2,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Sword"},["AllowedItems"]={"DeepsteelSword"},["Theme"]="DeepMetal",["Trophy"]="ArchiveHeart",["Family"]="",["Signature"]=true,["SignatureItemName"]="Deepsteel Sword",["Description"]="After 3/2 repeated hits, the target loses 8/12% damage resistance for four seconds. The strongest exposure applies.",["Source"]="Deep Metal; Archive Heart for rank II"},
 ["PhaseReturn"] = {["Name"]="Phase Return",["Grades"]={8},["Values"]={0.30},["MaxLevel"]=1,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Sword"},["AllowedItems"]={"Moonblade"},["Theme"]="MoonRock",["Trophy"]="GravityShard",["Family"]="",["Signature"]=true,["SignatureItemName"]="Moonblade",["Description"]="A sword special leaves an echo that repeats 30% of its damage after 0.5 seconds.",["Source"]="Moon Rock; Gravity Shard"},
 ["RootNetwork"] = {["Name"]="Root Network",["Grades"]={6,8},["Values"]={0.15,0.25},["MaxLevel"]=2,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Staff"},["AllowedItems"]={"RootStaff"},["Theme"]="LivingRoot",["Trophy"]="GrowthHeart",["Family"]="",["Signature"]=true,["SignatureItemName"]="Root Staff",["Description"]="A monster slowed by the Root Staff shares 15/25% of later staff damage with the nearest visible monster for three seconds. Shared damage cannot chain.",["Source"]="Living Root; Growth Heart for rank II"},
 ["BeaconEcho"] = {["Name"]="Beacon Echo",["Grades"]={7,8},["Values"]={0.5,0.75},["DurationValues"]={6,9},["MaxLevel"]=2,["AllowedKinds"]={"Weapon"},["AllowedSlots"]={},["AllowedFamilies"]={"Staff"},["AllowedItems"]={"LanternStaff"},["Theme"]="EchoShell",["Trophy"]="NightHeart",["Family"]="",["Signature"]=true,["SignatureItemName"]="Lantern Staff",["Description"]="A special leaves a light field for 6/9 seconds that reveals monsters and removes 0.5/0.75 exposure per second from nearby crew.",["Source"]="Echo Shell; Night Heart for rank II"},
}
local EnchantmentDisplay = {
 DrawForce={"Increase every normal and special bow shot.","Bow damage","+",100,"%"},
 HeldBreath={"Reward a full bow draw with a flatter, faster arrow.","Arrow speed","+",100,"%"},
 SplitFlight={"Send fragments from a fully drawn impact to nearby targets.","Fragment damage","",100,"%"},
 MeasuredEdge={"Pair sword strikes into a deliberate two-hit rhythm.","Second-hit damage","+",100,"%"},
 WideCut={"Carry a sword swing into a second nearby monster.","Second-target damage","",100,"%"},
 GuardReturn={"Time a sword special to soften a hit and answer it.","Incoming damage","-",100,"%"},
 SetPoint={"Reward spear attacks made from proper reach.","Long-range damage","+",100,"%"},
 DrivingLine={"Carry a spear special through more targets.","Follow-through damage","",100,"%"},
 Brace={"Hold position to stagger an approaching monster.","Stagger duration","",1,"s"},
 SplitArc={"Cleave a second target with a weapon axe.","Second-target damage","",100,"%"},
 DeepBite={"Store wounds with basic hits and consume them on a special.","Maximum wounds","",1,""},
 FellThrough={"A special kill returns part of the axe cooldown.","Cooldown refunded","",100,"%"},
 Blindside={"Deal more dagger damage from behind a monster.","Back-hit damage","+",100,"%"},
 SlipCut={"Follow a confirmed dodge with a second dagger cut.","Second-cut damage","",100,"%"},
 QuickExit={"Gain a short movement burst after a dagger kill.","Movement speed","+",100,"%"},
 HeavyEcho={"Repeat a ground slam with a delayed smaller impact.","Echo damage","",100,"%"},
 Crumple={"Make hammer targets easier to stagger.","Stagger received","+",100,"%"},
 GroundClaim={"Leave a slowing field after a ground slam.","Monster slow","",100,"%"},
 EchoCast={"Repeat a staff special at reduced strength.","Echo damage","",100,"%"},
 Conduit={"Return stamina to crew near a staff impact.","Stamina restored","+",1,""},
 FocusLine={"Build focus with basics to widen the next staff special.","Special radius","+",100,"%"},
 OpenSeam={"Build a three-hit breaking rhythm on one resource.","Third-hit breaking power","+",100,"%"},
 CleanCut={"Harvesting a plant speeds up the next plant gather.","Next gather time","-",100,"%"},
 QuickStow={"Completed nodes pull their normal drops into your pack.","Pickup radius","",1," studs"},
 HeatStore={"Exposure-clearing items can store a thermal buffer.","Exposure buffer","+",1," points"},
 WeatherMemory={"Gain early protection when revisiting known biomes.","15% protection duration","",1,"s"},
 DryStep={"Wetness clears faster after reaching dry shelter.","Wetness recovery speed","+",100,"%"},
 SharedCover={"Share environmental protection under the same roof.","Environmental buildup","-",100,"%"},
 CampStitch={"Repair this armor with Resin once per biome visit.","Durability restored","+",100,"%"},
 LastThread={"Prevent one armor break and gain a repair window.","Break protection","",1,"s"},
 RescueReserve={"Reviving a teammate restores your stamina and exposure.","Stamina and exposure restored","+",1," each"},
 SavedMeal={"Store food that would overflow your hunger meter.","Hunger stored","+",1,""},
 AirPocket={"Release emergency air when your supply becomes critical.","Emergency air","+",1,"s"},
 PackWarning={"A monster hit briefly marks more of that species.","Monsters marked","",1,""},
 SurveyLink={"Entering known regions reveals extra shared map terrain.","Extra reveal radius","+",1," studs"},
 ReturnShot={"A successful dodge empowers your next ranged shot.","Next-shot damage","+",100,"%"},
 VentStrike={"A special hit removes some heat or cold exposure.","Exposure removed","-",1," points"},
 StormLatch={"Storm exposure charges bonus damage for a special hit.","Special-hit damage","+",100,"%"},
 ForkedCurrent={"Extend a Storm Bow special through more monsters.","Chain damage","",100,"%"},
 RootPin={"Root a target with a fully drawn Ironwood Bow shot.","Root duration","",1,"s"},
 StarfallTrace={"Call a delayed star pulse onto an arrow impact.","Pulse damage","",100,"%"},
 RollingCharge={"Arc damage away from a Thunder Hammer stagger.","Arc damage","",100,"%"},
 OrbitBreak={"Pull monsters into a Gravity Hammer ground slam.","Pull radius","",1," studs"},
 Undertow={"Pull monsters toward a Tide Spear impact line.","Pull distance","",1," studs"},
 TailwindLine={"Turn a long Sky Spear hit into movement and efficiency.","Movement speed","+",100,"%"},
 BriarDebt={"Store received damage for the Thorn Blade's next special.","Damage stored","",100,"%"},
 PressureCut={"Expose monster defenses with repeated Deepsteel hits.","Resistance reduction","",100,"%"},
 PhaseReturn={"Repeat a Moonblade special with a delayed echo.","Echo damage","",100,"%"},
 RootNetwork={"Share Root Staff damage through a linked target.","Shared damage","",100,"%"},
 BeaconEcho={"Leave a restorative reveal field after a Lantern Staff special.","Exposure recovery","",1,"/s"},
}
for id,enchantment in pairs(C.Enchantments) do enchantment.Id=id end
for id,display in pairs(EnchantmentDisplay) do
 local enchantment=C.Enchantments[id]
 if enchantment then
  enchantment.ShortDescription=display[1]
  enchantment.ValueLabel=display[2]
  enchantment.ValuePrefix=display[3]
  enchantment.ValueScale=display[4]
  enchantment.ValueSuffix=display[5]
 end
end
-- Schematic pages and transfer scrolls are data-derived so each new family and
-- signature enchant receives every valid rank without duplicated catalog rows.
for id,enchantment in pairs(C.Enchantments) do
 if not enchantment.Hidden then
  for rank,grade in ipairs(enchantment.Grades or {}) do
   local schematicId=id.."Schematic"..rank
   local scrollId=id.."Scroll"..rank
   C.Items[schematicId]=C.Items[schematicId] or {Id=schematicId,Name=enchantment.Name.." Schematic "..rank,Grade=grade,Tier=grade,StackSize=1,Tags={"Schematic","Consumable"},Description="Teach the crew "..enchantment.Name.." rank "..rank..". Duplicate known pages yield 4 Enchanting Dust.",Schematic={Id=id,Rank=rank}}
   C.Items[scrollId]=C.Items[scrollId] or {Id=scrollId,Name=enchantment.Name.." Scroll "..rank,Grade=grade,Tier=grade,StackSize=1,Tags={"EnchantmentScroll"},Description="Transfer "..enchantment.Name.." rank "..rank.." to compatible gear.",Scroll={Id=id,Rank=rank}}
  end
 end
end
C.EnchantmentCompatibility={}
for itemId,gear in pairs(C.Gear) do
 local allowed={}
 local family=gear.WeaponFamily or gear.ToolFamily
 for enchantmentId,enchantment in pairs(C.Enchantments) do
  local kindMatches=table.find(enchantment.AllowedKinds,gear.Kind)~=nil
  local slotMatches=#enchantment.AllowedSlots==0 or table.find(enchantment.AllowedSlots,gear.Slot)~=nil
  local familyMatches=#enchantment.AllowedFamilies==0 or table.find(enchantment.AllowedFamilies,family)~=nil
  local exactItems=enchantment.AllowedItems or {}
  local itemMatches=#exactItems==0 or table.find(exactItems,itemId)~=nil
  local blocked=table.find(enchantment.BlockedItems or {},itemId)~=nil
  if not enchantment.Hidden and kindMatches and slotMatches and familyMatches and itemMatches and not blocked then table.insert(allowed,enchantmentId) end
 end
 table.sort(allowed,function(a,b)
  return (C.Enchantments[a].Name or a)<(C.Enchantments[b].Name or b)
 end)
 gear.ItemId=itemId
 gear.AllowedEnchantments=allowed
 if C.Items[itemId] and C.Items[itemId].Gear then C.Items[itemId].Gear.AllowedEnchantments=table.clone(allowed) end
 C.EnchantmentCompatibility[itemId]=allowed
end
C.Stations = {
 ["Workbench"] = {["Name"]="Workbench",["Tier"]=1,["Grade"]=1,["BuildType"]="Workbench",["InteractRadius"]=8,["Description"]="Tools, utility, structural items, assembly; inherits hand recipes"},
 ["Campfire"] = {["Name"]="Campfire",["Tier"]=1,["Grade"]=1,["BuildType"]="Campfire",["InteractRadius"]=8,["Description"]="Simple roasting and actual warmth"},
 ["Furnace"] = {["Name"]="Furnace",["Tier"]=1,["Grade"]=1,["BuildType"]="Furnace",["InteractRadius"]=8,["Description"]="Ore, glass, and higher-grade metal batches"},
 ["Loom"] = {["Name"]="Loom",["Tier"]=1,["Grade"]=1,["BuildType"]="Loom",["InteractRadius"]=8,["Description"]="Cloth, wearable pieces, packs, patches"},
 ["Stove"] = {["Name"]="Stove",["Tier"]=2,["Grade"]=2,["BuildType"]="Stove",["InteractRadius"]=8,["Description"]="Soups, drinks, rations, and mixed meals"},
 ["Oven"] = {["Name"]="Oven",["Tier"]=3,["Grade"]=3,["BuildType"]="Oven",["InteractRadius"]=8,["Description"]="Baked meals, dried food, and later expedition meals"},
 ["Anvil"] = {["Name"]="Anvil",["Tier"]=2,["Grade"]=2,["BuildType"]="Anvil",["InteractRadius"]=8,["Description"]="Metal equipment, full weapon/tool repairs"},
 ["MedicineTable"] = {["Name"]="Medicine Table",["Tier"]=2,["Grade"]=2,["BuildType"]="MedicineTable",["InteractRadius"]=8,["Description"]="Advanced medical items and brewing"},
 ["SurveyDesk"] = {["Name"]="Survey Desk",["Tier"]=2,["Grade"]=2,["BuildType"]="SurveyDesk",["InteractRadius"]=8,["Description"]="Instruments, maps, and world-control devices"},
 ["EnchantingTable"] = {["Name"]="Enchanting Table",["Tier"]=3,["Grade"]=3,["BuildType"]="EnchantingTable",["InteractRadius"]=8,["Description"]="Apply, upgrade, extract, and transfer enchantments"},
 ["RepairBench"] = {["Name"]="Repair Bench",["Tier"]=4,["Grade"]=4,["BuildType"]="RepairBench",["InteractRadius"]=8,["Description"]="Crew repair queue and consolidated gear-maintenance page; uses normal Anvil/Loom repair costs"},
 ["Hand"] = {["Name"]="Hand Crafting",["Tier"]=0,["Grade"]=0,["InteractRadius"]=0},
}
C.Placeables = {
 ["Workbench"] = {["BuildType"]="Workbench",["Grade"]=1,["Kind"]="Station"},
 ["Campfire"] = {["BuildType"]="Campfire",["Grade"]=1,["Kind"]="Station"},
 ["Furnace"] = {["BuildType"]="Furnace",["Grade"]=1,["Kind"]="Station"},
 ["Loom"] = {["BuildType"]="Loom",["Grade"]=1,["Kind"]="Station"},
 ["Stove"] = {["BuildType"]="Stove",["Grade"]=2,["Kind"]="Station"},
 ["Oven"] = {["BuildType"]="Oven",["Grade"]=3,["Kind"]="Station"},
 ["Anvil"] = {["BuildType"]="Anvil",["Grade"]=2,["Kind"]="Station"},
 ["MedicineTable"] = {["BuildType"]="MedicineTable",["Grade"]=2,["Kind"]="Station"},
 ["SurveyDesk"] = {["BuildType"]="SurveyDesk",["Grade"]=2,["Kind"]="Station"},
 ["EnchantingTable"] = {["BuildType"]="EnchantingTable",["Grade"]=3,["Kind"]="Station"},
 ["RepairBench"] = {["BuildType"]="RepairBench",["Grade"]=4,["Kind"]="Station"},
 ["Floor"] = {["BuildType"]="Floor",["Grade"]=1,["Kind"]="Structure",["Description"]="8×8 stud foundation panel"},
 ["Wall"] = {["BuildType"]="Wall",["Grade"]=1,["Kind"]="Structure",["Description"]="8 studs wide, 8 tall; blocks ordinary physical movement"},
 ["Roof"] = {["BuildType"]="Roof",["Grade"]=1,["Kind"]="Structure",["Description"]="8×8 panel; contributes shade/rain shelter"},
 ["Ramp"] = {["BuildType"]="Ramp",["Grade"]=1,["Kind"]="Structure",["Description"]="8×8 run/rise connection"},
 ["Door"] = {["BuildType"]="Door",["Grade"]=1,["Kind"]="Structure",["Description"]="Player-operated 4-stud opening; F/touch toggle"},
 ["Gate"] = {["BuildType"]="Gate",["Grade"]=1,["Kind"]="Structure",["Description"]="Player-operated 8-stud opening"},
 ["Stairs"] = {["BuildType"]="Stairs",["Grade"]=1,["Kind"]="Structure",["Description"]="8-stud story connection"},
 ["Ladder"] = {["BuildType"]="Ladder",["Grade"]=1,["Kind"]="Structure",["Description"]="8-stud vertical connection"},
 ["Watchtower"] = {["BuildType"]="Watchtower",["Grade"]=1,["Kind"]="Structure",["Description"]="8×8, approximately 16 high, accessible ladder"},
 ["Chest"] = {["BuildType"]="Chest",["Grade"]=1,["Kind"]="Structure",["Description"]="24 shared item slots",["Slots"]=24},
 ["LargeChest"] = {["BuildType"]="LargeChest",["Grade"]=4,["Kind"]="Structure",["Description"]="48 shared slots",["Slots"]=48},
 ["Torch"] = {["BuildType"]="Torch",["Grade"]=1,["Kind"]="Structure",["Description"]="Placeable light; no heat protection"},
 ["StandingLamp"] = {["BuildType"]="StandingLamp",["Grade"]=3,["Kind"]="Structure",["Description"]="Larger camp light, no ongoing fuel"},
 ["RainCollector"] = {["BuildType"]="RainCollector",["Grade"]=2,["Kind"]="Structure",["Description"]="Produces one Water/minute during rain, stores up to 10; no offline production"},
 ["WaterFilter"] = {["BuildType"]="WaterFilter",["Grade"]=4,["Kind"]="Structure",["Description"]="Dirty Water ×1 becomes Water ×1 in 10s; consumes one Coal per 10 batches"},
 ["Bedroll"] = {["BuildType"]="Bedroll",["Grade"]=2,["Kind"]="Structure",["Description"]="Stationary recovery: +1 stamina/s and +0.2 exposure recovery/s; no passive HP or respawn"},
 ["SpikeTrap"] = {["BuildType"]="SpikeTrap",["Grade"]=2,["Kind"]="Structure",["Description"]="Upgradeable grade; deals 0.8D to one monster crossing it, 3s reset; consumes 1 Bone per 10 triggers"},
 ["CampMarker"] = {["BuildType"]="CampMarker",["Grade"]=1,["Kind"]="Structure",["Description"]="Visible named crew map marker"},
 ["TrailBeacon"] = {["BuildType"]="TrailBeacon",["Grade"]=3,["Kind"]="Beacon",["OutsideCamp"]=true,["Lifetime"]=900},
}
C.Instruments = {
 ["FieldClock"] = {["Grade"]=1,["Description"]="Reveals current shift countdown"},
 ["ThreatGauge"] = {["Grade"]=2,["Description"]="Shows campaign tier, bounded pressure, and nearby region danger"},
 ["ResourceCompass"] = {["Grade"]=3,["Description"]="Select a known resource and point toward nearest discovered matching site within 300 studs; no unexplored map reveal"},
 ["WeatherScanner"] = {["Grade"]=3,["Description"]="Shows current region's measured hazards, recovery sources, and preparation advice; does not forecast the next biome"},
 ["BiomePredictor"] = {["Grade"]=4,["Description"]="Shows next main biome and current shift countdown"},
 ["WeatherPredictor"] = {["Grade"]=4,["Description"]="Adds next visit's base weather; keeps clock/biome information"},
 ["EventDetector"] = {["Grade"]=5,["Description"]="Warns of a scheduled major surface event 45s before start and marks its discovered origin"},
 ["TrailBeacon"] = {["Grade"]=3,["Description"]="Placeable temporary named return marker outside camp; 15-minute lifetime; no teleport"},
 ["FieldJournal"] = {["Grade"]=5,["Description"]="Combines owned Clock/Gauge/Compass/Scanner/forecast functions into one carried item; event module can be inserted later"},
}
C.WorldDevices = {
 ["ShiftStabilizer"] = {["Grade"]=2,["Fuel"]={{["Id"]="Coal",["N"]=2},{["Id"]="Resin",["N"]=2}},["Cooldown"]=300,["VoteSeconds"]=20,["Action"]="Delay",["Seconds"]=60,["OncePerVisit"]=true},
 ["ShiftTrigger"] = {["Grade"]=2,["Fuel"]={{["Id"]="Coal",["N"]=2},{["Id"]="Cactus",["N"]=2}},["Cooldown"]=300,["VoteSeconds"]=20,["Action"]="Trigger",["MinimumVisitSeconds"]=60,["WarningSeconds"]=15},
 ["WorldDial"] = {["Grade"]=4,["Fuel"]={{["Id"]="ClearCrystal",["N"]=3},{["Id"]="HerbalPaste",["N"]=2}},["Cooldown"]=600,["VoteSeconds"]=20,["Action"]="Select",["VisitedOnly"]=true,["OncePerVisit"]=true},
 ["WorldAnchor"] = {["Grade"]=8,["Fuel"]={{["Id"]="MoonOre",["N"]=2},{["Id"]="LivingRoot",["N"]=2},{["Id"]="ClearCrystal",["N"]=4}},["Cooldown"]=900,["VoteSeconds"]=20,["Action"]="Anchor",["MaximumVisitSeconds"]=600,["ChooseWeather"]=true},
}
C.MaterialByTier = {"Stone","SteelBar","BlacksteelBar","MeteorBar","StormBar","ReinforcedBar","DeepMetal","MoonBar"}
C.ClothByTier = {"Cloth","WarmCloth","FireCloth","GlowCloth","StormCloth","ToughCloth","SailCloth","NightCloth"}
C.StandardDamage = {18,36,72,144,288,576,1152,2304}
C.PhysicalByTier = {0.08,0.18,0.3,0.42,0.54,0.64,0.73,0.8}
C.Trophies = {"AncientSeed","SunHeart","MarshHeart","FrostHeart","GreaterFireCore","CrystalHeart","DawnHeart","GreaterStarCore","TideHeart","GreaterStormCore","GrowthHeart","IronHeart","SkyHeart","ArchiveHeart","NightHeart","GravityShard"}
C.WeaponFamilies = {
 ["Spear"] = {["DamageFactor"]=1,["AttackCycle"]=1,["Reach"]=9,["Special"]="Lunge",["SpecialFactor"]=1.5,["SpecialTargets"]=1},
 ["Sword"] = {["DamageFactor"]=0.85,["AttackCycle"]=0.85,["Reach"]=8,["Special"]="Sweep",["SpecialFactor"]=1.1,["SpecialTargets"]=3},
 ["Dagger"] = {["DamageFactor"]=0.55,["AttackCycle"]=0.55,["Reach"]=6.5,["Special"]="QuickCut",["SpecialFactor"]=1.5,["SpecialTargets"]=1,["Slow"]=0.2,["SlowSeconds"]=3},
 ["Axe"] = {["DamageFactor"]=1.2,["AttackCycle"]=1.2,["Reach"]=8,["Special"]="HeavyCleave",["SpecialFactor"]=1.6,["SpecialTargets"]=2,["Stagger"]=0.5},
 ["Hammer"] = {["DamageFactor"]=1.65,["AttackCycle"]=1.65,["Reach"]=8,["Special"]="GroundSlam",["SpecialFactor"]=1.3,["SpecialTargets"]=6,["SpecialRadius"]=10,["Stagger"]=0.7},
 ["Bow"] = {["DamageFactor"]=1.2,["AttackCycle"]=1.3,["Reach"]=1000,["Special"]="PiercingShot",["SpecialFactor"]=1.6,["SpecialTargets"]=2,["Ammo"]="Arrow"},
 ["Staff"] = {["DamageFactor"]=1,["AttackCycle"]=1.1,["Reach"]=50,["Special"]="Burst",["SpecialFactor"]=1.25,["SpecialTargets"]=6,["SpecialRadius"]=7,["BasicStamina"]=3},
}
-- Melee spacing includes the existing two-stud reliability allowance, then the
-- shared 25% range increase applies to every melee family and concrete weapon.
local meleeFamilies = {Spear=true,Sword=true,Dagger=true,Axe=true,Hammer=true}
for family, profile in pairs(C.WeaponFamilies) do
 if meleeFamilies[family] then profile.Reach = (profile.Reach + 2) * 1.25 end
end
for _, gear in pairs(C.Gear) do
 if gear.Kind=="Weapon" and gear.WeaponFamily=="Bow" then gear.Reach=1000
 elseif gear.Kind=="Weapon" and meleeFamilies[gear.WeaponFamily] then gear.Reach = (gear.Reach + 2) * 1.25 end
end
C.FurnaceFuels = {
 ["Wood"] = 15,
 ["Peat"] = 30,
 ["Coal"] = 60,
}
C.Consumables = {
 ["Bandage"] = {["Health"]=25,["Duration"]=5},
 ["HealingWrap"] = {["Health"]=50,["Duration"]=8},
 ["FirstAidKit"] = {["Health"]=70,["Duration"]=10},
 ["RevivalKit"] = {["Revive"]=true,["Duration"]=5},
 ["Antidote"] = {["ClearPoison"]=true,["ToxinResistance"]=0.35,["Duration"]=120},
 ["DryingSalve"] = {["ClearWetness"]=true,["WetResistance"]=0.25,["Duration"]=120},
 ["RecoveryTonic"] = {["ExposureRelief"]=25,["ExposureRecovery"]=0.5,["Duration"]=60},
 ["FieldRepairKit"] = {["RepairFraction"]=0.25,["Grade"]=1,["Kind"]="ToolWeapon",["Duration"]=3},
 ["ArmorPatch"] = {["RepairFraction"]=0.25,["Grade"]=1,["Kind"]="Armor",["Duration"]=3},
 ["FieldRepairKit2"] = {["RepairFraction"]=0.25,["Grade"]=2,["Kind"]="ToolWeapon",["Duration"]=3},
 ["ArmorPatch2"] = {["RepairFraction"]=0.25,["Grade"]=2,["Kind"]="Armor",["Duration"]=3},
 ["FieldRepairKit3"] = {["RepairFraction"]=0.25,["Grade"]=3,["Kind"]="ToolWeapon",["Duration"]=3},
 ["ArmorPatch3"] = {["RepairFraction"]=0.25,["Grade"]=3,["Kind"]="Armor",["Duration"]=3},
 ["FieldRepairKit4"] = {["RepairFraction"]=0.25,["Grade"]=4,["Kind"]="ToolWeapon",["Duration"]=3},
 ["ArmorPatch4"] = {["RepairFraction"]=0.25,["Grade"]=4,["Kind"]="Armor",["Duration"]=3},
 ["FieldRepairKit5"] = {["RepairFraction"]=0.25,["Grade"]=5,["Kind"]="ToolWeapon",["Duration"]=3},
 ["ArmorPatch5"] = {["RepairFraction"]=0.25,["Grade"]=5,["Kind"]="Armor",["Duration"]=3},
 ["FieldRepairKit6"] = {["RepairFraction"]=0.25,["Grade"]=6,["Kind"]="ToolWeapon",["Duration"]=3},
 ["ArmorPatch6"] = {["RepairFraction"]=0.25,["Grade"]=6,["Kind"]="Armor",["Duration"]=3},
 ["FieldRepairKit7"] = {["RepairFraction"]=0.25,["Grade"]=7,["Kind"]="ToolWeapon",["Duration"]=3},
 ["ArmorPatch7"] = {["RepairFraction"]=0.25,["Grade"]=7,["Kind"]="Armor",["Duration"]=3},
 ["FieldRepairKit8"] = {["RepairFraction"]=0.25,["Grade"]=8,["Kind"]="ToolWeapon",["Duration"]=3},
 ["ArmorPatch8"] = {["RepairFraction"]=0.25,["Grade"]=8,["Kind"]="Armor",["Duration"]=3},
}
C.EnchantingCosts = {
 [3] = {["Dust"]=4,["Material"]=1,["Theme"]=1},
 [4] = {["Dust"]=8,["Material"]=2,["Theme"]=1},
 [5] = {["Dust"]=12,["Material"]=3,["Theme"]=2},
 [6] = {["Dust"]=18,["Material"]=4,["Theme"]=2},
 [7] = {["Dust"]=26,["Material"]=5,["Theme"]=3},
 [8] = {["Dust"]=40,["Material"]=6,["Theme"]=4},
}
-- Solid meals have deterministic recipe/seasoning IDs; these are ordinary shareable stacks.
local Cooking = require(script.Parent.CookingConfig).GetVersion(2)
local biomeNames={Forest="Woodlands",Desert="Dunes",Swamp="Marsh",FrozenTundra="Tundra",Volcanic="Volcanic Plains",CrystalWastes="Crystal Basin",AuroraVale="Northern Valley",StarfallCrater="Meteor Crater",SaltglassCoast="Coast",StormspireHighlands="Highlands",MyceliumHollow="Mushroom Forest",IronrootBadlands="Badlands",CanopySea="Rainforest",SunkenArchive="Flooded Ruins",UmbralDepths="Caverns",ShattermoonExpanse="Moon Surface"}
C.BiomeNames=biomeNames
for id,spice in pairs(Cooking.Seasonings) do
 if not C.Items[id] then
  C.Items[id]={Id=id,Name=spice.Name,Grade=1,StackSize=30,Tags={"Resource","Plant","Seasoning"},Description=spice.Effect.." for 240 seconds when cooked into a meal.",IconColor=spice.Color}
  C.Resources[id]={Id=id,Kind="Plant",Grade=1,MiningGrade=1,Biome=biomeNames[spice.Biome] or spice.Biome,Depth="A",Duration=1.5,Min=2,Max=4}
 else
  table.insert(C.Items[id].Tags,"Seasoning")
  C.Items[id].StackSize=30
 end
end
for id,meal in pairs(Cooking.Recipes) do
 local description=string.format("%d hunger / %d stamina. %s grade %d; %ds per serving.",meal.Hunger,meal.Stamina,meal.StationType,meal.Tier,meal.Work)
 for channel,value in pairs(meal.ExposureRelief or {}) do description ..= string.format(" Removes %d %s exposure.",value,channel) end
 C.Items[id]={Id=id,Name=meal.Name,Grade=meal.Tier,StackSize=meal.StackSize,Tags={"Food","Consumable","Cooking"},Description=description}
 C.Recipes[id]={Id=id,Ingredients=meal.Ingredients,Output={Id=id,N=1},AllowedStations={meal.StationType},Category="Cooking",ProcessKind="Food",BaseCraftTime=meal.Work,RequiredGrade=meal.Tier,CampaignTier=meal.Tier,Cooking=true}
 if not meal.Drink then
  for spiceId,spice in pairs(Cooking.Seasonings) do
   local output=id.."__"..spiceId
   C.Items[output]={Id=output,Name=meal.Name,Grade=meal.Tier,StackSize=meal.StackSize,Tags={"Food","Consumable","Cooking","Seasoned"},IconColor=spice.Color,RecipeId=id,SeasoningId=spiceId,Description=description.."\n"..spice.Name..": "..spice.Effect.." for 240 seconds."}
  end
 end
end
for id,snack in pairs(Cooking.Snacks) do
 local def=C.Items[id]
 if def then
  table.insert(def.Tags,"Consumable"); table.insert(def.Tags,"Food")
  def.Description=string.format("Restores %d hunger. ",snack.Hunger or 0)..def.Description
  for channel,value in pairs(snack.ExposureRelief or {}) do def.Description ..= string.format(" Removes %d %s exposure.",value,channel) end
 end
end
-- Gear metadata has a single canonical table even when item adapters clone their top level.
local function ensureItemTag(def, tag)
 if not def then return end
 def.Tags=def.Tags or {}
 if not table.find(def.Tags,tag) then table.insert(def.Tags,tag) end
end
for id,station in pairs(C.Stations) do
 if station then ensureItemTag(C.Items[id],"CraftingStation") end
end
for id,gear in pairs(C.Gear) do
 local def=C.Items[id]; def.Gear=gear
 if gear.Kind=="Accessory" then ensureItemTag(def,"Accessory") end
 local lines={gear.Description or string.format("Grade %d %s.",gear.Grade,string.lower(gear.Kind))}
 if gear.Damage then table.insert(lines,string.format("Damage %g | reach %g studs | attack %.2fs.",gear.Damage,gear.Reach,gear.AttackCycle)) end
 if gear.Power then table.insert(lines,string.format("Breaking power %d; %s tool.",gear.Power,gear.ToolFamily)) end
 if gear.Defense then table.insert(lines,string.format("Physical protection %.1f%%; %s slot.",gear.Defense*100,gear.Slot)) end
 for channel,value in pairs(gear.Resistance or {}) do table.insert(lines,string.format("%s protection %.1f%%.",channel,value*100)) end
 if gear.Durability>0 then table.insert(lines,string.format("Durability %d; repairable when worn out.",gear.Durability)) end
 if gear.Set then table.insert(lines,gear.Set.." set: "..C.ArmorFamilies[gear.Set].TwoDescription.." (2); "..C.ArmorFamilies[gear.Set].FourDescription.." (4).") end
 def.Description=table.concat(lines,"\n")
end
-- Register lighting before building the shared placement/recipe adapters.
local Lights = require(script.Parent.LightConfig).Definitions
for id, light in pairs(Lights) do
 local description=string.format("%s %d-stud light radius. No ongoing fuel; no heat protection.",light.Description,light.Range)
 if light.Ingredients then
  C.Items[id]={Id=id,Name=light.Name,Grade=light.Grade,Tier=light.Grade,StackSize=99,Tags={"Placeable","Holdable","Structure","Light"},Description=description,IconColor=light.Color}
  C.Placeables[id]={BuildType=id,Grade=light.Grade,Kind="Structure",Description=description}
  C.Recipes[id]={Id=id,Ingredients=light.Ingredients,Output={Id=id,N=1},AllowedStations={"Workbench"},Category="Structures",BaseCraftTime=light.CraftSeconds,RequiredGrade=light.Grade,CampaignTier=light.Grade}
 else
  C.Items[id].Description=description;C.Items[id].IconColor=light.Color
  ensureItemTag(C.Items[id],"Light")
  C.Placeables[id].Description=description
 end
 C.Items[id].LightRange=light.Range
end
local footprints={Floor={8,.5,8},Wall={8,8,.5},Roof={8,.5,8},Ramp={8,8,8},Door={4,8,.5},Gate={8,8,.5},Stairs={8,8,8},Ladder={3,8,1},Watchtower={8,16,8},Chest={4,3,3},LargeChest={6,3,3},Torch={1,4,1},StandingLamp={2,7,2},RainCollector={5,4,5},WaterFilter={4,5,4},Bedroll={3,.5,6},SpikeTrap={5,1,5},CampMarker={1,5,1},TrailBeacon={2,5,2}}
for id,placeable in pairs(C.Placeables) do
 local dims=footprints[id] or {5,4,4}
 placeable.Size=Lights[id] and Lights[id].Size or Vector3.new(dims[1],dims[2],dims[3])
 placeable.Recipe=C.Recipes[id]
 placeable.HoldSalvageSeconds=3
end
C.ResourceDefinitions = C.Resources
function C.Get(id) return C.Items[id] end
function C.GetStationUpgradeCost(nextGrade)
 if type(nextGrade)~="number" or nextGrade%1~=0 or nextGrade<2 or nextGrade>8 then return nil end
 return {{Id=C.MaterialByTier[nextGrade-1],N=6},{Id=C.ClothByTier[nextGrade-1],N=4},{Id="Plank",N=4}}
end
function C.GetRefineCost(gear,nextGrade)
 if not gear or gear.Kind~="Armor" or not gear.Set or type(nextGrade)~="number" or nextGrade%1~=0 or nextGrade<2 or nextGrade>8 or nextGrade<=(gear.Grade or 1) then return nil end
 return {{Id=C.MaterialByTier[nextGrade],N=math.max(1,math.ceil((gear.MaterialCost or 0)*.75))},{Id=C.ClothByTier[nextGrade],N=math.max(1,math.ceil((gear.ClothCost or 0)*.75))}}
end
function C.GetRepairCost(itemId,grade,durability)
 local gear=C.Gear[itemId]
 if not gear or gear.Kind=="Accessory" then return nil end
 grade=math.clamp(math.floor(grade or gear.Grade or 1),1,8)
 local maximum=(gear.Kind=="Armor" and 180+25*(grade-1)) or (gear.Kind=="Tool" and 300+40*(grade-1)) or 400+40*(grade-1)
 local missing=1-math.clamp((durability or maximum)/maximum,0,1)
 if missing<=0 then return {} end
 if itemId=="Harvester" then return {{Id="Stone",N=1}} end
 local result={}
 if gear.Kind=="Armor" then
  local cloth=gear.ClothCost or 0; local material=gear.MaterialCost or 0
  if material>0 then table.insert(result,{Id=C.MaterialByTier[grade],N=math.max(1,math.ceil(.2*missing*material))}) end
  if cloth>0 then table.insert(result,{Id=C.ClothByTier[grade],N=math.max(1,math.ceil(.2*missing*cloth))}) end
  if #result==0 then result={{Id="Fiber",N=1}} end
 else
  local material=gear.WeaponFamily=="Bow" and 2 or gear.Kind=="Tool" and 3 or 4
  table.insert(result,{Id=C.MaterialByTier[grade],N=math.max(1,math.ceil(.2*missing*material))})
 end
 return result
end
function C.GetRecipe(id) return C.Recipes[id] end
function C.GetGear(id) return C.Gear[id] end
function C.GetMaterial(grade) return C.MaterialByTier[math.clamp(math.floor(grade or 1),1,8)] end
function C.GetCloth(grade) return C.ClothByTier[math.clamp(math.floor(grade or 1),1,8)] end
function C.EnchantmentStatText(enchantment)
 local e=type(enchantment)=="table" and enchantment or C.Enchantments[enchantment]
 if not e then return "" end
 local values={}
 for _,raw in ipairs(e.Values or {}) do
  local value=(tonumber(raw) or 0)*(e.ValueScale or 1)
  local rounded=math.round(value*10)/10
  local shown=rounded%1==0 and tostring(math.floor(rounded)) or tostring(rounded)
  table.insert(values,(e.ValuePrefix or "")..shown..(e.ValueSuffix or ""))
 end
 return (e.ValueLabel or "Effect").." by rank · "..table.concat(values," / ")
end
function C.EnchantmentSlots(kind, grade)
 if kind == "Accessory" then return grade >= 5 and 1 or 0 end
 if kind == "Armor" then return grade >= 5 and 2 or grade >= 3 and 1 or 0 end
 return grade >= 6 and 3 or grade >= 4 and 2 or grade >= 3 and 1 or 0
end
function C.CanUseEnchantment(gear, enchantment)
 if type(gear)=="string" then gear=C.Gear[gear] end
 local enchantmentId=type(enchantment)=="table" and enchantment.Id or enchantment
 if not gear or type(enchantmentId)~="string" then return false end
 return table.find(gear.AllowedEnchantments or {},enchantmentId)~=nil
end
function C.CanEnchant(gear, enchantment, rank)
 local e = type(enchantment)=="table" and enchantment or C.Enchantments[enchantment]
 return e~=nil
  and C.CanUseEnchantment(gear,e)
  and e.Grades[rank]~=nil
  and (gear.Grade or 1)>=e.Grades[rank]
end
return C
