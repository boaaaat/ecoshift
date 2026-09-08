# Session validation and handoff

The active lobby/persistent-world/original-art goal is not complete. This document accompanies the source milestone; publishing and entry-place migration remain separate unfinished work.

## Confirmed archive policy

Each original expedition participant has one personally named copy of the same shared world, up to five copies per player. All six original members need a free slot to create a world. Removing a copy affects only that player's archive; resuming with the original crew recreates missing copies when those players have capacity. Any original owner with a remaining copy may request resume once all six original players are together, online and ready. Party leadership may change.

## Executed checks

- WorldStateStore: all 16 deterministic cases passed on an injected disposable ModuleScript using fake stores. Covered reservation/generation/platform admission, lease expiry, competing owners, stale assignments, snapshot round trip, current/previous chunk retention, committed-but-unacknowledged retries, terminal write retries, callback replay, stale upload publication, exhausted writes and UTF-8 chunk boundaries. No production data-store calls were made by this fixture.
- Studio expedition boot with WorldSessionService reached Ready and loaded the player.
- A real running-server fixture seeded inventory (Harvester, 17 ForestWood, 9 SulfiteOre, FrostParka), a chest with 23 ForestWood and 3 Bandage at durability 71, a level-7 Wolf with 53/137 health, FieldClock pickup, RelayRepair at 40%, and ResourceBoom. A fresh Play session restored the captured JSON through StageWorld/RestoreWorld/CompleteWorldRestore/RestorePlayer. All serialized values matched within 0.1 numeric tolerance, except the event's no-op one-shot flag advancing to consumed. Timers advanced only about 0.03 seconds across restoration; armor was physically attached.
- A separate downed fixture restored one ragdoll, unchanged death GUID, 37 seconds downed time and one counted death without duplicating inventory or deaths.
- Restoring event/objective adapters twice preserved ResourceMultiplier=2 and the original objective occurrence at 40%.
- The downed fixture exposed a chunk/camera restoration issue: loading followed only living characters, and corpse camera selection could run before the corpse replicated. Fixes are being completed; recheck those before publication.
- Unknown item grants were rejected after adding inventory validation. The initial fixture used nonexistent generic item IDs and caught that validation gap; the corrected fixture used catalog IDs.

All temporary Rojo QA scripts and the temporary ServerMain fixture hook were removed at the end of this turn. The fake-store harness remains only under ignored build/qa. Studio was stopped in Edit mode.

## External work

The native EcoShift Expedition Lobbies matchmaking configuration was saved and applied to both existing places through Creator Dashboard. Its custom class attribute reads EcoshiftProfile_v1 / global / {UserId} / $.Role. Detailed weights and official sources are in native-matchmaking-setup.md.

The user stopped Computer Use with Escape while Studio configuration was being inspected. No Chat & Voice Groups terms were accepted, no entry-place migration was performed, and no place was published. Native window inspection temporarily maximized Studio. Continue through Rojo/MCP when resumed; Computer Use must not continue in the stopped turn.

## Remaining validation

Review and verify the final party resume lock integration and archive copy reconciliation. Check five-slot capacity, deletion/recreation, failure compensation and cross-server resume. Recheck downed surroundings/camera, results rewards, lobby archive controls, armor/tool fit and actual combat. Perform actual published entry-place routing and six-player handoff/rejoin checks; a solo Studio check does not prove those. Preserve survival content before migrating the start place. Commit and push a verified milestone, and keep the goal active until its required work is done.

## Follow-up validation

- Downed restore fix verified in a fresh Play session: corpse ReplicationFocus and client CameraSubject both pointed at the ragdoll torso; 48,481 generated descendants stayed loaded around it. The surroundings rendered correctly. Studio respawn cleared the corpse focus and downed flag. This is not a substitute for a two-player crafted-kit revival check.
- Profile operations passed 9 isolated fake-store cases: grant, duplicate receipt, conflicting fingerprint, one-time permanent purchase, insufficient funds, lost committed response, stale theme update, damaged stored balance, and exhausted-write pending state. No real balance or class ownership was modified by these checks.
- WorldSaveService passed all 22 isolated fake-store cases: hidden reservations, five-slot cap, compensation, partial commit, lost responses at each commit stage, owner-only copy removal, stale removal callback replay, exact original roster, missing-copy recreation with preserved peer names, full-cap rollback, expired workers, filtered rename, and public metadata whitelist.
- Actual running Lobby remotes accepted party creation, ready state, queue entry and cancellation. A solo player waited for the required six; no partial match launched. A display-only five-save sample verified rename/remove/resume layout without creating real archive entries. Dark lobby and the team reward summary rendered correctly.
- Both Rojo place projects built successfully. Temporary QA scripts, source hooks, fake modules and display data were removed or discarded by stopping Play. The final dedicated party resume lock was reviewed for exact roster/session, token/deadline and durable-generation fences; published race behavior still needs integration verification.

Remaining: publish correct entry and survival place content, native communication-API opt-in if desired, real six-player cross-lobby matching and reserved handoff, disconnect/rejoin/shutdown-resume checks, full avatar/tool/armor and combat review. The fixture suites exercise deterministic fault cases and do not simulate Roblox production quotas or guarantee availability during outages.
