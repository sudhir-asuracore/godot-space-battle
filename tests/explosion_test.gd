extends Node2D

# Preload your explosion scene 
# (Make sure this path exactly matches your file)
const EXPLOSION_SCENE = preload("res://scenes/trial/Explosion.tscn") 

func _input(event: InputEvent) -> void:
	# Check if the player left-clicked
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		spawn_explosion(event.position)
		
	# ALTERNATIVE: Press Spacebar to spawn at the center of the screen
	if event.is_action_pressed("ui_accept"):
		var center_of_screen = get_viewport_rect().size / 2
		spawn_explosion(center_of_screen)

func spawn_explosion(spawn_position: Vector2) -> void:
	# Instantiate the explosion
	var explosion = EXPLOSION_SCENE.instantiate()
	
	# Position it
	explosion.global_position = spawn_position
	
	# Add it to this test scene
	add_child(explosion)
	print("Explosion spawned at: ", spawn_position)
