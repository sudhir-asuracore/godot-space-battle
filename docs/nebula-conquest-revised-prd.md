# Product Requirement Document (PRD) - 2D Version

## Project Nebula Conquest (Working Title)

- **Target Engine:** Godot 4.x (Stable)
- **Target OS:** Ubuntu Linux / Cross-platform Desktop
- **Game Type:** Session-based 2D top-down tactical space conquest game.
- **Architecture:** Local-first simulation designed with clean separation between game state, input, AI, and presentation layers so future multiplayer can be added without rewriting core systems.
- **Visual Style:** Vibrant, stylized 2D sci-fi with readable top-down ship silhouettes, high-quality sprite artwork, particle systems, engine trails, shield effects, and dynamic 2D lighting/shaders.
- **Control Philosophy:** Easy to command, hard to master. The player should focus on movement, positioning, target priority, ability timing, and strategic planet control rather than manual aiming and constant firing.

---

# 1. Executive Summary & Vision

**Nebula Conquest** is a tactical, session-based 2D top-down space action game combining arcade-inertia ship movement, auto-firing combat, faction-based ship progression, planetary conquest, and a final homebase siege objective.

Players select a faction, spawn near their faction's homebase planet in a light assault ship, capture neutral and enemy planets to earn prestige, purchase stronger ships, and ultimately eliminate the enemy faction's protected homebase.

The game should feel like a small-scale playable space war where the player personally participates in the conquest of a solar system.

---

# 2. Core Design Pillars

## 2.1 Arcade Space Movement

Ships should feel like spacecraft, but the movement should prioritize fun and control over true physics realism.

Movement should include:

- smooth acceleration
- readable turning
- satisfying drift
- assisted braking
- tactical boost/survival abilities
- faction and class movement personality

The goal is **arcade inertia**, not realistic Newtonian simulation.

## 2.2 Tactical Targeting & Auto-Fire Combat

Basic weapons auto-fire at the player's selected target when valid.

The player should make meaningful combat decisions through:

- target selection
- positioning
- ability usage
- retreat timing
- planet control
- prestige spending

Manual aiming and constant fire-button holding are intentionally removed to reduce input overload.

## 2.3 Planetary Conquest

Planets are the strategic heart of the match.

Capturing planets provides prestige income, map control, forward pressure, and access to the enemy homebase siege condition.

## 2.4 Faction Identity

Each faction should feel different visually and mechanically.

Faction choice affects:

- ship silhouette
- color language
- movement feel
- stat modifiers
- preferred combat style
- survival ability flavor

## 2.5 Escalating Session Arc

Each match should naturally progress from small skirmishes to larger fleet battles and then into a final siege.

The player should always understand the current strategic goal:

1. Capture planets.
2. Earn prestige.
3. Upgrade ships.
4. Control the majority.
5. Break the enemy homebase shield.
6. Destroy the enemy homebase.

---

# 3. Gameplay Overview

## 3.1 Match Start

At the beginning of a match:

- Player selects one faction.
- Enemy faction spawns on another homebase planet.
- Player begins in a Tier 1 Light Assault ship.
- Neutral planets are distributed across the map.
- Player receives starting prestige.
- Enemy AI begins expanding toward nearby neutral planets.

## 3.2 Match Objective

The main objective is to destroy the enemy faction's homebase.

However, homebases are protected by a shield interlock network. A homebase cannot take hull damage until the attacking faction controls a majority of planets in the solar system.

## 3.3 Core Loop

1. Launch from homebase.
2. Move toward neutral or enemy planets.
3. Lock targets and auto-fire basic weapons.
4. Use abilities to survive, attack, defend, or support.
5. Capture planets.
6. Earn prestige.
7. Purchase stronger ships or respawn after death.
8. Push toward enemy territory.
9. Capture majority control.
10. Siege and destroy enemy homebase.

---

# 4. Camera & View System

## 4.1 Perspective

- **Perspective:** 2D top-down.
- **Node:** `Camera2D`.
- **Default Behavior:** Camera follows the active player ship.

## 4.2 Camera Tracking

The camera should:

- follow the player ship smoothly
- use position smoothing/interpolation
- allow adjustable zoom levels later if needed
- maintain clear readability during fleet battles

## 4.3 Removed Camera Rotation

The original `Q` and `E` screen rotation concept is removed.

Reason:

- top-down combat needs strong spatial readability
- camera rotation can confuse player orientation
- fixed orientation makes planets, fleets, and objectives easier to track
- fewer camera controls reduces input complexity

## 4.4 Optional Camera Pan

WASD camera panning may be supported, but it should not be required for normal play.

Recommended MVP behavior:

- camera follows ship automatically
- optional mouse-edge or WASD pan can be added later
- camera recenters on player after a short delay or button press

---

# 5. Input & Control Scheme

## 5.1 Core Inputs

| Input | Action |
|---|---|
| Left-click on space | Move/autopilot to destination |
| Right-click enemy | Lock target |
| Right-click empty space | Clear current target or issue contextual command |
| Mouse hover enemy | Highlight valid target |
| `1` | Survival/mobility ability |
| `2` | Offensive ability |
| `3` | Defensive ability |
| `4` | Class utility ability |
| `5` | Ultimate/high-cost ability, optional for later |
| `Spacebar` | Optional hold position, emergency brake, or target nearest enemy |
| `Esc` | Open pause/menu |

## 5.2 Targeting

Targeting should be stable and deliberate.

Recommended behavior:

- Hovering over an enemy highlights it.
- Right-clicking an enemy locks it as the current target.
- The ship continues auto-firing at the locked target while valid.
- If the target dies, the target lock clears or switches to the nearest hostile depending on selected accessibility settings.
- If the target leaves range for too long, the ship stops firing but may retain the lock briefly.
- Right-clicking empty space clears the target.

## 5.3 Basic Weapon Auto-Fire

Basic weapons automatically fire at the current locked target if:

- the target is alive
- the target is hostile
- the target is within weapon range
- weapon cooldown is ready
- the ship is not disabled
- line-of-sight rules allow firing, if line-of-sight is implemented
- capacitor or ammo conditions are satisfied, if applicable

The player should not need to hold a fire button for basic attacks.

## 5.4 Ability Activation

Special abilities are triggered manually with keys `1` through `5`.

Abilities should create meaningful combat moments such as:

- emergency escape
- last-second shield activation
- cloak activation
- burst damage
- turret deployment
- fleet repair
- area denial
- capture-zone control

## 5.5 Survival Ability Slot

Key `1` should usually be mapped to a survival, mobility, or escape tool.

Examples:

| Faction/Class | Key `1` Ability Example |
|---|---|
| Iron Vanguard | Super-shield / armor lockdown |
| Solarion Collective | Capacitor shield burst |
| Nebula Wraiths | Cloak and speed surge |
| Assault | Afterburner |
| Engineer | Emergency armor anchor |
| Medic | Phase pulse / self-shield restore |

This gives the player a reliable last-minute tactical option.

---

# 6. Ship Movement Dynamics

## 6.1 Movement Philosophy

Ship movement should be **fun first, physics second**.

The ship should feel like it has mass and momentum, but the player should never feel like they are fighting the controls.

Recommended feel:

> Drifty arcade movement with assisted autopilot, fake space friction, side-drift damping, and tactical movement bursts.

## 6.2 Recommended Node Choice

For player and AI-controlled ships, prefer:

- `CharacterBody2D` with a custom velocity simulation

Use `RigidBody2D` for:

- debris
- wreckage
- asteroids
- physics props
- non-critical environmental objects

Reason:

`CharacterBody2D` gives tighter gameplay control over acceleration, braking, speed limits, steering, arrival behavior, and AI pathing. This is better for a game that should feel responsive rather than physically accurate.

## 6.3 Movement Model

When the player left-clicks a destination:

1. Convert mouse position to world position.
2. Store it as the current navigation target.
3. Ship turns toward the destination.
4. Ship accelerates toward the destination.
5. Ship retains some forward momentum.
6. Sideways drift is damped faster than forward movement.
7. Near destination, assisted braking activates.
8. Ship comes to a smooth stop near the clicked point.

## 6.4 Fake Space Friction

True space has no friction, but this game should use designed friction.

Recommended damping model:

| Damping Type | Purpose |
|---|---|
| Forward damping | Keeps speed under control while preserving spacecraft feel |
| Lateral damping | Reduces ugly sideways sliding |
| Arrival damping | Helps ship stop near target |
| Combat damping | Optional modifier used while in combat for tighter control |

The key feel rule:

> Let ships drift forward, but reduce sideways drift faster.

## 6.5 Assisted Braking

Assisted braking activates when the ship enters a destination radius.

Braking should:

- reduce overshooting
- feel smooth
- vary by class and faction
- be stronger for heavier ships if needed for readability
- never instantly stop the ship unless using an explicit emergency brake ability

## 6.6 Turning Dynamics

Ships should not rotate instantly.

Turning speed communicates weight and class identity.

| Ship Type | Turning Feel |
|---|---|
| Light ships | Quick and responsive |
| Medium ships | Controlled and balanced |
| Heavy ships | Slow, committed, powerful |
| Wraith ships | Sharp but slippery |
| Vanguard ships | Heavy and deliberate |
| Solarion ships | Smooth and precise |

## 6.7 Movement Skill Expression

Since basic weapons auto-fire, movement becomes the player's main mechanical skill.

The player should be rewarded for:

- kiting heavier enemies
- boosting out of danger
- hiding behind planets or defenses
- entering and exiting capture zones at the right time
- retreating before ship destruction
- flanking enemy formations
- using faction survival abilities creatively

## 6.8 Optional Planet Movement Effects

Planet-based movement effects can be added later to make the map more interesting.

Examples:

| Planet Type | Movement Effect |
|---|---|
| Large planet | Mild gravity pull near orbit |
| Gas planet | Slows ships inside cloud radius |
| Magnetic planet | Slight steering disruption |
| Asteroid field | Blocks movement and line-of-sight |
| Homebase planet | Defensive pushback or shield pressure zone |

These effects should be subtle and should not make the player lose control.

---

# 7. Faction Design

## 7.1 Faction Overview

Upon starting a match, the player selects one of three factions.

Faction modifiers affect base ship data, movement feel, visual style, and ability flavor.

| Faction Name | Theme Profile | Global Stat Modifiers | Movement Identity |
|---|---|---|---|
| **The Iron Vanguard** | Chonky, brutalist metallic hulls with bright orange thrusters | Hull Health `x1.25`, Base Speed `x0.90` | Heavy, stable, powerful, slower to turn |
| **The Solarion Collective** | Sleek white/gold profiles with neon blue accents | Shield Capacity `x1.30`, Capacitor Max `x1.15` | Smooth, precise, controlled, elegant |
| **The Nebula Wraiths** | Asymmetrical scavenger hulls with exposed frames and purple emitters | Max Speed `x1.15`, Thrust Power `x1.20`, Shields `x0.80` | Fast, slippery, fragile, aggressive |

## 7.2 Visual Silhouette Rules

Faction ships must be readable at small top-down sizes.

| Faction | Silhouette Language |
|---|---|
| Iron Vanguard | Wide, blocky, armored, industrial |
| Solarion Collective | Symmetrical, sleek, clean, advanced |
| Nebula Wraiths | Jagged, asymmetric, predatory, scavenged |

## 7.3 Faction Survival Ability Flavor

| Faction | Survival Flavor |
|---|---|
| Iron Vanguard | Super-shield, armor lock, damage resistance |
| Solarion Collective | Shield recharge, capacitor burst, clean energy dash |
| Nebula Wraiths | Invisibility cloak, phase slip, speed surge |

---

# 8. Ship Classes & Tiers

## 8.1 Class Roles

| Class | Role | Combat Identity |
|---|---|---|
| Assault | Damage dealer / frontline attacker | Dives into fights, kills targets, escapes with boost |
| Engineer | Defender / fortifier / area control | Deploys turrets, locks down planets, supports captures |
| Medic | Fleet support / sustain / rescue | Repairs allies, restores shields, keeps pushes alive |

## 8.2 Ship Class and Tier Performance Matrix

These values are initial balancing targets and should be adjusted during playtesting.

| Ship Class & Tier | Hull HP | Shield | Max Speed | Thrust/Accel | Capacitor Max | Regen Rate |
|---|---:|---:|---:|---:|---:|---:|
| **T1 Light Assault** | 100 | 50 | 35 | 45 | 100 | 15/s |
| **T2 Medium Assault** | 250 | 150 | 28 | 75 | 120 | 18/s |
| **T3 Heavy Assault** | 600 | 300 | 20 | 110 | 150 | 20/s |
| **T1 Light Engineer** | 150 | 30 | 24 | 30 | 80 | 10/s |
| **T2 Medium Engineer** | 350 | 100 | 20 | 55 | 100 | 12/s |
| **T3 Heavy Engineer** | 850 | 200 | 15 | 85 | 130 | 15/s |
| **T1 Light Medic** | 90 | 60 | 30 | 35 | 120 | 22/s |
| **T2 Medium Medic** | 200 | 180 | 25 | 60 | 150 | 26/s |
| **T3 Heavy Medic** | 500 | 350 | 18 | 90 | 180 | 30/s |

## 8.3 Movement Feel by Class

| Class | Movement Feel |
|---|---|
| Assault | Medium drift, strong forward boost, aggressive acceleration |
| Engineer | Heavy, stable, slower movement, strong braking |
| Medic | Smooth, evasive, good turning, clean repositioning |

---

# 9. Weapons & Abilities

## 9.1 Basic Weapon Rules

Basic weapons auto-fire at locked targets.

Each weapon should have:

- range
- cooldown/fire rate
- projectile or beam behavior
- shield damage
- hull damage
- tracking or aim tolerance
- visual effect
- audio effect

## 9.2 Assault Archetype

### Weapon: Kinetic Autocannons

- Moderate shield damage
- High hull damage
- Reliable sustained fire
- Best against exposed hull targets

### Ability Examples

| Key | Ability | Description |
|---|---|---|
| `1` | Afterburner | Strong forward thrust burst for escape or chase |
| `2` | Overcharge Weapons | Temporarily increases weapon damage |
| `3` | Emergency Armor Burst | Short defensive damage reduction |
| `4` | Missile Barrage | Fires multiple guided or semi-guided missiles |
| `5` | Heavy Assault Mode | Optional late-game high-cost power mode |

## 9.3 Engineer Archetype

### Weapon: Flak Cannon

- Proximity explosive projectile
- Area-of-effect damage
- Good against groups
- Useful around capture zones

### Ability Examples

| Key | Ability | Description |
|---|---|---|
| `1` | Emergency Armor Anchor | Briefly stabilizes ship and reduces incoming damage |
| `2` | Deploy Sentinel | Drops an automated turret |
| `3` | Fortification Anchor | Locks ship in place, increases damage reduction, improves nearby capture pressure |
| `4` | Repair Drone | Deploys a drone that repairs allied ships or structures |
| `5` | Orbital Minefield | Optional late-game area denial ability |

## 9.4 Medic Archetype

### Weapon: Thermal Beam

- Continuous beam or rapid trace weapon
- Strong shield stripping
- Lower hull damage
- Good support pressure

### Ability Examples

| Key | Ability | Description |
|---|---|---|
| `1` | Phase Pulse | Short evasive movement burst and self-shield restore |
| `2` | Nanite Projection | Channeled healing beam for allies |
| `3` | Discharge Field | Restores nearby friendly shields and resets shield cooldowns |
| `4` | Shield Link | Links with an ally, sharing shield recovery or damage mitigation |
| `5` | Fleet Recovery Pulse | Optional late-game mass repair ability |

## 9.5 Ability Design Rules

Abilities should:

- have clear cooldowns
- have clear capacitor costs
- be visually readable
- create tactical moments
- avoid overwhelming the player early
- scale by tier through numbers, range, duration, or effect count

---

# 10. Economy & Match Progression

## 10.1 Match Phases

Matches follow an automated escalation structure.

### Phase 1: Land Grab — Minutes 0-5

- Player and enemy spawn at homebases.
- Neutral planets become the primary objective.
- Tier 1 ships dominate.
- Small skirmishes occur around nearby planets.

### Phase 2: Escalation — Minutes 5-15

- Multiple planets are owned.
- Economy begins to matter.
- Tier 2 ships enter the field.
- Engineers and support ships become more valuable.
- Mid-map planets become contested.

### Phase 3: Siege — Minute 15+

- Planet income pressure increases.
- Tier 3 ships may appear.
- Majority control becomes decisive.
- Homebase shields can fall.
- Final siege begins.

## 10.2 Economic Constants

Initial values:

- **Starting Funds:** 200 Prestige
- **Planet Capture Reward:** +100 Prestige to capturing actor
- **Friendly Capture Assist Reward:** +50 Prestige shared across friendly units inside the capture ring
- **Planet Holding Yield:** +2 Prestige/second to owning faction treasury
- **Defensive Bounty Bonus:** Kills inside allied planetary capture rings yield +50% prestige

## 10.3 Ship Purchase, Death Penalty & Kill Rewards

| Ship Tier | Purchase Cost | Death Penalty | Enemy Kill Reward |
|---|---:|---:|---:|
| **Tier 1 Light** | 150 | 37 | 75 |
| **Tier 2 Medium** | 500 | 125 | 250 |
| **Tier 3 Heavy** | 1200 | 300 | 600 |

## 10.4 Respawn Logic

On ship destruction:

1. Player ship is destroyed.
2. Death penalty is deducted from personal prestige wallet.
3. Player returns to the Homebase deployment menu.
4. Player purchases or selects an available ship.
5. If player funds fall below 150 Prestige, Tier 1 ships are available for free to prevent softlocks.

## 10.5 Snowball Protection

Territory-control games can snowball quickly, so optional comeback mechanics should be considered after MVP.

Possible systems:

- losing faction receives bonus prestige for killing higher-tier ships
- homebase periodically launches free defense waves
- planets near a losing faction's homebase are harder for enemies to capture
- capture speed slightly increases for the faction that controls fewer planets
- Tier 1 ships remain permanently free when the player is behind

These should be tuned carefully and should not feel unfair.

---

# 11. Planetary Domination Rules

## 11.1 Planet Entity

Each capturable planet has:

- visual sprite
- collision boundary
- capture ring
- ownership state
- capture progress
- income value
- optional planet type modifier
- optional defensive structures

## 11.2 Capture Zone

Capture is handled by an `Area2D` ring around the planet.

Ships inside the ring contribute capture pressure based on faction and optional ship weight.

## 11.3 Capture Evaluation

Capture should be evaluated on a timer tick rather than every frame.

Basic rules:

- If only Faction A is present, progress moves toward Faction A.
- If only Faction B is present, progress moves toward Faction B.
- If multiple factions are present, the planet becomes contested.

## 11.4 Contested Capture Recommendation

Instead of fully freezing capture progress whenever both factions are present, use weighted capture pressure.

Recommended model:

- friendly capture pressure is compared against enemy pressure
- if one side has more pressure, progress moves slowly in that side's favor
- if pressure is equal or nearly equal, progress freezes
- heavier ships may contribute more pressure
- Engineer fortification can increase nearby capture pressure
- Medic support can keep allied ships alive during capture pushes

This avoids situations where one weak ship completely blocks a large fleet.

## 11.5 Planet Types

Planet types can be added after the basic capture loop is working.

| Planet Type | Strategic Role |
|---|---|
| Mining Planet | Higher prestige income |
| Fortress Planet | Built-in defenses and slower capture |
| Shipyard Planet | Reduces ship purchase cost or respawn time |
| Relay Planet | Extends radar/vision range |
| Gas Planet | Adds movement or visibility hazards |
| Neutral Colony | Balanced default planet |

## 11.6 Homebase Shield Interlock Network

Homebases have a structural shield that reduces incoming hull damage by 100%.

The shield drops only when an attacking faction controls a clear majority of planets.

Example:

- Total capturable planets: 7
- Required majority: 4
- If player faction owns 4 or more, enemy homebase shield drops
- If player loses majority, enemy homebase shield reactivates after a warning delay

Recommended warning delay:

- shield does not instantly toggle
- use a 10-20 second warning period
- broadcast clear UI alerts to both sides

---

# 12. AI Director & State Framework

## 12.1 AI Goals

Enemy AI should make the map feel alive without requiring full RTS-level intelligence.

AI should:

- capture neutral planets
- defend owned planets
- attack weakly defended planets
- retreat when badly damaged
- group for siege pushes
- respond to homebase vulnerability
- purchase ships based on available prestige

## 12.2 Strategic Director

A faction-level AI director tracks:

- owned planets
- enemy-owned planets
- neutral planets
- nearby threats
- available prestige
- fleet strength
- homebase shield status
- vulnerable objectives

The director issues broad goals such as:

- `CAPTURE_NEAREST_NEUTRAL`
- `DEFEND_PLANET`
- `ATTACK_WEAK_PLANET`
- `RETREAT_TO_HOMEBASE`
- `GROUP_FOR_SIEGE`
- `ATTACK_HOMEBASE`

## 12.3 Local Ship State Machine

Each ship has a local state machine.

Recommended states:

```text
SPAWN
  -> NAVIGATING
  -> CAPTURING
  -> COMBAT_ENGAGED
  -> RETREAT
  -> RETURN_TO_OBJECTIVE
  -> DEAD
```

## 12.4 AI Movement

AI ships should use the same movement controller as player ships.

This ensures:

- consistent movement feel
- easier balancing
- predictable combat
- shared codebase
- fair behavior

## 12.5 AI Targeting

AI ships should auto-select targets based on priority.

Possible targeting priorities:

1. enemy attacking current objective
2. low-health enemy
3. enemy medic/support
4. enemy inside capture ring
5. closest enemy
6. enemy homebase structure during siege

---

# 13. Technical Architecture & Data Model

## 13.1 Data-Driven Design

Core gameplay values should be stored in custom Godot `Resource` files.

Benefits:

- easier balancing
- cleaner code
- fewer hardcoded values
- easier faction/class/tier expansion
- easier integration with coding assistants

## 13.2 ShipData Resource

```gdscript
extends Resource
class_name ShipData

@export_category("Profile")
@export var name: String = "Scout"
@export var tier: int = 1
@export var ship_class: String = "Assault"
@export var faction: String = ""

@export_category("Vitals")
@export var max_hull: float = 100.0
@export var max_shield: float = 50.0
@export var shield_regen: float = 5.0
@export var shield_regen_delay: float = 3.0

@export_category("Movement")
@export var max_speed: float = 35.0
@export var acceleration: float = 45.0
@export var turn_speed: float = 4.0
@export var forward_damping: float = 0.08
@export var lateral_damping: float = 0.18
@export var arrival_radius: float = 80.0
@export var braking_strength: float = 1.5

@export_category("Capacitor")
@export var max_capacitor: float = 100.0
@export var capacitor_regen: float = 15.0

@export_category("Weapons")
@export var basic_weapon: WeaponData
@export var target_lock_range: float = 600.0

@export_category("Abilities")
@export var ability_1: AbilityData
@export var ability_2: AbilityData
@export var ability_3: AbilityData
@export var ability_4: AbilityData
@export var ability_5: AbilityData

@export_category("Economy")
@export var purchase_cost: float = 150.0
@export var kill_bounty: float = 75.0
@export var death_penalty: float = 37.0
```

## 13.3 FactionData Resource

```gdscript
extends Resource
class_name FactionData

@export_category("Profile")
@export var name: String = "Iron Vanguard"
@export var description: String = ""
@export var primary_color: Color
@export var secondary_color: Color

@export_category("Stat Modifiers")
@export var hull_multiplier: float = 1.0
@export var shield_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0
@export var acceleration_multiplier: float = 1.0
@export var capacitor_multiplier: float = 1.0

@export_category("Movement Feel")
@export var turn_speed_multiplier: float = 1.0
@export var lateral_damping_multiplier: float = 1.0
@export var braking_multiplier: float = 1.0

@export_category("AI Personality")
@export var aggression: float = 1.0
@export var defense_bias: float = 1.0
@export var expansion_bias: float = 1.0
```

## 13.4 WeaponData Resource

```gdscript
extends Resource
class_name WeaponData

@export var name: String = "Autocannon"
@export var range: float = 500.0
@export var cooldown: float = 0.25
@export var shield_damage: float = 5.0
@export var hull_damage: float = 10.0
@export var projectile_speed: float = 900.0
@export var spread_degrees: float = 2.0
@export var is_beam: bool = false
@export var auto_fire: bool = true
```

## 13.5 AbilityData Resource

```gdscript
extends Resource
class_name AbilityData

@export var name: String = "Afterburner"
@export var description: String = ""
@export var capacitor_cost: float = 30.0
@export var cooldown: float = 8.0
@export var duration: float = 1.5
@export var ability_type: String = "Mobility"
@export var icon: Texture2D
```

## 13.6 PlanetData Resource

```gdscript
extends Resource
class_name PlanetData

@export var name: String = "Neutral Colony"
@export var planet_type: String = "Default"
@export var income_per_second: float = 2.0
@export var capture_radius: float = 300.0
@export var capture_required: float = 100.0
@export var capture_resistance: float = 1.0
@export var has_defenses: bool = false
```

---

# 14. Scene Node Layouts

## 14.1 Planet Entity Hierarchy

```text
StaticBody2D (Planet root)
├── Sprite2D (Planet terrain sprite)
├── CollisionShape2D (Planet collision)
├── Area2D (Capture ring detection zone)
│   ├── CollisionShape2D (Capture radius)
│   └── Sprite2D or Line2D (Capture ring/progress visual)
├── Node2D (DefenseSlots)
│   └── Turret nodes, if any
└── PointLight2D (Planet ambient lighting)
```

## 14.2 Ship Base Setup

```text
CharacterBody2D (Ship root)
├── Sprite2D (Ship sprite)
├── CollisionShape2D (Ship collision)
├── Marker2D (Weapon muzzle)
├── Marker2D (Engine trail origin)
├── GPUParticles2D (Thruster particles)
├── Node2D (WeaponController)
├── Node2D (AbilityController)
├── Node2D (TargetingController)
└── Node (StateMachine)
```

## 14.3 Projectile Setup

```text
Area2D (Projectile root)
├── Sprite2D or AnimatedSprite2D
├── CollisionShape2D
├── GPUParticles2D
└── Timer (Lifetime)
```

## 14.4 Homebase Setup

```text
StaticBody2D (Homebase root)
├── Sprite2D (Homebase planet/base visual)
├── CollisionShape2D
├── Area2D (Defense perimeter)
├── Node2D (Defense turrets)
├── Sprite2D or ShaderLayer (Shield visual)
├── HealthComponent
└── HomebaseShieldController
```

---

# 15. UI & Feedback

## 15.1 Essential HUD Elements

The HUD should show:

- hull
- shield
- capacitor
- current target
- weapon status
- ability cooldowns for `1-5`
- prestige amount
- owned planet count
- majority control status
- homebase shield status
- minimap or radar, later

## 15.2 Target Feedback

When a target is locked:

- show target reticle
- show target health/shield bar
- show range indicator if out of range
- show line-of-sight blocked indicator if applicable
- show weapon firing arcs or range rings later if useful

## 15.3 Planet Feedback

Planets should clearly show:

- neutral/owned/contested state
- capture progress
- owning faction color
- income value
- shield/homebase connection status
- defense structures if present

## 15.4 Ability Feedback

Abilities need strong readability:

- icon cooldown timers
- key labels
- activation sound
- visual effect
- capacitor cost feedback
- failed activation feedback

---

# 16. Art Direction Notes

## 16.1 Top-Down Readability

Because the game is top-down, ships must have:

- clear front/back direction
- strong silhouette
- visible engine locations
- readable faction colors
- distinct tier size increases
- minimal noisy detail at gameplay zoom

## 16.2 Effects

Important effects:

- thruster flames
- afterburner burst
- shield impact
- cloak shimmer
- super-shield activation
- weapon muzzle flashes
- projectile trails
- capture ring progress
- planet ownership aura
- homebase shield collapse

## 16.3 Faction Color Language

| Faction | Suggested Colors |
|---|---|
| Iron Vanguard | Dark steel, gunmetal, orange thrusters |
| Solarion Collective | White, gold, neon blue |
| Nebula Wraiths | Dark purple, black metal, violet emitters |

---

# 17. Audio Direction

Audio should reinforce faction and ship feel.

## 17.1 Core Audio Needs

- engine hum per ship class
- thruster burst
- afterburner
- cloak activation
- super-shield activation
- weapon fire
- shield impact
- hull damage
- planet capture start
- planet captured
- contested alert
- homebase shield down
- victory/defeat stingers

## 17.2 Audio Personality

| Faction | Audio Feel |
|---|---|
| Iron Vanguard | Heavy, metallic, industrial |
| Solarion Collective | Clean, harmonic, energy-based |
| Nebula Wraiths | Distorted, unstable, stealthy |

---

# 18. MVP Scope

The MVP should prove the full match loop with the smallest possible feature set.

The goal is not to build every faction, class, tier, and ability immediately.

The goal is:

> One fun ship, a few planets, one enemy faction, one complete match.

## 18.1 MVP Feature Set

### Must Have

| Area | MVP Requirement |
|---|---|
| Movement | One player ship with arcade inertia, assisted braking, and click-to-move |
| Targeting | Right-click enemy target lock |
| Combat | Basic weapon auto-fire against locked target |
| Ability | One survival/mobility ability on `1`, such as Afterburner |
| Planets | 3-5 capturable planets |
| Capture System | Capture ring, ownership state, contested state |
| Economy | Starting prestige, capture reward, planet income |
| Enemy AI | Basic enemy ships that move to capture/attack planets |
| Respawn | Player death and respawn at homebase |
| Homebases | Player and enemy homebase |
| Win Condition | Majority planet control disables enemy homebase shield, then destroy enemy homebase |
| UI | Hull, shield, capacitor, prestige, planet ownership, target lock, ability cooldown |

### Should Have

| Area | MVP+ Requirement |
|---|---|
| Factions | 2 factions instead of all 3 |
| Ship Types | T1 Assault only |
| Planet Count | 5 planets for stronger conquest loop |
| Basic AI Director | Enemy chooses nearest neutral/enemy planet |
| Homebase Shield Alert | Clear warning when shield drops or reactivates |
| Simple Minimap | Optional but useful |

### Not Needed for MVP

| Feature | Reason to Delay |
|---|---|
| All 3 factions | Adds balancing and art workload |
| Engineer and Medic classes | Requires support AI and more complex abilities |
| Tier 2 and Tier 3 ships | Adds economy complexity |
| Full ability set `1-5` | Too much balance work early |
| Planet type modifiers | Add after basic capture is fun |
| Multiplayer | Requires architecture discipline, but not implementation |
| Advanced camera controls | Fixed follow camera is enough |
| Complex AI strategy | Basic expansion/defense is enough |
| Line-of-sight | Can be added after combat works |
| Large fleet battles | First prove small battles feel good |

## 18.2 MVP Development Milestones

### Milestone 1: Flight Feel Prototype

Goal:

- one ship moves well

Tasks:

- implement click-to-move
- implement smooth acceleration
- implement turning speed
- implement lateral damping
- implement assisted braking
- implement afterburner on `1`
- tune movement until it feels fun

Success Criteria:

- moving around empty space is enjoyable
- player can stop near clicked destination
- afterburner feels useful and exciting
- movement does not feel like fighting physics

---

### Milestone 2: Targeting & Auto-Fire Combat

Goal:

- basic combat works without manual firing

Tasks:

- add enemy dummy ships
- right-click target lock
- target reticle UI
- basic weapon auto-fire
- hull/shield damage
- death/destruction effects

Success Criteria:

- player can select an enemy and automatically attack
- combat feels readable
- player focuses on positioning and ability timing

---

### Milestone 3: Planet Capture Loop

Goal:

- planets can be captured and owned

Tasks:

- add 3 neutral planets
- add capture rings
- add ownership state
- add capture progress UI
- add contested state
- add planet income

Success Criteria:

- player understands how to capture planets
- planet ownership is visually obvious
- capture rewards feel meaningful

---

### Milestone 4: Basic Enemy Faction

Goal:

- the map feels alive

Tasks:

- enemy homebase
- enemy T1 assault ship spawning
- simple AI movement
- AI captures neutral planets
- AI attacks player-owned planets
- AI targets player in combat range

Success Criteria:

- enemy faction expands without manual scripting
- player has to respond to threats
- planet control changes over time

---

### Milestone 5: Prestige, Respawn & Ship Purchase

Goal:

- economy loop exists

Tasks:

- prestige wallet
- capture reward
- passive planet income
- death penalty
- respawn at homebase
- basic deployment menu
- free T1 fallback if player is broke

Success Criteria:

- player can die and continue
- prestige creates meaningful decisions
- economy does not softlock the player

---

### Milestone 6: Homebase Shield & Victory Condition

Goal:

- complete match loop exists

Tasks:

- player homebase
- enemy homebase
- homebase shield interlock
- majority planet control check
- shield down/up alerts
- homebase damage
- victory/defeat state

Success Criteria:

- player can win a full match
- enemy homebase cannot be rushed early
- planet majority clearly matters

---

## 18.3 Recommended First Playable Version

The first playable version should include:

- 1 player faction
- 1 enemy faction
- 1 ship class: T1 Light Assault
- 1 ability: Afterburner
- 3-5 planets
- basic auto-fire combat
- basic AI
- prestige income
- respawn
- enemy homebase shield
- win condition

Do not add all classes, tiers, factions, planet types, and advanced abilities until this version is fun.

## 18.4 MVP Success Test

The MVP is successful if a player can say:

> "I understand what I need to do, moving feels good, fights are readable, capturing planets matters, and I want to play one more match."

That is the target.
