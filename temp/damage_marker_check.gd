extends SceneTree

const SHIP_SCENE := preload("res://scenes/Ship.tscn")
const SHIP_DATA_PATH := "res://resources/factions/zarak/ships/t1_assault_ship.tres"

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	await process_frame

	_verify_single_marker_turns_on_when_hull_is_damaged()
	_verify_multiple_markers_scale_with_damage()

	quit(0)

func _verify_single_marker_turns_on_when_hull_is_damaged() -> void:
	var ship := _spawn_ship_with_extra_markers(0)
	var effect := _get_marker_effect(ship, 0)
	assert(effect != null, "damage_0 should have an attached damage effect")
	assert(effect.visible, "Debug mode should keep damage effect visible at full hull")

	ship.current_shield = 0.0
	ship.take_damage(5.0, 0.0)
	assert(effect.visible, "damage_0 effect should remain visible after hull damage")

	ship.respawn(Vector2.ZERO)
	assert(effect.visible, "Debug mode should keep effect visible on respawn while alive")

	ship.queue_free()

func _verify_multiple_markers_scale_with_damage() -> void:
	var ship := _spawn_ship_with_extra_markers(2)
	assert(_count_visible_marker_effects(ship, 3) == 3, "Debug mode should keep all marker effects visible at full hull")

	ship.current_shield = 0.0
	ship.take_damage(10.0, 0.0)
	assert(_count_visible_marker_effects(ship, 3) == 3, "Debug mode should keep all markers visible after minor damage")

	ship.take_damage(30.0, 0.0)
	assert(_count_visible_marker_effects(ship, 3) == 3, "Debug mode should keep all markers visible after moderate damage")

	ship.take_damage(35.0, 0.0)
	assert(_count_visible_marker_effects(ship, 3) == 3, "Debug mode should keep all markers visible after heavy damage")

	ship.take_damage(200.0, 0.0)
	assert(
		_count_visible_marker_effects(ship, 3) == 0,
		"Marker effects should be disabled when the ship is destroyed"
	)

	ship.queue_free()

func _spawn_ship_with_extra_markers(extra_markers: int) -> Ship:
	var ship := SHIP_SCENE.instantiate() as Ship
	assert(ship != null, "Ship scene should instantiate")

	var ship_data := load(SHIP_DATA_PATH) as ShipData
	assert(ship_data != null, "Assault ship data should load")
	ship.ship_data = ship_data

	for marker_index in range(extra_markers):
		var marker := Marker2D.new()
		marker.name = ("damage_%d" % (marker_index + 1)) as StringName
		ship.add_child(marker)

	root.add_child(ship)
	return ship

func _get_marker_effect(ship: Ship, marker_index: int) -> Node2D:
	var marker_name := ("damage_%d" % marker_index) as StringName
	for child in ship.get_children():
		var marker := child as Marker2D
		if marker and marker.name == marker_name:
			return marker.get_node_or_null(^"DamageMarkerEffect") as Node2D
	return null

func _count_visible_marker_effects(ship: Ship, marker_count: int) -> int:
	var visible_count := 0

	for marker_index in range(marker_count):
		var effect := _get_marker_effect(ship, marker_index)
		assert(effect != null, "damage_%d should have an attached effect" % marker_index)
		if effect and effect.visible:
			visible_count += 1

	return visible_count