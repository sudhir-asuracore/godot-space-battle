extends Control
class_name TargetReticle

@onready var _shield_bar: ProgressBar = $ShieldBar
@onready var _hull_bar: ProgressBar = $HullBar

var target: Node2D = null

func _process(_delta: float) -> void:
	if not target or not is_instance_valid(target):
		visible = false
		return
		
	visible = true
	# Follow target in screen space
	global_position = target.get_global_transform_with_canvas().origin
	
	if target is Ship:
		_shield_bar.max_value = target.max_shield
		_shield_bar.value = target.current_shield
		_hull_bar.max_value = target.max_hull
		_hull_bar.value = target.current_hull
		_shield_bar.visible = true
		_hull_bar.visible = true
	elif target is Homebase:
		_shield_bar.max_value = 1.0
		_shield_bar.value = 1.0 if target.is_shield_active else 0.0
		_hull_bar.max_value = target.max_hull
		_hull_bar.value = target.current_hull
		_shield_bar.visible = true 
		_hull_bar.visible = true
	else:
		_shield_bar.visible = false
		_hull_bar.visible = false
