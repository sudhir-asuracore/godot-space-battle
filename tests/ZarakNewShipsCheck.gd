extends SceneTree

const FACTION_PATH := "res://resources/factions/zarak/zarak_confedaracy.tres"
const IRONMAW_PATH := "res://resources/factions/zarak/ships/ironmaw.tres"
const WARBEAST_PATH := "res://resources/factions/zarak/ships/warbeast.tres"
const FRIGATE_02_SCENE := "res://scenes/factions/zarak/ships/ZarakIronmaw.tscn"
const DREAD_01_SCENE := "res://scenes/factions/zarak/ships/ZarakWarbeast.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var ironmaw := load(IRONMAW_PATH) as ShipData
	var warbeast := load(WARBEAST_PATH) as ShipData
	for pair in [["Ironmaw", ironmaw], ["Warbeast", warbeast]]:
		var sd := pair[1] as ShipData
		if not sd:
			failures.append("Failed to load %s ShipData" % pair[0])
			continue
		if sd.name.is_empty():
			failures.append("%s has no name" % pair[0])
		if sd.ship_scene == null:
			failures.append("%s ship_scene unset" % pair[0])
		if sd.is_starter:
			failures.append("%s must not be a starter" % pair[0])
		if sd.purchase_cost <= 0.0:
			failures.append("%s purchase_cost must be positive" % pair[0])
		if sd.get_hangar_portrait() == null:
			failures.append("%s get_hangar_portrait() null (lod_near missing)" % pair[0])
		if sd.get_hangar_icon() == null:
			failures.append("%s get_hangar_icon() null (lod_medium missing)" % pair[0])

	for scene_path in [FRIGATE_02_SCENE, DREAD_01_SCENE]:
		var packed := load(scene_path) as PackedScene
		if not packed:
			failures.append("Failed to load %s" % scene_path)
			continue
		var state := packed.get_state()
		var names := {}
		for i in state.get_node_count():
			names[state.get_node_name(i)] = true
		for lod in ["lod_near", "lod_medium", "lod_far"]:
			if not names.has(lod):
				failures.append("%s missing LOD node '%s'" % [scene_path, lod])
		var inst = packed.instantiate()
		if not (inst is Ship):
			failures.append("%s root is not a Ship" % scene_path)
		if inst:
			inst.free()

	var faction := load(FACTION_PATH) as FactionData
	if not faction:
		failures.append("Failed to load Zarak faction")
	else:
		var found := {"Zarak Ironmaw": false, "Zarak Warbeast": false}
		for entry in faction.hangar_ship_options:
			var sd := entry as ShipData
			if sd and found.has(sd.name):
				found[sd.name] = true
		for key in found:
			if not found[key]:
				failures.append("Faction hangar_ship_options missing '%s'" % key)

	if failures.is_empty():
		print("[TEST] ZarakNewShipsCheck passed")
		quit(0)
		return
	for f in failures:
		push_error("[TEST] %s" % f)
	quit(1)
