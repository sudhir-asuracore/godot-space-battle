extends Node2D
class_name TargetingController

@onready var _ship: Ship = get_parent() as Ship

var manual_target: Node2D = null
var auto_target: Node2D = null

# Priority: Manual target > Ship with least health nearby > Ship
var locked_target: Node2D:
	get:
		if _is_target_still_attackable(manual_target):
			return manual_target
		if _is_target_still_attackable(auto_target):
			return auto_target
		return null
	set(v):
		manual_target = v

func _unhandled_input(event: InputEvent) -> void:
	if _ship.is_dead:
		return
	if event.is_action_pressed("target_lock"): # I'll register this in Main.gd
		_attempt_lock()

func _attempt_lock() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	
	# Use point sampling to see if we clicked an enemy
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	# Layer 1 = Ship, Layer 64 (bit 7) = Homebase. Allow locking both (siege targeting).
	query.collision_mask = 1 | 64
	query.collide_with_areas = true
	
	var results: Array[Dictionary] = space_state.intersect_point(query)
	
	var found_target: Node2D = null
	for result: Dictionary in results:
		var collider := result.get("collider") as Node
		if not collider:
			continue
		var candidate: Node2D = _resolve_attackable_target(collider)
		if not candidate:
			continue
		if candidate == _ship:
			continue
		# Skip friendly units / structures.
		if "faction_data" in candidate and candidate.faction_data == _ship.faction_data:
			continue
		if candidate is Ship or candidate.has_method("is_enemy"):
			found_target = candidate
			break
			
	if found_target:
		manual_target = found_target
		print("Manual target locked: ", manual_target.name)
	else:
		manual_target = null
		print("Manual target cleared")

func _process(_delta: float) -> void:
	if _ship.is_dead:
		return
	_update_targets()

func _update_targets() -> void:
	# 1. Validate Manual Target
	if manual_target:
		if not _is_target_still_attackable(manual_target):
			manual_target = null
			
	# 2. Find Auto Target (if no manual target or just to have it ready).
	# Includes defense structures so they are treated as attackable assets.
	var candidates: Array[Node] = []
	candidates.append_array(get_tree().get_nodes_in_group("ships"))
	candidates.append_array(get_tree().get_nodes_in_group("homebases"))
	candidates.append_array(get_tree().get_nodes_in_group("homebase_defenses"))

	var best_target: Node2D = null
	var min_health: float = INF
	
	# Use weapon range or target lock range for auto-targeting?
	# ShipData has target_lock_range.
	var search_range: float = _ship.ship_data.target_lock_range
	
	for candidate in candidates:
		var target: Node2D = _resolve_attackable_target(candidate)
		if not _is_valid_auto_target(target):
			continue
		if "faction_data" in target and target.faction_data == _ship.faction_data:
			continue
			
		var dist: float = _ship.global_position.distance_to(target.global_position)
		if dist <= search_range:
			# Priority: Ship with least health nearby
			var health: float = _get_target_health(target)
			if health < min_health:
				min_health = health
				best_target = target
	
	auto_target = best_target

func _resolve_attackable_target(collider: Node) -> Node2D:
	var direct := collider as Node2D
	if direct:
		if direct.has_meta("damage_receiver"):
			var receiver_meta: Variant = direct.get_meta("damage_receiver")
			if receiver_meta is Node2D and is_instance_valid(receiver_meta):
				return receiver_meta
		return direct

	if collider.has_meta("damage_receiver"):
		var receiver: Variant = collider.get_meta("damage_receiver")
		if receiver is Node2D and is_instance_valid(receiver):
			return receiver

	return null

func _is_target_still_attackable(target: Variant) -> bool:
	if target == null:
		return false
	if not is_instance_valid(target):
		return false

	var target_node := target as Node2D
	if not target_node:
		return false

	if target_node is Ship and target_node.is_dead:
		return false
	if "is_destroyed" in target_node and target_node.is_destroyed:
		return false
	return true

func _is_valid_auto_target(target: Node2D) -> bool:
	if not target:
		return false
	if target == _ship:
		return false
	return _is_target_still_attackable(target)

func _get_target_health(target: Node2D) -> float:
	var hull: float = float(target.get("current_hull")) if "current_hull" in target else 0.0
	var shield: float = float(target.get("current_shield")) if "current_shield" in target else 0.0

	var total: float = hull + shield
	if total <= 0.0:
		return INF
	return total
