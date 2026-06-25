extends SceneTree

const HOMEBASE_SCENE := preload("res://scenes/homebase/Homebase.tscn")
const SOLARION_FACTION := preload("res://resources/factions/solarion_collective/solarion_collective.tres")
const ENEMY_FACTION := preload("res://resources/factions/zarak/zarak_confedaracy.tres")

class DummyEnemyTarget:
	extends Node2D
	var faction_data: FactionData

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var homebase := HOMEBASE_SCENE.instantiate() as Homebase
	homebase.faction_data = SOLARION_FACTION
	root.add_child(homebase)

	var target := DummyEnemyTarget.new()
	target.faction_data = ENEMY_FACTION
	target.global_position = homebase.global_position + Vector2(700.0, 0.0)
	target.add_to_group("ships")
	root.add_child(target)

	var seen_projectiles: Dictionary = {}
	var eligible_frame_hits := 0
	var tracked_turrets: Array[DefenseTurret] = []

	for _i in range(180):
		if tracked_turrets.is_empty():
			for node in root.get_tree().get_nodes_in_group("homebase_defenses"):
				var turret := node as DefenseTurret
				if turret:
					tracked_turrets.append(turret)

		for turret in tracked_turrets:
			var in_band: bool = bool(turret.call("_is_target_in_attack_band", target))
			var in_cone: bool = bool(turret.call("_is_target_in_attack_cone", target))
			if in_band and in_cone:
				eligible_frame_hits += 1

		for child in root.get_children():
			if child is Projectile:
				seen_projectiles[child.get_instance_id()] = true

		await process_frame

	for child in root.get_children():
		if child is Projectile:
			seen_projectiles[child.get_instance_id()] = true
			child.queue_free()

	var projectile_count := seen_projectiles.size()

	if projectile_count <= 0:
		failures.append("Expected Solarion homebase turrets to spawn projectiles against enemy ship (eligible_frames=%d, tracked_turrets=%d)" % [eligible_frame_hits, tracked_turrets.size()])

	_finish(failures, homebase, target)

func _finish(failures: Array[String], homebase: Homebase, target: Node) -> void:
	if target:
		target.queue_free()
	if homebase:
		homebase.queue_free()

	if failures.is_empty():
		print("[TEST] SolarionHomebaseTurretFiringIntegrationCheck passed")
		quit(0)
		return

	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)