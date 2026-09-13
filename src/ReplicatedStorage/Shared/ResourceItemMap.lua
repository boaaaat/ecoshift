local Catalog=require(script.Parent.OverhaulCatalog)
local Map={Map={Tree="Wood",BigTree="Wood",SmallTree="Wood",Reed="Fiber",MossFlowers="HealingHerb",Sandstone="Stone",SunCrystal="Sunstone",PeatMound="Peat",GlowcapCluster="Glowcap",MangroveTree="Wood",CypressTree="Wood",WillowTreeSwamp="Wood",Crystal="ClearCrystal"}}
function Map.Normalize(id)
 if type(id)~="string" then return id end
 if Catalog.Items[id] then return id end
 return Map.Map[id] or id
end
return Map
