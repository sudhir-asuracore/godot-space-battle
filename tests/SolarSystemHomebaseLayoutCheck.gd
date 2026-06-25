extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	seed(20260626)

	var solar_system := SolarSystem.new()
	solar_system.player_count = 4 # 4 players -> 12 planets (clamped)
	root.add_child(solar_system)
	await process_frame

	var orbits: Array = solar_system.get("_planets")
	if orbits.size() != 12:
		failures.append("Expected 12 planets for 4 players, got %d" % orbits.size())

	var player_planet: Planet = solar_system.player_homebase_planet
	var enemy_planet: Planet = solar_system.enemy_homebase_planet
	if not player_planet or not enemy_planet:
		failures.append("Both homebase planets must be assigned")
	elif player_planet == enemy_planet:
		failures.append("Player and enemy homebases must be different planets")

	# The two homebase ends are the 2nd and last-but-2nd planets.
	var inner: Planet = orbits[1].node
	var outer: Planet = orbits[orbits.size() - 2].node
	var ends := [inner, outer]
	if player_planet not in ends or enemy_planet not in ends:
		failures.append("Homebases must be the 2nd and last-but-2nd planets")

	# Homebase ends sit on opposite sides of the sun and stay stationary.
	if float(orbits[1].speed) != 0.0 or float(orbits[orbits.size() - 2].speed) != 0.0:
		failures.append("Homebase end planets must be stationary")

	var player_pos: Vector2 = solar_system.player_homebase_position
	var enemy_pos: Vector2 = solar_system.enemy_homebase_position
	if player_pos.normalized().dot(enemy_pos.normalized()) > -0.5:
		failures.append("Homebases should be on opposite ends of the system")

	# Player ship spawns near its homebase garage.
	var spawn_pos: Vector2 = solar_system.player_spawn_position
	if spawn_pos.distance_to(player_pos) > 1500.0:
		failures.append("Player spawn must be near the player homebase")
	if spawn_pos.length() >= player_pos.length():
		failures.append("Player spawn should be nudged toward the sun from the homebase")

	solar_system.queue_free()

	if failures.is_empty():
		print("[TEST] SolarSystemHomebaseLayoutCheck passed")
		quit(0)
		return

	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)
