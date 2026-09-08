# Ecoshift Developer Guide

This guide is for developers extending game systems and content in this repo.

The current prototype has eight playable biomes and eight future biome concepts. Aurora Vale and Starfall Crater complete the current material progression, targeting powerful world-control gear in a 60–90 minute cooperative run.

## Quick Start

1. In VS Code, run the **rojo: serve both** task. Alternatively, run `scripts/rojo-serve.ps1` for Expedition and `scripts/rojo-serve.ps1 -Place Lobby` in a second terminal. Connect Expedition Studio to `localhost:34872` and Ecoshift (the lobby) Studio to `localhost:34873`. Each project restricts syncing to its corresponding cloud place ID. Both projects preserve authored Studio assets outside the mapped source tree. Keep the Studio plugin and CLI on the same Rojo version; `rojo plugin install` updates the plugin, followed by reopening the place.
2. RuntimeBootstrap creates required runtime folders/remotes before gameplay starts. PrototypePrefabService supplies missing resources, tools, enemies, and station models using temporary geometry. Authored models take precedence. Optional authored folders are:
   - `ResourcePrefabs/<BiomeName>`
   - `PropPrefabs/<BiomeName>`
   - `StructurePrefabs/<BiomeName>`
   - `ObjectivePrefabs/<BiomeName>`
   - `EnemyPrefabs/<BiomeName>`
   - `GameItems/<ItemId>` (optional visual drop models)
   - `Tools/<ItemId>` (for holdable tools/weapons)
   - `BuildPrefabs/<BuildType>` (for placeable structures)
   - `LootTables/<TableName>` (ModuleScript or folder-style table)
3. Start the game. `src/ServerScriptService/ServerMain.server.lua` boots services by tier. `.server.lua` and `.client.lua` suffixes are required for Rojo to create executable scripts.

See [the progression plan](docs/game-design.md), [temporary asset sources](docs/temporary-assets.md), and [the gameplay milestone](docs/gameplay-milestone.md) for current behavior and remaining design decisions. Use `scripts/rojo-build.ps1` to produce a local place file; generated builds are ignored by Git.

The field-kit controls are **G** pack, **C** craft, **B** build, **M** map, and **V** survey. Each has a clickable HUD button. Players begin with a harvester. Hold **E** at plants, click tougher resources with the harvester, and hand-craft a Stone Spear or Revival Kit. The next-shift countdown is hidden until FieldClock or an upgraded survey device is carried.

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

**Advanced Schema With Rarity Pools**
```lua
return {
  Name = "ExampleLootTable",
  Rarities = {
    Common = {
      Rolls = { min = 1, max = 3 },
      Items = {
        { Id = "Wood", Min = 2, Max = 6, Weight = 4 },
        { Tag = "Resource", Min = 1, Max = 3, Weight = 2 },
      },
      Guaranteed = {
        { Id = "Torch", Min = 1, Max = 1 },
      },
    },
    Rare = {
      Rolls = 2,
      Unique = true,
      AllowDuplicates = false,
      Items = {
        { Id = "GoldIngot", Min = 1, Max = 2, Weight = 1 },
        { Tag = "Weapon", Min = 1, Max = 1, Weight = 0.5 },
      },
    },
    Legendary = {
      Chance = 0.7,
      Rolls = { min = 1, max = 2 },
      Items = {
        { Id = "Diamond", Min = 1, Max = 2, Weight = 1 },
      },
    },
    Celestial = {
      Chance = 0.4,
      Rolls = 1,
      Items = {
        { Id = "EnchantedBow", Min = 1, Max = 1, Weight = 0.6 },
      },
    },
  },
}
```

**Tag-Based Entries**
You can use tags instead of explicit item IDs. Tags come from `src/ReplicatedStorage/Shared/Items/ItemDatabase.lua`.
```lua
{ Tag = "Weapon", Min = 1, Max = 1, Weight = 0.5 }
```

**Loot Service**
**File:** `src/ServerScriptService/Services/LootService.lua`

**Responsibilities**
- Attaches prompts to chests via CollectionService tags.
- Opens chest UI and syncs inventory slots.
- Rolls loot using `LootTableService`.

**Chest Configuration**
- Set `LootTable` attribute or StringValue on the chest model.
- Structure chest config can set `loot_table` per structure.
- Tier tags control rarity pool selection:
  - `Common_Chest`, `Rare_Chest`, `Legendary_Chest`, `Celestial_Chest`.

**Items And Tags**
**File:** `src/ReplicatedStorage/Shared/Items/ItemDatabase.lua`

Items define tags used by loot tables and other systems.

**Example Tags**
- `Resource`
- `Weapon`
- `Armor`
- `Material`
- `Placeable`

**Spawning Systems**
**ChunkStreamingService**
- Spawns resources, props, structures, objectives, enemies, and chests per chunk.

**Enemy Spawning**
- `SpawnService` builds waves.
- `EnemySpawner` places prefabs using spawn points.

**Notes**
- If a rarity pool exists but has no valid entries, the roll returns empty (strict behavior).
- Folder-based loot tables still use the legacy schema.
