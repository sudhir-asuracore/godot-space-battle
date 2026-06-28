extends GPUParticles2D

func _ready() -> void:
	# 1. Wait until the end of the current frame so the GPU is ready
	await get_tree().process_frame
	
	# 2. Fire the particles
	emitting = true
	
	# 3. Clean up ONLY when the particles are physically done playing
	finished.connect(_on_particles_finished)

func _on_particles_finished() -> void:
	queue_free()
