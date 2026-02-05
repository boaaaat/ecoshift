# Ecoshift Developer Guide

This guide is for developers extending game systems and content in this repo.

## Quick Start

1. Open the project in Roblox Studio with this source synced.
2. Ensure required `ServerStorage` folders exist:
   - `ResourcePrefabs/<BiomeName>`
   - `PropPrefabs/<BiomeName>`
   - `StructurePrefabs/<BiomeName>`
   - `ObjectivePrefabs/<BiomeName>`
   - `EnemyPrefabs/<BiomeName>`
   - `GameItems/<ItemId>` (optional visual drop models)
   - `Tools/<ItemId>` (for holdable tools/weapons)
   - `BuildPrefabs/<BuildType>` (for placeable structures)
   - `LootTables/<TableName>` (ModuleScript or folder-style table)
3. Start the game. `src/ServerScriptService/ServerMain.lua` boots services by tier.

## Project Layout

- Server services: `src/ServerScriptService/Services`
- Shared configs/data: `src/ReplicatedStorage/Shared`
- World generation: `src/ServerScriptService/WorldGen`, `src/ReplicatedStorage/Shared/BiomeConfig.lua`
- AI config: `src/ServerScriptService/AI/EntityConfig.lua`
- Client UIs/scripts: `src/StarterPlayer/StarterPlayerScripts`

## Core System Map

- Biomes and world shift: `BiomeService`
- Terrain slab generation: `TerrainService`
- Dynamic chunk loading/world content: `ChunkStreamingService`
- Legacy full-world generation: `WorldGen/BiomeGenerator.lua`
- Loot tables and drops: `LootTableService`, `LootService`, `ItemDropService`
- Objectives: `ObjectiveService`, `ObjectiveRuntimeService`
- Inventory and item actions: `InventoryService`, `InventoryActionService`
- Crafting and stations: `CraftingService`, `Shared/WorkbenchConfig.lua`
- Building placement: `BuildService`, `GridService`
- Enemy wave planning and AI: `SpawnService`, `SpawnerOrchestrator`, `EntityAIService`, `AI/EntityConfig.lua`
- Match pressure loops: `ThreatService`, `EventService`, `StatusService`

## Creating New Items

### 1. Define item data

Edit `src/ReplicatedStorage/Shared/Items/ItemDatabase.lua` and add a definition to `raw`:

```lua
{ Id = "CopperOre", Name = "Copper Ore", StackSize = 99, Tags = { "Resource", "Ore" } },
```

Important fields:
- `Id`: canonical identifier used everywhere.
- `Name`: display text.
- `StackSize`: max stack.
- `Tags`: behavior hints (`Tool`, `Weapon`, `Armor`, `Holdable`, `Placeable`, etc).

### 2. Optional icon

`ItemDatabase` resolves icons from `ReplicatedStorage/ItemIcons/<ItemId>` if present.

### 3. Optional world drop model

If you want a custom pickup model when dropped/looted, add:
- `ServerStorage/GameItems/<ItemId>` (Model)

If missing, the game spawns a fallback part.

### 4. Optional equippable tool/weapon

If item has `Holdable` tag and should equip, create:
- `ServerStorage/Tools/<ItemId>` (Tool)

`ToolService` syncs tools from inventory into backpack/character.

### 5. Optional placeable structure/station

For placeable content (like `Chest`, `Workbench`):
- Add item entry with `Placeable` tag.
- Add build type in `Config.BUILD.AllowedTypes` and `Config.BUILD.PlaceableItems`.
- Add prefab at `ServerStorage/BuildPrefabs/<BuildType>`.

## Creating Loot Tables

Loot tables live in `ServerStorage/LootTables` and are rolled by `LootTableService`.

### ModuleScript format (recommended)

```lua
return {
  Rolls = { min = 2, max = 4 },
  Unique = false,
  TierWeightMult = {
    [1] = 1.0,
    [2] = 1.35,
    [3] = 1.75,
    [4] = 2.2,
  },
  Guaranteed = {
    { Id = "Wood", Min = 1, Max = 3 },
  },
  Items = {
    { Id = "Stone", Min = 1, Max = 2, Weight = 10, MinTier = 1 },
    { Id = "Diamond", Min = 1, Max = 1, Weight = 1, MinTier = 3, Chance = 0.2 },
  },
}
```
# Ecoshift – Systems Documentation

This document describes the core game systems and their configuration surfaces. It is written as developer-facing documentation for complex, configurable systems such as world generation and loot tables.

**Table Of Contents**
1. Overview
2. World Generation (Streaming)
3. Biome Configuration
4. Structure Chests
5. Loot Tables
6. Loot Service
7. Items And Tags
8. Spawning Systems

**Overview**
- The runtime uses **chunk streaming only** for world generation.
- Content is defined through data tables and prefab folders.
- Loot is driven by ModuleScripts in `ServerStorage/LootTables`.

**Key Paths**
- `src/ReplicatedStorage/Shared/BiomeConfig.lua`
- `src/ServerScriptService/Services/ChunkStreamingService.lua`
- `src/ServerScriptService/Services/WorldGenController.lua`
- `src/ServerScriptService/Services/LootTableService.lua`
- `src/ServerScriptService/Services/LootService.lua`
- `src/ReplicatedStorage/Shared/Items/ItemDatabase.lua`

**World Generation (Streaming)**
The world is generated per-player using chunk streaming. This avoids a full world build and dynamically loads/unloads chunks around players.

**Runtime Flow**
1. `WorldGenController` initializes `ChunkStreamingService` and triggers biome generation.
2. `ChunkStreamingService` creates chunk folders under `Workspace/GeneratedWorld`.
3. Each chunk is populated based on the current biome definition.

**Required Folders (ServerStorage)**
- `ResourcePrefabs/<BiomeName>/...`
- `StructurePrefabs/<BiomeName>/...`
- `PropPrefabs/<BiomeName>/...`
- `ObjectivePrefabs/<BiomeName>/...`
- `EnemyPrefabs/<BiomeName>/...`
- `Chests/` (chest models by name)
- `LootTables/` (ModuleScripts defining loot tables)
- `GameItems/` (pickup models for `ItemDropService`)
- `Tools/Harvester` (tool template)

**Biome Configuration**
**File:** `src/ReplicatedStorage/Shared/BiomeConfig.lua`

**Top-Level Settings (selected)**
- `world_radius`
- `center_exclusion_radius`
- `chunk_size`
- `stream_load_radius`
- `stream_unload_radius`
- `stream_update_interval`
- `stream_unload_delay`
- `spawn_folder_name`

**Biome Definitions**
Each biome entry controls resources, props, structures, objectives, and chests. Example keys:
- `regions`
- `region_count`
- `resources`, `resource_count`
- `props`, `prop_count`
- `structures`, `structure_count`
- `objectives`, `objective_count`
- `chests`, `chest_count`

**DistanceWeight**
Many entries support `DistanceWeight` (number or `{ Min, Max }`). This scales spawn likelihood based on distance from the world center.

**Structure Chests**
Structure chest spawns are configured in `Config.structure_chests`.

**Spawn Points**
- Any `BasePart` or `Attachment` named `ChestSpawn` or `ChestSpawn_*` inside a structure prefab.

**Chest Models**
- Resolved from `ServerStorage/Chests` by name.
- Example model names: `Common_Chest`, `Rare_Chest`, `Legendary_Chest`, `Celestial_Chest`.

**Config Fields**
- `count`: number or `{ min, max }` per structure instance.
- `spawn_points`: list of name prefixes, default `{ "ChestSpawn" }`.
- `tier_weights`: per-tier weight with optional `DistanceWeight`.
- `loot_table`: optional LootTable name for all chests in this structure.
- `chests`: list of chest prefab names or weighted entries.

**Example**
```lua
Config.structure_chests = {
  Default = {
    count = { min = 0, max = 1 },
    spawn_points = { "ChestSpawn" },
    tier_weights = {
      Common = { Weight = 1.0, DistanceWeight = 0.6 },
      Rare = { Weight = 0.35, DistanceWeight = 1.2 },
      Legendary = { Weight = 0.12, DistanceWeight = 1.6 },
      Celestial = { Weight = 0.03, DistanceWeight = 2.0 },
    },
    chests = { "Common_Chest", "Rare_Chest" },
  },
  CabinRuin = {
    count = { min = 1, max = 1 },
    loot_table = "ExampleLootTable",
    chests = { "Common_Chest", "Rare_Chest", "Legendary_Chest", "Celestial_Chest" },
  },
}
```

**Loot Tables**
**File:** `src/ServerScriptService/Services/LootTableService.lua`

Loot tables are loaded from `ServerStorage/LootTables`. ModuleScripts can use the legacy schema or the advanced schema with rarity pools.

**Rarity Mapping**
- Tier 1 = Common
- Tier 2 = Rare
- Tier 3 = Legendary
- Tier 4 = Celestial

**Legacy Schema (still supported)**
```lua
return {
  Rolls = { min = 2, max = 5 },
  TierWeightMult = { [1] = 1.0, [2] = 1.35, [3] = 1.75, [4] = 2.2 },
  Items = {
    { Id = "Wood", Min = 1, Max = 3, Weight = 10, MinTier = 1 },
    { Id = "GoldIngot", Min = 1, Max = 1, Weight = 1, MinTier = 3 },
  },
  Guaranteed = {
    { Id = "Torch", Min = 1, Max = 1 },
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

**Spawn points:**\n- If `Workspace/EnemySpawns` is empty, SpawnService auto-creates invisible spawn points.\n- Tune count/radius in `EntityConfig.SpawnPoints` in `AI/EntityConfig.lua`.

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

**Purpose:** Handles weapon actions, damage validation, and shield blocking.

**Weapon System (new):**
- Weapons are **Tools** with **ValueBase children** (NumberValue/IntValue/StringValue).  
- Required child values by type:
  - **Sword**: `WeaponType = "Sword"`, `Damage`, `Range`, `AttackSpeed`
  - **Bow**: `WeaponType = "Bow"`, `Damage`, `ProjectileSpeed`, `ChargeTime`
  - **Gun**: `WeaponType = "Gun"`, `Damage`, `FireRate`, `Ammo`, `MaxAmmo`
  - **Shield**: `WeaponType = "Shield"`, `Durability`, `BlockPercent`
  - **Throwable**: `WeaponType = "Throwable"`, `Damage`, `ThrowSpeed`, `ThrowTime`

**Base classes (extendable):**
- `ReplicatedStorage/Shared/Weapons/Sword.lua`
- `ReplicatedStorage/Shared/Weapons/Bow.lua`
- `ReplicatedStorage/Shared/Weapons/Gun.lua`
- `ReplicatedStorage/Shared/Weapons/Shield.lua`
- `ReplicatedStorage/Shared/Weapons/Throwable.lua`

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
