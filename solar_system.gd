extends Node2D

# Array to hold planet data dictionaries
var planets = []

func _ready():
	# 1. Create the Host Star (Sun) at center (0,0)
	var sun_container = Node2D.new()
	sun_container.name = "Sun"
	add_child(sun_container)
	
	# Corona/Glow effect under the sun (base texture is 1024x1024)
	var sun_glow = Sprite2D.new()
	sun_glow.name = "Glow"
	sun_glow.texture = load("res://assets/kenney_planets/Parts/light0.png")
	sun_glow.modulate = Color(1.0, 0.65, 0.15, 0.75) # Glowing orange-yellow
	sun_glow.scale = Vector2(0.35, 0.35)
	sun_container.add_child(sun_glow)
	
	# Star core body (base texture is 1024x1024, scaled to ~150px)
	var sun_body = Sprite2D.new()
	sun_body.name = "Body"
	sun_body.texture = load("res://assets/kenney_planets/Parts/sphere0.png")
	sun_body.modulate = Color(1.0, 0.9, 0.4) # Bright golden sun core
	sun_body.scale = Vector2(0.15, 0.15)
	sun_container.add_child(sun_body)
	
	# 2. Spawn 5 planets (base textures are 1280x1280)
	# Spaced so they fit beautifully within 1280x720 and scrollable bounds
	var orbit_radii = [180.0, 300.0, 450.0, 620.0, 820.0]
	var planet_textures = []
	for i in range(10):
		planet_textures.append("res://assets/kenney_planets/Planets/planet0%d.png" % i)
	
	# Shuffle the texture list to get random distinct textures
	planet_textures.shuffle()
	
	for i in range(5):
		var radius = orbit_radii[i]
		var texture_path = planet_textures[i]
		
		# Create planet container node
		var planet_node = Node2D.new()
		planet_node.name = "Planet_%d" % (i + 1)
		add_child(planet_node)
		
		# Create planet sprite
		var sprite = Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = load(texture_path)
		
		# Calculate random planet size scaled to gameplay size (~30px to ~70px in game)
		var base_scale = 0.025 + (i * 0.005) + randf() * 0.015
		sprite.scale = Vector2(base_scale, base_scale)
		planet_node.add_child(sprite)
		
		# Define planet variables
		var planet_data = {
			"node": planet_node,
			"sprite": sprite,
			"radius": radius,
			"angle": randf() * TAU,
			"speed": (0.05 + randf() * 0.05) * (200.0 / radius), # Closer planets move faster (Keplerian physics)
			"spin_speed": (randf() - 0.5) * 1.5 # Rotation speed on its own axis
		}
		
		# Place at starting orbit position
		planet_node.position = Vector2(cos(planet_data.angle), sin(planet_data.angle)) * radius
		planets.append(planet_data)
	
	# Force redraw so paths are drawn immediately
	queue_redraw()

func _process(delta):
	# Rotate the sun core slowly
	var sun_body = $Sun/Body
	if sun_body:
		sun_body.rotation += 0.04 * delta
		
	var sun_glow = $Sun/Glow
	if sun_glow:
		# Add a subtle breathing/pulsation effect to the solar corona
		var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.002) * 0.06
		sun_glow.scale = Vector2(0.35, 0.35) * pulse

	# Update orbits and axial rotations for each planet
	for planet in planets:
		planet.angle += planet.speed * delta
		planet.node.position = Vector2(cos(planet.angle), sin(planet.angle)) * planet.radius
		planet.sprite.rotation += planet.spin_speed * delta

func _draw():
	# Draw orbital paths as thin, semi-transparent white rings
	for planet in planets:
		draw_arc(Vector2.ZERO, planet.radius, 0, TAU, 180, Color(1, 1, 1, 0.12), 2.0, true)
