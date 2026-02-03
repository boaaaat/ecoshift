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
