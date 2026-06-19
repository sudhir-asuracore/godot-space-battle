extends Node2D
class_name TargetingController

@onready var _ship: Ship = get_parent() as Ship

var locked_target: Node2D = null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("target_lock"): # I'll register this in Main.gd
		_attempt_lock()

func _attempt_lock() -> void:
	var mouse_pos = get_global_mouse_position()
	var space_state = get_world_2d().direct_space_state
	
	# Use point sampling to see if we clicked an enemy
	var query = PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	# Layer 1 = Ship, Layer 64 (bit 7) = Homebase. Allow locking both (siege targeting).
	query.collision_mask = 1 | 64
	query.collide_with_areas = true
	
	var results = space_state.intersect_point(query)
	
	var found_target = null
	for result in results:
		var collider = result.collider
		if collider == _ship:
			continue
		# Skip friendly units / structures.
		if "faction_data" in collider and collider.faction_data == _ship.faction_data:
			continue
		if collider is Ship or collider.has_method("is_enemy"):
			found_target = collider
			break
			
	if found_target:
		locked_target = found_target
		print("Target locked: ", locked_target.name)
	else:
		locked_target = null
		print("Target cleared")

func _process(_delta: float) -> void:
	if locked_target:
		# Check if target is still valid (not destroyed, in range?)
		if not is_instance_valid(locked_target):
			locked_target = null
			return
			
		var dist = _ship.global_position.distance_to(locked_target.global_position)
		if dist > _ship.ship_data.target_lock_range * 1.5: # Loose leash for lock
			# For MVP, maybe keep lock but stop firing
			pass
