extends Node2D
class_name ShipRangeIndicator

# World-space angle / range indicator drawn around the player ship.
# Renders a semi-circular arc of glowing dots that visualises the ship's
# shield coverage angle at its targeting range. Added as a child of the ship
# so the arc automatically tracks the hull's facing direction.

@export var dot_color: Color = Color(0.30, 0.80, 1.0, 0.9)
@export var dot_radius: float = 1.6
@export var dot_spacing: float = 18.0

# Longer radial "bar" marks placed at the cardinal clock positions
# (12 o'clock = forward, 3 o'clock = right, 9 o'clock = left).
@export var mark_color: Color = Color(0.45, 0.90, 1.0, 1.0)
@export var mark_length: float = 12.0
@export var mark_width: float = 1.5

var _ship: Ship = null

func _ready() -> void:
	# Draw behind the ship sprite so the hull stays readable.
	z_index = -1

func setup(ship: Ship) -> void:
	_ship = ship
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not _ship or not is_instance_valid(_ship) or not _ship.ship_data:
		return
	if _ship.is_dead:
		return

	var radius: float = maxf(40.0, _ship.ship_data.target_lock_range)
	var span_deg: float = clampf(_ship.ship_data.shield_angle, 30.0, 360.0)
	var span: float = deg_to_rad(span_deg)

	# Space dots evenly along the arc; longer arcs get proportionally more dots.
	var arc_length: float = radius * span
	var count: int = maxi(2, int(arc_length / dot_spacing))
	var start_angle: float = -span * 0.5

	for i in range(count + 1):
		var t: float = float(i) / float(count)
		var angle: float = start_angle + span * t
		var pos: Vector2 = Vector2.from_angle(angle) * radius
		# Soften the dots toward the open ends of the arc.
		var edge_fade: float = sin(t * PI)
		var col: Color = dot_color
		col.a *= lerpf(0.25, 1.0, edge_fade)
		draw_circle(pos, dot_radius, col)

	# Longer radial bar marks at the 12, 3 and 9 o'clock positions. These are
	# measured relative to the ship's facing (12 o'clock = forward), so they
	# only appear where they fall inside the visible coverage arc.
	var half_span: float = span * 0.5
	for mark_angle in [0.0, PI * 0.5, -PI * 0.5]:
		if absf(mark_angle) > half_span + 0.001:
			continue
		var dir: Vector2 = Vector2.from_angle(mark_angle)
		var inner: Vector2 = dir * (radius - mark_length * 0.5)
		var outer: Vector2 = dir * (radius + mark_length * 0.5)
		draw_line(inner, outer, mark_color, mark_width, true)
