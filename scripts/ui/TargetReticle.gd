extends Control
class_name TargetReticle

# Screen-space highlight for the enemy the player is currently locked onto.
# Draws animated corner brackets (plus a marker diamond) around the target and
# shows a compact readout panel beside it: ship name, class, hull, shield and
# the live distance to the player ship.

const BRACKET_COLOR: Color = Color(1.0, 0.16, 0.16, 0.95)
const DIAMOND_COLOR: Color = Color(1.0, 0.16, 0.16, 0.95)
const BRACKET_LENGTH: float = 16.0
const BRACKET_WIDTH: float = 2.0
const DIAMOND_RADIUS: float = 8.0
const DIAMOND_GAP: float = 18.0

# Bracket half-size in screen pixels, clamped so the box stays readable across
# the full zoom range.
const BASE_HALF_SIZE: float = 36.0
const MIN_HALF_SIZE: float = 24.0
const MAX_HALF_SIZE: float = 120.0

# World units per kilometre used for the distance readout.
const UNITS_PER_KM: float = 1000.0

var target: Node2D = null
var player_ship: Ship = null

var _info_panel: PanelContainer
var _name_label: Label
var _class_label: Label
var _hull_bar: ProgressBar
var _hull_label: Label
var _shield_bar: ProgressBar
var _shield_label: Label
var _distance_label: Label

var _half_size: float = BASE_HALF_SIZE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_info_panel()

func _build_info_panel() -> void:
	_info_panel = PanelContainer.new()
	_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info_panel)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(150, 0)
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.add_child(vbox)

	_name_label = _make_label(BRACKET_COLOR)
	vbox.add_child(_name_label)

	_class_label = _make_label(Color(0.85, 0.85, 0.9))
	vbox.add_child(_class_label)

	_hull_label = _make_label(Color(0.6, 0.95, 0.65))
	vbox.add_child(_hull_label)
	_hull_bar = _make_bar(Color(0.2, 0.9, 0.3))
	vbox.add_child(_hull_bar)

	_shield_label = _make_label(Color(0.55, 0.8, 1.0))
	vbox.add_child(_shield_label)
	_shield_bar = _make_bar(Color(0.2, 0.6, 1.0))
	vbox.add_child(_shield_bar)

	_distance_label = _make_label(Color(0.95, 0.95, 0.95))
	vbox.add_child(_distance_label)

func _make_label(color: Color) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 13)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _make_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(140, 8)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _process(_delta: float) -> void:
	if not target or not is_instance_valid(target):
		visible = false
		return

	visible = true
	# Follow the target in screen space; (0,0) in this Control is the target.
	global_position = target.get_global_transform_with_canvas().origin
	_half_size = _compute_half_size()
	_update_readout()
	queue_redraw()

func _compute_half_size() -> float:
	var zoom: float = 1.0
	var cam := get_viewport().get_camera_2d()
	if cam:
		zoom = cam.zoom.x
	return clampf(BASE_HALF_SIZE * zoom, MIN_HALF_SIZE, MAX_HALF_SIZE)

func _update_readout() -> void:
	var has_class: bool = false
	if target is Ship and target.ship_data:
		_name_label.text = str(target.ship_data.name)
		_class_label.text = "Class: %s" % str(target.ship_data.ship_class)
		has_class = true
		_set_bar(_hull_bar, _hull_label, "Hull", target.current_hull, target.max_hull)
		_set_bar(_shield_bar, _shield_label, "Shield", target.current_shield, target.max_shield)
	elif target is Homebase:
		_name_label.text = "%s Homebase" % (str(target.faction_data.name) if target.faction_data else "Enemy")
		_set_bar(_hull_bar, _hull_label, "Hull", target.current_hull, target.max_hull)
		var shield_value: float = 1.0 if target.is_shield_active else 0.0
		_set_bar(_shield_bar, _shield_label, "Shield", shield_value, 1.0)
		_shield_label.text = "Shield: %s" % ("UP" if target.is_shield_active else "DOWN")
	else:
		_name_label.text = str(target.name)
		_hull_bar.visible = false
		_hull_label.visible = false
		_shield_bar.visible = false
		_shield_label.visible = false

	_class_label.visible = has_class
	_distance_label.text = _format_distance()

	# Park the readout panel just to the right of the bracket box.
	_info_panel.position = Vector2(_half_size + 14.0, -_half_size)

func _set_bar(bar: ProgressBar, label: Label, title: String, value: float, max_value: float) -> void:
	bar.visible = true
	label.visible = true
	bar.max_value = maxf(1.0, max_value)
	bar.value = clampf(value, 0.0, bar.max_value)
	label.text = "%s: %d / %d" % [title, int(roundf(value)), int(roundf(max_value))]

func _format_distance() -> String:
	if not player_ship or not is_instance_valid(player_ship):
		return ""
	var dist: float = player_ship.global_position.distance_to(target.global_position)
	return "%.2f KM" % (dist / UNITS_PER_KM)

func _draw() -> void:
	if not target or not is_instance_valid(target):
		return

	var h: float = _half_size
	var l: float = minf(BRACKET_LENGTH, h)

	# Four L-shaped corner brackets framing the target.
	var corners := [
		Vector2(-h, -h), # top-left
		Vector2(h, -h),  # top-right
		Vector2(h, h),   # bottom-right
		Vector2(-h, h),  # bottom-left
	]
	for i in range(corners.size()):
		var corner: Vector2 = corners[i]
		var horizontal_sign: float = -1.0 if corner.x > 0.0 else 1.0
		var vertical_sign: float = -1.0 if corner.y > 0.0 else 1.0
		draw_line(corner, corner + Vector2(l * horizontal_sign, 0.0), BRACKET_COLOR, BRACKET_WIDTH, true)
		draw_line(corner, corner + Vector2(0.0, l * vertical_sign), BRACKET_COLOR, BRACKET_WIDTH, true)

	# Marker diamond hovering above the box.
	var center := Vector2(0.0, -h - DIAMOND_GAP)
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -DIAMOND_RADIUS),
		center + Vector2(DIAMOND_RADIUS, 0.0),
		center + Vector2(0.0, DIAMOND_RADIUS),
		center + Vector2(-DIAMOND_RADIUS, 0.0),
		center + Vector2(0.0, -DIAMOND_RADIUS),
	])
	draw_polyline(diamond, DIAMOND_COLOR, BRACKET_WIDTH, true)
