# Ecoshift original model direction

The approved direction is a stylized low-poly expedition: angular silhouettes, painted color planes, restrained glowing biome materials, and equipment that looks assembled from things gathered in the world. Original code-authored geometry lives in `Art/ExpeditionModels.lua`, `Art/ExpeditionEquipment.lua` and `Art/ExpeditionFieldObjects.lua`. These are Roblox part models, not Blender meshes.

## Model library contract

- `CreateResource(name, biome)` returns an unparented, anchored Roblox Model, or nil for an unsupported name.
- `CreateProp(name, biome)` has the same return contract.
- `CreateTool(itemId, isWeapon)` returns an unparented Roblox Tool with a direct Handle, visual Grip, and welded, noncolliding art. It returns nil for an unsupported item.
- World models are authored with their pivot at the ground origin. The factory must apply its placement offsets once; historical marketplace offsets should not lift this art off the terrain.
- Tool art has no damage, cooldown, harvesting, inventory, or weapon-type attributes. The gameplay factory applies those. Model metadata is limited to art family, style, version, and biome.
- No imported mesh IDs, textures, scripts, currencies, or random geometry are used. All silhouettes are reproducible from the source.

## Visual language

Use three scales of detail: a strong silhouette, two or three readable secondary shapes, and sparse color marks. Tree crowns are broad faceted layers; mangrove roots form visible arches; frost trees climb in stepped conical layers. Reeds have folded leaves and seed heads. Flowers have three folded petals, and mushrooms have low overhanging caps. Water sources are shallow framed pools. Clay, sand, peat, roots, bark, bone, ore, and crystals each have a different structural recipe.

Rocks use a chiseled central mass and broad wedge faces. Ore exposes small mineral planes on a darker matrix. Crystals are pointed paired prisms, not glowing rectangular boxes. Fine neon seams mark valuable material without covering a whole tree, tool, or landscape in emissive color. Surfaces use painted part colors and Roblox materials; there are no photographs stretched across geometry.

## Biome palette and silhouette

| Biome | Palette | Recognizable construction |
| --- | --- | --- |
| Verdant Reach | Moss green, honey wood, muted stone | Broad wind-combed crowns, amber resin on cut bark, tan mushroom caps |
| Sunscar Dunes | Ochre, pale sand, sage cactus | Ribbed branching cactus, pale bone, gold mineral seams and layered dunes |
| Mirefen | Deep sage, peat brown, pale mint | Arched mangrove roots, hanging willow leaves, reeds, glowcap gills, root mats |
| Frostfall | Slate blue, frosted teal, pale ice | Stepped conifers, low lichen, long ice shards, cold-metal tools |
| Cinder Rift | Basalt violet, ash brown, ember gold | Heavy dark mineral masses, angular obsidian edges, narrow hot bands |
| Prism Barrens | Dusty violet, lavender, pale quartz | Crystal clusters, folded luminous flowers, dark cutting edges with lilac seams |
| Aurora Vale | Sea glass, pale bark, warm dawn | Pale branching trees, mint canopy, peach flowers and subtle bark inlays |
| Starfall Crater | Smoky purple, iron gray, warm starlight | Impact boulders, broken spires, layered mineral dust and forked metal weapons |

## Held equipment

The library covers the current eight harvesting tools and nine weapons. Picks have distinct sockets and opposing beaks; hatchets and axes have asymmetric cutting cheeks; the sickle is a hooked segment blade; the multitool has a central mineral point. Spears retain a visible shaft and binding, while the meteor pike uses separate fork tines. The hammer carries its weight in a broad banded head. The bow has authored limbs, tips, and a visible string.

Grip wraps repeat a shared expedition motif. Later materials change the cutting surface and embedded mineral color while the basic function stays legible. Damage and mining power come from gameplay configuration, never from visual dimensions or a mesh name.

MCP Play checks confirmed native RightGrip mounting for all 17 tools on vanilla R6 and R15 NPC rigs. CrystalBow also appeared upright on an animated real-player R15 character. This verifies attachment and that specific held pose; other tools' animated poses and combat remain subject to visual review.

## Camps, armor, and creatures

`ExpeditionEquipment` provides three additional geometry factories:

- `CreateBuild(id)` returns an unparented, anchored Model with a ground-origin pivot. Main structural pieces collide; decorative details do not. The 21 current allowed build IDs are covered. Most structures fit the six-stud placement footprint; tower height and station apparatus retain their distinct silhouettes.
- `CreateArmor(id)` returns an unparented Accessory with a direct visible Handle, a BodyFrontAttachment, and welded, massless, noncolliding pieces. All nine current Armor item IDs are covered, including Reed Sunwrap. These are rigid torso accessories for R6/R15 attachment mounting, with painted plates, capes, bibs, collars, or filter packs; they are not layered clothing or articulated leg garments. GeneratedArmorFit makes decorative parts follow native Handle scaling. Sampled block-body proportions have passed review; arbitrary avatar bundles still need visual review.
- `CreateCreature(id, biome)` returns an unparented Model of anchored, noncolliding visual parts, facing local -Z with a ground-origin pivot. All 13 EntityConfig species are covered. The caller creates its root, collision body, Humanoid, welds or joints, and gameplay attributes. Wraiths and sentinels intentionally hover above that ground origin.

All three return nil for unsupported IDs. Build and creature models expose ArtWidth, ArtHeight, and ArtDepth as bounding-box dimensions; those dimensions are not a root position. Use the actual bounding-box center when fitting collision bodies. No creature root, Humanoid, AI script, animation, combat stat, armor resistance, or crafting function is included in these art factories.

Stations use a shared timber-and-metal construction language with identifiable apparatus: a carving block and vise on the workbench; calipers and calibration board on the advanced bench; a mineral jig on the master bench; chimney and bellows for the furnace; a clay hearth for the kiln; warp threads for the loom; hanging hides for the drying rack; colored vessels and mortar for alchemy; banded processing columns for the refinery; and a map and sighting telescope for surveying. The anvil has its own stump, waist, striking face, and horn. Camp structures include braced plank walls, an open gate frame, a slatted ramp, a ladder tower, pressure-plate trap art, a power apparatus, banded chest, fire ring, and torch. Geometry does not introduce trap damage or moving gate mechanics.

| Species | Silhouette |
| --- | --- |
| Wolf | Lean four-legged hunter with raised shoulders, muzzle, pointed ears, and swept tail |
| FrostWolf | Fuller angular mane and pale dorsal ridges |
| MagmaHound | Broad heavy shoulders, thick legs, cinder plates, and narrow fault seams |
| Scorpion | Flat segmented shell, six splayed legs, pincers, and a curled segmented stinger |
| SandSerpent | Curved segmented body, raised head, flared hood, and forked tongue |
| GiantLeech | Low blunt segmented body with a dark ringed mouth |
| BogToad | Wide throat, raised eyes, strong haunches, webbed feet, and a tongue ribbon |
| IceWraith | Floating hood, separated angular arms, dark face, and tattered lower mantle |
| LavaGolem | Heavy biped, broad fists and shoulders, dark plates, and an inset hot core |
| CrystalStalker | Tall mantis posture, four fine legs, raptorial blades, and a crystal crest |
| VoidSentinel | Floating armored guardian, geometric halo, blade arms, and separated skirt plates |
| AuroraStag | Long jointed legs, cloven-looking dark hooves, upright neck, and branching antlers |
| CometCrawler | Low impact shell, six wide jointed legs, a forward head, and glass spines |

## Integration and remaining art

The static resource and prop catalogs cover every current configured gather/prop name and canonical equivalents used for those sources. Unsupported future content returns nil so the caller can report the missing definition instead of silently replacing it with a generic rock.

The parent factory integrates these libraries and owns creature movement and animation, collision fitting, gameplay statistics, loot markers, and final scene composition. Preserve these models' ground pivots when cloning and disable historical prototype offsets. Use the returned Tool and Accessory directly instead of flattening them into another object. Existing studio or imported prefabs should only take precedence if they are intentionally retained original assets; marketplace placeholders should be replaced during the transition.

`PrototypePrefabService` now supplies all six catalog categories, including armor accessories in `ServerStorage/GameItems` for the existing ArmorService equip path. It preserves unmarked prefabs and explicit `PrefabOverride=true` templates; marked legacy prototypes are replaced. Creature roots are centered using authored axes and retain a ground-origin pivot, with compact colliders and hip height derived from the art elevation. Existing health, weapon, harvesting, and torch-light behavior stays in the factory. The unused historical `PrototypeVisuals` catalog is no longer loaded by it.

ExpeditionFieldObjects supplies ground-item pickup art, Common_Chest/Rare_Chest, and six generated ruins/landmarks. ItemDropService converts Tool/Accessory templates into welded physical pickup models and strips executable scripts and prompts from cloned art. Emergency generic fallbacks remain for genuinely missing content. In a Studio boot, all current catalogs supplied 132 pickup templates, 21 builds, 2 chest types, 8 armor accessories, 17 tools, 6 structure types and 13 creature species. Resources and environmental props are additionally populated per biome.

Studio review confirmed the 13-creature lineup has distinct grounded silhouettes, the lobby uses the original props, and FrostParka attaches during a saved-world restore. A fresh isolated armor fixture passed 21 checks, including native mounting of all eight armors on vanilla R6/R15, attachment alignment, part preservation, fallback/recovery and cancellation. It used a cloned ArmorService, stub inventory/stats services and fake players without live-player profile mutations. Native R6 AccessoryWeld and R15 AccessoryRigidConstraint mounts are both supported; imported accessory behavior is preserved.

Unobstructed MCP Play screenshots now cover front and rear views of all eight armor sets on vanilla R6 and R15, plus their default walk poses. Chest details remain distinct; split capes, weave ribbons and the filter pack are visible from behind. The gallery used an isolated clone of ArmorService with empty inventory/stats stubs and no live-player subscriptions or profile writes.

Walking exposed thigh clipping in the rigid SwampWaders apron and StarforgedPlate tasset. Their heights were reduced from 0.88 to 0.34 studs and 0.72 to 0.32 studs, with centers raised from -0.95 to -0.58 and -0.98 to -0.59 relative to the Handle. They retain paired oilskin tabs and a single plate at the waist. Fresh Play close-ups of both sets on both rigs showed clearance at opposite strides and the most forward thigh positions sampled across 16 walk phases. MCP captures `Armor_waist_fix_R6_left_peak`, `Armor_waist_fix_R6_right_peak`, `Armor_waist_fix_R15_left_peak` and `Armor_waist_fix_R15_right_peak` record the final comparison. Play was stopped afterward, and the temporary gallery and cloned service were confirmed absent in Edit.

These checks cover standard bodies and sampled default walking poses. Subsequent scaling review covered all nine armors on R15 block bodies with width/height/depth factors of (0.7, 0.9, 0.7), (1, 1.05, 1) and (1.4, 1.2, 1.3), including unobstructed small-body front and wide-body front/rear captures. It exposed and fixed native Handle scaling leaving decorative panels at their original size. Later review sampled opposite run strides, early/late jump and a Harvester swing midpoint on copies of the current R15 avatar, with attachment alignment retained. These bounded poses do not establish compatibility with custom animation packs or arbitrary avatar bundles. Resource/cache tuning is centralized in ExpeditionLootConfig; cache rewards use biome materials and modest supplies, and never bypass crafting with finished world-control devices. Monster levels scale independently of biome, with an opening spawn grace period, bounded waves and per-wave boss limits.
