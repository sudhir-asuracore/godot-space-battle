extends SceneTree

# Verifies the procedural nebula background:
#   * applies the requested seed,
#   * is reproducible (identical seeds -> identical sky), per docs/conventions.md,
#   * produces variety (different seeds -> different sky),
#   * clones its material so the shared on-disk resource is never mutated.

const SHADER_PATH := "res://shaders/skies-nebula.gdshader"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var shared_material: ShaderMaterial = _build_material()

	var a: NebulaBackground = _make_nebula(12345, shared_material)
	var b: NebulaBackground = _make_nebula(12345, shared_material)
	var c: NebulaBackground = _make_nebula(67890, shared_material)
	root.add_child(a)
	root.add_child(b)
	root.add_child(c)
	await process_frame

	# 1. The requested seed is recorded.
	if a.get_active_seed() != 12345:
		failures.append("Expected active seed 12345, got %d" % a.get_active_seed())

	var mat_a: ShaderMaterial = _nebula_material(a)
	var mat_b: ShaderMaterial = _nebula_material(b)
	var mat_c: ShaderMaterial = _nebula_material(c)

	if mat_a == null or mat_b == null or mat_c == null:
		failures.append("Nebula material missing after generation")
	else:
		# 2. The shared on-disk material must not be mutated (each node clones it).
		if mat_a == shared_material:
			failures.append("Nebula did not clone its material (shared resource mutated)")
		if mat_a == mat_b:
			failures.append("Two nebulas share the same material instance")

		# 3. Reproducibility: identical seeds yield an identical sky.
		if not _same_look(mat_a, mat_b):
			failures.append("Identical seeds produced different nebulas (non-deterministic)")

		# 4. Variety: different seeds yield a different sky.
		if _same_look(mat_a, mat_c):
			failures.append("Different seeds produced an identical nebula (no variety)")

	# 5. Auto seed (0) resolves to a concrete non-zero seed.
	var auto: NebulaBackground = _make_nebula(0, shared_material)
	root.add_child(auto)
	await process_frame
	if auto.get_active_seed() == 0:
		failures.append("Auto seed did not resolve to a concrete seed")

	a.queue_free()
	b.queue_free()
	c.queue_free()
	auto.queue_free()

	if failures.is_empty():
		print("[TEST] NebulaBackgroundSeedCheck passed")
		quit(0)
		return

	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)

func _build_material() -> ShaderMaterial:
	var shader: Shader = load(SHADER_PATH) as Shader
	var fn := FastNoiseLite.new()
	fn.frequency = 0.005
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = fn
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter(&"noise_texture", tex)
	mat.set_shader_parameter(&"nebula_color", Color(0.13, 0.42, 0.78, 0.85))
	mat.set_shader_parameter(&"cloud_density", 0.8)
	return mat

func _make_nebula(seed_value: int, base_material: ShaderMaterial) -> NebulaBackground:
	var rect := ColorRect.new()
	rect.material = base_material
	var neb := NebulaBackground.new()
	neb.nebula_seed = seed_value
	neb.add_child(rect)
	return neb

func _nebula_material(neb: NebulaBackground) -> ShaderMaterial:
	for child in neb.get_children():
		if child is ColorRect:
			return (child as ColorRect).material as ShaderMaterial
	return null

func _same_look(m1: ShaderMaterial, m2: ShaderMaterial) -> bool:
	if m1 == null or m2 == null:
		return false
	var c1: Color = m1.get_shader_parameter(&"nebula_color")
	var c2: Color = m2.get_shader_parameter(&"nebula_color")
	var d1: Vector2 = m1.get_shader_parameter(&"scroll_direction")
	var d2: Vector2 = m2.get_shader_parameter(&"scroll_direction")
	var n1: int = (m1.get_shader_parameter(&"noise_texture") as NoiseTexture2D).noise.seed
	var n2: int = (m2.get_shader_parameter(&"noise_texture") as NoiseTexture2D).noise.seed
	return c1.is_equal_approx(c2) and d1.is_equal_approx(d2) and n1 == n2
