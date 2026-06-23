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
@export var turret_attack_range: float = 700.0
@export var turret_min_attack_range: float = 0.0
@export var turret_turn_speed: float = 3.0
@export var turret_attack_cone_degrees: float = 28.0
@export var turret_fire_rate: float = 2.0
@export var turret_hull_damage: float = 18.0
@export var turret_shield_damage: float = 14.0
@export var turret_projectile_speed: float = 900.0
@export var hangar_ship_options: Array[ShipData] = []

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
