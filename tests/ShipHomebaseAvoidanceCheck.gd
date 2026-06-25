extends SceneTree

const SHIP_SCENE := preload("res://scenes/ship/Ship.tscn")
const HOMEBASE_SCENE := preload("res://scenes/homebase/Homebase.tscn")
const SHIP_DATA := preload("res://resources/ships/base/t1_assault_ship.tres")
const FACTION := preload("res://resources/factions/solarion_collective/solarion_collective.tres")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var homebase := HOMEBASE_SCENE.instantiate() as Homebase
	homebase.faction_data = FACTION
	homebase.global_position = Vector2.ZERO
	root.add_child(homebase)

	var ship := SHIP_SCENE.instantiate() as Ship
	ship.ship_data = SHIP_DATA
	ship.faction_data = FACTION
	ship.global_position = Vector2(-2300.0, 0.0)
	root.add_child(ship)
	await process_frame

	var destination := Vector2(2300.0, 0.0)
	ship.global_rotation = 0.0
	ship.set_target(destination)
	ship.call("_process_movement", 0.25)

	if absf(ship.global_rotation) > 0.01:
		failures.append("Expected ship heading to remain on direct line through homebase")
	if ship.target_position.distance_to(destination) > 0.01:
		failures.append("Expected target position to remain unchanged")

	ship.queue_free()
	homebase.queue_free()

	if failures.is_empty():
		print("[TEST] ShipHomebaseAvoidanceCheck passed")
		quit(0)
		return

	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)
