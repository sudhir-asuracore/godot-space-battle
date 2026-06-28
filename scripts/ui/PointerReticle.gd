extends Control
class_name PointerReticle

# Screen-space pointer reticle that replaces the system cursor during gameplay.
# Default look is an arrow cursor. When the pointer hovers an attackable enemy
# (ship, turret, homebase) it switches to a red ringed "target" reticle.

@export var arrow_color: Color = Color(0.45, 0.90, 1.0)
@export var target_color: Color = Color(1.0, 0.25, 0.25)

const RING_RADIUS := 12.0
const TICK_GAP := 4.0
const TICK_LENGTH := 7.0
const LINE_WIDTH := 1.5

var _ship: Ship = null
var _hovering_enemy: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func setup(ship: Ship) -> void:
	_ship = ship

# Toggles the in-game pointer. When active the custom reticle is drawn and the
# system cursor is hidden; when inactive (e.g. a full-screen menu like the
# hangar is open) the custom reticle is hidden and the system cursor is restored
# so the player can actually see what they are clicking.
func set_active(active: bool) -> void:
	visible = active
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN if active else Input.MOUSE_MODE_VISIBLE)

func _process(_delta: float) -> void:
	if not visible:
		return
	_update_hover()
	queue_redraw()

# Sample the physics world under the mouse to decide whether an attackable
# enemy is hovered. Mirrors the target-lock logic in TargetingController.
func _update_hover() -> void:
	_hovering_enemy = false
	if not _ship or not is_instance_valid(_ship) or _ship.is_dead:
		return

	var space_state: PhysicsDirectSpaceState2D = _ship.get_world_2d().direct_space_state
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = _ship.get_global_mouse_position()
	# Layer 1 = Ship, Layer 64 (bit 7) = Homebase / defenses.
	query.collision_mask = 1 | 64
	query.collide_with_areas = true

	var results: Array[Dictionary] = space_state.intersect_point(query)
	for result: Dictionary in results:
		var collider := result.get("collider") as Node
		if not collider:
			continue
		var candidate: Node2D = _resolve_target(collider)
		if not candidate or candidate == _ship:
			continue
		# Skip friendly units / structures.
		if "faction_data" in candidate and candidate.faction_data == _ship.faction_data:
			continue
		if candidate is Ship or candidate.has_method("is_enemy"):
			_hovering_enemy = true
			return

func _resolve_target(collider: Node) -> Node2D:
	if collider.has_meta("damage_receiver"):
		var receiver: Variant = collider.get_meta("damage_receiver")
		if receiver is Node2D and is_instance_valid(receiver):
			return receiver
	return collider as Node2D

func _draw() -> void:
	var p: Vector2 = get_viewport().get_mouse_position()
	if _hovering_enemy:
		_draw_target(p)
	else:
		_draw_arrow(p)

func _draw_arrow(p: Vector2) -> void:
	# Classic cursor arrow with the tip anchored at the mouse position.
	var pts: PackedVector2Array = PackedVector2Array([
		p,
		p + Vector2(0.0, 18.0),
		p + Vector2(4.5, 13.5),
		p + Vector2(7.5, 20.0),
		p + Vector2(10.0, 19.0),
		p + Vector2(7.0, 12.5),
		p + Vector2(13.0, 12.5),
	])
	draw_colored_polygon(pts, arrow_color)
	# Dark outline so the arrow stays readable over bright backgrounds.
	var outline: PackedVector2Array = pts.duplicate()
	outline.append(p)
	draw_polyline(outline, Color(0.0, 0.0, 0.0, 0.7), 1.0, true)

func _draw_target(p: Vector2) -> void:
	# Central ring.
	draw_arc(p, RING_RADIUS, 0.0, TAU, 48, target_color, LINE_WIDTH, true)

	# Four cardinal ticks pointing inward toward the ring.
	var inner: float = RING_RADIUS + TICK_GAP
	var outer: float = inner + TICK_LENGTH
	draw_line(p + Vector2(0.0, -inner), p + Vector2(0.0, -outer), target_color, LINE_WIDTH, true)
	draw_line(p + Vector2(0.0, inner), p + Vector2(0.0, outer), target_color, LINE_WIDTH, true)
	draw_line(p + Vector2(-inner, 0.0), p + Vector2(-outer, 0.0), target_color, LINE_WIDTH, true)
	draw_line(p + Vector2(inner, 0.0), p + Vector2(outer, 0.0), target_color, LINE_WIDTH, true)

	# Centre dot.
	draw_circle(p, 1.5, target_color)
