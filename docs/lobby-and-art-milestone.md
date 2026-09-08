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

Universe `8439909753`, group `34468779`: current start/survival place `120274921310527`; existing Lobby `94125768885713`. Inspected through Studio's place inventory. Start-place migration has not happened. Preserve a full survival-place copy before publishing lobby content over the current entry place, as required by Roblox's documented start-place workflow.

## Session design

Keep four different records: party membership, online presence, queue ticket, and expedition admission/rejoin. A disconnect changes presence, not membership. A teleport uses a short handoff lease so it does not count as the whole party leaving. A new server session supersedes the old presence owner, preventing a delayed PlayerRemoving from marking the newly connected player offline.

Shared MemoryStore records coordinate servers; all party mutations and matchmaking claims must use conditional UpdateAsync operations. Invitations require recipient acceptance. Six-member capacity and membership claims are checked on the server. Reserved-server access codes remain server-only. Teleport data identifies a run but never authorizes admission or awards currency.

Currency changes and class purchases must be atomic and idempotent across server transfers. Failed profile loads must never overwrite stored data with defaults. Class ownership and theme preferences persist across both places.

## Completion evidence still required

Actual published entry-place routing; dark/light UI inspection; class purchase/reward persistence; party invitations, capacity, disconnect, handoff and dissolution; cross-lobby class-aware matching; correct run rejoin; five-slot saved-world ownership, renaming and full-roster resumption; world restoration after shutdown; return-to-lobby persistence; original art in all required families; complete loot/spawn tuning; final builds and GitHub pushes. The user explicitly authorized Studio gameplay and published multi-server checks for this goal.
