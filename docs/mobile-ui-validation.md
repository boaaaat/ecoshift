# Mobile UI and controls — September 8, 2026

## Implemented

- Touch-first, screen-filling scrolling layouts for crafting, workbenches, recursive recipe help, settings, field guide, world controls, crew/classes/world archive, and death results. Close controls remain accessible while scrolling; desktop geometry restores when switching input modes.
- Vitals and tappable minimap at the top on phones, clock raised, crew/settings beside Roblox's top-left controls. Removed the separate mobile map shortcut. Compact portrait and narrow landscape layouts keep navigation clear of movement, jump, sprint, tool actions and hotbar.
- Hold Sprint, hold/release tool action (harvesting, melee, bow draw/release and shield block), centered touch aiming, and Place/Rotate/Cancel/Salvage controls. Gameplay controls cancel or hide during menus, death and placement as appropriate. Server validates quarter-turn build rotations.
- Touch inventory dragging, tap-to-transfer in either direction with a chest open, touch item context actions, readable item labels and close targets. The touch hit-test fix avoids subtracting the GUI inset twice. Mobile hotbar hides behind unrelated menus and during placement.
- Touch Previous/Next/Stop spectating controls and larger, stable results panels.

## Verification performed

- Rojo builds passed for Expedition and Lobby; Git whitespace check passed. Both Studio places were compared against all 152 local Lua sources using normalized source lengths and Adler-32 checksums.
- Studio phone emulation used iPhone 17 Pro and iPhone 7, landscape and portrait. Inspected HUD, inventory, chest, crafting, atlas, building, lobby crew/classes and results. The last compact portrait viewport was 374×666: navigation ended at Y344, action began at Y352 and ended at Y416, hotbar occupied Y432–504, and native jump began at Y518. Narrow landscape navigation also cleared the action button.
- Actual emulated touch on Sprint produced server requests `true,false`, reached WalkSpeed 24 from 16 while moving, consumed stamina to 98.77, and returned to 16 after release. Temporary movement observation was confined to Play mode.
- Actual touch drag moved ForestWood ×30 from Hotbar[2] to Storage[3], confirmed by the running server's inventory log. Touching a chest stack took ReedFiber ×5 into storage; touching the inventory stack returned all five to the chest. Server Take/Put logs and rendered slot contents confirmed both operations.
- Tapping the minimap opened the atlas, set menu cursor capture and hid Sprint. Actual touch hotbar input equipped Harvester; its action button fired one native Tool.Activated and one Tool.Deactivated event.
- Actual touch selected Workbench, rotated its preview to 90°, and placed a server-owned Workbench at (-6, 2, -18) with the requested quarter-turn. Cancel restored the HUD.
- A natural team wipe displayed readable results in portrait and scrollable results in landscape. Container position remained (0,0) during a bounded stability check. Lobby mobile class cards remained readable while scrolling; switching its simulator off restored the desktop layout.
- Fresh final Expedition and Lobby sessions reported no game-script errors. Initial checks caught and fixed a ScreenGui label ZIndex error, stale Rojo source after an encoding error, duplicate mobile close buttons and several control overlaps.

## Limits and cleanup

### Lobby layout correction

The first mobile lobby layout still forced the entire desk through a tall outer scroll area. It has been replaced with a fixed viewport: a compact header and persistent tabs, six crew cards, a separate action area, and a fixed feedback line. Landscape uses a 3-by-2 crew grid with actions alongside it; portrait uses 2-by-3 cards with actions below. Only classes, friends, invitations and saved-world lists scroll. Pending invitations have their own inbox, and crew profiles use a compact modal.

Studio iPhone 7 checks used a six-member display fixture (no real party or save mutations). At 666×374 landscape and 374×666 portrait, every crew card and party action remained inside the content bounds with scrolling disabled. The final landscape readiness label displayed both `Engineer` and `NOT READY` within its 116×33 area. Class cards formed a two-column list in portrait, and switching back to desktop restored the original desktop arrangement. Both Rojo builds and the whitespace check passed; Studio reported no script errors. The updated lobby script was compared against local source in both Studio places, and Play/device emulation were stopped afterward.

- These are Studio emulator checks, not physical-device performance or simultaneous multi-finger hardware testing. Bow/shield touch wiring and spectate navigation were reviewed but not exercised with a live crew in this pass. Existing deferred multi-server crew checks remain pending.
- Temporary inventory, chest, movement observer and placed Workbench existed only in Play mode. Both sessions were stopped and device simulation reset. No real saved-world records were changed. Nothing was published to Roblox; the user handles publishing.

## Compact icon HUD — September 9, 2026

Replaced mobile navigation and sprint/tool/placement labels with local line icons, translucent backgrounds and amber touch feedback. Mobile vitals occupy a 184×90 card; swiping horizontally exchanges vitals and biome conditions with a 0.24-second animation. The minimap occupies a 106×106 device-safe top-right corner, with no range label or duplicate map button. The clock shares the upper shortcut row where space permits; narrow portrait layouts use the row immediately below Roblox's controls. Mobile shortcuts and minimap hide while menus are open so they cannot cover headers or close buttons. The hotbar uses 48px slots and a harvester glyph during gameplay.

Verified in Studio iPhone 7 landscape/portrait and iPhone 17 Pro landscape emulation. Native touch swipes switched both directions; the final portrait swipe changed the biome page with zero camera direction change and no menu opening. Sprint hold feedback changed true→false on release. Touch hotbar input equipped the harvester, and its action icon fired exactly one Tool.Activated event. Tapping the minimap opened the atlas and hid sprint/tool controls; its close button remained usable. The final portrait atlas screenshot confirmed that the topbar no longer overlaps its header. Disabling emulation restored desktop HUD parents, sizes and keyboard labels, and hid touch sprint.

Both Rojo servers were restarted after the computer restart and both Studio plugins reconnected to their respective ports (34872 expedition, 34873 lobby). All 152 Lua sources matched local normalized lengths/checksums in both places. Both Rojo builds and Git whitespace validation passed. Fresh Expedition and Lobby console checks completed without game-script errors. These checks use Studio emulation; physical-device and simultaneous multi-finger hardware checks remain unverified. Nothing was published to Roblox.

## Touch corrections and starter combat balance — September 9, 2026

- Mobile secondary status tracks now span 55px (previously 13px), with values above the track. Health retains its full-width track.
- Mobile settings have one scrolling viewport: preference rows move into a non-scrolling frame, followed by status and footer actions. Desktop retains its inner preference list. Native touch dragging inside preference rows reached the footer (outer CanvasPosition Y408; hidden desktop list stayed Y0).
- Atlas input excludes the visible legend from drag, wheel zoom and pinch areas. Native legend scrolling reached Y306 with zero change in the player marker's map position.
- Harvester uses world tap gestures on mobile with its crosshair retained; its separate action button is hidden. Native world tap produced one Tool.Activated and one server Harvest request; a camera drag produced no extra activation. Gameplay/UI input guards remain in place.
- Fixed the live team-wipe return button retaining Active=false from its earlier hidden state. A bounded check of the actual source branch confirmed hidden/inactive before wipe, visible/active/interactable after wipe, disabled while pending and enabled again for retry. Actual published teleport was not exercised from Studio.

Wolf, Scorpion and Giant Leech groups are now 1–2. Fresh level-one checks confirmed Wolf 56HP/4.5 damage/4.8 range; Scorpion 52HP/6 damage/4 range; Giant Leech 60HP/4 damage/3.2 range. This applies damage×0.5, health×0.8 and attack-range×0.8 to those starter species while retaining level scaling. All monster humanoids use a 7-stud JumpHeight. Existing saved monster HP is preserved until the next fresh spawn.

Melee now resolves one tagged living target within a bounded forward sweep instead of requiring an exact client ray hit. Reach is weapon range+3.5 studs, with an extra0.75 on mobile, capped at14. Half-width is2.5 desktop/3.25 mobile; vertical root tolerance4.5. Solid cover still blocks hits. Server checks using a6-stud-range weapon confirmed an off-center target at(2.3,0,-8) is hit; x3 is missed on desktop and hit on mobile; x4, a target behind the player, a target12 studs away and a target behind a wall all miss. Two targets in the sweep took damage on only one target. Immediate repeat use was blocked. Fixtures existed only in Play mode and were cleaned up.
