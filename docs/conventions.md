# Coding Conventions — Nebula Conquest

These rules keep the codebase consistent and ready for a future server/client
split. Follow them for every milestone.

## Engine & Language
- Godot **4.6**, GDScript with **static typing** wherever practical (`var x: int = 0`, typed params, typed returns).
- Always use `class_name` for reusable scripts (resources, components, base nodes).
- Use tabs for indentation (Godot default).

## Project Layout
| Folder        | Purpose                                                        |
| ------------- | -------------------------------------------------------------- |
| `scenes/`     | Gameplay `.tscn` scenes (ships, planets, world, homebase).     |
| `scripts/`    | Reusable `.gd` scripts not bound to a single scene.            |
| `resources/`  | `.tres` data resources (`ShipData`, `FactionData`, …).         |
| `shaders/`    | `.gdshader` files (planet displacement, capture ring, skybox). |
| `ui/`         | Menus, HUD, and other `Control`-based scenes/scripts.          |
| `assets/`     | Art, audio, fonts, meshes, textures.                           |
| `autoload/`   | Global singletons registered in Project Settings.              |
| `tests/`      | Isolated sandbox scenes per milestone for verification.        |

## Naming
- Files & scenes: `PascalCase` (`ShipBase.tscn`, `ShipData.gd`).
- Folders: `lowercase`.
- Classes / nodes: `PascalCase`. Functions & variables: `snake_case`.
- Constants & enums values: `CONSTANT_CASE`. Signals: `snake_case`, past-tense for events (`ship_destroyed`).
- Private members prefixed with `_` (`_current_target`).

## Architecture Rules
- **Signal-first communication.** Systems talk through signals — local node
  signals for local concerns, the `EventBus` autoload for cross-system events.
  Avoid tight references between unrelated systems.
- **Data-driven design.** All tunable/balance numbers live in `Resource`
  files (`ShipData`, `FactionData`, future `ResourceNodeData`) — never
  hard-coded inside logic.
- **Simulation vs. presentation.** Keep gameplay/simulation logic separate from
  visuals/UI so the simulation layer can later run authoritatively on a server.
- **Determinism.** Procedural generation must be seed-driven and reproducible;
  identical coordinates must always yield identical systems.

## Autoload Singletons (registered in `project.godot`)
| Name              | Responsibility                                            |
| ----------------- | --------------------------------------------------------- |
| `EventBus`        | Global signal hub; no state, only signals.                |
| `GameState`       | Volatile session/match state (faction, wallet, phase).    |
| `SettingsManager` | Loads/saves user options via `ConfigFile`.                |
| `SceneRouter`     | Scene switching with fade/warp transitions.               |

Load order matters: `EventBus` is registered first so the others may emit on it.

## Input Actions (Project Settings → Input Map)
| Action            | Binding         | Purpose                          |
| ----------------- | --------------- | -------------------------------- |
| `navigate`        | LMB             | Click-to-move waypoint.          |
| `aim_fire`        | RMB / Space     | Aim & fire primary weapon.       |
| `manual_thrust`   | W               | Manual forward thrust.           |
| `cam_rotate_left` | Q               | Orbit camera left.               |
| `cam_rotate_right`| E               | Orbit camera right.              |
| `zoom_in`          | Wheel Up        | Zoom in camera.                  |
| `zoom_out`         | Wheel Down      | Zoom out camera.                 |
| `tactical_map`    | M               | Toggle tactical map.             |
| `ability_1`       | 1               | Archetype ability 1.             |
| `ability_2`       | 2               | Archetype ability 2.             |
| `scan_ping`       | F               | Active long-range sensor ping.   |

## Physics Layers (Project Settings → Layer Names → 3D Physics)
1. `Ship` · 2. `Planet` · 3. `ResourceNode` · 4. `Hazard` · 5. `Projectile` · 6. `CaptureZone` · 7. `Homebase`

## Testing
- Add a lightweight sandbox scene under `tests/` for each milestone.
- Cover the highest-risk areas explicitly: determinism (seeds) and
  economy/penalty math.
