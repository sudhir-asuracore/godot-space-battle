## Ship classes, upgrades and Retrofit

| Class                     | Role                                      |
| ------------------------- | ----------------------------------------- |
| Scout                     | Fast reconnaissance and skirmishing       |
| Striker                   | General-purpose combat ship               |
| Dreadnaught               | Heavy frontline warship                   |
| Carrier                   | Fleet support and drone deployment        |
| Engineer (Specialization) | Utility conversion available to any class |

This gives you:

* only **4 ship archetypes**
* easy balancing
* clear progression
* distinct playstyles
* much less asset creation work.

---

# Suggested Ship Progression

Instead of T1-T4 ships, make upgrades feel like **refits**.

Example:

## Scout

### Mk I

* Light weapons
* Fast engines

### Mk II

* Better sensors
* Cloak ability

### Mk III

* Advanced thrusters
* Improved shields

---

## Striker

### Mk I

* Dual cannons

### Mk II

* Missile pod

### Mk III

* Heavy autocannons

---

## Dreadnaught

### Mk I

* Heavy armor

### Mk II

* Additional turrets

### Mk III

* Siege cannon

---

## Carrier

### Mk I

* Launches 2 drones

### Mk II

* Launches 4 drones

### Mk III

* Launches 6 drones
* Can deploy fighter wings

---

# Engineer Conversion

I really like this idea.

Instead of Engineer being its own class:

```
Scout → Engineer Scout
Striker → Engineer Striker
Dreadnaught → Engineer Dreadnaught
Carrier → Engineer Carrier
```

This creates interesting combinations.

---

## Engineer Scout

* Extremely fast repair ship
* Great for rushing planets and supporting fleets.

---

## Engineer Striker

* Balanced support ship.
* Probably your most common engineer.

---

## Engineer Dreadnaught

* Slow mobile repair station.
* Repairs structures quickly.

---

## Engineer Carrier

* Deploys repair drones and construction drones.

This creates a lot of variety without adding more classes.

---

# Ability Replacement

You proposed:

```
Replace 2 abilities with:
- Repair Drones
- Repair Beam
```

I think this is perfect.

The player sacrifices combat power for utility.

That creates meaningful decisions.

---

# Planet Capture Bonus

I'd go even further:

Engineer specialization gives:

* +50% repair speed
* +50% structure build speed
* +30% planet capture speed
* Can build temporary defense platforms
* Can repair orbital defense rings.

This makes Engineers strategically valuable without making them mandatory.

---

# Ship Ability Suggestions

## Scout

1. Afterburner
2. Cloak
3. Sensor Pulse
4. EMP Burst

---

## Striker

1. Missile Barrage
2. Overcharge Weapons
3. Combat Shield
4. Thrusters

---

## Dreadnaught

1. Siege Mode
2. Heavy Shield
3. Flak Burst
4. Gravity Well

---

## Carrier

1. Fighter Launch
2. Drone Recall
3. Point Defense Network
4. Supply Drop

---

# One thing I would change

I would remove the word **Special Upgrade**.

Instead call it:

> **Engineer Retrofit**

or

> **Support Retrofit**

It feels more like a ship modification and fits the sci-fi setting better.

---

# Final system

```text
Classes
├── Scout
├── Striker
├── Dreadnaught
└── Carrier

Each class:
├── Mk I
├── Mk II
└── Mk III

Optional:
└── Engineer Retrofit
      ├── Repair Drones
      ├── Repair Beam
      ├── Faster Captures
      └── Structure Construction
```

For your game's scale (1–6 players per faction), this is probably the sweet spot: **simple enough to learn in 10 minutes, but deep enough to master over dozens of matches.**
-----


Ship: I removed older scout and Striker Lance ships. A new ship is now available: res://scenes/factions/solarion/ships/Frigate.tscn

Changes:
Collision: The ship defines 4 collisionShape2D's. collision_front, collision_rear, collision_left, collision_right. Define different damage taken percentages by direction. eg: rear would be the highest. front will be the least.

Engine: engine_0, engine_1.. will be available. Thruster trail needs to be rendered for each engine.

Damage indicators: damage_0, damage_1.. are where res://scenes/common/effects/DamageMarkerEffect.tscn will be displayed. eg: if there are 3 markers, display each one after 1/3rd damage to hull has occured.

Thrusters: thruster_rear_0,thruster_rear_1.. define thrusters on the rear.
thruster_left_0, thruster_left_1.. and thruster_right_0, thruster_right_1 etc.. are side thrusters. These should be fired for side movement. Q and E keys will be used by user to  turn/point the ship to left and right.

Muzzle: Weapons on the ship are defined in this pattern: muzzle_cannon_left_0, muzzle_cannon_left_1 = meaning, resource defined for muzzle_cannon in the ship specific tres file will be used as the projectile. Simmilarly muzzle_laser_front_0, muzzle_gattling_front_0 and any such patterns in future will follow the same definition structure. For now, use gattling.tres as the weapon projectile for all muzzles. We will customize it later.

Make all possible parsing changes to handle the dynamic systems. 

Texture LOD: Each ship may provide up to three `Sprite2D` children holding the same hull artwork at decreasing resolutions:
- `lod_near`  – high resolution (e.g. 1024h.png), used for close camera / hangar / selection screen.
- `lod_medium` – medium detail (e.g. 512h.png), used at normal gameplay zoom.
- `lod_far`   – low resolution (e.g. 256h.png), used when zoomed far out, simplified to reduce shimmering / pixel crawl.

`Ship.gd` shows exactly one of these based on the active `Camera2D` zoom (`zoom.x >= 1.6` → near, `>= 0.6` → medium, otherwise far). The lowest-detail level (`lod_far`) is the guaranteed fallback. Ships with no `lod_*` children, or only a single sprite, keep rendering their existing sprite unchanged, so the system is additive and backwards compatible.

Recommended Godot import settings for each LOD texture:
- Import > Compress > Mode: Lossless.
- Import > Mipmaps > Generate: On.
- Sprite2D/CanvasItem `texture_filter`: Linear With Mipmaps.