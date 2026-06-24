extends SceneTree

const SHIP_SCENE_PATH := "res://scenes/ship/zarak/Scout.tscn"
const SAMPLE_FRAMES := 240
const WARMUP_FRAMES := 12
const JITTER_THRESHOLD := 0.6

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var packed_scene := load(SHIP_SCENE_PATH) as PackedScene
	if not packed_scene:
		push_error("[TEST] Failed to load scene: %s" % SHIP_SCENE_PATH)
		quit(1)
		return

	var ship := packed_scene.instantiate() as Ship
	if not ship:
		push_error("[TEST] Failed to instantiate scene: %s" % SHIP_SCENE_PATH)
		quit(1)
		return

	root.add_child(ship)

	var camera := GameCamera.new()
	root.add_child(camera)

	camera.target_node = ship
	camera.follow_target = true
	camera.make_current()

	ship.global_position = Vector2.ZERO
	camera.global_position = ship.global_position

	ship.set_target(ship.global_position + Vector2(4500.0, 0.0))

	for _i in range(WARMUP_FRAMES):
		await process_frame

	var relative_positions: Array[Vector2] = []
	for _frame in range(SAMPLE_FRAMES):
		await process_frame
		relative_positions.append(ship.global_position - camera.global_position)

	var jitter_score: float = _calculate_jitter_score(relative_positions)
	print("[TEST] ShipCameraJitterCheck jitter_score=", jitter_score)

	if jitter_score > JITTER_THRESHOLD:
		failures.append("Camera-follow jitter score %.6f exceeds threshold %.6f" % [jitter_score, JITTER_THRESHOLD])

	ship.queue_free()
	camera.queue_free()

	if failures.is_empty():
		print("[TEST] ShipCameraJitterCheck passed")
		quit(0)
		return

	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)

func _calculate_jitter_score(relative_positions: Array[Vector2]) -> float:
	if relative_positions.size() < 3:
		return 0.0

	var sum_second_delta: float = 0.0
	var count: int = 0

	for i in range(2, relative_positions.size()):
		var second_delta: Vector2 = relative_positions[i] - (relative_positions[i - 1] * 2.0) + relative_positions[i - 2]
		sum_second_delta += second_delta.length()
		count += 1

	if count == 0:
		return 0.0

	return sum_second_delta / float(count)