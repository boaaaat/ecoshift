# Session validation and handoff

The active lobby/persistent-world/original-art goal is not complete. Both places are published and their cloud editors passed fresh Studio startup checks. Real six-player cross-server validation remains pending.

## Confirmed archive policy

Each original expedition participant has one personally named copy of the same shared world, up to five copies per player. Every original member needs a free slot to create a world: 1–6 players for a direct party start, six for matchmaking. Removing a copy affects only that player's archive; resuming with the original crew recreates missing copies when those players have capacity. Any original owner with a remaining copy may request resume once every original player is together, online and ready. Party leadership may change.

## Executed checks

- WorldStateStore: all 16 deterministic cases passed on an injected disposable ModuleScript using fake stores. Covered reservation/generation/platform admission, lease expiry, competing owners, stale assignments, snapshot round trip, current/previous chunk retention, committed-but-unacknowledged retries, terminal write retries, callback replay, stale upload publication, exhausted writes and UTF-8 chunk boundaries. No production data-store calls were made by this fixture.
- Studio expedition boot with WorldSessionService reached Ready and loaded the player.
- A real running-server fixture seeded inventory (Harvester, 17 ForestWood, 9 SulfiteOre, FrostParka), a chest with 23 ForestWood and 3 Bandage at durability 71, a level-7 Wolf with 53/137 health, FieldClock pickup, RelayRepair at 40%, and ResourceBoom. A fresh Play session restored the captured JSON through StageWorld/RestoreWorld/CompleteWorldRestore/RestorePlayer. All serialized values matched within 0.1 numeric tolerance, except the event's no-op one-shot flag advancing to consumed. Timers advanced only about 0.03 seconds across restoration; armor was physically attached.
- A separate downed fixture restored one ragdoll, unchanged death GUID, 37 seconds downed time and one counted death without duplicating inventory or deaths.
- Restoring event/objective adapters twice preserved ResourceMultiplier=2 and the original objective occurrence at 40%.
- The downed fixture exposed a chunk/camera restoration issue: loading followed only living characters, and corpse camera selection could run before the corpse replicated. The subsequent fix and fresh Play verification are recorded under Follow-up validation.
- Unknown item grants were rejected after adding inventory validation. The initial fixture used nonexistent generic item IDs and caught that validation gap; the corrected fixture used catalog IDs.

All temporary Rojo QA scripts and the temporary ServerMain fixture hook were removed at the end of this turn. The fake-store harness remains only under ignored build/qa. Studio was stopped in Edit mode.

## External work

The native EcoShift Expedition Lobbies matchmaking configuration was saved and applied to both existing places through Creator Dashboard. Its custom class attribute reads EcoshiftProfile_v1 / global / {UserId} / $.Role. Detailed weights and official sources are in native-matchmaking-setup.md.

At an earlier pause, the user stopped Computer Use with Escape while Studio configuration was being inspected. No Chat & Voice Groups terms had been accepted and no place had been published at that point. Later deployment progress is recorded below; the earlier pause is not the current publication status.

## Place migration status

Final source routing for universe `8439909753` is fixed by `Shared/SessionConfig.lua`; display names do not determine runtime mode.

| Runtime role | Place ID | Current Roblox name | Publication status at this update |
| --- | --- | --- | --- |
| Public entry lobby (`LobbyPlaceId`) | `120274921310527` | Ecoshift | Initial migration v812 confirmed in published-only history; final armor update v814 published at 7:21 PM local |
| Reserved expedition (`ExpeditionPlaceId`) | `94125768885713` | Expedition | Initial migration opened as v3; final armor update v5 published at 7:04 PM local |

Both full Studio backups were saved before replacing the place content:

| Local backup | Verified bytes |
| --- | ---: |
| `build/backups/Ecoshift-before-lobby-migration-2026-09-07.rbxl` | 330,736 |
| `build/backups/Lobby-original-2026-09-07.rbxl` | 78,880 |

These backups preserve the original entry survival place and original secondary Lobby place. The experience remains private. Creator Dashboard confirmed the secondary rename with Place Updated.

The cloud-backed lobby editor loaded place `120274921310527`, version 812, with PlaceMode Lobby and correct routing. Fresh Play reached ServerBootState Ready; the player had ProfileStatus Ready, ProfileLoaded true and UITheme Dark. The crew panel and observatory rendered, with no game console errors. The earlier unpublished local build's DataStore error disappeared after publication.

The secondary place was freshly opened from Studio's Places In Experience. Version 3 had PlaceMode Expedition, correct routing and AccessoryRigidConstraint support. Fresh Play reached Ready and initialized the original prefabs, streaming, tools, crafting and death UI without errors. These are Studio checks on cloud place content; they do not prove live reserved-server travel or persistence across servers.

A real Roblox Player join through the experience page loaded the observatory and dark expedition crew panel. Automated mouse/keyboard input did not activate either Create Party or Roblox's own menu/F9 console; therefore live party actions were not validated or attributed to a game defect. Six real accounts are still required for the cross-lobby queue, reserved handoff and shared-save integration checks.

The final walking-clearance geometry passed fresh R6/R15 review and both builds before publication to both places. Studio output explicitly confirmed publication of Expedition v5 and Ecoshift v814. The temporary gallery existed only in Play and was absent in Edit. The lobby Rojo process was restarted after the tool host restarted; the existing expedition server remained running.

## Remaining validation

Review and verify the final party resume lock integration and archive copy reconciliation across real servers. Check five-slot capacity, deletion/recreation, failure compensation and cross-server resume. Use the follow-up evidence below to distinguish completed isolated checks from outstanding integration and visual checks. Perform live entry joins and six-player handoff/rejoin checks; solo Studio startup does not prove those. Keep the goal active until its required work is done.

## Follow-up validation

- Downed restore fix verified in a fresh Play session: corpse ReplicationFocus and client CameraSubject both pointed at the ragdoll torso; 48,481 generated descendants stayed loaded around it. The surroundings rendered correctly. Studio respawn cleared the corpse focus and downed flag. This is not a substitute for a two-player crafted-kit revival check.
- Profile operations passed 9 isolated fake-store cases: grant, duplicate receipt, conflicting fingerprint, one-time permanent purchase, insufficient funds, lost committed response, stale theme update, damaged stored balance, and exhausted-write pending state. No real balance or class ownership was modified by these checks.
- WorldSaveService passed all 22 isolated fake-store cases: hidden reservations, five-slot cap, compensation, partial commit, lost responses at each commit stage, owner-only copy removal, stale removal callback replay, exact original roster, missing-copy recreation with preserved peer names, full-cap rollback, expired workers, filtered rename, and public metadata whitelist.
- Actual running Lobby remotes accepted party creation, ready state, queue entry and cancellation. A solo player waited for the required six; no partial match launched. A display-only five-save sample verified rename/remove/resume layout without creating real archive entries. Dark lobby and the team reward summary rendered correctly.
- Both Rojo place projects built successfully. Temporary QA scripts, source hooks, fake modules and display data were removed or discarded by stopping Play. The final dedicated party resume lock was reviewed for exact roster/session, token/deadline and durable-generation fences; published race behavior still needs integration verification.

Remaining: live place routing, native communication-API opt-in if desired, real six-player cross-lobby matching and reserved handoff, disconnect/rejoin/shutdown-resume checks, and the outstanding avatar/tool/armor visual and combat review described below. The fixture suites exercise deterministic fault cases and do not simulate Roblox production quotas or guarantee availability during outages.

## Avatar mounting follow-up

- A fresh MCP Play fixture passed all 21 armor checks: all eight armor types mounted natively on both vanilla R6 and R15 rigs; both rig types passed missing-attachment fallback, late-attachment recovery and destroyed-joint cache repair; unequip, character replacement and departure cancelled pending retries. Checks included attachment alignment and preservation of every armor part.
- The armor fixture required a cloned ArmorService with stub InventoryService/StatsService siblings and fake player tables, using real generated GameItems and vanilla engine-created rigs. Its player event subscriptions were isolated from live players. No live-player profile was mutated by the fixture.
- Runtime inspection identified native AccessoryWeld mounting on R6 and AccessoryRigidConstraint mounting on R15. Recovery now recognizes both, lets one native attachment request finish, and creates fallback welds after final parenting.
- All 17 tools passed native RightGrip mounting checks on each rig type, for 34 NPC mount checks. Separately, CrystalBow was visually verified upright while held by an animated real-player R15 character. These checks do not establish full tool animation or combat correctness.
- A subsequent temporary Play gallery provided unobstructed front/rear views of all eight armor sets on both vanilla rigs. Walking review found SwampWaders and StarforgedPlate lower-panel thigh clipping; their rigid panels were shortened and raised. Fresh R6/R15 close views confirmed clearance at sampled peak forward thigh positions. Both Rojo builds passed after the geometry change. Custom animation/combat poses, avatar scaling and extreme proportions remain unverified; see art-direction.md for the visual review details.

## Final local integration checks

- Actual SettingsUI clicks changed Dark to Light and back. ProfilePreference returned Success=true/Reason=Saved for both choices. Each choice survived a fresh Studio Play session with ProfileLoaded=true/ProfileStatus=Ready; the original Dark preference was restored. Light and Dark settings, lobby and class shop rendered, including scrolling to Medic/Engineer. No currency grants, purchases or class selections were made. Final fresh lobby console was empty. This covers desktop Studio and real preference persistence, not published mobile behavior.
- A temporary expedition Play arena exercised the production-bound CombatAction remote against a generated Wolf. The normal AI binding gave the level-7 wolf 137.2 health from its 70 base health. A generated StoneSpear dealt 18 damage; three immediate requests produced only one hit. An intervening wall blocked the next attack.
- A generated CrystalBow release without ChargeStart caused no damage. A full charge dealt 44 damage. Two further charged attacks defeated the wolf, which was removed and emitted the configured WolfPelt and WolfFang models with pickup prompts. Actual E input collected the pelt; the production InventoryUpdate snapshot contained one WolfPelt. A second E input removed the remaining fang pickup.
- Combat QA manually equipped generated tools and positioned an anchored player/target in a temporary arena; player health was raised for the check. Thus it validates weapon/monster/drop integration, not free movement, weapon input animations, organic crafting progression or six-player balance. No permanent currency or profile ownership was changed. Stop discarded the arena, equipment, target, drops and temporary client observer.

## Lobby responsiveness and invite picker

- Removed the mutation lock from slow snapshot reads. Lobby requests now carry unique IDs, immediate acknowledgments, explicit failures and revisioned partial snapshots. Class/crew updates refresh independently of archive/rejoin reads. Unchanged polling preserves existing controls; pending buttons update locally before any server response.
- Isolated service checks passed 10 ordering/deduplication/rate/read-fencing cases, 8 queue/directory contract cases and 9 numeric-invite validation cases. Fake invite sinks sent no actual invitations. A real Studio class-button click showed Equipping on release and server confirmation about 0.87 seconds after mouse-down; Generalist was equipped and the original Gatherer selection was restored.
- A disposable UI remote with a 1.5-second response delay verified immediate disabled pending states, successful readiness changes, explicit Generalist / Ready and Not ready labels, queue elapsed time from the server timestamp, continued elapsed time across navigation, cancellation, failed purchase feedback and enabled retry. A conflicting old-revision snapshot could not replace the confirmed state.
- The scrollable picker rendered 18 simulated online-friend profile tiles followed by a simulated server player, with no username entry required. Avatar thumbnails loaded independently; tile clicks displayed Inviting immediately. No actual friend invitations were sent. Outside-experience invitations use the documented targeted Roblox confirmation prompt; delivery and recipient arrival still need a user-driven live check. See [Roblox invite prompts](https://create.roblox.com/docs/production/promotion/invite-prompts) and [online friend API](https://create.roblox.com/docs/reference/engine/classes/Player#GetFriendsOnlineAsync).
- The lobby design is now 1120 by 740 with larger typography and resolution-aware scaling shared across the field kit. Fixed HUD edge spacing scales with its controls to preserve the gap above the hotbar. Actual Theme.Fit code passed geometry checks at 1280x720, 1920x1080, 2560x1440, 3840x2160 and 390x844; the latter checks containment only, not phone readability. Fresh expedition startup rendered the updated HUD without game console errors. Animated modals and paired chest/pack positioning keep their existing dynamic layout behavior.
- Both Rojo projects detected the new directory service without a restart. Temporary UI fixtures, QA remotes and scaling clones were discarded by stopping Play. No currency, class ownership, saved worlds or real invitations were changed by the UI fixtures.
- Final builds passed and Studio publication output confirmed entry lobby `120274921310527` version **819** at 8:27 PM local and expedition `94125768885713` version **10** at 8:28 PM local. Both were in Edit with no QA objects when published. The expedition editor still displays its former Lobby title; the verified place ID and PlaceMode remain Expedition.

## Direct party start and optional matchmaking

- The leader now has separate Start Expedition and Matchmake controls. Start preserves the current online, ready party of 1–6 and checks each member's free archive capacity. It uses the existing recoverable world reservation and crew commit, without exporting a public queue ticket. Matchmaking continues to require six matched players. Pending starts give immediate feedback and allow cancellation before the irreversible crew commit.
- PartyService passed 50 isolated fake-store checks covering direct and matched roster sizes, invalid rosters, mode/replay conflicts, exact original crew/session/readiness fences, recovery and storage uncertainty. MatchmakingService and WorldSessionService passed 21 isolated cases covering starts and resumes for 1, 2 and 6 players, duplicate requests, invalid sizes, leader authorization, offline/unready/stale-session members, save capacity, concurrent crew changes, cancellation before the first world write and preservation of uncertain committed work. These checks created no live queue tickets, reserved servers or saved worlds.
- Actual production-bound Studio UI clicks verified separate Start and Matchmake buttons, unready feedback, Ready status and explicit published-play feedback for Start. Leaving restored the initial no-party state. An older Play snapshot initially failed the new cancellation check; verifying Rojo's Edit source and starting fresh passed the complete 21-case fixture.
- Both final Rojo builds passed. Both Edit datamodels contained the new launch, cancellation and variable-roster code with no QA/fixture objects. Live reserved-server travel and saved-world resume remain to be verified in published play; isolated fixtures do not establish those results.
- Studio output confirmed publication of entry lobby `120274921310527` version **821** at 8:51 PM local and expedition `94125768885713` version **12** at 8:53 PM local. Both places were stopped in Edit during publication.
