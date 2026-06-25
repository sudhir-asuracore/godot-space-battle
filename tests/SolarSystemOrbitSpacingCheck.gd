extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	seed(20260624)

	var solar_system := SolarSystem.new()
	root.add_child(solar_system)
	await process_frame

	var orbits: Array = solar_system.get("_planets")
	if orbits.size() < 3 or orbits.size() > 5:
		failures.append("Expected 3-5 planets, got %d" % orbits.size())

	if not orbits.is_empty():
		var first_radius: float = float(orbits[0].radius)
		if first_radius < 2800.0:
			failures.append("Expected first orbit radius >= 2800, got %.2f" % first_radius)

	for i in range(1, orbits.size()):
		var prev_radius: float = float(orbits[i - 1].radius)
		var current_radius: float = float(orbits[i].radius)
		var spacing: float = current_radius - prev_radius
		if spacing < 2600.0:
			failures.append("Orbit spacing too small between rings %d and %d: %.2f" % [i, i + 1, spacing])

	solar_system.queue_free()

	if failures.is_empty():
		print("[TEST] SolarSystemOrbitSpacingCheck passed")
		quit(0)
		return

	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)
