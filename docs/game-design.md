# Ecoshift — survival and progression plan

The approved scope is 16 biomes: eight playable now and eight on the future roadmap. Powerful world-control equipment targets a 60–90 minute cooperative run, with endless survival afterward. Existing internal IDs remain stable. Recipe quantities, encounter tuning, and device limits are adjustable balance values; future content is explicitly separated below.

## Confirmed rules

- Cooperative survival; the goal is to keep the whole team alive as long as possible.
- The world normally shifts every 300 seconds. Built structures and stored items survive; old monsters are removed when the biome changes.
- A world-control action requires a majority team vote.
- World-control devices are reusable, with fuel costs and limits on each activation.
- The shift countdown is hidden until a player owns FieldClock or an upgraded intel device. BiomePredictor adds the next biome; WeatherPredictor adds the next weather and retains both earlier capabilities.
- Fallen players leave a ragdoll, spectate, and can return through a teammate's crafted revive kit. A full-team wipe ends the run and automatically removes that world's named copies from every owner's archive, freeing their save slots for the return to lobby. Active and paused worlds remain resumable.
- Temporary Roblox Creator Store models support playtesting; original Blender models come later.
- The UI direction is a clean animated field kit, with a distinct Ecoshift identity.
- Approved playable roster: Verdant Reach, Sunscar Dunes, Mirefen, Frostfall, Cinder Rift, Prism Barrens, Aurora Vale, and Starfall Crater.
- Eight additional biomes remain future content, outside generation, forecasts, and world-control voting.

## Five-minute team rhythm

On arrival, identify the biome and weather, compare the team's protection, and agree on the current shortage. Divide gathering, scouting, camp processing, and defense according to the situation rather than permanently locking players into classes. Bring materials home before the next shift. Store a recovery reserve: food, basic wood and stone, fiber, resin, and revive kits.

Preparation should create decisions: wear the best cold protection or keep stronger physical armor; spend precious glass on a safer expedition or save it for world control; extend a productive biome or advance to escape a dangerous one. A shift changes what can be gathered, not the value of everything already gathered.

The clock advances without forcing an expedition to every resource node. Common supplies must be sufficiently available in each region; rare cores require deliberate encounters. Never require a station to craft its own construction inputs. Avoid hiding an essential early resource exclusively inside random chests.

## Biome roster

These eight biomes have generation, resource, monster, weather, and crafting data. Internal IDs appear in parentheses.

| Biome | Survival identity and weather | Materials that stay useful | Encounter roles |
| --- | --- | --- | --- |
| Verdant Reach (`Forest`) | Recovery, camp foundations, rain and mist | Wood and stone for every camp; ReedFiber, SapResin, SpringWater; MossBloom for medicine; WolfPelt and WolfFang | Wolf packs isolate gatherers; fauna and readable sight lines make this the learning biome |
| Sunscar Dunes (`Desert`) | Heat, exposed travel, heatwaves and sandstorms | CactusStem for food/fiber; SulfiteOre and Coal for metal; Sand, SaltCrystal, SunShard for glass and solar components | Scorpion close ambusher; SandSerpent pursuit/burrow specialist |
| Mirefen (`Swamp`) | Wetness and toxins, rain and spore fog | BogReed/RootFiber textiles, PeatClump fuel/composites, MireStone, Glowcap, MarshWater, WillowBark; venom sacs/glands for medicine | GiantLeech attrition and sticky pursuit; BogToad slower area denial/ranged tongue |
| Frostfall (`FrozenTundra`) | Cold and exposure, snowfall and whiteouts | Frostwood, FrozenReed, SnowLichen, ChillBloom; IceCrystal optics and PermafrostOre cooling alloys; fur and essence | FrostWolf coordinated flanker; IceWraith fast visible attack windup followed by recovery |
| Cinder Rift (`Volcanic`) | Severe heat and ash, ashfall and emberstorms | BasaltChunk, SulfurOre, ObsidianShard, EmberBloom, AshFiber, LavaSalt, ScoriaRock; MagmaCore and GolemFragment for powerful machinery | MagmaHound chase pressure; LavaGolem slow telegraphed siege elite, not merely a bigger wolf |
| Prism Barrens (`CrystalWastes`) | Unstable visibility and energy, crystal haze and static storms | CrystalShard, VoidResidue, AlloyDust, PhaseQuartz, PrismSand, EchoBloom, LatticeFiber; SentinelCore/NullFragment for precise control | CrystalStalker repositioning skirmisher; VoidSentinel deliberate arena-control elite |
| Aurora Vale (`AuroraVale`) | Warm dawn surges alternate with polar cold every minute; protection against both matters | AuroraFiber and DawnBloom form treated lining; PolarQuartz becomes AuroraLens; AuroraAntler supports adaptive clothing | AuroraStag is a fast, lighter-hitting pursuer with a longer recovery window |
| Starfall Crater (`StarfallCrater`) | Heat, meteor showers, and cosmic dust haze | MeteorIron and CosmicDust combine with cooling/heating alloys; ImpactGlass reinforces armor; MeteorCore powers exact world selection | CometCrawler is a slow, heavy-hitting pursuer with a long attack recovery |

Enemy roles are the target behavior, not a description of current AI: the existing catalog mostly shares Wolf AI. Each needs a recognizable silhouette, windup, attack window, and recovery before extra attack patterns are added. Preserve the existing species IDs while models and behaviors improve.

## Eight future biomes

These complete the 16-biome plan. They are design proposals only: there are no active generation entries or craftable dependencies on their materials. The shared `future_biomes` catalog explicitly marks each as unimplemented.

| Future biome | World condition | Planned materials and equipment purpose | Planned monster roles |
| --- | --- | --- | --- |
| Saltglass Coast | Tidal flooding, sea mist, wind | BrinePearl, ShellPlate, KelpCord; waterproof storage and buoyant structures using Mirefen sealants | TideCrab guards resource beds; FoamRay patrols flooded routes |
| Stormspire Highlands | Gusts and charged storms | CopperSpine, Stormglass, CloudFleece; grounding rods and weather-control fuel combined with Prism optics | GaleRaptor pressures exposed travel; ThunderRam telegraphs straight charges |
| Mycelium Hollow | Spore blooms and nutrient cycles | MyceliumCord, SporeHeart, RemedyCap; longer-lasting medicines using Verdant herbs and Aurora lining | SporeMite swarms; Bloomkeeper defends medicine-rich groves |
| Ironroot Badlands | Dust storms and abrasive heat | FerricRoot, RedClay, RustCrystal; reinforced camps and machinery using Starfall alloys | Rustback is armored at the front; Drillmaw attacks stationary camps after warning |
| Sunken Archive | Flooded ruins, pressure, low visibility | ArchiveGlass, PressurePearl, SalvageFilament; diving protection and remote survey devices | LanternEel lures explorers; ArchiveGuardian protects salvage chambers |
| Canopy Sea | Vertical travel, rainfall, fragile bridges | CanopySilk, FloatSeed, Heartwood; gliders and rope transport using Frostfall insulation | Branchstalker ambushes isolated players; SailMoth moves between canopy routes |
| Umbral Depths | Darkness and sound-sensitive hazards | LumenOre, EchoChitin, DeepMoss; camp lighting and acoustic scouts using Prism circuitry | EchoHunter follows noise; LanternGrazer creates temporary safe light pockets |
| Shattermoon Expanse | Intermittent low gravity and vacuum gusts | LunarBasalt, GravityShard, MoonThread; expensive world anchors combining Aurora optics and meteor cores | OrbitWarden controls movement lanes; RiftSkipper telegraphs displacement attacks |

Future biomes should extend survival options after the eight-biome equipment path is stable. They must not become surprise prerequisites for today's recipes. Adding their mechanics will require their own implementation and playtesting pass.

## Progression and recipes

Proposed stage gates depend on materials and achievements rather than character level. The team should be able to revisit earlier biomes throughout a long run.

| Stage | Crafting and survival goals | Cross-biome dependency |
| --- | --- | --- |
| Establish | Hand craft StoneSpear, ReedSunwrap, camp basics, and ReviveKit; build Workbench, then Loom/Furnace; make StoneHatchet and StonePickaxe | Forest alone enables gathering, fighting, recovery, food, and first-desert heat preparation; BoneSpear can add a Desert encounter objective |
| Adapt | Add FieldClock, DesertCloak, SwampWaders, medicine, improved food, and Sandite tools; construct AlchemyTable | Two biome inputs for protective kits and countdown access; Forest supplies still consumed |
| Coordinate | AdvancedWorkbench; forecast equipment; choose whether to delay or force the next shift | Forest + Desert + Swamp processing; monster-derived catalysts give hunting a purpose |
| Endure | FrostParka, VolcanicPlate, Cryo tools; Refinery; stronger specialized weapons | Three to four biomes; cooling and heat materials complement one another |
| Direct | Exact-biome selector and adaptive equipment; keep a shared fuel reserve | All eight biomes plus elite cores; world control remains costly |

The implemented final tier now extends to all eight biomes: AuroraLens and MeteorAlloy/MeteorCore join BiomeSelector; AdaptiveSurvivalSuit combines the six-biome suit path with AuroraMantle and MeteorAlloy. MeteorPike and StarforgedPlate provide late combat options. Every new raw resource has a current recipe use.

Keep existing stations for compatibility initially, but simplify onboarding: show the next useful station and hide unavailable recipe detail behind clear requirements. DryingRack, Kiln, and Refinery can improve throughput; they should not create arbitrary extra steps for basic medicine. Decide later whether all twelve station types deserve distinct models and UI space.

Current bootstrap repairs expand self-dependent station ingredients into their existing components. This preserves material/biome gates without allowing high-tier refined materials to be hand crafted. Every raw item required by a recipe needs an explicit gather or monster source.

The first Forest loop now includes a hand-crafted StoneSpear (ForestWood ×3, ForestStone ×2, ReedFiber ×2). BrownMushroom is already edible raw and restores 6 hunger; CactusStem restores 8. StaminaRation remains a better processed food that combines three biomes, rather than being the first way to eat. FieldClock uses a provisional Forest/Desert recipe at Workbench: TemperedGlass ×2, SanditeIngot ×1, ForestPlank ×2.

New content should reduce redundant materials rather than add many synonymous rocks. Each biome has a small core of common supplies, one signature processor input, and one valuable encounter drop. Existing extra raw IDs remain supported while recipes are rationalized.

## Armor and weather

Protection has separate heat, cold, toxin, and wetness channels. Armor still reduces physical damage. Resistances remove a fraction of matching exposure, never all hazards automatically. The shared `SurvivalConfig` supplies provisional exposure fractions and weather variations.

- ReedSunwrap: hand craft ReedFiber ×6, MossBloom ×2 and SapResin ×2 in five seconds. All ingredients come from Verdant Reach. Provides 4 armor and 70% heat resistance, with no cold/toxin/wet resistance; prepare and equip it before the first desert shift.
- DesertCloak: cactus weave + Forest cloth + Desert glass; upgrades heat resistance to 85%, with 12 armor and modest other protection.
- SwampWaders: marsh thread + BioGel + Forest resin waterproofing; excels against wetness/toxins.
- FrostParka: frost fur/cloth + Swamp-treated lining + Desert glass fasteners; excellent cold protection, poor heat protection.
- VolcanicPlate: obsidite + heat plate + insulated lining; best heat protection and physical defense, modest other coverage.
- CrystalWeave: crystal glass + quantum thread + marsh fiber; balanced protection and future energy-hazard specialization.
- AdaptiveSurvivalSuit: components from every biome, including Swamp filtration; broad protection but less specialized resistance than the strongest dedicated suit.

The cross-biome armor revisions above are implemented. AuroraMantle adds balanced heat/cold protection; StarforgedPlate combines meteor alloy, aurora lining, impact glass, and SwampWaders. Higher-tier tools and weapons similarly keep earlier biomes useful. Weather uses readable ambient variants and exposure; meteor-shower visuals currently accompany heat/dust exposure rather than independent impact attacks. Wetness amplifies cold. Fog must keep essential prompts and the HUD readable.

## Monster levels and escalating difficulty

Assign an immutable level when each monster spawns. Species determines behavior and baseline silhouette; level supplies health/damage multipliers. The level remains unchanged while that monster lives. A return to Forest late in the run can contain dangerous high-level wolves; it does not reset difficulty. Old monsters are removed on a shift as confirmed.

Provisional formula: health multiplier `1 + 0.16 × (level - 1)` and damage multiplier `1 + 0.10 × (level - 1)`. Keep speed and attack cadence primarily species-driven so leveling does not remove dodge windows. Show level beside the name and give elite status a separate marker. Party size primarily affects count and encounter composition, not hidden large damage jumps.

Monsters gain one level per 450 seconds (7.5 minutes), with the level fixed at spawn. Biome eligibility begins at 0/5/10/20/30/40/45/55 minutes for Verdant Reach/Sunscar Dunes/Mirefen/Frostfall/Cinder Rift/Prism Barrens/Aurora Vale/Starfall Crater. Eligibility is the earliest possible visit, not a guaranteed arrival. Later biome weights rise with elapsed time; an early-biome weight floor of 0.4 preserves revisits. Forecasts and selectors use the same eligibility rules, and advancing a shift cannot bypass a future biome's introduction gate.

The 60–90 minute target includes gathering, hunting, processing, and infrastructure after biome visits. Team preparation and random shifts affect actual completion time. This is a balance target, not a hard time lock on crafting or a maximum run length. Natural shifts remain fully weighted random as confirmed on September 7; do not add an unvisited-biome bias or guaranteed rotation. Unlucky runs may take substantially longer. See progression-balance.md for the natural-visit analysis.

## Proposed world-control equipment

The implementation uses authoritative server state for schedules, votes, ownership, and fuel. These values are the initial balance for the approved 60–90 minute progression.

| Equipment | Construction proposal | Effect and ongoing cost | Constraint |
| --- | --- | --- | --- |
| FieldClock | Workbench; TemperedGlass ×2, SanditeIngot ×1, ForestPlank ×2 | Unlocks the shift countdown for its owner; no vote or fuel for reading | Countdown stays hidden without an intel device; FieldClock alone does not reveal the next biome or weather |
| BiomePredictor / WeatherPredictor | BiomePredictor: AdvancedWorkbench; FieldClock ×1, IceLens ×2, BioGel ×2, SanditeIngot ×2. WeatherPredictor: later SurveyBench upgrade | BiomePredictor retains the countdown and reveals the next biome; WeatherPredictor retains both and adds weather on arrival | Forecast must be truthful; no reroll by reopening UI; upgrading never removes earlier information. Aurora can cycle after arrival |
| Shift Stabilizer | New ID; AdvancedWorkbench; SanditeIngot ×3, TemperedGlass ×2, BioGel ×2 | Majority-approved +60 seconds; consumes Coal ×2 and SapResin ×2 | Once per normal shift; never stack delays indefinitely; five-minute team cooldown |
| Shift Trigger | AdvancedWorkbench; SanditeIngot ×3, SunShard ×2, BioGel ×1, MagmaCore ×1 | Majority-approved early transition with a visible 15-second warning; consumes SunShard ×1 and Coal ×2 | At least 60 seconds spent in the current biome; five-minute team cooldown |
| Biome Selector | SurveyBench; PhaseCircuit ×2, CryoAlloy ×2, ObsiditeIngot ×2, SentinelCore ×1, AuroraLens ×1, MeteorAlloy ×2, MeteorCore ×1 | Majority-approved choice of next eligible biome; consumes ResonantCrystal ×2 and BioGel ×1 | One committed destination per shift, ten-minute team cooldown; choosing a biome does not also advance the timer |

Devices are reusable as confirmed; fuel is consumed only when an approved action successfully commits. Count a strict majority, `floor(eligible voters / 2) + 1`; single-player becomes one approval. Proposed ballot duration: 20 seconds, one ballot active at a time. Define eligible voters consistently, preferably connected run participants including spectating teammates; disconnections must never produce a duplicate execution. The proposer contributes fuel unless shared-storage payment is explicitly added. Revalidate item ownership, materials, chosen biome, and schedule version at commitment. Failed/rejected ballots consume no fuel.

Keep fuel costs cross-biome so holding a safe biome cannot sustain world control forever. The selector chooses an opportunity, not immunity: late-run monster levels and weather still matter.

## Prototype assets and presentation

Use the catalog visual pack as temporary meshes only: remove imported scripts, normalize scale, and supply gameplay attributes through code. Resource models need a clear identity, ground placement, collision policy, and the canonical DropItemId. Tools need a held grip and server-authoritative stats. Models must never silently decide loot, damage, or progression.

The field-kit UI should expose current danger and the next actionable craft, then reveal the countdown and forecasts as the corresponding devices are acquired. Use biome accents, clear material silhouettes, restrained motion, and consistent spacing. Craft feedback, damage alerts, votes, and shift warnings should animate with different priorities so important information stays readable.

## Later design work

The eight future biome concepts, differentiated monster attacks, station consolidation, live lobby/replay flow, and final Blender art remain separate future decisions. Fuel costs, resistances, and recipe quantities should be tuned from cooperative sessions without changing the confirmed run rules.

Balance proposals remain editable. Implement and play through one complete gathering → crafting → fight → rescue → shift loop before expanding enemy attack variety or final art.
