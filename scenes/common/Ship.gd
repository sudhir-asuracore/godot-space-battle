extends CharacterBody2D
class_name Ship

@export var ship_data: ShipData
@export var faction_data: FactionData
@export_range(5.0, 100.0, 5) var damage_flame_scale_factor: float = 50.0
# Multiplies the rear-thruster plume length so larger hulls can show longer
# flames. The base intensity-to-scale mapping is tuned for the smallest ships;
# bigger ships scale it up here. Defaults to 1.0 so existing ships are unchanged.
@export_range(0.5, 20.0, 0.5) var thruster_flame_scale_factor: float = 1.0

# Current state
var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false
var current_hull: float = 0.0
var current_shield: float = 0.0
var current_capacitor: float = 0.0
var is_dead: bool = false
var is_player_ship: bool = false
# Debug cheat: when enabled the ship's hull never takes damage (shields still work).
var infinite_hull: bool = false

@onready var _engine: Marker2D = get_node_or_null(^"Engine") as Marker2D
@onready var _shield_sprite: ColorRect = get_node_or_null(^"Shield") as ColorRect


const RIBBON_TRAIL_SCENE = preload("res://scenes/common/effects/RibbonTrail.tscn")
const DAMAGE_MARKER_EFFECT_SCENE = preload("res://scenes/common/effects/DamageMarkerEffect.tscn")
const SHIP_EXPLOSION_SCENE = preload("res://scenes/common/effects/ExplosionSprite.tscn")
const DEATH_EXPLOSION_NODE_NAME := &"death_explosion"
const DAMAGE_MARKER_PREFIX := "damage_"
const THRUSTER_NODE_PREFIX := "thruster_"
const ENGINE_NODE_PREFIX := "engine_"
const COLLISION_NODE_PREFIX := "collision_"

# Texture level-of-detail. Ships may provide up to three Sprite2D children
# (lod_near / lod_medium / lod_far) holding the same artwork at decreasing
# resolutions. The appropriate one is shown based on the active camera zoom so
# the hull stays crisp when zoomed in and avoids shimmering when zoomed out.
# Ordered from highest detail to lowest; each level is shown while the camera
# zoom is at or above its minimum threshold.
const LOD_LEVELS: Array[Dictionary] = [
	{"name": &"lod_near", "min_zoom": 1.6},
	{"name": &"lod_medium", "min_zoom": 0.6},
	{"name": &"lod_far", "min_zoom": 0.0},
]

# Per-direction multipliers applied to incoming damage. Only directions that
# have a matching collision_<dir> shape on the ship are used; everything else
# falls back to 1.0. Rear is the most vulnerable, the front the least.
const DIRECTIONAL_DAMAGE_MULTIPLIERS := {
	&"front": 0.6,
	&"left": 1.0,
	&"right": 1.0,
	&"rear": 1.6,
}

var _trail: Node = null
var _trails: Array[Node] = []
var _engines: Array[Marker2D] = []
var _collision_directions: Dictionary = {}
var _damage_markers: Array[Marker2D] = []
var _damage_marker_effects: Array[Node2D] = []
var _thruster_entries: Array[Dictionary] = []
var _thrusters_by_category: Dictionary = {}
# Ordered list of available texture LOD sprites (highest detail first) and the
# name of the level currently shown so we only toggle visibility on change.
var _lod_sprites: Array[Dictionary] = []
var _current_lod: StringName = &""

# Internal calculated stats (data + faction multipliers)
var max_hull: float
var max_shield: float
var max_capacitor: float
var _max_speed: float
var _acceleration: float
var _turn_speed: float
var _turn_acceleration: float
var _strafe_speed: float
var _reverse_speed: float
var _forward_damping: float
var _lateral_damping: float
var _braking_strength: float

# Current angular velocity (radians/second). Turning ramps this toward the
# desired rate rather than rotating the ship directly, giving rotational
# inertia so the hull feels heavy (eases in and coasts out of turns).
var _angular_velocity: float = 0.0

var _thrust_intensity: float = 0.0
var _visual_thrust: float = 0.0
# Per-side thruster intensities (driven by the Q/E turn input). Keys: "left"/"right".
var _side_thrust_intensity: Dictionary = {&"left": 0.0, &"right": 0.0}
var _visual_side_thrust: Dictionary = {&"left": 0.0, &"right": 0.0}

var _shield_regen_delay_timer: float = 0.0
var _last_attacker: Node2D = null
var _shield_active: bool = true
# Tracks the ship_data the current vitals (hull/shield/capacitor) were
# initialized from. When a spawner assigns ship_data after the scene's _ready
# ran (so update_stats first executed against a fallback resource), the vitals
# must be re-initialized against the real resource instead of being preserved.
var _vitals_initialized_for: ShipData = null
# Cached AudioManager autoload reference (resolved once; the singleton lives for
# the whole game so the per-frame node-path lookup is avoidable).
var _audio_manager: Node = null

func _ready() -> void:
	_before_ship_ready()
	add_to_group("ships")
	target_position = global_position
	_cache_engines()
	_cache_collision_directions()
	_cache_thrusters()
	update_stats()
	_duplicate_runtime_materials()
	_initialize_ship_visuals()
	_cache_lod_sprites()
	_update_lod()
	_after_ship_ready()

func _process(_delta: float) -> void:
	# Presentation-only: keep the visible texture LOD in sync with camera zoom.
	_update_lod()

func _exit_tree() -> void:
	if is_player_ship:
		var audio_manager := _get_audio_manager()
		if audio_manager:
			audio_manager.call("stop_player_thruster_audio", true)

func _get_audio_manager() -> Node:
	if _audio_manager == null or not is_instance_valid(_audio_manager):
		_audio_manager = get_node_or_null(^"/root/AudioManager")
	return _audio_manager

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

func _cache_engines() -> void:
	# Collect every engine_<index> Marker2D so each one can drive its own
	# thruster trail. Falls back to a legacy single "Engine" node if present.
	_engines.clear()

	for child in get_children():
		var engine_marker := child as Marker2D
		if not engine_marker:
			continue
		var engine_name := str(engine_marker.name)
		if not engine_name.begins_with(ENGINE_NODE_PREFIX):
			continue
		var index_text := engine_name.substr(ENGINE_NODE_PREFIX.length())
		if index_text.is_valid_int():
			_engines.append(engine_marker)

	_engines.sort_custom(func(a: Marker2D, b: Marker2D) -> bool:
		return _engine_index(a.name) < _engine_index(b.name)
	)

	if _engines.is_empty() and _engine != null:
		_engines.append(_engine)

func _engine_index(engine_name: StringName) -> int:
	var engine_name_text := str(engine_name)
	if not engine_name_text.begins_with(ENGINE_NODE_PREFIX):
		return 1_000_000
	var index_text := engine_name_text.substr(ENGINE_NODE_PREFIX.length())
	if index_text.is_valid_int():
		return index_text.to_int()
	return 1_000_000

func _cache_collision_directions() -> void:
	# Record which collision_<dir> shapes exist so directional damage scaling
	# only kicks in for directions the ship actually models.
	_collision_directions.clear()

	for child in get_children():
		var collision_shape := child as CollisionShape2D
		if not collision_shape:
			continue
		var collision_name := str(collision_shape.name)
		if not collision_name.begins_with(COLLISION_NODE_PREFIX):
			continue
		var direction := collision_name.substr(COLLISION_NODE_PREFIX.length())
		if direction.is_empty():
			continue
		_collision_directions[StringName(direction)] = collision_shape

func _cache_lod_sprites() -> void:
	# Collect the lod_near / lod_medium / lod_far Sprite2D children (in detail
	# order) so render logic can switch between them by camera zoom. Ships that
	# don't define LOD sprites simply end up with an empty list and are left to
	# render whatever single sprite they ship with.
	_lod_sprites.clear()
	_current_lod = &""

	for level in LOD_LEVELS:
		var level_name: StringName = level.get("name", &"")
		var sprite := get_node_or_null(NodePath(String(level_name))) as Sprite2D
		if sprite:
			_lod_sprites.append({
				"name": level_name,
				"sprite": sprite,
				"min_zoom": float(level.get("min_zoom", 0.0)),
			})

func _update_lod() -> void:
	# No LOD sprites means this ship uses a single static sprite: nothing to do.
	if _lod_sprites.size() < 2:
		if _lod_sprites.size() == 1 and _current_lod == &"":
			var only := _lod_sprites[0]
			(only["sprite"] as Sprite2D).visible = true
			_current_lod = only["name"]
		return

	var zoom := _get_camera_zoom()
	var selected: Dictionary = _select_lod_level(zoom)
	var selected_name: StringName = selected.get("name", &"")
	if selected_name == _current_lod:
		return

	_current_lod = selected_name
	for entry in _lod_sprites:
		var sprite := entry["sprite"] as Sprite2D
		if sprite:
			sprite.visible = entry["name"] == selected_name

func _select_lod_level(zoom: float) -> Dictionary:
	# Pick the highest-detail level whose minimum zoom threshold is satisfied.
	# LOD entries are stored highest-detail first, so the first match wins; the
	# lowest-detail level (min_zoom 0.0) is the guaranteed fallback.
	for entry in _lod_sprites:
		if zoom >= float(entry.get("min_zoom", 0.0)):
			return entry
	return _lod_sprites[_lod_sprites.size() - 1]

func _get_camera_zoom() -> float:
	if not is_inside_tree():
		return 1.0
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return 1.0
	return camera.zoom.x

func _initialize_ship_visuals() -> void:
	_setup_trail()
	_cache_damage_markers()
	_setup_damage_marker_effects()
	_update_damage_marker_effects()

func _setup_trail() -> void:
	if not ship_data or not is_inside_tree():
		return

	# Tear down any trails left over from a previous life so they can fade out
	# and clean themselves up.
	_clear_trails()

	# Render one trail per engine marker. Ships without explicit engine markers
	# fall back to a single trail emitted from the ship origin.
	var trail_targets: Array[Node2D] = []
	if _engines.is_empty():
		trail_targets.append(self)
	else:
		for engine_marker in _engines:
			trail_targets.append(engine_marker)

	for trail_target in trail_targets:
		var trail: Node = RIBBON_TRAIL_SCENE.instantiate()
		# Add as sibling so it's in world space but managed by the same parent.
		get_parent().add_child(trail)
		trail.call("setup", ship_data)
		trail.call("set_target", trail_target)
		trail.call("set_emitting", false)
		_trails.append(trail)

	# Keep the legacy single-trail reference pointing at the first trail so any
	# external code relying on it keeps working.
	_trail = _trails[0] if not _trails.is_empty() else null

func _clear_trails() -> void:
	for trail in _trails:
		if trail and is_instance_valid(trail):
			trail.call("stop_emitting")
			trail.call("set_target", null)
	_trails.clear()
	_trail = null

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

	# Resolve allegiance straight from the ship resource when a faction was not
	# supplied externally, so a directly-instantiated ship scene is still tied
	# to its own faction instead of silently running with default multipliers.
	if faction_data == null:
		faction_data = ship_data.resolve_faction_data()

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
	_turn_acceleration = ship_data.turn_acceleration * turn_mult
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
	
	# Initialize vitals when they have never been set, or when the ship_data has
	# changed since the last initialization (e.g. a spawner assigned the real
	# resource after _ready already ran update_stats against a fallback). Without
	# the data-changed check, current_hull would stay pinned to the fallback's
	# smaller max_hull and the ship would spawn looking damaged.
	if current_hull <= 0 or _vitals_initialized_for != ship_data:
		current_hull = max_hull
		current_shield = max_shield
		current_capacitor = max_capacitor
		_vitals_initialized_for = ship_data

		# Rebuild the engine trail against the (possibly newly assigned) ship_data
		# so trail styling (thickness/length/color) follows the real resource
		# instead of a fallback that was active when _ready first ran.
		if is_inside_tree():
			_setup_trail()
		
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
	# A/D (or Q/E) manually turn (point) the ship. Negative = turn left
	# (counter-clockwise), positive = turn right (clockwise).
	var turn_input: float = 0.0
	if InputMap.has_action("turn_left") and Input.is_action_pressed("turn_left"):
		turn_input -= 1.0
	if InputMap.has_action("turn_right") and Input.is_action_pressed("turn_right"):
		turn_input += 1.0

	# Drive the side-thruster VFX from the turn input. Turning the nose left
	# fires the right-hand thrusters (their push rotates the bow left) and
	# turning right fires the left-hand thrusters.
	_side_thrust_intensity[&"right"] = 1.0 if turn_input < 0.0 else 0.0
	_side_thrust_intensity[&"left"] = 1.0 if turn_input > 0.0 else 0.0

	if not is_zero_approx(turn_input):
		# Manual steering takes over from any click-to-move heading.
		is_moving = false
		_apply_turn_toward_rate(turn_input * _turn_speed, delta)
	elif not is_moving:
		# No steering input and not navigating: let the spin bleed off through
		# its inertia so the ship coasts to a stop instead of halting instantly.
		_apply_turn_toward_rate(0.0, delta)

	# W drives the ship forward, S brakes / reverses it.
	var forward_input: bool = InputMap.has_action("thrust_forward") and Input.is_action_pressed("thrust_forward")
	var reverse_input: bool = InputMap.has_action("reverse_thrust") and Input.is_action_pressed("reverse_thrust")

	# Manual thrust also overrides any click-to-move heading.
	if forward_input or reverse_input:
		is_moving = false

	if is_zero_approx(turn_input) and not forward_input and not reverse_input:
		return false

	var forward_dir: Vector2 = Vector2.from_angle(global_rotation)
	var lateral_dir: Vector2 = forward_dir.rotated(PI / 2.0)
	var forward_vel: float = velocity.dot(forward_dir)
	var lateral_vel: float = velocity.dot(lateral_dir)

	# Forward thrust wins over reverse when both are held.
	if forward_input:
		forward_vel = move_toward(forward_vel, _max_speed, _acceleration * delta)
		_thrust_intensity = max(_thrust_intensity, 1.0)
	elif reverse_input:
		forward_vel = move_toward(forward_vel, -_reverse_speed, _acceleration * delta)
		_thrust_intensity = max(_thrust_intensity, 0.25)

	velocity = forward_dir * forward_vel + lateral_dir * lateral_vel
	return true

# Eases the ship's angular velocity toward a requested turn rate (radians/sec)
# instead of rotating instantly, then integrates it into the heading. The
# turn_acceleration stat caps how fast that rate can change, giving the hull
# rotational inertia so it feels heavy. A non-positive turn_acceleration falls
# back to instant turning (no inertia).
func _apply_turn_toward_rate(desired_rate: float, delta: float) -> void:
	if _turn_acceleration > 0.0:
		_angular_velocity = move_toward(_angular_velocity, desired_rate, _turn_acceleration * delta)
	else:
		_angular_velocity = desired_rate
	if not is_zero_approx(_angular_velocity):
		global_rotation += _angular_velocity * delta

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
	_visual_side_thrust[&"left"] = move_toward(_visual_side_thrust[&"left"], _side_thrust_intensity[&"left"], delta * 8.0)
	_visual_side_thrust[&"right"] = move_toward(_visual_side_thrust[&"right"], _side_thrust_intensity[&"right"], delta * 8.0)

	# Each thruster group reacts to the relevant intensity: rear thrusters track
	# forward thrust, while the left/right side thrusters track the turn input.
	for thruster_entry in _thruster_entries:
		var category: StringName = thruster_entry.get("category", &"")
		var intensity: float = _visual_thrust
		if _visual_side_thrust.has(category):
			intensity = _visual_side_thrust[category]
		_apply_thruster_intensity(thruster_entry, intensity)

	# Drive every engine trail from the forward thrust.
	var trail_emitting: bool = _visual_thrust > 0.01
	for trail in _trails:
		if trail and is_instance_valid(trail):
			trail.call("set_emitting", trail_emitting)

func _apply_thruster_intensity(thruster_entry: Dictionary, intensity: float) -> void:
	var clamped_intensity: float = clampf(intensity, 0.0, 1.0)
	var thrust_scale: float = lerp(0.008, 0.05, clamped_intensity) * thruster_flame_scale_factor

	var thruster_node := thruster_entry.get("node") as Node2D
	if thruster_node:
		thruster_node.scale.y = thrust_scale

	var thruster_sprite := thruster_entry.get("sprite") as Sprite2D
	if thruster_sprite and thruster_sprite.material:
		var shader_material := thruster_sprite.material as ShaderMaterial
		if shader_material:
			shader_material.set_shader_parameter(&"emission_glow", clamped_intensity)

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
	var final_distance: float = global_position.distance_to(target_position)
	if final_distance < 10.0:
		is_moving = false
		return

	var to_target: Vector2 = target_position - global_position
	var distance: float = to_target.length()
	if distance < 1.0:
		return
	
	# 1. Rotation. Steer toward the target through the ship's angular inertia
	# (heavy feel) rather than snapping the heading. The desired turn rate is
	# whatever closes the remaining angle this frame, capped at _turn_speed.
	var target_angle: float = to_target.angle()
	var angle_error: float = angle_difference(global_rotation, target_angle)

	# Cap the requested turn rate so the ship can still decelerate to a stop
	# before the heading reaches the target (otherwise it keeps spinning at top
	# speed, overshoots, and wobbles left/right because the angular inertia can't
	# brake in time). This is the rotational analogue of braking distance: given
	# the available turn acceleration, we limit the turn rate to the fastest one
	# that can still bleed off over the remaining angle. Capping at this value
	# makes _apply_turn_toward_rate ease the angular velocity down (reverse turn
	# thrust) as the ship approaches alignment.
	#
	# We use the discrete-time braking limit rather than the idealised
	# sqrt(2 * accel * angle): integrating at a fixed timestep travels a little
	# further per step than the continuous formula predicts, so the naive cap
	# still overshoots by one frame. Solving v^2 + (accel*dt)*v - 2*accel*angle
	# <= 0 for v gives the rate that stops exactly on target without overshoot.
	var max_rate: float = _turn_speed
	if _turn_acceleration > 0.0:
		var a_dt: float = _turn_acceleration * delta
		var brake_rate: float = (-a_dt + sqrt(a_dt * a_dt + 8.0 * _turn_acceleration * abs(angle_error))) / 2.0
		max_rate = min(_turn_speed, brake_rate)
	var desired_rate: float = clampf(angle_error / delta, -max_rate, max_rate)

	# Drive the side-thruster VFX from the turn the auto-nav is actually
	# commanding, just like manual steering does. We key off the change the
	# turn requires (desired_rate vs the current spin) rather than the heading
	# error so the correct thruster also fires while braking the turn: easing a
	# leftward spin back down fires the opposite (reverse) thruster. Firing the
	# right-hand thrusters rotates the bow left (negative rate) and the left-hand
	# thrusters rotate it right (positive rate), matching the manual convention.
	var turn_thrust: float = desired_rate - _angular_velocity
	_side_thrust_intensity[&"right"] = 1.0 if turn_thrust < 0.0 else 0.0
	_side_thrust_intensity[&"left"] = 1.0 if turn_thrust > 0.0 else 0.0

	_apply_turn_toward_rate(desired_rate, delta)
	
	# 2. Acceleration
	var forward_dir: Vector2 = Vector2.from_angle(global_rotation)
	var angle_diff: float = abs(angle_difference(global_rotation, target_angle))
	
	# Scale acceleration based on alignment (thrust factor)
	var thrust_factor: float = clamp(1.0 - (angle_diff / PI), 0.0, 1.0)
	
	# 3. Assisted Braking
	var speed_limit: float = _max_speed
	if final_distance < ship_data.arrival_radius:
		speed_limit = _max_speed * (final_distance / ship_data.arrival_radius)
	
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
	# Debug cheat: ignore all hull damage while invulnerable.
	if infinite_hull:
		hull_dmg = 0.0

	# Scale incoming damage by the impacted side. Hits to weaker faces (rear)
	# hurt more than hits to the reinforced bow.
	var directional_multiplier: float = _get_directional_damage_multiplier(attacker)
	hull_dmg *= directional_multiplier
	shield_dmg *= directional_multiplier

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

func _get_directional_damage_multiplier(attacker: Node2D) -> float:
	# No attacker reference (e.g. environmental damage) means no directional bias.
	if attacker == null or not is_instance_valid(attacker):
		return 1.0
	if _collision_directions.is_empty():
		return 1.0

	var to_attacker: Vector2 = attacker.global_position - global_position
	if to_attacker.length_squared() <= 0.0001:
		return 1.0

	# Express the hit direction in the ship's local frame where +x is forward
	# and +y is the ship's right-hand (starboard) side.
	var local_angle: float = to_attacker.rotated(-global_rotation).angle()
	var direction: StringName = _hit_direction_from_angle(local_angle)

	# Only bias damage for directions the ship actually models with a collider.
	if not _collision_directions.has(direction):
		return 1.0
	return float(DIRECTIONAL_DAMAGE_MULTIPLIERS.get(direction, 1.0))

func _hit_direction_from_angle(local_angle: float) -> StringName:
	var abs_angle: float = abs(local_angle)
	if abs_angle <= PI / 4.0:
		return &"front"
	if abs_angle >= 3.0 * PI / 4.0:
		return &"rear"
	# Positive local angle points toward +y (the ship's right side).
	return &"right" if local_angle > 0.0 else &"left"

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
	# Trigger the ship's embedded death-explosion node (if it provides one) so its
	# bespoke explosion animation/audio plays as the hull disappears. If the ship
	# supplies its own death explosion, skip the generic destruction explosion.
	if not _trigger_death_explosion():
		# Spawn the destruction explosion (scaled to the ship size) then hide the hull.
		_spawn_destruction_explosion()
	visible = false
	_clear_trails()

	_update_damage_marker_effects()
	_on_ship_destroyed(_last_attacker)
		
	print(name, " destroyed!")
	var event_bus := get_node_or_null(^"/root/EventBus")
	if event_bus:
		event_bus.call("emit_signal", &"ship_destroyed", self, _last_attacker)

func _on_ship_destroyed(_killer: Node2D) -> void:
	pass

## Plays the ship's embedded "death_explosion" node, if present. The node is
## hidden during normal play; on death it is reparented to the ship's parent so
## it stays visible (the hull itself is hidden right after) and survives the
## ship being freed, then it plays and self-frees once finished.
## Returns true if an embedded death-explosion node was found and triggered.
func _trigger_death_explosion() -> bool:
	var death_explosion := get_node_or_null(NodePath(DEATH_EXPLOSION_NODE_NAME)) as Node2D
	if death_explosion == null:
		return false
	var spawn_parent: Node = get_parent()
	if spawn_parent:
		# reparent keeps the global transform, so the explosion stays put.
		death_explosion.reparent(spawn_parent)
	death_explosion.visible = true
	if death_explosion.has_method("play"):
		death_explosion.call("play")
	return true

func _spawn_destruction_explosion() -> void:
	var spawn_parent: Node = get_parent()
	if spawn_parent == null:
		return
	# Spawn the one-shot explosion sprite (it plays its animation + audio and
	# frees itself once the effect is over).
	var explosion := SHIP_EXPLOSION_SCENE.instantiate() as Node2D
	if explosion == null:
		return
	spawn_parent.add_child(explosion)
	explosion.global_position = global_position
	explosion.global_rotation = global_rotation
	
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
