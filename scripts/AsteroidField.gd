extends Node2D
class_name AsteroidField

# Purely decorative, seed-driven asteroid backdrop that adds depth to the map.
# It is intentionally NOT a gameplay dependency: no physics bodies and no
# per-asteroid scene nodes are created. A small, fixed set of asteroid textures
# is loaded once and shared across every asteroid; each asteroid is just a
# light-weight struct (position, texture index, scale, rotation, drift) drawn in
# a single batched `_draw()` pass (see docs/conventions.md: procedural
# generation must be seed-driven and reproducible).

# Shared asteroid textures. These are loaded a single time and reused for every
# asteroid, so adding more on-screen rocks costs only a handful of bytes each.
const ASTEROID_TEXTURES: Array[Texture2D] = [
	preload("res://assets/env/asteroids/1.png"),
	preload("res://assets/env/asteroids/2.png"),
	preload("res://assets/env/asteroids/3.png"),
	preload("res://assets/env/asteroids/4.png"),
	preload("res://assets/env/asteroids/5.png"),
	preload("res://assets/env/asteroids/6.png"),
]

# Base seed for the field. 0 means "pick a fresh random seed at runtime".
@export var asteroid_seed: int = 0
# How many asteroids to scatter. Kept modest on purpose — these are background filler.
@export var asteroid_count: int = 140
# Asteroids are scattered inside this radius around the field origin.
@export var field_radius: float = 9000.0
# Empty disc kept clear around the origin so spawn areas stay readable.
@export var clear_radius: float = 900.0
# Per-asteroid target size range (longest texture side, in pixels).
@export var min_size: float = 24.0
@export var max_size: float = 180.0
# Subtle drift/spin so the field feels alive without stealing focus. 0 disables motion.
@export var drift_speed: float = 5.0
@export var max_spin: float = 0.18
# The procedural tint is sampled between these two rocky anchors so the shared
# textures don't look repetitive when reused.
@export var tint_a: Color = Color(0.55, 0.55, 0.62, 1.0)
@export var tint_b: Color = Color(0.85, 0.8, 0.72, 1.0)
# Overall opacity — asteroids stay dim so they read as far-away depth.
@export var field_alpha: float = 0.65

class Asteroid:
	var offset: Vector2
	var texture_index: int
	var scale: float
	var color: Color
	var rotation: float
	var spin: float
	var drift: Vector2

var _asteroids: Array[Asteroid] = []
var _active_seed: int = 0
var _animated: bool = false

func _ready() -> void:
	generate(asteroid_seed)

# Builds the field from a seed. The same seed always yields the same asteroids.
func generate(p_seed: int) -> void:
	_active_seed = p_seed if p_seed != 0 else _pick_random_seed()
	var rng := RandomNumberGenerator.new()
	rng.seed = _active_seed

	_asteroids.clear()
	for i in range(asteroid_count):
		_asteroids.append(_make_asteroid(rng))

	# Only pay the per-frame cost when something actually moves.
	_animated = drift_speed > 0.0 or max_spin > 0.0
	set_process(_animated)
	queue_redraw()

func get_active_seed() -> int:
	return _active_seed

func _make_asteroid(rng: RandomNumberGenerator) -> Asteroid:
	var asteroid := Asteroid.new()

	# Uniform scatter across the disc, leaving the central clearing empty.
	var angle: float = rng.randf() * TAU
	var radius: float = sqrt(rng.randf()) * field_radius
	radius = maxf(radius, clear_radius)
	asteroid.offset = Vector2(cos(angle), sin(angle)) * radius

	asteroid.texture_index = rng.randi_range(0, ASTEROID_TEXTURES.size() - 1)

	# Convert the desired on-screen size into a texture scale factor.
	var target_size: float = rng.randf_range(min_size, max_size)
	var texture: Texture2D = ASTEROID_TEXTURES[asteroid.texture_index]
	var longest_side: float = maxf(texture.get_width(), texture.get_height())
	asteroid.scale = target_size / longest_side if longest_side > 0.0 else 1.0

	asteroid.color = tint_a.lerp(tint_b, rng.randf())
	asteroid.color.a = field_alpha
	asteroid.rotation = rng.randf() * TAU
	asteroid.spin = rng.randf_range(-max_spin, max_spin)

	var drift_angle: float = rng.randf() * TAU
	asteroid.drift = Vector2(cos(drift_angle), sin(drift_angle)) * rng.randf_range(0.0, drift_speed)
	return asteroid

func _process(delta: float) -> void:
	for asteroid: Asteroid in _asteroids:
		asteroid.rotation += asteroid.spin * delta
		asteroid.offset += asteroid.drift * delta
	queue_redraw()

func _draw() -> void:
	for asteroid: Asteroid in _asteroids:
		var texture: Texture2D = ASTEROID_TEXTURES[asteroid.texture_index]
		var size: Vector2 = texture.get_size()
		draw_set_transform(asteroid.offset, asteroid.rotation, Vector2.ONE * asteroid.scale)
		# Draw centered on the asteroid's offset so rotation pivots about its middle.
		draw_texture_rect(texture, Rect2(-size * 0.5, size), false, asteroid.color)
	# Restore the default transform so nothing else inherits ours.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _pick_random_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Keep it positive and non-zero so it never collides with the "auto" sentinel.
	return (rng.randi() & 0x7fffffff) | 1
