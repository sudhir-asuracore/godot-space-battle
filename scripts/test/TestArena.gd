extends Node2D
class_name TestArena

# Standalone test arena for prototyping ships, their weapons, flight and
# controls while building them. Launch this scene directly (F6 in the editor or
# as the run target) to:
#   * render a planet for scale,
#   * pick a faction and then any ship belonging to that faction and spawn it,
#   * always face a lockable enemy target so weapons can be tested immediately.
#
# It is intentionally self-contained: it does not rely on Main.gd, the solar
# system generator or the match flow, so spaceships can be iterated on in
# isolation.

const PLANET_SCENE: PackedScene = preload("res://scenes/solar_system/Planet.tscn")
const PLANET_DATA: PlanetData = preload("res://resources/planets/default_planet.tres")

# Factions offered in the picker. Only factions that ship with both a
# FactionData resource and at least one hull are listed (Aegis has none yet).
const FACTION_RESOURCE_PATHS: Array[String] = [
	"res://resources/factions/zarak/zarak_confedaracy.tres",
	"res://resources/factions/solarion_collective/solarion_collective.tres",
]

# Per-faction fallback ship scene, used when a ShipData has no `ship_scene`
# authored on it (e.g. the starter Scout / Striker Lance resources).
const FACTION_DEFAULT_SHIP_SCENES: Dictionary = {
	FactionData.Faction.ZARAK: "res://scenes/factions/zarak/ships/ZarakFrigate.tscn",
	FactionData.Faction.SOLARION: "res://scenes/factions/solarion/ships/Frigate.tscn",
}

# Where the player ship spawns and how far ahead the enemy target is placed.
# The enemy sits inside the default target-lock range so it can be locked and
# fired upon right away.
const PLAYER_SPAWN_POSITION: Vector2 = Vector2.ZERO
const ENEMY_SPAWN_OFFSET: Vector2 = Vector2(0.0, -280.0)
# The enemy is a practice dummy: it gets a much larger hull so it survives
# prolonged weapon testing instead of popping after a few hits.
const ENEMY_HULL_MULTIPLIER: float = 10.0
# Planet offset from the origin: far enough to read as background scale, close
# enough to stay framed when the camera follows the ship.
const PLANET_POSITION: Vector2 = Vector2(1600.0, -900.0)
const PLANET_SPRITE_SCALE: float = 2.5

@onready var _camera: GameCamera = $Camera2D as GameCamera
@onready var _world: Node2D = $World as Node2D
@onready var _faction_picker: OptionButton = $UI/Panel/VBox/FactionPicker as OptionButton
@onready var _ship_picker: OptionButton = $UI/Panel/VBox/ShipPicker as OptionButton
@onready var _spawn_button: Button = $UI/Panel/VBox/SpawnButton as Button
@onready var _status_label: Label = $UI/StatusLabel as Label

# FactionData resources loaded from FACTION_RESOURCE_PATHS, in picker order.
var _factions: Array[FactionData] = []

var _player_ship: Ship = null
var _enemy_ship: Ship = null
var _planet: Planet = null
var _targeting: TargetingController = null
var _ability: AbilityController = null

func _ready() -> void:
	_register_inputs()
	_spawn_planet()
	_populate_faction_picker()

	_faction_picker.item_selected.connect(_on_faction_selected)
	_ship_picker.item_selected.connect(_on_ship_selected)
	_spawn_button.pressed.connect(_on_spawn_pressed)

	# Default to the first faction and refresh its ship list.
	if _factions.size() > 0:
		_faction_picker.select(0)
		_populate_ship_picker(_factions[0])
	_update_status()

# --- Setup helpers -----------------------------------------------------------

func _spawn_planet() -> void:
	_planet = PLANET_SCENE.instantiate() as Planet
	if not _planet:
		return
	_planet.name = &"ScalePlanet"
	_planet.planet_data = PLANET_DATA
	_world.add_child(_planet)
	_planet.position = PLANET_POSITION
	var sprite := _planet.get_node_or_null(^"Sprite2D") as Sprite2D
	if sprite:
		sprite.scale = Vector2(PLANET_SPRITE_SCALE, PLANET_SPRITE_SCALE)

func _populate_faction_picker() -> void:
	_factions.clear()
	_faction_picker.clear()
	for path in FACTION_RESOURCE_PATHS:
		var faction := load(path) as FactionData
		if not faction:
			continue
		_factions.append(faction)
		_faction_picker.add_item(faction.get_faction_name())

func _populate_ship_picker(faction: FactionData) -> void:
	_ship_picker.clear()
	if not faction:
		return
	for option in faction.hangar_ship_options:
		var ship_data := option as ShipData
		if not ship_data:
			continue
		var label := ship_data.name
		var class_name_text := ship_data.get_ship_class_name()
		if not class_name_text.is_empty():
			label = "%s  (%s)" % [ship_data.name, class_name_text]
		_ship_picker.add_item(label)

# --- Picker callbacks --------------------------------------------------------

func _on_faction_selected(index: int) -> void:
	var faction := _faction_at(index)
	if faction:
		_populate_ship_picker(faction)
	_update_status()

func _on_ship_selected(_index: int) -> void:
	_update_status()

func _on_spawn_pressed() -> void:
	_spawn_selected_ship()

# --- Spawning ----------------------------------------------------------------

func _spawn_selected_ship() -> void:
	var faction := _selected_faction()
	var ship_data := _selected_ship_data()
	if not faction or not ship_data:
		_set_status("Pick a faction and a ship first.")
		return

	# Replace any previously spawned player ship and its enemy target so each
	# spawn starts from a clean, predictable arena. queue_free() is deferred, so
	# the old nodes are renamed first to release their canonical names for the
	# replacements added later this frame (otherwise Godot auto-suffixes them).
	if is_instance_valid(_player_ship):
		_player_ship.name = &"PlayerShipOld"
		_player_ship.queue_free()
	_player_ship = null
	if is_instance_valid(_enemy_ship):
		_enemy_ship.name = &"EnemyTargetOld"
		_enemy_ship.queue_free()
	_enemy_ship = null

	_player_ship = _instantiate_ship(ship_data, faction, true)
	if not _player_ship:
		_set_status("Could not load a scene for %s." % ship_data.name)
		return
	_player_ship.name = &"PlayerShip"
	_player_ship.global_position = PLAYER_SPAWN_POSITION

	_targeting = _player_ship.get_node_or_null(^"TargetingController") as TargetingController
	_ability = _player_ship.get_node_or_null(^"AbilityController") as AbilityController

	# Bind the camera to follow the freshly spawned ship.
	if _camera:
		_camera.target_node = _player_ship
		_camera.follow_target = true

	_spawn_enemy_target(faction)
	_update_status()

# Always provide an enemy of a different faction so the player ship has
# something to lock onto and fire at. It is left without an AI controller so it
# stays put as a stable target dummy. Its weapons/targeting are disabled so it
# never shoots back at the player, and its hull is greatly enlarged so it can
# soak up sustained fire while weapons are being tuned.
func _spawn_enemy_target(player_faction: FactionData) -> void:
	var enemy_faction := _other_faction(player_faction)
	if not enemy_faction:
		enemy_faction = player_faction
	var enemy_data := _first_ship_data(enemy_faction)
	if not enemy_data:
		_set_status("Enemy faction has no ships to spawn.")
		return
	_enemy_ship = _instantiate_ship(enemy_data, enemy_faction, false)
	if not _enemy_ship:
		return
	_enemy_ship.name = &"EnemyTarget"
	_enemy_ship.global_position = PLAYER_SPAWN_POSITION + ENEMY_SPAWN_OFFSET
	_make_passive_target(_enemy_ship)

# Turns the enemy into a harmless, durable practice dummy: it cannot acquire a
# target or fire (so it never attacks the player) and its hull is scaled up so
# it survives extended weapon testing.
func _make_passive_target(enemy: Ship) -> void:
	# Fortify the hull. update_stats() (called during spawn) already set
	# current_hull to the base max_hull, so both are raised together to keep the
	# ship at full health.
	enemy.max_hull *= ENEMY_HULL_MULTIPLIER
	enemy.current_hull = enemy.max_hull

	# Silence its offence so it never shoots back at the player.
	var weapon_controller := enemy.get_node_or_null(^"WeaponController")
	if weapon_controller:
		weapon_controller.process_mode = Node.PROCESS_MODE_DISABLED
	var targeting := enemy.get_node_or_null(^"TargetingController")
	if targeting:
		targeting.process_mode = Node.PROCESS_MODE_DISABLED

# Instantiates a ship scene for the given data/faction, wires the runtime stats
# and adds it to the world. Mirrors Main.gd's spawn recipe.
func _instantiate_ship(ship_data: ShipData, faction: FactionData, is_player: bool) -> Ship:
	var scene := _resolve_ship_scene(ship_data, faction)
	if not scene:
		return null
	var ship := scene.instantiate() as Ship
	if not ship:
		return null
	_world.add_child(ship)
	ship.is_player_ship = is_player
	ship.ship_data = ship_data
	ship.faction_data = faction
	ship.update_stats()
	return ship

# Prefers the scene authored on the ship resource and otherwise falls back to
# the faction's default hull scene.
func _resolve_ship_scene(ship_data: ShipData, faction: FactionData) -> PackedScene:
	if ship_data and ship_data.ship_scene:
		return ship_data.ship_scene
	if faction:
		var path := String(FACTION_DEFAULT_SHIP_SCENES.get(faction.faction, ""))
		if not path.is_empty():
			return load(path) as PackedScene
	return null

# --- Selection helpers -------------------------------------------------------

func _faction_at(index: int) -> FactionData:
	if index < 0 or index >= _factions.size():
		return null
	return _factions[index]

func _selected_faction() -> FactionData:
	return _faction_at(_faction_picker.selected)

func _selected_ship_data() -> ShipData:
	var faction := _selected_faction()
	if not faction:
		return null
	var index := _ship_picker.selected
	if index < 0 or index >= faction.hangar_ship_options.size():
		return null
	return faction.hangar_ship_options[index] as ShipData

func _first_ship_data(faction: FactionData) -> ShipData:
	if not faction:
		return null
	for option in faction.hangar_ship_options:
		var ship_data := option as ShipData
		if ship_data:
			return ship_data
	return null

func _other_faction(faction: FactionData) -> FactionData:
	for candidate in _factions:
		if candidate != faction:
			return candidate
	return null

# --- Status / HUD ------------------------------------------------------------

func _update_status() -> void:
	var faction := _selected_faction()
	var ship_data := _selected_ship_data()
	var faction_name := faction.get_faction_name() if faction else "—"
	var ship_name := ship_data.name if ship_data else "—"
	var enemy := _other_faction(faction)
	var enemy_name := enemy.get_faction_name() if enemy else "—"
	_set_status("Faction: %s\nSelected ship: %s\nEnemy target: %s" % [faction_name, ship_name, enemy_name])

func _set_status(text: String) -> void:
	if _status_label:
		_status_label.text = text

# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not _player_ship or not is_instance_valid(_player_ship) or _player_ship.is_dead:
		return
	# Left click steers the ship toward the clicked point.
	if event.is_action_pressed(&"navigate"):
		_player_ship.set_target(get_global_mouse_position())
		if _camera:
			_camera.follow_target = true
	elif event.is_action_pressed(&"ability_1"):
		if _ability:
			_ability.use_ability_1()

# Registers the same Input Map actions Main.gd relies on so flight, targeting
# and abilities behave identically inside the standalone arena.
func _register_inputs() -> void:
	_register_mouse_action(&"navigate", MOUSE_BUTTON_LEFT)
	_register_mouse_action(&"target_lock", MOUSE_BUTTON_RIGHT)
	_register_mouse_action(&"zoom_in", MOUSE_BUTTON_WHEEL_UP)
	_register_mouse_action(&"zoom_out", MOUSE_BUTTON_WHEEL_DOWN)
	_register_key_action(&"ability_1", KEY_1)
	_register_key_action(&"turn_left", KEY_Q)
	_register_key_action(&"turn_right", KEY_E)
	_register_key_action(&"reverse_thrust", KEY_R)

func _register_mouse_action(action_name: StringName, button_index: MouseButton) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	var ev := InputEventMouseButton.new()
	ev.button_index = button_index
	InputMap.action_add_event(action_name, ev)

func _register_key_action(action_name: StringName, key_index: Key) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	var ev := InputEventKey.new()
	ev.keycode = key_index
	InputMap.action_add_event(action_name, ev)
