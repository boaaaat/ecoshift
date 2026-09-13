-- Nearby caches supplement ordinary materials without bypassing region progression.
local Catalog=require(script.Parent.OverhaulCatalog)
local Config={CacheMaterials={}}
function Config.CacheTable(biome)
 local name=Catalog.BiomeNames[biome] or biome
 local raw={"Wood","Stone","Fiber"}
 local tier=tonumber(workspace:GetAttribute("CampaignTier")) or 1
 for id,r in pairs(Catalog.Resources) do
  if r.Biome==name and r.Depth<="B" and r.Grade<=tier and r.Kind~="Animal" then table.insert(raw,id) end
 end
 local common,rare={},{}
 for _,id in ipairs(raw) do table.insert(common,{Id=id,Min=2,Max=5,Weight=1});table.insert(rare,{Id=id,Min=4,Max=7,Weight=1}) end
 for _,id in ipairs({"Plank","Cloth","HerbalPaste"}) do table.insert(rare,{Id=id,Min=1,Max=2,Weight=.7}) end
 return {Name=biome.."Supplies",Rarities={Common={Rolls=3,Unique=true,AllowDuplicates=false,Items=common,Guaranteed={{Id="Bandage",Min=1,Max=1}}},Rare={Rolls=4,Unique=true,AllowDuplicates=false,Items=rare,Guaranteed={{Id="StaminaRation",Min=1,Max=2},{Id="Bandage",Min=1,Max=2}}}}}
end
-- Grades advance with campaign certification; deep ranks require deep regions too.
function Config.EligibleSchematics(biome,depth,tier)
 depth=type(depth)=="string" and string.byte(depth)-64 or tonumber(depth) or 1
 local maxGrade=math.min(tonumber(tier) or 1,({0,3,5,7,8})[math.clamp(depth,1,5)])
 local biomeName=Catalog.BiomeNames[biome] or biome
 local pages={}
 for id,enchantment in pairs(Catalog.Enchantments) do
  for rank,grade in ipairs(enchantment.Grades) do
   if grade<=maxGrade then
    local theme=enchantment.Themes and enchantment.Themes[rank] or enchantment.Theme
    local source=Catalog.Resources[theme]
    table.insert(pages,{Id=id.."Schematic"..rank,Min=1,Max=1,Weight=source and source.Biome==biomeName and 3 or 1})
   end
  end
 end
 table.sort(pages,function(a,b)return a.Id<b.Id end)
 return pages
end
local function pick(pool,rng)
 local total=0;for _,entry in ipairs(pool) do total+=entry.Weight or 1 end
 if total<=0 then return nil end
 local roll=rng:NextNumber()*total
 for index,entry in ipairs(pool) do roll-=entry.Weight or 1;if roll<=0 then return index,entry end end
 return #pool,pool[#pool]
end
function Config.RollCache(biome,depth,tier,rng)
 rng=rng or Random.new()
 local tableDef=Config.CacheTable(biome).Rarities.Rare
 local output={};local pool=table.clone(tableDef.Items)
 for _,entry in ipairs(tableDef.Guaranteed) do table.insert(output,{Id=entry.Id,N=rng:NextInteger(entry.Min,entry.Max)}) end
 for _=1,tableDef.Rolls do
  local index,entry=pick(pool,rng);if not entry then break end
  table.remove(pool,index);table.insert(output,{Id=entry.Id,N=rng:NextInteger(entry.Min,entry.Max)})
 end
 local pages=Config.EligibleSchematics(biome,depth,tier)
 if #pages>0 and rng:NextNumber()<.18+.03*math.clamp(tonumber(depth) or 1,1,5) then
  local _,page=pick(pages,rng);table.insert(output,{Id=page.Id,N=1})
 end
 return output
end
function Config.ResourceProfile(item,prefabName)
 local source=Catalog.Resources[item.Id]
 if not source then return {Health=200,Min=2,Max=4,MiningGrade=1,Kind="Other"} end
 local result=table.clone(source)
 if item.Id=="Wood" and prefabName=="BigTree" then result.Health=source.LargeHealth end
 return result
end
return Config
