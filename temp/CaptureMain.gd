extends Node2D

# Temporary verification harness: loads the real Main scene, waits for a few
# frames so 2D lights/CanvasModulate are composited, saves a screenshot, quits.

func _ready() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	# Let the solar system spawn and lights settle.
	await get_tree().create_timer(1.5).timeout

	# --- Diagnostics ---
	var ship: Node = main.get_node_or_null("Ship")
	print("SHIP=", ship)
	if ship:
		var spr := ship.get_node_or_null("Sprite2D")
		print("SHIP_SPRITE=", spr, " material=", (spr.material if spr else null), " light_mask=", (spr.light_mask if spr else -1), " self_modulate=", (spr.self_modulate if spr else null))
		# Move ship right next to the sun and focus the camera on it.
		ship.global_position = Vector2(0, 250)
		var cam: Camera2D = main.get_node_or_null("Camera2D")
		if cam:
			cam.set_process(false)
			cam.set_physics_process(false)
			cam.make_current()
			cam.global_position = ship.global_position
			cam.zoom = Vector2(3, 3)

	# Experiment: kill ambient and crank the light to test if 2D light affects the sprite.
	var amb := main.get_node_or_null("AmbientLight")
	if amb:
		amb.color = Color(0, 0, 0, 1)
		print("AMBIENT set black")
	# Find the sun light and inspect whether it can affect the ship.
	var light := _find_pointlight(main)
	print("POINTLIGHT=", light)
	if light:
		# Stop the sun's per-frame energy pulse so our test energy sticks.
		var sun_node := light.get_parent()
		if sun_node:
			sun_node.set_process(false)
		light.enabled = true
		light.energy = 6.0
		print("  enabled=", light.enabled, " energy=", light.energy, " range_layer_min=", light.range_layer_min, " range_layer_max=", light.range_layer_max, " item_cull=", light.range_item_cull_mask, " z_min=", light.range_z_min, " z_max=", light.range_z_max, " global_pos=", light.global_position)

	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://temp/run_capture.png")
	print("CAPTURE_SAVED res://temp/run_capture.png size=", img.get_size())
	get_tree().quit()

func _find_pointlight(n: Node) -> PointLight2D:
	if n is PointLight2D:
		return n
	for c in n.get_children():
		var r := _find_pointlight(c)
		if r:
			return r
	return null
