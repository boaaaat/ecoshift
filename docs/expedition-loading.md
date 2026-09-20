# Expedition loading screen

Both place projects include `src/ReplicatedFirst`. `ExpeditionLoading.client.lua`
mounts the destination screen before removing Roblox's loading screen. In the
lobby it registers a separate static teleport screen before departure, then shows
the animated version when `ExpeditionTravelState` is published. The destination
creates its own controller and removes the arriving teleport GUI.

The screen uses native Roblox UI and a small, locally built ViewportFrame forest
diorama. No uploaded image, mesh, audio, or external asset is required. Brass
compass markings, a rotating shift crystal, segmented amber/sage meters, and dark
field-instrument colors match the expedition art. Short screens use a compact
layout. The saved ReducedMotion preference disables continuous animation.

## Progress contract

`LoadingProgress` publishes public attributes, without any reservation credentials
or saved player data. Percentages are weighted work milestones, not elapsed-time
estimates or a count of the entire streaming world.

| Meter | Source | Completion |
| --- | --- | --- |
| World | Admission, snapshot staging, completed service initializations, nine generated camp chunks, world activation | `WorldLoadProgress = 1` after `CompleteWorldRestore` |
| Explorer | Profile readiness and `WorldRestoreStage` milestones (90%); client data, camera/character, and arrival streaming (10%) | `WorldPlayerReady`, client arrival ready, and boot ready |

During transit, the meters show `--` because the lobby does not have the destination
server's live progress. Roblox runs no scripts inside the teleport GUI; animation
and live progress resume in the destination. See the official
[custom teleport screen documentation](https://create.roblox.com/docs/projects/teleport#create-custom-teleport-screens).

The overlay remains through saved-world restoration, including saved downed
players, and supports late rejoining. Generation retry and boot failure messages
replace silent waiting. Failed departures offer a way to show the lobby while the
existing server retry process continues. Arrival streaming is bounded; subsequent
terrain continues using the existing streaming system.

The controller releases its movement input binding and destroys its rendering
connections when the arrival screen finishes. `ClientSettings.CanInput` also
respects the local `PlayerGui.ExpeditionLoading` attribute. Ordinary biome shifts
and later respawns do not reopen the initial-arrival screen.

Implementation was reviewed statically. No tests or Studio play sessions were run.
