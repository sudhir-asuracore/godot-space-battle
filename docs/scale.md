# Scale & Dimensions — Nebula Conquest

This document defines the **pixels-per-dimension scale** for the game world so
every system — planetary systems, orbits, the star, ships and planetary defense
structures — shares one consistent sense of size. The guiding goal is that space
should **feel vast**: objects are small, the void between them is enormous, and a
single solar system takes real travel time to cross.

All measurements are in **world pixels (px)** at camera zoom `1.0` (1 world px =
1 screen px when fully zoomed in). The game viewport is `1920 × 1080`.

> Determinism note (`conventions.md`): every size/spacing range below must be
> sampled from the **seeded** system RNG so identical coordinates always yield an
> identical system.

---

## 1. The "Vast Space" Principle

What makes space feel big is **not** large objects — it is the *ratio* of empty
space to object size. A carrier is a few hundred pixels; the gap to the next
orbit is several **thousand** pixels. That 1:10–1:30 object-to-void ratio is the
single most important rule in this document.

```
[ship ~300px] ......~3000px of empty space...... [planet ~600px]
```

Design rule of thumb:

| Relationship                         | Target ratio | Why                                  |
| ------------------------------------ | ------------ | ------------------------------------ |
| Inter-orbit gap : largest ship       | ≥ 6 : 1      | crossing a gap takes meaningful time |
| Planet diameter : carrier length     | 1.5–3 : 1    | planets clearly dwarf ships          |
| Star diameter : planet diameter      | 3–5 : 1      | the star anchors the whole system    |
| Star diameter : largest ship         | 5–10 : 1     | ships are specks beside a star       |

---

## 2. Base Unit

To keep conversations consistent we define one logical unit:

- **1 System Unit (SU) = 1000 px.**

Use **px** for object-scale things (ships, structures, planet radii) and **SU**
for system-scale things (orbits, system radius, travel distances). Example: an
orbit at `2800 px` is `2.8 SU`.

---

## 3. Scale Ladder (overview)

From smallest to largest, every object lives in one of these bands:

| Band                  | Typical size (px)     | Notes                                    |
| --------------------- | --------------------- | ---------------------------------------- |
| Projectiles / drones  | 8 – 60                | fast, read as motion not mass            |
| Ships                 | 60 – 600              | see §4                                   |
| Planetary defenses    | 70 – 220              | between a ship and a planet              |
| Planets               | 380 – 900             | clearly bigger than any ship             |
| Star (sun)            | 2400 – 3200 diameter  | largest single body; system anchor       |
| Orbits / system       | 2.8 – ~40 SU radius   | the void; dominates everything (see §6)  |

---

## 4. Ships

Per the design brief the capital-ship order, **largest → smallest**, is:

```
Carrier  >  Dreadnaught  >  Frigate  >  (Striker)  >  Scout
```

`Frigate` is the general-purpose hull and the smallest of the three named
capital classes. `Scout` and `Striker` remain the light end of the roster from
`ship-classes.md`.

Ship size is measured as **hull length** (longest axis) on screen at zoom `1.0`.

| Class        | `ShipData.ShipSize` | Hull length (px) | Hull width (px) | Notes                              |
| ------------ | ------------------- | ---------------- | --------------- | ---------------------------------- |
| Scout        | `SMALL`             | 60 – 90          | 30 – 50         | fast skirmisher, read as a dart    |
| Striker      | `MEDIUM`            | 110 – 150        | 60 – 90         | general combat ship                |
| Frigate      | `MEDIUM`            | 150 – 200        | 90 – 130        | versatile workhorse hull           |
| Dreadnaught  | `LARGE`             | 280 – 380        | 160 – 240       | heavy frontline warship            |
| Carrier      | `CAPITAL`           | 450 – 600        | 260 – 360       | largest hull; drone platform       |

Guidelines:

- **Pick the target length first, then derive the sprite scale** from the source
  texture. `sprite.scale = target_length_px / texture_long_edge_px`.
- Collision shapes should hug the *visible* hull, not the texture bounds.
- Drones launched by a Carrier sit in the projectile/drone band (`30 – 60 px`)
  so a full wing never visually competes with the Carrier itself.

### Current asset reconciliation

The shipped `Frigate.tscn` uses `frigate-low.png` (`1568 × 2710`) at
`scale = 0.25`, giving a ~`390 × 680 px` sprite with a collision length near
`500 px`. That is **Carrier-band size** for a Frigate. To match this scale,
**reduce the Frigate sprite scale to ≈ 0.065–0.075** (≈ `175 px` length) and
re-fit its collision/marker offsets, reserving the `450–600 px` footprint for
the actual Carrier hull.

---

## 5. Planets & Planetary Defenses

### Planets

Planet textures (`assets/kenney_planets/Planets/*.png`) are `1280 × 1280`.
Target **on-screen diameters** keep planets comfortably larger than a Carrier:

| Planet role     | Diameter (px) | Sprite scale (from 1280px) | Collision radius (px) |
| --------------- | ------------- | -------------------------- | --------------------- |
| Small / moon    | 380 – 480     | 0.30 – 0.375               | 190 – 240             |
| Standard colony | 500 – 700     | 0.39 – 0.55                | 250 – 350             |
| Large / gas     | 720 – 900     | 0.56 – 0.70                | 360 – 450             |

- **Collision radius = visible radius** (≈ `diameter / 2`), so the body's
  physics matches its art instead of the current `250 * base_scale`.
- **Capture radius** (the contest zone) scales with the planet so bigger worlds
  are fought over a wider ring: `capture_radius ≈ planet_radius + 250 px`
  (current default `400 px` suits a standard colony).
- Homebase planets should sit in the **Large** band so a faction's home world
  reads as the most important body in the system.

### Planetary defense structures

Orbital defenses (turret platforms, defense rings, shield nodes) sit between a
ship and a planet in size and are anchored to the planet's `DefenseSlots` node,
orbiting just outside its surface.

| Structure          | Size (px) | Orbit offset from planet surface (px) |
| ------------------ | --------- | ------------------------------------- |
| Point-defense node | 70 – 110  | 60 – 120                              |
| Turret platform    | 120 – 180 | 100 – 200                             |
| Defense ring       | 200 – 220 | 80 – 160 (ring radius ≈ planet + 150) |

Rule: a defense structure is always **smaller than its planet** and **never
smaller than a Scout**, so it reads as a built object, not a ship or debris.

---

## 6. The Star (Sun)

The star is the single largest body and anchors the whole system at the origin.

| Property                | Value (px)        | Source / note                              |
| ----------------------- | ----------------- | ------------------------------------------ |
| Visible disc diameter   | 2400 – 3200       | `≈ 4 – 5×` a standard planet               |
| Recommended default     | 2800 (radius 1400)| keeps a clean `2.8 SU = 1 orbit` reference |
| Light reach (PointLight)| ≥ 3× disc radius  | so inner planets are lit, outer ones dim   |

The current `SunCorona.tscn` is a `1920 × 1920` `ColorRect` scaled `×2`
(`3840 px` rect) with the shader's `sun_radius = 0.3`, i.e. a visible disc of
≈ `0.3 × 3840 ≈ 1150 px` radius (`~2300 px` diameter). Nudge the disc scale so
the **visible** diameter lands in the `2400 – 3200 px` band above.

**Future "different suns" hook:** sun *type* should drive disc diameter,
palette and light reach together. Suggested seeded variation:

| Sun type     | Disc diameter (px) | Light reach        | Palette hint        |
| ------------ | ------------------ | ------------------ | ------------------- |
| Red dwarf    | 1800 – 2200        | short (dim outer)  | deep red / orange   |
| Yellow (def) | 2600 – 3000        | medium             | warm white / gold   |
| Blue giant   | 3200 – 4200        | long (bright everywhere) | white / cyan  |

---

## 7. Orbits & System Layout

These are the numbers that actually sell "vast". They extend the existing
`SolarSystem.gd` constants.

| Parameter                      | Value           | In SU         | Source constant                   |
| ------------------------------ | --------------- | ------------- | --------------------------------- |
| First orbit radius             | 2800 px         | 2.8 SU        | `FIRST_PLANET_ORBIT_RADIUS`       |
| Orbit spacing (min)            | 2600 px         | 2.6 SU        | `PLANET_ORBIT_SPACING_MIN`        |
| Orbit spacing variance         | +0 … 1200 px    | up to 1.2 SU  | `PLANET_ORBIT_SPACING_VARIANCE`   |
| Effective gap between orbits   | 2600 – 3800 px  | 2.6 – 3.8 SU  | min + variance                    |
| Planet count                   | 6 – 12          | —             | `MIN/MAX_PLANETS`                 |
| Player spawn offset (sunward)  | 700 px          | 0.7 SU        | `PLAYER_SPAWN_OFFSET`             |

Derived system extent:

- Outermost orbit radius ≈ `2800 + 11 × (2600 … 3800)` ≈ **31,400 – 44,800 px**
  (`~31 – 45 SU`), i.e. a full system spans **60k–90k px** edge to edge.
- With the largest ship at `~600 px`, the void-to-ship ratio across a single
  orbit gap is **~4–6×**, and across the whole system **~50–75×** — comfortably
  inside the "vast" target from §1.

Keep these invariants when tuning:

1. `min orbit gap (2600px)` must stay **≥ 6 ×** the largest ship length.
2. The star's light reach should **not** illuminate the outermost orbit, so far
   planets feel cold and distant.
3. Homebase planets remain anchored on opposite ends (`speed = 0`) so the two
   factions are always a full system-crossing apart.

---

## 8. Quick Reference (one screen)

```
Projectile / drone   8 – 60 px
Scout               60 – 90 px
Striker            110 – 150 px
Frigate            150 – 200 px
Defense structure   70 – 220 px
Dreadnaught        280 – 380 px
Carrier            450 – 600 px      <- largest ship
Planet             380 – 900 px (Ø)
Star               2400 – 3200 px (Ø) <- largest body
First orbit        2.8 SU  (2800 px)
Orbit gap          2.6 – 3.8 SU
System radius      ~31 – 45 SU
1 SU = 1000 px
```

---

## 9. Future Work

- **Procedural planets:** drive diameter, palette and surface shader from a
  seeded `PlanetData` "biome", staying inside the `380 – 900 px` band.
- **Procedural suns:** implement the §6 sun-type table so each generated system
  has a visibly different star (size + light + colour).
- **Defense tiers:** when Milestone 10 adds planet modifiers, slot the structure
  sizes from §5 into `PlanetData.has_defenses` data.
- Treat every range here as **seeded** input (`conventions.md` §Determinism) so a
  given system seed always reproduces the same scale.
