# Class progression implementation

The authoritative class definitions are in `src/ReplicatedStorage/Shared/ClassConfig.lua`: all 12 classes, all five kit tiers, passive values, unlock prices, upgrade prices, and ability values. Generalist is free. Abilities unlock at level 3. There are no class penalties.

| Upgrade | Total active time | Total XP | Field Marks spent for this upgrade |
| --- | --- | --- | --- |
| 2 | 1 hour | 60 | 300 |
| 3 | 4 hours | 240 | 900 |
| 4 | 12 hours | 720 | 2,400 |
| 5 | 24 hours | 1,440 | 3,600 |

Class XP is cumulative, never consumed, and separate from account XP. Only active living expedition time counts; 120 seconds without movement or successful player action pauses it. Automatic turret attacks do not count as player activity. Marks remain account-wide, with 7,200 total needed for upgrades plus the class unlock. Existing rewards yield 240 Marks/hour from survival alone, so the 24-hour currency target assumes objective/teamwork bonuses.

## Save and compatibility behavior

- Profiles migrate existing unlocked classes to level 1, preserving money and account progression. Historical class time is not inferred.
- Purchases are atomic and sequential. World/class cumulative time receipts prevent retry or saved-world replay from double-crediting XP.
- New worlds pin the selected class and purchased level. Existing worlds with no class level use level 1.
- Starter kits are granted once for a new world. Rejoining, revival, and resume preserve inventory rather than reissuing supplies.
- Offline time does not reduce class cooldowns. Temporary effects end on departure/death; Builder deployments and markers clear on biome shifts.
- Botanist regrowth is recorded in generated-object tombstones and survives chunk unloading/save restoration. Each plant can regrow once per shift across all Botanists.
- As with existing run rewards, an abrupt crash may lose time newer than the last durable world snapshot. A restored total below a previously paid watermark must catch up before new time is paid; it cannot duplicate rewards.

## Gameplay and controls

`G` / gamepad `Y` / the mobile class icon activates the class ability. If G is already bound, migration chooses a free fallback. Builder chooses turret or shelter and confirms a valid placement. The server checks the final target, range, life state, class level, cooldown, and footprint. Invalid actions do not consume cooldown.

Engineer increases crafting work rate, never discounts ingredients. Running crafts accumulate work so Overclock starts and stops without restarting progress. Identical temporary buffs use the strongest contribution. See ClassConfig and ClassEffects for bonus caps.

Scout and Prospector use server generation metadata for map markers, without activating extra chunks or spawning monsters. Normal streaming covers a three-chunk radius, larger than the maximum 200-stud scan. Discovery records are shared with the crew.

## Acceptance scenarios — pending user authorization

No automated tests, smoke tests, or gameplay sessions were created or run for this implementation.

1. Verify exact 1/4/12/24-hour eligibility, both purchase requirements, sequential upgrades, double-click protection, and failure feedback.
2. Verify active-time pause while idle, dead, loading, or in lobby; check partial-minute preservation and no duplicate grants after retry/resume.
3. Inspect all 60 kit combinations: Harvester slot 1, first class weapon/tool slot 2, armor equipped, inventory capacity, and at most two midgame items at level 5.
4. Verify saved class levels stay pinned; rejoining/revival cannot grant items or reset cooldowns. New Warden starts at its increased maximum HP; restored/revived Wardens receive no extra heal.
5. Verify all class passives, resource classifications, extra-drop rules, ability durations/ranges, stacking caps, and maximum-stat clamping.
6. Verify turret line of sight, damage attribution/loot, monster attacks on deployments, shared shelter health, player-only door interaction, and the five-second expiry warning.
7. Verify deployment outside camp, invalid footprint rejection, cancellation without cooldown, and cleanup on owner departure/death/shift.
8. Verify shared scans and marker expiry; a regrown plant cannot be regrown twice by another Botanist or after reload.
9. Verify Overclock changes progress smoothly on ongoing crafts; ingredients remain unchanged and cancelled crafts refund paid materials.
10. Verify mobile targeting, previews, scrolling, ability feedback, locked/cooldown states, crew class levels, results progression, and sprint continuity while menus are open.

Source delivery uses the two Rojo projects. Roblox publishing remains a separate user action.
