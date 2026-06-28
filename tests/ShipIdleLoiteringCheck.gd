extends SceneTree

const SHIP_SCENE_PATH := "res://scenes/factions/zarak/ships/Scout.tscn"
const WARMUP_FRAMES := 10
const SAMPLE_FRAMES := 180
const POSITION_DRIFT_THRESHOLD := 0.05
const ROTATION_DRIFT_THRESHOLD := 0.001

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

	ship.global_position = Vector2.ZERO
	ship.global_rotation = 0.0
	ship.velocity = Vector2.ZERO

	for _i in range(WARMUP_FRAMES):
		await process_frame

	var start_position: Vector2 = ship.global_position
	var start_rotation: float = ship.global_rotation

	for _frame in range(SAMPLE_FRAMES):
		await process_frame

	var position_drift: float = ship.global_position.distance_to(start_position)
	var rotation_drift: float = abs(angle_difference(ship.global_rotation, start_rotation))

	print("[TEST] ShipIdleLoiteringCheck position_drift=", position_drift, " rotation_drift=", rotation_drift)

	if position_drift > POSITION_DRIFT_THRESHOLD:
		failures.append("Idle position drift %.6f exceeds threshold %.6f" % [position_drift, POSITION_DRIFT_THRESHOLD])

	if rotation_drift > ROTATION_DRIFT_THRESHOLD:
		failures.append("Idle rotation drift %.6f exceeds threshold %.6f" % [rotation_drift, ROTATION_DRIFT_THRESHOLD])

	ship.queue_free()

	if failures.is_empty():
		print("[TEST] ShipIdleLoiteringCheck passed")
		quit(0)
		return

	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)