extends CharacterBody2D
class_name Ship

@export var max_speed: float = 1200.0      # Max travel speed
@export var acceleration: float = 800.0    # Engine acceleration
@export var deceleration: float = 1200.0   # Retro-thruster deceleration
@export var rotation_speed: float = 5.0    # Yaw speed (turning speed)

var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false

func _ready() -> void:
	target_position = global_position

func _physics_process(delta: float) -> void:
	if not is_moving:
		return
		
	var to_target: Vector2 = target_position - global_position
	var distance: float = to_target.length()
	
	# Stop moving if we are extremely close to target position
	if distance < 12.0:
		velocity = Vector2.ZERO
		is_moving = false
		return
		
	# 1. Smooth rotation toward target angle
	var target_angle: float = to_target.angle()
	global_rotation = rotate_toward(global_rotation, target_angle, rotation_speed * delta)
	
	# 2. Forward acceleration & deceleration math
	var angle_diff: float = abs(angle_difference(global_rotation, target_angle))
	
	# Thrust factor: Scale thrust based on alignment. The ship will slow down
	# during sharp turns to avoid unrealistic sliding.
	var thrust_factor: float = clamp(1.0 - (angle_diff / (PI / 2.0)), 0.0, 1.0)
	
	# Calculate the distance required to brake to a complete stop: v^2 = 2 * a * d
	var brake_distance: float = (velocity.length() * velocity.length()) / (2.0 * deceleration)
	
	var target_speed: float = max_speed
	# If we are within the braking distance, scale down the target speed
	if distance < brake_distance:
		target_speed = max_speed * (distance / brake_distance)
		
	# Apply thrust constraints
	target_speed *= thrust_factor
	
	# Interpolate speed
	var target_velocity: Vector2 = Vector2(cos(global_rotation), sin(global_rotation)) * target_speed
	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	
	move_and_slide()

# Called by input script when player sets a coordinate target
func set_target(pos: Vector2) -> void:
	target_position = pos
	is_moving = true
