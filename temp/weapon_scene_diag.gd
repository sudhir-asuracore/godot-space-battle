extends SceneTree

const GATTLING := preload("res://scenes/common/weapons/Weapon_Gattling.tscn")
const CANNON := preload("res://scenes/factions/zarak/weapons/ZarakWeapon_Cannon.tscn")
const GATTLING_DATA := "res://resources/factions/zarak/weapons/zarak_weapon_gattlingheavy.tres"
const CANNON_DATA := "res://resources/factions/zarak/weapons/zarak_weapon_cannonlarge.tres"

func _initialize() -> void:
	await process_frame
	_probe("CANNON", CANNON, CANNON_DATA)
	_probe("GATTLING", GATTLING, GATTLING_DATA)
	quit(0)

func _probe(label: String, scene: PackedScene, data_path: String) -> void:
	var wdata := load(data_path) as WeaponData
	var mod := scene.instantiate()
	get_root().add_child(mod)
	var ship := Node2D.new()
	get_root().add_child(ship)

	# List children BEFORE configure.
	var names := []
	for c in mod.get_children():
		names.append("%s(%s, sfp=%s)" % [c.name, c.get_class(), c.scene_file_path])
	print("[DEBUG_LOG] ", label, " children before configure: ", names)

	mod.call("configure", wdata, ship)
	print("[DEBUG_LOG] ", label, " after configure: _projectile_scene=", mod.get("_projectile_scene"),
		" _projectile_template=", mod.get("_projectile_template"),
		" _muzzle=", mod.get("_muzzle"))

	var target := Node2D.new()
	get_root().add_child(target)
	target.global_position = mod.global_position + Vector2.RIGHT * 100.0

	var rc0 := get_root().get_child_count()
	mod.call("_fire", target)
	print("[DEBUG_LOG] ", label, " root child delta after _fire=", get_root().get_child_count() - rc0)

	mod.queue_free()
	ship.queue_free()
	target.queue_free()
