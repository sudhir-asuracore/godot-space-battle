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

func _ready() -> void:
	# 1. Instance the Sun
	var sun_instance: Node2D = SUN_SCENE.instantiate() as Node2D
	sun_instance.name = "Sun"
	add_child(sun_instance)
	
	# 2. Number of planets for MVP
	var num_planets: int = randi_range(3, 5)
	
	# Generate unique planet textures
	var planet_textures: Array[String] = []
	for i in range(10):
		planet_textures.append("res://assets/kenney_planets/Planets/planet0%d.png" % i)
	planet_textures.shuffle()
	
	var default_planet_data: PlanetData = load("res://resources/planets/default_planet.tres") as PlanetData

	var current_radius: float = 2000.0
	for i in range(num_planets):
		if i > 0:
			current_radius += 2000.0 + randf() * 1000.0
		
		var texture_path: String = planet_textures[i % planet_textures.size()]
		
		# Instantiate Planet
		var planet_instance: Planet = PLANET_SCENE.instantiate() as Planet
		planet_instance.name = "Planet_%d" % (i + 1)
		planet_instance.planet_data = default_planet_data
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
		orbit_data.angle = randf() * TAU
		orbit_data.speed = (0.005 + randf() * 0.007) * (1500.0 / current_radius)
		orbit_data.spin_speed = (randf() - 0.5) * 0.22
		
		# Initial position
		planet_instance.position = Vector2(cos(orbit_data.angle), sin(orbit_data.angle)) * orbit_data.radius
		_planets.append(orbit_data)
	
	queue_redraw()

func _process(delta: float) -> void:
	for orbit_data: OrbitData in _planets:
		orbit_data.angle += orbit_data.speed * delta
		orbit_data.node.position = Vector2(cos(orbit_data.angle), sin(orbit_data.angle)) * orbit_data.radius
		orbit_data.sprite.rotation += orbit_data.spin_speed * delta

func _draw() -> void:
	for orbit_data: OrbitData in _planets:
		draw_arc(Vector2.ZERO, orbit_data.radius, 0, TAU, 360, Color(1, 1, 1, 0.12), 2.5, true)
