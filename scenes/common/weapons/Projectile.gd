extends Area2D
class_name Projectile

var direction: Vector2 = Vector2.RIGHT
var speed: float = 800.0
var damage_hull: float = 10.0
var damage_shield: float = 5.0
# Marks whether this shot represents a beam/laser type weapon as opposed to a
# travelling projectile. Set by the firing turret from the weapon definition.
var is_beam: bool = false
var source_ship: Node2D = null

func _ready() -> void:
	# Self destruct after 5 seconds if no hit
	await get_tree().create_timer(5.0).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	rotation = direction.angle()

func _on_body_entered(body: Node) -> void:
	_refresh_source_ship_reference()

	if _try_apply_hit(body):
		return

	if body is StaticBody2D: # Planets and other solid bodies block the shot.
		if _is_friendly_static_body(body):
			return
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	_refresh_source_ship_reference()
	_try_apply_hit(area)

func _refresh_source_ship_reference() -> void:
	# The firing ship may have been destroyed (freed) while the shot was in
	# flight. Drop the stale reference so it is never read or passed along.
	if not is_instance_valid(source_ship):
		source_ship = null


func _try_apply_hit(target: Node) -> bool:
	var receiver: Node = _resolve_damage_receiver(target)
	if not receiver:
		return false

	if receiver == source_ship:
		return false

	# Ignore friendly units / structures (no friendly fire).
	if source_ship and "faction_data" in receiver and receiver.faction_data == source_ship.faction_data:
		return false

	receiver.call("take_damage", damage_hull, damage_shield, source_ship)
	queue_free()
	return true

func _resolve_damage_receiver(target: Node) -> Node:
	if target.has_method("take_damage"):
		return target

	if target.has_meta("damage_receiver"):
		var receiver: Variant = target.get_meta("damage_receiver")
		if receiver is Node and is_instance_valid(receiver) and receiver.has_method("take_damage"):
			return receiver

	return null

func _is_friendly_static_body(body: Node) -> bool:
	if not source_ship or not is_instance_valid(source_ship):
		return false

	if not ("faction_data" in source_ship):
		return false

	if not ("faction_data" in body):
		return false

	return body.faction_data == source_ship.faction_data
