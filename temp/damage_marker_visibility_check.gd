extends SceneTree

const SHIP_SCENE := preload("res://scenes/Ship.tscn")
const SHIP_DATA_PATH := "res://resources/factions/zarak/ships/t1_assault_ship.tres"

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	await process_frame

	var ship := _spawn_ship()
	var effect := _get_effect(ship)
	assert(effect != null, "damage_0 should have an attached effect")
	assert(effect.visible, "Debug mode should keep damage effect visible while ship is alive")

	var plume := effect.get_node_or_null(^"Sprite2D") as Sprite2D
	assert(plume != null, "Damage effect should contain a Sprite2D plume")
	assert(plume.material is ShaderMaterial, "Plume should use ShaderMaterial")

	var plume_material := plume.material as ShaderMaterial
	assert(plume_material != null, "Plume material should be ShaderMaterial")
	assert(plume_material.shader != null, "Plume shader should be assigned")

	ship.current_shield = 0.0
	ship.take_damage(5.0, 0.0)
	assert(effect.visible, "Effect should remain visible after taking non-lethal damage in debug mode")
	assert(plume.visible, "Plume should remain visible while effect is active")

	ship.take_damage(10_000.0, 0.0)
	assert(ship.is_dead, "Ship should be dead after lethal damage")
	assert(not effect.visible, "Effect should be disabled once ship is dead")
	assert(not plume.is_visible_in_tree(), "Plume should be hidden once effect is disabled")

	ship.queue_free()
	quit(0)

func _spawn_ship() -> Ship:
	var ship := SHIP_SCENE.instantiate() as Ship
	assert(ship != null, "Ship scene should instantiate")

	var ship_data := load(SHIP_DATA_PATH) as ShipData
	assert(ship_data != null, "Assault ship data should load")
	ship.ship_data = ship_data

	root.add_child(ship)
	return ship

func _get_effect(ship: Ship) -> Node2D:
	var marker := ship.get_node_or_null(^"damage_0") as Marker2D
	assert(marker != null, "Ship scene should contain marker damage_0")
	return marker.get_node_or_null(^"DamageMarkerEffect") as Node2D
