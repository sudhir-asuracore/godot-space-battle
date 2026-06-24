extends Sprite2D
class_name DefenseTurret

const PROJECTILE_SCENE := preload("res://scenes/ship/accessories/Projectile.tscn")

var faction_data: FactionData = null
var homebase: Homebase = null

@onready var _muzzle: Marker2D = get_node_or_null(^"Muzzle")

var _target: Variant = null
var _shot_timer: float = 0.0

func configure(faction: FactionData, owner_homebase: Homebase) -> void:
	faction_data = faction
	homebase = owner_homebase

func _process(delta: float) -> void:
	if not faction_data or not homebase:
		return

	_shot_timer = maxf(0.0, _shot_timer - delta)

	if not _is_valid_target(_target):
		_target = _find_target()

	var target := _target as Node2D
	if not target:
		return

	_rotate_turret_towards(target, delta)

	if _shot_timer > 0.0:
		return

	if not _is_target_in_attack_band(target):
		return

	if not _is_target_in_attack_cone(target):
		return

	_fire_projectile(target)
	_shot_timer = 1.0 / maxf(0.01, faction_data.turret_fire_rate)

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
	if not _is_target_in_attack_band(node):
		return false
	if "faction_data" in node and node.faction_data == faction_data:
		return false
	return true

func _is_target_in_attack_band(target: Node2D) -> bool:
	var dist := global_position.distance_to(target.global_position)
	return dist >= faction_data.turret_min_attack_range and dist <= faction_data.turret_attack_range

func _rotate_turret_towards(target: Node2D, delta: float) -> void:
	var desired_angle := global_position.direction_to(target.global_position).angle()
	global_rotation = rotate_toward(global_rotation, desired_angle, maxf(0.0, faction_data.turret_turn_speed) * delta)

func _is_target_in_attack_cone(target: Node2D) -> bool:
	var forward := Vector2.RIGHT.rotated(global_rotation)
	var to_target := global_position.direction_to(target.global_position)
	var angle_diff_deg := absf(rad_to_deg(forward.angle_to(to_target)))
	return angle_diff_deg <= maxf(0.0, faction_data.turret_attack_cone_degrees) * 0.5

func _fire_projectile(target: Node2D) -> void:
	var projectile := PROJECTILE_SCENE.instantiate() as Projectile
	if not projectile:
		return

	var origin := _muzzle.global_position if _muzzle else global_position
	projectile.global_position = origin
	projectile.direction = origin.direction_to(target.global_position).normalized()
	projectile.speed = faction_data.turret_projectile_speed
	projectile.damage_hull = faction_data.turret_hull_damage
	projectile.damage_shield = faction_data.turret_shield_damage
	projectile.source_ship = self

	get_tree().root.add_child(projectile)