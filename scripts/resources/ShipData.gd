extends Resource
class_name ShipData

@export_category("Profile")
@export var name: String = "Scout"
@export var tier: int = 1
@export var ship_class: String = "Assault"
@export var faction: String = ""

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
