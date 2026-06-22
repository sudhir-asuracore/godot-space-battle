extends Node2D
class_name AbilityController

@onready var _ship: Ship = get_parent() as Ship

var _ability_1_cooldown: float = 0.0
var _ability_1_active_time: float = 0.0

func _process(delta: float) -> void:
	if _ability_1_cooldown > 0:
		_ability_1_cooldown -= delta

func _physics_process(delta: float) -> void:
	if _ability_1_active_time > 0:
		_ability_1_active_time -= delta
		_process_active_abilities(delta)

func _process_active_abilities(_delta: float) -> void:
	if not _ship or not _ship.ship_data:
		return
		
	var ability = _ship.ship_data.ability_1
	if not ability:
		return
		
	if ability.name == "Afterburner":
		# Strong forward thrust burst. 
		# We use 4x base acceleration for a significant boost.
		var forward = Vector2.from_angle(_ship.global_rotation)
		var accel = forward * _ship._acceleration * 4.0
		_ship.apply_acceleration(accel)

func use_ability_1() -> void:
	if _ability_1_cooldown > 0:
		return
	if not _ship.ship_data:
		return
		
	var ability = _ship.ship_data.ability_1
	if not ability:
		return
	
	# Abilities cost capacitor (PRD section 9.5).
	if not _ship.can_afford(ability.capacitor_cost):
		print("Ability failed: not enough capacitor")
		return
	_ship.spend_capacitor(ability.capacitor_cost)
		
	if ability.name == "Afterburner":
		_ability_1_active_time = ability.duration
		print("Afterburner activated!")
	_ability_1_cooldown = ability.cooldown

func get_ability_1_cooldown() -> float:
	return max(_ability_1_cooldown, 0.0)

func get_ability_1_max_cooldown() -> float:
	if _ship.ship_data and _ship.ship_data.ability_1:
		return _ship.ship_data.ability_1.cooldown
	return 0.0

