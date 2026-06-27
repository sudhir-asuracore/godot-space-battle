extends Resource
class_name ShipData

# Physical size class of the ship. Drives the destruction explosion scale,
# duration and audio so larger hulls blow up bigger, longer and louder.
enum ShipSize { SMALL, MEDIUM, LARGE, CAPITAL }

@export_category("Profile")
@export var name: String = "Scout"
@export var tier: int = 1
@export var ship_class: String = "Assault"
@export var faction: String = ""
@export var ship_size: ShipSize = ShipSize.MEDIUM
# Scene instantiated when this ship is spawned for the player. When left unset
# the spawner falls back to its configured default ship scene.
@export var ship_scene: PackedScene

@export_category("Vitals")
@export var max_hull: float = 100.0
@export var max_shield: float = 50.0
@export var shield_regen: float = 5.0
@export var shield_regen_delay: float = 3.0
@export var shield_angle: float = 360.0

@export_category("Movement")
@export var max_speed: float = 35.0
@export var acceleration: float = 45.0
@export var turn_speed: float = 4.0
@export var strafe_speed: float = 12.0
@export var reverse_speed: float = 8.0
@export var forward_damping: float = 0.08
@export var lateral_damping: float = 0.18
@export var arrival_radius: float = 80.0
@export var braking_strength: float = 1.5

@export_category("Capacitor")
@export var max_capacitor: float = 100.0
@export var capacitor_regen: float = 15.0

@export_category("Weapons")
@export var basic_weapon: WeaponData
@export var target_lock_range: float = 300.0
# Maps a muzzle weapon-type (the <type> in muzzle_<type>_<side>_<index> markers,
# e.g. "cannon", "gattling", "laser") to the WeaponData used for its projectile.
# Any type not listed here falls back to basic_weapon.
@export var muzzle_weapons: Dictionary = {}

# Returns the weapon resource configured for a given muzzle type, or null when
# no specific mapping exists (callers fall back to basic_weapon).
func get_muzzle_weapon(muzzle_type: StringName) -> WeaponData:
	if muzzle_type == &"":
		return null
	var mapped: Variant = muzzle_weapons.get(muzzle_type)
	if mapped == null:
		# Allow string keys too for convenience when authored in the inspector.
		mapped = muzzle_weapons.get(String(muzzle_type))
	return mapped as WeaponData

@export_category("Visuals")
@export var trail_color: Color = Color(1.0, 0.5, 0.2, 0.8)
@export var trail_brightness: float = 2.0
@export var trail_thickness: float = 8.0
@export var trail_length: int = 40
@export var trail_lifetime: float = 1.5

@export_category("Abilities")
@export var ability_1: AbilityData
@export var ability_2: AbilityData
@export var ability_3: AbilityData
@export var ability_4: AbilityData
@export var ability_5: AbilityData

@export_category("Economy")
@export var purchase_cost: float = 150.0
@export var kill_bounty: float = 75.0
@export var death_penalty: float = 37.0
