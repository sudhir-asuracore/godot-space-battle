extends Node2D
class_name ShipExplosion

## Self-contained ship destruction explosion.
##
## Spawn this scene at a destroyed ship's position and call [method play] with
## the ship's [enum ShipData.ShipSize]. The fireball, smoke plume, sparks, flash
## and the explosion audio are all scaled by that size class so a tiny fighter
## pops quickly and quietly while a capital ship erupts big, long and loud.
## The node frees itself once the longest-lived effect has finished.

@onready var _fire: GPUParticles2D = $Fire
@onready var _smoke: GPUParticles2D = $Smoke
@onready var _sparks: GPUParticles2D = $Sparks
@onready var _flash: Sprite2D = $Flash
@onready var _audio: AudioStreamPlayer2D = $Audio

# Per-size tuning. One entry per ShipData.ShipSize value.
#   scale         - overall visual scale multiplier for the whole effect.
#   fire_amount   - number of fireball particles.
#   smoke_amount  - number of smoke particles.
#   spark_amount  - number of spark particles.
#   fire_life     - fireball particle lifetime (seconds).
#   smoke_life    - smoke particle lifetime (seconds).
#   flash_time    - duration of the bright initial flash (seconds).
#   volume_db     - explosion audio loudness.
#   pitch         - explosion audio pitch (smaller ships pop higher).
const SIZE_PROFILES: Array[Dictionary] = [
	{ # SMALL
		"scale": 0.6, "fire_amount": 24, "smoke_amount": 16, "spark_amount": 16,
		"fire_life": 0.5, "smoke_life": 1.0, "flash_time": 0.18,
		"volume_db": -6.0, "pitch": 1.25,
	},
	{ # MEDIUM
		"scale": 1.0, "fire_amount": 40, "smoke_amount": 28, "spark_amount": 24,
		"fire_life": 0.7, "smoke_life": 1.6, "flash_time": 0.22,
		"volume_db": -2.0, "pitch": 1.0,
	},
	{ # LARGE
		"scale": 1.6, "fire_amount": 64, "smoke_amount": 44, "spark_amount": 36,
		"fire_life": 0.9, "smoke_life": 2.2, "flash_time": 0.28,
		"volume_db": 1.0, "pitch": 0.85,
	},
	{ # CAPITAL
		"scale": 2.4, "fire_amount": 96, "smoke_amount": 64, "spark_amount": 52,
		"fire_life": 1.2, "smoke_life": 3.0, "flash_time": 0.35,
		"volume_db": 3.0, "pitch": 0.7,
	},
]

const AUDIO_MAX_DISTANCE := 2400.0
const AUDIO_ATTENUATION := 2.0

## Configure the explosion for the given ship size and trigger it.
## [param size] is a value of [enum ShipData.ShipSize]. The node frees itself
## automatically once all effects have completed.
func play(size: int = ShipData.ShipSize.MEDIUM) -> void:
	var profile: Dictionary = _resolve_profile(size)

	# Scale the whole effect by the ship size.
	scale = Vector2.ONE * float(profile["scale"])

	_setup_fire(profile)
	_setup_smoke(profile)
	_setup_sparks(profile)
	_setup_flash(profile)
	_setup_audio(profile)

	# Emit the one-shot bursts.
	_fire.restart()
	_smoke.restart()
	_sparks.restart()
	_fire.emitting = true
	_smoke.emitting = true
	_sparks.emitting = true

	# Keep the node alive until the longest effect has fully faded.
	var lifetime: float = maxf(float(profile["fire_life"]), float(profile["smoke_life"]))
	var stream_length: float = _audio.stream.get_length() if _audio.stream else 0.0
	var total: float = maxf(lifetime, stream_length) + 0.25
	await get_tree().create_timer(total).timeout
	queue_free()

func _resolve_profile(size: int) -> Dictionary:
	if size < 0 or size >= SIZE_PROFILES.size():
		size = ShipData.ShipSize.MEDIUM
	return SIZE_PROFILES[size]

func _setup_fire(profile: Dictionary) -> void:
	_fire.amount = int(profile["fire_amount"])
	_fire.lifetime = float(profile["fire_life"])
	_fire.one_shot = true
	_fire.explosiveness = 0.95

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 10.0
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 70.0
	# Push particles outward from the blast centre for an omnidirectional ball.
	mat.radial_accel_min = 150.0
	mat.radial_accel_max = 320.0
	mat.damping_min = 80.0
	mat.damping_max = 140.0
	mat.scale_min = 0.4
	mat.scale_max = 0.9
	mat.color_ramp = _make_gradient([
		Color(1.0, 0.95, 0.7, 1.0),
		Color(1.0, 0.6, 0.15, 1.0),
		Color(0.8, 0.2, 0.05, 0.8),
		Color(0.3, 0.05, 0.02, 0.0),
	])
	_fire.process_material = mat

func _setup_smoke(profile: Dictionary) -> void:
	_smoke.amount = int(profile["smoke_amount"])
	_smoke.lifetime = float(profile["smoke_life"])
	_smoke.one_shot = true
	_smoke.explosiveness = 0.8

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 14.0
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 35.0
	mat.radial_accel_min = 40.0
	mat.radial_accel_max = 110.0
	mat.damping_min = 30.0
	mat.damping_max = 70.0
	mat.scale_min = 1.2
	mat.scale_max = 2.4
	mat.angle_min = -180.0
	mat.angle_max = 180.0
	mat.color_ramp = _make_gradient([
		Color(0.35, 0.32, 0.30, 0.0),
		Color(0.28, 0.26, 0.25, 0.7),
		Color(0.18, 0.17, 0.16, 0.5),
		Color(0.1, 0.1, 0.1, 0.0),
	])
	_smoke.process_material = mat

func _setup_sparks(profile: Dictionary) -> void:
	_sparks.amount = int(profile["spark_amount"])
	_sparks.lifetime = maxf(0.3, float(profile["fire_life"]) * 0.8)
	_sparks.one_shot = true
	_sparks.explosiveness = 1.0

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 6.0
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 180.0
	mat.initial_velocity_max = 420.0
	mat.radial_accel_min = 60.0
	mat.radial_accel_max = 160.0
	mat.damping_min = 120.0
	mat.damping_max = 240.0
	mat.scale_min = 0.15
	mat.scale_max = 0.4
	mat.color_ramp = _make_gradient([
		Color(1.0, 0.95, 0.75, 1.0),
		Color(1.0, 0.7, 0.3, 1.0),
		Color(1.0, 0.5, 0.1, 0.0),
	])
	_sparks.process_material = mat

func _setup_flash(profile: Dictionary) -> void:
	# A quick bright additive pop right at the blast centre.
	_flash.modulate = Color(1.0, 0.85, 0.55, 1.0)
	_flash.scale = Vector2.ONE * 0.4
	var flash_time: float = float(profile["flash_time"])
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_flash, "scale", Vector2.ONE * 2.2, flash_time)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_flash, "modulate:a", 0.0, flash_time)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

func _setup_audio(profile: Dictionary) -> void:
	_audio.volume_db = float(profile["volume_db"])
	_audio.pitch_scale = float(profile["pitch"])
	_audio.max_distance = AUDIO_MAX_DISTANCE
	_audio.attenuation = AUDIO_ATTENUATION
	_audio.play()

func _make_gradient(colors: Array) -> GradientTexture1D:
	var count: int = colors.size()
	var offsets := PackedFloat32Array()
	var color_values := PackedColorArray()
	for i in range(count):
		var offset: float = 0.0 if count <= 1 else float(i) / float(count - 1)
		offsets.append(offset)
		color_values.append(colors[i])
	var gradient := Gradient.new()
	# Assign both arrays at once to replace Gradient's default black/white points.
	gradient.offsets = offsets
	gradient.colors = color_values
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture
