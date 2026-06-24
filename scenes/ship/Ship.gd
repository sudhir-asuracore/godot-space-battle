extends CharacterBody2D
class_name Ship

@export var ship_data: ShipData
@export var faction_data: FactionData
@export_range(5.0, 100.0, 5) var damage_flame_scale_factor: float = 50.0

# Current state
var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false
var current_hull: float = 0.0
var current_shield: float = 0.0
var current_capacitor: float = 0.0
var is_dead: bool = false
var is_player_ship: bool = false

@onready var _engine: Marker2D = $Engine
@onready var _shield_sprite: ColorRect = $Shield


const RIBBON_TRAIL_SCENE = preload("res://scenes/ship/accessories/RibbonTrail.tscn")
const DAMAGE_MARKER_EFFECT_SCENE = preload("res://scenes/ship/accessories/ShipDamageFlames.tscn")
const DAMAGE_MARKER_PREFIX := "damage_"
const THRUSTER_NODE_PREFIX := "thruster_"

var _trail: Node = null
var _damage_markers: Array[Marker2D] = []
var _damage_marker_effects: Array[Node2D] = []
var _thruster_entries: Array[Dictionary] = []
var _thrusters_by_category: Dictionary = {}

# Internal calculated stats (data + faction multipliers)
var max_hull: float
var max_shield: float
var max_capacitor: float
var _max_speed: float
var _acceleration: float
var _turn_speed: float
var _strafe_speed: float
var _reverse_speed: float
var _forward_damping: float
var _lateral_damping: float
var _braking_strength: float

var _thrust_intensity: float = 0.0
var _visual_thrust: float = 0.0

var _shield_regen_delay_timer: float = 0.0
var _last_attacker: Node2D = null
var _shield_active: bool = true

func _ready() -> void:
	_before_ship_ready()
	add_to_group("ships")
	target_position = global_position
	_cache_thrusters()
	update_stats()
	_duplicate_runtime_materials()
	_initialize_ship_visuals()
	_after_ship_ready()

func _exit_tree() -> void:
	if is_player_ship:
		var audio_manager := _get_audio_manager()
		if audio_manager:
			audio_manager.call("stop_player_thruster_audio", true)

func _get_audio_manager() -> Node:
	return get_node_or_null(^"/root/AudioManager")

func _before_ship_ready() -> void:
	pass

func _after_ship_ready() -> void:
	pass

func _duplicate_runtime_materials() -> void:
	for thruster_entry in _thruster_entries:
		var thruster_sprite := thruster_entry.get("sprite") as Sprite2D
		if thruster_sprite and thruster_sprite.material:
			thruster_sprite.material = thruster_sprite.material.duplicate()
	if _shield_sprite and _shield_sprite.material:
		_shield_sprite.material = _shield_sprite.material.duplicate()

func _cache_thrusters() -> void:
	_thruster_entries.clear()
	_thrusters_by_category.clear()

	for child in get_children():
		var thruster_node := child as Node2D
		if not thruster_node:
			continue

		var thruster_metadata: Dictionary = _parse_thruster_node_name(thruster_node.name)
		if thruster_metadata.is_empty():
			continue

		var thruster_category: StringName = thruster_metadata.get("category", &"")
		var thruster_index: int = int(thruster_metadata.get("index", 0))
		var thruster_sprite := thruster_node.get_node_or_null(^"Sprite2D") as Sprite2D

		_thruster_entries.append({
			"node": thruster_node,
			"sprite": thruster_sprite,
			"category": thruster_category,
			"index": thruster_index,
		})

	_thruster_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_category: String = str(a.get("category", &""))
		var b_category: String = str(b.get("category", &""))
		if a_category == b_category:
			return int(a.get("index", 0)) < int(b.get("index", 0))
		return a_category < b_category
	)

	for thruster_entry in _thruster_entries:
		var category: StringName = thruster_entry.get("category", &"")
		var category_thrusters: Array = _thrusters_by_category.get(category, [])
		category_thrusters.append(thruster_entry.get("node"))
		_thrusters_by_category[category] = category_thrusters

func _parse_thruster_node_name(node_name: StringName) -> Dictionary:
	var raw_name: String = str(node_name)
	if not raw_name.begins_with(THRUSTER_NODE_PREFIX):
		return {}

	var parts: PackedStringArray = raw_name.split("_")
	if parts.size() != 3:
		return {}
	if parts[0] != "thruster":
		return {}

	var category: String = parts[1]
	if category.is_empty():
		return {}

	var index_text: String = parts[2]
	if not index_text.is_valid_int():
		return {}

	return {
		"category": StringName(category),
		"index": int(index_text),
	}

func _initialize_ship_visuals() -> void:
	_setup_trail()
	_cache_damage_markers()
	_setup_damage_marker_effects()
	_update_damage_marker_effects()

func _setup_trail() -> void:
	if not ship_data or not is_inside_tree():
		return
	
	# If we already have a trail (e.g. from previous life that didn't clean up), 
	# stop it so it can fade out and clean itself up
	if _trail:
		_trail.call("stop_emitting")
		_trail.call("set_target", null)
		_trail = null
		
	_trail = RIBBON_TRAIL_SCENE.instantiate()
	# Add as sibling so it's in world space but managed by the same parent
	get_parent().add_child(_trail)
	_trail.call("setup", ship_data)
	var trail_target: Node2D = self
	if _engine != null:
		trail_target = _engine
	_trail.call("set_target", trail_target)
	_trail.call("set_emitting", false)

func _cache_damage_markers() -> void:
	_damage_markers.clear()

	for child in get_children():
		var marker := child as Marker2D
		if not marker:
			continue
		if str(marker.name).begins_with(DAMAGE_MARKER_PREFIX):
			_damage_markers.append(marker)

	_damage_markers.sort_custom(_is_damage_marker_before)

func _setup_damage_marker_effects() -> void:
	for effect in _damage_marker_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	_damage_marker_effects.clear()

	for marker in _damage_markers:
		var effect := DAMAGE_MARKER_EFFECT_SCENE.instantiate() as Node2D
		if not effect:
			continue
		effect.name = &"DamageMarkerEffect"
		effect.scale *= damage_flame_scale_factor
		marker.add_child(effect)
		_damage_marker_effects.append(effect)

func _is_damage_marker_before(a: Marker2D, b: Marker2D) -> bool:
	return _damage_marker_index(a.name) < _damage_marker_index(b.name)

func _damage_marker_index(marker_name: StringName) -> int:
	var marker_name_text := str(marker_name)
	if not marker_name_text.begins_with(DAMAGE_MARKER_PREFIX):
		return 1_000_000

	var index_text := marker_name_text.substr(DAMAGE_MARKER_PREFIX.length())
	if index_text.is_valid_int():
		return index_text.to_int()

	return 1_000_000

func _update_damage_marker_effects() -> void:
	if _damage_marker_effects.is_empty():
		return

	var active_marker_count := _get_active_damage_marker_count()

	for marker_index in range(_damage_marker_effects.size()):
		var marker_effect := _damage_marker_effects[marker_index]
		var should_be_active := not is_dead and marker_index < active_marker_count
		_set_damage_marker_effect_active(marker_effect, should_be_active)

func _get_active_damage_marker_count() -> int:
	if _damage_marker_effects.is_empty() or max_hull <= 0.0:
		return 0

	var health_percent := current_hull / max_hull
	
	# Only show flames if health is below 80%
	if health_percent > 0.8:
		return 0
	
	# Map health from 80% down to 0% to 1 to N flames
	# (0.8 - health_percent) / 0.8 gives 0.0 at 80% health and 1.0 at 0% health
	var damage_factor := (0.8 - health_percent) / 0.8
	var count := int(ceil(damage_factor * _damage_marker_effects.size()))
	
	return clampi(count, 1, _damage_marker_effects.size())

func _set_damage_marker_effect_active(effect: Node2D, active: bool) -> void:
	if not effect:
		return

	effect.visible = active

	for child in effect.get_children():
		var gpu_particles := child as GPUParticles2D
		if not gpu_particles:
			continue

		if active and not gpu_particles.emitting:
			gpu_particles.restart()
		gpu_particles.emitting = active

func update_stats() -> void:
	if not ship_data:
		return
		
	if not _trail and is_inside_tree():
		_setup_trail()
		
	var speed_mult: float = faction_data.speed_multiplier if faction_data else 1.0
	var accel_mult: float = faction_data.acceleration_multiplier if faction_data else 1.0
	var turn_mult: float = faction_data.turn_speed_multiplier if faction_data else 1.0
	var lateral_mult: float = faction_data.lateral_damping_multiplier if faction_data else 1.0
	var braking_mult: float = faction_data.braking_multiplier if faction_data else 1.0
	var hull_mult: float = faction_data.hull_multiplier if faction_data else 1.0
	var shield_mult: float = faction_data.shield_multiplier if faction_data else 1.0
	var cap_mult: float = faction_data.capacitor_multiplier if faction_data else 1.0
	
	_max_speed = ship_data.max_speed * speed_mult
	_acceleration = ship_data.acceleration * accel_mult
	_turn_speed = ship_data.turn_speed * turn_mult
	_strafe_speed = ship_data.strafe_speed
	_reverse_speed = ship_data.reverse_speed
	_forward_damping = ship_data.forward_damping
	_lateral_damping = ship_data.lateral_damping * lateral_mult
	_braking_strength = ship_data.braking_strength * braking_mult
	
	max_hull = ship_data.max_hull * hull_mult
	max_shield = ship_data.max_shield * shield_mult
	max_capacitor = ship_data.max_capacitor * cap_mult
	_apply_stat_overrides()
	
	if faction_data and has_node(^"Sprite2D"):
		$Sprite2D.modulate = faction_data.primary_color
	
	if current_hull <= 0: # Only init if not already set (or if we want to reset)
		current_hull = max_hull
		current_shield = max_shield
		current_capacitor = max_capacitor
		
		# Initialize shield visual state
		_shield_active = current_shield > 0
		set_shield_angle(ship_data.shield_angle if _shield_active else 0.0)

	_update_damage_marker_effects()
	_on_stats_updated()

func _apply_stat_overrides() -> void:
	pass

func _on_stats_updated() -> void:
	pass

func _physics_process(delta: float) -> void:
	if is_dead:
		if is_player_ship:
			var audio_manager := _get_audio_manager()
			if audio_manager:
				audio_manager.call("set_player_thruster_intensity", 0.0)
		return
	
	# 0. Regenerate capacitor and (delayed) shields.
	_process_regen(delta)
	
	# 1. Handle Damping (Fake Space Friction)
	_apply_friction(delta)
	
	_process_manual_movement_input(delta)

	if is_moving:
		_process_movement(delta)

	_update_thruster_vfx(delta)
	_update_player_thruster_audio()
	_thrust_intensity = 0.0
	
	move_and_slide()

func _process_manual_movement_input(delta: float) -> bool:
	var strafe_input: float = 0.0
	if InputMap.has_action("strafe_left") and Input.is_action_pressed("strafe_left"):
		strafe_input -= 1.0
	if InputMap.has_action("strafe_right") and Input.is_action_pressed("strafe_right"):
		strafe_input += 1.0

	var reverse_input: bool = InputMap.has_action("reverse_thrust") and Input.is_action_pressed("reverse_thrust")
	if is_zero_approx(strafe_input) and not reverse_input:
		return false

	var forward_dir: Vector2 = Vector2.from_angle(global_rotation)
	var lateral_dir: Vector2 = forward_dir.rotated(PI / 2.0)
	var forward_vel: float = velocity.dot(forward_dir)
	var lateral_vel: float = velocity.dot(lateral_dir)

	if not is_zero_approx(strafe_input):
		lateral_vel = move_toward(lateral_vel, strafe_input * _strafe_speed, _acceleration * delta)

	if reverse_input:
		forward_vel = move_toward(forward_vel, -_reverse_speed, _acceleration * delta)
		_thrust_intensity = max(_thrust_intensity, 0.25)

	velocity = forward_dir * forward_vel + lateral_dir * lateral_vel
	return true

func apply_acceleration(accel: Vector2) -> void:
	velocity += accel * get_physics_process_delta_time()
	
	# Update thrust intensity based on forward component of acceleration
	# This allows visuals (thrusters, trails) to react to any acceleration source.
	var forward_dir: Vector2 = Vector2.from_angle(global_rotation)
	var thrust_component: float = accel.dot(forward_dir)
	if thrust_component > 0 and _acceleration > 0:
		# We normalize intensity against the ship's base acceleration.
		# Afterburners or multiple thrust sources can push this above 1.0.
		_thrust_intensity = max(_thrust_intensity, thrust_component / _acceleration)

func _update_thruster_vfx(delta: float) -> void:
	_visual_thrust = move_toward(_visual_thrust, _thrust_intensity, delta * 5.0)
	
	if _visual_thrust > 0.001:
		var thrust_scale: float = lerp(0.008, 0.05, _visual_thrust)

		for thruster_entry in _thruster_entries:
			var thruster_node := thruster_entry.get("node") as Node2D
			if thruster_node:
				thruster_node.scale.y = thrust_scale

			var thruster_sprite := thruster_entry.get("sprite") as Sprite2D
			if thruster_sprite and thruster_sprite.material:
				var shader_material := thruster_sprite.material as ShaderMaterial
				if shader_material:
					shader_material.set_shader_parameter(&"emission_glow", _visual_thrust)
	
	if _trail:
		_trail.call("set_emitting", _visual_thrust > 0.01)

func _update_player_thruster_audio() -> void:
	if not is_player_ship:
		return
	var audio_manager := _get_audio_manager()
	if audio_manager:
		audio_manager.call("set_player_thruster_intensity", _visual_thrust)

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
		var old_shield: float = current_shield
		current_shield = min(max_shield, current_shield + ship_data.shield_regen * delta)
		if old_shield <= 0.0 and current_shield > 0.0:
			if not _shield_active:
				activate_shield()
				_shield_active = true

func _apply_friction(delta: float) -> void:
	if velocity.length() < 1.0:
		velocity = Vector2.ZERO
		return
		
	var forward_dir: Vector2 = Vector2.from_angle(global_rotation)
	var lateral_dir: Vector2 = forward_dir.rotated(PI / 2.0)
	
	var forward_vel: float = velocity.dot(forward_dir)
	var lateral_vel: float = velocity.dot(lateral_dir)
	
	# Apply damping
	# Using (1.0 - damping * delta) approach for simple linear-ish friction
	forward_vel = lerp(forward_vel, 0.0, _forward_damping * delta * 10.0)
	lateral_vel = lerp(lateral_vel, 0.0, _lateral_damping * delta * 10.0)
	
	velocity = forward_dir * forward_vel + lateral_dir * lateral_vel

func _process_movement(delta: float) -> void:
	var to_target: Vector2 = target_position - global_position
	var distance: float = to_target.length()
	
	if distance < 10.0:
		is_moving = false
		return
		
	# 1. Rotation
	var target_angle: float = to_target.angle()
	global_rotation = rotate_toward(global_rotation, target_angle, _turn_speed * delta)
	
	# 2. Acceleration
	var forward_dir: Vector2 = Vector2.from_angle(global_rotation)
	var angle_diff: float = abs(angle_difference(global_rotation, target_angle))
	
	# Scale acceleration based on alignment (thrust factor)
	var thrust_factor: float = clamp(1.0 - (angle_diff / PI), 0.0, 1.0)
	
	# 3. Assisted Braking
	var speed_limit: float = _max_speed
	if distance < ship_data.arrival_radius:
		speed_limit = _max_speed * (distance / ship_data.arrival_radius)
	
	# Apply acceleration if below speed limit
	if velocity.length() < speed_limit:
		apply_acceleration(forward_dir * _acceleration * thrust_factor)
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
		if current_shield <= 0:
			# Shield broke this hit: spill the basic weapon's hull damage through.
			current_hull -= hull_dmg
			current_shield = 0.0
			if _shield_active:
				deactivate_shield()
				_shield_active = false
	else:
		current_hull -= hull_dmg

	_update_damage_marker_effects()
	_on_damage_taken(hull_dmg, shield_dmg, attacker)
		
	if current_hull <= 0:
		_die()

func _on_damage_taken(_hull_dmg: float, _shield_dmg: float, _attacker: Node2D) -> void:
	pass

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
	_update_damage_marker_effects()
	_on_ship_respawned()

func _on_ship_respawned() -> void:
	pass

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	is_moving = false
	velocity = Vector2.ZERO
	if is_player_ship:
		var audio_manager := _get_audio_manager()
		if audio_manager:
			audio_manager.call("set_player_thruster_intensity", 0.0)
	# Hide or explode
	visible = false
	if _trail:
		_trail.call("stop_emitting")
		_trail.call("set_target", null)
		_trail = null

	_update_damage_marker_effects()
	_on_ship_destroyed(_last_attacker)
		
	print(name, " destroyed!")
	var event_bus := get_node_or_null(^"/root/EventBus")
	if event_bus:
		event_bus.call("emit_signal", &"ship_destroyed", self, _last_attacker)

func _on_ship_destroyed(_killer: Node2D) -> void:
	pass
	
func is_enemy() -> bool:
	return faction_data != null # Simple check for MVP

func activate_shield(duration: float = 2) -> void:
	var mat: ShaderMaterial = _shield_sprite.material as ShaderMaterial
	if not mat: return
	
	# Create a smooth opening animation from 0 to target shield angle
	var target_angle: float = ship_data.shield_angle if ship_data else 360.0
	var tween: Tween = create_tween()
	tween.tween_method(set_shield_angle, 0.0, target_angle, duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

func deactivate_shield(duration: float = 0.4) -> void:
	var mat: ShaderMaterial = _shield_sprite.material as ShaderMaterial
	if not mat: return
	
	# Shrink it back down to the tip when collapsing
	var start_angle: float = ship_data.shield_angle if ship_data else 360.0
	var tween: Tween = create_tween()
	tween.tween_method(set_shield_angle, start_angle, 0.0, duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)

# Helper function because we are animating a shader parameter
func set_shield_angle(value: float) -> void:
	var mat: ShaderMaterial = _shield_sprite.material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter("shield_angle", value)
