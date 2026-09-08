# Survival guidance and personal settings

The expedition HUD's biome and conditions rows now open a survival field guide. It shows current combined biome/weather exposure, equipped armor and its resistance values, recommended armor and support supplies, and buttons into the existing crafting recipe guide. Forecasts only appear when already supplied by the server's instrument-gated state. All eight playable biomes and their 24 weather combinations are covered. Advice uses shared biome, weather, armor and recipe definitions; it does not alter damage, equipment or progression.

The three-step starting tutorial covers gathering, the hand-crafted Reed Sunwrap (6 Reed Fiber, 2 Moss Bloom, 2 Sap Resin), equipping armor, hunger, exposure and stamina. It describes Desert as an early possible shift. Players can skip, disable future starting tutorials, or replay from Settings. Startup waits for the character, world and profile; unavailable profiles use session defaults. It runs once per client expedition session, not on every respawn. The world continues during the tutorial.

Settings offers Gameplay, Graphics and Keybinds tabs. Preferences include appearance, starting tutorial, field notes, HUD navigation, hold/toggle sprint, effects quality, shadows, weather particles, post processing, reduced menu motion and field of view. Keyboard controls for Pack, Craft, Build, Map, Survey, Settings, Sprint and Salvage can be rebound. Movement, interaction, hotbar, chat, camera lock and spectator controls remain reserved; Shift is only available for sprint to preserve armor/transfer shortcuts. Conflicting assignments are rejected. HUD shortcuts and salvage hints follow changes; map and survey close hints use Escape.

Preferences apply locally immediately. Save preferences stores changes in the existing profile through a validated write-through operation. Reset defaults applies locally until saved. The tutorial's disable button saves directly. Failed or unavailable persistence retains local changes and provides retry status. Validation accepts only known settings and values, validates bindings against fresh stored state, and retains unrelated profile data. Clients retain edits made during a save and accept the server's authoritative result.

Graphics quality controls local weather particle density and disables shadows at Low; it is not Roblox's engine-wide quality slider. Other graphics controls adjust world shadows, post effects and camera field of view. Weather atmosphere and server hazards remain active. Existing touch menu buttons and gamepad map access remain available.

## Validation

- Both `default.project.json` and `lobby.project.json` Rojo builds passed.
- `scripts/check-survival-settings.luau`, executed with the installed Lune 0.10.4 binary, compiled 62 shared/client/profile scripts and passed settings migration, boolean preservation, invalid input and binding conflict checks.
- Every biome/weather pairing resolves advice; every recommended item and recipe exists. Desert baseline and heatwave exposure, Sunwrap resistance and its exact recipe were checked against real shared data.
- Actual ProfileService operations passed with a mock DataStore: preference writes and reload, stale-write handling, binding conflict rejection, replicated disabled values and preservation of currency/theme.
- Actual ClientSettings passed with mock remotes: local edits during save, failure/retry, timeout, unavailable profile, reset and keyboard capture.
- `git diff --check` passed.
- A full-source Lune compile initially encountered pre-existing `goto continue_enemy` syntax in `WorldGen/BiomeGenerator.lua` that this installed compiler does not accept. Targeted compilation covers all files changed here; the generator was not changed.
- No live Studio, visual layout, real DataStore, multiplayer or physical input validation is claimed. Computer Use was stopped and further checks used only command-line tools. Roblox publishing was not performed.

## Item descriptions

All 158 catalog items now expose short descriptions through ItemDatabase lookup and listing. Equipment and consumables describe implemented behavior; armor percentages come from SurvivalConfig and material-use examples come from actual recipe ingredients. Threat Meter, Resource Compass, Event Seismograph, Pathfinder Beacon and Hazard Analyzer are marked "Not active yet," as confirmed by the user. Stamina Rations describe their actual hunger restoration. No item balance or recipe was changed.

Descriptions appear directly in hand-crafting cards, workbench cards, recipe-book listings and the existing item detail view. Card heights account for wrapped descriptions and viewport scaling. Recipe-book search also matches description text. Command-line validation compiled 64 shared/client/profile scripts, checked nonempty descriptions of at most 160 characters for all 158 items through both database APIs, and passed both Rojo builds. Live visual/input validation remains unperformed at the user's request to avoid Computer Use.
