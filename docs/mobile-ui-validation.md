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

- These are Studio emulator checks, not physical-device performance or simultaneous multi-finger hardware testing. Bow/shield touch wiring and spectate navigation were reviewed but not exercised with a live crew in this pass. Existing deferred multi-server crew checks remain pending.
- Temporary inventory, chest, movement observer and placed Workbench existed only in Play mode. Both sessions were stopped and device simulation reset. No real saved-world records were changed. Nothing was published to Roblox; the user handles publishing.
