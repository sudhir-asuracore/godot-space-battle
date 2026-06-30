extends SceneTree

const SHIP_SCENE := preload("res://scenes/factions/zarak/ships/Zarak_Ship_Frigate_Gorehammer.tscn")
const SHIP_DATA_PATH := "res://resources/factions/zarak/ships/gorehammer.tres"

func _initialize() -> void:
	var ship_data := load(SHIP_DATA_PATH) as ShipData
	var ship := SHIP_SCENE.instantiate() as Node2D

	# Remove the built-in WeaponController so it does not also configure.
	var wc := ship.get_node_or_null(^"WeaponController")
	if wc:
		ship.remove_child(wc)
		wc.queue_free()

	# Configure each module while still OUT of the tree, so the projectile
	# template is captured before any physics frame can free it.
	var modules := []
	for child in ship.get_children():
		if not str(child.name).begins_with("weapon_"):
			continue
		if not (child.has_method("configure") and child.has_method("tick")):
			continue
		var key := _key(child.name)
		var wd: WeaponData = ship_data.get_ship_weapon(key)
		child.configure(wd, ship)
		modules.append({"node": child, "wd": wd})

	get_root().add_child(ship)
	await process_frame
	ship.global_position = Vector2.ZERO
	ship.global_rotation = 0.0

	var target := Node2D.new()
	get_root().add_child(target)
	target.global_position = Vector2.RIGHT * 200.0

	for m in modules:
		var child = m["node"]
		var wd: WeaponData = m["wd"]
		print("[DEBUG_LOG] ", child.name,
			" projscene=", child.get("_projectile_scene") != null,
			" projtmpl=", child.get("_projectile_template") != null)
		var seen := {}
		for i in range(160):
			child.tick(0.05, target, true)
			for c in get_root().get_children():
				if c is Projectile and not seen.has(c.get_instance_id()):
					seen[c.get_instance_id()] = true
			for c in get_root().get_children():
				if c is Projectile:
					c.queue_free()
			await process_frame
		print("[DEBUG_LOG]   ", child.name, " weapon=", (wd.name if wd else "NULL"),
			" -> unique projectiles fired=", seen.size())
	quit(0)

func _key(node_name: StringName) -> StringName:
	var parts := str(node_name).split("_")
	if parts.size() < 4:
		return &""
	return StringName("weapon_" + "_".join(parts.slice(1, parts.size() - 2)))
