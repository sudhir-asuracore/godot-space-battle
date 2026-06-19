extends Node
class_name AIShipController

enum State {
	SPAWN,
	NAVIGATING,
	CAPTURING,
	COMBAT_ENGAGED,
	RETREAT,
	DEAD
}

var current_state: State = State.SPAWN
var _target_objective: Node2D = null

@onready var _ship: Ship = get_parent() as Ship
@onready var _targeting: TargetingController = _ship.get_node("TargetingController")

func _ready() -> void:
	current_state = State.NAVIGATING

func _physics_process(delta: float) -> void:
	if _ship.is_dead:
		current_state = State.DEAD
		return
		
	match current_state:
		State.NAVIGATING:
			_state_navigating(delta)
		State.CAPTURING:
			_state_capturing(delta)
		State.COMBAT_ENGAGED:
			_state_combat(delta)

func _state_navigating(_delta: float) -> void:
	if not _target_objective:
		_find_new_objective()
		return
		
	if _ship.global_position.distance_to(_target_objective.global_position) < 200.0:
		if _target_objective is Planet:
			current_state = State.CAPTURING
		return
		
	_ship.set_target(_target_objective.global_position)
	
	# Check for nearby enemies to engage
	_check_for_combat()

func _state_capturing(_delta: float) -> void:
	if not _target_objective or (_target_objective is Planet and _target_objective.owning_faction == _ship.faction_data):
		_target_objective = null
		current_state = State.NAVIGATING
		return
		
	_ship.set_target(_target_objective.global_position)
	_check_for_combat()

func _state_combat(_delta: float) -> void:
	if not _targeting.locked_target or not is_instance_valid(_targeting.locked_target):
		current_state = State.NAVIGATING
		return
		
	# Simple kiting or orbiting
	var dist = _ship.global_position.distance_to(_targeting.locked_target.global_position)
	if dist > _ship.ship_data.target_lock_range * 0.8:
		_ship.set_target(_targeting.locked_target.global_position)
	elif dist < _ship.ship_data.target_lock_range * 0.4:
		# Back away
		var away = _ship.global_position + (_ship.global_position - _targeting.locked_target.global_position).normalized() * 300.0
		_ship.set_target(away)

func _find_new_objective() -> void:
	# Find nearest neutral or enemy planet
	var planets = get_tree().get_nodes_in_group("planets")
	var best_p = null
	var min_dist = INF
	
	for p in planets:
		if p is Planet and p.owning_faction != _ship.faction_data:
			var d = _ship.global_position.distance_to(p.global_position)
			if d < min_dist:
				min_dist = d
				best_p = p
				
	_target_objective = best_p

func _check_for_combat() -> void:
	# For MVP, just look for player ship or other faction ships
	# This is a bit expensive to do every frame, but okay for MVP
	var ships = get_tree().get_nodes_in_group("ships")
	for s in ships:
		if s != _ship and s is Ship and not s.is_dead and s.faction_data != _ship.faction_data:
			var d = _ship.global_position.distance_to(s.global_position)
			if d < _ship.ship_data.target_lock_range:
				_targeting.locked_target = s
				current_state = State.COMBAT_ENGAGED
				return
