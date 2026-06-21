extends Sprite2D
#
#func trigger_impact(global_hit_position: Vector2):
	## 1. Safely grab the material as a ShaderMaterial
	#var mat = material as ShaderMaterial
	#if not mat:
		#return
#
	## 2. Convert global pixel coordinates to local coordinates
	#var local_pos: Vector2 = to_local(global_hit_position)
	#
	## 3. Map local coordinates to a 0.0 -> 1.0 UV space
	#var uv_pos: Vector2 = (local_pos / size) + Vector2(0.5, 0.5)
	#
	## 4. Pass the Vector2 hit origin to the shader uniform
	#mat.set_shader_parameter("impact_pos", uv_pos)
	#
	## 5. Animate the ripple radius expanding outward
	#var tween = create_tween()
	#
	## Reset the radius back to zero immediately before starting
	#mat.set_shader_parameter("impact_radius", 0.0)
	#
	## Smoothly scale the radius from 0.0 to 1.2 over 0.6 seconds
	#tween.tween_property(mat, "shader_parameter/impact_radius", 1.2, 0.6)\
		#.set_trans(Tween.TRANS_QUAD)\
		#.set_ease(Tween.EASE_OUT)
