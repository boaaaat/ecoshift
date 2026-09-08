# World snapshot lifecycle

`Services/WorldSnapshotService.lua` is a server-only adapter. WorldSessionService owns admission, leases, autosave, shutdown and storage; clients never provide or select snapshot contents.

1. Require WorldSnapshotService **before any gameplay service**. Its PlayerRemoving listener captures inventory, stats, role, position and downed state before those services delete their player records. Keep Players.CharacterAutoLoads false.
2. After the world reservation and crew are verified, call `StageWorld(snapshotOrNil)` before Tier1. This stages the biome, seed/depletion map, clocks, match state and run tallies and marks saved players as restoring. The loading attribute pauses simulation. Assign a new run's trusted roster classes with `RoleService:ApplyRunRole(player, roleId)`; resumed classes come from the snapshot and do not modify permanent profile selections.
3. Initialize Tier1 and Tier2 (including EventEffectsService), then call `RestoreWorld()`. This restores player buildings, grid occupancy, chest inventories and frozen ground drops and stages event/objective/threat state.
4. Initialize Tier3. Wait for `workspace.GeneratedWorld:GetAttribute("Generated") == true`, then call `CompleteWorldRestore()`. This restores global enemies after the generator's enemy cleanup, releases drops only after terrain exists, rebases timers and activates restored runtime hooks. Offline time and loading do not consume the saved biome timer.
5. Load each character, await its Humanoid, and call `RestorePlayer(player)` **for fresh players too**. Saved restoration applies stats, inventory/armor, transform, wetness and remaining tonic durations, then reconstructs a downed body if needed. It never calls KillPlayer, spills inventory again or increments death counts. New-player starter inventory is initialized even when their PlayerAdded occurred before service startup. `WorldPlayerLoading` prevents an accidental wipe while teammate characters load sequentially.
6. Call `Capture()` (alias `CaptureWorld()`) for a JSON-safe payload. Capture retains disconnected players, updates connected players, and throws on incomplete restoration or a failed departure capture. A storage caller must keep the previous successful snapshot when capture/save fails. Never overwrite it with an empty or partial fallback.

All APIs throw on invalid core state; auxiliary service restore methods may return false/reason, which the coordinator converts into an error. A failed activation must leave the session unavailable for play/save rather than release an incomplete world. The coordinator is intended for one boot-time stage/restore sequence per server.

## Saved state

- Biome, current/next weather, current/next biome, seed, shift count, elapsed run time, day/night phase, remaining shift/weather timers, locked destination and used delay allowance.
- Reusable-device cooldown remaining. Active votes and held inputs are cancelled and never restore consent from a disconnected crew.
- Placed structures, transforms, owners, durability, station prompts, grid reservations and complete chest slot inventories.
- Ground item identities, counts and transforms, including death spills.
- Per-player hotbar/storage/armor, run class, base stats, actual HP, persistent/stat modifier durations, tonic resistance durations, wetness, position, downed state and body transform. Team death/revive totals remain available for offline participants. A downed body's DeathId survives for reward deduplication.
- Current biome generated resource/prop depletion and partial HP, including marked subnodes; generated chest contents; generated enemy levels/HP/transforms. Keys combine shift epoch, chunk, category and deterministic placement ordinal; unload records state before destruction and reload reconstructs it. Static untouched scenery is regenerated from seed.
- Living enemies in workspace.Enemies with prefab ID, level, HP/max HP, transform and entity type. The current procedural art uses Humanoid-based models.
- Active events/objectives, remaining schedules, one-shot drop gates, objective progress/instance IDs and threat through their explicit adapters.

## Deliberate limits and migration

Payload limit: 3,500,000 JSON bytes. Record caps: 1,500 builds, 3,000 ground drops, 60,000 changed generated nodes, 500 global enemies and 100 historical player records. Limits cause explicit capture failure; nothing is silently truncated. Build placement enforces the structure cap before spending resources. Session UI/operations should surface save failures and retain the previous snapshot.

Ragdoll limb pose/velocity, dropped-item velocity, AI path/target/attack animation, selected UI tabs and held tool input restart. These are transient presentation or controller state; world/player transforms and gameplay quantities persist. Enemy-wave random rolls and the process random generator resume from a fresh stream; already selected biome/weather forecasts and active entities are saved. No future random sequence is claimed identical.

Generated object keys depend on prefab names, prefab hierarchy and the procedural placement recipe. Changing those requires incrementing GeneratorVersion and supplying an explicit migration before old saves can load. A changed/missing known prefab, unknown item/class, invalid slot shape, or generated chunk failure blocks a subsequent save rather than replacing the old record. This is a snapshot adapter, not a generic Roblox instance dump; new persistent mechanics must add an explicit adapter and a migration.

Runtime verification is performed by the parent task in Studio after lifecycle integration; this source slice was inspected without running a competing Studio session.

## Session controller integration

`WorldSessionService:PrepareExpedition()` returns `true, snapshotOrNil` before snapshot staging. Published expeditions resolve their Roblox reserved-server ID through WorldStateStore, verify the committed original roster and native MatchmakingType, acquire a fenced server lease, and wait for the original six users before loading saved data. TeleportData never authorizes entry. The Studio branch returns a fresh local world and does not reserve or save production worlds.

`StartExpedition(snapshotService)` runs after snapshot activation and owns profile/character loading, later original-member rejoin, initial/120-second snapshots, departure/shutdown save attempts and terminal wipe handling. Lease renewal runs separately from uploads every 30 seconds. A separate one-second watchdog checks the authoritative Unix deadline. `WorldLeaseOwned` and `WorldLeaseUntil` let reward code reject new earnings immediately after expiry, including during a blocked upload. New admissions stop when the final save begins; a paused server cannot admit a player midway through publishing its final snapshot.

Matchmaking calls `CreateMatchedExpedition(record)`. Its durable intent stores the stable world ID, original members/classes and source party claims before merging. All six player archives must reserve a free slot before the crew commit. Only a confirmed precommit cancellation returns false and compensates slots. Storage uncertainty and postcommit failures return nil so the same transaction is retried. A server-only reservation credential is published under a worker/generation fence, then durable per-user assignments allow lobby workers to transfer their local players to the same reserved server. Transfer failures retry with attempt IDs; an old failure cannot cancel a later attempt.

Lobby APIs are `GetRejoinSummary(player)`, `Rejoin(player)`, `Resume(player, ownedSlotId)` and `ReturnToLobby(player)`. Active rejoin checks durable original membership independently of expiring party indexes. Paused or expired-server resume requires exactly the original six users together in a ready lobby party, compatible native MatchmakingType and no conflicting active assignments. Any original owner with a remaining copy can request it; the party's current leader need not be the original leader. A new generation cannot start while the preceding server lease remains valid. Ended worlds cannot resume.

Resume holds a temporary PartyService membership lock while WorldStateStore adopts the new generation. Adoption checks the lock's generation, expiry and durable rejection token; release acknowledges the exact adopted token or writes a durable rejection before unlocking an expired attempt. Heartbeats do not invalidate consent, and a member cannot leave midway through the commit. Uncertain decisions keep the lock pending until retry/reconciliation can establish the outcome.

Archive names are personal references to one shared world. `WorldSaveService:RemoveCopy(player, slotId)` removes only that owner's slot. `ReconcileRosterForResume(worldId, roster)` recreates missing owners' references with the default name, reserving all needed capacity before commit. It fails if an owner lacks a free slot, preserves existing names, and never duplicates the underlying world progress. Pending capacity reservations count toward the five-slot cap. `HasFreeSlot(userId)` supplies the queue-entry check; `ReserveRoster` remains the authoritative capacity check. `UpdateManifest(record)` publishes snapshot revision/status for all surviving named copies.

The runtime stores source/roster metadata durably so confirmed crew commits can recover after MemoryStore expiry. If the merge outcome was uncertain and all short-lived evidence expires before a durable CrewCommitted decision exists, recovery stays pending instead of guessing commit or abort. Roblox/storage outages can also outlast the shutdown window: the preceding successful snapshot remains usable, but the latest unsaved changes cannot be guaranteed in that case. Reserved-server travel, cross-server failures and production DataStore behavior still require the parent's published integration checks; a successful Studio fresh boot does not validate them.

Roblox API references: [TeleportService](https://create.roblox.com/docs/reference/engine/classes/TeleportService), [TeleportOptions](https://create.roblox.com/docs/reference/engine/classes/TeleportOptions).
