extends Node2D
class_name WeaponCoverageOverlay

@export var outer_range: float = 500.0:
	set(value):
		outer_range = maxf(0.0, value)
		queue_redraw()

@export var inner_range: float = 0.0:
	set(value):
		inner_range = maxf(0.0, value)
		queue_redraw()

@export_range(0.0, 360.0, 0.5) var cone_degrees: float = 360.0:
	set(value):
		cone_degrees = clampf(value, 0.0, 360.0)
		queue_redraw()

@export var radial_step: float = 120.0:
	set(value):
		radial_step = maxf(20.0, value)
		queue_redraw()

@export var angle_step_degrees: float = 12.0:
	set(value):
		angle_step_degrees = maxf(1.0, value)
		queue_redraw()

@export var line_width: float = 1.6:
	set(value):
		line_width = maxf(0.5, value)
		queue_redraw()

@export var line_color: Color = Color(1.0, 1.0, 1.0, 0.12):
	set(value):
		line_color = value
		queue_redraw()

var _anchor: Node2D = null
var _overlay_visible: bool = true

func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 200
	set_process(true)

func _process(_delta: float) -> void:
	if _anchor and is_instance_valid(_anchor):
		global_position = _anchor.global_position
		global_rotation = _anchor.global_rotation
	visible = _overlay_visible

func follow(anchor: Node2D) -> void:
	_anchor = anchor
	if _anchor and is_instance_valid(_anchor):
		global_position = _anchor.global_position
		global_rotation = _anchor.global_rotation

func set_coverage(max_range: float, min_range: float = 0.0, cone: float = 360.0) -> void:
	outer_range = maxf(0.0, max_range)
	inner_range = clampf(min_range, 0.0, outer_range)
	cone_degrees = clampf(cone, 0.0, 360.0)
	queue_redraw()

func set_overlay_visible(visible_now: bool) -> void:
	if _overlay_visible == visible_now:
		return
	_overlay_visible = visible_now
	visible = _overlay_visible

func set_line_color(value: Color) -> void:
	line_color = value

func _draw() -> void:
	if not _overlay_visible:
		return

	var max_range := maxf(0.0, outer_range)
	if max_range <= 0.0:
		return

	var min_range := clampf(inner_range, 0.0, max_range)
	var cone := clampf(cone_degrees, 0.0, 360.0)
	if cone <= 0.0:
		return

	var full_circle := cone >= 359.95
	var start_angle := -PI if full_circle else -deg_to_rad(cone) * 0.5
	var end_angle := PI if full_circle else deg_to_rad(cone) * 0.5
	var arc_points := maxi(24, int(ceil(max_range / 16.0)))

	_draw_range_rings(min_range, max_range, start_angle, end_angle, arc_points)
	_draw_angle_grid(min_range, max_range, start_angle, end_angle, full_circle)

func _draw_range_rings(min_range: float, max_range: float, start_angle: float, end_angle: float, arc_points: int) -> void:
	var major_color := _alpha_scaled(line_color, 1.0)
	var minor_color := _alpha_scaled(line_color, 0.65)

	if min_range > 0.0:
		draw_arc(Vector2.ZERO, min_range, start_angle, end_angle, arc_points, major_color, line_width, true)

	var ring := radial_step
	while ring < max_range:
		if ring > min_range + 0.001:
			draw_arc(Vector2.ZERO, ring, start_angle, end_angle, arc_points, minor_color, maxf(1.0, line_width * 0.85), true)
		ring += radial_step

	draw_arc(Vector2.ZERO, max_range, start_angle, end_angle, arc_points, major_color, line_width, true)

func _draw_angle_grid(min_range: float, max_range: float, start_angle: float, end_angle: float, full_circle: bool) -> void:
	var radial_color := _alpha_scaled(line_color, 0.75)
	var major_color := _alpha_scaled(line_color, 1.0)
	var angle_step := deg_to_rad(maxf(1.0, angle_step_degrees))

	if full_circle:
		var angle := -PI
		while angle <= PI + 0.0001:
			_draw_radial_line(angle, min_range, max_range, radial_color)
			angle += angle_step
		return

	_draw_radial_line(start_angle, min_range, max_range, major_color)
	_draw_radial_line(0.0, min_range, max_range, major_color)
	_draw_radial_line(end_angle, min_range, max_range, major_color)

	var angle := start_angle + angle_step
	while angle < end_angle - 0.0001:
		_draw_radial_line(angle, min_range, max_range, radial_color)
		angle += angle_step

func _draw_radial_line(angle: float, min_range: float, max_range: float, color: Color) -> void:
	var direction := Vector2.RIGHT.rotated(angle)
	var start := direction * min_range
	var finish := direction * max_range
	draw_line(start, finish, color, line_width, true)

func _alpha_scaled(color: Color, multiplier: float) -> Color:
	var adjusted := color
	adjusted.a = clampf(color.a * multiplier, 0.0, 1.0)
	return adjusted