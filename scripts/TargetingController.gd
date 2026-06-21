extends Node2D
class_name TargetingController

@onready var _ship: Ship = get_parent() as Ship

var manual_target: Node2D = null
var auto_target: Node2D = null

# Priority: Manual target > Ship with least health nearby > Ship
var locked_target: Node2D:
	get:
		if is_instance_valid(manual_target):
			if not manual_target is Ship or not manual_target.is_dead:
				return manual_target
		if is_instance_valid(auto_target):
			if not auto_target is Ship or not auto_target.is_dead:
				return auto_target
		return null
	set(v):
		manual_target = v

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
		manual_target = found_target
		print("Manual target locked: ", manual_target.name)
	else:
		manual_target = null
		print("Manual target cleared")

func _process(_delta: float) -> void:
	_update_targets()

func _update_targets() -> void:
	# 1. Validate Manual Target
	if manual_target:
		if not is_instance_valid(manual_target) or (manual_target is Ship and manual_target.is_dead):
			manual_target = null
			
	# 2. Find Auto Target (if no manual target or just to have it ready)
	var ships = get_tree().get_nodes_in_group("ships")
	var best_target = null
	var min_health = INF
	
	# Use weapon range or target lock range for auto-targeting?
	# ShipData has target_lock_range.
	var search_range = _ship.ship_data.target_lock_range
	
	for s in ships:
		if s == _ship or not is_instance_valid(s) or (s is Ship and s.is_dead):
			continue
		if s.faction_data == _ship.faction_data:
			continue
			
		var dist = _ship.global_position.distance_to(s.global_position)
		if dist <= search_range:
			# Priority: Ship with least health nearby
			var health = s.current_hull + s.current_shield
			if health < min_health:
				min_health = health
				best_target = s
	
	auto_target = best_target
