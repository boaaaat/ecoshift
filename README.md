# Ecoshift – Systems Guide

This README explains **every system** in the project and how to use/extend it. It’s written for editing the game’s systems while leaving content (items/biomes/etc.) flexible.

---

## Quick Start

1) **Required folders (ServerStorage)**
- `ResourcePrefabs/<BiomeName>/...` (resources)
- `StructurePrefabs/<BiomeName>/...`
- `PropPrefabs/<BiomeName>/...`
- `ObjectivePrefabs/<BiomeName>/...`
- `EnemyPrefabs/<BiomeName>/...` (AI enemies)
- `GameItems/<ItemId>` (pickup models for drops)
- `Tools/Harvester` (tool template; contains Damage/Range/Cooldown)
- `LootTables/<TableName>` (ModuleScripts that return loot table data)

2) **Run** Studio; `ServerMain.server.lua` boots all services.

3) **Customize** biomes in `WorldGen/BiomeConfig.lua` and entities in `AI/EntityConfig.lua`.

---

## World Generation

### BiomeGenerator
**File:** `src/ServerScriptService/WorldGen/BiomeGenerator.lua` (ModuleScript)

**Purpose:** Creates the 2D world with regions, resources, props, structures, objectives, and enemies. No overlap; ignores center exclusion radius; generates in steps to reduce lag.

**How to use:**
- Edit `WorldGen/BiomeConfig.lua`:
  - `world_radius`, `chunk_size`, `max_chunks`, `center_exclusion_radius`.
  - `biomes` table: regions, resources, props, structure/objective probability.
- Set `use_entity_config_enemies = true` to use `AI/EntityConfig.lua` for enemy spawning.
- Each region definition controls resource/prop/enemy counts and sizes.
- Each prefab can include a `NumberValue` named `Offset` to adjust Y placement.

### BiomeConfig
**File:** `src/ServerScriptService/WorldGen/BiomeConfig.lua`

**Purpose:** Main generation tuning + biome data.

**How to use:**
- Add/remove biomes and regions.
- Configure `structure_count`/`objective_count` as **probability per chunk** (max 1 per chunk).
- Configure `resource_count`, `prop_count`, `enemy_count` as min/max ranges.

### WorldGenController
**File:** `src/ServerScriptService/Services/WorldGenController.lua`

**Purpose:** Calls BiomeGenerator, handles re-generation and informs other systems.

**How to use:**
- Called by `ServerMain`. You can trigger regeneration or rescan logic here.

### TerrainService
**File:** `src/ServerScriptService/Services/TerrainService.lua`

**Purpose:** Creates a base Terrain slab (size = world) and paints material to match current biome.

**How to use:**
- Edit materials in `Shared/Config.lua` under `Config.TERRAIN.MaterialByBiome`.

---

## Grid & Building

### GridService
**File:** `src/ServerScriptService/Services/GridService.lua`

**Purpose:** Grid placement logic for building and snapping.

**How to use:**
- Edit grid size in `Shared/Config.lua` → `Config.GRID.Size`.
- Used by BuildService to validate placement.

### BuildService
**File:** `src/ServerScriptService/Services/BuildService.lua`

**Purpose:** Build placement, validation, and decay/biome interactions.

**How to use:**
- Clients request builds via remote `Build`.
- On biome change, BuildService performs decay/cleanup (if enabled).

---

## Inventory & Items

### Items OOP
**Files:**
- `src/ReplicatedStorage/Shared/Items/Item.lua`
- `src/ReplicatedStorage/Shared/Items/ItemDatabase.lua`

**Purpose:** Item definitions (id, name, icon, max stack). Easy to extend.

**How to use:**
- Add item entries in `ItemDatabase` with `Id`, `Name`, `Icon`, `MaxStack`.
- Items referenced by `Id` in loot tables, resource drops, crafting, etc.

### InventoryService
**File:** `src/ServerScriptService/Services/InventoryService.lua`

**Purpose:** Server-side inventory data + stack logic. Supports hotbar, storage, armor.

**How to use:**
- `Give(player, itemId, count)` to add items.
- `Move` handles drag/drop + stacking (same item stacks).
- Supports `Split` and direct slot adds (`TryAddToSlot`).

### InventoryActionService
**File:** `src/ServerScriptService/Services/InventoryActionService.lua`

**Purpose:** Remote actions from UI (move, split, equip, drop, etc.).

**How to use:**
- Client fires `InventoryAction` with actions.
- Service validates and applies to InventoryService.

### Inventory UI
**File:** `src/StarterPlayer/StarterPlayerScripts/InventoryUI.client.lua`

**Purpose:** Client inventory UI (hotbar 1–4, storage 10, armor slot). Drag & drop, shift-click, right-click menu.

**How to use:**
- Customize layout and styling here.
- Shift-click: moves between hotbar/storage.
- Right-click: menu for Drop/Split.

### ArmorService
**File:** `src/ServerScriptService/Services/ArmorService.lua`

**Purpose:** Equip/unequip armor slot and apply stats.

**How to use:**
- Any item in armor slot triggers equip logic.

### ToolService
**File:** `src/ServerScriptService/Services/ToolService.lua`

**Purpose:** Manages tools in inventory, equips, and syncs to character.

**How to use:**
- Tools are cloned from `ServerStorage/Tools`.

---

## Harvesting & Resources

### ResourceService
**File:** `src/ServerScriptService/ResourceService.lua`

**Purpose:** Core harvesting logic (health-based + tool damage). Sends harvest feedback UI.

**How to use:**
- **Resource prefab values**:
  - `Health` (int): hits required.
  - `Duration` (float): hold prompt; auto-add item to inventory.
  - `DropItemId` / `DropCount` or `DropMin`/`DropMax`.
  - `Weakness` (tool type for bonus damage).
- Tool stats are read from tool values (`Damage`, `Range`, `Cooldown`).

### ResourceNodeService
**File:** `src/ServerScriptService/Services/ResourceNodeService.lua`

**Purpose:** Adds ProximityPrompts to duration resources in **batches**.

**How to use:**
- Rate limit controlled by `Config.PROMPTS.MaxPerSecond`.

### HarvestingManager
**File:** `src/ServerScriptService/HarvestingManager.lua`

**Purpose:** Legacy interface and logging for harvest requests.

### Harvester Tool
**ServerStorage:** `Tools/Harvester`

**How to use:**
- Must have `Damage`, `Range`, `Cooldown` values.
- Starter items spawn this tool in hotbar slot 1.

### Harvester Client
**File:** `src/StarterPlayer/StarterPlayerScripts/HarvesterClient.client.lua`

**Purpose:** Handles click/hold harvesting, sends requests to server, debug prints.

---

## Loot & Chests

### LootTableService
**File:** `src/ServerScriptService/Services/LootTableService.lua`

**Purpose:** Rolls loot from `ServerStorage/LootTables` ModuleScripts.

**How to use:**
- Loot table format:
  ```lua
  return {
    Rolls = { min = 2, max = 5 },
    TierWeightMult = { [1]=1.0, [2]=1.35, [3]=1.75, [4]=2.2 },
    Items = {
      { Id = "Wood", Min = 1, Max = 3, Weight = 10, MinTier = 1 },
      { Id = "RareGem", Min = 1, Max = 1, Weight = 1, MinTier = 3 },
    },
  }
  ```

### LootService
**File:** `src/ServerScriptService/Services/LootService.lua`

**Purpose:**
- Adds prompts to chests via CollectionService tags.
- Opens chest UI and syncs chest contents.
- Handles monster loot drops on death.

**How to use:**
- Tag chests with:
  - `Common_Chest`, `Rare_Chest`, `Legendary_Chest`, `Celestial_Chest`.
- Tag monsters with:
  - `Common_Monster`, `Rare_Monster`, `Legendary_Monster`, `Celestial_Monster`.
- Set `LootTable` attribute or StringValue on chest/monster.

### Chest UI
**File:** `src/StarterPlayer/StarterPlayerScripts/ChestUI.client.lua`

**Purpose:** Shows chest inventory; drag into player inventory; shift-click support.

---

## Drops & Pickups

### ItemDropService
**File:** `src/ServerScriptService/Services/ItemDropService.lua`

**Purpose:** Spawns pickup items from `ServerStorage/GameItems`.

### DropItemService
**File:** `src/ServerScriptService/Services/DropItemService.lua`

**Purpose:** Handles player “Drop” actions from inventory UI.

---

## AI System (Monsters + Animals)

### EntityConfig (central AI + spawn config)
**File:** `src/ServerScriptService/AI/EntityConfig.lua`

**Purpose:** One place to define **AI tuning + spawn rules**.

**How to use:**
- Add new entities under `EntityConfig.Entities`:
  - `Type = "Monster" | "Animal"`
  - `AIClass = "Wolf"` (custom AI module name)
  - `AI = { ... }` (detection, damage, speed, etc.)
  - `Spawn = { Weight, TimeScaledWeight, GroupSize, Biomes = { ... } }`

### Entity AI Runtime
**Files:**
- `src/ServerScriptService/Services/EntityAIService.lua`
- `src/ServerScriptService/AI/EntityBase.lua`
- `src/ServerScriptService/AI/Monster.lua`
- `src/ServerScriptService/AI/Animal.lua`
- `src/ServerScriptService/AI/Wolf.lua`

**Purpose:** Pathfinding, detection (angle + distance), auto detect radius, target selection by priority, attack ranges.

**How to use:**
- Tag monsters with `Monster` and animals with `Animal` (auto-tagged by worldgen/spawner).
- Set attributes or values on models to override config.
- Add custom AI by creating a module in `AI/` and setting `AIClass`.

**Wolf example:**
- Spawns in Forest; extra weight in `ThickGrove` region.
- Pack boosts speed/attack.

---

## Enemy Spawning

### SpawnService
**File:** `src/ServerScriptService/Services/SpawnService.lua`

**Purpose:** Builds enemy wave IDs based on biome and threat.

**How to use:**
- Edit `EntityConfig.EnemyWaves` in `AI/EntityConfig.lua`.
- `Config.BIOMES[biome].enemyTables` decides which table(s) are active per biome.
- Currently only Wolf spawns in Forest.

### EnemySpawner
**Files:**
- `src/ServerScriptService/EnemySpawner.lua`
- `src/ServerScriptService/Services/EnemySpawner.lua`

**Purpose:** Places enemy prefabs in world using spawn points and safe raycast.

**How to use:**
- Ensure enemy prefabs exist in ServerStorage.
- Spawner auto-tags new enemies for AI.

### SpawnerOrchestrator
**File:** `src/ServerScriptService/Services/SpawnerOrchestrator.lua`

**Purpose:** Requests waves from SpawnService and triggers EnemySpawner callbacks.

---

## Biome Shifts & Game Loop

### BiomeService
**File:** `src/ServerScriptService/Services/BiomeService.lua`

**Purpose:** Stores and broadcasts current biome; used by other services.

### GameLoopService
**File:** `src/ServerScriptService/Services/GameLoopService.lua`

**Purpose:** Cycles core loop; handles biome shift timings.

### DayNightService
**File:** `src/ServerScriptService/Services/DayNightService.lua`

**Purpose:** Tracks time-of-day, broadcasts to clients, and applies night multipliers.

### RoundService / GameStateService
**Files:**
- `src/ServerScriptService/Services/RoundService.lua`
- `src/ServerScriptService/Services/GameStateService.lua`

**Purpose:** Round lifecycle and match state.

---

## Objectives & Events

### ObjectiveService + Runtime
**Files:**
- `src/ServerScriptService/Services/ObjectiveService.lua`
- `src/ServerScriptService/Services/ObjectiveRuntimeService.lua`
- `src/ServerScriptService/Services/ObjectiveBootstrap.lua`

**Purpose:** Chooses objectives, spawns, tracks completion.

### EventService + Effects
**Files:**
- `src/ServerScriptService/Services/EventService.lua`
- `src/ServerScriptService/Services/EventEffectsService.lua`

**Purpose:** Random events (meteor, fog, etc.) and world effects.

### ThreatService
**File:** `src/ServerScriptService/Services/ThreatService.lua`

**Purpose:** Threat scaling over time; used for wave strength.

---

## Roles, Combat, Status

### RoleService
**File:** `src/ServerScriptService/Services/RoleService.lua`

**Purpose:** Assigns player roles and multipliers (gather, combat, build).

### CombatService
**File:** `src/ServerScriptService/Services/CombatService.lua`

**Purpose:** Handles damage events and combat remotes.

### StatusService
**File:** `src/ServerScriptService/Services/StatusService.lua`

**Purpose:** Buff/debuff and status management.

---

## Crafting

### CraftingService + Bootstrap
**Files:**
- `src/ServerScriptService/Services/CraftingService.lua`
- `src/ServerScriptService/Bootstrap/CraftingBootstrap.lua`
- `src/StarterPlayer/StarterPlayerScripts/CraftingUI.client.lua`

**Purpose:** Workbench crafting, recipe validation, UI.

**How to use:**
- Recipes live in `Shared/Config.lua` under `Config.RECIPES`.

---

## Persistence

### ProfileService
**File:** `src/ServerScriptService/Services/ProfileService.lua`

**Purpose:** DataStore persistence for player profiles/inventory.

**How to use:**
- Configure store name in `Shared/Config.lua` → `Config.DATASTORE`.

---

## UI & Client Systems

### MainHUD
**File:** `src/StarterPlayer/StarterPlayerScripts/MainHUD.client.lua`

**Purpose:** Shows biome, time, role, and buttons.

### Inventory UI
**File:** `src/StarterPlayer/StarterPlayerScripts/InventoryUI.client.lua`

**Purpose:** Inventory interface, hotbar, armor slot, drag‑swap, shift click, right‑click menu.

### Chest UI
**File:** `src/StarterPlayer/StarterPlayerScripts/ChestUI.client.lua`

**Purpose:** Looting interface for chests.

### HarvestFeedback UI
**File:** `src/StarterPlayer/StarterPlayerScripts/HarvestFeedbackUI.client.lua`

**Purpose:** Damage numbers + linear health bar feedback for harvesting.

### DayNightClient
**File:** `src/StarterPlayer/StarterPlayerScripts/DayNightClient.client.lua`

**Purpose:** Client side day/night visuals.

---

## Bootstrapping

### ServerMain
**File:** `src/ServerScriptService/ServerMain.lua`

**Purpose:** Initializes all services in priority tiers.

### RemotesBootstrap
**File:** `src/ServerScriptService/RemotesBootstrap.server.lua`

**Purpose:** Creates RemoteEvents under `ReplicatedStorage/Remotes`.

### WorldFoldersBootstrap
**File:** `src/ServerScriptService/WorldFoldersBootstrap.server.lua`

**Purpose:** Ensures key Workspace folders exist (Resources, Objectives, etc.).

### PlayerBootstrap
**File:** `src/ServerScriptService/PlayerBootstrap.lua`

**Purpose:** Sets starter inventory, role defaults, and hooks player events.

---

## Other Systems & Utilities

### ChunkStreamingService (optional)
**File:** `src/ServerScriptService/Services/ChunkStreamingService.lua`

**Purpose:** Experimental runtime chunk loading/unloading around players.

**How to use:**\n- Not currently initialized in `ServerMain`. Add to init list if you want streaming.\n- Config reads from `WorldGen/BiomeConfig.lua` (stream_* settings).

### AIService (legacy)
**File:** `src/ServerScriptService/Services/AIService.lua`

**Purpose:** Old targeting helper; kept for compatibility.

### InteractService
**File:** `src/ServerScriptService/Services/InteractService.lua`

**Purpose:** Handles generic interaction remote (`Interact`).

### RewardsObserver
**File:** `src/ServerScriptService/Services/RewardsObserver.lua`

**Purpose:** Grants rewards + XP on objective completion.

### WorldBuilder (placeholder)
**File:** `src/ServerScriptService/Services/WorldBuilder.lua`

**Purpose:** Placeholder for future terrain/material passes.

### WorldGenServer (bootstrap)
**File:** `src/ServerScriptService/WorldGenServer.lua`

**Purpose:** Convenience bootstrap for WorldGenController (not required if using `ServerMain`).

### Utilities / Adapters
**Files:**\n- `src/ReplicatedStorage/Shared/Util.lua`\n- `src/ReplicatedStorage/Shared/InventoryAdapter.lua`\n- `src/ReplicatedStorage/Modules/ToolConfig.lua`

**Purpose:**\n- `Util`: helpers (weighted choice, remote lookup, waits).\n- `InventoryAdapter`: thin adapter for services wanting inventory access.\n- `ToolConfig`: reads tool stats (Damage/Range/Cooldown/ToolType).

---

## Adding New Content (Summary)

- **New biome:** edit `WorldGen/BiomeConfig.lua` and add matching prefab folders under ServerStorage.
- **New resource/prop/structure:** place prefab under matching biome folder, add to region lists.
- **New enemy/animal:**
  1) Add prefab under `ServerStorage/EnemyPrefabs/<BiomeName>`.
  2) Add entry in `AI/EntityConfig.lua` with Spawn rules.
  3) (Optional) Add custom AI module and set `AIClass`.
- **New item:** add to `Shared/Items/ItemDatabase.lua` and create `GameItems/<Id>` model for pickups.
- **New loot table:** add ModuleScript under `ServerStorage/LootTables`.

---

## Notes

- Only **Wolf** spawns for now (forest only). Update `Shared/Config.lua` and `AI/EntityConfig.lua` to add more monsters later.
- Most systems are modular; you can disable them by removing or no‑op’ing the service `Init/Bind` calls in `ServerMain`.
