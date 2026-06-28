extends AnimatedSprite2D
class_name ExplosionSprite

## One-shot explosion effect.
##
## Plays the "fire" animation a single time together with the embedded
## explosion audio, then frees itself once both the animation and the audio
## have finished so nothing is left lingering in the scene tree.

const ANIMATION_NAME := &"fire"

@onready var _audio: AudioStreamPlayer2D = $AudioStreamPlayer2D

var _animation_done: bool = false
var _audio_done: bool = false

func _ready() -> void:
	# The SpriteFrames resource loops by default; force a single playthrough so
	# the animation_finished signal fires and we can clean up.
	if sprite_frames and sprite_frames.has_animation(ANIMATION_NAME):
		sprite_frames.set_animation_loop(ANIMATION_NAME, false)

	animation_finished.connect(_on_animation_finished)

	if _audio and _audio.stream:
		_audio.finished.connect(_on_audio_finished)
	else:
		_audio_done = true

	frame = 0
	play(ANIMATION_NAME)

func _on_animation_finished() -> void:
	_animation_done = true
	_try_cleanup()

func _on_audio_finished() -> void:
	_audio_done = true
	_try_cleanup()

func _try_cleanup() -> void:
	if _animation_done and _audio_done:
		queue_free()
