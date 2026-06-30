extends SceneTree

# Reproduces the TestArena spawn recipe for the Zarak Warbeast: the scene is
# added to the tree (running _ready/update_stats against the zarak_frigate.gd
# fallback ShipData) BEFORE the real warbeast ShipData/faction is assigned. The
# warbeast must end up at full hull/shield with no active damage markers, i.e.
# it must not look damaged right after spawning.

const FACTION_PATH := "res://resources/factions/zarak/zarak_confedaracy.tres"
const WARBEAST_PATH := "res://resources/factions/zarak/ships/warbeast.tres"
const WARBEAST_SCENE := "res://scenes/factions/zarak/ships/Zarak_Ship_Dread_Warbeast.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var faction := load(FACTION_PATH) as FactionData
	var ship_data := load(WARBEAST_PATH) as ShipData
	var packed := load(WARBEAST_SCENE) as PackedScene
	if not faction or not ship_data or not packed:
		push_error("[TEST] Failed to load warbeast resources")
		quit(1)
		return

	# Mirror TestArena._instantiate_ship: add to the tree first, assign data after.
	var ship := packed.instantiate() as Ship
	root.add_child(ship)
	ship.is_player_ship = true
	ship.ship_data = ship_data
	ship.faction_data = faction
	ship.update_stats()

	if not is_equal_approx(ship.current_hull, ship.max_hull):
		failures.append("Hull not full after spawn: %.1f / %.1f" % [ship.current_hull, ship.max_hull])
	if not is_equal_approx(ship.current_shield, ship.max_shield):
		failures.append("Shield not full after spawn: %.1f / %.1f" % [ship.current_shield, ship.max_shield])

	var active_markers: int = ship._get_active_damage_marker_count()
	if active_markers != 0:
		failures.append("Fresh warbeast shows %d active damage markers (smoke)" % active_markers)

	# Sanity: max_hull must reflect the warbeast resource (900) with the Zarak
	# hull multiplier (1.25), not the gorehammer fallback (320).
	var expected_max_hull := ship_data.max_hull * faction.hull_multiplier
	if not is_equal_approx(ship.max_hull, expected_max_hull):
		failures.append("max_hull %.1f != expected %.1f" % [ship.max_hull, expected_max_hull])

	ship.free()

	if failures.is_empty():
		print("[TEST] ZarakWarbeastSpawnHealthCheck passed")
		quit(0)
		return
	for f in failures:
		push_error("[TEST] %s" % f)
	quit(1)
