extends Parallax2D
class_name ParallaxBg

func _process(_delta: float) -> void:
	# Dynamically get the currently active Camera2D in the viewport
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera:
		# Calculate the raw parallax offset based on camera's global position
		var offset_x: float = -camera.global_position.x * scroll_scale.x
		var offset_y: float = -camera.global_position.y * scroll_scale.y
		
		# Wrap the offset to fit within the repeat texture bounds (tiling sizes)
		offset_x = fmod(offset_x, repeat_size.x)
		offset_y = fmod(offset_y, repeat_size.y)
		
		# Keep offsets strictly positive to ensure perfect coverage
		# with repeat_times = 3 across 1080p dimensions
		if offset_x < 0.0:
			offset_x += repeat_size.x
		if offset_y < 0.0:
			offset_y += repeat_size.y
			
		# Manually apply the wrapped scroll offset
		scroll_offset = Vector2(offset_x, offset_y)
