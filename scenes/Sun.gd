extends Node2D
class_name Sun

@onready var _light: PointLight2D = $PointLight2D as PointLight2D

func _process(_delta: float) -> void:
	# Pulse the star's light energy dynamically to simulate solar activity
	if _light:
		_light.energy = 2.3 + sin(Time.get_ticks_msec() * 0.003) * 0.3
