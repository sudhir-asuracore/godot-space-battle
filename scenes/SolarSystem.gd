extends Node2D
class_name SolarSystem

# Array to hold planet data dictionaries
var _planets: Array = []

func _ready() -> void:
	# 1. Instance the Sun scene at center (0,0) (updated path to scenes/Sun.tscn)
	var sun_scene: PackedScene = load("res://scenes/Sun.tscn") as PackedScene
	var sun_instance: Node2D = sun_scene.instantiate() as Node2D
	sun_instance.name = "Sun"
	add_child(sun_instance)
	
	# 2. Programmatically determine the number of planets (between 6 and 10)
	var num_planets: int = randi_range(6, 10)
	
	# Generate unique planet texture paths
	var planet_textures: Array[String] = []
	for i in range(10):
		planet_textures.append("res://assets/kenney_planets/Planets/planet0%d.png" % i)
	
	# Shuffle the texture list to get random distinct textures
	planet_textures.shuffle()
	
	# Programmatically generate large orbital distances and dimensions
	# We start at 1200px (outside the sun's core and corona glow)
	var current_radius: float = 1200.0
	for i in range(num_planets):
		# Spaced widely (1500px to 2500px gap) so only 1 or 2 planets are visible at a time
		# at normal zoom levels, creating a true sense of space travel
		if i > 0:
			var gap: float = 1500.0 + randf() * 1000.0
			current_radius += gap
		
		# Select texture (wrap index just in case)
		var texture_path: String = planet_textures[i % planet_textures.size()]
		
		# Create planet container node
		var planet_node: Node2D = Node2D.new()
		planet_node.name = "Planet_%d" % (i + 1)
		add_child(planet_node)
		
		# Create planet sprite
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = load(texture_path)
		
		# Calculate dynamic planet size with high variance (rocky vs gas giants)
		# Outer orbits have a higher probability of spawning gas giants
		var gas_giant_prob: float = 0.15 + (float(i) / num_planets) * 0.7
		var is_gas_giant: bool = randf() < gas_giant_prob
		
		var base_scale: float = 0.0
		if is_gas_giant:
			# Large gas giant (diameter ~486px to ~1088px)
			base_scale = randf_range(0.38, 0.85)
		else:
			# Small rocky planet (diameter ~76px to ~192px)
			base_scale = randf_range(0.06, 0.15)
			
		sprite.scale = Vector2(base_scale, base_scale)
		planet_node.add_child(sprite)
		
		# Create circular LightOccluder2D so the planet casts realistic shadows away from the Sun
		# Kenney planet sphere occupies roughly ~500px radius of the 1280px texture canvas
		var occluder_radius: float = 500.0 * base_scale
		var occluder: LightOccluder2D = create_planet_occluder(occluder_radius)
		planet_node.add_child(occluder)
		
		# Define planet variables (Keplerian speed: outer planets move slower, slowed down for cinematic feel)
		var planet_data: Dictionary = {
			"node": planet_node,
			"sprite": sprite,
			"radius": current_radius,
			"angle": randf() * TAU,
			"speed": (0.005 + randf() * 0.007) * (800.0 / current_radius),
			"spin_speed": (randf() - 0.5) * 0.12 # Gentle axial rotation
		}
		
		# Place at starting orbit position
		planet_node.position = Vector2(cos(planet_data.angle), sin(planet_data.angle)) * current_radius
		_planets.append(planet_data)
	
	# Force redraw so paths are drawn immediately
	queue_redraw()

func _process(delta: float) -> void:
	# Update orbits and axial rotations for each planet
	for planet in _planets:
		planet.angle += planet.speed * delta
		planet.node.position = Vector2(cos(planet.angle), sin(planet.angle)) * planet.radius
		planet.sprite.rotation += planet.spin_speed * delta

func _draw() -> void:
	# Draw orbital paths as thin, semi-transparent white rings
	for planet in _planets:
		draw_arc(Vector2.ZERO, planet.radius, 0, TAU, 360, Color(1, 1, 1, 0.12), 2.5, true)

# Helper function to programmatically generate circular LightOccluder2D nodes
func create_planet_occluder(radius: float) -> LightOccluder2D:
	var occluder_node: LightOccluder2D = LightOccluder2D.new()
	var occluder_poly: OccluderPolygon2D = OccluderPolygon2D.new()
	
	# Approximate a circle using a 32-point polygon for larger size accuracy
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = 32
	for i in range(segments):
		var angle: float = (float(i) / segments) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)
		
	occluder_poly.polygon = points
	occluder_node.occluder = occluder_poly
	return occluder_node
