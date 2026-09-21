# EcoShift — complete gameplay overhaul, first draft

> Implementation override (2026-09-12): the user requested deleting all old worlds/player data and removing legacy compatibility. The overhaul is now the sole supported ruleset. Retain persistence for new overhaul worlds; earlier legacy-save requirements below are superseded.
**Revision:** 0.4 — September 12, 2026

**Status:** The user has approved implementation of the entire revision 0.4. The cooking-only checkpoint was an incomplete scope interpretation. Track full implementation and remaining integration in [the delivery ledger](overhaul-implementation-status.md). No tests or smoke tests are authorized; Roblox publishing remains with the user.

This is the consolidated first draft for the new campaign, equipment, resources, enchanting, encounters, events, and terrain. It supersedes earlier *proposals* in this conversation where they conflict. Existing game behavior is not evidence that a proposed feature already works.

**Reading key:** Section 1 records user-confirmed decisions. Everything else is a concrete **proposal for refinement**, including names, recipes, timings, formulas, and release details, unless explicitly identified as confirmed. Numbers are starting design values, not measured balance results. Sections 20–22 identify compatibility, delivery, and review work.

**Suggested first review:** campaign pacing (2), biome progression and terrain (3–5), gear choices (8–11), enchanting (14), and the open refinement points (22). Item recipes are deliberately explicit so we can change concrete costs instead of approving vague promises.

## Contents

1. [Confirmed decisions and retained rules](#1-confirmed-decisions-and-retained-rules)
2. [Campaign and power progression](#2-campaign-and-power-progression)
3. [Random biome selection and repeat visits](#3-random-biome-selection-and-repeat-visits)
4. [Terrain, streaming, shifts, and exploration](#4-terrain-streaming-shifts-and-exploration)
5. [All 16 biomes and 80 sub-biomes](#5-all-16-biomes-and-80-sub-biomes)
6. [Gathering and the resource catalog](#6-gathering-and-the-resource-catalog)
7. [Processing and crafting rules](#7-processing-and-crafting-rules)
8. [Weapons and combat](#8-weapons-and-combat)
9. [Tools](#9-tools)
10. [Armor and set bonuses](#10-armor-and-set-bonuses)
11. [Accessories and traversal](#11-accessories-and-traversal)
12. [Food, medicine, and environmental survival](#12-food-medicine-and-environmental-survival)
13. [Durability and repair](#13-durability-and-repair)
14. [Enchanting](#14-enchanting)
15. [Camp, stations, and structures](#15-camp-stations-and-structures)
16. [Intelligence and world controls](#16-intelligence-and-world-controls)
17. [Monsters, bosses, and expedition areas](#17-monsters-bosses-and-expedition-areas)
18. [Events and objectives](#18-events-and-objectives)
19. [Classes, rewards, and player experience](#19-classes-rewards-and-player-experience)
20. [Overhaul saves and technical integration](#20-overhaul-saves-and-technical-integration)
21. [Staged delivery and later acceptance scenarios](#21-staged-delivery-and-later-acceptance-scenarios)
22. [Refinement checklist](#22-refinement-checklist)

## 1. Confirmed decisions and retained rules

### Confirmed during this planning conversation

- Strongest equipment should take a prepared crew approximately **10–15 hours of active saved-world play** to reach. This is a pacing target, not a minimum timer.
- **Eight major equipment tiers**, with the standard weapon damage curve **18 / 36 / 72 / 144 / 288 / 576 / 1,152 / 2,304**. Final baseline weapon power is 128 times starter power.
- Progress requires **materials, milestones, and stations** together. Required milestones mix bosses and crew projects.
- Major difficulty increases follow milestones. Elapsed time adds bounded pressure within the current campaign tier.
- Design all **16 main biomes**, release them in stages, and make **all 16 eligible by campaign tier 4** when the expansion exists. Tiers 5–8 deepen those biomes rather than introducing more main biomes.
- Every biome has **at least five sub-biomes: 80 minimum**. Multiple eligible sub-biomes coexist in a visit.
- Every biome has **at least four ordinary creatures**, with sub-biome-specific species probabilities and group compositions; bosses/elites do not satisfy that minimum.
- Harder sub-biomes require **previous qualifying visits plus campaign progression**. Earlier regions remain eligible. Unlocking does not mean guaranteed generation.
- Natural and player-controlled visits qualify after **two active minutes**. History belongs to the world and persists through saving.
- Repeat visits gradually increase environmental severity; the first visit is gentle relative to that biome. Campaign progression limits escalation.
- **Fresh terrain layout on every visit**, with players placed on **nearby safe ground** at a shift.
- Separate expedition/boss interiors can persist while the surface changes.
- **Four armor pieces:** head, chest, legs, boots. Matching sets give bonuses.
- **Four accessory slots**, freely mixed; no duplicate item or upgrade-family stacking.
- Equipment has **repairable wear**. Zero durability disables equipment until repaired; it does not permanently destroy it.
- Combat includes **basic attack, dodge, weapon special**, and the existing separate class ability.
- Enchantment schematics are **discovered**, then players choose which enchantment to apply. Compatible enchantments transfer between items for a material cost. Stronger enchantments require stronger gear. Enchantments should have EcoShift-specific mechanics and **individual level caps**, rather than one uniform Minecraft-like upgrade ladder.
- Discoveries are shared by the **saved-world crew**, not permanently unlocked across every future world.
- Camp is a **functional expedition camp** with specialist stations and modest batch processing, not a conveyor/power-network factory game.
- Use clearer names: Iron Ore, Steel Bar, Frost Powder, Antidote, and similar readable names. Keep character in signature equipment without filling the catalog with invented technical terms.
- This overhaul applies to **new worlds**. Pre-overhaul worlds keep their existing rules. Worlds started under the new system can continue into the future-biome expansion without starting over.
- Cooking uses **Campfire, Stove, and Oven only**, with automatic queued preparation. Meals have **fixed ingredients and one optional seasoning choice**, not ingredient substitutions. Some biome seasonings provide magical stat boosts.
- Finish and refine this document before final implementation.

### Previously approved rules retained

- Cooperative 1–6-player expeditions; matchmaking is optional and merges parties. Class diversity is a preference, never a requirement. Existing leaders are randomly selected after merging; the leader starts the expedition after everyone readies.
- Natural shifts last a randomly chosen **300–500 active seconds**, inclusive. Selection remains weighted random: no guaranteed rotation or hidden unvisited-biome bias.
- The shift countdown requires a Field Clock; forecasts require additional equipment.
- Reusable world controls consume fuel, require majority votes, and have cooldowns/limits. Timing controls target 1–2 hours, limited destination selection 4–6 hours, strongest controls 10–15 hours.
- The camp has a **200-stud radius / 400-stud diameter**. Permanent player construction stays inside it. Generated resources, structures, chests, and fresh monsters stay outside. Existing monsters can approach it.
- Builds and storage survive shifts. Old surface monsters are removed. Camp geometry is not made destructible by this overhaul; temporary Builder deployments retain their special damage rules.
- Death leaves a revivable body and permits spectating. Revival restores **30 HP, 50 hunger, 50 energy, and zero exposure**. A full-team wipe ends a survival world and removes its save copies. Solo has the same wipe rule.
- Five personal save slots; shared world progress, personally named copies, original full crew required to resume, and existing rejoin/party behavior remain.
- Creative is a separate world type, permanently ineligible for progression rewards even while an individual switches to survival behavior.
- The existing 12 permanent classes, level 1–5 purchases, class-time requirements, and abilities remain the account progression system.
- PC/mobile support is mandatory. Preserve E inventory, F interact, Control shift lock, Shift sprint, quantity crafting, crafting progress, recursive recipe navigation, and the established inventory interactions.
- Base movement is **20 studs/s walking and 30 studs/s sprinting**. Ground movement inside camp is **2×**, giving **40 walking / 60 sprinting** before class and equipment modifiers. Opening menus does not cancel sprint intent; toggle sprint resumes at 20% stamina after exhaustion.
- Buildable held items use placement mode. Hold-to-salvage takes several seconds with visible feedback. No separate build menu.
- Art remains stylized low-poly expedition: angular forms, painted colors, subtle biome glow. UI remains warm paper, moss green, amber instruments. Final Blender assets are separate later work.
- Do not create/run tests or smoke tests without a new request. Use Rojo for eventual source delivery; leave Roblox publishing to the user.

## 2. Campaign and power progression

The table describes objectives for a moderately experienced crew, not time locks. Random biome availability, gathering choices, deaths, and crew size affect actual pacing. Solo uses the same unlocks with smaller encounter/project requirements.

| Tier | Approximate cumulative play | Standard damage D | Ordinary enemy HP before pressure | Full-set physical reduction | Main capability | Milestone to advance |
| --- | --- | ---: | ---: | ---: | --- | --- |
| 1 — Field | 0–45 min | 18 | 72 | 8% | Camp, stone equipment, first-hazard preparation | Restore the Field Relay |
| 2 — Steel | 45–120 min | 36 | 144 | 18% | Steel, cold/toxin protection, shift timing | Defeat the Bog King |
| 3 — Forge | 2–3.5 h | 72 | 288 | 30% | Fire protection, enchanting, precision assembly | Restore the Old Forge |
| 4 — Meteor | 3.5–5 h | 144 | 576 | 42% | All main biomes eligible; meteor gear; limited destination choice | Defeat the Fallen Star |
| 5 — Storm | 5–7 h | 288 | 1,152 | 54% | Stronger regional gear; storm and coastal expeditions | Restore the Weather Tower |
| 6 — Reinforced | 7–9 h | 576 | 2,304 | 64% | Fourth sub-biomes, advanced medicine and repair | Defeat the Ironback |
| 7 — Deep | 9–12 h | 1,152 | 4,608 | 73% | Deep exploration, upgraded traversal and equipment | Restore the Deep Archive |
| 8 — Moon | 12–15 h | 2,304 | 9,216 | 80% | Fifth sub-biomes, final materials, strongest world controls | Defeat the Moon Warden; continue endless survival |

- Tier upgrades are world-wide station certifications earned through milestones, not personal class levels. Using/gifting a valid item does not require the recipient to replay the unlock.
- A matching-tier ordinary enemy takes roughly four unmodified standard hits. A tier-4 enemy takes 32 starter-spear hits; a tier-8 enemy takes 512. No artificial damage immunity is needed to make starter weapons impractical.
- Monster health scales much more strongly than attack speed or movement. Preserve readable windups and escape windows.
- Proposed standard enemy contact damage by tier: **8 / 12 / 18 / 27 / 41 / 62 / 93 / 140** before armor and class reduction. Player base HP remains 100, preserving the usefulness of existing fixed-value class heals.
- Ordinary enemy health is 4D; light enemies use 2.5D, heavy enemies 8D, elites 16D. Species modifiers and boss scaling are specified in section 17.
- Higher-tier gear should strongly outperform old equipment without requiring enchantments. Enchantments specialize and improve it; they are not required to make its basic damage functional.
- Pressure within a tier rises from 0 to 1 across 90 active minutes, then stops. It adds up to 25% ordinary enemy HP and 15% damage; encounter density rises by at most 25%. Completing the next milestone starts the next tier at low pressure, with a two-minute transition warning before new-strength spawns.
- Required milestone fights use the current tier. They never demand equipment that only their completion unlocks.
- After the final boss, optional endurance cycles increase HP by 10% and damage by 5% per active hour. This is explicitly post-campaign escalation, not pressure that can trap a tier-2 crew.

## 3. Random biome selection and repeat visits

### Main-biome eligibility

Naming revision: use grounded, recognizable display names instead of the earlier fantasy-style names. The names below are the replacement draft roster; existing internal biome identifiers remain stable when implementing display-name changes.

| Earliest campaign tier | Newly eligible main biomes |
| --- | --- |
| 1 | Woodlands; Dunes |
| 2 | Marsh; Tundra; Coast; Rainforest |
| 3 | Volcanic Plains; Crystal Basin; Mushroom Forest; Badlands |
| 4 | Northern Valley; Meteor Crater; Highlands; Flooded Ruins; Caverns; Moon Surface |

The world starts in Woodlands. All 16 become eligible by tier 4 in the complete release. Future biomes remain absent from actual generation until their content release is enabled.

- Choose randomly from the implemented, campaign-eligible pool, excluding the current main biome when another option exists.
- Proposal: weight 2 for biomes introduced at the most recently unlocked main-biome tier, 1 for earlier biomes. Once tier 4 has been active for one hour, all main-biome weights become 1. Harder regional content supplies subsequent escalation.
- Do not adjust weights using missing materials, visits, or undiscovered regions. Devices are the deliberate way to influence the destination.
- Each natural surface visit samples a duration uniformly from integer **300 through 500 seconds**, inclusive, once when its schedule is created. Save that chosen duration and remaining active time; reconnects, forecasts, and generation retries never reroll it. Generation/loading, all-offline pauses, and restore time are excluded from active timers. The mean is 400 seconds (6 minutes 40 seconds), so progression pacing must account for fewer natural visits per hour.
- Count a visit once after 120 active seconds of a committed surface generation with at least one living surface player participating. Time may accumulate during the visit; being in menus without activity does not qualify participation. Different crew members do not multiply the visit count.
- Controlled arrivals qualify by the same rule. Delaying a visit cannot earn multiple credits. Loading, reconnecting, weather changes, and regeneration retries never create an extra visit.
- Use completed credits from *earlier* visits to select the current region pool and environmental maturity. Earning this visit's credit changes eligibility only on a later arrival.

### Regional depth

| Depth | Minimum previous visit credits | Minimum campaign tier | Role |
| --- | ---: | --- | --- |
| A and B | 0 | Main biome's unlock tier | Two introductory regions with different terrain and common supplies |
| C | 1 | 4 | Specialist resources, discoveries, and expedition entrances |
| D | 2 | 6 | Advanced materials and encounters |
| E | 3 | 8 | Final materials, elite sites, and strongest discoveries |

- Generate 6–9 coherent region footprints per surface layout. Always retain an accessible introductory region outside camp. Fill the remaining footprints by weighted random selection among eligible types; repeats of a type are allowed.
- Proposal weights A/B/C/D/E: **3/3/2/1.5/1**. The guaranteed introductory foothold is an access rule, not a guarantee of a rare region. Locked regions and their rewards do not generate.
- Each region type has multiple terrain/landmark arrangements; a first visit containing only A/B still has geographic variety.
- Native high-level biomes have accessible outer regions by tier 4. Their names do not imply that final-tier materials or lethal conditions are immediately present.
- Region danger has a floor: A/B follows campaign tier; C at least tier 4, D at least tier 6, E tier 8. Previously spawned monsters retain their strength until removed; changing region does not level an existing monster up/down.

## 4. Terrain, streaming, shifts, and exploration

### Landform generation

Keep the current approximately 1,500-stud surface radius for the first overhaul. Improve its depth and routes before increasing travel distance.

1. Choose the eligible region pool and a visit seed derived from world seed, main biome, and committed visit serial.
2. Reserve the permanent camp, its foundations, a blending collar, and valid entrance/exit connections.
3. Generate main landforms appropriate to the biome: ridges, basins, coasts, canyon networks, craters, or terraces. Use coherent elevation fields and deliberate geological features, not independent random bumps.
4. Fit region footprints into those landforms; connect introductory regions and milestone approaches with traversable routes.
5. Place rivers along descending routes, lakes in basins, caves within sufficient ground volume, and waterfalls between supported elevations.
6. Reserve and shape landmark foundations, entrances, bridges, and clear approaches.
7. Place resources, creatures, and props using biome/region metadata, ground height, slope, water depth, support, and clearance.

Proposed elevation envelope outside camp: approximately -120 to +240 studs. Peaks can use distant visual extensions without requiring every visible summit to be playable. Ordinary routes target slopes below 30 degrees; traversal routes may be steeper but must advertise the necessary equipment. No forced precision parkour on the basic progression path.

### Grounding and performance requirements

- Replace both the flat base generation and the flat material-painting pass. Updating only one would flatten or overwrite the other.
- Plan major geography from the full visit seed, then materialize nearby chunks. Neighboring chunks sample the same landform functions and boundary data.
- Validate a structure's support across its footprint, not just its pivot. Allow small foundation grading; reject placements that would bury doors or leave foundations suspended.
- Put resource roots at the measured surface. Ground loot safely; do not let drops inherit underground pivots or fall through still-loading terrain.
- Use native terrain for bulk ground/water and modular low-poly geometry for overhangs, roots, buildings, bridges, and cave detail.
- Bound work per frame and prioritize occupied areas. Mobile lowers decorative foliage, particles, and distant detail, never collision or resource availability.
- Maintain coarse, deterministic world metadata for map/scanner queries without instantiating distant resources or enemies.
- Every region gets a terrain silhouette, material palette, vegetation family, ambient sound, landmark language, and weather treatment. Heavy fog must not hide nearby attacks, interactables, or safe footing.

### Stable camp and safe shifts

- Preserve the camp's 200-stud-radius ground and all permanent builds/storage. Blend new geography into it over a proposed 40-stud outer collar. Water and terrain must not intrude through its floor.
- Camp is a stable foundation, not automatic immunity to weather or approaching monsters.
- During a shift, safely suspend surface movement/damage while occupied destination chunks become ready. Preserve approximate X/Z and nearby team grouping.
- Select nearby supported, walkable ground, rejecting water, hazards, locked regions, inaccessible ledges, occupied footprints, and immediate enemy overlap. Expand the search before falling back to camp.
- Relocate downed bodies with their revival targets. Cancel an interrupted revive cleanly without consuming its kit.
- Begin the new active timer only after the replacement is committed and occupants are placed safely. Generation retries must not reroll visit rewards or counters.
- Surface regeneration must not call a global clear that destroys occupied dungeon geometry or the camp.

### Map and discovery

- Each fresh layout starts a fresh shared surface exploration layer. Persist biome/region discoveries, schematics, visit history, and expedition records separately.
- Show discovered sub-biome names, landmarks, entrances, hazards, and team markers. Terrain shading distinguishes cliffs, water, and traversable routes.
- Use separate surface/cave/interior layers where vertical overlap makes a flat map misleading. Mark entrances linking layers.
- Preserve portrait rotation, downed red tint, minimap-to-map interaction, and input isolation from legends/menus.

## 5. All 16 biomes and 80 sub-biomes

Each row below defines a distinct terrain/activity region. A/B/C/D/E refer to section 3 eligibility, not separate main-biome rolls. Drops reference section 6; generic rewards mean food, repair supplies, or enchanting discoveries of the permitted tier, not arbitrary final-tier equipment.

### Woodlands — meadows, old trees, and sheltered roots

| Depth / region | Geography and activity | Resource/reward focus |
| --- | --- | --- |
| A Open Meadows | Rolling grassland, streams, open sight lines; learn gathering and establish a route home | Wood, stone, fiber, mushrooms, water |
| B Birch Woods | White-trunk stands, fallen-log routes, small clearings | Resin, herbs, wolves and warm fur |
| C Old Forest | Dense broad trunks, abandoned ranger platforms | Deep Resin; wood/medicine schematics |
| D Root Caves | Root-supported chambers and underground streams | Enchanting crystals, supply rooms, difficult ambushes |
| E Giant Tree Grove | Enormous trees, root bridges, hollow-trunk arenas | Ancient Seed elite reward; strongest growth discoveries |

### Dunes — dunes, red stone, and buried settlements

| Depth / region | Geography and activity | Resource/reward focus |
| --- | --- | --- |
| A Sandy Flats | Low dunes, scattered rock shelves, readable paths | Sand, coal, shallow iron seams |
| B Cactus Valley | Sheltered channels, cactus groves, small water pockets | Cactus, iron; first heat supplies |
| C Red Canyons | Winding red walls, natural bridges, exposed ledges | Sunstone, rich ore, scorpion encounters |
| D Buried City | Roofs emerging from sand; accessible underground streets | Enchanting discoveries and recovered machine parts |
| E Glass Dunes | Fused-glass ridges, hot vents, dangerous reflections | Sun Heart elite reward; advanced heat effects |

### Marsh — water, roots, and medicinal growth

| Depth / region | Geography and activity | Resource/reward focus |
| --- | --- | --- |
| A Reed Marsh | Shallow water with connected raised banks | Reeds, herbs, safe wetness introduction |
| B Willow Pools | Tree-root islands and slow streams | Peat, glowcaps, leech venom |
| C Mushroom Bog | Large mushrooms, drifting spores, clear dry routes | Bog King entrance, antidote/enchanting discoveries |
| D Sunken Village | Flooded houses and narrow raised walkways | Advanced supplies, venom specialists |
| E Blackwater Basin | Dark pools divided by root islands | Marsh Heart elite reward; strongest toxin discoveries |

**Early milestone exception:** the Bog King's introductory entrance can spawn in B at tier 2. C later adds an enhanced optional version. The campaign cannot require C before tier 4.

### Tundra — forests, ice, and exposed heights

| Depth / region | Geography and activity | Resource/reward focus |
| --- | --- | --- |
| A Snowfields | Gentle slopes, sparse snow, visible shelter | Common supplies, basic cold introduction |
| B Frozen Woods | Snow-covered pines, windbreaks, shallow ice caves | Warm fur, ice crystals |
| C Frozen Lake | Broad ice with visible cracks and safe shore routes | Frost Bloom, ice discoveries |
| D Ice Caves | Translucent chambers, hanging ice, narrow passes | Concentrated crystals, frost enchantments |
| E Whiteout Peaks | Wind-exposed ridges and summit shelters | Frost Heart elite reward |

### Volcanic Plains — ash, black rock, and active lava

| Depth / region | Geography and activity | Resource/reward focus |
| --- | --- | --- |
| A Ash Plains | Rolling ash beds with safe exposed stone | Ash Fiber, coal |
| B Black Rock Fields | Basalt shelves, cooled flows, sheltered gullies | Black Glass, sulfur; Old Forge approach |
| C Lava Channels | Slow visible lava channels with solid crossings | Heat schematics and richer black glass |
| D Furnace Ruins | Stone foundries integrated into cliffs | Fire Core, forge/enchanting discoveries |
| E Volcano Heart | Caldera walls and a controlled central arena | Greater Fire Core elite reward |

### Crystal Basin — angular crystals and fractured stone

| Depth / region | Geography and activity | Resource/reward focus |
| --- | --- | --- |
| A Crystal Fields | Low crystal fans and open stony ground | Clear Crystal |
| B Broken Stone Flats | Split shelves, shallow ravines, obvious crossings | Crystal Thread, common minerals |
| C Mirror Canyon | Reflective walls and branching routes | Dark Dust, beam-routing discoveries |
| D Crystal Caves | Large crystal chambers with resonating hazards | Advanced enchantments and crystal caches |
| E Shattered Spire | Broken vertical tower with stable approach routes | Crystal Heart elite reward |

### Northern Valley — warm springs beneath cold skies

| Depth / region | Geography and activity | Resource/reward focus |
| --- | --- | --- |
| A Frosted Meadows | Light frost, colored sky, broad paths | Glow Fiber |
| B Dawn Woods | Glowing foliage and sheltered sunrise clearings | Dawn Flower |
| C Hot Spring Valley | Warm pools separated by cold rock terraces | Aurora Stone; thermal-management discoveries |
| D Northern Cliffs | High paths, warming shelters, strong wind | Advanced cloth/enchantment caches |
| E Aurora Ridge | Aurora-lit summit and exposed arena | Dawn Heart elite reward |

### Meteor Crater — impact bowls and fallen metal

| Depth / region | Geography and activity | Resource/reward focus |
| --- | --- | --- |
| A Dust Plains | Low dust ridges and scattered impact debris | Impact Glass |
| B Fallen Rock Fields | Large embedded meteor fragments and sheltered gaps | Meteor Ore |
| C Crater Lakes | Nested crater basins, flooded rims, ruined instruments | Star Core; Fallen Star entrance |
| D Meteor Tunnels | Passages through shattered impact rock | Advanced metal/enchantment deposits |
| E Impact Core | Central impact chamber with falling-debris warnings | Greater Star Core elite reward |

### Coast — beaches, tide pools, and wrecks

| Depth / region | Geography and activity | Resource/reward focus |
| --- | --- | --- |
| A Shell Beach | Curved shore, dunes, driftwood | Shell Plate, salt |
| B Tide Pools | Shallow pools, rock steps, kelp beds | Kelp, coastal food |
| C Sea Cliffs | Sea-facing paths, arches, sheltered coves | Waterproofing and traversal discoveries |
| D Shipwreck Cove | Grounded ships, cargo holds, short diving routes | Pearl, recovered parts |
| E Storm Reef | Exposed reef islands with readable wave lanes | Tide Heart elite reward |

### Highlands — grassy heights and charged stone

| Depth / region | Geography and activity | Resource/reward focus |
| --- | --- | --- |
| A Windy Hills | Rounded hills and stone windbreaks | Cloud Wool |
| B Cloud Meadows | Elevated plateaus with safe connecting passes | Storm Ore |
| C Thunder Pass | Sheltered gorge and charged outcrops | Weather Tower entrance and storm discoveries |
| D Lightning Fields | Telegraph-marked strike zones among grounding rocks | Storm Core |
| E Storm Summit | Tall central peak and sheltered approach | Greater Storm Core elite reward |

### Mushroom Forest — giant mushrooms and living roots

| Depth / region | Geography and activity | Resource/reward focus |
| --- | --- | --- |
| A Mushroom Fields | Low caps, soft hills, edible patches | Glow Mushroom |
| B Moss Woods | Moss-coated trunks and damp hollows | Thick Spores, herbs |
| C Giant Cap Forest | Enormous caps and root-lined paths | Living Root |
| D Spore Caves | Ventilated chambers with visible spore pulses | Advanced medicine/enchantment supplies |
| E Root Chamber | Huge living root chamber | Growth Heart elite reward |

### Badlands — red rock and armored wildlife

| Depth / region | Geography and activity | Resource/reward focus |
| --- | --- | --- |
| A Red Flats | Cracked clay terraces and gullies | Ironwood stands |
| B Thorn Scrub | Tough low vegetation and stone shelter | Red Ore, Tough Hide |
| C Ironwood Forest | Dense heavy trunks and narrow sight lines | Rich Ironwood and strength discoveries |
| D Abandoned Mines | Mine tracks and supported underground chambers | Ironback entrance; advanced ore deposits |
| E Rust Fortress | Layered ruined fortification and courtyard arena | Iron Heart elite reward |

### Rainforest — a forest with several playable heights

| Depth / region | Geography and activity | Resource/reward focus |
| --- | --- | --- |
| A Forest Floor | Large trunks, clear floor routes, fallen branches | Common wood and fiber |
| B Low Canopy | Gradual root ramps and low platforms | Strong Silk |
| C Hanging Gardens | Suspended vegetation and optional glide routes | Lift Seed |
| D Broken Bridges | Connected branch platforms and repairable crossings | Heartwood |
| E Crown Canopy | High crowns above the cloud line | Sky Heart elite reward |

### Flooded Ruins — a drowned research settlement

| Depth / region | Geography and activity | Resource/reward focus |
| --- | --- | --- |
| A Flooded Courtyard | Raised walkways around shallow flooded plazas | Old Gear |
| B Canal District | Canals, bridges, dry maintenance rooms | Pressure Glass |
| C Drowned Library | Submerged shelves and frequent air pockets | Survey/enchantment schematics |
| D Sealed Vaults | Pressure doors and bounded diving chambers | Pearl; Deep Archive project entrance |
| E Deep Archive | Large underwater vault with permanent interior air rooms | Archive Heart elite reward |

### Caverns — cavern landscapes beneath a dark roof

| Depth / region | Geography and activity | Resource/reward focus |
| --- | --- | --- |
| A Cave Mouths | Large open entrances with natural light shafts | Dark Moss |
| B Glowmoss Caverns | Broad lit chambers and clear routes | Light Ore |
| C Echo Tunnels | Branching passages and sound-sensitive encounters | Echo Shell |
| D Underground Lake | Shore routes, boats as scenery, optional dive pockets | Advanced light/enchantment caches |
| E Lightless Chasm | Deep ledges, persistent darkness, sheltered platforms | Night Heart elite reward |

### Moon Surface — lunar ground and broken gravity

| Depth / region | Geography and activity | Resource/reward focus |
| --- | --- | --- |
| A Moon Flats | Broad low craters and stable gravity | Moon Rock |
| B Silver Ridges | Low silvery ridges and sheltered cracks | Moon Thread |
| C Floating Stone Fields | Clearly bounded low-gravity pockets; ordinary bypasses | Gravity/traversal discoveries |
| D Broken Observatory | Damaged instruments and supported crater tunnels | Moon Ore |
| E Gravity Well | Floating rocks surrounding a stable arena | Gravity Shard; Moon Warden entrance |

Introductory moon regions do not impose vacuum/mandatory breathing equipment. Late pressure hazards occupy marked interior/region areas with preparation available beforehand. Earlier biomes remain valuable through deep-region rewards and cross-biome recipes.

## 6. Gathering and the resource catalog

### Gathering rules

- Trees, cactus, ores, coal, sandstone, crystal deposits, and large mineral fragments require breaking. Flowers, herbs, mushrooms, reeds, kelp, loose fibers, and water use F/touch gathering.
- Ordinary plants take 1.5 seconds, dense reeds/kelp 2 seconds, valuable flowers 2.5 seconds, water filling 1 second. Class reductions and tools apply within the approved 50% duration-reduction cap.
- A small starter tree takes 8 Harvester hits; a large starter tree 14. Tier-appropriate axes take approximately 4 and 7 hits. Ordinary matching-tool mineral nodes take 5 hits.
- Matching-tier raw nodes target roughly 3–6 seconds of work. Each tool tier doubles base breaking power, so old nodes become much faster. Advanced nodes require at least the preceding tool tier; unlocking a material never requires a tool made from that same inaccessible material.
- Node health is tied to its material/region grade, not global monster level. Old wood does not become harder simply because the campaign progressed.
- Common nodes yield 4–8 primary units; specialty nodes 2–4; deep deposits 1–3. Roll bonus harvest once per node, not once per hit/drop stack.
- Cactus deals 4 contact damage at most once per second while actually touching it. Gathering range does not itself cause cactus damage.
- No line-of-sight requirement on ordinary collection/chest prompts; short interaction ranges remain. Weapon and targeted ability visibility checks are separate.

### Common resources

| Item | Source | Purpose |
| --- | --- | --- |
| Wood | Break ordinary trees; also driftwood | Planks, handles, fuel, structures |
| Stone | Break ordinary rocks or sandstone; sandstone also yields Sand | Starter tools, foundations, stations |
| Fiber | Gather reeds/loose plant fibers | Cloth, cord, first protection |
| Resin | Primary/secondary tree drops, visible resin patches | Binding, waterproofing, medicine, fuels |
| Healing Herb | Gather green medicinal plants | Bandages, medicine, preparation supplies |
| Mushroom | Gather edible brown mushrooms | Starter food, cooking |
| Water | Fill at safe springs or prepared collection stations | Drinking, cooking, recovery, brewing |
| Dirty Water | Fill from explicitly labeled unsafe pools | Filter at camp; not a direct substitute for safe recipe water |
| Coal | Break common coal seams | Longer-burning fuel, steel processing |
| Raw Meat | Hunt ordinary fauna/appropriate monsters | Cooking; not edible raw |
| Bone | Hunt animals/appropriate monsters | Backup spear, traps, crafting |
| Warm Fur | Wolves and cold-region animals | Early cold preparation and warm cloth |

Cooking adds **Berries** from bushes in Woodlands A/B, Marsh A, and Rainforest A, and **Root Vegetable** from visible leafy roots in Woodlands A/B, Marsh A/B, and Badlands A. Both are hand-gathered plants, eligible for the ordinary plant rules; neither needs a new processing material. Edible spice plants and their biome/depth sources are listed in section 12 and extend this resource catalog.

Common supplies have suitable sources across multiple biomes. A late crew should not need a Forest roll merely to obtain ordinary wood, stone, or water. Water source labels distinguish safe collection from hazardous pools.

### Signature resources — crafting roster

| Biome | Resources and source depths | Concrete uses |
| --- | --- | --- |
| Woodlands | Deep Resin C | Storm Bar binding, advanced repair, growth enchanting |
| Dunes | Iron Ore A/B; Sand A; Cactus B; Sunstone C | Iron/steel, glass, cooling food/cloth, solar instruments |
| Marsh | Reeds A; Peat B; Glowcap B; Venom Gland from leeches/toads | Warm cloth, fuel, medicine, antidote and poison effects |
| Tundra | Ice Crystal B; Frost Bloom C; common Warm Fur | Meteor cooling, cold weapons, warming medicine |
| Volcanic Plains | Black Glass B; Ash Fiber A; Sulfur B; Fire Core D | Blacksteel, fire cloth, fuel, fire specials/enchantments |
| Crystal Basin | Clear Crystal A; Crystal Thread B; Dark Dust C | Optics, weapon bindings, enchantment dust, dark effects |
| Northern Valley | Glow Fiber A; Dawn Flower B; Aurora Stone C | Glow cloth, balanced thermal medicine, prediction optics |
| Meteor Crater | Impact Glass A; Meteor Ore B; Star Core C | Armor, meteor bars, biome-control instruments |
| Coast | Shell Plate A; Salt A; Kelp B; Pearl D | Coastal protection, preservation, storm cloth, deep equipment |
| Highlands | Cloud Wool A; Storm Ore B; Storm Core D | Storm cloth/bars, charged weapon effects and weather control |
| Mushroom Forest | Glow Mushroom A; Thick Spores B; Living Root C | Food, medicine, reinforced bars, advanced repair |
| Badlands | Ironwood A/C; Red Ore B; Tough Hide from regional beasts | Strong handles/storage, reinforced bars, tough cloth |
| Rainforest | Strong Silk B; Lift Seed C; Heartwood D | Bowstrings, sail cloth, gliders, deep-tier handles |
| Flooded Ruins | Old Gear A; Pressure Glass B; Pearl D | Recovered gears, diving gear, sail cloth, deep metal |
| Caverns | Dark Moss A; Light Ore B; Echo Shell C | Night cloth, deep metal, lighting and sound tools |
| Moon Surface | Moon Rock A; Moon Thread B; Moon Ore D; Gravity Shard E | Weighting/traversal, night cloth, final bars, gravity equipment |

### Deep-region trophies

Every E region's elite site awards its named trophy from section 5 once per completed site: Ancient Seed, Sun Heart, Marsh Heart, Frost Heart, Greater Fire Core, Crystal Heart, Dawn Heart, Greater Star Core, Tide Heart, Greater Storm Core, Growth Heart, Iron Heart, Sky Heart, Archive Heart, Night Heart, or Gravity Shard.

They are ingredients for that biome's final armor set trait and the grade-8 ranks of selected signature enchantments. They are not 16 interchangeable mandatory steps: ordinary final equipment requires the relevant branch's trophy, not all trophies. World Anchor uses four different trophies, chosen by the crew. This keeps random visits meaningful without making every final recipe require a complete 16-biome collection.

## 7. Processing and crafting rules

All recipes below are proposals. The new catalog uses a small set of shared processed materials. Avoid separate functionally identical wood/stone/fiber items for every region.

### Processing catalog

| Output | Inputs per batch | Output count | Station |
| --- | --- | ---: | --- |
| Plank | Wood ×2 | 4 | Workbench |
| Cloth | Fiber ×3 | 2 | Hand or Loom |
| Cord | Fiber ×2 | 2 | Hand or Loom |
| Iron Bar | Iron Ore ×3 | 2 | Furnace; fuel separate |
| Glass | Sand ×3 | 2 | Furnace; fuel separate |
| Herbal Paste | Healing Herb ×2 + Mushroom ×1 | 2 | Hand or Medicine Table |
| Plant Oil | Glow Mushroom ×2 + Resin ×1 | 2 | Medicine Table |
| Gears | Steel Bar ×2 + Resin ×1, OR Old Gear ×1 | 2 | Anvil; recovered alternative at Workbench |
| Enchanting Dust | Clear Crystal ×2 + Dark Dust ×1 | 4 | Enchanting Table |
| Steel Bar — M2 | Iron Bar ×2 + Coal ×1 | 2 | Furnace |
| Blacksteel Bar — M3 | Steel Bar ×2 + Black Glass ×2 + Clear Crystal ×1 | 2 | Furnace grade 3 |
| Meteor Bar — M4 | Blacksteel Bar ×2 + Meteor Ore ×3 + Ice Crystal ×1 | 2 | Furnace grade 4 |
| Storm Bar — M5 | Meteor Bar ×2 + Storm Ore ×3 + Deep Resin ×1 | 2 | Furnace grade 5 |
| Reinforced Bar — M6 | Storm Bar ×2 + Red Ore ×3 + Living Root ×1 | 2 | Furnace grade 6 |
| Deep Metal — M7 | Reinforced Bar ×2 + Light Ore ×3 + Pearl ×1 | 2 | Furnace grade 7 |
| Moon Bar — M8 | Deep Metal ×8 + Moon Ore ×12 + Gravity Shard ×1 | 8 | Furnace grade 8; larger batch spreads the rare catalyst cost |
| Warm Cloth — C2 | Cloth ×2 + Reeds ×2 + Warm Fur ×2 | 2 | Loom grade 2 |
| Fire Cloth — C3 | Warm Cloth ×2 + Ash Fiber ×3 + Resin ×1 | 2 | Loom grade 3 |
| Glow Cloth — C4 | Fire Cloth ×2 + Glow Fiber ×3 + Clear Crystal ×1 | 2 | Loom grade 4 |
| Storm Cloth — C5 | Glow Cloth ×2 + Cloud Wool ×3 + Kelp ×1 | 2 | Loom grade 5 |
| Tough Cloth — C6 | Storm Cloth ×2 + Tough Hide ×3 + Plant Oil ×1 | 2 | Loom grade 6 |
| Sail Cloth — C7 | Tough Cloth ×2 + Strong Silk ×3 + Pressure Glass ×1 | 2 | Loom grade 7 |
| Night Cloth — C8 | Sail Cloth ×2 + Moon Thread ×3 + Dark Moss ×1 | 2 | Loom grade 8 |

For recipe shorthand, **M1 = Stone**, **C1 = Cloth**. Handle material H is Wood at tiers 1–4, Ironwood at 5–6, Heartwood at 7–8. Cloth/metal grades are recipe capability gates, not 16 extra placeable station items.

### Recipe behavior

- A station can be constructed/upgraded with the previous grade's materials after its milestone; its own newly unlocked products are never required for that upgrade.
- Basic hand recipes appear at Workbench and its upgrades, not at unrelated stations such as Loom.
- All recipes show output quantity, station/grade, milestone, input sources, and total time. Ingredients and missing stations open recursive recipe/source pages with Back.
- Empty categories stay hidden. Starting/completing a craft preserves category, selected recipe, quantity, and scroll position.
- Default craft work: hand items 3–8 seconds, processing batches 6 seconds, weapons/tools 12 seconds, armor pieces 15 seconds, stations/devices 20 seconds. Quantity scales total work linearly.
- Player-bound crafts retain the approved cancel-and-refund-on-disconnect behavior. Work-rate bonuses operate on accumulated work; no output duplication or ingredient discounts from faster crafting.
- Optional batch machines use their own escrowed input/output inventories and saved work, rather than pretending a departed player is still crafting. They do not progress while the world is offline.
- Builder discounts apply only to structural-item raw costs, round upward, and record actual payment for salvage; other crafting recipes are undiscounted.
- Permanent recipes are learned by the shared world. Baseline recipes are visible from the start; advanced recipes disclose their discovery/milestone requirement and known source, rather than hiding how progression works.

## 8. Weapons and combat

### Common combat rules

| Location | Base walk speed | Base sprint speed |
| --- | ---: | ---: |
| Outside camp | 20 studs/s | 30 studs/s |
| Inside the 200-stud camp radius | 40 studs/s | 60 studs/s |

The camp multiplier is based on horizontal distance from the camp center and applies once to walking/sprinting. Apply existing class/equipment movement modifiers afterward; entering, leaving, respawning, or restoring must recalculate rather than repeatedly multiply the current speed. Sprint still uses its normal stamina drain per second. Jump height, dodge distance, gliding, and monster movement use their own rules.

- Keep server-authoritative attacks, stamina, targeting, cooldowns, and damage. Client animations and feedback begin immediately but do not grant damage authority.
- PC: left click basic attack; right click weapon special when a weapon is held. Holding a buildable keeps right-click placement instead. Mobile: tap unobstructed gameplay space for basic attack, plus a special icon. Gamepad: right trigger attack, left trigger special. Existing custom bindings take priority.
- Dodge: Space while moving on keyboard would conflict with jumping, so use **Q** for dodge outside inventory; Q retains its hover-item drop meaning inside inventory. Gamepad B; mobile dodge icon. Allow rebinding.
- Proposed dodge: 25 stamina, 2-second cooldown, 9-stud travel over 0.4 seconds, 0.18-second invulnerability window. Collision limits the movement; it cannot pass through walls or locked boundaries. It does not add upward launch height.
- Weapon specials cost 20 stamina with an 8-second cooldown unless their archetype below says otherwise. No valid cast/target means no resource cost. Class ability remains a separate action/cooldown.
- Menus block attacks, dodges, and specials without clearing sprint intent. Movement/camera touches and touches consumed by UI are not attacks.
- Use server swept volumes between attack poses, bounded reach, and target visibility. Mobile gets roughly 15% wider target tolerance and at most 0.75 extra studs of reach, not a huge spherical hitbox. Multi-hit animation frames cannot repeatedly damage the same target in one swing.
- Basic melee attacks cost no stamina. Sprint, dodging, specials, and certain traversal share stamina, creating meaningful movement choices.
- Monster names, levels, and exact current/max HP remain visible within 30 studs. Show ordinary hit confirmation and distinct critical/status feedback without excessive floating text.

### Weapon families

Damage uses the tier's standard D from section 2. Specials list total damage, including any damage-over-time component; passive/enchantment rules apply once.

| Family | Basic hit / cycle | Base reach | Special |
| --- | --- | --- | --- |
| Spear | D / 1 second | 9 studs | Lunge: 1.5D along a short thrust; modest forward movement, collision checked |
| Sword | 0.85D / 0.85 seconds | 8 studs | Sweep: 1.1D to up to three nearby targets |
| Dagger | 0.55D / 0.55 seconds | 6.5 studs | Quick Cut: 1.5D to one target and a 20% slow for 3 seconds |
| Axe | 1.2D / 1.2 seconds | 8 studs | Heavy Cleave: 1.6D to up to two targets; 0.5-second stagger on ordinary enemies |
| Hammer | 1.65D / 1.65 seconds | 8 studs | Ground Slam: 1.3D in a 10-stud forward area; 0.7-second ordinary-enemy stagger |
| Bow | Up to 1.2D / 1.3 seconds | 1,000 studs maximum travel | Each bow has its own special; see [bow specials](bow-specials.md). |
| Staff | D / 1.1 seconds | 50 studs | Burst: 1.25D in a 7-stud target area; line of sight required |

Bosses resist forced movement and stagger. They are not immune to ordinary damage. Elemental weapon visuals do not silently bypass armor or grant undocumented extra basic-hit damage.

### Complete first-draft weapon roster

The weapon names are distinct choices, not a requirement to craft every weapon. Each row has three main choices. Spear/Sword/Axe etc. determines its behavior above; the theme affects appearance and the described special variation.

| Tier | Weapon 1 | Weapon 2 | Weapon 3 |
| --- | --- | --- | --- |
| 1 | Stone Spear — Spear | Hunting Bow — Bow | Bone Knife — Dagger |
| 2 | Steel Sword — Sword | Frost Spear — Spear; special slows 20% for 3s instead of moving the user | Marsh Bow — Bow |
| 3 | Ember Axe — Axe; cleave damage is 1.2D immediately + 0.4D burn over 4s | Crystal Staff — Staff | Blacksteel Sword — Sword |
| 4 | Meteor Pike — Spear | Dawn Bow — Bow | Crater Hammer — Hammer |
| 5 | Thunder Hammer — Hammer; slam gains an electrical visual, same damage envelope | Tide Spear — Spear | Storm Bow — Bow; Lightning Rod special delivers three pulses to nearby visible enemies |
| 6 | Thorn Blade — Sword; sweep damage is 0.8D immediately + 0.3D bleed over 3s | Ironwood Bow — Bow | Root Staff — Staff; burst slows 20% for 3s |
| 7 | Deepsteel Sword — Sword | Lantern Staff — Staff; burst illuminates its area for 8s | Sky Spear — Spear |
| 8 | Moonblade — Sword | Star Bow — Bow | Gravity Hammer — Hammer; slam briefly pulls ordinary targets up to 2 studs before impact |

**Recipes:** melee weapons use M(t) ×4 + H(t) ×2 + Cord ×2. Bows use M(t) ×2 + H(t) ×4 + Cord ×3; at tier 3–4 replace Cord with Crystal Thread, at 5–8 with Strong Silk. Staves use M(t) ×4 + H(t) ×2 + Clear Crystal ×2. Every tier 2+ weapon additionally uses two signature units: Ice Crystal / Black Glass / Impact Glass / Storm Ore / Thick Spores / Echo Shell / Moon Rock for tiers 2–8 respectively. Tier 1 Bone Knife uses Bone ×3 instead of Stone ×4. Workbench crafts tier 1; Anvil crafts tier 2+.

**Ammunition:** Wood ×1 + Stone ×1 + Fiber ×1 makes 20 Arrows at Hand/Workbench. Arrows deal the equipped bow's damage and remain viable ammunition at every tier. The bow supplies the power; do not require eight nearly identical arrow items. Staves use no ammunition but cost 3 stamina per basic shot.

**Harvester:** everyone still starts with one. Six base combat damage; weak emergency defense, not a scalable substitute for a weapon. It retains a crosshair and tap-to-harvest on mobile.

## 9. Tools

| Tier | Axe | Pickaxe | Base breaking power |
| --- | --- | --- | ---: |
| 1 | Stone Axe | Stone Pickaxe | 40 |
| 2 | Steel Axe | Steel Pickaxe | 80 |
| 3 | Blacksteel Axe | Blacksteel Pickaxe | 160 |
| 4 | Meteor Axe | Meteor Pickaxe | 320 |
| 5 | Storm Axe | Storm Pickaxe | 640 |
| 6 | Ironwood Axe | Reinforced Pickaxe | 1,280 |
| 7 | Deep Axe | Deep Pickaxe | 2,560 |
| 8 | Moon Axe | Moon Pickaxe | 5,120 |

- Harvester base power 20; harvest cycle 0.6 seconds. Dedicated tools use a 0.55-second cycle. Axes specialize in wood/cactus; pickaxes specialize in stone/minerals. Wrong-family tools deal 25% harvesting power and cannot bypass minimum mining grade.
- Tool recipes: M(t) ×3 + H(t) ×2 + Cord ×1, at Workbench for tier 1 and Anvil thereafter.
- **Garden Sickle, tier 2:** Steel Bar ×2 + Wood ×2 + Reeds ×2. Reduces plant interaction duration by 15% while equipped.
- **Field Sickle, tier 5:** Garden Sickle ×1 + Storm Bar ×3 + Living Root ×2. Reduces plant duration by 25%. Does not multiply rare drops.
- **Expedition Tool, tier 8:** Moon Axe ×1 + Moon Pickaxe ×1 + Field Sickle ×1 + Gears ×4. Combines their supported harvesting functions into one held tool, at the same tier-8 power. No combat weapon damage upgrade.
- Tool enchantments and class modifiers must not turn multi-unit node drops into independent bonus-roll opportunities.

## 10. Armor and set bonuses

### Slots, defense, and construction

- Four slots: Head, Chest, Legs, Boots. Every armor family below contains a Hood/Helmet, Coat/Chestplate, Trousers/Legguards, and Boots. These are separate inventory items, named consistently within the set.
- Full-set physical reduction follows the tier table. Piece shares are **20% head, 35% chest, 30% legs, 15% boots** of that set's full value. Mixed gear sums the actual pieces; it does not inherit the highest item's tier.
- Combined equipment physical reduction, including enchantments, caps at 85%. Class monster reduction is applied multiplicatively afterward, retaining its existing 50% class/ability cap.
- Environmental resistance adds between armor pieces to the set's listed full value. Accessories can add at most 15 percentage points, with total equipment resistance capped at 90%; tonics/class/fields multiply afterward.
- Two matching, functional pieces activate the two-piece bonus. Four activate both bonuses. Broken pieces provide no defense/resistance or set count.
- Armor recipes use **M(t)/C(t)/local signature material**: head 2/3/1, chest 4/5/2, legs 3/4/2, boots 2/2/1. Anvil assembles metal pieces; Loom assembles cloth pieces. Both use the same cost budget and tier certification.
- Each family has a minimum craft tier below. Reforge it to a higher unlocked tier at the appropriate station to keep a preferred environmental style relevant. This consumes the old piece plus 75% of the new tier's M/C cost, rounded up, and retains its identity/enchantments if compatible. Signature traits do not multiply with tier. Reforging is an actual material upgrade, not free scaling.
- Reforging restores durability and is not salvage/refund eligible for old costs. Higher-grade armor is visibly labeled, e.g. **Frost Coat · Grade 6**; do not create dozens of obscure material prefixes.

### Armor families

Heat/Cold/Toxin/Wet numbers are complete-set percentages before accessories. Unlisted channels are 0. Two-piece bonuses below are modest utility, not hidden additions to those resistance numbers.

| Set / first tier / signature | Full-set resistance | Two-piece bonus | Four-piece bonus |
| --- | --- | --- | --- |
| Trail / 1 / Resin | Wet 30 | Hunger drains 5% slower | Medical consumables restore +10% HP |
| Dune / 1 / Cactus | Heat 85, Wet 10 | Water removes +5 exposure | After drinking, +10% movement for 5s; 20s cooldown |
| Marsh / 2 / Reeds | Toxin 80, Wet 85 | Mud movement penalty halved | Poison duration reduced 30% |
| Frost / 2 / Warm Fur | Cold 85, Wet 40 | Snow movement penalty halved | Warmth recovery near heat sources +25% |
| Ash / 3 / Black Glass | Heat 85, Toxin 40 | Ash visibility penalty reduced | Burn duration reduced 40%; no lava immunity |
| Crystal / 3 / Clear Crystal | Heat 40, Cold 40, Toxin 50 | Special stamina cost -5% | Weapon-special cooldown -10% |
| Aurora / 4 / Glow Fiber | Heat 70, Cold 70, Wet 40 | Exposure recovery +10% | Changing between hot/cold regions grants 8s of +15% recovery; 30s cooldown |
| Meteor / 4 / Impact Glass | Heat 75, Cold 40, Wet 40 | Stagger duration -10% | First monster hit after 20s without taking damage deals 20% less damage |
| Coast / 2 / Shell Plate | Wet 85, Cold 35 | Swimming stamina cost -10% | Air supply lasts 25% longer |
| Storm / 4 / Cloud Wool | Wet 80, Cold 55 | Wind movement penalty halved | Telegraph-marked lightning damage reduced 35% |
| Garden / 4 / Living Root | Toxin 80, Wet 60 | Medical item use time -10% | Healing over time on wearer restores +15%; abilities unchanged |
| Iron / 3 / Tough Hide | Heat 45, Toxin 35 | Stagger duration -15% | Lose 20% less armor durability |
| Canopy / 2 / Strong Silk | Wet 65, Cold 25 | Climbing stamina cost -10% | Glider stamina cost -20% |
| Diver / 4 / Pressure Glass | Wet 90, Cold 60 | Swimming speed +10% | Pressure-zone air consumption reduced 30% |
| Lantern / 4 / Dark Moss | Cold 65, Toxin 50 | Own carried light radius +15% | Movement-generated monster hearing radius -20% |
| Moon / 4 / Moon Thread | Heat 60, Cold 60, Wet 25 | Landing recovery shortened | Low-gravity movement control improved; fall damage -25% |

**Final set awakening:** at grade 8, each piece additionally accepts one matching E-region trophy to awaken it. Four awakened pieces improve the magnitude of the four-piece bonus by 50%, not the armor's base defense. Flat/categorical bonuses use explicitly displayed alternate values. This is optional final specialization, not required to survive ordinary tier-8 encounters.

**First-hazard exception:** the hand-crafted **Sun Vest** replaces the beginner Reed Sunwrap for new worlds. Fiber ×6 + Healing Herb ×2 + Resin ×2; chest slot; 75% heat resistance on that piece, 2% physical reduction, no set bonus. It can carry a first desert visit without demanding desert materials. Dune armor offers a proper full set and physical-defense path afterward.

**Desert Coat, tier 2:** a standalone chest item with 85% heat resistance, 6% physical reduction, and no set bonus. Recipe Steel Bar ×2 + Cloth ×3 + Cactus ×4 at Loom. This preserves the existing Desert Cloak's role in class starter kits: replacing a Sun Vest must not accidentally reduce protection to one quarter of a set. It counts as one midgame kit item. Its environmental resistance follows the equipment cap; it cannot double-stack with another chest piece.

## 11. Accessories and traversal

Four freely assigned slots. One item per family; upgraded versions replace the earlier version. Bonuses use strongest-per-family and do not stack copies in storage. No passive benefit unless equipped. Accessories do not lose durability in this first draft.

| Item / tier | Effect | Recipe / station |
| --- | --- | --- |
| Warm Scarf / 1 | +30 percentage points cold resistance for early preparation; special early item exception to the usual +15 accessory cap | Cloth ×3 + Warm Fur ×2; Hand |
| Rain Cape / 1 | +15 points wet resistance; reduces wetness buildup | Cloth ×3 + Resin ×2; Workbench |
| Water Flask / 1 | Holds 5 gathered Water uses without separate water stacks; refill at safe source | Glass ×2 + Cord ×1; Workbench |
| Filter Mask / 2 | +15 points toxin resistance | Warm Cloth ×2 + Coal ×2 + Resin ×1; Loom |
| Ice Cleats / 2 | Prevent ordinary ice sliding; no protection from visibly breaking ice | Steel Bar ×2 + Cloth ×1; Anvil |
| Climbing Gloves / 2 | Climb authored rough surfaces/ropes; costs 8 stamina/s | Warm Cloth ×2 + Steel Bar ×1; Loom |
| Small Pack / 2 | +6 storage slots | Warm Cloth ×4 + Cord ×2; Loom |
| Spring Boots Charm / 3 | Dodge costs 20 rather than 25 stamina | Blacksteel Bar ×2 + Crystal Thread ×2; Anvil |
| Heat Shield / 3 | +15 points heat resistance | Black Glass ×3 + Fire Cloth ×2; Anvil |
| Gatherer's Pouch / 3 | +10% common primary harvest quantity, one roll per node; excludes rare drops | Fire Cloth ×3 + Resin ×2; Loom |
| Steady Grip / 3 | Weapon durability loss -15% | Blacksteel Bar ×2 + Warm Fur ×2; Anvil |
| Glider / 4 | Controlled descent; never upward flight; 6 stamina/s | Glow Cloth ×4 + Strong Silk ×3 + Lift Seed ×2; Workbench |
| Air Tank / 4 | 120 seconds additional underwater air; refill at camp for Water ×1 + Coal ×1 and 10s work | Meteor Bar ×3 + Pressure Glass ×3; Anvil |
| Bright Lantern / 4 | Hands-free 24-stud light, no fuel; does not reveal unexplored map | Light Ore ×2 + Glass ×2 + Meteor Bar ×1; Workbench |
| Large Pack / 4 | +12 storage slots, replaces Small Pack | Small Pack ×1 + Glow Cloth ×4 + Gears ×2; Loom |
| Cooling Ring / 5 | Natural heat recovery +15% | Storm Bar ×2 + Ice Crystal ×3; Anvil |
| Warming Ring / 5 | Natural cold recovery +15% | Storm Bar ×2 + Dawn Flower ×3; Anvil |
| Hunter's Charm / 5 | +8% monster damage | Storm Bar ×2 + Bone ×4; Anvil |
| Grounding Belt / 5 | Lightning damage -20%; combines multiplicatively with Storm set | Storm Bar ×3 + Shell Plate ×2; Anvil |
| Repair Pouch / 6 | Field repair restores 35% instead of 25% durability | Tough Cloth ×3 + Living Root ×2; Loom |
| Rescue Charm / 6 | Revival Kit interaction 10% faster, respecting existing combined duration floor | Reinforced Bar ×2 + Living Root ×2; Anvil |
| Strong Glider / 7 | Replaces Glider; stamina cost 4/s, improved turning | Glider ×1 + Sail Cloth ×4 + Heartwood ×2; Workbench |
| Deep Air Tank / 7 | Replaces Air Tank; 240 seconds additional air | Air Tank ×1 + Deep Metal ×3 + Pearl ×2; Anvil |
| Expedition Pack / 7 | +18 storage slots, replaces Large Pack | Large Pack ×1 + Sail Cloth ×4 + Heartwood ×2; Loom |
| Echo Charm / 7 | Brief on-screen direction cue when a nearby unseen monster makes an attack windup; no wall targeting | Echo Shell ×3 + Deep Metal ×2; Workbench |
| Gravity Belt / 8 | Fall damage -40%; stabilizes low-gravity drift, no flight | Moon Bar ×3 + Moon Rock ×3; Anvil |
| Survivor's Charm / 8 | Once per 180s, a nonlethal hit leaving HP below 25 restores 10 HP over 5s; cannot prevent death or revive | Moon Bar ×2 + Living Root ×2 + any E trophy ×1; Anvil |

Pack removal is blocked if its extra slots cannot be moved into available base slots; the UI explains how much space to free. No deletion or silent ground spill. Base storage stays 18 slots plus the six hotbar slots, with equipment separately stored.

## 12. Food, medicine, and environmental survival

### Survival model

- Keep HP, hunger, stamina, signed heat/cold exposure, wetness, and poison distinct. Do not create a permanent thirst meter; water is a useful consumable/preparation resource.
- Exposure spans -100 cold to +100 heat. Dangerous damage starts at magnitude 75: 2 HP/s at 75–89, 4 HP/s at 90–100. Damage bypasses physical armor but uses the environmental preparation rules before buildup.
- Natural recovery toward zero is 0.3 points/s in mild surroundings. Sources such as warm campfires, shade, and medicine add recovery without flipping exposure to the opposite hazard.
- Proposed ordinary harsh-biome buildup before protection: 0.6 points/s at introductory depth, 0.9 C, 1.2 D, 1.5 E. Apply visit maturity **0.35 / 0.50 / 0.65 / 0.80 / 1.00** for 0/1/2/3/4+ previous credits; cap maturity at 0.65 through campaign tier 2 and 0.80 through tier 4.
- Environmental intensity ramps from 25% of the visit's intended value to full over 60 seconds after arrival. No exposure accrues during loading/relocation. The multiplier applies to buildup, not instantaneous HP loss.
- Weather can add at most 25% of the region's ordinary exposure rate before tier 4, 40% later. Do not stack several identical storm/event temperature bonuses.
- Ordinary cold/hot outer regions must remain survivable for a full first visit with their available preparation and occasional recovery. Severe inner areas require better gear and supplies.
- Wetness amplifies cold buildup by at most 25%; poison has a visible buildup/active state and a capped tick rate, not invisible stacking damage from every overlapping volume.
- Early biome weather is calm. Damage-causing major events are disabled for the first two completed visits and until tier 2. Tier-1 desert cannot roll a lethal heatwave chain.
- Campfire gives +1 cold recovery/s within 12 studs while fueled. A roof provides shade that reduces ordinary heat buildup 20% and wetness buildup 60%; it does not grant global weather immunity or stop poison fog.

### Cooking loop — three stations, fixed recipes

**Confirmed direction:** choose a named meal, optionally add one seasoning, choose quantity, and queue it. Cooking runs automatically while the crew explores. No ingredient substitutions, stirring minigame, quality rolls, or burning finished meals. All numbers and catalog additions below remain proposals.

- **Campfire, tier 1:** simple roasting and first-visit food. It also provides the existing nearby warmth.
- **Stove, tier 2:** soups, drinks, rations, and mixed meals. It has its own burner; no separate pot, prep table, or nearby campfire is required.
- **Oven, tier 3:** filling baked meals and larger expedition supplies. Its later grades unlock stronger recipes, not another cooking station.
- Each station shows only its own recipes. Higher stations do not inherit every Campfire recipe. All three stay useful, but basic survival never requires owning all three.
- Baseline recipes are known when their station becomes available; later meals show their campaign tier, exact ingredients, and station grade. Seasoning discovery never blocks an unseasoned meal.
- Click an ingredient to open its source/recipe and return with Back. One seasoning slot opens a compact list showing the buff and its biome source. Missing ingredients cannot be silently substituted.
- Queue up to three jobs per station, each for 1–20 meals. One meal completes at a time; quantity scales ingredients, seasoning charges, and work linearly. Show current progress, total remaining work, output space, fuel, and queued quantities. Preserve the selected recipe and scroll position.
- Stations have 12 output slots. Finished meals stack to 10; Dried Food and Stamina Rations stack to 30. A full output pauses the next meal before consuming its work or fuel; finished output is never dropped on the floor.
- Completed meals can be shared normally through inventory/chests. There is no spoilage, freshness, or serving-temperature meter in this draft. Cooking decisions come from meal size, supplies, and seasoning effects.

### Food roster

Recipes below produce **one meal**. Times are baseline work-seconds **per meal**; required station grade equals the listed tier. Hunger/stamina gains are immediate, capped at the player's maximum, and use the consumer's applicable class food passive. Seasoning buffs use their listed final values, not the Cook's restoration multiplier.

| Food / tier | Exact ingredients | Station / work | Hunger / stamina | Other effect |
| --- | --- | --- | ---: | --- |
| Roasted Meat / 1 | Raw Meat ×1 | Campfire / 8s | 25 / 10 | Simple hunting meal |
| Roasted Mushrooms / 1 | Mushroom ×3 | Campfire / 8s | 22 / 8 | Early meat-free meal |
| Baked Roots / 1 | Root Vegetable ×2 | Campfire / 10s | 24 / 5 | Easy gathered staple |
| Mushroom Soup / 2 | Mushroom ×3 + Water ×1 | Stove / 12s | 30 / 12 | Remove 15 cold exposure |
| Trail Meal / 2 | Roasted Meat ×1 + Mushroom ×2 | Stove / 12s | 35 / 20 | Compact mixed meal |
| Vegetable Stew / 2 | Root Vegetable ×2 + Mushroom ×2 + Water ×1 | Stove / 14s | 38 / 15 | Meat-free expedition option |
| Berry Porridge / 2 | Root Vegetable ×2 + Berries ×3 + Water ×1 | Stove / 12s | 30 / 22 | Energy-focused breakfast |
| Stamina Ration / 2 | Mushroom ×3 + Cactus ×2 + Reeds ×1 | Stove / 14s | 24 / 30 | Stack 30; retains the existing class-kit role |
| Cooling Drink / 2 | Cactus ×2 + Water ×1 + Healing Herb ×1 | Stove / 8s | 0 / 0 | Remove 35 heat exposure; heat buildup −35% for 120s |
| Warming Drink / 2 | Mushroom ×2 + Water ×1 + Healing Herb ×1 | Stove / 8s | 0 / 0 | Remove 35 cold exposure; cold buildup −35% for 120s |
| Dried Food / 3 | Raw Meat ×1 + Mushroom ×1 | Oven / 18s | 30 / 10 | Stack 30; no Salt dependency on an unreleased biome |
| Stuffed Mushrooms / 3 | Mushroom ×3 + Raw Meat ×1 + Healing Herb ×1 | Oven / 18s | 45 / 25 | Smaller alternative to a full roast |
| Root Roast / 3 | Root Vegetable ×3 + Mushroom ×2 + Berries ×2 | Oven / 18s | 42 / 25 | Filling meat-free meal |
| Hunter's Roast / 4 | Raw Meat ×3 + Root Vegetable ×2 + Healing Herb ×1 | Oven / 24s | 55 / 30 | Large hunting meal |
| Glowcap Stew / 4 | Glowcap ×2 + Mushroom ×2 + Root Vegetable ×1 + Water ×1 | Stove / 20s | 45 / 35 | Uses Marsh ingredients; no future-biome dependency |
| Expedition Meal / 6 | Roasted Meat ×2 + Glow Mushroom ×2 + Root Vegetable ×2 | Oven / 28s | 60 / 45 | Strong late expedition supply |

Raw snacks remain useful: Mushroom +6 hunger; Berries +5 hunger; Root Vegetable +4 hunger; Cactus +8 hunger and removes 5 heat exposure. Raw Meat is not edible. Water removes 30 heat exposure and shares the existing 3s drink cooldown. These are snack/source items, not additional cooking recipes.

Meals have a 2s eating action and a shared 5s food-use cooldown. Drinks use the existing drink action/cooldown; neither category blocks emergency medical use through an unrelated food cooldown. Final timing is a balance proposal. Cooking better food improves supplies and preparation, not permanent maximum HP or the equipment tier curve.

### Optional biome seasonings

Every cooked **solid meal or soup** accepts exactly **one** seasoning charge per serving, chosen before queuing. Drinks, raw snacks, medicine, and existing seasoned meals cannot be seasoned again. Unseasoned meals retain their full food restoration. There are no spice combinations or additional meal quality levels.

Seasonings are edible herbs, seeds, salts, or magical plants. Do not repurpose Sulfur, ore, weapon dust, or Resin as edible powders. Newly introduced seasoning nodes are visibly distinct and use the hand-gathered plant rules, except the existing mineral Salt. One completed node yields 2–4 charges; Salt's existing resource yield is unchanged. No grinding station is needed. Charges stack to 30.

All listed effects last **240 active living seconds** after eating. Sources A/B are accessible introductory regions when that biome becomes eligible; seasoning potency does not secretly increase with repeated visits. Numbers are initial balance proposals.

| Seasoning | Biome / source | Meal's additional effect |
| --- | --- | --- |
| Wild Herb | Woodlands A/B; small leafy patches | Hunger drain −10% |
| Cool Mint | Dunes A/B; shaded plants around rocks | Heat exposure buildup −15% |
| Bitter Seed | Marsh A/B; seed-bearing reeds | Poison damage received −15%; does not clear poison |
| Warm Pepper | Tundra A/B; red pods near sheltered rock pockets | Cold exposure buildup −15% |
| Ember Pepper | Volcanic Plains A/B; orange plants along cooled lava edges | Direct player weapon damage to monsters +8%, including Harvester combat |
| Crystal Basil | Crystal Basin A/B; translucent leaves near crystal outcrops | Resource breaking power +8% |
| Dawn Petal | Northern Valley B; edible Dawn Flower petals, using one Dawn Flower as one charge | Natural exposure recovery +20%; no effect without a valid recovery source |
| Star Seed | Meteor Crater A/B; glowing seed heads on crater rims | Sprint stamina drain −10% |
| Sea Salt | Coast A; use one existing Salt as one charge | Wetness buildup −15% |
| Storm Thyme | Highlands A/B; grass pockets below exposed ridges | Natural stamina regeneration +10%; does not regenerate through sprint exhaustion rules |
| Glow Spice | Mushroom Forest A/B; glowing edible caps distinct from ordinary Glow Mushroom | Hand-gathering duration −10% |
| Red Garlic | Badlands A/B; exposed red bulbs | Incoming monster damage −5% |
| Citrus Peel | Rainforest A/B; citrus-bearing bushes | Dodge stamina cost −10% |
| River Dill | Flooded Ruins A/B; greenery on raised canal edges | Swimming speed +8%; no benefit to ground speed |
| Cave Anise | Caverns A/B; pale plants near cave entrances | Air consumption while submerged −10% |
| Moon Poppy | Moon Surface A/B; luminous flowers in sheltered dust | Weapon-special stamina cost −10%; does not affect class abilities/cooldowns |

The later eight seasonings are optional expansion content. No meal in the initial eight-biome release requires them. Ordinary seasonings remain useful late because their effects are percentages; higher equipment still provides the main power increase.

**Buff rules:**

- One seasoning buff is active per player. Eating a differently seasoned meal replaces it; eating the same seasoning refreshes its duration, never adds potency or banks time. Unseasoned food does not remove an active seasoning.
- One thermal drink buff can be active: Cooling or Warming. Same drink refreshes; switching replaces. If a drink and seasoning both reduce the same exposure channel, use the stronger reduction, not both. Multiply this food protection with armor and the existing class/field resistance rules.
- Wild Herb, hunger set bonuses, and class hunger reduction multiply; food alone never eliminates drain. Red Garlic multiplies after the existing capped class reduction and armor. Ember Pepper applies once to direct player damage, not turret shots, damage-over-time, or reflected/proc damage.
- Resource power joins the existing +75% total class/ability/enchantment cap; hand-gathering reduction joins the 50% cap. Movement/stamina effects multiply with their existing modifiers and cannot bypass movement states, cooldowns, or exhaustion restart requirements.
- Seasoning is not an enchantment and occupies no gear slot. It persists when gear is swapped; inventory storage does not pause a buff already consumed. There is no random chance to get a stronger dish.
- Buff timers pause when offline/loading and clear on death or the end of the run. Save remaining time and refresh/replace atomically; reconnecting cannot refresh it. Creative may preview effects but cannot export food or rewards to survival worlds.
- Tooltips show the meal name, exact restoration, seasoning name/effect, and duration. Stack identity includes recipe and seasoning: an Ember Pepper Trail Meal cannot merge with a Cool Mint Trail Meal. Use a small colored seasoning icon, not a long invented item name.

### Cooking jobs, fuel, and class compatibility

- Cooking uses shared station jobs, not player-bound crafting timers. Ingredients and selected seasoning charges enter station escrow when queued. Walking away or disconnecting does not cancel food already cooking; an entirely offline world pauses it. Ordinary player-bound crafting still follows the approved disconnect refund rule.
- Cancel returns ingredients and seasoning for unfinished servings, including a partly prepared serving; spent fuel is not refunded, and completed output remains. Each serving commits input consumption and output exactly once. Station movement/salvage must require collecting output and canceling/refunding pending jobs, with an inventory-space check before removal.
- Each cooking station has its own visible fuel slot and on/off control. Wood burns for 60 active seconds, Peat for 120, Coal for 240. Heat is explicit elapsed burn time, unlike the Furnace's work-based fuel. Stations stop automatically when their queue finishes, except a Campfire deliberately left in **Keep warm** mode. Retain unused fractional burn time through pause/save.
- Campfire cooking and nearby warmth share one burn; do not charge fuel twice. Stove/Oven provide cooking only, without stacking extra Campfire recovery auras. Empty stations never silently take fuel from player inventories.
- Engineer's approved work-rate passive applies to jobs they queued while they are living in that world; otherwise work returns to baseline. Overclock affects existing/new work at its selected station while active. Combined work rate remains capped at 2×. These change speed, not outputs or refunds; faster cooking can use less elapsed burn time.
- Cook retains the approved food-restoration/hunger passives and Mess Call. Those do not amplify seasoning stats, extend buff duration, or duplicate portions. Queues alone do not count as meaningful activity for class XP. Any class can prepare every dish.
- **Starter-kit compatibility proposal for review:** replace the Cook's level-4 Drying Rack with one base Stove in new-overhaul worlds. Keep the level-2 Campfire and level-5 two Stamina Rations. A Stove is tier 2 and introduces no late-game starter item. Legacy kits/worlds retain the Drying Rack. This is the only new class-kit change proposed here.
- Mobile uses one recipe list/detail flow, a single seasoning picker, quantity controls, and a visible queue strip. No nested scroll areas, dragging requirement, or timing interaction. Show pending feedback immediately and confirm only after the server accepts the job.

### Medicine and repair consumables

Recipes produce one unless stated. Medical restoration is capped at maximum and follows applicable medical passives; ability restoration is never amplified a second time. These remain at their appropriate stations, not in cooking tabs.

| Item | Effect | Recipe / source |
| --- | --- | --- |
| Bandage | +25 HP over 5s | Cloth ×1 + Herbal Paste ×1; Hand |
| Healing Wrap | +50 HP over 8s | Warm Cloth ×1 + Herbal Paste ×2; Medicine Table |
| First Aid Kit | +70 HP over 10s | Tough Cloth ×1 + Living Root ×1 + Herbal Paste ×2; Medicine Table grade 6 |
| Revival Kit | Revive to 30 HP, 50 hunger/stamina, zero exposure; base 5s interaction | Cloth ×3 + Herbal Paste ×2 + Resin ×2; Hand |
| Antidote | Clear active poison and toxin buildup; +35% toxin resistance for 120s | Healing Herb ×2 + Venom Gland ×1 + Water ×1; Medicine Table |
| Drying Salve | Remove wetness; +25% wet resistance for 120s | Plant Oil ×1 + Cloth ×1; Medicine Table |
| Recovery Tonic | Remove 25 heat/cold exposure toward zero; +0.5 recovery/s for 60s | Dawn Flower ×2 + Frost Bloom ×1 + Water ×1; Medicine Table |
| Field Repair Kit | Restore 25% tool/weapon durability after 3s use; item grade limited to kit grade | M(t) ×1 + Resin ×1 + C(t) ×1; Workbench; labeled by grade |
| Armor Patch | Restore 25% durability to one armor piece after 3s use; grade limited | C(t) ×2 + Resin ×1; Loom; labeled by grade |

Repeated identical healing-over-time effects refresh their remaining duration instead of summing rates. Different medical consumables share a 5s use cooldown. Recovery items move exposure toward zero, never make a hot player colder than neutral. Poison resistance and reduced poison damage are distinct: Bitter Seed does not substitute for an Antidote or appropriate armor.

## 13. Durability and repair

- Successful weapon contacts consume 1 durability per attack, regardless of targets hit. Misses and rejected hits consume none. Bow/staff shots consume 1 only when the server accepts the shot.
- A successful resource hit consumes 1 tool durability; invalid targets do not. Armor loses 1 durability per accepted damaging monster strike, allocated to one random functional piece so four pieces do not all wear from every hit. Environmental buildup does not wear armor.
- Proposed capacities: weapons 400 + 40×(tier−1), tools 300 + 40×(tier−1), each armor piece 180 + 25×(tier−1).
- Warn at 20% and 5%, with a small HUD indicator for equipped gear. At zero: no weapon damage/tool power/armor benefits until repaired. Keep the item and all enchantments.
- Full station repair restores missing durability for **ceil(20% × missing fraction × original M/C crafting requirements)**, with minimum one required material. Repairs do not consume another gear item, rare trophy, or transferred enchantment.
- Use Anvil for weapons/tools and Loom for armor. Repair requires the item's grade and takes 5s base work. Partial field kits are the expedition alternative.
- A damaged item cannot be reset by stacking, dropping, storage, creative/survival toggling, or saving. Creative can explicitly restore durability through its admin panel.
- The first Harvester is repairable for Stone ×1 at Hand to avoid a soft lock when all other tools are broken. It is not replaced for free on rejoin/revival.

## 14. Enchanting

**Revision direction confirmed:** replace the generic Minecraft-like enchantment ladder with EcoShift-specific interactions. Each enchantment has its own maximum level. The names, effects, caps, and prices below are proposed replacements for review, not implemented behavior.

### Discovery, slots, and costs

- Enchanting Table unlocks at tier 3. Discover named schematic pages through landmarks, projects, bosses, and regional exploration; consuming a page teaches that saved-world crew its named enchantment/rank. No random enchanting rolls or failure chance.
- The Old Forge introduction offers a choice of Strike Rhythm I, Open Seam I, or Camp Stitch I. Duplicate known pages convert to 4 Enchanting Dust, once per consumed item.
- Gear slots: weapons/tools 1 at grade 3, 2 at grade 4, 3 at grade 6; armor 1 at grade 3 and 2 at grade 5; accessories 1 at grade 5. No slots on starter gear.
- **There is no universal level-V cap or shared rank-to-grade formula.** Every catalog entry specifies its own maximum and exact required gear/station grades. For example, Last Thread is a complete one-level effect at grade 7; Open Seam has four levels across grades 3/5/6/8; Strike Rhythm has five.
- The UI shows the enchantment's actual level/max, next effect, required schematic rank, grade, and cost. A completed one-level enchantment says Complete, not Locked level II.
- Levels replace earlier values. An upgrade purchases only its destination rank; lower ranks are not added together. New-world grade-3+ equipment is functional without enchantments.
- Costs follow the **required grade of the destination rank**, not its ordinal rank. M is the equipped item's current metal/material grade, so transferring onto stronger gear retains a relevant material cost.

| Required grade of rank | Dust | M units | Theme units |
| --- | ---: | ---: | ---: |
| 3 | 4 | 1 | 1 |
| 4 | 8 | 2 | 1 |
| 5 | 12 | 3 | 2 |
| 6 | 18 | 4 | 2 |
| 7 | 26 | 5 | 3 |
| 8 | 40 | 6 | 4 |

- A rank requiring grade 8 additionally consumes one matching E-region trophy named in its catalog row. Enchantments ending before grade 8 have no trophy requirement merely because they are at their maximum.
- Upgrades are sequential and require the learned rank. Extraction removes the enchantment into a non-stackable transferable scroll, costs half its rank's Dust cost rounded up plus Glass x1, and preserves rank. Reapplying consumes that scroll and half its destination material/theme cost rounded up; no second trophy is charged. The receiving item must have a compatible free slot and sufficient grade. Removal without extraction destroys the enchantment with no refund.
- An extracted effect cannot carry ready-to-use stored charges. A source item's spent once-per-visit effects remain spent. Moving a scroll to another piece cannot refresh a once-per-visit allowance for its user.

### Replacement enchantment catalog — 18 distinct effects

Values separated by slashes correspond only to that enchantment's actual ranks. Grade lists are likewise ordered by rank. D below means the weapon's unenchanted tier-standard damage from section 2; it does not use an already amplified hit as a new damage multiplier.

| Enchantment | Gear / maximum / required grades | Effect by rank | Theme and discovery source |
| --- | --- | --- | --- |
| Strike Rhythm | Weapons; **5 levels**; 3/4/5/7/8 | Every third consecutive accepted basic hit on the same monster adds 10/14/18/22/26% D. Chain expires after 4s without a hit or changing target; specials do not advance it. | Bone; hunting sites; any E trophy for rank V |
| Open Seam | Axes/pickaxes/Expedition Tool; **4 levels**; 3/5/6/8 | On the same resource node, every third successful hit gains 15/25/35/45% normal breaking power. Visible crack cue; change target or wait 4s to lose the chain. Does not bypass mining grade. | Resin for rank I, Deep Resin for later ranks; mineral/root sites; Sun Heart for rank IV |
| Clean Cut | Sickles/Expedition Tool; **3 levels**; 3/5/7 | After completing a plant harvest, the next plant gather started within 5s takes 10/15/20% less time. At most one stored benefit; no extra rare drops. | Reeds; wetland/plant sites |
| Quick Stow | Tools; **2 levels**; 4/6 | On node completion, automatically collect that node's normal drops within 6/10 studs if space exists. Overflow stays on the ground; no loot through walls, from other players, or from chests. | Resin; field-supply sites |
| Heat Store | Chest armor; **2 levels**; 4/6 | An actual reduction of at least 20 heat or cold exposure by a consumable stores an 8/12-point buffer against the same temperature direction for 90s. Buffer absorbs new exposure, not HP damage. One buffer; cannot charge from its own absorption or neutral-player item use. | Ice Crystal; thermal sites |
| Weather Memory | Head armor; **3 levels**; 4/6/8 | After qualifying for a biome visit while worn, remember its dominant environmental channel. On a later visit to that biome, reduce that channel's buildup 15% for the first 30/45/60s. One memory per biome; no bonus before discovery or prediction of an unvisited biome. | Aurora Stone; weather sites; Dawn Heart for rank III |
| Dry Step | Boots; **3 levels**; 3/5/7 | After leaving water/rain for dry shelter, wetness clears 20/35/50% faster for 10s. Entering water/rain ends it; does not erase wetness instantly. | Kelp; coastal sites; unavailable until its content release |
| Shared Cover | Chest armor; **2 levels**; 5/7 | While wearer and a living teammate are under the same valid roof within 10 studs, both receive 8/12% less environmental buildup. Strongest aura only; no added protection through separate floors or walls. | Shell Plate; shelter/defense sites |
| Camp Stitch | Armor; **3 levels**; 3/5/7 | After 10s at a suitable camp repair station, offer a quick repair consuming Resin x1 to restore 4/7/10% durability to that enchanted piece. Explicit confirmation; once per item per visit; no repair if already full. | Resin; repair sites; Anvil or Loom works before Repair Bench unlock |
| Last Thread | Armor; **1 level**; 7 | Once per user per visit, a durability loss that would break an enchanted piece leaves it at 1 durability for 8s. Further wear is ignored during that window; it then becomes broken unless repaired. Does not prevent HP death. | Tough Hide; advanced repair sites |
| Rescue Reserve | Accessories; **1 level**; 5 | After personally completing a teammate revival, restore 15 of the rescuer's stamina and remove 15 heat/cold exposure toward zero. 60s cooldown. Does not alter the revived player's established reset values. | Healing Herb; rescue objectives |
| Saved Meal | Accessories; **2 levels**; 5/7 | Capture up to 10/20 hunger that would otherwise be wasted by eating above maximum hunger. Once hunger falls below 50, release the saved amount at 1 hunger/s. No charge from class abilities, admin restoration, or consuming the reserve itself. | Glow Mushroom; cooking/supply sites |
| Air Pocket | Head armor; **3 levels**; 4/6/8 | When remaining air first falls below 25%, release 15/25/35 extra seconds from a reserve. Recharges only at a camp air-refill station after a full refill; merely surfacing, re-equipping, or reconnecting does not refill it. | Pressure Glass; underwater sites; Archive Heart for rank III |
| Pack Warning | Head armor; **2 levels**; 4/6 | After receiving a monster hit, show local map warnings for up to 3/5 nearby monsters of that species within 40 studs for 8s. 20s cooldown; does not reveal terrain or permit targeting through cover. | Echo Shell; tracking/cave sites |
| Survey Link | Accessories; **2 levels**; 5/7 | First personal entry into an already generated sub-biome footprint reveals an extra 12/20-stud terrain radius around the entry point on the shared map. Once per user per footprint per visit; no resource/loot duplication or distant chunk activation. | Clear Crystal; survey projects |
| Return Shot | Bows/staves; **4 levels**; 4/5/7/8 | A dodge that actually avoids a server-confirmed monster attack primes the next accepted basic shot within 3s for +10/15/20/25% D. 8s cooldown; dodging empty space does not charge it. | Strong Silk; traversal/combat sites; Sky Heart for rank IV |
| Vent Strike | Weapons; **3 levels**; 4/6/8 | A special that hits a monster removes 4/7/10 exposure toward zero when magnitude is at least 25. One trigger per cast regardless of targets; no poison removal or extra damage. | Frost Bloom; thermal combat sites; Frost Heart for rank III |
| Storm Latch | Weapons; **2 levels**; 6/8 | After 30s of active outdoor exposure to current rainy/storm weather, store one charge. The next special hit releases +12/20% D to its primary target. Charge expires after 60s or leaving the visit; no stacking charges. | Storm Core; storm sites; Greater Storm Core for rank II |

### Effect limits and persistent state

- Each enchantment is installed at most once on an item. Across equipped pieces, same-name effects use the strongest rank, except Camp Stitch which repairs only its own paid-for item. Equipping duplicates does not create several auras, reserves, or warning cooldowns.
- Schematics requiring an unimplemented future-biome ingredient remain unavailable until that content release; do not offer them as the only introduction reward. All three Old Forge introduction choices can be applied using tier-3-accessible materials.
- Strike Rhythm and Return Shot share the **Attack Rhythm** family: only one on a weapon. Vent Strike and Storm Latch share the **Special Response** family: only one on a weapon. Tool functions Open Seam/Clean Cut may coexist on the Expedition Tool because they operate on different actions.
- Bonus damage uses the unenchanted reference D once, then the ordinary class/armor/mark resolution once. Triggered damage cannot charge another enchantment, repeat a hit counter, trigger itself, or count as a second active action. No chain-reaction damage loops.
- Open Seam's conditional resource bonus joins class/ability bonuses under the existing +75% cap over normal tool power. Total plant duration reduction still caps at 50%; crafting work rate remains capped at 2x baseline.
- Environmental effects multiply with armor/class effects. Strongest identical aura only. Heat Store, Saved Meal, Air Pocket, Weather Memory, cooldowns, and spent visit allowances need saved state with their owner/item as appropriate.
- Swapping gear suspends or clears short combat chains rather than preserving a charged attack on every stored weapon. It does not reset cooldowns, refill reserves, or restore a once-per-visit allowance. Enchantment histories stay with the saved world.
- The compatibility UI lists the **actual supported enchantments** for an accessory. Saved Meal/Rescue Reserve/Survey Link work as attached functions; there is no generic multiplier that accidentally expands a backpack or grants flight.

## 15. Camp, stations, and structures

### Station roster

Stations are shared crew facilities. Grade is an upgrade on the placed item and survives salvage/save; it is not discarded when moving the station. Starter station items remain grade 1 unless an approved class kit explicitly supplies a higher grade, which this draft does not introduce.

| Station / earliest tier | Purpose | Initial recipe |
| --- | --- | --- |
| Workbench / 1 | Tools, utility, structural items, assembly; inherits hand recipes | Wood ×8 + Stone ×4; Hand |
| Campfire / 1 | Simple roasting and actual warmth | Stone ×6 + Wood ×4; Hand |
| Furnace / 1 | Ore, glass, and higher-grade metal batches | Stone ×12 + Wood ×6; Workbench |
| Loom / 1 | Cloth, wearable pieces, packs, patches | Wood ×6 + Fiber ×4; Workbench |
| Stove / 2 | Soups, drinks, rations, and mixed meals | Stone ×8 + Iron Bar ×4 + Plank ×4; Workbench |
| Oven / 3 | Baked meals, dried food, and later expedition meals | Stone ×16 + Steel Bar ×4 + Plank ×4; Workbench |
| Anvil / 2 | Metal equipment, full weapon/tool repairs | Iron Bar ×4 + Stone ×8; Workbench |
| Medicine Table / 2 | Advanced medical items and brewing | Plank ×6 + Glass ×2 + Herbal Paste ×2; Workbench |
| Survey Desk / 2 | Instruments, maps, and world-control devices | Plank ×6 + Iron Bar ×2 + Glass ×2; Workbench |
| Enchanting Table / 3 | Apply, upgrade, extract, and transfer enchantments | Blacksteel Bar ×4 + Clear Crystal ×4 + Crystal Thread ×2; Workbench |
| Repair Bench / 4 | Crew repair queue and consolidated gear-maintenance page; uses normal Anvil/Loom repair costs | Meteor Bar ×3 + Plank ×6 + Gears ×2; Workbench |

- All physical grade upgrades use the previous grade's M ×6 + C ×4 + Plank ×4. Upgrade only after the corresponding world certification; named station role remains unchanged.
- A station first introduced after tier 1 is created at its introductory grade using the explicit initial recipe, not charged for earlier unavailable grades.
- Workbench display title becomes Advanced Workbench at grade 4 and Master Workbench at grade 7, preserving familiar names without an extra self-dependent recipe chain.
- The new rules remove separate Kiln and Refinery items; Furnace takes their processing roles. Legacy worlds retain their old stations. Old class-kit Furnace and Workbench entries map to the corresponding new base facilities.
- Furnace batch input and output are physical inventories, with one active batch queue per station. Wood gives 15 work-seconds of fuel, Peat 30, Coal 60. Pause when out of fuel; do not consume unperformed work. Fuel is a separate visible cost from any Coal used as a steel ingredient.
- Cooking fuel/queues follow section 12. Campfire, Stove, and Oven are the only new-world cooking stations; Oven absorbs the former Drying Rack food role. No food Prep Table, Smoker, separate Pot, or separate spice-processing station is added. Medicine Table remains for medical items, not food.
- Upgrading a busy station waits until its existing batch finishes or the crew cancels it with an exact refund of unprocessed inputs. Do not reprice work already accepted.

### Building and utility roster

All dimensions are initial model targets. Place from the held inventory item. Structural recipes are at Workbench and produce one item unless noted.

| Item | Function / footprint | Recipe |
| --- | --- | --- |
| Floor | 8×8 stud foundation panel | Plank ×2 |
| Wall | 8 studs wide, 8 tall; blocks ordinary physical movement | Plank ×2 |
| Roof | 8×8 panel; contributes shade/rain shelter | Plank ×2 + Fiber ×1 |
| Ramp | 8×8 run/rise connection | Plank ×3 |
| Door | Player-operated 4-stud opening; F/touch toggle | Plank ×2 + Resin ×1 |
| Gate | Player-operated 8-stud opening | Plank ×4 + Iron Bar ×1 |
| Stairs | 8-stud story connection | Plank ×3 |
| Ladder | 8-stud vertical connection | Wood ×3 + Cord ×1 |
| Watchtower | 8×8, approximately 16 high, accessible ladder | Plank ×10 + Stone ×6 |
| Chest | 24 shared item slots | Plank ×4 + Resin ×2 |
| Large Chest / tier 4 | 48 shared slots | Chest ×1 + Ironwood ×4 + Gears ×2 |
| Torch | Placeable light; no heat protection | Wood ×1 + Resin ×1; produces 2 |
| Standing Lamp / tier 3 | Larger camp light, no ongoing fuel | Iron Bar ×2 + Glass ×2 + Clear Crystal ×1 |
| Rain Collector / tier 2 | Produces one Water/minute during rain, stores up to 10; no offline production | Plank ×4 + Cloth ×3 + Resin ×2 |
| Water Filter / tier 4 | Dirty Water ×1 becomes Water ×1 in 10s; consumes one Coal per 10 batches | Meteor Bar ×2 + Coal ×2 + Glass ×2 |
| Bedroll / tier 2 | Stationary recovery: +1 stamina/s and +0.2 exposure recovery/s; no passive HP or respawn | Warm Cloth ×3 + Fiber ×4 |
| Spike Trap / tier 2+ | Upgradeable grade; deals 0.8D to one monster crossing it, 3s reset; consumes 1 Bone per 10 triggers | M(t) ×2 + Plank ×2 + Bone ×2 |
| Camp Marker | Visible named crew map marker | Wood ×2 + Cloth ×1 |

The generic old Machine item has no standalone replacement: its intended functions become named stations/devices. Permanent traps are not free monster farms: they require fuel/ammunition and do not award class activity for an idle owner.

Permanent building stays inside camp. No automated resource extractors, conveyors, farming simulation, building demolition by monsters, or power networks in this first draft. Safe camp geometry does not prevent all monster attacks: ranged enemies can attack through openings and melee enemies can enter open doors, but do not suddenly gain wall-breaking behavior.

Salvage remains a deliberate three-second hold in survival and creative. Refund the placed inventory item with its stored station grade, inventory contents, and relevant metadata; structural paid-material salvage follows actual recorded cost where applicable. Preserve the existing chest-overflow handling. Never both return an intact station and separately refund its crafting materials.

## 16. Intelligence and world controls

### Instrument roster

Carried instruments grant information; accessories are not required to equip them. Combining instruments prevents permanent inventory-slot clutter. Their inspection panel shows exactly which information is unlocked.

| Item / tier | Actual function | Recipe |
| --- | --- | --- |
| Field Clock / 1 | Reveals current shift countdown | Glass ×2 + Iron Bar ×1 + Plank ×2; Workbench |
| Threat Gauge / 2 | Shows campaign tier, bounded pressure, and nearby region danger | Iron Bar ×2 + Glass ×2 + Coal ×1; Survey Desk |
| Resource Compass / 3 | Select a known resource and point toward nearest discovered matching site within 300 studs; no unexplored map reveal | Blacksteel Bar ×2 + Clear Crystal ×2 + Resin ×1; Survey Desk |
| Weather Scanner / 3 | Shows current region's measured hazards, recovery sources, and preparation advice; does not forecast the next biome | Glass ×3 + Blacksteel Bar ×2 + Ice Crystal ×1; Survey Desk |
| Biome Predictor / 4 | Shows next main biome and current shift countdown | Field Clock ×1 + Meteor Bar ×2 + Aurora Stone ×2; Survey Desk |
| Weather Predictor / 4 | Adds next visit's base weather; keeps clock/biome information | Biome Predictor ×1 + Weather Scanner ×1 + Clear Crystal ×3; Survey Desk |
| Event Detector / 5 | Warns of a scheduled major surface event 45s before start and marks its discovered origin | Storm Bar ×2 + Gears ×2 + Sunstone ×2; Survey Desk |
| Trail Beacon / 3 | Placeable temporary named return marker outside camp; 15-minute lifetime; no teleport | Blacksteel Bar ×1 + Clear Crystal ×1 + Cloth ×1; Survey Desk |
| Field Journal / 5 | Combines owned Clock/Gauge/Compass/Scanner/forecast functions into one carried item; event module can be inserted later | Instruments to combine + Storm Bar ×2; Survey Desk; consume only functions actually installed |

No instrument promises a function that is merely planned. Resource instructions distinguish undiscovered, absent this visit, locked depth, and known nearby sources.

### Reusable control devices

All use existing majority voting among living, connected crew. Proposal: 20-second ballot, strictly more than half; proposer votes yes. Solo can approve their own action. Death/departure updates the eligible electorate; revalidate before committing. Refund fuel if a failed generation prevents the approved action from committing.

| Device / target availability | Effect | Build recipe / fuel / limits |
| --- | --- | --- |
| Shift Stabilizer / tier 2, 1–2 h | Add 60 seconds to this visit | Steel Bar ×4 + Glass ×2 + Resin ×3; fuel Coal ×2 + Resin ×2; once per visit, 300s cooldown |
| Shift Trigger / tier 2, 1–2 h | Begin a 15s warning and shift early | Steel Bar ×4 + Ice Crystal ×2 + Gears ×2; fuel Coal ×2 + Cactus ×2; usable after the first active minute, 300s cooldown |
| World Dial / tier 4, 4–6 h | Choose next main biome from previously visited, currently eligible choices | Meteor Bar ×6 + Star Core ×2 + Aurora Stone ×2 + Gears ×4; fuel Clear Crystal ×3 + Herbal Paste ×2; once per visit, 600s cooldown |
| World Anchor / tier 8, 10–15 h | Choose any eligible biome, including unvisited ones; propose base weather; optionally extend a visit up to 600 seconds total | World Dial ×1 + Moon Bar ×6 + Pressure Glass ×4 + four different E trophies ×1 each; fuel Moon Ore ×2 + Living Root ×2 + Clear Crystal ×4; 900s cooldown |

Controls never bypass campaign/sub-biome eligibility or count as extra visit credit by themselves. Destination selection chooses the main biome, not a guaranteed rare sub-biome layout. Weather choice cannot spawn missing resources or suppress scripted dungeon mechanics. The maximum visit length of 600s is shared with all extension effects, including any class/event effects.

## 17. Monsters, bosses, and expedition areas

### Ordinary creature roster — 64 species

**Confirmed scope:** at least four ordinary creatures per main biome. Bosses and elite versions do not count toward that minimum. The first draft below has four per biome, with different habitat/behavior roles; additional species can be added if they bring a useful role.

Each species needs its own silhouette, movement/attack rhythm, windup, and recovery. Reusing the current Wolf AI with a different name is not sufficient. N species are ordinary non-hostile wildlife, not extra attackers; heavy territorial species threaten players only inside their clearly indicated territory or after provocation.

Role tags: **L** light, **O** ordinary, **H** heavy, **S** small swarm, **N** non-hostile wildlife. These select section 2 health budgets. Wildlife has light HP and no offensive attack. Swarm creatures use half light HP/damage. Species role is independent of region/campaign strength.

| Biome | Creature 1 | Creature 2 | Creature 3 | Creature 4 |
| --- | --- | --- | --- | --- |
| Woodlands | Wolf [L]: flanking bite and short committed lunge | Boar [H]: straight charge with long recovery | Bark Spider [O]: ground-level web snare followed by a short bite | Deer [N]: cautious herd animal that flees danger |
| Dunes | Scorpion [O]: visible pincer/tail windups | Sand Serpent [H]: visible moving sand trail before emergence | Dune Beetle [L]: short rolling rush, exposed while recovering | Desert Fox [N]: scavenger that retreats between rock shelters |
| Marsh | Leech [L]: slow approach and interruptible drain contact | Bog Toad [H]: aimed tongue shot and recovery pause | Marsh Snake [O]: swims between banks, pauses visibly before striking | Heron [N]: shallow-water feeder that flies away from danger |
| Tundra | Frost Wolf [L]: flank and short-lived cold patch | Ice Wraith [O]: windup dash followed by a vulnerable pause | Ice Bear [H]: slow swipe and telegraphed ground slam | Snow Hare [N]: small prey animal using snow shelters |
| Volcanic Plains | Ash Hound [L]: fast approach and committed bite | Lava Golem [H]: slow slam with a marked ground area | Cinder Crab [O]: sideways approach and brief hot ground behind it | Ash Lizard [N]: hides in cooled rock cracks |
| Crystal Basin | Crystal Stalker [O]: visible sidestep before attacking | Prism Guard [H]: slow beam with an obvious tracking line | Shard Mite [L]: short hops and brittle close-range attacks | Crystal Grazer [N]: moves between mineral outcrops and flees |
| Northern Valley | Aurora Stag [O]: straight antler charge, territorial rather than long pursuit | Snow Owl [L]: low swoop with a reachable landing recovery | Spring Bear [H]: guards warm pools, slow two-swipe attack | Valley Hare [N]: grazes sheltered warm patches |
| Meteor Crater | Rock Crawler [H]: armored front and exposed rear | Star Beetle [O]: arcing projectile with a visible landing marker | Dust Mite [L]: short burrowing rush with a visible trail | Crater Lizard [N]: ground scavenger sheltering beneath debris |
| Coast | Tide Crab [O]: sideways approach with shell-front defense | Reef Eel [L]: water-only rush preceded by a ripple | Shellback [H]: territorial turtle with a slow head thrust; short chase | Sandpiper [N]: beach-feeding bird that retreats from combat |
| Highlands | Gale Raptor [L]: low jumping attack with grounded recovery | Thunder Ram [H]: committed charge at last aimed position | Cliff Spider [O]: short web shot across a path, then approaches | Mountain Goat [N]: climbs authored safe ledges and avoids danger |
| Mushroom Forest | Spore Mite [S]: weak short-range attacker in small swarms | Root Guardian [H]: stationary warning pulse and root strike | Cap Beetle [O]: slow shove followed by a visible spore puff | Moss Snail [N]: slow grazer along damp ground |
| Badlands | Rustback [H]: armored beast with vulnerable sides | Burrower [O]: tunnel trail and delayed emergence | Thorn Jackal [L]: circles once before a committed bite | Rock Hare [N]: small prey using rocky cover |
| Rainforest | Branch Cat [O]: stalks connected routes and leaps short gaps | Giant Moth [L]: dust cone with a long recovery window | Vine Snake [L]: visible hanging posture before dropping onto a route | Canopy Deer [N]: moves along broad root platforms |
| Flooded Ruins | Lantern Eel [L]: water-only light lure and short rush | Archive Guard [H]: slow patrol and visible pressure blast | Canal Crab [O]: hides beside rubble and makes a short pincer attack | Silverfish [N]: small shoaling fish restricted to water |
| Caverns | Echo Hunter [O]: reacts to noise and telegraphs its rush | Cave Grazer [N]: neutral animal moving between light patches | Cave Bat [L]: low flight pass followed by a perch recovery | Stoneback [H]: slow armored lizard with exposed flanks |
| Moon Surface | Moon Crawler [H]: grounded pursuit and slow slam | Rift Hopper [O]: visible destination before short displacement | Moon Mite [L]: short low-gravity hop with a long landing pause | Dust Grazer [N]: neutral ground animal browsing mineral dust |

### Sub-biome encounter selection

The next table supplies **all 80 regional profiles**, not one shared biome-wide spawn pool. Creature numbers refer to the four columns above.

- Each normal region encounter first rolls its listed mixed-encounter percentage. Otherwise choose one species using that region's four percentages, then roll a group count uniformly within its listed range. Percentages are encounter-selection weights, not four independent guaranteed spawns.
- A mixed encounter is two separately navigable neighboring creatures: one C1 and one C3. They remain species-specific AI, not an artificial interspecies hunting pack. Northern Valley uses C1+C2; Coast uses C1+C2 at shoreline sites. Place them only where both habitats fit; otherwise use an ordinary single-species encounter draw.
- Habitat filtering happens before selection and renormalizes eligible species weights. Water-only creatures never appear on dry paths; flying wildlife requires a viable retreat route; grounded attackers require reachable walking ground. A zero weight is an intentional exclusion.
- Group ranges are constrained by species and campaign safety caps: H at most 1 per group; O at most 3; L at most 4; S at most 5; N at most 3. Hostile tier-1 encounters cap at 2 total, tier 2–4 at 3, tier 5+ at 4 except S swarms may reach 5. If a requested group's minimum exceeds its allowed cap, reduce both bounds to that cap. Mixed groups always contain two creatures, subject to remaining active capacity.
- Every group uses a shared spacing/arrival budget. Do not independently spawn four species groups because four probabilities exist. Truncate or defer an encounter if the active cap lacks room; do not split a large group into several immediate follow-up waves.
- Select once per deterministic encounter ID. Chunk unload/reload cannot reroll the species, count, cleared state, or loot. New visits create new encounter IDs.

| Main biome / sub-biome | C1 / C2 / C3 / C4 (%) | Ordinary group range | Mixed encounter chance |
| --- | --- | --- | ---: |
| Woodlands / A Open Meadows | 15 / 10 / 5 / 70 | 1 | 0% |
| Woodlands / B Birch Woods | 45 / 15 / 25 / 15 | 1–2 | 0% |
| Woodlands / C Old Forest | 30 / 20 / 40 / 10 | 1–3 | 10% |
| Woodlands / D Root Caves | 20 / 10 / 65 / 5 | 2–3 | 15% |
| Woodlands / E Giant Tree Grove | 30 / 40 / 20 / 10 | 2–4 | 20% |
| Dunes / A Sandy Flats | 20 / 5 / 35 / 40 | 1 | 0% |
| Dunes / B Cactus Valley | 35 / 10 / 20 / 35 | 1–2 | 0% |
| Dunes / C Red Canyons | 45 / 30 / 20 / 5 | 1–2 | 10% |
| Dunes / D Buried City | 30 / 35 / 30 / 5 | 2–3 | 15% |
| Dunes / E Glass Dunes | 20 / 50 / 25 / 5 | 2–4 | 20% |
| Marsh / A Reed Marsh | 35 / 10 / 15 / 40 | 1–2 | 0% |
| Marsh / B Willow Pools | 45 / 20 / 15 / 20 | 1–3 | 5% |
| Marsh / C Mushroom Bog | 20 / 40 / 30 / 10 | 1–3 | 10% |
| Marsh / D Sunken Village | 30 / 25 / 40 / 5 | 2–4 | 20% |
| Marsh / E Blackwater Basin | 25 / 45 / 25 / 5 | 2–4 | 20% |
| Tundra / A Snowfields | 20 / 10 / 5 / 65 | 1 | 0% |
| Tundra / B Frozen Woods | 45 / 10 / 15 / 30 | 1–2 | 5% |
| Tundra / C Frozen Lake | 25 / 30 / 25 / 20 | 1–3 | 10% |
| Tundra / D Ice Caves | 20 / 55 / 20 / 5 | 1–2 | 10% |
| Tundra / E Whiteout Peaks | 30 / 35 / 30 / 5 | 2–3 | 15% |
| Volcanic Plains / A Ash Plains | 30 / 5 / 25 / 40 | 1 | 0% |
| Volcanic Plains / B Black Rock Fields | 25 / 20 / 30 / 25 | 1–2 | 5% |
| Volcanic Plains / C Lava Channels | 40 / 25 / 25 / 10 | 1–3 | 15% |
| Volcanic Plains / D Furnace Ruins | 20 / 45 / 30 / 5 | 1–2 | 10% |
| Volcanic Plains / E Volcano Heart | 25 / 50 / 20 / 5 | 2–3 | 20% |
| Crystal Basin / A Crystal Fields | 20 / 5 / 35 / 40 | 1–2 | 0% |
| Crystal Basin / B Broken Stone Flats | 35 / 15 / 25 / 25 | 1–2 | 5% |
| Crystal Basin / C Mirror Canyon | 45 / 25 / 20 / 10 | 2–3 | 15% |
| Crystal Basin / D Crystal Caves | 30 / 30 / 35 / 5 | 2–4 | 20% |
| Crystal Basin / E Shattered Spire | 25 / 50 / 20 / 5 | 2–4 | 20% |
| Northern Valley / A Frosted Meadows | 15 / 5 / 5 / 75 | 1 | 0% |
| Northern Valley / B Dawn Woods | 30 / 20 / 10 / 40 | 1–2 | 5% |
| Northern Valley / C Hot Spring Valley | 25 / 20 / 30 / 25 | 1–3 | 10% |
| Northern Valley / D Northern Cliffs | 25 / 40 / 25 / 10 | 1–2 | 15% |
| Northern Valley / E Aurora Ridge | 35 / 35 / 25 / 5 | 2–3 | 20% |
| Meteor Crater / A Dust Plains | 10 / 20 / 30 / 40 | 1 | 0% |
| Meteor Crater / B Fallen Rock Fields | 30 / 20 / 25 / 25 | 1–2 | 5% |
| Meteor Crater / C Crater Lakes | 30 / 40 / 20 / 10 | 2–3 | 15% |
| Meteor Crater / D Meteor Tunnels | 40 / 20 / 35 / 5 | 1–3 | 20% |
| Meteor Crater / E Impact Core | 50 / 25 / 20 / 5 | 2–4 | 20% |
| Coast / A Shell Beach | 30 / 0 / 10 / 60 | 1–2 | 0% |
| Coast / B Tide Pools | 35 / 30 / 15 / 20 | 1–3 | 5% |
| Coast / C Sea Cliffs | 35 / 5 / 30 / 30 | 1–2 | 5% |
| Coast / D Shipwreck Cove | 30 / 45 / 20 / 5 | 2–3 | 15% |
| Coast / E Storm Reef | 35 / 35 / 25 / 5 | 2–4 | 20% |
| Highlands / A Windy Hills | 20 / 10 / 10 / 60 | 1 | 0% |
| Highlands / B Cloud Meadows | 20 / 20 / 15 / 45 | 1–2 | 5% |
| Highlands / C Thunder Pass | 35 / 35 / 20 / 10 | 1–3 | 10% |
| Highlands / D Lightning Fields | 30 / 40 / 25 / 5 | 2–3 | 15% |
| Highlands / E Storm Summit | 40 / 40 / 15 / 5 | 2–3 | 20% |
| Mushroom Forest / A Mushroom Fields | 25 / 5 / 20 / 50 | 1–2 | 0% |
| Mushroom Forest / B Moss Woods | 35 / 10 / 25 / 30 | 2–3 | 5% |
| Mushroom Forest / C Giant Cap Forest | 30 / 25 / 30 / 15 | 2–3 | 15% |
| Mushroom Forest / D Spore Caves | 45 / 30 / 20 / 5 | 2–4 | 15% |
| Mushroom Forest / E Root Chamber | 30 / 45 / 20 / 5 | 3–5 | 20% |
| Badlands / A Red Flats | 5 / 15 / 20 / 60 | 1 | 0% |
| Badlands / B Thorn Scrub | 10 / 20 / 35 / 35 | 1–2 | 5% |
| Badlands / C Ironwood Forest | 30 / 20 / 40 / 10 | 1–3 | 10% |
| Badlands / D Abandoned Mines | 30 / 50 / 15 / 5 | 2–3 | 15% |
| Badlands / E Rust Fortress | 50 / 25 / 20 / 5 | 2–4 | 20% |
| Rainforest / A Forest Floor | 20 / 10 / 20 / 50 | 1–2 | 0% |
| Rainforest / B Low Canopy | 25 / 30 / 25 / 20 | 1–3 | 5% |
| Rainforest / C Hanging Gardens | 20 / 45 / 25 / 10 | 2–3 | 10% |
| Rainforest / D Broken Bridges | 30 / 25 / 40 / 5 | 2–3 | 20% |
| Rainforest / E Crown Canopy | 40 / 35 / 20 / 5 | 2–4 | 20% |
| Flooded Ruins / A Flooded Courtyard | 10 / 10 / 25 / 55 | 1–2 | 0% |
| Flooded Ruins / B Canal District | 20 / 15 / 30 / 35 | 1–3 | 5% |
| Flooded Ruins / C Drowned Library | 30 / 25 / 25 / 20 | 1–3 | 10% |
| Flooded Ruins / D Sealed Vaults | 25 / 45 / 25 / 5 | 2–3 | 15% |
| Flooded Ruins / E Deep Archive | 35 / 45 / 15 / 5 | 2–4 | 20% |
| Caverns / A Cave Mouths | 10 / 65 / 20 / 5 | 1–2 | 0% |
| Caverns / B Glowmoss Caverns | 20 / 45 / 25 / 10 | 1–3 | 5% |
| Caverns / C Echo Tunnels | 35 / 20 / 35 / 10 | 2–3 | 15% |
| Caverns / D Underground Lake | 25 / 20 / 20 / 35 | 1–2 | 10% |
| Caverns / E Lightless Chasm | 40 / 5 / 30 / 25 | 2–4 | 20% |
| Moon Surface / A Moon Flats | 15 / 10 / 25 / 50 | 1 | 0% |
| Moon Surface / B Silver Ridges | 20 / 25 / 25 / 30 | 1–2 | 5% |
| Moon Surface / C Floating Stone Fields | 25 / 35 / 25 / 15 | 2–3 | 15% |
| Moon Surface / D Broken Observatory | 40 / 30 / 25 / 5 | 1–3 | 15% |
| Moon Surface / E Gravity Well | 40 / 40 / 15 / 5 | 2–4 | 20% |

These weights are a first balance proposal. For example, Open Meadows mostly contains Deer, Birch Woods has more Wolves and Bark Spiders, and Root Caves favors Bark Spiders. The Coast excludes Reef Eels from Shell Beach's normal pool while making them common in Shipwreck Cove's water routes. Region choice changes both species composition and group size without automatically raising total spawn density.

### Population, strength, and loot limits

- Species use light/ordinary/heavy HP from section 2. Light damage is 75% standard; heavy damage 125%, with slower cadence. Elites use 16D HP and 150% standard damage, plus one readable variant mechanic. Elite/boss spawns are separately budgeted and never counted as an additional ordinary species.
- Monster levels are immutable at spawn: **1 + 5×(campaign tier−1) + floor(pressure×4)**, plus an elite indicator where relevant. Region crossings do not modify existing creatures. Species movement speed and reach do not increase with level.
- No hostile wave in the first 90 active seconds of a new expedition. Safe relocation at subsequent shifts uses the terrain safety rules, not immediate point-blank monster spawns.
- Hostile/territorial active cap stays **max(4, 4×living crew), capped at 24**. Neutral wildlife uses a separate **3×living crew, capped at 12** budget. No extra hostile cap is granted merely because the catalog now has 64 species. Encounters spread across occupied regions rather than concentrating on an isolated player.
- Grounded creature jumps remain approximately 7 studs. Flying attackers use low attacks and reachable recovery windows; they cannot permanently attack from unreachable heights. Non-hostile birds can flee rather than becoming required airborne combat targets.
- Physical cover blocks ordinary attacks. Water/shore creatures have explicit pursuit boundaries; they cannot attack through banks, floors, or dry terrain. Monster navigation must follow the new elevation/cave/bridge routes.
- Common fauna loot: meat, bone, fur/hide where appropriate. Mineral creatures drop the region's accessible common mineral instead of edible meat. Plant creatures drop ordinary local plants. Tiny non-hostile wildlife drops at most one common unit and no rare loot.
- Normal monsters can have one bounded signature-resource roll, but a resource's minimum region depth still applies. An introductory Moon Crawler cannot drop Moon Ore or Gravity Shards just because its species also appears in Gravity Well.
- Neutral wildlife supplies no combat objective credit or teamwork bonuses; normal class time still follows meaningful active participation. No per-hit XP or rewards from repeatedly loading a cleared creature.

### Required campaign milestones

Projects use cumulative world progress, not a one-visit timer. Stage costs below scale **1 + 0.35×(original crew size−1)**, rounded up per ingredient. Gear costs remain per-player. Campaign recipes/schematics cannot disappear because the wrong player picked up a quest item.

| Completed tier | Milestone | Required work and encounter | Reward |
| --- | --- | --- | --- |
| 1 | Field Relay | Recover antenna at either introductory biome landmark; contribute Plank ×12, Iron Bar ×4, Cloth ×4; survive a 60s small defense | Tier-2 certification, basic station diagrams |
| 2 | Bog King | Locate introductory Marsh den, clear two small rooms, defeat boss | Tier-3 certification; guaranteed medical/weapon schematic choice |
| 3 | Old Forge | Restore cooling in Tundra B and collect a focusing crystal in Crystal Basin B; contribute Steel Bar ×12, Black Glass ×8, Glass ×6; defend forge for 90s | Tier-4 certification; first enchanting choice is granted after the first restored subsystem |
| 4 | Fallen Star | Locate Meteor Crater C crater instrument, open encounter with Meteor Bar ×8 and Aurora Stone ×4; defeat boss | Tier-5 certification, World Dial schematic |
| 5 | Weather Tower | Recover three calibrated instruments from different eligible C-region landmarks; contribute Storm Bar ×12, Gears ×8, Storm Cloth ×6; 120s defense | Tier-6 certification and regional depth-D access |
| 6 | Ironback | Locate Badlands D mine arena; use visible machinery to expose armor, then defeat boss | Tier-7 certification, deep equipment diagrams |
| 7 | Deep Archive | Complete an optional-equipment-accessible route through Flooded Ruins D; recover three records, repair air system with Deep Metal ×10, Pressure Glass ×8, Sail Cloth ×6 | Tier-8 certification and regional depth-E access |
| 8 | Moon Warden | Find Moon Surface E; prepare the arena, defeat three-phase boss | Campaign completion record, final schematic choice, endless endurance option |

**Bootstrap correction:** the tier-7 Archive project cannot require grade-7 Deep Metal if its own completion were to unlock grade 7. Here grade 7 is already unlocked by Ironback; the project unlocks grade 8. Apply this same preceding-tier check to every gate.

### Boss behavior

- Bog King: tongue pull with a dodge window, lily-platform leap, and a few clearly announced leeches. No unavoidable permanent poison pool covering the whole room.
- Fallen Star: sweeping arm, falling debris with marked safe lanes, and an exposed core after a committed slam.
- Ironback: armored frontal attacks; players activate reachable side machinery to expose a weak side. No class-specific interaction required.
- Moon Warden: grounded melee phase, controlled low-gravity platform phase with safe routes, final combined attack pattern. Normal movement can complete the mandatory route; traversal accessories provide optional advantages.
- Boss HP is 135D × **(1 + 0.65×(participants−1))**. Attack damage is 1.5× standard tier damage, with at least 0.8s windup for high-damage moves. Target 5–8 minutes of active combat, including evasive downtime; this must be measured later.
- Register participants once per encounter. Late entries increase remaining/max HP by only their additional budget; repeat entry never does. Leaving does not lower HP. Ordinary project defenses scale counts rather than silently multiplying monster damage.
- Introductory boss rewards guarantee the progression item. Optional repeated bosses supply crafting materials and schematics, with a once-per-encounter reward receipt.
- Deep E elite sites drop **3 + participant count** matching trophy units for the whole group, not that amount separately for every player. High-end crafting batches should be affordable with deliberate successful expeditions, not dozens of identical random visits.
- Full-team wipe evaluates all living crew across surface and interiors. A dungeon-only wipe does not delete the world if somebody remains alive elsewhere.

### Interior lifetime and saving

- Entrances create a world-owned interior instance in a separate generation domain of the same survival server. Surface terrain clearing cannot touch it.
- Preserve occupied interiors across surface shifts. Mark an active crew entrance/return route from camp so outside teammates can assist rather than losing access when the original landmark disappears.
- Exiting returns to a safe location in the current surface layout, never the removed entrance coordinates.
- If everyone leaves an unfinished interior, keep its durable progress but unload its physical content. Re-entry must not refill looted containers or reset claimed rewards. A reset encounter, when explicitly offered, uses a new encounter identity and new cost; it is not a save exploit.
- Save boss phase, health, participating roster, cleared rooms, loot claims, and active objective state. Offline time pauses encounters and environmental timers.

## 18. Events and objectives

Events need a visible activity or terrain interaction, not just an unexplained global stat multiplier. Preview what changed and why participating is useful.

### Surface event catalog

| Event | Available from | Gameplay / counterplay | Reward |
| --- | --- | --- | --- |
| Fresh Growth | Tier 1 | Temporary new common plant clusters in a marked region; no rare-node duplication | Food, herbs, fibers |
| Supply Signal | Tier 1 | Follow a visible signal to a small cache; no forced combat in the first two visits | Starter supplies, repair materials |
| Lost Explorer | Tier 1 | Find an injured NPC and escort along generated safe routes | Medicine and shared objective Marks |
| Animal Migration | Tier 2 | Visible fauna group crosses a region; hunt or avoid | Meat, hides, bone |
| Buried Cache | Tier 2; Desert | Break marked soft rock/sandstone to reveal a contained chest | Metal, glass, schematic chance |
| Rising Water | Tier 2; coast/swamp/archive | Temporarily floods marked low ground; raised routes remain | Exposed cache when water recedes |
| Whiteout | Tier 3; Tundra | Short visibility/cold event with lit shelter locations and recovery windows | Frost materials at sheltered event sites |
| Spore Bloom | Tier 3; swamp/mycelium | Visible spore vents activate in pulses; close vents or skirt them | Medicine ingredients, clean-air schematic chance |
| Falling Stars | Tier 4; Meteor Crater | Marked impact zones; impacts leave mineable deposits afterward | Meteor Ore and Impact Glass; no free final cores |
| Heat Surge | Tier 3; Dunes/Volcanic Plains | Heat rises after warning; shade and cooling supplies counter it | Sunstone/Black Glass near cooled vents |
| Crystal Echo | Tier 4; Crystal Basin | Repeat a short, readable crystal-light sequence; solo-compatible | Dust and enchanting discovery |
| Aurora Shift | Tier 4; Northern Valley | Alternating warm/cold pockets with a stable neutral route | Aurora Stone and thermal discoveries |
| Thunderfront | Tier 5; Highlands | Telegraph strikes and use grounding rocks to reach charged deposits | Storm materials |
| Root Outbreak | Tier 5; Mushroom Forest/Badlands | Clear connected root nodes while avoiding pulsed attacks | Living Root, advanced medicine |
| Broken Crossing | Tier 5; Rainforest/Coast | Supply materials to a temporary bridge; optional route opens | Traversal discoveries and supply cache |
| Archive Alarm | Tier 6; Flooded Ruins | Patrols activate around a visible terminal; shut it down or leave | Old Gear, Pressure Glass, survey discoveries |
| Deep Rumbling | Tier 6; Caverns | Avoid marked falling-rock zones; reopen a short blocked passage | Light Ore, Echo Shell |
| Gravity Drift | Tier 7; Moon Surface | Local low-gravity zone with clearly marked boundary and return path | Moon Ore and gravity discoveries |
| Hunting Party | Tier 4+ | A marked elite group enters the current region; optional engagement | Tier-appropriate materials and schematic chance |
| Camp Warning | Tier 3+ | Announced approaching group; defend, close routes, or intercept | Shared objective reward; buildings are not demolished |

### Cadence and limits

- Minor opportunity/event every 180–300 active seconds; major event every 10–15 active minutes once eligible. At most one minor and one major; do not stack a major damage event with a required boss encounter involving the entire living crew.
- Before tier 3, opportunity events outnumber hostile events at least 2:1. Later use approximately 1:1. Do not make every 300–500-second visit a compulsory crisis.
- Harmful events give at least 15 seconds of visible warning, even without crafted prediction gear. Prediction adds notice, not the only way to avoid unavoidable damage.
- Surface events end at a shift. Durable project progress and occupied interior encounters persist. Temporary event drops remain normal saved inventory after collection.
- Optional event failure loses its opportunity reward; it does not permanently raise threat, remove campaign unlocks, or delete camp resources.
- Reusable objective templates: repair, recover, escort, defend, clear, survey, and environmental puzzle. Use stable objective IDs and receipt-backed completion to prevent reward replay after save/restore.
- First-time stage projects/bosses award a proposed 30 Marks per player; optional objectives 10–20; teamwork milestones 5–10 with anti-repeat limits. Combined with existing 240 survival Marks/hour, target approximately 300/hour rather than multiplying income by every spawned enemy. Class XP remains active time only.

## 19. Classes, rewards, and player experience

### Existing permanent classes stay in place

| Class / unlock Marks | Role retained | Level-3 ability retained |
| --- | --- | --- |
| Generalist / free | General harvesting and food efficiency | Second Wind |
| Gatherer / 400 | Resource breaking and hand gathering | Harvest Rhythm |
| Builder / 500 | Structural material efficiency | Field Deployment: turret/shelter |
| Hunter / 500 | Monster damage | Marked Prey |
| Medic / 600 | Medical consumables and revival | Rally Pulse |
| Engineer / 800 | Crafting work rate | Overclock |
| Scout / 400 | Movement and sprint efficiency | Trail Scan |
| Cook / 400 | Food efficiency and restoration | Mess Call |
| Botanist / 600 | Plant gathering and bonus yields | Bloom Cycle |
| Prospector / 600 | Mineral power and bonus yields | Vein Sense |
| Warden / 600 | HP and monster damage resistance | Hold the Line |
| Climatologist / 800 | Environmental buildup/recovery | Shelter Field |

- Purchased levels 2/3/4/5 still require **1/4/12/24 active class hours** and **300/900/2,400/3,600 Marks**. XP is cumulative and not consumed. Existing exact passives/ability values remain the reference in `ClassConfig.lua` and `class-progression.md` unless a separate refinement explicitly changes them.
- Do not turn campaign hours, monster kills, recipe discovery, or automatic machines into extra class XP sources. Preserve the 120-second meaningful-activity rule and dead/loading/offline exclusions.
- New-world starter-kit substitutions preserve quantity and the approved item roles: Stone Hatchet→Stone Axe; Sandite Pickaxe→Steel Pickaxe; Sandite Blade→Steel Sword; Mire Sickle→Garden Sickle; Reed Sunwrap→Sun Vest; Desert Cloak→Desert Coat; Antitoxin Tonic→Antidote; Forest Wood/Stone→Wood/Stone; Reed Fiber→Fiber; Moss Bloom→Healing Herb; Forest Plank→Plank; Spring Water→Water; Brown Mushroom→Mushroom; Sap Resin→Resin.
- Unchanged clear item names retain their roles. Kits grant once at world creation. Chest armor starts equipped; no automatic full four-piece set is added to a class kit. Level 5 still supplies at most two individual midgame items, with tier 2 the starter-kit ceiling.
- **Balance issue for refinement:** existing Builder turret damage 6/8/10 becomes irrelevant against the new curve. Proposed new-world rule: multiply its approved damage values by the campaign weapon multiplier at deployment; preserve class level, duration, range, and cooldown. Scale temporary deployment HP by the standard monster-damage multiplier. Legacy values remain unchanged. This is a proposed class integration change, not previously approved.
- Fixed class heals remain meaningful because base player HP stays 100. Hunter marks, Warden reduction, Scout movement, and class harvesting bonuses preserve their established caps.

### UI and discoverability

- Journal home shows current campaign milestone, current biome maturity, known region depths, next useful station, and preparation advice. Do not reveal the hidden shift countdown without the required instrument.
- Every item tooltip shows its real damage/defense, grade, durability, enchantments, use, source or recipe, and equipped comparison. Use concise labels rather than unexplained stat abbreviations.
- Armor page shows four pieces, four accessories, active set bonuses, and total effective protections. Failed equip/upgrade actions explain the exact issue immediately.
- Enchanting and repair use one detail page with a preview of costs and before/after stats, not nested scrolling panels.
- Surface HUD stays compact. Mobile keeps minimap top right, top controls next to Roblox controls, swipeable vitals/biome card, semi-transparent action icons, and larger readable menus.
- Controls remain context-aware: Q drops a hovered inventory item in inventory, otherwise dodges; Control+Q drops stack. Right click handles inventory stack splitting inside inventory, weapon special with a weapon equipped, or placement with a buildable equipped.
- Touch inventory/chest transfer stays a tap action; dragging supports placement/drop/trash as appropriate. UI interaction never triggers a combat action behind the menu.
- Results show campaign tier/milestone, time, visited biomes, class XP earned, and rewards. Existing saved-world names/party readiness/class display behavior remains.

## 20. Overhaul saves and technical integration

### Overhaul-only storage (approved reset)

- The user explicitly superseded legacy preservation: delete all old worlds/player data and remove their compatibility code.
- The only supported rules and content versions are **GameplayRulesVersion 2 / ContentRelease 2**, including all sixteen biomes and all eight campaign tiers.
- Retire the seven `_v1` data stores and the old session namespace. All new profile, archive, manifest, session, snapshot, assignment, and reservation writes use the isolated `_Overhaul_20260912` namespace.
- Old active entries were explicitly removed once; this is not a reset on every server startup. New overhaul worlds and new permanent class progression persist normally.
- Do not import old inventory, class time, currency, schematics, or world progress. Unknown rules are rejected rather than migrated or silently converted.

### Persistent gameplay state

Record, at minimum:

- Campaign tier, certification/milestone progress, pressure elapsed time, endurance state, claimed milestone rewards.
- Each biome's qualified-visit count; current committed visit serial, elapsed qualified time, already-counted flag, maturity, generated region selections, and visit seed.
- Terrain generator version and current-layout seed; deterministic object identifiers; harvested nodes, regrowth usage, moved objects, looted containers, and discovered map cells.
- World schematic discoveries, enchanting levels learned, active objectives, dungeon states, participants, and claimed encounter rewards.
- Station grade, owned inventories, fuel (including fractional cooking burn time), accumulated batch work, recipe IDs, selected seasonings, output variants, and unprocessed-input escrow.
- Meal recipe/seasoning identity and player food/drink buff identity with remaining active duration; save recipe version so an already-queued job cannot change cost/output after a content update.
- Individual gear identity, definition, grade, durability, armor family, enchantments, installed instrument modules, and transferable scroll data. Equipment is non-stackable; fungible raw resources remain simple stacks.
- Four armor slots and four accessories, extra pack capacity, active player inventory, ordinary vitals, pinned class/level, and existing class cooldown/regrowth persistence.

All inventory paths must preserve item-instance data: equip/swap, split, chest transfer, drops, crafting/reforging, salvage, death/revival, creative trash, save/restore, and admin grants. A definition ID alone is no longer enough to identify a specific enchanted item.

### Service/data boundaries

- Introduce shared catalog definitions for equipment families, resource classes, recipes, enchantments, biome depths, terrain features, and milestone eligibility. UI and server validation consume the same definitions.
- One overhaul catalog and service set serves every new world. Reject retired rules at storage/admission boundaries.
- Biome schedule commits one visit identity. Generation, weather maturity, discoveries, and visit credit use that identity, with idempotent retry behavior.
- Terrain returns authoritative ground/slope/water/region metadata to placement, creature spawning, survival, harvesting, scanning, and maps. No independent guessed ground-height formulas in those services.
- Upgrade, enchant, extract, repair, and batch-start actions atomically validate source item identity, materials, station reach/grade, life state, cooldown where relevant, and world rules before committing. Replayed requests cannot duplicate output.
- Network responses expose pending/success/error and authoritative changed item state. Clients can animate immediately but must not display a completed upgrade before the server commits it.
- World snapshots remain the authority for resume. Reconstruct deterministic terrain plus deltas rather than storing a full voxel copy every save. Generator versions must remain available for active saved layouts.
- Preserve original crew/save-slot/party/reward receipt behavior. Full-team death still removes survival save copies; creative recovery rules remain separate.

## 21. Staged delivery and later acceptance scenarios

### Approved implementation sequence

1. **Refine this document.** Agree on the catalog, campaign gates, difficulty/repair burden, dungeon access, and class-scaling exceptions. Freeze a numbered design revision.
2. **Versioning and item foundation.** Rules selection, individual gear data, four armor/four accessory slots, safe inventory/chest/drop/save handling. Keep existing worlds functional.
3. **Terrain prototype for Woodlands and Tundra.** Camp preservation, real elevations/water/caves, slope-aware placement, fresh visit seeds, safe player/downed-body shifts, shared map layers. Extend the same system to all current eight biomes after this foundation is accepted.
4. **Progression and combat foundation.** Strong gear curve, resource grades, functional station/recipe chains, durability/repair, dodge/specials, representative enemy behaviors, and regional visit gating.
5. **Complete the current eight-biome release.** Tier 1–4 campaign, 40 authored sub-biome definitions with later depths appropriately gated, first two bosses/projects, early world controls, basic enchanting. Do not create dependencies on unimplemented future resources.
6. **Add the eight future biomes.** Enable all main biomes by tier 4, campaign tiers 5–8, their 40 regional definitions, full dungeons/events/gear/enchanting, and safe expansion of existing version-2 worlds.
7. **Balance and presentation pass.** Run only user-authorized checks. Tune measured progression pace, hazards, supplies, group encounters, mobile performance, and UI before publishing.

**First-release recipe substitutions:** until future biomes are enabled, optional future-biome accessories/sets are not exposed. Tier 1–4 mandatory recipes and milestones already use the current eight biomes. Any optional tier-4 recipe referencing a future resource stays unavailable with a clear future-content label; it must not block campaign progression or the World Dial. Stage-one worlds stop at the completed Fallen Star milestone with tier-5 certification recorded but content locked; enabling the expansion activates tier 5 without repeating the fight.

### Later acceptance scenarios — document only, do not run/create tests now

- Eight-tier damage curve and fair matching-tier hit counts; starter gear underperforms strongly in mid/late game; mobile assistance remains bounded.
- No recipe/station/mining-grade cycle; first cold/heat/toxin/wetness preparation exists before its hazard; first visits provide enough time to learn and gather.
- All 16 implemented main biomes are eligible by tier 4, with random selection; all 80 region definitions obey depth/visit gates and have distinct geography/activity.
- At least 64 ordinary creature definitions exist, with four per biome and an explicit encounter profile for each of the 80 sub-biomes. Habitat filtering, species weights, group limits, mixed encounters, active budgets, and persistent encounter IDs behave as specified; expanded variety does not multiply hostile density.
- A two-minute visit counts exactly once across normal shifts, controlled shifts, disconnects, loading, retries, and saves. Current-region eligibility cannot change midway through generation.
- Natural durations stay within 300–500 seconds and preserve the sampled timer across save/restore. Field Clock remains required to see the actual countdown; timing devices modify the existing schedule rather than rerolling it.
- Camp construction/clearance uses a 200-stud radius. Unmodified walk/sprint speeds are 20/30 outside and 40/60 inside; crossing the boundary or restoring cannot stack the multiplier or cancel sprint intent.
- Saved active terrain restores identically; returning visits differ; chunk borders match; camp remains supported; players/downed bodies are placed safely; occupied interiors survive surface shifts.
- No floating/buried trees, stations, natural structures, chests, or inaccessible interaction points on slopes or multi-level terrain.
- Weapon specials, dodge, block-by-geometry behavior, 7-stud grounded jumps, and 30-stud HP labels behave correctly for solo and six-player encounters.
- Four armor pieces and four accessories preserve per-instance data; set bonuses, mixed grades, breakage, repair, reforging, and pack removal behave as described.
- Enchantment discovery, individual rank/grade caps, conditional triggers, saved reserves, once-per-visit allowances, incompatibilities, extraction, transfer, costs, and duplicate/retry protection; no copying or reset from save/chest/equip/creative paths. One-rank effects cannot expose nonexistent upgrades.
- Station batches preserve fuel/work/input/output through shutdown and salvage; ordinary player crafts cancel/refund on departure as approved. Cooking is an explicitly separate shared-station job.
- All 16 food/drink recipes have fixed inputs and only Campfire/Stove/Oven requirements; no ingredient substitutions or removed-station dependency. Seasoning consumes one charge per eligible serving, preserves stack identity, obeys refresh/replacement/caps, and cannot reset across saves. Cancellation, full output, fuel exhaustion, owner departure, and queue retries cannot lose or duplicate ingredients/output. Mobile cooking requires neither nested scrolling nor timing actions.
- Required milestones have accessible entrances, guaranteed progression rewards, and solo-compatible mechanics. Missing an optional event never permanently raises campaign difficulty.
- Retired world/profile records are absent from active storage and cannot enter the new rules. New overhaul worlds resume without losing progress; class kits are granted once and contain no late-game gear; creative never earns rewards.
- All menu/input interactions work on phone and PC; camera unlock, map layers, tooltip size, scrolling, inventory transfers, item drop/split/trash, and button feedback remain usable.
- Measure organic solo and crew campaign completion, resource visit variance, durability consumption, enchantment grind, and performance. The 10–15-hour and 300 Marks/hour goals are targets until measured.
- Keep already deferred real-player cross-lobby merging/travel/resume checks explicitly pending until a crew session is arranged.

### Delivery policy

This document authorizes no implementation, model purchase, test creation, test execution, or Roblox publishing. Implementation is now authorized: edit source through the repository, deliver via Rojo to both places, and push completed implementation checkpoints. The user publishes Roblox places.

## 22. Refinement checklist

The confirmed direction is stable; the following proposals should be refined with the user before code changes:

1. **Catalog readability and volume:** the first draft has 24 main weapons, 16 dedicated axe/pickaxe tools plus sickles/multitool, 16 armor families with four pieces each, and 27 accessory choices. Decide which names/branches feel memorable and remove anything redundant.
2. **Reforging versus replacement:** proposed armor reforging keeps favorite biome sets viable; decide whether the same approach is wanted for favorite weapon appearances without adding another stat-upgrade system.
3. **Repair burden:** capacities and costs are unmeasured. Decide whether repairs should happen roughly once per long expedition or more often, especially for solo players.
4. **RNG and rare resources:** all rare depths remain probabilistic, as requested. With the new 300–500s schedule, mean natural visit duration is 400s instead of 300s, reducing average natural arrivals from 12 to 9 per active hour before generation pauses. Tune weights/yields against the unchanged 10–15-hour target without introducing an unapproved guaranteed rotation.
5. **Final-tier trophy costs:** grade-8 material, set awakening, and grade-8 enchantment ranks compete for the same exploration rewards. Keep mandatory gear achievable; reserve long trophy collections for optional specialization.
6. **Creature and enchantment identity:** review all 64 ordinary species, the 80 encounter profiles, and the 18 conditional enchantments with individual caps. Confirm the patterns feel distinct without excessive trigger/cooldown bookkeeping.
7. **Campaign project/boss details:** milestone names, room sequences, contribution counts, and exact boss mechanics are proposals. Confirm the desired amount of puzzles/escorting versus combat.
8. **Class integration:** approve or revise the explicit Builder temporary-deployment scaling proposal and Cook level-4 Drying Rack→Stove substitution before altering the existing class design.
9. **Armor/enchantment exceptions:** review the strong first-desert Sun Vest, early Warm Scarf allowance, four-piece protection caps, and optional awakening bonuses for clarity.
10. **Survival pressure:** test authorization comes later; first agree on whether the proposed bounded pressure, post-campaign endurance, and food/repair loops sound enjoyable.
11. **Cooking balance:** the fixed-recipe/optional-seasoning loop and three stations are confirmed. Review the proposed 16 dishes/drinks, 16 biome seasonings, four-minute single seasoning buff, fuel costs, and queue sizes. No extra cooking stations or ingredient substitution system.
12. **Art workload:** 80 region definitions need reusable terrain/landmark families and varied arrangements, not 80 entirely unrelated asset sets. Final original models remain a separate stage.

### Revision log

- **0.1:** Consolidated user decisions; replaced the earlier plan that introduced new main biomes after tier 4; added all 80 region concepts, fresh terrain generation, repeated-visit hazards, the stronger equipment ladder, complete draft item systems, encounters/events, and versioned-world rollout. Values remain proposals for collaborative refinement.

- **0.2:** Replaced ornate main-biome names with grounded display names and simplified three region names. User changed camp radius to 200 studs (400-stud diameter), base walk/sprint to 20/30 studs per second, camp ground movement to 2×, and natural shift durations to a random 300–500 seconds. These remain draft-document changes only.

- **0.3:** Replaced the generic enchantment ladder with 18 EcoShift-specific conditional effects and independent one-to-five-level caps, grade-based pricing, and persistent trigger/reserve rules. Expanded the ordinary creature roster to 64 species and specified species weights, group sizes, and mixed encounters for all 80 sub-biomes without increasing the hostile population cap. All changes are draft documentation only.

- **0.4:** Expanded cooking with user-confirmed automatic queues, fixed recipes, optional biome seasonings including magical buffs, and only Campfire/Stove/Oven. Added 16 food/drink recipes, explicit spice sources/effects, fuel and persistence rules, and a proposed Cook kit substitution. Removed the obsolete new-world Drying Rack role and clarified the Trail hunger bonus. Documentation only; no implementation or tests.
