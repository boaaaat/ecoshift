# EcoShift generated item art

Status: **uploaded and connected in Expedition Studio** (place 94125768885713). All 23 Roblox asset IDs are saved in `uploaded-assets.json`; all 825 catalog entries are assigned. Game publishing is left to the user.

## Art direction

Clean, chunky Roblox-style objects with broad facets, simple matte materials, strong silhouettes and restrained magical accents. These are visual targets for the future graphics update, not renders of the current placeholder models. The world models have not been changed.

Generated using the built-in image-generation tool. Full prompts, revision prompts, tile order and original generation paths are in `atlas-plan.json`. The final selected source PNGs are copied beside this file. The more realistic initial direction was rejected; the food and iron armor were regenerated again to remove detailed surface textures.

- `published/`: 23 transparent 1024 × 1024 atlases, 4 × 4 cells of 256 pixels. These are the files to upload.
- `assignments.json`: exact assignments for all 825 catalog entries, including 224 seasoned meals, 254 enchantment schematics/scrolls and two recipe requirement tokens. Coordinates are zero-based pixels in the published atlases. Seasoned meals use a generated ingredient overlay; enchantments use themed page/scroll art, their material overlay and a rank.
- `catalog-snapshot.json`: source catalog inventory for this art pass.
- `review/`: each atlas visually inspected at 64px on dark slots and 40px on light slots. `all-items.png` is a 48px overview.
- `pack_atlases.py`: asset preparation only; locates transparent gutters, slices, centers and resizes the generated artwork without drawing or recoloring it. Rebuild with `python assets/icons/pack_atlases.py` (Pillow required).
- Runtime: `Shared.UI.ItemIconConfig` resolves exact atlas rectangles, and `Shared.UI.UITheme.ItemIcon` renders untinted ImageLabels with ingredient overlays and rank labels. The obsolete procedural item glyphs and `ReplicatedStorage.ItemIcons` override path have been removed.

## Upload and integration review

The new atlas IDs, renderer, database integration and responsive inventory sizing were confirmed present in the open Expedition Studio through Rojo. A temporary edit-time preview instantiated the real renderer with one item from each atlas plus meal/enchantment variants; all 36 ImageLabels reported loaded. Studio's viewport capture did not include GUI artwork, so this is a loading confirmation, not a new screenshot-based assessment of the live inventory. The earlier local 40/64px visual reviews remain the artwork approval reference. Temporary preview objects were removed. No game was published.

No tests or smoke tests were created or run. This pass performed the visual artwork review requested by the user.
