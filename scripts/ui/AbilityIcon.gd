extends Control
class_name AbilityIcon

# Lightweight vector icon drawer used by the in-game abilities bar.
# Renders a simple cyan line-art glyph identified by `icon_id` so the HUD
# does not depend on imported texture assets.

@export var icon_id: String = "":
	set(value):
		icon_id = value
		queue_redraw()

@export var color: Color = Color(0.45, 0.85, 1.0):
	set(value):
		color = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	var line_w: float = maxf(2.0, h * 0.09)
	match icon_id:
		"afterburner":
			_draw_afterburner(w, h, line_w)
		"overcharge":
			_draw_overcharge(w, h)
		"supershield":
			_draw_supershield(w, h, line_w)
		"heal":
			_draw_heal(w, h)
		"repair_drones":
			_draw_repair_drones(w, h, line_w)
		_:
			_draw_default(w, h, line_w)

func _draw_afterburner(w: float, h: float, line_w: float) -> void:
	# Three forward chevrons pointing right.
	var chev_w: float = w * 0.18
	var chev_h: float = h * 0.26
	var cy: float = h * 0.5
	var start_x: float = w * 0.24
	var step: float = w * 0.22
	for i in range(3):
		var x: float = start_x + step * i
		var pts := PackedVector2Array([
			Vector2(x - chev_w * 0.5, cy - chev_h),
			Vector2(x + chev_w * 0.5, cy),
			Vector2(x - chev_w * 0.5, cy + chev_h),
		])
		draw_polyline(pts, color, line_w, true)

func _draw_overcharge(w: float, h: float) -> void:
	# Lightning bolt filled glyph.
	var pts := PackedVector2Array([
		Vector2(w * 0.58, h * 0.10),
		Vector2(w * 0.30, h * 0.55),
		Vector2(w * 0.47, h * 0.55),
		Vector2(w * 0.40, h * 0.90),
		Vector2(w * 0.70, h * 0.42),
		Vector2(w * 0.52, h * 0.42),
		Vector2(w * 0.66, h * 0.10),
	])
	draw_colored_polygon(pts, color)

func _draw_supershield(w: float, h: float, line_w: float) -> void:
	# Heraldic shield outline.
	var pts := PackedVector2Array([
		Vector2(w * 0.50, h * 0.10),
		Vector2(w * 0.82, h * 0.22),
		Vector2(w * 0.82, h * 0.52),
		Vector2(w * 0.50, h * 0.90),
		Vector2(w * 0.18, h * 0.52),
		Vector2(w * 0.18, h * 0.22),
		Vector2(w * 0.50, h * 0.10),
	])
	draw_polyline(pts, color, line_w, true)

func _draw_heal(w: float, h: float) -> void:
	# Bold plus sign.
	var t: float = minf(w, h) * 0.18
	var cx: float = w * 0.5
	var cy: float = h * 0.5
	var arm: float = minf(w, h) * 0.34
	draw_rect(Rect2(cx - t * 0.5, cy - arm, t, arm * 2.0), color)
	draw_rect(Rect2(cx - arm, cy - t * 0.5, arm * 2.0, t), color)

func _draw_repair_drones(w: float, h: float, line_w: float) -> void:
	# Central diamond hub with orbiting drone nodes and a top sensor.
	var cx: float = w * 0.5
	var cy: float = h * 0.54
	var dx: float = w * 0.16
	var dy: float = h * 0.16
	var diamond := PackedVector2Array([
		Vector2(cx, cy - dy),
		Vector2(cx + dx, cy),
		Vector2(cx, cy + dy),
		Vector2(cx - dx, cy),
		Vector2(cx, cy - dy),
	])
	draw_polyline(diamond, color, line_w, true)
	# Top sensor stalk + node.
	draw_line(Vector2(cx, cy - dy), Vector2(cx, h * 0.16), color, line_w, true)
	draw_circle(Vector2(cx, h * 0.14), maxf(2.0, h * 0.05), color)
	# Side drone nodes.
	var node_r: float = maxf(2.0, h * 0.05)
	draw_line(Vector2(cx + dx, cy), Vector2(w * 0.86, cy), color, line_w, true)
	draw_circle(Vector2(w * 0.88, cy), node_r, color)
	draw_line(Vector2(cx - dx, cy), Vector2(w * 0.14, cy), color, line_w, true)
	draw_circle(Vector2(w * 0.12, cy), node_r, color)

func _draw_default(w: float, h: float, line_w: float) -> void:
	# Empty / unknown slot marker.
	var r: float = minf(w, h) * 0.28
	draw_arc(Vector2(w * 0.5, h * 0.5), r, 0.0, TAU, 32, color, line_w, true)
