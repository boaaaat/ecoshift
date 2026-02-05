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

Entry fields:
- `Id`
- `Min` / `Max`
- `Weight`
- `MinTier` / `MaxTier`
- `Chance` (0-1, or 0-100 percent)

Table fields:
- `Rolls` (number or `{min,max}`)
- `Unique` / `AllowDuplicates`
- `Guaranteed` (always rolled, still tier/chance-gated)

### Folder format

You can also use folder/config objects under `LootTables`:
- Table-level values: `Rolls`, `MinRolls`, `MaxRolls`, `Unique`
- Child folders/configurations per item with `Min`, `Max`, `Weight`, `MinTier`, `MaxTier`

### Binding tables to world entities

`LootService` chooses table names from:
- `LootTable` or `LootTableName` attribute
- `LootTable` or `LootTableName` StringValue
- fallback to `Config.LOOT.DefaultTable`

Chest tier tags:
- `Common_Chest`, `Rare_Chest`, `Legendary_Chest`, `Celestial_Chest`

Monster tier tags:
- `Common_Monster`, `Rare_Monster`, `Legendary_Monster`, `Celestial_Monster`

Generic `Monster` tagged entities only drop loot when they have an explicit loot table name.

## Creating Objectives

### 1. Register objective IDs

Edit `src/ReplicatedStorage/Shared/Config.lua`:
- `Config.OBJECTIVES.Pool`
- `Config.OBJECTIVES.DurationSeconds`
- `Config.OBJECTIVES.MaxConcurrent`

Example:

```lua
Config.OBJECTIVES.Pool = {
  { Id = "RelayRepair", MinMinute = 0 },
  { Id = "StormBeacon", MinMinute = 5 },
}
```

### 2. Place objective anchors

`ObjectiveRuntimeService` scans `Workspace/Objectives` for BaseParts where:
- `ObjectiveId` attribute equals your objective ID, or
- part `Name` equals objective ID.

When objective starts, prompts are enabled on matching anchors.

### 3. Progress behavior

Default runtime prompt contributes `0.2` progress per trigger.
Adjust this in:
- `src/ServerScriptService/Services/ObjectiveRuntimeService.lua`

You can also progress objectives from custom interactions:
- Send `Interact` remote with action `ObjectiveProgress`
- Payload: `{ ObjectiveId = "StormBeacon", Delta = 0.1 }`

### 4. Lifecycle hooks

`ObjectiveService` publishes global callbacks:
- `_G.Ecoshift.OnObjectiveStartAdd(fn)`
- `_G.Ecoshift.OnObjectiveProgressAdd(fn)`
- `_G.Ecoshift.OnObjectiveEndAdd(fn)`

Use these to award rewards, spawn waves, update UI logic, etc.

## Terrain and World Generation

### Terrain slab

`TerrainService` currently creates one flat terrain block per biome generation.
Material is selected from:
- `src/ReplicatedStorage/Shared/BiomeConfig.lua`
- `Config.TERRAIN.MaterialByBiome[BiomeName]`

World dimensions come from:
- `Config.WORLD.WorldRadius`
- `Config.WORLD.BaseY`
- `Config.TERRAIN.Thickness`

### Streaming chunk generation (default)

Enabled by default via `BiomeConfig.use_streaming = true`.
`ChunkStreamingService` loads chunks around players and unloads distant chunks.

Important config keys in `BiomeConfig.lua`:
- `chunk_size`
- `stream_load_radius`
- `stream_unload_radius`
- `stream_update_interval`
- `stream_unload_delay`
- `world_radius`
- `center_exclusion_radius`

Per-biome content config (`Config.biomes[BiomeName]`):
- `region_count`
- `regions[]` with `resource_count`, `prop_count`, `enemy_count`
- `structures` + `structure_count` (probability per chunk)
- `objectives` + `objective_count` (probability per chunk)
- `chests` + `chest_count` (probability per chunk)

Distance-based scaling is supported with `DistanceWeight` on entries.

### Legacy full-world generation

If you set `use_streaming = false`, `WorldGenController` uses `WorldGen/BiomeGenerator.lua` to generate full map content up front.

## Biomes, Threat, Events, and Spawning

### Biome rotation

`BiomeService` rotates active biome using:
- `BiomeConfig.BIOME_SHIFT.MinSeconds`
- `BiomeConfig.BIOME_SHIFT.MaxSeconds`
- weighted `BiomeConfig.BIOMES`

### Threat and dynamic pressure

`ThreatService` raises/lower threat over time and objective outcomes.
`SpawnService` uses threat + player count + biome tables to compute wave requests.

### Enemy definitions

Edit `src/ServerScriptService/AI/EntityConfig.lua`:
- `Entities[Id].AI`
- `Entities[Id].Spawn`
- `EnemyWaves.Tables`

Enemy spawn tuning supports:
- `Weight`, `TimeScaledWeight`
- `DistanceWeight`
- `MinDistance`, `MaxDistance`
- `GroupSize`, `GroupRadius`
- `MaxPerWave`

## Crafting, Building, Inventory

### Crafting recipes and stations

Primary recipe source:
- `src/ReplicatedStorage/Shared/WorkbenchConfig.lua`

Recipe supports:
- `Ingredients`
- `Output`
- `StationTier` or `StationType`
- `Category`

Station metadata in `WorkbenchConfig.STATIONS` controls interaction radius and tier.

### Building

`BuildService` validates placement through `GridService` and world bounds from `BiomeConfig.WORLD`.

If build type is in `Config.BUILD.PlaceableItems`, placement consumes an inventory item.
Otherwise it uses `Config.BUILD.Costs` resource costs.

### Inventory

`InventoryService` is authoritative for slot state and stacking.
`InventoryActionService` handles remote actions (`Move`, `Split`, `Equip`).

## End-to-End Example: Add a New Biome Resource Loop

1. Add new item IDs in `ItemDatabase.lua`.
2. Add resource prefabs to `ServerStorage/ResourcePrefabs/<BiomeName>`.
3. Reference those prefab names in `BiomeConfig.lua` under `biomes.<Biome>.regions[].resources`.
4. Add crafting recipes in `WorkbenchConfig.RECIPES` that consume the new resources.
5. Add loot table entries in `ServerStorage/LootTables` so chests/monsters can drop them.
6. If needed, add `ServerStorage/GameItems/<ItemId>` and `ServerStorage/Tools/<ItemId>` models.

## Common Pitfalls

- Item IDs must match exactly across `ItemDatabase`, recipes, loot tables, prefabs, and tool names.
- If chest prompt appears but no loot, verify chest has valid loot table reference or `Default` table exists.
- If objective prompts never appear, confirm anchor is in `Workspace/Objectives` and `ObjectiveId` matches `Config.OBJECTIVES.Pool` entry.
- If terrain/world looks empty in streaming mode, verify prefab folder names and biome subfolder names match biome IDs.
- If a holdable item will not equip, confirm it has `Holdable` tag and matching `ServerStorage/Tools/<ItemId>` tool.

## Files You Will Edit Most

- `src/ReplicatedStorage/Shared/Items/ItemDatabase.lua`
- `src/ReplicatedStorage/Shared/WorkbenchConfig.lua`
- `src/ReplicatedStorage/Shared/Config.lua`
- `src/ReplicatedStorage/Shared/BiomeConfig.lua`
- `src/ServerScriptService/AI/EntityConfig.lua`
- `src/ServerScriptService/Services/LootTableService.lua`
- `src/ServerScriptService/Services/ObjectiveService.lua`
- `src/ServerScriptService/Services/ObjectiveRuntimeService.lua`
- `src/ServerScriptService/Services/ChunkStreamingService.lua`
