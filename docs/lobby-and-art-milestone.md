# Lobby, sessions, and original art — work in progress

The previous gameplay milestone is complete. This document tracks the full new goal; partial implementation does not constitute completion.

## Confirmed scope

- Add dark mode, enabled by default, while retaining the expedition UI and a light mode option.
- Make the lobby the experience entry place, with party management, class selection, class shop, and other useful expedition preparation controls. Do not implement cosmetics.
- Generalist is free. Other classes are permanent unlocks bought with currency earned from survival milestones, teamwork, and objectives.
- Parties hold at most six members. Disconnected members stay in the party, marked offline, while anyone remains online. Membership survives lobby/run teleports and returning to the lobby. Dissolve the party when everyone leaves; retain each individual's run rejoin record separately.
- The leader can start an expedition with the current party of 1–6 online, ready players. Optional matchmaking merges whole parties into a six-player lobby crew, preferring complementary classes and similar levels when authoritative progression stats are added. It chooses randomly among the original party leaders for now. All members must ready up again, then the new leader presses Start Expedition; merging itself never creates a world or starts travel.
- Crew slots show avatar portraits and open member profiles. Career statistics are unavailable until the stats system is added. In the lobby, the current leader can remove another crew member or transfer leadership to an online member; queued, launching and recovery crews are locked. Crew management resets readiness.
- Rejoining must route to the correct expedition. Each participant has up to five named saved worlds. Saving must preserve the world after the server shuts down. Resume requires exactly the original 1–6 players present when the world was created; a different leader must work. Personally named copies share one world's progress, and every original player must have a free slot before creating a world. A lobby merger does not consume a save slot.
- A full-team wipe automatically removes that world's copies from all original owners and frees their save slots. Terminal internal records prevent stale workers from restoring the ended run; active and paused saves survive.
- Queue admission requires every party member online. A disconnect cancels that party's queue.
- Replace temporary art with original stylized low-poly expedition models: angular silhouettes, painted colors, and restrained biome glow. Complete the resource, tool, weapon, armor, station, and monster families; tune loot and spawn rates.
- Use Rojo source edits. GitHub pushes mark completed substantial milestones. The user's later instruction reserves Roblox publishing for them; do not publish source updates automatically.

## Current external state

Universe `8439909753`, group `34468779`: the final routing in `Shared/SessionConfig.lua` is `LobbyPlaceId = 120274921310527` and `ExpeditionPlaceId = 94125768885713`. The entry place **Ecoshift** now contains the lobby; the secondary place **Expedition** contains survival gameplay. The experience remains private.

Full Studio backups were saved before replacing either place: `build/backups/Ecoshift-before-lobby-migration-2026-09-07.rbxl` (330,736 bytes) and `build/backups/Lobby-original-2026-09-07.rbxl` (78,880 bytes). The initial migration published expedition v3 and lobby v812. Both cloud editors reached Ready in fresh Studio Play sessions with correct routing and the armor mounting fix; a real Roblox Player join loaded the new lobby. The subsequent walking-clearance fix passed R6/R15 review and both builds, then published as Expedition v5 and Ecoshift v814. Real six-player travel and persistence validation remains pending; see `validation-2026-09-07.md`.

## Session design

Current source checkpoint: `7affe1b` on `codex/gameplay-fieldkit-milestone`, pushed to GitHub. Both local Rojo builds passed at that checkpoint. Read-only inspection of both connected editors confirmed the latest terminal-save cleanup and compact topbar module, with Lobby/Expedition modes matching their configured IDs. Their open document versions were 812 and 3; those editor properties do not establish the current cloud publication version. The earlier publication evidence above is historical, and later source changes are not claimed published.

Keep four different records: party membership, online presence, queue ticket, and expedition admission/rejoin. A disconnect changes presence, not membership. A teleport uses a short handoff lease so it does not count as the whole party leaving. A new server session supersedes the old presence owner, preventing a delayed PlayerRemoving from marking the newly connected player offline.

Shared MemoryStore records coordinate servers; all party mutations and matchmaking claims must use conditional UpdateAsync operations. Invitations require recipient acceptance. Six-member capacity and membership claims are checked on the server. Reserved-server access codes remain server-only. Teleport data identifies a run but never authorizes admission or awards currency.

Currency changes and class purchases must be atomic and idempotent across server transfers. Failed profile loads must never overwrite stored data with defaults. Class ownership and theme preferences persist across both places.

## Requirement audit

| Requirement | Current evidence | Remaining verification |
| --- | --- | --- |
| Dark by default; optional light theme | DefaultTheme is Dark. Actual settings clicks saved both themes across fresh Play sessions; both lobby/shop themes inspected. | Published device coverage beyond desktop Studio. |
| Lobby is the entry place | Ecoshift v814 contains Lobby mode; Expedition v5 contains survival. Actual Roblox Player join entered the observatory. Full pre-migration backups exist. | Entry join is verified; six-person travel is covered below. |
| Party, classes and earned-currency shop; no cosmetics | Lobby controls/class catalog implemented and rendered. Generalist is free; permanent class purchase/reward operations passed nine isolated persistence/failure cases. | Earn currency in a real expedition, purchase once, and retain ownership across place changes. |
| Persistent parties; offline members; dissolve when everyone leaves | Presence ownership, handoff leases and six-member limits implemented. Actual Studio remotes created/readied/queued/cancelled a solo party. | Multiple accounts: invites, disconnect cancellation, offline membership, capacity, return-to-lobby persistence and final dissolution. |
| Class-aware cross-lobby party merger | Native class-diversity configuration applied; custom queue preserves whole parties, merges six into a lobby crew, chooses an original leader and resets readiness. Manual Start reserves travel only after everyone readies again. Optional level scoring is dormant until authoritative stats exist. | Six real accounts across lobbies: merge, ready again, manual start, travel, retry and disconnect races. |
| Correct run rejoin and shared saved worlds | Generation/lease admission, five personally named copies and exact-original-crew resume implemented. World store passed 16 isolated cases; current save ownership/cleanup passed 27. Actual world/player snapshot restoration checked. Ended copies disappear and cannot resume; partial cleanup, lost acknowledgments and late resume writes are covered with fake stores. | Full crew: live rejoin, shutdown/resume, new leader/any owner, personal names, copy removal/recreation, capacity, shared progress and wipe/return deletion. |
| Original models and cohesive art | Original resource, prop, tool, armor, build, pickup, chest, landmark and creature families generated. Catalog and mount checks, creature lineup and armor front/rear/walking reviews passed. All nine armors were checked on sampled R15 proportions; native decoration scaling was fixed. Run, jump and Harvester-swing poses were subsequently sampled. | Custom animation packs/extreme avatar bundles remain outside verified art coverage. These samples do not establish every possible avatar combination. |
| Loot and spawn tuning integrated | Biome cache/resource yields and independent monster levels/caps configured. Catalog references resolve. Real melee/bow/monster death/generated loot/pickup integration passed in a temporary Studio arena. | Full-team survival playthrough for the intended 60–90-minute progression and balance. |
| Builds, publication and GitHub milestone | Both current builds passed; source through 7affe1b is pushed and synced to both editors. The initial lobby migration was published historically. | The user handles publishing current source. Current cross-server behavior cannot be inferred from the older published revision. |

The goal remains incomplete because full-team live behavior and progression are not established by isolated fixtures or a solo Studio session. Six distinct Roblox accounts with access to this private experience are required for the remaining crew checks. The user explicitly chose to keep those checks pending and handles publishing. Do not repeatedly request a crew or treat this deferral as successful validation.

## Pending live acceptance sequence

Run against the same source revision in both places once the user has published it; record that revision and both place versions with the results. Use the participants' intended disposable worlds, not existing valued saves.

1. From separate lobbies, form small parties with different classes. Verify online-friend invites, acceptance, offline membership, queue cancellation on disconnect, and rejection when an offline member tries to queue. A whole-party merger must create one crew of six, choose one of the original leaders, clear readiness, and wait for that leader's Start after everyone readies.
2. Also start a smaller ready party directly. For both paths, verify exact crew admission and preserved membership during travel. Disconnect one participant and rejoin the correct running world. Verify the last departure dissolves the party without losing a paused world's saved progress.
3. Re-form the exact original crew under a different leader. Resume through any original owner with a copy. Check inventory, buildings, chest contents, weather, biome elapsed time and independent monster levels. Personally renamed copies must share this progress. Remove one copy and verify resume recreates it only with a free slot; a missing original participant must block resume. Starting a new world must require capacity for everyone.
4. Earn a survival milestone, objective and revive reward through gameplay; buy an affordable class once, then change places and reconnect. Confirm permanent ownership and the correct remaining balance. A full-team wipe must return the crew to the lobby with the ended world absent from all archives and its slots free, while unrelated paused worlds and earned rewards remain.
5. Play ordinary gathering, crafting and combat through late progression. Record biome visits, deaths, resource bottlenecks and the first successful world-control craft/use. Fully random weighted shifts remain the user's choice: 60–90 minutes is a target, not a guarantee that all required biomes appear. Verify fuel, cooldowns and majority voting with actual teammates.
