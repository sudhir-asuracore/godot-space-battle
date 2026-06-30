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

# How far the attack-cone grid is rotated away from the overlay's forward
# (mount) direction, in degrees. Lets the grid track the turret's current aim
# while the swing-arc outline stays anchored to the mount-forward direction.
@export var cone_facing_offset_degrees: float = 0.0:
	set(value):
		cone_facing_offset_degrees = value
		queue_redraw()

# The turret's full swing arc. When greater than zero it is rendered as a plain
# outline (no internal grid) so it reads as a boundary rather than coverage.
@export_range(0.0, 360.0, 0.5) var outline_cone_degrees: float = 0.0:
	set(value):
		outline_cone_degrees = clampf(value, 0.0, 360.0)
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
	# Draw beneath the ship sprites so the coverage grid reads as a background
	# layer rather than overlapping the hull. The world background sits lower
	# still (see Main.tscn at z_index -50), so the grid stays above it.
	z_index = -10
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

func set_coverage(max_range: float, min_range: float = 0.0, cone: float = 360.0, outline_cone: float = 0.0, cone_facing_offset: float = 0.0) -> void:
	outer_range = maxf(0.0, max_range)
	inner_range = clampf(min_range, 0.0, outer_range)
	cone_degrees = clampf(cone, 0.0, 360.0)
	outline_cone_degrees = clampf(outline_cone, 0.0, 360.0)
	cone_facing_offset_degrees = cone_facing_offset
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
	var arc_points := maxi(24, int(ceil(max_range / 16.0)))

	# Draw the attack cone as a full grid (range rings + radial lines).
	var cone := clampf(cone_degrees, 0.0, 360.0)
	if cone > 0.0:
		var full_circle := cone >= 359.95
		var facing := deg_to_rad(cone_facing_offset_degrees)
		var start_angle := -PI if full_circle else facing - deg_to_rad(cone) * 0.5
		var end_angle := PI if full_circle else facing + deg_to_rad(cone) * 0.5
		_draw_range_rings(min_range, max_range, start_angle, end_angle, arc_points)
		_draw_angle_grid(min_range, max_range, start_angle, end_angle, full_circle, facing)

	# Draw the turret swing arc as a plain outline, without any internal grid.
	var outline_cone := clampf(outline_cone_degrees, 0.0, 360.0)
	if outline_cone > 0.0:
		_draw_cone_outline(min_range, max_range, outline_cone, arc_points)

func _draw_cone_outline(min_range: float, max_range: float, cone: float, arc_points: int) -> void:
	var outline_color := _alpha_scaled(line_color, 1.0)
	var full_circle := cone >= 359.95
	var start_angle := -PI if full_circle else -deg_to_rad(cone) * 0.5
	var end_angle := PI if full_circle else deg_to_rad(cone) * 0.5

	draw_arc(Vector2.ZERO, max_range, start_angle, end_angle, arc_points, outline_color, line_width, true)
	if min_range > 0.0:
		draw_arc(Vector2.ZERO, min_range, start_angle, end_angle, arc_points, outline_color, line_width, true)

	if not full_circle:
		_draw_radial_line(start_angle, min_range, max_range, outline_color)
		_draw_radial_line(end_angle, min_range, max_range, outline_color)

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

func _draw_angle_grid(min_range: float, max_range: float, start_angle: float, end_angle: float, full_circle: bool, facing: float = 0.0) -> void:
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
	_draw_radial_line(facing, min_range, max_range, major_color)
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