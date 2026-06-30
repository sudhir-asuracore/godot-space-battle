extends SceneTree

# Verifies that the Zarak frigate is registered as a selectable ship and that
# the in-game ship selection wiring (signal + HUD/Main hooks) is in place.
#
# NOTE: Scripts that reference the `EventBus` autoload *global* (e.g. PlayerHUD,
# Main) cannot be compiled under the headless `--script` harness because the
# autoload global identifiers are not registered in that mode. Those scripts are
# therefore validated by source inspection, while the live signal is exercised
# through the `/root/EventBus` autoload node.

const ZARAK_FACTION_PATH := "res://resources/factions/zarak/zarak_confedaracy.tres"
const ZARAK_FRIGATE_PATH := "res://resources/factions/zarak/ships/gorehammer.tres"
const ZARAK_FRIGATE_SCENE := "res://scenes/factions/zarak/ships/Zarak_Ship_Frigate_Gorehammer.tscn"
const PLAYER_HUD_SCRIPT := "res://scripts/ui/PlayerHUD.gd"
const HANGAR_STORE_SCRIPT := "res://scripts/ui/HangarStore.gd"
const MAIN_SCRIPT := "res://scenes/Main.gd"

var _selected_ship_data: ShipData = null

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	# 1. Frigate ship resource exists, is named, and points at its scene.
	var frigate := load(ZARAK_FRIGATE_PATH) as ShipData
	if not frigate:
		failures.append("Failed to load gorehammer.tres as ShipData")
	else:
		if frigate.name != "Zarak Gorehammer":
			failures.append("Frigate name should be 'Zarak Gorehammer', got '%s'" % frigate.name)
		if frigate.ship_scene == null:
			failures.append("Frigate ship_scene is not set")

	# 2. ZarakFrigate scene instantiates as a Ship.
	var frigate_scene := load(ZARAK_FRIGATE_SCENE) as PackedScene
	if not frigate_scene:
		failures.append("Failed to load Zarak_Ship_Frigate_Gorehammer.tscn")
	else:
		var ship := frigate_scene.instantiate()
		if not (ship is Ship):
			failures.append("Zarak_Ship_Frigate_Gorehammer.tscn root is not a Ship")
		if ship:
			ship.free()

	# 3. Frigate is registered in the Zarak faction's hangar options.
	if frigate and frigate.ship_scene:
		var faction := load(ZARAK_FACTION_PATH) as FactionData
		if not faction:
			failures.append("Failed to load Zarak faction")
		else:
			var found_frigate := false
			for entry in faction.hangar_ship_options:
				var sd := entry as ShipData
				if sd and sd.name == "Zarak Gorehammer":
					found_frigate = true
			if not found_frigate:
				failures.append("Zarak faction hangar_ship_options is missing the frigate")

	# 4. The player_ship_selected signal exists and routes the chosen ship.
	var event_bus := root.get_node_or_null(^"/root/EventBus")
	if not event_bus:
		failures.append("EventBus autoload not found")
	elif not event_bus.has_signal("player_ship_selected"):
		failures.append("EventBus is missing the player_ship_selected signal")
	elif frigate:
		event_bus.connect("player_ship_selected", _on_player_ship_selected)
		event_bus.emit_signal("player_ship_selected", frigate)
		await process_frame
		if _selected_ship_data != frigate:
			failures.append("player_ship_selected did not deliver the chosen ship data")
		event_bus.disconnect("player_ship_selected", _on_player_ship_selected)

	# 5. HUD exposes the clickable selection API; the Hangar Store scene builds
	# the ship list and emits the selection signal.
	_check_source(PLAYER_HUD_SCRIPT, [
		"func show_ship_selection",
		"func hide_ship_selection",
		"func is_ship_selection_visible",
	], failures)
	_check_source(HANGAR_STORE_SCRIPT, [
		"func _make_ship_button",
		"EventBus.player_ship_selected.emit",
	], failures)

	# 6. Main wires the picker and spawns/replaces the player ship.
	_check_source(MAIN_SCRIPT, [
		"func _prompt_initial_ship_selection",
		"func _on_player_ship_selected",
		"func _spawn_player_ship_from_data",
		"EventBus.player_ship_selected.connect",
	], failures)

	if failures.is_empty():
		print("[TEST] ZarakFrigateShipSelectionCheck passed")
		quit(0)
		return
	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)

func _check_source(path: String, needles: Array, failures: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		failures.append("Could not open %s for inspection" % path)
		return
	var text := file.get_as_text()
	file.close()
	for needle in needles:
		if not text.contains(needle):
			failures.append("%s is missing expected code: '%s'" % [path, needle])

func _on_player_ship_selected(ship_data: ShipData) -> void:
	_selected_ship_data = ship_data
