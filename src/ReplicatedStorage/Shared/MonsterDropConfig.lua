local Catalog=require(script.Parent.OverhaulBiomes)
local Config={Monsters={}}
local minerals={LavaGolem="BlackGlass",PrismGuard="ClearCrystal",CrystalStalker="ClearCrystal",ShardMite="ClearCrystal",CrystalGrazer="Stone",RockCrawler="ImpactGlass",StarBeetle="ImpactGlass",DustMite="Stone",ArchiveGuard="OldGear",Stoneback="Stone",MoonCrawler="MoonRock",RiftHopper="MoonRock",MoonMite="MoonRock",DustGrazer="MoonRock"}
local plants={BarkSpider="Fiber",SporeMite="GlowMushroom",RootGuardian="ThickSpores",CapBeetle="GlowMushroom",MossSnail="Mushroom"}
for id,creature in pairs(Catalog.Creatures) do
 local primary=minerals[id] or plants[id] or "RawMeat"
 local drops={{ItemId=primary,Min=1,Max=creature.Role=="N" and 1 or 3,Chance=1}}
 if creature.Role~="N" and not minerals[id] and not plants[id] then table.insert(drops,{ItemId="Bone",Min=1,Max=2,Chance=.5}) end
 if id:find("Wolf") or id:find("Bear") then table.insert(drops,{ItemId="WarmFur",Min=1,Max=2,Chance=.7}) end
 if id=="Leech" or id=="BogToad" then table.insert(drops,{ItemId="VenomGland",Min=1,Max=1,Chance=.35}) end
 if id=="Rustback" or id=="ThornJackal" then table.insert(drops,{ItemId="ToughHide",Min=1,Max=2,Chance=.65}) end
 Config.Monsters[id]={Boss=false,Drops=drops,CraftUnlocks={}}
end
return Config
