extends SceneTree

# Verifies the ship-death explosion sprite: the scene loads, plays its "fire"
# animation once (non-looping), plays the embedded explosion audio and frees
# itself once both the animation and the audio have finished. Run headless with:
#   godot --headless --script res://tests/ExplosionSpriteCheck.gd

const EXPLOSION_SCENE := preload("res://scenes/common/effects/ExplosionSprite.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var explosion: ExplosionSprite = EXPLOSION_SCENE.instantiate()
	if explosion == null:
		print("[DEBUG_LOG] FAIL: ExplosionSprite scene failed to instantiate")
		quit(1)
		return

	root.add_child(explosion)
	await process_frame

	# Animation must be playing the "fire" clip as a single (non-looping) pass.
	if not explosion.is_playing():
		failures.append("ExplosionSprite is not playing its animation")
	if explosion.animation != ExplosionSprite.ANIMATION_NAME:
		failures.append("ExplosionSprite is not playing the 'fire' animation")
	if explosion.sprite_frames and explosion.sprite_frames.get_animation_loop(ExplosionSprite.ANIMATION_NAME):
		failures.append("ExplosionSprite 'fire' animation should not loop")

	# The embedded explosion audio must be playing.
	var audio := explosion.get_node("AudioStreamPlayer2D") as AudioStreamPlayer2D
	if audio == null or not audio.playing:
		failures.append("ExplosionSprite explosion audio not playing")

	# Once both the animation and audio finish, the node must free itself.
	explosion._on_animation_finished()
	explosion._on_audio_finished()
	await process_frame
	if is_instance_valid(explosion):
		failures.append("ExplosionSprite did not free itself after the effect finished")

	if failures.is_empty():
		print("[DEBUG_LOG] ExplosionSpriteCheck PASSED")
		quit(0)
	else:
		for failure in failures:
			print("[DEBUG_LOG] FAIL: %s" % failure)
		quit(1)
