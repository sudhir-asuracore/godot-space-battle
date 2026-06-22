extends SceneTree

const LASER_AUDIO_PATH := "res://assets/audio/laser-short-pulse.mp3"
const AUDIO_MANAGER_SCRIPT := preload("res://scripts/autoload/AudioManager.gd")

var _audio_manager: Node = null

func _initialize() -> void:
	_audio_manager = AUDIO_MANAGER_SCRIPT.new()
	root.add_child(_audio_manager)
	assert(_audio_manager != null, "AudioManager autoload should be available")
	call_deferred("_run_checks")

func _run_checks() -> void:
	await process_frame

	var stream := load(LASER_AUDIO_PATH) as AudioStream
	assert(stream != null, "Laser fire stream should load")

	_verify_missing_stream_rejected()
	_verify_enemy_polyphony_limit(stream)
	_verify_enemy_global_limit(stream)
	_verify_player_shots_not_blocked_by_enemy_cap(stream)

	_audio_manager.call("clear_debug_state")
	quit(0)

func _verify_missing_stream_rejected() -> void:
	_audio_manager.call("clear_debug_state")
	var emitter := Node2D.new()
	root.add_child(emitter)
	assert(
		not _audio_manager.call("play_weapon_fire", null, Vector2.ZERO, false, emitter),
		"Null stream should be ignored"
	)
	emitter.queue_free()

func _verify_enemy_polyphony_limit(stream: AudioStream) -> void:
	_audio_manager.call("clear_debug_state")
	var polyphony_cap := _audio_manager.call("get_enemy_polyphony_cap") as int
	var emitter := Node2D.new()
	root.add_child(emitter)

	for i in range(polyphony_cap):
		assert(
			_audio_manager.call("play_weapon_fire", stream, Vector2.ZERO, false, emitter),
			"Enemy shot %d should pass per-ship cap" % (i + 1)
		)

	assert(
		not _audio_manager.call("play_weapon_fire", stream, Vector2.ZERO, false, emitter),
		"Enemy per-ship polyphony should cap at %d" % polyphony_cap
	)
	assert(
		_audio_manager.call("get_enemy_ship_voice_count", emitter) == polyphony_cap,
		"Per-ship voice count should match configured cap"
	)
	emitter.queue_free()

func _verify_enemy_global_limit(stream: AudioStream) -> void:
	_audio_manager.call("clear_debug_state")
	var global_cap := _audio_manager.call("get_enemy_global_cap") as int
	var emitters: Array[Node2D] = []

	for i in range(global_cap):
		var emitter := Node2D.new()
		emitters.append(emitter)
		root.add_child(emitter)
		assert(
			_audio_manager.call("play_weapon_fire", stream, Vector2.ZERO, false, emitter),
			"Enemy voice %d should pass global cap" % (i + 1)
		)

	var overflow_emitter := Node2D.new()
	root.add_child(overflow_emitter)
	assert(
		not _audio_manager.call("play_weapon_fire", stream, Vector2.ZERO, false, overflow_emitter),
		"Enemy global cap should block extra voices"
	)
	assert(
		_audio_manager.call("get_enemy_active_voice_count") == global_cap,
		"Enemy active voice count should match configured global cap"
	)

	for emitter in emitters:
		emitter.queue_free()
	overflow_emitter.queue_free()

func _verify_player_shots_not_blocked_by_enemy_cap(stream: AudioStream) -> void:
	_audio_manager.call("clear_debug_state")
	var global_cap := _audio_manager.call("get_enemy_global_cap") as int
	var emitters: Array[Node2D] = []

	for _i in range(global_cap):
		var emitter := Node2D.new()
		emitters.append(emitter)
		root.add_child(emitter)
		_audio_manager.call("play_weapon_fire", stream, Vector2.ZERO, false, emitter)

	assert(
		_audio_manager.call("play_weapon_fire", stream, Vector2.ZERO, true, null),
		"Player laser should not be blocked by enemy voice cap"
	)

	for emitter in emitters:
		emitter.queue_free()