extends Area2D
class_name Projectile

var direction: Vector2 = Vector2.RIGHT
var speed: float = 800.0
var damage_hull: float = 10.0
var damage_shield: float = 5.0
var source_ship: Node2D = null

func _ready() -> void:
	# Self destruct after 5 seconds if no hit
	await get_tree().create_timer(5.0).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	rotation = direction.angle()

func _on_body_entered(body: Node) -> void:
	# The firing ship may have been destroyed (freed) while the shot was in
	# flight. Drop the stale reference so it is never read or passed along.
	if not is_instance_valid(source_ship):
		source_ship = null

	if body == source_ship:
		return
	
	# Ignore friendly units / structures (no friendly fire).
	if source_ship and "faction_data" in body and body.faction_data == source_ship.faction_data:
		return
		
	if body.has_method("take_damage"):
		body.take_damage(damage_hull, damage_shield, source_ship)
		queue_free()
	elif body is StaticBody2D: # Planets and other solid bodies block the shot.
		queue_free()
