extends Node2D
class_name AbilityController

@onready var _ship: Ship = get_parent() as Ship

var _ability_1_cooldown: float = 0.0

func _process(delta: float) -> void:
	if _ability_1_cooldown > 0:
		_ability_1_cooldown -= delta

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
		_apply_afterburner(ability)
	_ability_1_cooldown = ability.cooldown

func get_ability_1_cooldown() -> float:
	return max(_ability_1_cooldown, 0.0)

func get_ability_1_max_cooldown() -> float:
	if _ship.ship_data and _ship.ship_data.ability_1:
		return _ship.ship_data.ability_1.cooldown
	return 0.0

func _apply_afterburner(ability: AbilityData) -> void:
	# For Afterburner, we can just give a temporary speed/accel boost
	# or an immediate impulse. 
	# PRD says "Strong forward thrust burst".
	
	var impulse = Vector2.from_angle(_ship.global_rotation) * 500.0 # Random impulse value
	_ship.velocity += impulse
	
	# We could also temporarily increase max_speed and acceleration in Ship.gd
	# but for MVP a simple impulse is a good start.
	print("Afterburner activated!")
