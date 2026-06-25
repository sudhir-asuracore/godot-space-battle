extends Node2D
class_name Sun

@onready var _light: PointLight2D = $PointLight2D as PointLight2D

func _process(_delta: float) -> void:
	# Pulse the star's light energy dynamically to simulate solar activity.
	# Base energy is kept a touch higher because normal-mapped surfaces (e.g. the
	# StrikerLance) receive less apparent light once the light's height is raised
	# for self-shadowing, so we compensate to keep the scene's brightness.
	if _light:
		_light.energy = 2.9 + sin(Time.get_ticks_msec() * 0.003) * 0.3
