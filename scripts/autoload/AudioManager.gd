extends Node

const MASTER_BUS := &"Master"
const PLAYER_BUS := &"Player_SFX"
const ENEMY_BUS := &"Enemy_SFX"

const MAX_ENEMY_LASERS := 8
const MAX_ENEMY_POLYPHONY_PER_SHIP := 3

const PLAYER_PITCH_MIN := 0.98
const PLAYER_PITCH_MAX := 1.06
const PLAYER_VOLUME_DB_MIN := -1.0
const PLAYER_VOLUME_DB_MAX := 0.5
const ENEMY_PITCH_MIN := 0.92
const ENEMY_PITCH_MAX := 1.08
const ENEMY_VOLUME_DB_MIN := -8.0
const ENEMY_VOLUME_DB_MAX := -3.0

const ENEMY_CUTOFF_NEAR_HZ := 3000.0
const ENEMY_CUTOFF_FAR_HZ := 1500.0

const DEFAULT_MAX_DISTANCE := 2200.0
const DEFAULT_ATTENUATION := 2.0

const MENU_CLICK_STREAM := preload("res://assets/audio/btn-click.mp3")
const MENU_AMBIENT_STREAM := preload("res://assets/audio/spaceship-ambient.mp3")
const PLAYER_THRUSTER_STREAM := preload("res://assets/audio/thrustmax.mp3")
const MENU_CLICK_VOLUME_DB := -5.0
const MENU_AMBIENT_VOLUME_DB := -12.0
const PLAYER_THRUSTER_VOLUME_DB_IDLE := -42.0
const PLAYER_THRUSTER_VOLUME_DB_MAX := -10.0
const PLAYER_THRUSTER_PITCH_MIN := 0.92
const PLAYER_THRUSTER_PITCH_MAX := 1.08
const PLAYER_THRUSTER_FADE_IN_SPEED := 4.0
const PLAYER_THRUSTER_FADE_OUT_SPEED := 3.0
const PLAYER_THRUSTER_PLAY_THRESHOLD := 0.01
const PLAYER_THRUSTER_STOP_THRESHOLD := 0.001

var _camera: GameCamera = null
var _enemy_bus_index: int = -1
var _enemy_lowpass_effect_index: int = -1

var _active_enemy_laser_count: int = 0
var _enemy_laser_count_by_ship: Dictionary = {}
var _menu_click_player: AudioStreamPlayer = null
var _menu_ambient_player: AudioStreamPlayer = null
var _player_thruster_player: AudioStreamPlayer = null
var _player_thruster_target_intensity: float = 0.0
var _player_thruster_smoothed_intensity: float = 0.0

func _ready() -> void:
	randomize()
	_cache_enemy_lowpass_effect_index()
	_ensure_menu_audio_players()
	_ensure_player_thruster_audio_player()

func _process(delta: float) -> void:
	_update_enemy_lowpass_from_zoom()
	_update_player_thruster_audio(delta)

func set_listener_camera(camera: GameCamera) -> void:
	_camera = camera

func start_menu_ambient() -> void:
	_ensure_menu_audio_players()
	if _menu_ambient_player.playing:
		return
	_menu_ambient_player.play()

func stop_menu_ambient() -> void:
	if not _menu_ambient_player:
		return
	_menu_ambient_player.stop()

func play_menu_click() -> void:
	_ensure_menu_audio_players()
	_menu_click_player.stop()
	_menu_click_player.play()

func set_player_thruster_intensity(intensity: float) -> void:
	_ensure_player_thruster_audio_player()
	_player_thruster_target_intensity = clampf(intensity, 0.0, 1.0)

func stop_player_thruster_audio(immediate: bool = false) -> void:
	_player_thruster_target_intensity = 0.0
	if immediate:
		_player_thruster_smoothed_intensity = 0.0
		if _player_thruster_player:
			_player_thruster_player.stop()

func play_weapon_fire(
	audio_stream: AudioStream,
	global_pos: Vector2,
	is_player_shot: bool,
	ship_emitter: Node = null
) -> bool:
	if not audio_stream:
		return false

	var emitter_id := ship_emitter.get_instance_id() if ship_emitter else 0
	if not is_player_shot:
		if _active_enemy_laser_count >= MAX_ENEMY_LASERS:
			return false
		var active_for_ship: int = 0
		if _enemy_laser_count_by_ship.has(emitter_id):
			active_for_ship = _enemy_laser_count_by_ship[emitter_id]
		if active_for_ship >= MAX_ENEMY_POLYPHONY_PER_SHIP:
			return false

	var audio_player := AudioStreamPlayer2D.new()
	audio_player.stream = audio_stream
	audio_player.global_position = global_pos
	audio_player.max_distance = DEFAULT_MAX_DISTANCE
	audio_player.attenuation = DEFAULT_ATTENUATION

	if is_player_shot:
		audio_player.bus = _resolve_bus_name(PLAYER_BUS)
		_apply_randomization(audio_player, PLAYER_PITCH_MIN, PLAYER_PITCH_MAX, PLAYER_VOLUME_DB_MIN, PLAYER_VOLUME_DB_MAX)
	else:
		audio_player.bus = _resolve_bus_name(ENEMY_BUS)
		_apply_randomization(audio_player, ENEMY_PITCH_MIN, ENEMY_PITCH_MAX, ENEMY_VOLUME_DB_MIN, ENEMY_VOLUME_DB_MAX)
		_active_enemy_laser_count += 1
		if emitter_id != 0:
			var existing_for_ship: int = 0
			if _enemy_laser_count_by_ship.has(emitter_id):
				existing_for_ship = _enemy_laser_count_by_ship[emitter_id]
			_enemy_laser_count_by_ship[emitter_id] = existing_for_ship + 1

	if is_inside_tree():
		add_child(audio_player)
	else:
		get_tree().root.add_child(audio_player)
	audio_player.finished.connect(_on_one_shot_finished.bind(audio_player, emitter_id, not is_player_shot))
	audio_player.play()
	return true

func get_enemy_active_voice_count() -> int:
	return _active_enemy_laser_count

func get_enemy_global_cap() -> int:
	return MAX_ENEMY_LASERS

func get_enemy_polyphony_cap() -> int:
	return MAX_ENEMY_POLYPHONY_PER_SHIP

func get_enemy_ship_voice_count(ship: Node) -> int:
	if not ship:
		return 0
	var emitter_id := ship.get_instance_id()
	if not _enemy_laser_count_by_ship.has(emitter_id):
		return 0
	return _enemy_laser_count_by_ship[emitter_id]

func clear_debug_state() -> void:
	_active_enemy_laser_count = 0
	_enemy_laser_count_by_ship.clear()
	stop_player_thruster_audio(true)
	for child in get_children():
		if child is AudioStreamPlayer2D:
			child.queue_free()

func _on_one_shot_finished(audio_player: AudioStreamPlayer2D, emitter_id: int, was_enemy_shot: bool) -> void:
	if was_enemy_shot:
		_active_enemy_laser_count = max(0, _active_enemy_laser_count - 1)
		if emitter_id != 0 and _enemy_laser_count_by_ship.has(emitter_id):
			var updated_ship_count: int = _enemy_laser_count_by_ship[emitter_id] - 1
			if updated_ship_count <= 0:
				_enemy_laser_count_by_ship.erase(emitter_id)
			else:
				_enemy_laser_count_by_ship[emitter_id] = updated_ship_count

	audio_player.queue_free()

func _ensure_menu_audio_players() -> void:
	if not _menu_click_player:
		_menu_click_player = AudioStreamPlayer.new()
		_menu_click_player.stream = MENU_CLICK_STREAM
		_menu_click_player.volume_db = MENU_CLICK_VOLUME_DB
		_menu_click_player.bus = _resolve_bus_name(MASTER_BUS)
		add_child(_menu_click_player)

	if not _menu_ambient_player:
		_menu_ambient_player = AudioStreamPlayer.new()
		_menu_ambient_player.stream = MENU_AMBIENT_STREAM
		_menu_ambient_player.volume_db = MENU_AMBIENT_VOLUME_DB
		_menu_ambient_player.bus = _resolve_bus_name(MASTER_BUS)
		_menu_ambient_player.finished.connect(_on_menu_ambient_finished)
		add_child(_menu_ambient_player)

func _ensure_player_thruster_audio_player() -> void:
	if _player_thruster_player:
		return

	_player_thruster_player = AudioStreamPlayer.new()
	_player_thruster_player.stream = PLAYER_THRUSTER_STREAM
	_player_thruster_player.volume_db = PLAYER_THRUSTER_VOLUME_DB_IDLE
	_player_thruster_player.pitch_scale = PLAYER_THRUSTER_PITCH_MIN
	_player_thruster_player.bus = _resolve_bus_name(PLAYER_BUS)
	_player_thruster_player.finished.connect(_on_player_thruster_finished)
	add_child(_player_thruster_player)

func _on_menu_ambient_finished() -> void:
	if _menu_ambient_player and _menu_ambient_player.stream:
		_menu_ambient_player.play()

func _on_player_thruster_finished() -> void:
	if _player_thruster_player and _player_thruster_target_intensity > PLAYER_THRUSTER_PLAY_THRESHOLD:
		_player_thruster_player.play()

func _update_player_thruster_audio(delta: float) -> void:
	if not _player_thruster_player:
		return

	var fade_speed: float = PLAYER_THRUSTER_FADE_IN_SPEED
	if _player_thruster_smoothed_intensity > _player_thruster_target_intensity:
		fade_speed = PLAYER_THRUSTER_FADE_OUT_SPEED

	_player_thruster_smoothed_intensity = move_toward(
		_player_thruster_smoothed_intensity,
		_player_thruster_target_intensity,
		delta * fade_speed
	)

	if _player_thruster_smoothed_intensity > PLAYER_THRUSTER_PLAY_THRESHOLD and not _player_thruster_player.playing:
		_player_thruster_player.play()

	_player_thruster_player.volume_db = lerpf(
		PLAYER_THRUSTER_VOLUME_DB_IDLE,
		PLAYER_THRUSTER_VOLUME_DB_MAX,
		_player_thruster_smoothed_intensity
	)
	_player_thruster_player.pitch_scale = lerpf(
		PLAYER_THRUSTER_PITCH_MIN,
		PLAYER_THRUSTER_PITCH_MAX,
		_player_thruster_smoothed_intensity
	)

	if _player_thruster_target_intensity <= PLAYER_THRUSTER_STOP_THRESHOLD and _player_thruster_smoothed_intensity <= PLAYER_THRUSTER_STOP_THRESHOLD:
		if _player_thruster_player.playing:
			_player_thruster_player.stop()

func _resolve_bus_name(preferred_bus: StringName) -> StringName:
	if AudioServer.get_bus_index(preferred_bus) != -1:
		return preferred_bus
	return MASTER_BUS

func _apply_randomization(
	audio_player: AudioStreamPlayer2D,
	pitch_min: float,
	pitch_max: float,
	volume_db_min: float,
	volume_db_max: float
) -> void:
	audio_player.pitch_scale = randf_range(pitch_min, pitch_max)
	audio_player.volume_db = randf_range(volume_db_min, volume_db_max)

func _cache_enemy_lowpass_effect_index() -> void:
	_enemy_bus_index = AudioServer.get_bus_index(ENEMY_BUS)
	_enemy_lowpass_effect_index = -1

	if _enemy_bus_index == -1:
		return

	for effect_index in AudioServer.get_bus_effect_count(_enemy_bus_index):
		var effect := AudioServer.get_bus_effect(_enemy_bus_index, effect_index)
		if effect is AudioEffectLowPassFilter:
			_enemy_lowpass_effect_index = effect_index
			break

func _update_enemy_lowpass_from_zoom() -> void:
	if not _camera:
		return

	if _enemy_bus_index == -1 or _enemy_lowpass_effect_index == -1:
		_cache_enemy_lowpass_effect_index()
		if _enemy_bus_index == -1 or _enemy_lowpass_effect_index == -1:
			return

	var zoom_min: float = minf(_camera.min_zoom, _camera.max_zoom)
	var zoom_max: float = maxf(_camera.min_zoom, _camera.max_zoom)
	var zoom_t := 0.0
	if not is_equal_approx(zoom_min, zoom_max):
		zoom_t = clamp((_camera.zoom.x - zoom_min) / (zoom_max - zoom_min), 0.0, 1.0)

	var cutoff_hz := lerpf(ENEMY_CUTOFF_NEAR_HZ, ENEMY_CUTOFF_FAR_HZ, zoom_t)
	var lowpass := AudioServer.get_bus_effect(_enemy_bus_index, _enemy_lowpass_effect_index) as AudioEffectLowPassFilter
	if lowpass:
		lowpass.cutoff_hz = cutoff_hz