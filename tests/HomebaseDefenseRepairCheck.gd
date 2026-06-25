extends SceneTree

const HOMEBASE_SCENE := preload("res://scenes/homebase/Homebase.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var faction := FactionData.new()
	faction.defense_structure_max_hull = 100.0
	faction.defense_structure_auto_repair_rate = 1000.0
	faction.defense_structure_auto_repair_delay = 0.0
	faction.turret_attack_range = 1000.0
	faction.turret_min_attack_range = 0.0
	faction.turret_attack_cone_degrees = 360.0
	faction.turret_turn_speed = 10.0
	faction.turret_fire_rate = 1.0
	faction.turret_projectile_speed = 1000.0

	var homebase := HOMEBASE_SCENE.instantiate() as Homebase
	homebase.faction_data = faction
	root.add_child(homebase)

	var turret := DefenseTurret.new()
	root.add_child(turret)
	turret.configure(faction, homebase)

	var hangar := DefenseHangar.new()
	root.add_child(hangar)
	hangar.configure(faction, homebase)

	await process_frame

	var turret_hitbox := turret.get_node_or_null(^"Hitbox") as Area2D
	if not turret_hitbox:
		failures.append("Expected defense turret to provide a hitbox")
	else:
		var turret_projectile := Projectile.new()
		turret_projectile.damage_hull = 30.0
		var turret_hit_result: bool = bool(turret_projectile.call("_try_apply_hit", turret_hitbox))
		if not turret_hit_result:
			failures.append("Expected projectile to damage turret through hitbox")
		if turret.current_hull >= turret.max_hull:
			failures.append("Expected turret hull to decrease after hit")

	var hangar_projectile := Projectile.new()
	hangar_projectile.damage_hull = 30.0
	var hangar_hit_result: bool = bool(hangar_projectile.call("_try_apply_hit", hangar))
	if not hangar_hit_result:
		failures.append("Expected projectile to damage hangar")
	if hangar.current_hull >= hangar.max_hull:
		failures.append("Expected hangar hull to decrease after hit")

	turret.take_damage(999.0, 0.0)
	hangar.take_damage(999.0, 0.0)
	if not turret.is_destroyed:
		failures.append("Expected turret to enter destroyed state")
	if not hangar.is_destroyed:
		failures.append("Expected hangar to enter destroyed state")

	for _i in range(5):
		await process_frame

	if turret.current_hull <= 0.0 or turret.is_destroyed:
		failures.append("Expected turret auto-repair to restore operational state")
	if hangar.current_hull <= 0.0 or hangar.is_destroyed:
		failures.append("Expected hangar auto-repair to restore operational state")

	turret.queue_free()
	hangar.queue_free()
	homebase.queue_free()

	if failures.is_empty():
		print("[TEST] HomebaseDefenseRepairCheck passed")
		quit(0)
		return

	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)
