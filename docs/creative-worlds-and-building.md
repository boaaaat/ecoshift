# Creative worlds and held-item building

From the lobby, the leader presses Start Expedition, chooses Survival or Creative, then confirms the launch. The world type is permanent for that save. Existing saves default to Survival. The existing crew/save-slot/resume rules apply to both types.

Everyone in a Creative world can open the Creative field kit. Its Items page searches names, IDs and tags, filters categories, and adds the selected quantity when inventory space permits. World controls change the implemented biome, its available weather, time of day, shift timer, vitals, invincibility, monster spawns/clearing, and spawn teleport. Commands are validated by the server and display pending/result feedback.

The mode button switches individual players between Creative and Survival. Creative starts invincible; invincibility can be disabled separately. Creative building keeps the held item instead of consuming it. Switching to Creative while dead recovers the player without granting another starter kit. Personal mode/invincibility are saved. Creative worlds do not terminal-wipe when all players die, so their controls remain available for recovery.

Creative-origin worlds never award Field Marks, account XP or class XP, including while playing Survival. World identity is checked against durable launch/save records; normal Survival worlds do not authorize creative remotes. Admin actions do not publish or edit the place source.

## Building controls

- The build menu and its HUD shortcut are removed. Equip a buildable item in a hotbar slot to preview placement; switch items to leave placement.
- PC: right-click places; R rotates unless that key is already assigned (the displayed alternative is used). Hold left-click on an owned structure for three seconds to salvage it. Gamepad: L2 places and R2 holds salvage. Mobile: place/rotate icons and a hold-to-salvage icon.
- Releasing, changing targets, opening a menu, losing focus, leaving range or losing the character cancels salvage. An amber highlight and progress bar show the target and countdown. Server timing, heartbeat, ownership, range and obstruction checks enforce the hold.
- Salvage returns the placed item and spills chest contents. Inventory must have room for the returned build. Camp boundaries, grid occupancy and placement support rules still apply.
- Wall, Floor, Ramp, Gate, Tower, Trap and Machine are craftable inventory items, using their previous material costs. These basic recipes appear in the field menu, Workbench and Advanced Workbench. Builder construction discounts apply only to these structural material costs and round up per ingredient. Stations do not gain discounts.

Inventory and chest tooltips share a screen-clamped overlay above both panels. Their width and text are approximately 50% larger than the previous inventory tooltip, include item descriptions, and wrap longer text.

## Verification status

Source review and whitespace checks only. No automated tests, smoke tests or gameplay sessions were created or run. Runtime verification of launch/resume across places, touch controls, mode recovery, rewards staying disabled, item grants, held-item placement and cancelled/completed salvage remains pending user authorization. Roblox publishing remains with the user.
