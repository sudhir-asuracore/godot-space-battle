extends Resource
class_name FactionData

@export_category("Profile")
@export var name: String = "Zarak Confedaracy"
@export var description: String = ""
@export var primary_color: Color
@export var secondary_color: Color
@export var shield_color: Color

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
