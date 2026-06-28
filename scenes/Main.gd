extends Node2D
class_name GameMain

var _ship: Ship = null
@onready var _path_line: Line2D = $PathLine as Line2D
@onready var _camera: GameCamera = $Camera2D as GameCamera
@onready var _zoom_label: Label = $HUD/Control/ZoomPanel/Label as Label
@onready var _reticle: TargetReticle = $HUD/TargetReticle as TargetReticle
@onready var _player_hud: PlayerHUD = $HUD/PlayerHUD as PlayerHUD
@onready var _debug_panel: DebugPanel = $HUD/DebugPanel as DebugPanel
@onready var _solar_system: SolarSystem = $SolarSystem as SolarSystem

const AI_SHIP_CONTROLLER_SCRIPT = preload("res://scripts/AIShipController.gd")
const HOMEBASE_SCENE = preload("res://scenes/homebase/Homebase.tscn")
const DEFAULT_PLAYER_SHIP_DATA_PATH := "res://resources/factions/zarak/ships/scout.tres"
const DEFAULT_PLAYER_FACTION_PATH := "res://resources/factions/zarak/zarak_confedaracy.tres"
const DEFAULT_PLAYER_SHIP_SCENE_PATH := "res://scenes/factions/solarion/ships/Frigate.tscn"
const DEFAULT_ENEMY_SHIP_DATA_PATH := "res://resources/factions/solarion_collective/ships/striker_lance.tres"
const DEFAULT_ENEMY_FACTION_PATH := "res://resources/factions/solarion_collective/solarion_collective.tres"
const DEFAULT_ENEMY_SHIP_SCENE_PATH := "res://scenes/factions/solarion/ships/Frigate.tscn"

# Fallback layout used only if the solar system is unavailable. The live
# values come from SolarSystem, which anchors the two homebase planets.
const PLAYER_HOMEBASE_POS := Vector2.DOWN * 3000.0
const ENEMY_HOMEBASE_POS := Vector2.UP * 3000.0
const PLAYER_SPAWN_POSITION := Vector2(0, 500)

const PLAYER_RESPAWN_DELAY := 5.0
const ENEMY_SPAWN_INTERVAL := 10.0
const MAX_ENEMY_SHIPS := 3

var _player_faction: FactionData
var _enemy_faction: FactionData
var _targeting: TargetingController
var _ability: AbilityController

var _player_ship_data_path: String = DEFAULT_PLAYER_SHIP_DATA_PATH
var _player_ship_scene_path: String = DEFAULT_PLAYER_SHIP_SCENE_PATH
var _enemy_ship_data_path: String = DEFAULT_ENEMY_SHIP_DATA_PATH
var _enemy_ship_scene_path: String = DEFAULT_ENEMY_SHIP_SCENE_PATH

var _enemy_ships: Array[Ship] = []
var _enemy_spawn_timer: float = 0.0
var _match_over: bool = false

# Live homebase / spawn positions resolved from the solar system layout.
var _player_homebase_pos: Vector2 = PLAYER_HOMEBASE_POS
var _enemy_homebase_pos: Vector2 = ENEMY_HOMEBASE_POS
var _player_spawn_pos: Vector2 = PLAYER_SPAWN_POSITION

func _ready() -> void:
	AudioManager.stop_menu_ambient()
	# Programmatically register required Input Map actions.
	_register_input_action(&"navigate", MOUSE_BUTTON_LEFT)
	_register_input_action(&"target_lock", MOUSE_BUTTON_RIGHT)
	_register_input_action(&"zoom_in", MOUSE_BUTTON_WHEEL_UP)
	_register_input_action(&"zoom_out", MOUSE_BUTTON_WHEEL_DOWN)
	_register_key_action(&"ability_1", KEY_1)
	# Q/E point (turn) the ship left/right.
	_register_key_action(&"turn_left", KEY_Q)
	_register_key_action(&"turn_right", KEY_E)
	_register_key_action(&"reverse_thrust", KEY_R)
	
	_resolve_match_setup()
	_resolve_solar_system_layout()
	_player_faction = load(GameState.selected_faction_path if not GameState.selected_faction_path.is_empty() else DEFAULT_PLAYER_FACTION_PATH) as FactionData
	_enemy_faction = load(GameState.selected_enemy_faction_path if not GameState.selected_enemy_faction_path.is_empty() else DEFAULT_ENEMY_FACTION_PATH) as FactionData
	if not _player_faction:
		_player_faction = load(DEFAULT_PLAYER_FACTION_PATH) as FactionData
	if not _enemy_faction:
		_enemy_faction = load(DEFAULT_ENEMY_FACTION_PATH) as FactionData
	GameState.player_faction = _player_faction

	EventBus.player_ship_selected.connect(_on_player_ship_selected)

	_spawn_homebases()
	_spawn_enemy()

	EventBus.homebase_destroyed.connect(_on_homebase_destroyed)
	EventBus.match_ended.connect(_on_match_ended)
	EventBus.ship_destroyed.connect(_on_ship_destroyed)

	# Present the faction's available ships and spawn the one the player picks.
	_prompt_initial_ship_selection()

# Shows the start-of-match ship picker. Falls back to the configured default
# ship data when the faction has no hangar options.
func _prompt_initial_ship_selection() -> void:
	var ships: Array = []
	if _player_faction:
		ships = _player_faction.hangar_ship_options.duplicate()
	if _player_hud and ships.size() > 0:
		_player_hud.show_ship_selection(_player_faction, ships, "Select your ship to deploy")
	else:
		_on_player_ship_selected(load(_player_ship_data_path) as ShipData)

# Spawns the chosen ship, replacing the current player ship if one exists
# (start-of-match deployment and later hangar swaps both route through here).
func _on_player_ship_selected(ship_data: ShipData) -> void:
	if not ship_data:
		return
	var spawn_pos: Vector2 = _player_spawn_pos
	if _ship and is_instance_valid(_ship):
		spawn_pos = _ship.global_position
		_ship.queue_free()
		_ship = null
	_spawn_player_ship_from_data(ship_data, spawn_pos)

func _setup_camera_and_path() -> void:
	# Camera follows the player ship automatically on launch.
	if _camera and _ship:
		_camera.target_node = _ship
		_camera.follow_target = true
		var audio_manager: Node = get_node_or_null(^"/root/AudioManager")
		if audio_manager:
			audio_manager.call("set_listener_camera", _camera)
		
	# Visual trajectory path line look.
	if _path_line:
		_path_line.width = 3.0
		var path_color: Color = Color.DEEP_SKY_BLUE
		path_color.a = 0.45
		_path_line.default_color = path_color # Glowing semi-transparent cyan
		_path_line.clear_points()
		_path_line.visible = false

func _spawn_homebases() -> void:
	var player_hb: Homebase = HOMEBASE_SCENE.instantiate() as Homebase
	player_hb.name = &"PlayerHomebase"
	player_hb.position = _player_homebase_pos
	player_hb.faction_data = _player_faction
	add_child(player_hb)
	
	var enemy_hb: Homebase = HOMEBASE_SCENE.instantiate() as Homebase
	enemy_hb.name = &"EnemyHomebase"
	enemy_hb.position = _enemy_homebase_pos
	enemy_hb.faction_data = _enemy_faction
	add_child(enemy_hb)

func _spawn_player_ship_from_data(ship_data: ShipData, spawn_pos: Vector2) -> void:
	# Prefer the scene declared on the ship resource; fall back to the match's
	# configured player scene (and finally the hard default) when unset.
	var player_ship_scene: PackedScene = ship_data.ship_scene if ship_data else null
	if not player_ship_scene:
		player_ship_scene = _load_ship_scene(_player_ship_scene_path, DEFAULT_PLAYER_SHIP_SCENE_PATH)
	var player_ship: Ship = player_ship_scene.instantiate() as Ship if player_ship_scene else null
	if not player_ship:
		return
	add_child(player_ship)
	player_ship.global_position = spawn_pos
	_ship = player_ship

	_ship.is_player_ship = true
	_ship.ship_data = ship_data
	if not _ship.ship_data:
		_ship.ship_data = load(DEFAULT_PLAYER_SHIP_DATA_PATH) as ShipData
	# Prefer the faction the ship resource resolves to so the ship stays linked
	# to its own faction; fall back to the match faction when it resolves none.
	var player_ship_faction: FactionData = _ship.ship_data.resolve_faction_data() if _ship.ship_data else null
	_ship.faction_data = player_ship_faction if player_ship_faction else _player_faction
	_ship.update_stats()
	_targeting = _ship.get_node_or_null(^"TargetingController") as TargetingController
	_ability = _ship.get_node_or_null(^"AbilityController") as AbilityController
	_attach_range_indicator(_ship)
	_setup_camera_and_path()
	if _player_hud:
		_player_hud.setup(_ship, _player_faction, _enemy_faction, _ability)
		if _solar_system:
			_player_hud.configure_system_endpoints(_solar_system.player_homebase_planet, _solar_system.enemy_homebase_planet)
	if _debug_panel:
		_debug_panel.setup(_ship)

func _attach_range_indicator(ship: Ship) -> void:
	if not ship:
		return
	if ship.has_node(^"RangeIndicator"):
		return
	var indicator := ShipRangeIndicator.new()
	indicator.name = &"RangeIndicator"
	ship.add_child(indicator)
	indicator.setup(ship)

func _spawn_enemy() -> void:
	var enemy_scene: PackedScene = _load_ship_scene(_enemy_ship_scene_path, DEFAULT_ENEMY_SHIP_SCENE_PATH)
	if not enemy_scene:
		return
	var enemy: Ship = enemy_scene.instantiate() as Ship
	if not enemy:
		return
	enemy.is_player_ship = false
	var spawn_offset: Vector2 = Vector2.RIGHT * randf_range(-300.0, 300.0) + Vector2.DOWN * randf_range(200.0, 500.0)
	enemy.position = _enemy_homebase_pos + spawn_offset
	_apply_ship_data_override(enemy, _enemy_ship_data_path, DEFAULT_ENEMY_SHIP_DATA_PATH)
	# Prefer the faction the ship resource resolves to; fall back to the match
	# enemy faction when the resource resolves none.
	var enemy_ship_faction: FactionData = enemy.ship_data.resolve_faction_data() if enemy.ship_data else null
	enemy.faction_data = enemy_ship_faction if enemy_ship_faction else _enemy_faction
	_configure_enemy_ai(enemy)
	add_child(enemy)
	enemy.update_stats()
	_enemy_ships.append(enemy)

func _resolve_solar_system_layout() -> void:
	# SolarSystem is a child node, so it is ready before Main: read the homebase
	# ends (2nd / last-but-2nd planet) and player spawn it chose for this match.
	if not _solar_system:
		return
	_player_homebase_pos = _solar_system.player_homebase_position
	_enemy_homebase_pos = _solar_system.enemy_homebase_position
	_player_spawn_pos = _solar_system.player_spawn_position

func _resolve_match_setup() -> void:
	_player_ship_data_path = GameState.selected_ship_data_path if not GameState.selected_ship_data_path.is_empty() else DEFAULT_PLAYER_SHIP_DATA_PATH
	_player_ship_scene_path = GameState.selected_ship_scene_path if not GameState.selected_ship_scene_path.is_empty() else DEFAULT_PLAYER_SHIP_SCENE_PATH
	_enemy_ship_data_path = GameState.selected_enemy_ship_data_path if not GameState.selected_enemy_ship_data_path.is_empty() else DEFAULT_ENEMY_SHIP_DATA_PATH
	_enemy_ship_scene_path = GameState.selected_enemy_ship_scene_path if not GameState.selected_enemy_ship_scene_path.is_empty() else DEFAULT_ENEMY_SHIP_SCENE_PATH

func _load_ship_scene(primary_path: String, fallback_path: String) -> PackedScene:
	var scene: PackedScene = load(primary_path) as PackedScene
	if scene:
		return scene
	return load(fallback_path) as PackedScene

func _apply_ship_data_override(target_ship: Ship, primary_path: String, fallback_path: String) -> void:
	if not target_ship:
		return
	target_ship.ship_data = load(primary_path) as ShipData
	if not target_ship.ship_data:
		target_ship.ship_data = load(fallback_path) as ShipData

func _configure_enemy_ai(enemy_ship: Ship) -> void:
	if not enemy_ship:
		return
	var state_machine: Node = enemy_ship.get_node_or_null(^"StateMachine")
	if state_machine:
		state_machine.set_script(AI_SHIP_CONTROLLER_SCRIPT)

func _on_ship_destroyed(ship: Ship, _killer: Node2D) -> void:
	if ship == _ship:
		print("Player destroyed! Respawning in %.0f seconds..." % PLAYER_RESPAWN_DELAY)
		await get_tree().create_timer(PLAYER_RESPAWN_DELAY).timeout
		_respawn_player()
	elif ship in _enemy_ships:
		# Free the wreck; the spawn timer will bring a replacement.
		_enemy_ships.erase(ship)
		ship.queue_free()

func _respawn_player() -> void:
	if not _ship or _match_over:
		return
	# Free T1 fallback so the player can never softlock (PRD section 10.4).
	_ship.respawn(_player_homebase_pos)
	if _targeting:
		_targeting.locked_target = null
	print("Player respawned at homebase!")

func _on_homebase_destroyed(_faction: FactionData) -> void:
	pass # Handled via match_ended for clarity.

func _on_match_ended(winning_faction: FactionData) -> void:
	if _match_over:
		return
	_match_over = true
	if winning_faction == _player_faction:
		print("--- VICTORY ---")
		_zoom_label.text = "VICTORY"
	else:
		print("--- DEFEAT ---")
		_zoom_label.text = "DEFEAT"

func _process(delta: float) -> void:
	# 1. Draw and update the visual trajectory path line.
	if _path_line and _ship:
		if _ship.is_moving and not _ship.is_dead:
			_path_line.visible = true
			_path_line.clear_points()
			_path_line.add_point(_ship.global_position)
			_path_line.add_point(_ship.target_position)
		else:
			_path_line.visible = false
			
	# 2. Update the dynamic zoom level display.
	if _zoom_label and _camera and not _match_over:
		var percentage: int = roundi(_camera.zoom.x * 100.0)
		_zoom_label.text = "Zoom: %d%%" % percentage
	
	# 3. Keep the target reticle bound to the current locked target.
	if _reticle and _targeting:
		# Drop stale references: a locked target may have been freed (e.g. a
		# destroyed enemy ship) before TargetingController clears it this frame.
		if not is_instance_valid(_targeting.locked_target):
			_targeting.locked_target = null
		_reticle.player_ship = _ship
		_reticle.target = _targeting.locked_target
	
	# 4. Keep the enemy faction alive (basic respawn / reinforcement).
	if not _match_over:
		_enemy_spawn_timer += delta
		if _enemy_spawn_timer >= ENEMY_SPAWN_INTERVAL:
			_enemy_spawn_timer = 0.0
			var alive_enemy_ships: Array[Ship] = []
			for enemy_ship: Ship in _enemy_ships:
				if is_instance_valid(enemy_ship):
					alive_enemy_ships.append(enemy_ship)
			_enemy_ships = alive_enemy_ships
			if _enemy_ships.size() < MAX_ENEMY_SHIPS:
				_spawn_enemy()

func _unhandled_input(event: InputEvent) -> void:
	if _match_over:
		return
	# Set destination target on Left Click using the "navigate" action.
	if event.is_action_pressed(&"navigate"):
		var click_pos: Vector2 = get_global_mouse_position()
		if _ship and not _ship.is_dead:
			_ship.set_target(click_pos)
		if _camera:
			_camera.follow_target = true
			
	if event.is_action_pressed(&"ability_1"):
		if _ability and _ship and not _ship.is_dead:
			_ability.use_ability_1()

# Helper to programmatically register MouseButton inputs into Godot's InputMap.
func _register_input_action(action_name: StringName, button_index: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		var ev: InputEventMouseButton = InputEventMouseButton.new()
		ev.button_index = button_index
		InputMap.action_add_event(action_name, ev)

func _register_key_action(action_name: StringName, key_index: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		var ev: InputEventKey = InputEventKey.new()
		ev.keycode = key_index
		InputMap.action_add_event(action_name, ev)
