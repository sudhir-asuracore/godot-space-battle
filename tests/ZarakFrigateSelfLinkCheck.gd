extends SceneTree

# Verifies a directly-instantiated ZarakFrigate scene becomes self-sufficient:
# it picks up its own ship_data (safety net) and resolves the zarak faction,
# producing non-default stats without any external spawner wiring.

const ZARAK_FRIGATE_SCENE := "res://scenes/factions/zarak/ships/ZarakFrigate.tscn"
const ZARAK_FACTION_PATH := "res://resources/factions/zarak/zarak_confedaracy.tres"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var scene := load(ZARAK_FRIGATE_SCENE) as PackedScene
	var ship := scene.instantiate()
	root.add_child(ship)
	await process_frame

	if ship.ship_data == null:
		failures.append("ship_data was not auto-assigned")
	elif ship.ship_data.name != "Zarak Frigate":
		failures.append("ship_data is not the zarak frigate: %s" % ship.ship_data.name)

	var zarak_faction := load(ZARAK_FACTION_PATH) as FactionData
	if ship.faction_data == null:
		failures.append("faction_data was not resolved")
	elif ship.faction_data != zarak_faction:
		failures.append("faction_data resolved to the wrong faction")

	# Stats reflect the resolved faction multipliers (zarak hull_multiplier=1.25),
	# proving the faction was applied rather than left at default 1.0.
	var expected_hull: float = ship.ship_data.max_hull * zarak_faction.hull_multiplier
	if not is_equal_approx(ship.max_hull, expected_hull):
		failures.append("max_hull %.1f did not apply faction multiplier (expected %.1f)" % [ship.max_hull, expected_hull])

	ship.queue_free()

	if failures.is_empty():
		print("[TEST] ZarakFrigateSelfLinkCheck passed")
		quit(0)
		return
	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)
