extends SceneTree

const SOLARION_SHOT_SCENE := preload("res://scenes/ship/accessories/projectiles/SolarionTurretShot.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var faction := FactionData.new()
	faction.turret_attack_range = 1000.0
	faction.turret_min_attack_range = 0.0
	faction.turret_attack_cone_degrees = 360.0
	faction.turret_turn_speed = 10.0
	faction.turret_fire_rate = 10.0
	faction.turret_projectile_speed = 900.0
	faction.turret_projectile_scene = SOLARION_SHOT_SCENE

	var turret := DefenseTurret.new()
	turret.faction_data = faction
	turret.homebase = Homebase.new()
	root.add_child(turret)

	var target := Node2D.new()
	target.global_position = Vector2(300.0, 0.0)
	target.add_to_group("ships")
	root.add_child(target)

	var before_count := root.get_child_count()
	for _i in range(60):
		await process_frame

	if root.get_child_count() <= before_count:
		failures.append("Expected turret to spawn a projectile when Solarion turret projectile scene is configured")

	for child in root.get_children():
		if child is Projectile:
			child.queue_free()

	turret.queue_free()
	target.queue_free()
	if turret.homebase:
		turret.homebase.queue_free()

	if failures.is_empty():
		print("[TEST] DefenseTurretSolarionShotFiringCheck passed")
		quit(0)
		return

	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)