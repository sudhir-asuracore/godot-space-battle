extends CharacterBody2D
class_name Ship

@export var ship_data: ShipData
@export var faction_data: FactionData

# Current state
var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false
var current_hull: float = 0.0
var current_shield: float = 0.0
var current_capacitor: float = 0.0
var is_dead: bool = false

@onready var _thruster: Node2D = $Thruster
@onready var _thruster_sprite: Sprite2D = $Thruster/Sprite2D
@onready var _engine: Marker2D = $Engine

const RIBBON_TRAIL_SCENE = preload("res://scenes/RibbonTrail.tscn")
var _trail: Line2D = null

# Internal calculated stats (data + faction multipliers)
var max_hull: float
var max_shield: float
var max_capacitor: float
var _max_speed: float
var _acceleration: float
var _turn_speed: float
var _forward_damping: float
var _lateral_damping: float
var _braking_strength: float

var _thrust_intensity: float = 0.0
var _visual_thrust: float = 0.0

var _shield_regen_delay_timer: float = 0.0
var _last_attacker: Node2D = null

func _ready() -> void:
	add_to_group("ships")
	target_position = global_position
	update_stats()
	
	if _thruster_sprite and _thruster_sprite.material:
		_thruster_sprite.material = _thruster_sprite.material.duplicate()
	
	_setup_trail()

func _setup_trail() -> void:
	if not ship_data or not is_inside_tree():
		return
	
	# If we already have a trail (e.g. from previous life that didn't clean up), 
	# stop it so it can fade out and clean itself up
	if _trail:
		_trail.stop_emitting()
		_trail.set_target(null)
		_trail = null
		
	_trail = RIBBON_TRAIL_SCENE.instantiate()
	# Add as sibling so it's in world space but managed by the same parent
	get_parent().add_child(_trail)
	_trail.setup(ship_data)
	_trail.set_target(_engine if _engine else self)
	_trail.set_emitting(false)

func update_stats() -> void:
	if not ship_data:
		return
		
	if not _trail and is_inside_tree():
		_setup_trail()
		
	var speed_mult = faction_data.speed_multiplier if faction_data else 1.0
	var accel_mult = faction_data.acceleration_multiplier if faction_data else 1.0
	var turn_mult = faction_data.turn_speed_multiplier if faction_data else 1.0
	var lateral_mult = faction_data.lateral_damping_multiplier if faction_data else 1.0
	var braking_mult = faction_data.braking_multiplier if faction_data else 1.0
	var hull_mult = faction_data.hull_multiplier if faction_data else 1.0
	var shield_mult = faction_data.shield_multiplier if faction_data else 1.0
	var cap_mult = faction_data.capacitor_multiplier if faction_data else 1.0
	
	_max_speed = ship_data.max_speed * speed_mult
	_acceleration = ship_data.acceleration * accel_mult
	_turn_speed = ship_data.turn_speed * turn_mult
	_forward_damping = ship_data.forward_damping
	_lateral_damping = ship_data.lateral_damping * lateral_mult
	_braking_strength = ship_data.braking_strength * braking_mult
	
	max_hull = ship_data.max_hull * hull_mult
	max_shield = ship_data.max_shield * shield_mult
	max_capacitor = ship_data.max_capacitor * cap_mult
	
	if faction_data and has_node("Sprite2D"):
		$Sprite2D.modulate = faction_data.primary_color
	
	if current_hull <= 0: # Only init if not already set (or if we want to reset)
		current_hull = max_hull
		current_shield = max_shield
		current_capacitor = max_capacitor

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	# 0. Regenerate capacitor and (delayed) shields.
	_process_regen(delta)
	
	# 1. Handle Damping (Fake Space Friction)
	_apply_friction(delta)
	
	_thrust_intensity = 0.0
	if is_moving:
		_process_movement(delta)
	
	_update_thruster_vfx(delta)
	
	move_and_slide()

func _update_thruster_vfx(delta: float) -> void:
	if not _thruster:
		return
		
	_visual_thrust = move_toward(_visual_thrust, _thrust_intensity, delta * 5.0)
	
	if _visual_thrust > 0.001:
#		_thruster.visible = true
		_thruster.scale.y = lerp(0.008, 0.05, _visual_thrust)
		if _thruster_sprite and _thruster_sprite.material:
			_thruster_sprite.material.set_shader_parameter("emission_glow", _visual_thrust)
	
	if _trail:
		_trail.set_emitting(_visual_thrust > 0.01)
#	else:
#		_thruster.visible = false

func _process_regen(delta: float) -> void:
	if not ship_data:
		return
	# Capacitor regenerates continuously.
	if current_capacitor < max_capacitor:
		current_capacitor = min(max_capacitor, current_capacitor + ship_data.capacitor_regen * delta)
	# Shields regenerate only after a delay since the last damage taken.
	if _shield_regen_delay_timer > 0.0:
		_shield_regen_delay_timer -= delta
	elif current_shield < max_shield:
		current_shield = min(max_shield, current_shield + ship_data.shield_regen * delta)

func _apply_friction(delta: float) -> void:
	if velocity.length() < 1.0:
		velocity = Vector2.ZERO
		return
		
	var forward_dir = Vector2.from_angle(global_rotation)
	var lateral_dir = forward_dir.rotated(PI/2.0)
	
	var forward_vel = velocity.dot(forward_dir)
	var lateral_vel = velocity.dot(lateral_dir)
	
	# Apply damping
	# Using (1.0 - damping * delta) approach for simple linear-ish friction
	forward_vel = lerp(forward_vel, 0.0, _forward_damping * delta * 10.0)
	lateral_vel = lerp(lateral_vel, 0.0, _lateral_damping * delta * 10.0)
	
	velocity = forward_dir * forward_vel + lateral_dir * lateral_vel

func _process_movement(delta: float) -> void:
	var to_target = target_position - global_position
	var distance = to_target.length()
	
	if distance < 10.0:
		is_moving = false
		return
		
	# 1. Rotation
	var target_angle = to_target.angle()
	global_rotation = rotate_toward(global_rotation, target_angle, _turn_speed * delta)
	
	# 2. Acceleration
	var forward_dir = Vector2.from_angle(global_rotation)
	var angle_diff = abs(angle_difference(global_rotation, target_angle))
	
	# Scale acceleration based on alignment (thrust factor)
	var thrust_factor = clamp(1.0 - (angle_diff / PI), 0.0, 1.0)
	
	# 3. Assisted Braking
	var speed_limit = _max_speed
	if distance < ship_data.arrival_radius:
		speed_limit = _max_speed * (distance / ship_data.arrival_radius)
	
	# Apply acceleration if below speed limit
	if velocity.length() < speed_limit:
		velocity += forward_dir * _acceleration * thrust_factor * delta
		_thrust_intensity = thrust_factor
	elif velocity.length() > speed_limit + 10.0:
		# Braking logic
		velocity = velocity.move_toward(forward_dir * speed_limit, _acceleration * _braking_strength * delta)
	else:
		pass

func set_target(pos: Vector2) -> void:
	target_position = pos
	is_moving = true

func take_damage(hull_dmg: float, shield_dmg: float, attacker: Node2D = null) -> void:
	if is_dead:
		return
	
	_last_attacker = attacker
	# Any damage resets the shield regeneration delay.
	if ship_data:
		_shield_regen_delay_timer = ship_data.shield_regen_delay
	
	if current_shield > 0:
		current_shield -= shield_dmg
		if current_shield < 0:
			# Shield broke this hit: spill the basic weapon's hull damage through.
			current_hull -= hull_dmg
			current_shield = 0
	else:
		current_hull -= hull_dmg
		
	if current_hull <= 0:
		_die()

func can_afford(cost: float) -> bool:
	return current_capacitor >= cost

func spend_capacitor(cost: float) -> void:
	current_capacitor = max(0.0, current_capacitor - cost)

func respawn(at: Vector2) -> void:
	global_position = at
	target_position = at
	is_dead = false
	is_moving = false
	velocity = Vector2.ZERO
	_last_attacker = null
	_shield_regen_delay_timer = 0.0
	current_hull = 0.0 # Forces full reset of vitals in update_stats().
	update_stats()
	
	_setup_trail()
	visible = true

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	is_moving = false
	velocity = Vector2.ZERO
	# Hide or explode
	visible = false
	if _trail:
		_trail.stop_emitting()
		_trail.set_target(null)
		_trail = null
		
	print(name, " destroyed!")
	EventBus.ship_destroyed.emit(self, _last_attacker)
	
func is_enemy() -> bool:
	return faction_data != null # Simple check for MVP
