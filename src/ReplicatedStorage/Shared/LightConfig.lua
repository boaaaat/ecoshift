-- One source for light art, illumination, recipes, and client-only effects.
-- Range is Roblox PointLight.Range in studs, not the diameter of the lit area.
local function ingredient(id, count) return {Id = id, N = count} end
local I, V, RGB = ingredient, Vector3.new, Color3.fromRGB
local C = { SourceTag = "ExpeditionLightSource", Definitions = {} }
local function light(id, name, grade, range, color, style, size, description, ingredients, seconds)
	C.Definitions[id] = {
		Id = id, Name = name, Grade = grade, Range = range, Color = color, Style = style, Size = size,
		Brightness = 1.35 + grade * .12, Description = description, Ingredients = ingredients, CraftSeconds = seconds,
		Effect = "Motes", Accent = color:Lerp(RGB(245, 239, 218), .35),
	}
	return C.Definitions[id]
end

local torch = light("Torch", "Torch", 1, 16, RGB(255, 196, 102), "Torch", V(1, 4, 1), "A bound timber torch with a square ember head.")
torch.Effect, torch.FlameSize, torch.Brightness = "Flame", 2.2, 1.6
-- Existing recipes and trail-beacon lifetime remain owned by OverhaulCatalog.
light("StandingLamp", "Standing Lamp", 3, 24, RGB(233, 181, 77), "Standing", V(2, 7, 2), "A brass-caged camp lamp.").Brightness = 1.6
light("TrailBeacon", "Trail Beacon", 3, 16, RGB(233, 181, 77), "Trail", V(2, 5, 2), "Temporary return marker; lasts 15 minutes and can be placed outside camp.").Brightness = 1.6

local candle = light("CandleLantern", "Candle Lantern", 1, 10, RGB(255, 229, 173), "Candle", V(1.8, 2.5, 1.8),
	"A small wooden lantern with a sheltered square candle.", {I("Wood", 2), I("Resin", 2), I("Fiber", 1)}, 6)
candle.Effect, candle.FlameSize = "Flame", .8
light("MireGlowLantern", "Mireglow Lantern", 2, 18, RGB(166, 239, 106), "Mire", V(2.4, 3.5, 2.4),
	"A mossy root cage holding luminous marsh caps.", {I("Glowcap", 4), I("Glass", 2), I("IronBar", 1)}, 10)
light("FrostglassLamp", "Frostglass Lamp", 2, 22, RGB(130, 216, 255), "Frost", V(2.6, 4.8, 2.6),
	"An ice-blue lens between a crown of frost crystals.", {I("IceCrystal", 4), I("Glass", 3), I("SteelBar", 2)}, 14)
local ember = light("EmberBrazier", "Ember Brazier", 3, 26, RGB(255, 105, 67), "Brazier", V(3.8, 3.8, 3.8),
	"A blacksteel fire bowl with glowing coals and clawed corners.", {I("BlacksteelBar", 3), I("BlackGlass", 4), I("Coal", 3)}, 18)
ember.Effect, ember.FlameSize = "Flame", 4
light("AmethystObelisk", "Amethyst Obelisk", 3, 28, RGB(196, 130, 255), "Obelisk", V(3, 6.5, 3),
	"An etched stone spire cradling a violet crystal.", {I("ClearCrystal", 6), I("BlacksteelBar", 3), I("EnchantingDust", 4)}, 22)
light("AuroraLantern", "Aurora Lantern", 4, 32, RGB(108, 255, 195), "Aurora", V(3.8, 6, 3.8),
	"A mint-green lens with a sweeping double arch and aurora ribbons.", {I("AuroraStone", 4), I("GlowFiber", 4), I("MeteorBar", 3), I("Glass", 3)}, 28)
light("StarfallOrrery", "Starfall Orrery", 4, 36, RGB(255, 194, 137), "Orrery", V(5.4, 6.8, 5.4),
	"A suspended star core inside tilted brass orbits and satellite stones.", {I("StarCore", 2), I("MeteorBar", 4), I("ImpactGlass", 5), I("Gears", 3)}, 34)
light("StormcoilBeacon", "Stormcoil Beacon", 5, 40, RGB(103, 156, 255), "Storm", V(4.2, 7.5, 4.2),
	"An electric-blue reactor with layered coils and four lightning prongs.", {I("StormBar", 5), I("StormOre", 6), I("Gears", 4), I("ClearCrystal", 4)}, 42)
light("AbyssalPrism", "Abyssal Prism", 7, 48, RGB(149, 119, 255), "Abyss", V(5.8, 8, 5.8),
	"A rare deep-metal shrine with a suspended prism, orbiting shards, and luminous rune bands.", {I("DeepMetal", 6), I("LightOre", 8), I("PressureGlass", 4), I("NightHeart", 1)}, 60)
light("MoonwellBeacon", "Moonwell Beacon", 8, 60, RGB(217, 211, 255), "Moon", V(7, 9, 7),
	"A celestial monument: crescent crown, twin orbital halos, floating moons, and a silver well of light.", {I("MoonBar", 8), I("MoonThread", 6), I("GravityShard", 1), I("EnchantingDust", 20)}, 80)

return C
