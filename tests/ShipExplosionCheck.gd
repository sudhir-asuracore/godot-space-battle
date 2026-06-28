extends SceneTree

# Verifies the ship destruction explosion: the scene loads, plays for every
# ShipData.ShipSize, scales by size, configures its particle/audio children and
# frees itself once finished. Run headless with:
#   godot --headless --script res://tests/ShipExplosionCheck.gd

const EXPLOSION_SCENE := preload("res://scenes/common/effects/ShipExplosion.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	# Larger ship sizes must produce a larger overall explosion scale.
	var last_scale := -1.0
	for size in [ShipData.ShipSize.SMALL, ShipData.ShipSize.MEDIUM, ShipData.ShipSize.LARGE, ShipData.ShipSize.CAPITAL]:
		var explosion: ShipExplosion = EXPLOSION_SCENE.instantiate()
		if explosion == null:
			failures.append("Explosion scene failed to instantiate for size %d" % size)
			continue
		root.add_child(explosion)
		explosion.play(size)
		await process_frame

		var current_scale: float = explosion.scale.x
		if current_scale <= last_scale:
			failures.append("Size %d scale %.2f did not grow over previous %.2f" % [size, current_scale, last_scale])
		last_scale = current_scale

		# Particle emitters must be configured and emitting.
		var fire := explosion.get_node("Fire") as GPUParticles2D
		var smoke := explosion.get_node("Smoke") as GPUParticles2D
		var audio := explosion.get_node("Audio") as AudioStreamPlayer2D
		if fire == null or not fire.emitting or fire.process_material == null:
			failures.append("Size %d fire particles not configured/emitting" % size)
		if smoke == null or not smoke.emitting or smoke.process_material == null:
			failures.append("Size %d smoke particles not configured/emitting" % size)
		if audio == null or not audio.playing:
			failures.append("Size %d explosion audio not playing" % size)

		explosion.queue_free()
		await process_frame

	# An out-of-range size must fall back to the medium profile instead of crashing.
	var fallback: ShipExplosion = EXPLOSION_SCENE.instantiate()
	root.add_child(fallback)
	fallback.play(999)
	await process_frame
	if not is_equal_approx(fallback.scale.x, 1.0):
		failures.append("Out-of-range size did not fall back to medium scale (got %.2f)" % fallback.scale.x)
	fallback.queue_free()
	await process_frame

	if failures.is_empty():
		print("[DEBUG_LOG] ShipExplosionCheck PASSED")
		quit(0)
	else:
		for failure in failures:
			print("[DEBUG_LOG] FAIL: %s" % failure)
		quit(1)
