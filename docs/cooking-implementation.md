# Cooking implementation checkpoint

This implements the cooking system in gameplay-overhaul-draft.md revision 0.4 against the existing eight-biome game. It does not implement the wider terrain, equipment, enchanting, campaign, or sixteen-biome overhaul.

## Delivered catalog and compatibility

- CookingConfig is the shared source for 16 fixed recipes, automatic per-serving work, three stations, fuel durations, output sizes, snacks, and seasoning effects. Campfire has three recipes; Stove eight; Oven five. No ingredient substitutions or additional cooking stations.
- Campfire remains hand-crafted. Stove costs 10 Forest Stone, 6 Forest Planks and 2 Sandite Ingots; Oven costs 12 Clay Mud, 12 Forest Stone and 4 Sandite Ingots. Both are crafted at Workbench or Advanced Workbench. Their grounded, original low-poly prefabs have distinct burner/chimney shapes.
- Meal tier numbers are catalog metadata. The current game has no eight-tier campaign or station grades. Building the required station and supplying its exact ingredients unlocks that recipe. No invented campaign gates, hidden elapsed-time locks, or future-biome ingredients are enforced.
- Existing ingredient identities remain stable: Mushroom = BrownMushroom; Water = SpringWater; Cactus = CactusStem; Reeds = ReedFiber; Healing Herb = MossBloom; Glowcap = Glowcap. Expedition Meal uses two DawnBloom from the existing late Aurora Vale in place of future Glow Mushroom, preserving a late-biome supply requirement without unreleased ingredients.
- Berries and Root Vegetable are new Forest hand-gathered food nodes (0.8s and 1.1s). Raw Meat is a guaranteed 1–2 drop from Wolf, Sand Serpent, Bog Toad, Frost Wolf and Aurora Stag; raw meat is not consumable. Meat-free Campfire food remains available without fighting.
- Wild Herb, Cool Mint, Bitter Seed, Warm Pepper, Ember Pepper, Crystal Basil and Star Seed have distinct plant prefabs, 0.8–1.1s hand gathering, 2–4 charges per node, and matching biome spawning. Existing DawnBloom supplies Dawn Petal seasoning. All use plant classification consistently for Botanist bonuses and regrowth.
- Eight future seasonings stay in the config with Future=true. They are excluded from output identities, item registration, spawning and the active picker. Sea Salt is a future catalog name, not an invitation to season food with the current unrelated SaltCrystal mineral.
- Shared station fuel is ForestWood 60s, PeatClump 120s and Coal 240s, capped at 60 minutes in one station. Cooking and deliberate Campfire warmth share the same burn time; Keep Warm continues heating even if output blocks cooking. Paused stations use no fuel. Loaded fuel is a consumed charge, not a recoverable inventory item; the Kitchen explains that salvaging discards the remaining charge. The catalog has no food-processing bonus rolls.
- IDs such as TrailMeal__EmberPepper represent a specific meal/seasoning pair. Existing inventory, chest, drop and saved item Id/N paths preserve that identity. Meals keep their simple base display name, a seasoning color, and exact effects in their tooltip. Recipes can be followed through the guide, including a variant's extra seasoning ingredient.
- New solid meals stack to 10; Dried Food and new seasoned Stamina Rations stack to 30. The preexisting unseasoned StaminaRation retains its old item stack capacity to avoid invalidating old saved stacks; the station output still uses the cooking recipe's 30-serving limit.
- Cook level 4 receives a Stove in new cooking-enabled worlds. Cook's existing passives, ability, other kit supplies and class progression are unchanged. Legacy worlds retain the Drying Rack kit.

## World versioning

CookingEnabled=false retains the old food recipes and removes Stove/Oven craft recipes and added food resource/monster drop sources. Existing Drying Racks and non-food processing remain available. Shared config responds when the world version is staged, rather than assuming the first client/module load already knows the save version.

The new station queue, escrow, fuel, output, consumed buffs and version are persisted by their respective server services. Resuming old worlds must leave CookingEnabled false; fresh worlds and saves containing CookingVersion=1 use the new rules. Catalog item identities remain readable in both cases to avoid destructive inventory migration.

## Acceptance scenarios pending user-authorized checks

No tests or smoke tests were created or run for this task. These are a checklist for a later explicitly authorized gameplay session:

- New and legacy worlds select their correct recipe/source/kit behavior, including resume after restart.
- Campfire, Stove and Oven placement previews align with the ground and each prompt opens its own recipe list.
- Each fixed recipe requires exactly its named ingredients and optional one live seasoning per serving; invalid IDs and future seasonings cannot bypass requirements.
- Queue three jobs of 1–20 meals; observe work, pending feedback, fuel, pause/resume, complete output, full-output pause and exact cancellation refunds.
- Two crew members interacting with the same output or cancel operation never duplicate ingredients or meals.
- Disconnect and save during partial work retain fractional fuel/work and do not refund or duplicate completed servings.
- Salvage with pending jobs/output requires safe refund/collection space; ordinary building remains unaffected.
- Seasoned variants transfer/drop/save independently, show exact tooltips, and never stack with different seasoning identities.
- Eating, drink cooldowns, class restoration caps, strongest thermal protection, replacement/refresh and expiry/death behavior match the draft.
- Mobile recipe selection, ingredient back-navigation, quantity, seasoning selection and queue controls work without dragging or nested scrolling.
- Meat-free first-visit meals are obtainable; added ingredients and seasoning plants spawn above ground with correct gathering times and drops.
- Cooking does not credit class activity automatically; Engineer speed and Overclock do not duplicate outputs or exceed the work-rate cap.

Roblox publishing remains the user's responsibility.

## Source delivery

Rojo servers were restarted on expedition port 34872 and lobby port 34873 to include new files. Both Studio instances were open in Edit mode, but their disconnected plugins had not received the source. Windows was locked during reconnection, so Studio sync remains pending until the desktop is unlocked. No gameplay or smoke tests were run, and no Roblox publishing was performed.
