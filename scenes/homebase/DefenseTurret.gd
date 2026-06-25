extends Sprite2D
class_name DefenseTurret

const PROJECTILE_SCENE := preload("res://scenes/ship/accessories/Projectile.tscn")
const ENERGY_BEAM_SCENE := preload("res://scenes/ship/accessories/EnergyBeam.tscn")
const WEAPON_COVERAGE_OVERLAY_SCRIPT := preload("res://scripts/WeaponCoverageOverlay.gd")
const DEFENSE_HITBOX_RADIUS := 170.0

var faction_data: FactionData = null
var homebase: Homebase = null
var max_hull: float = 1.0
var current_hull: float = 1.0
var is_destroyed: bool = false

@onready var _muzzle: Marker2D = get_node_or_null(^"Muzzle")

var _target: Variant = null
# Independent cooldown timer per configured weapon (keyed by weapon name).
var _weapon_timers: Dictionary = {}
var _coverage_overlay = null
var _hitbox: Area2D = null
var _repair_cooldown: float = 0.0

# Combined weapon stats are derived purely from the (static) faction data, so
# they are computed once per configuration instead of every frame.
var _combined_stats_valid: bool = false
var _cached_attack_range: float = 0.0
var _cached_min_attack_range: float = 0.0
var _cached_turn_speed: float = 0.0
var _cached_attack_cone_degrees: float = 0.0

func _ready() -> void:
	add_to_group("homebase_defenses")
	_ensure_hitbox()
	_ensure_coverage_overlay()
	_apply_destroyed_state()

func configure(faction: FactionData, owner_homebase: Homebase) -> void:
	faction_data = faction
	homebase = owner_homebase
	_combined_stats_valid = false
	max_hull = maxf(1.0, faction_data.defense_structure_max_hull) if faction_data else 420.0
	current_hull = max_hull
	is_destroyed = false
	_repair_cooldown = 0.0
	_ensure_hitbox()
	_apply_destroyed_state()
	_sync_coverage_overlay()

func _process(delta: float) -> void:
	if not faction_data or not homebase:
		_set_coverage_overlay_visible(false)
		return

	_process_repair(delta)
	if is_destroyed:
		_target = null
		_set_coverage_overlay_visible(false)
		return

	_sync_coverage_overlay()

	_tick_weapon_timers(delta)

	if not _is_valid_target(_target):
		_target = _find_target()

	var target := _target as Node2D
	if not target:
		return

	_rotate_turret_towards(target, delta)

	_fire_weapons(target)

func _tick_weapon_timers(delta: float) -> void:
	for weapon in _weapon_timers.keys():
		_weapon_timers[weapon] = maxf(0.0, _weapon_timers[weapon] - delta)

func _fire_weapons(target: Node2D) -> void:
	for weapon in faction_data.get_turret_weapons():
		if _weapon_timers.get(weapon, 0.0) > 0.0:
			continue
		if not _is_target_in_weapon_band(weapon, target):
			continue
		if not _is_target_in_weapon_cone(weapon, target):
			continue

		_fire_weapon(weapon, target)
		_weapon_timers[weapon] = _weapon_cooldown(weapon)

# Cooldown before a weapon may fire again. Beam weapons stay active for their
# whole duration, so they only re-fire once the previous beam has expired.
func _weapon_cooldown(weapon: String) -> float:
	var cooldown := 1.0 / maxf(0.01, faction_data.turret_weapon_fire_rate(weapon))
	if faction_data.turret_weapon_is_beam(weapon):
		cooldown = maxf(cooldown, faction_data.turret_weapon_beam_duration(weapon))
	return cooldown

func _find_target() -> Node2D:
	var best_target: Node2D = null
	var best_dist: float = INF

	for ship in get_tree().get_nodes_in_group("ships"):
		var candidate := ship as Node2D
		if not _is_valid_target(candidate):
			continue
		var dist := global_position.distance_to(candidate.global_position)
		if dist < best_dist:
			best_dist = dist
			best_target = candidate

	for hb in get_tree().get_nodes_in_group("homebases"):
		var candidate := hb as Node2D
		if not _is_valid_target(candidate):
			continue
		var dist := global_position.distance_to(candidate.global_position)
		if dist < best_dist:
			best_dist = dist
			best_target = candidate

	return best_target

func _is_valid_target(candidate: Variant) -> bool:
	if not candidate or not is_instance_valid(candidate):
		return false
	if not candidate is Node2D:
		return false
	var node := candidate as Node2D
	if not node:
		return false
	if node == homebase:
		return false
	if node is Ship and node.is_dead:
		return false
	if "is_destroyed" in node and node.is_destroyed:
		return false
	if not _is_target_in_attack_band(node):
		return false
	if "faction_data" in node and node.faction_data == faction_data:
		return false
	return true

# The turret can engage as long as a target is within the band of any of its
# weapons. Individual weapons re-check their own band before firing.
func _is_target_in_attack_band(target: Node2D) -> bool:
	var dist := global_position.distance_to(target.global_position)
	return dist >= _combined_min_attack_range() and dist <= _combined_attack_range()

func _is_target_in_weapon_band(weapon: String, target: Node2D) -> bool:
	var dist := global_position.distance_to(target.global_position)
	return dist >= faction_data.turret_weapon_min_attack_range(weapon) and dist <= faction_data.turret_weapon_attack_range(weapon)

func _rotate_turret_towards(target: Node2D, delta: float) -> void:
	var desired_angle := global_position.direction_to(target.global_position).angle()
	global_rotation = rotate_toward(global_rotation, desired_angle, maxf(0.0, _combined_turn_speed()) * delta)

func _is_target_in_weapon_cone(weapon: String, target: Node2D) -> bool:
	var forward := Vector2.RIGHT.rotated(global_rotation)
	var to_target := global_position.direction_to(target.global_position)
	var angle_diff_deg := absf(rad_to_deg(forward.angle_to(to_target)))
	return angle_diff_deg <= maxf(0.0, faction_data.turret_weapon_attack_cone_degrees(weapon)) * 0.5

# Turret level cone test using the widest configured weapon cone.
func _is_target_in_attack_cone(target: Node2D) -> bool:
	var forward := Vector2.RIGHT.rotated(global_rotation)
	var to_target := global_position.direction_to(target.global_position)
	var angle_diff_deg := absf(rad_to_deg(forward.angle_to(to_target)))
	return angle_diff_deg <= maxf(0.0, _combined_attack_cone_degrees()) * 0.5

# Computes the combined weapon stats once and caches them. They only depend on
# the static faction data, so recomputing every frame (and per helper call) was
# wasted work on the turret hot path.
func _ensure_combined_stats() -> void:
	if _combined_stats_valid or not faction_data:
		return

	var range_best := 0.0
	var min_best := INF
	var turn_best := 0.0
	var cone_best := 0.0
	for weapon in faction_data.get_turret_weapons():
		range_best = maxf(range_best, faction_data.turret_weapon_attack_range(weapon))
		min_best = minf(min_best, faction_data.turret_weapon_min_attack_range(weapon))
		turn_best = maxf(turn_best, faction_data.turret_weapon_turn_speed(weapon))
		cone_best = maxf(cone_best, faction_data.turret_weapon_attack_cone_degrees(weapon))

	_cached_attack_range = range_best
	_cached_min_attack_range = min_best if min_best != INF else 0.0
	_cached_turn_speed = turn_best
	_cached_attack_cone_degrees = cone_best
	_combined_stats_valid = true

func _combined_attack_range() -> float:
	_ensure_combined_stats()
	return _cached_attack_range

func _combined_min_attack_range() -> float:
	_ensure_combined_stats()
	return _cached_min_attack_range

func _combined_turn_speed() -> float:
	_ensure_combined_stats()
	return _cached_turn_speed

func _combined_attack_cone_degrees() -> float:
	_ensure_combined_stats()
	return _cached_attack_cone_degrees

# Backward compatible helper: fires every configured weapon at the target.
func _fire_projectile(target: Node2D) -> void:
	for weapon in faction_data.get_turret_weapons():
		_fire_weapon(weapon, target)

func _fire_weapon(weapon: String, target: Node2D) -> void:
	if faction_data.turret_weapon_is_beam(weapon):
		_fire_beam(weapon, target)
		return

	var projectile_scene := faction_data.turret_weapon_scene(weapon)
	if not projectile_scene:
		projectile_scene = PROJECTILE_SCENE

	for origin in _get_weapon_origins(weapon):
		var projectile := projectile_scene.instantiate() as Projectile
		if not projectile:
			continue

		projectile.global_position = origin
		projectile.direction = origin.direction_to(target.global_position).normalized()
		projectile.speed = faction_data.turret_weapon_speed(weapon)
		projectile.damage_hull = faction_data.turret_weapon_hull_damage(weapon)
		projectile.damage_shield = faction_data.turret_weapon_shield_damage(weapon)
		projectile.is_beam = faction_data.turret_weapon_is_beam(weapon)
		projectile.source_ship = self

		get_tree().root.add_child(projectile)

# Spawns a sustained energy beam for beam-type weapons. The beam grows out of
# each muzzle, tracks the target and applies its (low) damage over time for the
# configured duration.
func _fire_beam(weapon: String, target: Node2D) -> void:
	var beam_scene := faction_data.turret_weapon_scene(weapon)
	if not beam_scene:
		beam_scene = ENERGY_BEAM_SCENE

	for origin in _get_weapon_origins(weapon):
		var instance := beam_scene.instantiate()
		var beam := instance as EnergyBeam
		if not beam:
			# Configured scene is not an energy beam; fall back to the default.
			if instance:
				instance.free()
			beam = ENERGY_BEAM_SCENE.instantiate() as EnergyBeam
		if not beam:
			continue

		beam.global_position = origin
		beam.origin_node = self
		beam.origin_offset = to_local(origin)
		beam.target = target
		beam.source_ship = self
		beam.damage_hull_per_second = faction_data.turret_weapon_hull_damage(weapon)
		beam.damage_shield_per_second = faction_data.turret_weapon_shield_damage(weapon)
		beam.duration = faction_data.turret_weapon_beam_duration(weapon)
		beam.max_length = faction_data.turret_weapon_attack_range(weapon)

		get_tree().root.add_child(beam)

# Collects the firing positions for a weapon from its `<weapon>_0`, `<weapon>_1`
# muzzle markers. Falls back to the legacy `Muzzle` node or the turret centre
# when no dedicated markers are present.
func _get_weapon_origins(weapon: String) -> Array:
	var origins: Array = []

	if weapon != "":
		var index := 0
		while true:
			var marker := get_node_or_null(NodePath("%s_%d" % [weapon, index])) as Node2D
			if not marker:
				break
			origins.append(marker.global_position)
			index += 1

	if origins.is_empty():
		origins.append(_muzzle.global_position if _muzzle else global_position)

	return origins

func take_damage(hull_dmg: float, _shield_dmg: float, _attacker: Node2D = null) -> void:
	if hull_dmg <= 0.0:
		return

	current_hull = maxf(0.0, current_hull - hull_dmg)
	_repair_cooldown = _get_auto_repair_delay()
	if current_hull <= 0.0:
		_set_destroyed_state(true)

func _process_repair(delta: float) -> void:
	if _repair_cooldown > 0.0:
		_repair_cooldown = maxf(0.0, _repair_cooldown - delta)
		return

	if current_hull >= max_hull:
		return

	current_hull = min(max_hull, current_hull + _get_auto_repair_rate() * delta)
	if is_destroyed and current_hull > 0.0:
		_set_destroyed_state(false)

func _set_destroyed_state(destroyed: bool) -> void:
	if is_destroyed == destroyed:
		return

	is_destroyed = destroyed
	_target = null
	_weapon_timers.clear()
	_apply_destroyed_state()

func _apply_destroyed_state() -> void:
	visible = not is_destroyed
	if _hitbox and is_instance_valid(_hitbox):
		_hitbox.monitorable = not is_destroyed

func _get_auto_repair_rate() -> float:
	if not faction_data:
		return 0.0
	return maxf(0.0, faction_data.defense_structure_auto_repair_rate)

func _get_auto_repair_delay() -> float:
	if not faction_data:
		return 0.0
	return maxf(0.0, faction_data.defense_structure_auto_repair_delay)

func is_enemy() -> bool:
	return not is_destroyed

func _ensure_hitbox() -> void:
	if _hitbox and is_instance_valid(_hitbox):
		_hitbox.set_meta("damage_receiver", self)
		return

	_hitbox = get_node_or_null(^"Hitbox") as Area2D
	if not _hitbox:
		_hitbox = Area2D.new()
		_hitbox.name = "Hitbox"
		add_child(_hitbox)

	_hitbox.collision_layer = 1
	_hitbox.collision_mask = 0
	_hitbox.monitoring = false
	_hitbox.monitorable = true
	_hitbox.input_pickable = true
	_hitbox.set_meta("damage_receiver", self)

	var shape := _hitbox.get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if not shape:
		shape = CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		_hitbox.add_child(shape)

	if not shape.shape:
		var circle := CircleShape2D.new()
		circle.radius = DEFENSE_HITBOX_RADIUS
		shape.shape = circle

func _ensure_coverage_overlay() -> void:
	if _coverage_overlay and is_instance_valid(_coverage_overlay):
		return

	_coverage_overlay = WEAPON_COVERAGE_OVERLAY_SCRIPT.new()
	if not _coverage_overlay:
		return

	_coverage_overlay.name = "WeaponCoverageOverlay"
	add_child(_coverage_overlay)
	_coverage_overlay.follow(self)

func _set_coverage_overlay_visible(visible_now: bool) -> void:
	if not _coverage_overlay or not is_instance_valid(_coverage_overlay):
		return
	_coverage_overlay.set_overlay_visible(visible_now)

func _sync_coverage_overlay() -> void:
	_ensure_coverage_overlay()
	if not _coverage_overlay:
		return

	if not faction_data:
		_coverage_overlay.set_overlay_visible(false)
		return

	_coverage_overlay.set_overlay_visible(true)
	_coverage_overlay.set_coverage(
		_combined_attack_range(),
		_combined_min_attack_range(),
		_combined_attack_cone_degrees()
	)