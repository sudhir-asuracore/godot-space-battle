extends SceneTree

# Verifies the ship texture level-of-detail (LOD) system:
#   * The ZarakFrigate scene ships three LOD Sprite2D children
#     (lod_near / lod_medium / lod_far) using the agreed naming convention.
#   * Ship.gd switches the visible sprite based on the active camera zoom so a
#     single, appropriately-detailed texture is shown at any zoom level.
#
# The render logic is exercised live by instantiating the frigate next to a
# Camera2D and driving the zoom across the near / medium / far bands.

const ZARAK_FRIGATE_SCENE := "res://scenes/ship/zarak/ZarakFrigate.tscn"

const EXPECTED_LOD_NODES := ["lod_near", "lod_medium", "lod_far"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var packed := load(ZARAK_FRIGATE_SCENE) as PackedScene
	if not packed:
		_fail(["Failed to load ZarakFrigate.tscn"])
		return

	var ship := packed.instantiate()
	if not (ship is Ship):
		ship.free()
		_fail(["ZarakFrigate.tscn root is not a Ship"])
		return

	# 1. The three LOD sprites exist with the expected names.
	for lod_name in EXPECTED_LOD_NODES:
		var sprite := ship.get_node_or_null(NodePath(lod_name)) as Sprite2D
		if sprite == null:
			failures.append("ZarakFrigate is missing LOD Sprite2D '%s'" % lod_name)
		elif sprite.texture == null:
			failures.append("LOD sprite '%s' has no texture assigned" % lod_name)

	# 2. Drive the render logic with a real camera at different zoom levels.
	var camera := Camera2D.new()
	root.add_child(camera)
	camera.make_current()
	root.add_child(ship)
	await process_frame

	# zoom >= 1.6 -> near, 0.6 <= zoom < 1.6 -> medium, zoom < 0.6 -> far.
	_assert_visible_lod(ship, 3.0, "lod_near", failures)
	_assert_visible_lod(ship, 1.0, "lod_medium", failures)
	_assert_visible_lod(ship, 0.3, "lod_far", failures)
	# Boundary: exactly at the near threshold should still select near.
	_assert_visible_lod(ship, 1.6, "lod_near", failures)

	root.remove_child(ship)
	ship.free()
	root.remove_child(camera)
	camera.free()

	if failures.is_empty():
		print("[TEST] ShipTextureLodCheck passed")
		quit(0)
		return
	_fail(failures)

func _assert_visible_lod(ship: Node, zoom: float, expected_name: String, failures: Array[String]) -> void:
	var camera := root.get_viewport().get_camera_2d()
	if camera == null:
		failures.append("No active Camera2D while testing zoom %s" % zoom)
		return
	camera.zoom = Vector2(zoom, zoom)
	ship.call("_update_lod")

	for lod_name in EXPECTED_LOD_NODES:
		var sprite := ship.get_node_or_null(NodePath(lod_name)) as Sprite2D
		if sprite == null:
			continue
		var should_be_visible: bool = lod_name == expected_name
		if sprite.visible != should_be_visible:
			failures.append("At zoom %s expected '%s' visible; '%s'.visible == %s" % [
				zoom, expected_name, lod_name, str(sprite.visible)])

func _fail(failures: Array[String]) -> void:
	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)
