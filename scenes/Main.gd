extends Node2D
class_name GameMain

@onready var _ship: Ship = $Ship as Ship
@onready var _path_line: Line2D = $PathLine as Line2D
@onready var _camera: GameCamera = $Camera2D as GameCamera
@onready var _zoom_label: Label = $HUD/Control/ZoomPanel/Label as Label
@onready var _reticle: TargetReticle = $HUD/TargetReticle as TargetReticle
@onready var _player_hud: PlayerHUD = $HUD/PlayerHUD as PlayerHUD

const AIS_SHIP_SCENE = preload("res://scenes/AIShip.tscn")
const HOMEBASE_SCENE = preload("res://scenes/Homebase.tscn")
const SHIP_DATA_PATH := "res://resources/ships/t1_assault_ship.tres"
const PLAYER_FACTION_PATH := "res://resources/factions/iron_vanguard.tres"
const ENEMY_FACTION_PATH := "res://resources/factions/solarion_collective.tres"

const PLAYER_HOMEBASE_POS := Vector2(0, 3000)
const ENEMY_HOMEBASE_POS := Vector2(0, -3000)

const PLAYER_RESPAWN_DELAY := 5.0
const ENEMY_SPAWN_INTERVAL := 10.0
const MAX_ENEMY_SHIPS := 3

var _player_faction: FactionData
var _enemy_faction: FactionData
var _targeting: TargetingController
var _ability: AbilityController

var _enemy_ships: Array = []
var _enemy_spawn_timer: float = 0.0
var _match_over: bool = false

func _ready() -> void:
	# Programmatically register required Input Map actions.
	_register_input_action("navigate", MOUSE_BUTTON_LEFT)
	_register_input_action("target_lock", MOUSE_BUTTON_RIGHT)
	_register_input_action("zoom_in", MOUSE_BUTTON_WHEEL_UP)
	_register_input_action("zoom_out", MOUSE_BUTTON_WHEEL_DOWN)
	_register_key_action("ability_1", KEY_1)
	
	_player_faction = load(PLAYER_FACTION_PATH)
	_enemy_faction = load(ENEMY_FACTION_PATH)
	GameState.player_faction = _player_faction
	
	# Load MVP data for the player ship.
	if _ship:
		_ship.ship_data = load(SHIP_DATA_PATH)
		_ship.faction_data = _player_faction
		_ship.update_stats()
		_targeting = _ship.get_node("TargetingController") as TargetingController
		_ability = _ship.get_node("AbilityController") as AbilityController
	
	_spawn_homebases()
	_setup_camera_and_path()
	_spawn_enemy()
	
	if _player_hud:
		_player_hud.setup(_ship, _player_faction, _enemy_faction, _ability)
	
	EventBus.homebase_destroyed.connect(_on_homebase_destroyed)
	EventBus.match_ended.connect(_on_match_ended)
	EventBus.ship_destroyed.connect(_on_ship_destroyed)

func _setup_camera_and_path() -> void:
	# Camera follows the player ship automatically on launch.
	if _camera and _ship:
		_camera.target_node = _ship
		_camera.follow_target = true
		var audio_manager := get_node_or_null(^"/root/AudioManager")
		if audio_manager:
			audio_manager.call("set_listener_camera", _camera)
		
	# Visual trajectory path line look.
	if _path_line:
		_path_line.width = 3.0
		_path_line.default_color = Color(0.0, 0.8, 1.0, 0.45) # Glowing semi-transparent cyan
		_path_line.clear_points()
		_path_line.visible = false

func _spawn_homebases() -> void:
	var player_hb = HOMEBASE_SCENE.instantiate()
	player_hb.name = "PlayerHomebase"
	player_hb.position = PLAYER_HOMEBASE_POS
	player_hb.faction_data = _player_faction
	add_child(player_hb)
	
	var enemy_hb = HOMEBASE_SCENE.instantiate()
	enemy_hb.name = "EnemyHomebase"
	enemy_hb.position = ENEMY_HOMEBASE_POS
	enemy_hb.faction_data = _enemy_faction
	add_child(enemy_hb)

func _spawn_enemy() -> void:
	var enemy = AIS_SHIP_SCENE.instantiate()
	enemy.position = ENEMY_HOMEBASE_POS + Vector2(randf_range(-300, 300), randf_range(200, 500))
	enemy.ship_data = load(SHIP_DATA_PATH)
	enemy.faction_data = _enemy_faction
	add_child(enemy)
	enemy.update_stats()
	_enemy_ships.append(enemy)

func _on_ship_destroyed(ship: Ship, _killer: Node2D) -> void:
	if ship == _ship:
		print("Player destroyed! Respawning in %d seconds..." % int(PLAYER_RESPAWN_DELAY))
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
	_ship.respawn(PLAYER_HOMEBASE_POS)
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
		_reticle.target = _targeting.locked_target
	
	# 4. Keep the enemy faction alive (basic respawn / reinforcement).
	if not _match_over:
		_enemy_spawn_timer += delta
		if _enemy_spawn_timer >= ENEMY_SPAWN_INTERVAL:
			_enemy_spawn_timer = 0.0
			_enemy_ships = _enemy_ships.filter(func(s): return is_instance_valid(s))
			if _enemy_ships.size() < MAX_ENEMY_SHIPS:
				_spawn_enemy()

func _unhandled_input(event: InputEvent) -> void:
	if _match_over:
		return
	# Set destination target on Left Click using the "navigate" action.
	if event.is_action_pressed("navigate"):
		var click_pos: Vector2 = get_global_mouse_position()
		if _ship and not _ship.is_dead:
			_ship.set_target(click_pos)
		if _camera:
			_camera.follow_target = true
			
	if event.is_action_pressed("ability_1"):
		if _ability and _ship and not _ship.is_dead:
			_ability.use_ability_1()

# Helper to programmatically register MouseButton inputs into Godot's InputMap.
func _register_input_action(action_name: String, button_index: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		var ev: InputEventMouseButton = InputEventMouseButton.new()
		ev.button_index = button_index
		InputMap.action_add_event(action_name, ev)

func _register_key_action(action_name: String, key_index: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		var ev: InputEventKey = InputEventKey.new()
		ev.keycode = key_index
		InputMap.action_add_event(action_name, ev)
