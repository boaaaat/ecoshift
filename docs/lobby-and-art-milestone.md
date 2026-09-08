# Lobby, sessions, and original art — work in progress

The previous gameplay milestone is complete. This document tracks the full new goal; partial implementation does not constitute completion.

## Confirmed scope

- Add dark mode, enabled by default, while retaining the expedition UI and a light mode option.
- Make the lobby the experience entry place, with party management, class selection, class shop, and other useful expedition preparation controls. Do not implement cosmetics.
- Generalist is free. Other classes are permanent unlocks bought with currency earned from survival milestones, teamwork, and objectives.
- Parties hold at most six members. Disconnected members stay in the party, marked offline, while anyone remains online. Membership survives lobby/run teleports and returning to the lobby. Dissolve the party when everyone leaves; retain each individual's run rejoin record separately.
- Cross-server matchmaking fills expeditions to six, preferring complementary classes without splitting existing parties.
- Rejoining must route to the correct expedition. Each participant has up to five named saved worlds. Saving must preserve the world after the server shuts down. Resume requires all six original players, including a crew assembled through matchmaking; a different leader must work. Personally named copies share one world's progress, and all six players must have a free slot before creating a world. These ownership rules are confirmed.
- Queue admission requires every party member online. A disconnect cancels that party's queue.
- Replace temporary art with original stylized low-poly expedition models: angular silhouettes, painted colors, and restrained biome glow. Complete the resource, tool, weapon, armor, station, and monster families; tune loot and spawn rates.
- Use Rojo source edits; computer use is now authorized. GitHub pushes mark completed substantial milestones.

## Current external state

Universe `8439909753`, group `34468779`: the final routing in `Shared/SessionConfig.lua` is `LobbyPlaceId = 120274921310527` and `ExpeditionPlaceId = 94125768885713`. The entry place **Ecoshift** now contains the lobby; the secondary place **Expedition** contains survival gameplay. The experience remains private.

Full Studio backups were saved before replacing either place: `build/backups/Ecoshift-before-lobby-migration-2026-09-07.rbxl` (330,736 bytes) and `build/backups/Lobby-original-2026-09-07.rbxl` (78,880 bytes). The initial migration published expedition v3 and lobby v812. Both cloud editors reached Ready in fresh Studio Play sessions with correct routing and the armor mounting fix; a real Roblox Player join loaded the new lobby. The subsequent walking-clearance fix passed R6/R15 review and both builds, then published as Expedition v5 and Ecoshift v814. Real six-player travel and persistence validation remains pending; see `validation-2026-09-07.md`.

## Session design

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
| Class-aware cross-lobby exact-six queue | Native class-diversity configuration applied; custom queue preserves whole parties, claims a full roster and reserves travel. Solo queue did not launch a partial team. | Six real accounts across lobbies: merge, travel, retry and disconnect races. |
| Correct run rejoin and shared saved worlds | Generation/lease admission, five personally named copies and exact-original-crew resume implemented. World store passed 16 isolated cases; save ownership passed 22. Actual world/player snapshot restoration checked. | Full crew: live rejoin, shutdown/resume, new leader/any owner, personal names, copy removal/recreation, capacity and shared progress. |
| Original models and cohesive art | Original resource, prop, tool, armor, build, pickup, chest, landmark and creature families generated. Catalog coverage, 34 tool mounts, 21 armor checks, creature lineup and armor front/rear/walking reviews passed; observed walking clipping fixed. | Custom animation packs/extreme avatar proportions remain outside verified art coverage. |
| Loot and spawn tuning integrated | Biome cache/resource yields and independent monster levels/caps configured. Catalog references resolve. Real melee/bow/monster death/generated loot/pickup integration passed in a temporary Studio arena. | Full-team survival playthrough for the intended 60–90-minute progression and balance. |
| Builds, publication and GitHub milestone | Both builds passed; both final places published. Source migration/armor milestone pushed as 4906467. | No publishing gate remains for that revision. |

The goal remains incomplete because full-team live behavior and progression are not established by isolated fixtures or a solo Studio session. Six distinct Roblox accounts with access to this private experience are required for the remaining crew tests. The user explicitly authorized the necessary gameplay and published multi-server checks.
