# Enchantment identity overhaul

## Goal

Enchantments should change how a weapon is played. A bow build should care about draw time, arrow flight, and range; a sword build should care about combos and sweeps; a hammer build should care about stagger and ground control. A high-grade named weapon should also have access to a signature enchantment that lower-grade weapons cannot roll.

This plan preserves the clean inventory tooltip rule: an enchanted item tooltip shows only the enchantment's styled name and rank. Full effects, exact numbers, compatibility, and rank previews belong in the enchanting station UI.

## Previous enchantments, grouped by category

This section records the baseline that the overhaul replaced. Strike Rhythm and its generated items no longer exist in source.

### Weapons

| Enchantment | Current compatibility | Ranks | Current effect |
|---|---|---:|---|
| Strike Rhythm | Axe, Dagger, Hammer, Spear, Staff, Sword | 5 | Every third accepted basic hit against the same monster gains 10/14/18/22/26% damage. The chain expires after four seconds or a target change. |
| Draw Force | Bow | 5 | All normal and special bow shots deal 8/16/24/32/40% more damage. |
| Return Shot | Bow, Staff | 4 | A successful dodge primes the next basic ranged hit within three seconds for 10/15/20/25% more damage. Eight-second cooldown. |
| Vent Strike | Every weapon family | 3 | A special hit removes 4/7/10 exposure toward zero when exposure is at least 25. |
| Storm Latch | Every weapon family | 2 | Spending 30 seconds in outdoor rain or a storm charges the next special hit for 12/20% more damage. |

The problem is visible here: all six non-bow families receive Strike Rhythm, Vent Strike, and Storm Latch. Their enchanting choices barely respond to the weapon's actual attack pattern.

### Harvesting tools

| Enchantment | Compatibility | Ranks | Effect |
|---|---|---:|---|
| Open Seam | Tool axe, pickaxe, universal tool | 4 | Every third hit on one resource node gains 15/25/35/45% breaking power. |
| Clean Cut | Sickle and universal tool | 3 | After harvesting a plant, the next plant harvest begun within five seconds is 10/15/20% faster. |
| Quick Stow | All harvesting tools | 2 | Collects normal drops from the completed node within 6/10 studs when inventory space exists. |

### Armor

| Enchantment | Slot | Ranks | Effect |
|---|---|---:|---|
| Heat Store | Chest | 2 | A qualifying exposure consumable stores an 8/12-point buffer against the same temperature direction for 90 seconds. |
| Weather Memory | Head | 3 | On a repeat biome visit, reduces its dominant exposure buildup by 15% for the first 30/45/60 seconds. |
| Dry Step | Boots | 3 | Wetness clears 20/35/50% faster for ten seconds after reaching dry shelter. |
| Shared Cover | Chest | 2 | The wearer and one nearby teammate under the same roof take 8/12% less environmental buildup. |
| Camp Stitch | Any armor slot | 3 | At a repair station, Resin can restore 4/7/10% durability once per item per visit. |
| Last Thread | Any armor slot | 1 | Once per visit, lethal durability loss holds the item at one durability for eight seconds so it can be repaired. |
| Air Pocket | Head | 3 | Below 25% remaining air, releases an emergency reserve of 15/25/35 seconds. Recharges only at camp. |
| Pack Warning | Head | 2 | After taking a monster hit, marks up to 3/5 nearby monsters of that species for eight seconds. |

### Accessories

| Enchantment | Ranks | Effect |
|---|---:|---|
| Rescue Reserve | 1 | Reviving a teammate restores 15 stamina and removes 15 exposure from the rescuer. |
| Saved Meal | 2 | Stores 10/20 hunger that would have been wasted above maximum and releases it below 50 hunger. |
| Survey Link | 2 | First entry into a generated sub-biome reveals an additional 12/20 studs of shared map terrain. |

The tool, armor, and accessory enchantments can remain for this pass. Weapon compatibility and effects receive the full redesign below.

## New weapon-family enchantments

Each family gets its own pool. Rank counts vary with the effect rather than every enchantment having the same five levels. Grade requirements are the minimum actual item grade, including reforged grade.

### Bows: draw control, arrow flight, and ranged positioning

| Enchantment | Grades / ranks | Planned effect |
|---|---|---|
| Draw Force | G3/4/5/7/8, V | Normal and special arrow damage increases 8/16/24/32/40%. This remains the direct-damage bow choice. |
| Held Breath | G3/5/7, III | An arrow released at 90% or greater draw travels 20/35/50% faster and receives 15/25/35% less gravity. It still follows a visible ballistic path. |
| Return Shot | G4/5/7/8, IV | A server-confirmed dodge primes the next arrow within three seconds for 10/15/20/25% more damage. Empty dodges do not trigger it. Bow only. |
| Split Flight | G5/7/8, III | A fully drawn hit sends a fragment to up to 1/1/2 other visible monsters within 10/12/14 studs for 18/24/30% of the original hit. Fragments cannot split again. |

### Swords: steady combos, sweeps, and timing

| Enchantment | Grades / ranks | Planned effect |
|---|---|---|
| Measured Edge | G3/5/7/8, IV | The second basic hit landed within 2.5 seconds gains 10/15/20/26% damage and a 15% wider hit arc. Missing or changing weapons resets the pair. |
| Wide Cut | G4/6/8, III | A basic hit can also strike the nearest second monster in the forward arc for 25/35/45% damage. It never repeats damage on the primary target. |
| Guard Return | G5/7/8, III | Using the sword special during a monster's attack windup reduces that attack by 25/35/45% and empowers the next basic hit by 12/18/25%. A failed timing window gives no bonus. |

### Spears: distance, lines, and controlling approaches

| Enchantment | Grades / ranks | Planned effect |
|---|---|---|
| Set Point | G3/5/7/8, IV | A hit started at least 8 studs from the target gains 8/13/19/26% damage and briefly slows a non-boss by 10/14/18/22%. Boss slow is halved. |
| Driving Line | G4/6/8, III | A spear special may continue through 1/1/2 additional monsters in the same narrow line for 45/60/75% damage. |
| Brace | G5/7, II | After holding position for 0.6 seconds, the next monster entering melee range is staggered for 0.6/0.9 seconds when struck. Eight-second per-target cooldown; bosses resist the stagger. |

### Weapon axes: cleaves, wounds, and finishing groups

| Enchantment | Grades / ranks | Planned effect |
|---|---|---|
| Split Arc | G3/5/7, III | A basic swing can strike one additional monster in the axe arc for 35/50/65% damage. |
| Deep Bite | G4/6/8, III | Basic hits place a wound for four seconds, up to 1/2/3 stacks. A special consumes the stacks for 8% weapon damage per stack over three seconds. |
| Fell Through | G5/7, II | A kill made by an axe special refunds 20/35% of that special's cooldown. Only one refund per cast. |

### Daggers: flanking, dodge follow-ups, and fast exits

| Enchantment | Grades / ranks | Planned effect |
|---|---|---|
| Blindside | G3/5/7/8, IV | Hits from behind the target gain 8/14/20/28% damage. Boss bonus is halved, and server facing decides whether the hit qualifies. |
| Slip Cut | G4/6/8, III | A confirmed dodge followed by a dagger hit within two seconds adds a second cut for 15/25/35% damage. Six-second cooldown. |
| Quick Exit | G5/7, II | A dagger kill grants 10/16% movement speed for three seconds. Repeated kills refresh the duration without stacking the speed. |

### Hammers: stagger, delayed impacts, and space control

| Enchantment | Grades / ranks | Planned effect |
|---|---|---|
| Heavy Echo | G3/5/7, III | A ground-slam special creates a second impact 0.65 seconds later for 20/30/40% damage in 70% of the original radius. |
| Crumple | G4/6/8, III | Hammer hits increase the target's stagger received by 12/20/30% for four seconds. The effect does not increase raw damage and does not stack between players. |
| Ground Claim | G5/7, II | A ground slam leaves a 3/5-second zone that slows non-boss monsters by 18/28%. One zone per hammer owner. |

### Staffs: repeated casts, team support, and area control

| Enchantment | Grades / ranks | Planned effect |
|---|---|---|
| Echo Cast | G3/5/7/8, IV | A special that hits creates a smaller repeat at its center after 0.7 seconds for 15/22/30/38% damage and 60% radius. |
| Conduit | G4/6/8, III | The first monster hit by a special restores 4/7/10 stamina to living crew within 12 studs. One trigger per cast. |
| Focus Line | G5/7, II | Three consecutive basic staff hits on the same target increase the next staff special's radius by 15/25%. The stored focus expires after six seconds. |

## Signature enchantments for named high-grade weapons

Signature enchantments use an exact `AllowedItems` list. They occupy a normal enchantment slot, so their special behavior has a real build cost. They are discovered from content associated with that weapon's biome and grade; they are not random low-tier rolls.

| Weapon | Signature enchantment | Ranks | Effect |
|---|---|---:|---|
| Storm Bow, G5 | Forked Current | II | Lightning Rod pulses hit 1/2 additional visible monsters and deal 25/35% more pulse damage. Pulses do not chain recursively. |
| Ironwood Bow, G6 | Root Pin | II | A fully drawn hit roots a non-boss for 0.75/1.25 seconds. Bosses are slowed 15/25% for 1.5 seconds instead. Six-second per-target cooldown. |
| Star Bow, G8 | Starfall Trace | I | A fully drawn hit marks its impact; after 0.6 seconds a star pulse deals 25% arrow damage in a six-stud radius. Four-second cooldown. |
| Thunder Hammer, G5 | Rolling Charge | II | Staggering a monster arcs 20/30% weapon damage to 1/2 nearby monsters. Each target can be hit once per trigger. |
| Gravity Hammer, G8 | Orbit Break | I | Ground slam pulls non-boss monsters within ten studs toward the impact before the hit. Bosses receive a short 15% slow instead. |
| Tide Spear, G5 | Undertow | II | A special hit pulls nearby non-boss monsters 2/3 studs toward its impact line, setting up the spear's follow-through. |
| Sky Spear, G7 | Tailwind Line | II | A qualifying Set Point hit grants 10/15% movement speed for three seconds and reduces the next spear special's stamina cost by 25/40%. |
| Thorn Blade, G6 | Briar Debt | II | Stores 10/18% of monster damage received, up to 25/45% of one normal sword hit. The next successful special releases it and clears the store. |
| Deepsteel Sword, G7 | Pressure Cut | II | Repeated sword hits expose an armored target after the third/second hit, reducing its damage resistance by 8/12% for four seconds. Strongest exposure only. |
| Moonblade, G8 | Phase Return | I | A sword special leaves an echo across the sweep path that repeats 30% of its damage after 0.5 seconds. |
| Root Staff, G6 | Root Network | II | A monster slowed by the staff shares 15/25% of subsequent staff damage with the nearest visible monster for three seconds. Shared damage cannot chain. |
| Lantern Staff, G7 | Beacon Echo | II | A special leaves a visible six/nine-second light field that reveals monsters and removes 0.5/0.75 exposure per second from nearby crew. Fields do not stack. |

The current weapon catalog has only one weapon axe, Ember Axe at grade 3, and only one dagger, Bone Knife at grade 1. Those families need additional G5-G8 weapons before they receive true high-grade signature enchantments. Reforging the existing items should unlock stronger family enchants, but it should not turn a starter knife into a named endgame signature weapon.

## Existing reactive enchants

The two current all-weapon reactive enchants should become themed, exact-item options instead of appearing everywhere:

- **Vent Strike** is limited to Frost Spear, Ember Axe, Crystal Staff, Root Staff, and Lantern Staff. These weapons plausibly exchange or vent environmental energy.
- **Storm Latch** is limited to Storm Bow, Thunder Hammer, Tide Spear, and Sky Spear. It remains a storm-weather payoff instead of a universal damage roll.
- **Return Shot** becomes bow-only. Staff users receive Echo Cast, Conduit, and Focus Line instead.
- **Strike Rhythm** and its pages and scrolls are removed; every family receives a mechanic suited to its attack pattern.

## Compatibility and stacking rules

- Every weapon may have at most one direct damage-pattern enchantment. The conflict group includes Draw Force, Measured Edge, Set Point, Deep Bite, Blindside, Heavy Echo, and Echo Cast.
- A signature enchantment may coexist with a family enchant unless both modify the same hit stage. The configuration declares explicit conflict groups rather than relying on names.
- Compatible enchantment damage bonuses use their full listed values. Delayed hits, chains, and fragments still cannot recursively trigger themselves.
- Crowd control has server-side boss reductions and per-target cooldowns. One player cannot permanently root, slow, or stagger a monster.
- Projectile effects use the server-confirmed arrow path and impact. Client particles never decide damage.
- Identical debuffs use the strongest value and refresh duration. They do not add together across players.
- Signature effects never duplicate loot, arrows, drops, or kill credit.

## Configuration changes

Extend every enchantment definition with explicit compatibility and effect data:

```lua
AllowedKinds = { "Weapon" },
AllowedFamilies = { "Bow" },
AllowedItems = { "StormBow" }, -- optional exact allow-list
BlockedItems = {},              -- optional explicit exclusions
ConflictGroups = { "BowDamagePattern" },
EffectId = "ForkedCurrent",
EffectValues = {
    { Targets = 1, DamageFactor = 0.25 },
    { Targets = 2, DamageFactor = 0.35 },
},
```

Compatibility uses all populated restrictions together: kind, slot, family, minimum grade, and exact item. The server is authoritative and rejects stale or forged enchanting requests even if the client UI displayed an outdated option.

Combat effects should run through named hooks rather than scattered ID checks:

- `BeforeAttackAccepted`
- `AfterAttackHit`
- `AfterSpecialHit`
- `AfterConfirmedDodge`
- `AfterKill`
- `ModifyProjectileLaunch`
- `AfterProjectileImpact`
- `ModifyIncomingMonsterAttack`

Each proc receives one attack ID so chains, echoes, and area hits cannot trigger themselves again.

## Enchanting UI

- Selecting an item immediately filters the list to that item's valid family and exact-item enchantments.
- Each option shows its icon, name, rank range, short effect description, and exact current/next-rank values before selection.
- Signature choices receive a distinct border and a small `SIGNATURE · <weapon name>` label.
- Incompatible enchants never appear in the selectable list. Search only ranks valid results; it cannot bring incompatible entries back.
- The comparison panel shows the currently installed enchant beside the proposed rank and highlights only values that change.
- Inventory, chest, hotbar, and creative-menu item tooltips remain clean: styled enchantment name plus Roman-numeral rank only, with no effect summary.

## Fresh catalog policy

The game is not public, so the redesign replaces the old weapon-enchantment catalog directly. Strike Rhythm and its pages, scrolls, runtime behavior, and save conversion code are removed. Development worlds and old enchanted items should be deleted rather than migrated. New enchantments still use stable IDs and ranks in ordinary inventory, chest, ground-item, and world persistence.

## Delivery order

1. Add exact-item compatibility, conflict groups, data-derived pages and scrolls, and shared combat hooks.
2. Implement and balance one complete family at a time: Bow, Sword, Spear, Hammer, Staff, Axe, Dagger.
3. Update the enchanting UI and server validation as soon as the first two families are available so invalid choices cannot be created during rollout.
4. Add signature effects for the existing G5-G8 weapons, with clear particles and sounds tied to their materials.
5. Remove the former generic enchantments and their pages from the catalog.
6. Later, add high-grade weapon axes and daggers so those families receive their own signature path.

## Acceptance scenarios for later verification

These are documentation only until testing is requested.

- Selecting a bow never shows sword, spear, axe, dagger, hammer, or staff enchantments, and the reverse holds for every family.
- A Storm Bow can see Forked Current; a Hunting Bow cannot. A reforged Hunting Bow still cannot use an exact-item signature.
- A family enchant and signature enchant obey their conflict groups and never recurse through chains, echoes, fragments, or damage-over-time ticks.
- Rank previews display the exact current and next values, while ordinary item tooltips show only styled name and rank.
- Boss crowd-control reductions, per-target cooldowns, full compatible damage stacking, and multiplayer strongest-effect rules remain consistent.
- Arrow launch modifiers affect the same server projectile used for hit detection and damage.
