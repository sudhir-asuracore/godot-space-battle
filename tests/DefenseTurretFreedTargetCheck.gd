extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var turret := DefenseTurret.new()
	var faction := FactionData.new()
	faction.turret_attack_range = 1000.0
	faction.turret_min_attack_range = 0.0
	turret.faction_data = faction
	turret.homebase = Homebase.new()
	root.add_child(turret)

	var target := Node2D.new()
	target.global_position = Vector2(120.0, 0.0)
	root.add_child(target)

	turret.set("_target", target)
	target.queue_free()
	await process_frame

	var result: Variant = turret.call("_is_valid_target", turret.get("_target"))
	if result != false:
		failures.append("Expected freed target validation to return false, got: %s" % [result])

	turret.queue_free()
	if turret.homebase:
		turret.homebase.queue_free()

	if failures.is_empty():
		print("[TEST] DefenseTurretFreedTargetCheck passed")
		quit(0)
		return

	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)