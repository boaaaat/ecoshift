-- Shared, deterministic meal identities preserve seasoning through ordinary Id/N inventories.
local C = {}
C.Version = 2
C.MaxJobs = 3
C.MaxQuantity = 20
C.OutputSlots = 12
C.SeasoningDuration = 240
C.Fuels = { Wood = 60, Peat = 120, Coal = 240 }
C.Stations = {
 Campfire = {Name="Campfire",Tier=1,InteractRadius=15},
 Stove = {Name="Stove",Tier=2,InteractRadius=15},
 Oven = {Name="Oven",Tier=3,InteractRadius=15},
}
C.Recipes = {}
C.RecipeOrder = {}
local function meal(id,name,station,tier,work,hunger,stamina,ingredients,extra)
 local r = {Version=2,Id=id,Name=name,StationType=station,Tier=tier,Work=work,WorkSeconds=work,Hunger=hunger,Stamina=stamina,Ingredients=ingredients,StackSize=10}
 for key,value in pairs(extra or {}) do r[key]=value end
 C.Recipes[id]=r; table.insert(C.RecipeOrder,id)
end
meal("RoastedMeat","Roasted Meat","Campfire",1,8,25,10,{{Id="RawMeat",N=1}})
meal("RoastedMushrooms","Roasted Mushrooms","Campfire",1,8,22,8,{{Id="Mushroom",N=3}})
meal("BakedRoots","Baked Roots","Campfire",1,10,24,5,{{Id="RootVegetable",N=2}})
meal("MushroomSoup","Mushroom Soup","Stove",2,12,30,12,{{Id="Mushroom",N=3},{Id="Water",N=1}},{ExposureRelief={Cold=15}})
meal("TrailMeal","Trail Meal","Stove",2,12,35,20,{{Id="RoastedMeat",N=1},{Id="Mushroom",N=2}})
meal("VegetableStew","Vegetable Stew","Stove",2,14,38,15,{{Id="RootVegetable",N=2},{Id="Mushroom",N=2},{Id="Water",N=1}})
meal("BerryPorridge","Berry Porridge","Stove",2,12,30,22,{{Id="RootVegetable",N=2},{Id="Berries",N=3},{Id="Water",N=1}})
meal("StaminaRation","Stamina Ration","Stove",2,14,24,30,{{Id="Mushroom",N=3},{Id="Cactus",N=2},{Id="Reeds",N=1}},{StackSize=30})
meal("CoolingDrink","Cooling Drink","Stove",2,8,0,0,{{Id="Cactus",N=2},{Id="Water",N=1},{Id="HealingHerb",N=1}},{Drink=true,ExposureRelief={Heat=35},Thermal={Channel="Heat",Reduction=.35,Duration=120}})
meal("WarmingDrink","Warming Drink","Stove",2,8,0,0,{{Id="Mushroom",N=2},{Id="Water",N=1},{Id="HealingHerb",N=1}},{Drink=true,ExposureRelief={Cold=35},Thermal={Channel="Cold",Reduction=.35,Duration=120}})
meal("DriedFood","Dried Food","Oven",3,18,30,10,{{Id="RawMeat",N=1},{Id="Mushroom",N=1}},{StackSize=30})
meal("StuffedMushrooms","Stuffed Mushrooms","Oven",3,18,45,25,{{Id="Mushroom",N=3},{Id="RawMeat",N=1},{Id="HealingHerb",N=1}})
meal("RootRoast","Root Roast","Oven",3,18,42,25,{{Id="RootVegetable",N=3},{Id="Mushroom",N=2},{Id="Berries",N=2}})
meal("HuntersRoast","Hunter's Roast","Oven",4,24,55,30,{{Id="RawMeat",N=3},{Id="RootVegetable",N=2},{Id="HealingHerb",N=1}})
meal("GlowcapStew","Glowcap Stew","Stove",4,20,45,35,{{Id="Glowcap",N=2},{Id="Mushroom",N=2},{Id="RootVegetable",N=1},{Id="Water",N=1}})
meal("ExpeditionMeal","Expedition Meal","Oven",6,28,60,45,{{Id="RoastedMeat",N=2},{Id="GlowMushroom",N=2},{Id="RootVegetable",N=2}})
C.Snacks = {
 Mushroom={Id="Mushroom",Hunger=6,Stamina=0},
 Berries={Id="Berries",Hunger=5,Stamina=0},
 RootVegetable={Id="RootVegetable",Hunger=4,Stamina=0},
 Cactus={Id="Cactus",Hunger=8,Stamina=0,ExposureRelief={Heat=5}},
 Water={Id="Water",Hunger=0,Stamina=0,Drink=true,ExposureRelief={Heat=30}},
}
C.Seasonings = {}
C.SeasoningOrder = {}
local function spice(id,name,biome,effect,key,value,hex,future)
 C.Seasonings[id]={Id=id,Name=name,Biome=biome,Effect=effect,Modifiers={[key]=value},Duration=240,Color=Color3.fromHex(hex),Future=future==true}
 table.insert(C.SeasoningOrder,id)
end
spice("WildHerb","Wild Herb","Forest","10% less hunger drain","HungerDrainReduction",.10,"99BA7C")
spice("CoolMint","Cool Mint","Desert","15% less heat buildup","HeatReduction",.15,"8DDCC1")
spice("BitterSeed","Bitter Seed","Swamp","15% less poison damage; does not cure poison","PoisonDamageReduction",.15,"B7BA69")
spice("WarmPepper","Warm Pepper","FrozenTundra","15% less cold buildup","ColdReduction",.15,"DA776D")
spice("EmberPepper","Ember Pepper","Volcanic","8% more direct weapon damage to monsters","MonsterDamageBonus",.08,"F4A160")
spice("CrystalBasil","Crystal Basil","CrystalWastes","8% more resource breaking power","ResourcePowerBonus",.08,"B9A3EA")
spice("DawnFlower","Dawn Petal","AuroraVale","20% more natural exposure recovery","ExposureRecoveryBonus",.20,"F0C8A2")
spice("StarSeed","Star Seed","StarfallCrater","10% less sprint stamina drain","SprintDrainReduction",.10,"C1BBF4")
spice("Salt","Sea Salt","SaltglassCoast","15% less wetness buildup","WetnessReduction",.15,"E6DFC8")
spice("StormThyme","Storm Thyme","StormspireHighlands","10% more natural stamina recovery","StaminaRecoveryBonus",.10,"9ECACF")
spice("GlowSpice","Glow Spice","MyceliumHollow","10% faster hand gathering","GatherDurationReduction",.10,"ACDBAA")
spice("RedGarlic","Red Garlic","IronrootBadlands","5% less incoming monster damage","MonsterDamageReduction",.05,"BC7266")
spice("CitrusPeel","Citrus Peel","CanopySea","10% less dodge stamina cost","DodgeDrainReduction",.10,"E1BF64")
spice("RiverDill","River Dill","SunkenArchive","8% faster swimming","SwimSpeedBonus",.08,"91CFC0")
spice("CaveAnise","Cave Anise","UmbralDepths","10% less underwater air consumption","AirDrainReduction",.10,"D9D2B8")
spice("MoonPoppy","Moon Poppy","ShattermoonExpanse","10% less weapon-special stamina cost","SpecialDrainReduction",.10,"CCC3E9")
-- One current recipe catalog; old worlds and their recipe versions were retired.
function C.GetVersion(version) assert(version==2,"Retired cooking version");return C end
function C.GetOutputId(recipeId,seasoningId)
 local r=C.Recipes[recipeId]
 if not r then return nil end
 if seasoningId==nil or seasoningId=="" then return recipeId end
 local s=C.Seasonings[seasoningId]
 if r.Drink or not s or s.Future then return nil end
 return recipeId.."__"..seasoningId
end
function C.GetMeal(itemId)
 if type(itemId)~="string" then return nil end
 if C.Recipes[itemId] then return C.Recipes[itemId],nil end
 local base,spiceId=itemId:match("^([%w]+)__([%w]+)$")
 if base and C.GetOutputId(base,spiceId)==itemId then return C.Recipes[base],C.Seasonings[spiceId] end
 return nil
end
function C.Describe(itemId)
 local r,s=C.GetMeal(itemId)
 if not r then
  local spiceDef=C.Seasonings[itemId]
  if spiceDef then return "Optional meal seasoning: "..spiceDef.Effect.." for 240 seconds. One seasoning per meal." end
  r=C.Snacks[itemId]
 end
 if not r then return nil end
 local lines={string.format("Restores %d hunger and %d stamina.",r.Hunger or 0,r.Stamina or 0)}
 for channel,amount in pairs(r.ExposureRelief or {}) do table.insert(lines,string.format("Removes %d %s exposure.",amount,string.lower(channel))) end
 if r.Thermal then table.insert(lines,string.format("%d%% less %s buildup for %ds.",r.Thermal.Reduction*100,string.lower(r.Thermal.Channel),r.Thermal.Duration)) end
 if s then table.insert(lines,s.Name..": "..s.Effect.." for 240s.") end
 return table.concat(lines,"\n")
end
return C
