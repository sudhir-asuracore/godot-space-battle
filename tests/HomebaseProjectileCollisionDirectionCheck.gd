extends SceneTree

const HOMEBASE_SCENE := preload("res://scenes/homebase/Homebase.tscn")
const SOLARION_FACTION := preload("res://resources/factions/solarion_collective/solarion_collective.tres")
const ENEMY_FACTION := preload("res://resources/factions/zarak/zarak_confedaracy.tres")
const PROJECTILE_SCENE := preload("res://scenes/common/weapons/Projectile.tscn")

class DummyEnemySource:
	extends Node2D
	var faction_data: FactionData

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var homebase := HOMEBASE_SCENE.instantiate() as Homebase
	homebase.faction_data = SOLARION_FACTION
	root.add_child(homebase)

	await process_frame

	var turret := _find_right_side_turret(homebase)
	if not turret:
		failures.append("Failed to locate a configured homebase turret for collision-direction checks")
		_finish(failures, homebase)
		return

	var outgoing_projectile := await _spawn_outgoing_turret_projectile(turret)
	if not outgoing_projectile:
		failures.append("Failed to spawn outgoing turret projectile for homebase collision check")
	else:
		var survived_outgoing := await _wait_for_projectile_survival(outgoing_projectile, 45)
		if not survived_outgoing:
			failures.append("Expected outgoing turret projectile to pass through own homebase collision and continue traveling")

	var incoming_blocked := await _verify_incoming_projectile_blocked(homebase)
	if not incoming_blocked:
		failures.append("Expected incoming enemy projectile to be blocked by homebase collision")

	_finish(failures, homebase)

func _find_right_side_turret(homebase: Homebase) -> DefenseTurret:
	for turret_node in root.get_tree().get_nodes_in_group("homebase_defenses"):
		var turret := turret_node as DefenseTurret
		if not turret or turret.homebase != homebase:
			continue
		if turret.global_position.x > homebase.global_position.x:
			return turret
	return null

func _spawn_outgoing_turret_projectile(turret: DefenseTurret) -> Projectile:
	var target := Node2D.new()
	target.global_position = turret.homebase.global_position + Vector2(-700.0, 0.0)
	root.add_child(target)

	turret.call("_fire_projectile", target)
	await process_frame

	target.queue_free()

	for child in root.get_children():
		var projectile := child as Projectile
		if projectile and projectile.source_ship == turret:
			return projectile

	return null

func _wait_for_projectile_survival(projectile: Projectile, frames: int) -> bool:
	for _i in range(frames):
		if not is_instance_valid(projectile):
			return false
		await process_frame
	return is_instance_valid(projectile)

func _verify_incoming_projectile_blocked(homebase: Homebase) -> bool:
	var enemy_source := DummyEnemySource.new()
	enemy_source.faction_data = ENEMY_FACTION
	root.add_child(enemy_source)

	var projectile := PROJECTILE_SCENE.instantiate() as Projectile
	if not projectile:
		enemy_source.queue_free()
		return false

	projectile.global_position = homebase.global_position + Vector2(-250.0, 0.0)
	projectile.direction = Vector2.RIGHT
	projectile.speed = 900.0
	projectile.source_ship = enemy_source
	root.add_child(projectile)

	for _i in range(45):
		if not is_instance_valid(projectile):
			enemy_source.queue_free()
			return true
		await process_frame

	enemy_source.queue_free()
	if is_instance_valid(projectile):
		projectile.queue_free()
	return false

func _finish(failures: Array[String], homebase: Homebase) -> void:
	for child in root.get_children():
		if child is Projectile:
			child.queue_free()

	if homebase:
		homebase.queue_free()

	if failures.is_empty():
		print("[TEST] HomebaseProjectileCollisionDirectionCheck passed")
		quit(0)
		return

	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)