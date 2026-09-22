# Recipe helper

Select a recipe and choose **Track recipe on HUD**. The tracker stays visible when the station closes or the player walks away. Hand crafting, workbenches, the recipe book, furnaces, and cooking details support tracking. Cooking includes the selected seasoning and serving count.

Choose **Track upgrade on HUD** in a station's upgrade menu to track the next upgrade for that specific placed station. Upgrade requirements come from the same station upgrade catalog used by the server, including grade jumps.

The compact HUD shows the next action. Use **+** (or **H** on keyboard) to expand the remaining checklist, **−** to collapse it, and **×** to stop tracking. Selecting another target replaces the current plan. Tracking lasts for the current game session and survives character respawns.

The helper totals shared dependencies, subtracts backpack/hotbar materials, and rounds each missing crafted material to whole recipe batches. It lists missing gathered resources and their sources first, then intermediate crafts in dependency order, then the chosen craft or upgrade. Inventory changes update the remaining work automatically. Craft instructions include station grades, campaign requirements, and fuel/collection reminders.

Accepted direct crafts and last-seen station queues count toward intermediate requirements, with a separate finish/collect step. Station queue state refreshes through the existing station and cooking snapshots; the helper does not open a station menu or send crafting requests. A recipe goal completes when its requested additional output reaches the inventory; an upgrade goal completes when the selected station reaches its target grade.
