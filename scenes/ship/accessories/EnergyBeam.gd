extends Node2D
class_name EnergyBeam

# A sustained energy beam weapon. Unlike a travelling Projectile, the beam grows
# out of the firing turret toward its target, stays connected for `duration`
# seconds and deals its (low) damage continuously while it is locked on. The
# turret configures all of the values below before adding the beam to the tree.

# The node the beam emanates from (typically the firing turret). The beam
# re-anchors to this every frame so it keeps growing out of the muzzle while the
# turret tracks the target.
var origin_node: Node2D = null
# Muzzle offset expressed in `origin_node`'s local space so the beam follows the
# turret's rotation.
var origin_offset: Vector2 = Vector2.ZERO

var target: Node2D = null
var source_ship: Node2D = null

# Damage is expressed per second because the beam applies it continuously.
var damage_hull_per_second: float = 10.0
var damage_shield_per_second: float = 18.0
# How long the beam stays active and keeps hitting the enemy.
var duration: float = 0.6
# Maximum reach of the beam (usually the weapon's attack range).
var max_length: float = 800.0
# Seconds for the beam to extend from the turret to its full reach.
var grow_time: float = 0.08

var core_color: Color = Color(0.8, 0.95, 1.0, 1.0)
var glow_color: Color = Color(0.0, 0.6, 1.0, 0.35)
var core_width: float = 4.0
var glow_width: float = 12.0

var _elapsed: float = 0.0
var _current_length: float = 0.0

@onready var _core: Line2D = get_node_or_null(^"Core")
@onready var _glow: Line2D = get_node_or_null(^"Glow")

func _ready() -> void:
	_apply_style()
	_update_anchor()
	_update_geometry(0.0)

func _apply_style() -> void:
	if _core:
		_core.default_color = core_color
		_core.width = core_width
	if _glow:
		_glow.default_color = glow_color
		_glow.width = glow_width

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return

	_update_anchor()

	var target_length := _resolve_target_length()
	# Grow quickly toward the target, then keep tracking it.
	var grow_rate := max_length / maxf(0.01, grow_time)
	_current_length = move_toward(_current_length, target_length, grow_rate * delta)
	_update_geometry(_current_length)

	_apply_damage(delta)

func _update_anchor() -> void:
	if origin_node and is_instance_valid(origin_node):
		global_position = origin_node.to_global(origin_offset)
	if _is_target_valid():
		global_rotation = global_position.direction_to(target.global_position).angle()

func _resolve_target_length() -> float:
	if _is_target_valid():
		return minf(max_length, global_position.distance_to(target.global_position))
	# Hold the current reach when the target is gone so the beam simply fades out
	# over the remainder of its duration.
	return _current_length

func _update_geometry(length: float) -> void:
	var pts := PackedVector2Array([Vector2.ZERO, Vector2(length, 0.0)])
	if _core:
		_core.points = pts
	if _glow:
		_glow.points = pts

func _apply_damage(delta: float) -> void:
	if not _is_target_valid():
		return
	# Only deal damage once the beam has actually reached the target.
	var reach := global_position.distance_to(target.global_position)
	if _current_length + 1.0 < reach:
		return
	if not target.has_method("take_damage"):
		return
	# The firing ship may have been destroyed (freed) while the beam was still
	# active. Drop the stale reference so a previously freed object is never
	# passed along to take_damage().
	if not is_instance_valid(source_ship):
		source_ship = null
	target.call("take_damage", damage_hull_per_second * delta, damage_shield_per_second * delta, source_ship)

func _is_target_valid() -> bool:
	if not target or not is_instance_valid(target):
		return false
	if target is Ship and target.is_dead:
		return false
	if "is_destroyed" in target and target.is_destroyed:
		return false
	return true
