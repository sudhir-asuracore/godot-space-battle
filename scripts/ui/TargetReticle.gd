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
	var canvas = get_canvas_transform()
	var top_left = canvas * target.global_position
	set_position(top_left)
	
	if target is Ship:
		_shield_bar.max_value = target.ship_data.max_shield * (target.faction_data.shield_multiplier if target.faction_data else 1.0)
		_shield_bar.value = target.current_shield
		
		_hull_bar.max_value = target.ship_data.max_hull * (target.faction_data.hull_multiplier if target.faction_data else 1.0)
		_hull_bar.value = target.current_hull
