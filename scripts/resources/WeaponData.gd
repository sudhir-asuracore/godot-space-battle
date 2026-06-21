extends Resource
class_name WeaponData

@export var name: String = "Autocannon"
@export var weapon_range: float = 500.0
@export var fire_rate: float = 4.0:
	set(v):
		if is_equal_approx(fire_rate, v): return
		fire_rate = v
		if v > 0:
			cooldown = 1.0 / v
@export var cooldown: float = 0.25:
	set(v):
		if is_equal_approx(cooldown, v): return
		cooldown = v
		if v > 0:
			fire_rate = 1.0 / v
@export var shield_damage: float = 5.0
@export var hull_damage: float = 10.0
@export var projectile_speed: float = 900.0
@export var spread_degrees: float = 2.0
@export var is_beam: bool = false
@export var auto_fire: bool = true
