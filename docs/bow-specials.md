# Bow specials

Implemented source reference. Damage percentages below use the bow's normal fully drawn damage, including Draw Force, before the existing combat modifiers. Each special consumes one Arrow. Normal arrows retain their draw-dependent speed, gravity, 1,000-stud maximum travel and 10-second, non-pickup impact lifetime.

| Bow | Special | Gameplay | Cooldown / stamina | Visuals |
| --- | --- | --- | --- | --- |
| Hunting | Piercing Shot | 135% initial damage; up to 10 enemies; retains 80% current damage and speed after each penetration. Solid geometry stops it. | 8s / 20 | Enhanced arrow trail and individual penetration bursts. |
| Marsh | Spore Arrow | 120% impact; 10-stud patch for 7s, dealing 18% per second and slowing 25%, halved against bosses. | 12s / 20 | Rising spores, drifting green motes and a softly pulsing perimeter. |
| Dawn | Flare Arrow | 125% impact; 100% blast after 0.8s within 10 studs; reveal for 8s; non-bosses within 5 studs stagger for 0.65s. | 14s / 20 | Growing sun core, rotating rays, gold blast rings and sparks. |
| Storm | Lightning Rod | 100% impact; 3 pulses over 6s, hitting up to 4 visible enemies within 12 studs for 45% each. | 16s / 20 | Orbiting charges, a crackling rod, pulse rings and branching bolts. |
| Ironwood | Vine Trap | 100% impact; 24-by-6-stud thorn path for 8s. Each crossing enemy takes 70% once and is rooted for 2s; bosses instead slow 25%. | 16s / 20 | Ground-following growing vines, rising thorns and curling root hit effects. |
| Star | Star Barrage | 120% impact; 8 stars descend over 3s for 45% each, maximum 3 per enemy. Final blast deals 100% within 9 studs and 50% out to 18. Non-bosses are briefly launched; bosses slow 20% for 2s. | 24s / 25 | Violet/gold comet, eight-point overhead constellation, colliding falling stars, linked glowing shards and a final shockwave. |

## Controls and enchantments

- Right-click on PC, L2 on gamepad, or the bow special icon above dodge on touch. Ordinary world taps continue firing normal shots.
- Specials use the existing shared weapon-special cooldown, inventory cooldown indicator, stamina reductions and special cooldown reductions.
- Held Breath modifies the initial special projectile, including Hunting Bow penetration. It does not enlarge area effects or the Star Bow's falling stars.
- Forked Current increases Lightning Rod target count by 1/2 and pulse damage by 25/35% at ranks I/II.
- Split Flight, Root Pin and Starfall Trace remain effects of normal fully drawn shots; specials do not trigger them.
- Tooltips show each special's description, stamina and cooldown.

## Lifecycle and rendering

Server-owned records control damage, collision, line of sight, durations and targets. Local effects use graphics-quality scaling, proximity culling and active-effect budgets. Lightning and flare anchors follow surviving struck enemies. Persistent areas end on owner death, departure, interior transition, world shutdown/restoration, or surface biome shift. Stars collide with world geometry; area effects do not damage through solid walls. Bosses receive their specified slow instead of roots or launch.

## Verification status

Source reviewed only. No tests or smoke tests were created or run, following the user's instruction. Studio gameplay and device verification remain unperformed.
