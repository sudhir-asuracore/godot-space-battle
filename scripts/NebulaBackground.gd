extends ParallaxBg
class_name NebulaBackground

# Procedurally varies the nebula shader so every match shows a different sky,
# while staying fully seed-driven and reproducible (see docs/conventions.md:
# identical seeds must always yield an identical nebula).

# Base seed for this nebula layer. 0 means "pick a fresh random seed at runtime".
@export var nebula_seed: int = 0
# Extra offset so stacked nebula layers sharing a base seed look different.
@export var layer_seed_offset: int = 0
# The procedural tint is sampled between these two palette anchors.
@export var tint_a: Color = Color(0.12, 0.35, 0.75, 0.85)
@export var tint_b: Color = Color(0.1, 0.55, 0.8, 0.85)
# How strongly the cloud density may drift between matches.
@export var density_variation: float = 0.18

var _active_seed: int = 0

func _ready() -> void:
	randomize_nebula(nebula_seed)

# Rebuilds the nebula look from a seed. The same seed always yields the same sky.
func randomize_nebula(p_seed: int) -> void:
	_active_seed = p_seed if p_seed != 0 else _pick_random_seed()
	var rng := RandomNumberGenerator.new()
	rng.seed = _active_seed + layer_seed_offset

	var color_rect: ColorRect = _get_color_rect()
	if not color_rect:
		return
	var base_material: ShaderMaterial = color_rect.material as ShaderMaterial
	if not base_material:
		return

	# Clone the material (and its noise) so the shared on-disk resource is never mutated.
	var mat: ShaderMaterial = base_material.duplicate(true) as ShaderMaterial
	color_rect.material = mat

	var noise_tex: NoiseTexture2D = mat.get_shader_parameter(&"noise_texture") as NoiseTexture2D
	if noise_tex:
		noise_tex = noise_tex.duplicate(true) as NoiseTexture2D
		var noise: FastNoiseLite = noise_tex.noise as FastNoiseLite
		if noise:
			noise = noise.duplicate(true) as FastNoiseLite
			noise.seed = rng.randi()
			noise_tex.noise = noise
		mat.set_shader_parameter(&"noise_texture", noise_tex)

	# Subtle per-match tint between the two palette anchors.
	var tint: Color = tint_a.lerp(tint_b, rng.randf())
	mat.set_shader_parameter(&"nebula_color", tint)

	# Random drift direction so clouds never scroll the same way twice.
	var angle: float = rng.randf() * TAU
	mat.set_shader_parameter(&"scroll_direction", Vector2(cos(angle), sin(angle)))

	# Vary the cloud density slightly around the scene-authored value.
	var base_density: float = 0.4
	var density_param: Variant = mat.get_shader_parameter(&"cloud_density")
	if density_param != null:
		base_density = float(density_param)
	var density: float = clampf(base_density + rng.randf_range(-density_variation, density_variation), 0.0, 1.0)
	mat.set_shader_parameter(&"cloud_density", density)

# The seed actually applied this run (useful for reproducing a sky exactly).
func get_active_seed() -> int:
	return _active_seed

func _pick_random_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Keep it positive and non-zero so it never collides with the "auto" sentinel.
	return (rng.randi() & 0x7fffffff) | 1

func _get_color_rect() -> ColorRect:
	for child in get_children():
		if child is ColorRect:
			return child as ColorRect
	return null
