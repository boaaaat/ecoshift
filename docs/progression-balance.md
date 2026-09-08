# Progression audit — September 7, 2026

Natural biome access is a substantial source of variation in the 60–90 minute equipment target. The user explicitly chose to retain fully random weighted shifts after reviewing this result. No biome weights, eligibility gates or recipes were changed by this audit.

## Natural visits

These are exact probabilities for the current five-minute schedule, starting in Forest, with no world-control devices, deaths or interrupted generation. They describe visits, not successful gathering, survival or completed crafting. Visiting a biome exactly at the reported deadline counts; its resources have not necessarily been collected yet.

| Elapsed time | Visited all eight | Still missing Starfall | Still missing Aurora | Still missing Mirefen |
| --- | ---: | ---: | ---: | ---: |
| 60 minutes | 13.71% | 57.74% | 33.01% | 5.27% |
| 75 minutes | 48.70% | 24.63% | 15.56% | 4.53% |
| 90 minutes | 73.47% | 10.22% | 7.16% | 3.97% |
| 120 minutes | 92.34% | 1.67% | 1.45% | 3.18% |
| 180 minutes | 97.58% | 0.04% | 0.05% | 2.26% |

Method: propagate probability through states `(current biome, visited bitmask)` at each 300-second transition. Start with `(Forest, Forest)` at probability 1. Exclude the current biome and any biome whose MinElapsed is greater than arrival time. Normalize each eligible destination's `max(0.4, Weight + TimeScaledWeight * elapsed / 900)` and accumulate the next states. This directly follows BiomeService:GetEligibleBiomes/_pickNext/_scheduleNext using the live Edit BiomeConfig values. It is a probability calculation, not a sample of gameplay sessions.

| Biome | Earliest minute | Base weight | Weight change per 15 minutes |
| --- | ---: | ---: | ---: |
| Verdant Reach | 0 | 1.0 | -0.10 |
| Sunscar Dunes | 5 | 1.0 | -0.05 |
| Mirefen | 10 | 1.0 | 0 |
| Frostfall | 20 | 1.1 | 0.55 |
| Cinder Rift | 30 | 1.0 | 0.65 |
| Prism Barrens | 40 | 1.1 | 0.85 |
| Aurora Vale | 45 | 1.1 | 0.75 |
| Starfall Crater | 55 | 1.2 | 0.85 |

## Required materials

Both BiomeSelector and AdaptiveSurvivalSuit still require all eight biomes through their recipe and station chains. Aurora caches can replace some tundra derivatives; Starfall caches can supply some crystal/volcanic glass. They do not replace the required PermafrostOre, AlloyDust, VoidResidue, biome trophies and meteor materials. The visit probabilities therefore bound natural progression opportunity, but cannot establish completion time.

Material estimates must retain processed leftovers: ForestPlank produces two planks per wood. Station access and station ingredients are separate costs. For example, crafting an upgraded station can consume an inventory Workbench/AdvancedWorkbench while requiring another already placed bench nearby.

## Enemy pressure and limits of this audit

Current configured waves have a 90-second initial grace period and a 40-second evaluation interval. Wave size starts from `floor(1 + threat + 0.5 * playerCount)`, then applies event and distance multipliers and a 1–12 clamp. Per-species caps, eligible spawn locations and the active monster cap can reduce actual spawns. Active monsters are limited to eight per player, capped at 42. These are configuration constraints, not measured encounter rates or a six-player difficulty result.

Monster levels remain fixed at spawn and use expedition elapsed time. SpawnService's optional time-scaled species weights now use that same saved expedition clock instead of module uptime. Existing configured species slopes are zero, so this clock correction does not rebalance today's species mix. An isolated nonzero-slope check verified fresh, resumed and paused elapsed-time inputs.

Still needed: organic gathering/crafting/combat sessions and the already deferred live crew travel/resume checks. No claim is made that a typical team currently completes world-control gear within 60–90 minutes.
