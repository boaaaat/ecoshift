# Item and world art validation — 2026-09-20

The user explicitly authorized tests and live Play checks for this pass.

| Check | Coverage | Result |
| --- | --- | --- |
| `scripts/check-item-presentation.luau` | 733 held inventory items; 44 direct gear factories; R6/R15; 8,868 pose samples; 189,545 assertions | Passed |
| `scripts/check-pick-head.luau` | 10 picks/universal tools; 970 continuity rays; 230 outside-profile probes after serialization | Passed |
| `scripts/check-cutting-edges.luau` | 8 sickles/swords/daggers; 582 continuity rays; 60 outline/hook-interior probes after serialization | Passed |
| `scripts/check-resource-art.luau` | 16 biomes, 80 region definitions, 63 distinct resource IDs, 93 resource/biome models, 66 armor pickups, 64,000 region plans | Passed |
| `scripts/check-resource-spawns.luau` | 192 biome/seed/tier/visit scenarios; 37,632 chunks; 481,875 candidates; 954 eligible-resource coverage checks | Passed |
| `scripts/check-world-art.luau` | 40 builds, 64 creatures, 66 armor displays, 264 intact/broken R6/R15 armor mounts; 8,751 parts; 38,697 assertions | Passed |
| Prefab initialization | 80 resource prefabs, 85 tool prefabs, 66 armor pickups | No missing models |
| Official Luau 0.739 compilation | All 222 `.lua`/`.luau` files in `src` and `scripts` | Passed |

The pose suite checks connected, massless/noncolliding tool assemblies, finite transforms, lead-hand grasp contact, support-hand shaft contact, idle head clearance, bow nock/string/arrow contact, sequential action samples, idle camera movement, and restoration after cancellation/destruction. It uses isolated rigs with joint transforms projected into geometry, rather than treating screenshots as exhaustive coverage.

Live Studio review used the player's actual R15 avatar for all 15 pose families. A fresh Play session confirmed the normal-inventory Harvester's new continuous head and forward forearm, mouse-triggered harvest motion, and right-hand bow draw/release/unequip cancellation. Full bow draw placed the right palm about 1.98 studs ahead of the torso; left hand-to-nock separation was 0.00025 studs. Release and cancellation both cleared charging and hid the arrow. The holding arm remains bent forward at idle while the empty left bow arm relaxes. Screenshots are saved under `docs/images/`. Resin, ore and rock surface reviews below belong to the preceding world-art pass.

New pose regressions require forward R15 forearms, palms at least half a forearm length ahead of the elbow, connected wrists, stable palm-to-grip rotation, and forward-facing mining heads. Bow approach leaves the string relaxed for .2 seconds, then validates hand contact. R6's already-forward rigid arm must reach at least 95% forward extension and complete 70% of its available extension before substantial string pull; R15 retains minimum forward-travel checks. These checks address earlier cases where connected geometry still produced an unattractive stance.

Failures found and fixed include oversized tool heads crossing the face at idle, supporting hands exceeding reach during spear/hammer attacks, randomly omitted resource-bearing regions, hidden sap and mineral details, obsolete prefab factory routes, and coastal kelp/salvage rejected by dry-ground spawn filtering. Coastal aquatic resources now allow stable seabed placement; dry resources still require dry land. Existing tier/visit gates remain enforced.

The preceding resource-validation Play session contained 206 Resin nodes among 2,132 generated woodland resource nodes, with no missing model pivots or runtime errors. This correction pass does not repeat the unchanged world-generation sweeps.

The generation sweep samples three seeds, tiers 1/8, and visits 0/4 for every biome; it does not prove every possible random world. Multiplayer network delivery, every avatar bundle, and performance benchmarks remain outside this pass. Tests do not publish assets or modify player inventories. Temporary Play models are removed when Play stops.
