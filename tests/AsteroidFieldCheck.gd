extends SceneTree

# Verifies the decorative asteroid field: correct count, deterministic from a
# seed, and that the central clearing is respected. Run headless with:
#   godot --headless --script res://tests/AsteroidFieldCheck.gd

const FIELD_SCRIPT := preload("res://scripts/AsteroidField.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var field_a: AsteroidField = FIELD_SCRIPT.new()
	field_a.asteroid_seed = 12345
	field_a.asteroid_count = 80
	root.add_child(field_a)
	await process_frame

	if field_a._asteroids.size() != 80:
		failures.append("Expected 80 asteroids, got %d" % field_a._asteroids.size())

	# Every asteroid must sit outside the central clearing.
	for asteroid in field_a._asteroids:
		if asteroid.offset.length() < field_a.clear_radius - 0.01:
			failures.append("Asteroid spawned inside the clear radius")
			break

	# Same seed must reproduce the exact same layout (determinism rule).
	var field_b: AsteroidField = FIELD_SCRIPT.new()
	field_b.asteroid_seed = 12345
	field_b.asteroid_count = 80
	root.add_child(field_b)
	await process_frame

	if field_a._asteroids[0].offset.distance_to(field_b._asteroids[0].offset) > 0.01:
		failures.append("Identical seeds produced different asteroid layouts")

	field_a.queue_free()
	field_b.queue_free()

	if failures.is_empty():
		print("[TEST] AsteroidFieldCheck passed")
		quit(0)
		return

	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)
