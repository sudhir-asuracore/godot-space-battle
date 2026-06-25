extends Resource
class_name FactionData

@export_category("Profile")
@export var name: String = "Zarak Confedaracy"
@export var description: String = ""
@export var primary_color: Color
@export var secondary_color: Color
@export var shield_color: Color

@export_category("Homebase")
@export var defense_ring_scene: PackedScene
@export var defense_ring_scale: float = 1.0
@export var shield_scale: float = 1.0
# Turret level defaults. These are used when a weapon does not override the
# matching `turret_projectile_<weapon>_<suffix>` value, and keep single-weapon
# turrets working without the dynamic configuration below.
@export var turret_attack_range: float = 700.0
@export var turret_min_attack_range: float = 0.0
@export var turret_turn_speed: float = 3.0
@export var turret_attack_cone_degrees: float = 28.0
@export var turret_fire_rate: float = 2.0
@export var turret_hull_damage: float = 18.0
@export var turret_shield_damage: float = 14.0
# Default duration (seconds) a beam-type weapon stays connected to its target.
@export var turret_beam_duration: float = 0.6
@export var turret_projectile_speed: float = 900.0
@export var turret_projectile_scene: PackedScene
# Dynamic multi-weapon configuration. `turret_projectiles` lists the weapon
# names mounted on each defense turret (e.g. ["cannon", "laser"]). Every weapon
# may declare its own properties through resource keys shaped like
# `turret_projectile_<weapon>_<suffix>` (scene, speed, attack_range,
# min_attack_range, turn_speed, attack_cone_degrees, fire_rate, hull_damage,
# shield_damage, is_beam). Muzzles for a weapon are child markers named
# `<weapon>_0`, `<weapon>_1`, etc.
@export var turret_projectiles: PackedStringArray = PackedStringArray()
@export var hangar_ship_options: Array[ShipData] = []
@export var defense_structure_max_hull: float = 420.0
@export var defense_structure_auto_repair_rate: float = 20.0
@export var defense_structure_auto_repair_delay: float = 6.0

const TURRET_WEAPON_PREFIX := "turret_projectile_"

# Backing store for the dynamic `turret_projectile_<weapon>_<suffix>` keys that
# are not declared as explicit members above.
var _turret_weapon_overrides: Dictionary = {}

# Cached result of get_turret_weapons(). The weapon list is static at runtime,
# so it is built once and reused, avoiding a per-call Array allocation on the
# turret hot path. The cache is rebuilt automatically if turret_projectiles
# changes (e.g. when edited in the editor).
var _turret_weapons_cache: Array = []
var _turret_weapons_source: PackedStringArray = PackedStringArray()
var _turret_weapons_cache_valid: bool = false

func _set(property: StringName, value: Variant) -> bool:
	var key := String(property)
	if _is_dynamic_weapon_property(key):
		_turret_weapon_overrides[key] = value
		return true
	return false

func _get(property: StringName) -> Variant:
	var key := String(property)
	if _turret_weapon_overrides.has(key):
		return _turret_weapon_overrides[key]
	return null

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	for key in _turret_weapon_overrides.keys():
		props.append({
			"name": key,
			"type": typeof(_turret_weapon_overrides[key]),
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	return props

func _is_dynamic_weapon_property(key: String) -> bool:
	if not key.begins_with(TURRET_WEAPON_PREFIX):
		return false
	# Guard the explicitly declared single-weapon members.
	return key != "turret_projectile_speed" and key != "turret_projectile_scene"

# Returns the configured weapon names. Falls back to a single implicit weapon
# (empty name) that uses the turret level defaults for legacy turrets.
# The result is cached because it is queried many times per frame per turret.
func get_turret_weapons() -> Array:
	if not _turret_weapons_cache_valid or _turret_weapons_source != turret_projectiles:
		_rebuild_turret_weapons_cache()
	return _turret_weapons_cache

func _rebuild_turret_weapons_cache() -> void:
	var names: Array = []
	if turret_projectiles.size() > 0:
		for weapon in turret_projectiles:
			names.append(String(weapon))
	else:
		names.append("")
	_turret_weapons_cache = names
	_turret_weapons_source = turret_projectiles.duplicate()
	_turret_weapons_cache_valid = true

func _turret_weapon_value(weapon: String, suffix: String, default_value: Variant) -> Variant:
	var key := "%s%s_%s" % [TURRET_WEAPON_PREFIX, weapon, suffix]
	if _turret_weapon_overrides.has(key):
		return _turret_weapon_overrides[key]
	return default_value

func turret_weapon_scene(weapon: String) -> PackedScene:
	var value: Variant = _turret_weapon_value(weapon, "scene", turret_projectile_scene)
	return value as PackedScene

func turret_weapon_speed(weapon: String) -> float:
	return float(_turret_weapon_value(weapon, "speed", turret_projectile_speed))

func turret_weapon_attack_range(weapon: String) -> float:
	return float(_turret_weapon_value(weapon, "attack_range", turret_attack_range))

func turret_weapon_min_attack_range(weapon: String) -> float:
	return float(_turret_weapon_value(weapon, "min_attack_range", turret_min_attack_range))

func turret_weapon_turn_speed(weapon: String) -> float:
	return float(_turret_weapon_value(weapon, "turn_speed", turret_turn_speed))

func turret_weapon_attack_cone_degrees(weapon: String) -> float:
	return float(_turret_weapon_value(weapon, "attack_cone_degrees", turret_attack_cone_degrees))

func turret_weapon_fire_rate(weapon: String) -> float:
	return float(_turret_weapon_value(weapon, "fire_rate", turret_fire_rate))

func turret_weapon_hull_damage(weapon: String) -> float:
	return float(_turret_weapon_value(weapon, "hull_damage", turret_hull_damage))

func turret_weapon_shield_damage(weapon: String) -> float:
	return float(_turret_weapon_value(weapon, "shield_damage", turret_shield_damage))

func turret_weapon_is_beam(weapon: String) -> bool:
	return bool(_turret_weapon_value(weapon, "is_beam", false))

func turret_weapon_beam_duration(weapon: String) -> float:
	return float(_turret_weapon_value(weapon, "beam_duration", turret_beam_duration))

@export_category("Stat Modifiers")
@export var hull_multiplier: float = 1.0
@export var shield_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0
@export var acceleration_multiplier: float = 1.0
@export var capacitor_multiplier: float = 1.0

@export_category("Movement Feel")
@export var turn_speed_multiplier: float = 1.0
@export var lateral_damping_multiplier: float = 1.0
@export var braking_multiplier: float = 1.0

@export_category("AI Personality")
@export var aggression: float = 1.0
@export var defense_bias: float = 1.0
@export var expansion_bias: float = 1.0
