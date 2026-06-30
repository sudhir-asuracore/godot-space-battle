extends Resource
class_name WeaponData

@export var name: String = "Autocannon"
@export var weapon_range: float = 500.0
@export_range(0.0, 360.0, 0.5) var attack_cone_degrees: float = 360.0
# Maximum arc the turret can swing through, centred on its mounted/home
# direction. 360 (default) means it can rotate freely; e.g. 180 lets the
# weapon swing -90..+90 from its home position, so a side-mounted gun cannot
# fire on enemies behind the opposite flank. WeaponModule enforces this.
@export_range(0.0, 360.0, 1.0) var max_turret_angle: float = 360.0
# How fast the turret can swing its barrel toward (or back from) a target,
# in degrees per second. Lower values make the turret feel heavy: it lags
# behind a moving target and takes time to line up before it can fire.
# Set <= 0 to track instantly (no weight, original snapping behaviour).
@export var turret_homing_speed: float = 0.0
@export var show_coverage_grid: bool = false
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
