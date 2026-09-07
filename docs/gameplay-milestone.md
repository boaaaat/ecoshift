# Gameplay and field-kit milestone

## Implemented

- Rojo entrypoints are executable Scripts/LocalScripts; one bootstrap creates runtime folders and remotes before service startup. Authored assets remain compatible.
- Normal biome duration is five minutes. Structures, their grid occupancy, and storage survive shifts. Old enemies are cleared. Chunk generation cancels stale work when shifts overlap.
- Monsters receive a fixed level at spawn. Health and damage scale with level; templates remain unscaled. Active enemy counts are capped.
- Current weather affects heat/cold, toxin, and wetness. Armor supplies separate protection channels. Local weather presentation transitions smoothly.
- A fallen player leaves a ragdoll and can spectate a teammate. A living teammate holding a Revival Kit can revive them through a three-second prompt at 25% health. A full-team wipe ends the run with team statistics.
- FieldClock reveals the countdown. BiomePredictor retains it and adds the next biome; WeatherPredictor retains both and adds the next weather. Forecasts share the actual server schedule.
- Reusable stabilizer, trigger, and selector devices use majority ballots, fuel, cooldowns, and per-shift limits. Failed ballots spend nothing. Selection/advancement respect biome eligibility.
- Hand-crafted Stone Spear and Revival Kit, a reachable Field Clock recipe, repaired station dependencies, and missing raw-resource sources support progression.
- Shared animated field-kit styling covers HUD, vitals, inventory, crafting, building, stations, storage, map, survey/voting, spectating, and results.
- Inventory, pickup, placement, combat, armor attachment, tool respawn, and crafting cancellation fixes address invalid requests and item-loss/duplication paths.
- Temporary free Creator Store geometry supplies missing resource, tool, creature, and station visuals. Imported scripts are excluded; sources are recorded separately.

## Gameplay checks performed in Studio

The user requested gameplay testing. These were live Studio interactions and a temporary two-client diagnostic session, not a permanent automated test suite.

- Normal resource prompt gathering produced inventory materials. Cursor-aimed harvesting reduced node health and produced a drop; the corrected cursor ray hits the visible target.
- Crafted planks, crafted a Workbench through the crafting UI, placed it, and confirmed it remained after a biome shift.
- An equipped Stone Spear hit a target for 18 damage. A level-four prototype wolf received 125.8 maximum health from its 85 baseline.
- Equipping Desert Cloak applied 70% heat and 10% cold protection, plus 12 armor. This checks equipment wiring, not long-run survival balance.
- No-device payloads hid countdown and forecasts. FieldClock revealed only timing; the top predictor retained timing and both forecasts.
- A solo stabilizer vote added 60 seconds, consumed the listed fuel once, retained the device, and rejected a second use during cooldown.
- Two actual Studio clients required both votes. Rejection consumed no fuel; approval extended the biome and consumed fuel once.
- In that two-client session, a fallen player produced a ragdoll and their camera followed the living teammate. Revival without a kit was rejected. Client prompt-holding revived them at 25% health and consumed exactly one kit.
- A full-team wipe produced results for both players. HUD, survey, crafting, and results were also visually inspected through Studio MCP.
- Repeated startup/shift sessions showed no game-script errors in the inspected output. Studio/plugin diagnostic warnings were separate from game errors.
- The final helper-free session confirmed a single weather Atmosphere and the corrected downed-health/results display. `scripts/rojo-build.ps1` successfully built `build/Ecoshift.rbxl`; both launch scripts now invoke Aftman's Rojo shim directly.

All temporary diagnostic Scripts, LocalScripts, and grant/remoting helpers were removed before committing. No computer-use tools were needed; changes synced through Rojo.

## Follow-up storage and catalog review

The follow-up storage check opened a crafted chest with the normal E prompt, deposited six wood, shifted biomes, and recovered all six. Fractional slot moves and NaN quantities were rejected without changing either inventory. Death closed the active chest session. Heat and Cold Tonics were consumed through the normal inventory remote and applied only their corresponding 35% resistance channel. These fixes also keep crafted storage empty when a default world loot table exists. The temporary setup/readback helper was removed afterward.

A static catalog audit of the initial milestone found valid canonical IDs and sources for its 84 recipes. The expanded catalog now has 89 reachable recipes, 51 gatherable material IDs, and all 12 station types reachable across eight biomes. This establishes dependency reachability, not balanced quantities or run duration.

## Eight playable biomes and the expanded roadmap

- The approved names are now displayed in the HUD. Frostfall, Cinder Rift, and Prism Barrens join random progression alongside the new Aurora Vale and Starfall Crater. Eligibility begins at 0/5/10/20/30/40/45/55 minutes; later biome weights rise over time while earlier biomes retain a revisit weight floor.
- Aurora Vale alternates Dawn Surge and Polar Night every minute. Starfall Crater adds meteor materials and heat/dust weather. Aurora Stag and Comet Crawler have different movement, damage, and recovery settings, plus guaranteed signature drops. They use prototype Wolf AI and temporary models.
- Thirteen new item IDs and five new recipes add Aurora Lens, Aurora Mantle, Meteor Alloy, Meteor Pike, and Starforged Plate. The final selector and adaptive suit require both new biomes. Earlier armor and weapon recipes now retain more cross-biome inputs; early forging and optics no longer depend on later-biome materials.
- Monster levels advance every 7.5 minutes. The revised target is powerful world-control gear at 60–90 minutes; this is a balance target, not a guaranteed completion time.
- Eight future biome concepts complete the 16-biome plan. They are explicitly unimplemented and excluded from generation, forecasts, voting, and recipe dependencies.

Live Studio checks used accelerated elapsed time and supplied crafting ingredients to inspect late progression. Aurora resources generated, normal prompt gathering yielded Aurora Fiber, and consecutive weather cycles changed temperature without changing the scheduled destination. Starfall generated Meteor Iron, Impact Glass, and Cosmic Dust; old Aurora monsters disappeared, and a level-eight Comet Crawler had 270.3 maximum health. Crafting Biome Predictor consumed Field Clock while retaining the countdown and adding only the biome forecast. The expanded Biome Selector recipe completed at a placed Survey Bench. These checks do not replace a full-length balance playthrough.

A request for Starfall before its unlock gate was rejected without spending fuel. After unlocking, selection plus the trigger's 15-second transition arrived in Aurora with exactly the forecast weather. Both fuel costs were charged once, and both devices remained. Frostfall, Cinder Rift, and Prism Barrens each generated all seven configured material IDs; the placed Survey Bench survived those shifts.

The longer session exposed a HUD event-label error: Lua's `gsub` returned a second value that was incorrectly passed into `table.insert`. The formatting helper now returns only the text. A fresh helper-free session displayed an Aurora Surge announcement correctly and showed no game-script errors in the inspected output. The final Rojo build succeeded.

## Remaining design and validation work

- Fuel quantities, cooldowns, monster scaling, armor resistance, and recipes are initial tunable values. A full-length cooperative balance playthrough remains necessary.
- The content plan describes intended differentiated monster attacks. Most species still share the existing Wolf-style AI; the attack-pattern proposals remain future work. The cross-biome armor revisions are implemented.
- Some loose items still use fallback pickup geometry; armor visuals and all final models remain for the later art pass. Stations use generic temporary geometry.
- Live lobby destination and replay flow have not been specified. The run ends with results; the existing development-only respawn is clearly labeled for Studio and does not reset a finished run.
- Touch/gamepad play and small-screen layouts need device-specific playtesting. UI scales and clickable controls are present, but desktop Studio is the environment checked here.
