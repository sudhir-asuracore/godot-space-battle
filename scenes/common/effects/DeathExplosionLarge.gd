extends Node2D
class_name DeathExplosionLarge

## Self-contained large death explosion.
##
## Discovers every "flash_N" AnimatedSprite2D child at runtime, plays all of them
## except the last in quick succession (flash_0..flash_(N-1)) and then the final
## flash (the highest-numbered one). The explosion audio is (re)triggered for
## every flash so the blast builds up audibly. The node frees itself once the
## final flash has finished playing.
##
## The sequence does NOT start automatically: the node stays dormant (and hidden)
## until [method play] is called, so it can be embedded inside a ship and only
## triggered when that ship is destroyed.

## Delay between the staggered flashes, in seconds.
@export var flash_gap: float = 0.2

## Explosion volume
@export_range(0, 1.0, 0.05) var volume: float = 1

@onready var _audio: AudioStreamPlayer2D = $AudioStreamPlayer2D

# All flash sprites in ascending "flash_N" order, gathered at runtime.
var _flashes: Array[AnimatedSprite2D] = []

func _ready() -> void:
	_flashes = _collect_flashes()

	# Hide everything until its turn so the scene starts blank.
	for flash in _flashes:
		flash.visible = false
		if flash.sprite_frames:
			flash.sprite_frames.set_animation_loop(flash.animation, false)

## Starts the explosion: makes the node visible and plays the staggered flash
## sequence. Call this when the owning entity (e.g. a ship) is destroyed.
func play() -> void:
	visible = true
	_play_sequence()

## Finds every child named "flash_<number>" and returns them sorted ascending by
## that number, so the sequence is independent of how many flashes exist.
func _collect_flashes() -> Array[AnimatedSprite2D]:
	var flashes: Array[AnimatedSprite2D] = []
	for child in get_children():
		if child is AnimatedSprite2D and (child.name as String).begins_with("flash_"):
			flashes.append(child)
	flashes.sort_custom(func(a, b): return _flash_index(a) < _flash_index(b))
	return flashes

## Extracts the numeric suffix from a "flash_<number>" node name.
func _flash_index(flash: AnimatedSprite2D) -> int:
	return (flash.name as String).get_slice("_", 1).to_int()

## Plays the flashes in order, firing the audio for each, then self-frees.
func _play_sequence() -> void:
	if _flashes.is_empty():
		queue_free()
		return

	# All but the last flash play in quick, staggered succession.
	for i in range(_flashes.size() - 1):
		_trigger_flash(_flashes[i])
		await get_tree().create_timer(flash_gap).timeout

	# The highest-numbered flash is the final blast.
	var final_flash: AnimatedSprite2D = _flashes[-1]
	_trigger_flash(final_flash)
	await final_flash.animation_finished
	queue_free()

## Shows a single flash, restarts its animation and plays the explosion audio.
func _trigger_flash(flash: AnimatedSprite2D) -> void:
	flash.visible = true
	flash.frame = 0
	flash.play()
	if _audio.stream:
		_audio.volume_db = volume
		_audio.play()
