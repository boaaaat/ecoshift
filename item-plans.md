# Ecoshift Itemization Master Plan

## 1. Design goals and progression rules
- Survival-first progression across biome shifts, environmental hazards, and enemy pressure.
- Core loop: gather biome resources -> refine into materials -> craft stations -> craft survivability/combat/intel tools.
- Itemization spans all six target biomes: Forest, Desert, Swamp, FrozenTundra, Volcanic, CrystalWastes.
- Strategic intel devices (`FieldClock`, `BiomePredictor`, `WeatherPredictor`) are gated behind multi-biome materials.
- Monster drops are direct progression keys: each enemy feeds specific recipes and unlock tiers.

## 2. Biome-by-biome resource catalog
### Forest
- Raw: `ForestWood`, `ForestStone`, `ReedFiber`, `ClayMud`, `BrownMushroom`, `MossBloom`, `SapResin`, `SpringWater`
- Enemy drops: `WolfPelt`, `WolfFang`
- Refined: `ForestPlank`, `FiberCloth`, `HerbalPaste`, `TanninOil`

### Desert
- Raw: `CactusStem`, `Sand`, `SandstoneChunk`, `Coal`, `DriedBone`, `SulfiteOre`, `SaltCrystal`, `SunShard`
- Enemy drops: `ScorpionStinger`, `SerpentScale`
- Refined: `BoneMeal`, `CactusFiber`, `SanditeIngot`, `TemperedGlass`, `HeatWrap`

### Swamp
- Raw: `BogReed`, `PeatClump`, `MireStone`, `Glowcap`, `MangroveWood`, `WillowBark`, `MarshWater`, `RootFiber`
- Enemy drops: `LeechVenomSac`, `BogToadGland`
- Refined: `MarshThread`, `PeatBrick`, `AntitoxinPaste`, `BioGel`, `MireComposite`

### FrozenTundra
- Raw: `Frostwood`, `IceCrystal`, `PermafrostOre`, `SnowLichen`, `GlacialStone`, `ChillBloom`, `FrozenReed`
- Enemy drops: `FrostWolfFur`, `WraithEssence`
- Refined: `InsulatedCloth`, `CryoAlloy`, `IceLens`, `HoarfrostPowder`, `ThermalGel`

### Volcanic
- Raw: `BasaltChunk`, `SulfurOre`, `ObsidianShard`, `EmberBloom`, `AshFiber`, `LavaSalt`, `ScoriaRock`
- Enemy drops: `MagmaCore`, `GolemFragment`, `HoundFang`
- Refined: `ObsiditeIngot`, `MagmaGlass`, `HeatPlate`, `VulcanLeather`, `IgnitionPowder`

### CrystalWastes
- Raw: `CrystalShard`, `VoidResidue`, `AlloyDust`, `PhaseQuartz`, `PrismSand`, `EchoBloom`, `LatticeFiber`
- Enemy drops: `SentinelCore`, `StalkerTalon`, `NullFragment`
- Refined: `ResonantCrystal`, `VoidAlloy`, `PhaseCircuit`, `PrismGlass`, `QuantumThread`

## 3. Refined material catalog
- Forest chain: `ForestPlank`, `FiberCloth`, `HerbalPaste`, `TanninOil`
- Desert chain: `BoneMeal`, `CactusFiber`, `SanditeIngot`, `TemperedGlass`, `HeatWrap`
- Swamp chain: `MarshThread`, `PeatBrick`, `AntitoxinPaste`, `BioGel`, `MireComposite`
- Frozen chain: `InsulatedCloth`, `CryoAlloy`, `IceLens`, `HoarfrostPowder`, `ThermalGel`
- Volcanic chain: `ObsiditeIngot`, `MagmaGlass`, `HeatPlate`, `VulcanLeather`, `IgnitionPowder`
- Crystal chain: `ResonantCrystal`, `VoidAlloy`, `PhaseCircuit`, `PrismGlass`, `QuantumThread`

## 4. Crafted item catalog with exact recipes and station/time
### Stations (placeable progression)
- `Workbench` = `ForestPlank x8`, `FiberCloth x2`
- `Furnace` = `ForestStone x12`, `ClayMud x6`
- `Loom` = `ForestPlank x6`, `ReedFiber x8`
- `DryingRack` = `MangroveWood x6`, `ReedFiber x6`, `RootFiber x4`
- `AlchemyTable` = `MireStone x8`, `TemperedGlass x4`, `BioGel x2`
- `Kiln` = `SandstoneChunk x10`, `SulfiteOre x4`, `ForestStone x6`
- `AdvancedWorkbench` = `Workbench x1`, `SanditeIngot x4`, `MireComposite x4`
- `Anvil` = `SanditeIngot x8`, `BasaltChunk x6`
- `Refinery` = `AdvancedWorkbench x1`, `ObsiditeIngot x6`, `CryoAlloy x4`, `VoidAlloy x2`
- `SurveyBench` = `AdvancedWorkbench x1`, `PrismGlass x4`, `PhaseCircuit x2`, `IceLens x2`
- `MasterWorkbench` = `AdvancedWorkbench x1`, `ObsiditeIngot x4`, `CryoAlloy x4`, `ResonantCrystal x4`

### Survival/consumables
- `Bandage` (Loom) = `FiberCloth x2`, `HerbalPaste x1`
- `AntitoxinTonic` (AlchemyTable) = `AntitoxinPaste x2`, `MarshWater x1`, `BioGel x1`
- `HeatTonic` (AlchemyTable) = `EmberBloom x2`, `CactusStem x2`, `SpringWater x1`
- `ColdTonic` (AlchemyTable) = `HoarfrostPowder x2`, `ChillBloom x2`, `SpringWater x1`
- `StaminaRation` (Hand or DryingRack) = `BrownMushroom x2`, `CactusStem x2`, `BogReed x1`
- `ReinforcedRation` (DryingRack) = `StaminaRation x1`, `FrostWolfFur x1`, `LavaSalt x1`
- `ToxinFilter` (AlchemyTable) = `ReedFiber x3`, `BioGel x2`, `TemperedGlass x1`
- `ThermalPatch` (AlchemyTable) = `HeatWrap x1`, `ThermalGel x1`, `FiberCloth x2`

### Tools/weapons/armor
- `StoneHatchet` (Workbench) = `ForestWood x3`, `ForestStone x2`
- `StonePickaxe` (Workbench) = `ForestWood x2`, `ForestStone x3`
- `SanditePickaxe` (Anvil) = `SanditeIngot x3`, `ForestWood x2`, `HeatPlate x1`
- `MireSickle` (AdvancedWorkbench) = `MireComposite x3`, `MangroveWood x2`, `BioGel x1`
- `CryoPickaxe` (Anvil) = `CryoAlloy x3`, `Frostwood x2`, `IceLens x1`
- `ObsidianAxe` (Anvil) = `ObsiditeIngot x3`, `BasaltChunk x2`, `HoundFang x1`
- `PhaseMultitool` (MasterWorkbench) = `VoidAlloy x3`, `PhaseCircuit x2`, `ResonantCrystal x2`
- `BoneSpear` (Workbench) = `DriedBone x4`, `ReedFiber x2`, `CactusFiber x1`
- `SanditeBlade` (AdvancedWorkbench) = `SanditeIngot x2`, `SerpentScale x1`, `ForestWood x1`
- `MireDagger` (AdvancedWorkbench) = `MireComposite x2`, `LeechVenomSac x1`, `RootFiber x2`
- `FrostLance` (Anvil) = `CryoAlloy x2`, `IceCrystal x3`, `FrostWolfFur x1`
- `MagmaHammer` (Anvil) = `ObsiditeIngot x3`, `MagmaCore x1`, `BasaltChunk x4`
- `CrystalBow` (MasterWorkbench) = `QuantumThread x2`, `ResonantCrystal x2`, `LatticeFiber x3`
- `VoidEdge` (MasterWorkbench) = `VoidAlloy x3`, `NullFragment x2`, `SentinelCore x1`
- `DesertCloak` (Loom) = `CactusFiber x4`, `HeatWrap x2`, `FiberCloth x2`
- `SwampWaders` (Loom) = `MarshThread x4`, `BioGel x2`, `MangroveWood x2`
- `FrostParka` (Loom) = `InsulatedCloth x5`, `FrostWolfFur x3`, `ThermalGel x1`
- `VolcanicPlate` (Anvil) = `ObsiditeIngot x5`, `HeatPlate x2`, `VulcanLeather x2`
- `CrystalWeave` (Loom) = `QuantumThread x4`, `PrismGlass x2`, `LatticeFiber x3`
- `AdaptiveSurvivalSuit` (MasterWorkbench) = `DesertCloak x1`, `FrostParka x1`, `VolcanicPlate x1`, `CrystalWeave x1`, `VoidAlloy x2`

### Strategy/intel items
- `FieldClock` (SurveyBench) = `TemperedGlass x2`, `SanditeIngot x1`, `IceLens x1`, `ResonantCrystal x1`
- `BiomePredictor` (SurveyBench) = `FieldClock x1`, `PhaseCircuit x2`, `CryoAlloy x1`, `ObsiditeIngot x1`
- `WeatherPredictor` (SurveyBench) = `BiomePredictor x1`, `PrismGlass x2`, `VoidAlloy x2`, `EchoBloom x2`
- `ThreatMeter` (SurveyBench) = `SanditeIngot x2`, `MagmaCore x1`, `SentinelCore x1`, `TemperedGlass x1`
- `ResourceCompass` (SurveyBench) = `ResonantCrystal x2`, `PhaseQuartz x2`, `ForestWood x1`, `TanninOil x1`
- `EventSeismograph` (SurveyBench) = `ObsidianShard x3`, `GlacialStone x2`, `VoidResidue x2`, `PhaseCircuit x1`
- `PathfinderBeacon` (SurveyBench) = `ResourceCompass x1`, `PrismGlass x1`, `QuantumThread x1`, `HeatPlate x1`
- `HazardAnalyzer` (SurveyBench) = `AntitoxinPaste x2`, `ThermalGel x2`, `PrismGlass x1`, `ResonantCrystal x1`

## 5. Station specialization and speed table
- `DryingRack`: `0.65x` craft time for food/fiber/leather process kinds.
- `Kiln`: `0.60x` craft time for glass/clay/stone/heat processing.
- `AlchemyTable`: `0.70x` craft time for tonics/filters/pastes/gels/powders/medicine.
- `Refinery`: `0.55x` craft time for alloy/circuit/crystal processing, plus `10%` extra-output chance.
- `AdvancedWorkbench`: `0.85x` time on generic tools/weapons.
- `MasterWorkbench`: `0.75x` time on high-tier tools/weapons/armor.
- `SurveyBench`: required station for intel devices (no substitute).

## 6. Intel/strategy item unlock path
- Midgame: `FieldClock`.
- Late-mid: `BiomePredictor`.
- Late: `WeatherPredictor`, `ThreatMeter`, `EventSeismograph`.
- Endgame navigation/intel: `ResourceCompass`, `PathfinderBeacon`, `HazardAnalyzer`.

## 7. Validation checklist
- Every recipe ingredient/output item ID exists.
- No station progression dead-end from early game to master-tier.
- All six biomes contain raw resources, drops, and refined materials.
- Intel devices are gated by multi-biome materials.
- Specialized station speed modifiers apply correctly.
- Refinery extra-yield logic triggers at configured chance.
- UI displays recipes only for currently valid station.
- Timed crafting path returns result after station-adjusted duration.

## 8. Monster and boss progression (drops + craft unlocks)
### Forest
- `Wolf` drops: `WolfPelt`, `WolfFang`
- Craft paths enabled: `Bandage`, `StoneHatchet`, `StonePickaxe`, `ResourceCompass`

### Desert
- `Scorpion` drops: `ScorpionStinger`, `CactusStem`
- Craft paths enabled: `SanditeBlade`, `ToxinFilter`, `AntitoxinTonic`

- `SandSerpent` drops: `SerpentScale`, `SunShard`
- Craft paths enabled: `SanditeBlade`, `SanditePickaxe`, `ThreatMeter`

### Swamp
- `GiantLeech` drops: `LeechVenomSac`, `BogReed`
- Craft paths enabled: `MireDagger`, `BioGel`, `AntitoxinPaste`

- `BogToad` drops: `BogToadGland`, `Glowcap`
- Craft paths enabled: `AntitoxinPaste`, `AntitoxinTonic`, `SwampWaders`

### FrozenTundra
- `FrostWolf` drops: `FrostWolfFur`, `IceCrystal`
- Craft paths enabled: `FrostParka`, `InsulatedCloth`, `ReinforcedRation`

- `IceWraith` drops: `WraithEssence`, `SnowLichen`
- Craft paths enabled: `HoarfrostPowder`, `ColdTonic`, `CryoAlloy`

### Volcanic
- `MagmaHound` drops: `HoundFang`, `EmberBloom`
- Craft paths enabled: `ObsidianAxe`, `VulcanLeather`, `HeatTonic`

- Boss `LavaGolem` drops: `MagmaCore`, `GolemFragment`, `ObsidianShard`
- Craft paths enabled: `MagmaHammer`, `VolcanicPlate`, `Refinery`

### CrystalWastes
- `CrystalStalker` drops: `StalkerTalon`, `CrystalShard`
- Craft paths enabled: `CrystalBow`, `PhaseCircuit`, `PrismGlass`

- Boss `VoidSentinel` drops: `SentinelCore`, `NullFragment`, `PhaseQuartz`
- Craft paths enabled: `VoidEdge`, `WeatherPredictor`, `AdaptiveSurvivalSuit`
