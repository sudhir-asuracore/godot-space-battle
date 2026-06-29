extends Node2D
class_name SolarSystem

class OrbitData:
	var node: Planet
	var sprite: Sprite2D
	var radius: float
	var angle: float
	var speed: float
	var spin_speed: float

# Array to hold planet data dictionaries for orbital animation
var _planets: Array[OrbitData] = []

const SUN_SCENE = preload("res://scenes/solar_system/SunCorona.tscn")
const PLANET_SCENE = preload("res://scenes/solar_system/Planet.tscn")
const FIRST_PLANET_ORBIT_RADIUS := 2800.0
const PLANET_ORBIT_SPACING_MIN := 2600.0
const PLANET_ORBIT_SPACING_VARIANCE := 1200.0

# Planet-count configuration. The system always holds between MIN and MAX
# planets; the exact amount scales with the number of players. This formula is
# intentionally simple for now and will be expanded in the future.
const MIN_PLANETS := 6
const MAX_PLANETS := 12
const PLANETS_PER_PLAYER := 3

# How far (toward the sun) the player ship spawns from its homebase planet.
const PLAYER_SPAWN_OFFSET := 700.0

# Number of players in the match. Drives the planet count. Defaults to a 1v1
# setup but can be overridden before the node enters the tree.
@export var player_count: int = 2

# Homebase planets sit on the two ends of the system (the 2nd and the
# last-but-2nd planet). Which faction owns which end is decided randomly.
var player_homebase_planet: Planet = null
var enemy_homebase_planet: Planet = null
var player_homebase_position: Vector2 = Vector2.DOWN * 3000.0
var enemy_homebase_position: Vector2 = Vector2.UP * 3000.0
var player_spawn_position: Vector2 = Vector2(0, 500)

func _ready() -> void:
	# 1. Instance the Sun
	var sun_instance: Node2D = SUN_SCENE.instantiate() as Node2D
	sun_instance.name = "Sun"
	sun_instance.scale = Vector2(2, 2)
	add_child(sun_instance)
	
	# 2. Number of planets scales with the player count, clamped to [6, 12].
	var num_planets: int = clampi(player_count * PLANETS_PER_PLAYER, MIN_PLANETS, MAX_PLANETS)
	
	# 3. Pick the two homebase ends: the 2nd planet and the last-but-2nd planet.
	var inner_end_index: int = 1
	var outer_end_index: int = num_planets - 2
	# Randomly allot the player and enemy to either end.
	var player_uses_inner_end: bool = randi() % 2 == 0
	var player_end_index: int = inner_end_index if player_uses_inner_end else outer_end_index
	var enemy_end_index: int = outer_end_index if player_uses_inner_end else inner_end_index
	
	# Generate unique planet textures
	var planet_textures: Array[String] = []
	for i in range(10):
		planet_textures.append("res://assets/kenney_planets/Planets/planet0%d.png" % i)
	planet_textures.shuffle()
	
	# Per-planet properties are generated from the PRD planet-type table (11.5)
	# via PlanetData.generate. A dedicated RNG keeps planet generation isolated
	# from the orbit randf() sequence so existing layout tests stay stable.
	var planet_rng := RandomNumberGenerator.new()
	planet_rng.randomize()

	var current_radius: float = FIRST_PLANET_ORBIT_RADIUS
	for i in range(num_planets):
		if i > 0:
			current_radius += PLANET_ORBIT_SPACING_MIN + randf() * PLANET_ORBIT_SPACING_VARIANCE
		
		var texture_path: String = planet_textures[i % planet_textures.size()]
		
		var is_homebase_end: bool = i == inner_end_index or i == outer_end_index
		
		# Instantiate Planet
		var planet_instance: Planet = PLANET_SCENE.instantiate() as Planet
		planet_instance.name = "Planet_%d" % (i + 1)
		# Homebase-end worlds always host a hangar (the fleet must be able to
		# (re)deploy from home); every other world gets a random PRD type.
		if is_homebase_end:
			planet_instance.planet_data = PlanetData.build_type(PlanetData.PlanetType.SHIPYARD, planet_rng)
		else:
			planet_instance.planet_data = PlanetData.generate(planet_rng)
		add_child(planet_instance)
		
		var sprite: Sprite2D = planet_instance.get_node("Sprite2D")
		sprite.texture = load(texture_path)
		
		# Random size
		var base_scale: float = randf_range(0.2, 0.5)
		sprite.scale = Vector2(base_scale, base_scale)
		planet_instance.get_node("CollisionShape2D").shape.radius = 250.0 * base_scale
		
		# Orbital stats
		var orbit_data: OrbitData = OrbitData.new()
		orbit_data.node = planet_instance
		orbit_data.sprite = sprite
		orbit_data.radius = current_radius
		# Homebase planets stay anchored on opposite ends so their bases never
		# drift; all other planets orbit normally.
		if is_homebase_end:
			orbit_data.angle = PI * 0.5 if i == inner_end_index else -PI * 0.5
			orbit_data.speed = 0.0
		else:
			orbit_data.angle = randf() * TAU
			orbit_data.speed = (0.005 + randf() * 0.007) * (1500.0 / current_radius)
		orbit_data.spin_speed = (randf() - 0.5) * 0.22
		
		# Initial position
		planet_instance.position = Vector2(cos(orbit_data.angle), sin(orbit_data.angle)) * orbit_data.radius
		_planets.append(orbit_data)
		
		# Record homebase planets / positions.
		if i == player_end_index:
			player_homebase_planet = planet_instance
			player_homebase_position = planet_instance.position
		elif i == enemy_end_index:
			enemy_homebase_planet = planet_instance
			enemy_homebase_position = planet_instance.position
	
	# Player ship spawns near its homebase garage, nudged toward the sun.
	var to_sun: Vector2 = (Vector2.ZERO - player_homebase_position)
	if to_sun.length() > 0.001:
		player_spawn_position = player_homebase_position + to_sun.normalized() * PLAYER_SPAWN_OFFSET
	else:
		player_spawn_position = player_homebase_position
	
	queue_redraw()

func _process(delta: float) -> void:
	for orbit_data: OrbitData in _planets:
		if orbit_data.speed != 0.0:
			orbit_data.angle += orbit_data.speed * delta
			orbit_data.node.position = Vector2(cos(orbit_data.angle), sin(orbit_data.angle)) * orbit_data.radius
		orbit_data.sprite.rotation += orbit_data.spin_speed * delta

func _draw() -> void:
	for orbit_data: OrbitData in _planets:
		draw_arc(Vector2.ZERO, orbit_data.radius, 0, TAU, 360, Color(1, 1, 1, 0.12), 2.5, true)
