extends Resource
class_name WeaponData

@export var name: String = "Autocannon"
@export var weapon_range: float = 500.0
@export var fire_rate: float = 4.0
@export var ammo: int = 0
@export var cooldown: float = 0.25
@export var shield_damage: float = 5.0
@export var hull_damage: float = 10.0
@export var projectile_speed: float = 900.0
@export var spread_degrees: float = 2.0
@export var muzzle_flash: PackedScene
@export var muzzle_flash_scale: float = 1.0
@export var muzzle_flash_speed_scale: float = 1.0
@export var fire_audio: AudioStream
@export var fire_audio_once_per_ammo: int = 1
@export var is_beam: bool = false
@export var auto_fire: bool = true
