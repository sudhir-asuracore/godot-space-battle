extends Node2D
class_name WeaponModule

# Self-contained weapon node attached to a weapon scene (e.g. ZarakWeapon_Cannon).
# The owning ship's WeaponController discovers this node, resolves which
# WeaponData it should fire from the ship's data and calls configure().
# From then on the weapon manages everything about itself:
#   * its coverage grid, drawn from the weapon's own centre (not the ship's),
#   * measuring range from the weapon,
#   * turning the barrel toward an in-range target (using the centre->muzzle
#     vector as the weapon's forward direction),
#   * its own fire cadence / reload, projectile, muzzle flash and audio.
# The controller stays a thin coordinator that only forwards the locked target.

const WEAPON_COVERAGE_OVERLAY_SCRIPT := preload("res://scripts/WeaponCoverageOverlay.gd")
const MUZZLE_NODE_PREFIX := "muzzle_"

var _weapon: WeaponData = null
var _ship: Node2D = null
var _configured: bool = false

# Captured parts of the weapon scene.
var _muzzle: Marker2D = null
var _muzzle_flash: Node = null
var _projectile_scene: PackedScene = null
var _projectile_template: Node = null

# The weapon's mounting orientation (local rotation authored in the ship scene)
# and the angle of the centre->muzzle offset, which together define where the
# barrel points at rest.
var _rest_local_rotation: float = 0.0
var _muzzle_local_angle: float = 0.0

var _coverage_overlay = null

# Independent fire timing so several weapons on one ship fire on their own
# schedules rather than sharing a single ship-level cadence.
var _shot_timer: float = 0.0
var _reload_timer: float = 0.0
var _ammo_in_mag: int = -1

func _ready() -> void:
	# The owning WeaponController drives this weapon via tick(), so it does not
	# need its own per-frame processing.
	set_process(false)

# Called once by the WeaponController with the WeaponData this slot fires and a
# reference to the owning ship. Captures the weapon scene's parts and prepares
# the coverage overlay.
func configure(weapon: WeaponData, ship: Node2D) -> void:
	_weapon = weapon
	_ship = ship
	_rest_local_rotation = rotation
	_capture_parts()
	_sync_ammo()
	_ensure_overlay()
	_configured = true

func _capture_parts() -> void:
	_muzzle = _find_muzzle()
	if _muzzle:
		_muzzle_local_angle = _muzzle.position.angle()
	_muzzle_flash = get_node_or_null(^"flash")
	_capture_projectile()

func _find_muzzle() -> Marker2D:
	# The muzzle marker inside the weapon scene is named muzzle_* (e.g.
	# muzzle_zarak_cannon_0) and marks where the projectile leaves the barrel.
	for child in get_children():
		var marker := child as Marker2D
		if marker and str(marker.name).begins_with(MUZZLE_NODE_PREFIX):
			return marker
	return null

func _capture_projectile() -> void:
	# The weapon scene ships with a `projectile` instance used purely as a
	# template. Remember how to respawn it (preferring its source scene so each
	# shot is a fresh instance) then remove the live template so it never acts
	# as a stray bullet sitting on the muzzle.
	var projectile_node := get_node_or_null(^"projectile")
	if not projectile_node:
		return

	if not String(projectile_node.scene_file_path).is_empty():
		_projectile_scene = load(projectile_node.scene_file_path) as PackedScene
	else:
		_projectile_template = projectile_node.duplicate()

	projectile_node.get_parent().remove_child(projectile_node)
	projectile_node.queue_free()

# Driven each frame by the WeaponController. `target` is the ship's locked
# target (may be null); `active` is false while the ship is dead or weapon
# logic is otherwise suspended.
func tick(delta: float, target: Node2D, active: bool) -> void:
	if not _configured or not _weapon:
		return

	_tick_timers(delta)

	var has_target := active and target != null and is_instance_valid(target)
	var in_range := has_target and _is_in_range(target)
	# A target can be in range but outside the turret's swing arc (e.g. behind a
	# side-mounted gun). The barrel still tracks toward it as far as the arc
	# allows, but the weapon only fires when the target is actually inside it.
	var in_arc := in_range and _is_within_arc(target.global_position)

	if in_range:
		_aim_at(target.global_position, delta)
	else:
		_return_to_rest(delta)

	_update_overlay(active)

	# A heavy turret may still be swinging onto the target; only fire once the
	# barrel has actually lined up (within the homing tolerance).
	if in_range and in_arc and _is_aimed_at(target.global_position) and _can_fire():
		_fire(target)

# --- Range & aiming -------------------------------------------------------

func _weapon_origin() -> Vector2:
	return global_position

func _is_in_range(target: Node2D) -> bool:
	return _weapon_origin().distance_to(target.global_position) <= _weapon.weapon_range

func _aim_at(target_pos: Vector2, delta: float) -> void:
	# Point the centre->muzzle vector at the target, clamped to the turret arc
	# so the barrel never swings past its allowed range. The barrel eases toward
	# that heading at turret_homing_speed so heavy turrets track slowly.
	var aim_angle := (target_pos - global_position).angle()
	var clamped := _clamp_to_arc(aim_angle)
	_rotate_toward_global(clamped - _muzzle_local_angle, delta)

# Eases the turret's global rotation toward a desired heading, capped at the
# weapon's turret_homing_speed (degrees/second). A non-positive homing speed
# snaps instantly (original behaviour).
func _rotate_toward_global(desired_global: float, delta: float) -> void:
	var rate := _homing_rate_rad()
	if rate <= 0.0:
		global_rotation = desired_global
	else:
		global_rotation = rotate_toward(global_rotation, desired_global, rate * delta)

# The turret's tracking speed in radians/second (0 or less = instant tracking).
func _homing_rate_rad() -> float:
	if _weapon and _weapon.turret_homing_speed > 0.0:
		return deg_to_rad(_weapon.turret_homing_speed)
	return 0.0

# True when the barrel's current forward direction is lined up with the target
# closely enough to fire. Instantly-tracking turrets are always considered
# aimed; homing turrets must first swing within half their attack cone.
func _is_aimed_at(target_pos: Vector2) -> bool:
	if _homing_rate_rad() <= 0.0:
		return true
	var aim_angle := (target_pos - global_position).angle()
	var current_forward := global_rotation + _muzzle_local_angle
	var tolerance := deg_to_rad(maxf(_weapon.attack_cone_degrees, 1.0)) * 0.5
	return absf(angle_difference(current_forward, aim_angle)) <= tolerance

func _is_within_arc(target_pos: Vector2) -> bool:
	# True when the target lies within the turret's swing arc, centred on the
	# weapon's home (mount-forward) direction. max_turret_angle >= 360 means the
	# turret rotates freely and every direction is allowed.
	if not _weapon or _weapon.max_turret_angle >= 360.0:
		return true
	var aim_angle := (target_pos - global_position).angle()
	var half := deg_to_rad(_weapon.max_turret_angle) * 0.5
	var delta := absf(wrapf(aim_angle - _mount_forward_global(), -PI, PI))
	return delta <= half

func _clamp_to_arc(desired_forward: float) -> float:
	# Limit a desired barrel direction to the turret's swing arc around its home
	# direction. Returns the desired direction unchanged when unrestricted.
	if not _weapon or _weapon.max_turret_angle >= 360.0:
		return desired_forward
	var rest_forward := _mount_forward_global()
	var half := deg_to_rad(_weapon.max_turret_angle) * 0.5
	var delta := clampf(wrapf(desired_forward - rest_forward, -PI, PI), -half, half)
	return rest_forward + delta

func _return_to_rest(delta: float) -> void:
	if _ship and is_instance_valid(_ship):
		_rotate_toward_global(_ship.global_rotation + _rest_local_rotation, delta)
	else:
		var rate := _homing_rate_rad()
		if rate <= 0.0:
			rotation = _rest_local_rotation
		else:
			rotation = rotate_toward(rotation, _rest_local_rotation, rate * delta)

func _mount_forward_global() -> float:
	# The direction the barrel points at rest, in global space.
	if _ship and is_instance_valid(_ship):
		return _ship.global_rotation + _rest_local_rotation + _muzzle_local_angle
	return rotation + _muzzle_local_angle

# --- Coverage overlay -----------------------------------------------------

func _ensure_overlay() -> void:
	if _coverage_overlay and is_instance_valid(_coverage_overlay):
		return
	_coverage_overlay = WEAPON_COVERAGE_OVERLAY_SCRIPT.new()
	if not _coverage_overlay:
		return
	_coverage_overlay.name = "WeaponCoverageOverlay"
	add_child(_coverage_overlay)

func _update_overlay(active: bool) -> void:
	if not _coverage_overlay or not is_instance_valid(_coverage_overlay):
		return

	var is_player: bool = bool(_ship.get("is_player_ship")) if _ship else false
	var should_show := active and is_player and _weapon.show_coverage_grid and _weapon.weapon_range > 0.0
	_coverage_overlay.set_overlay_visible(should_show)
	if not should_show:
		return

	# Anchor the grid to the weapon's own centre and orient its cone along the
	# weapon's mount-forward direction, so coverage reads from the weapon.
	_coverage_overlay.global_position = global_position
	_coverage_overlay.global_rotation = _mount_forward_global()
	# Draw the attack cone as a grid (the area shots actually cover) and, when the
	# turret is restricted, draw its swing arc as a plain outline so the two read
	# as distinct: the grid shows coverage, the outline shows the swing limit.
	var outline_cone := 0.0
	if _weapon.max_turret_angle < 360.0:
		outline_cone = _weapon.max_turret_angle
	_coverage_overlay.set_coverage(_weapon.weapon_range, 0.0, _weapon.attack_cone_degrees, outline_cone)

# --- Fire timing ----------------------------------------------------------

func _sync_ammo() -> void:
	_ammo_in_mag = _weapon.ammo if _uses_ammo() else -1

func _uses_ammo() -> bool:
	return _weapon != null and _weapon.ammo > 0

func _tick_timers(delta: float) -> void:
	if _shot_timer > 0.0:
		_shot_timer = maxf(0.0, _shot_timer - delta)

	if _reload_timer <= 0.0:
		return
	_reload_timer = maxf(0.0, _reload_timer - delta)
	if _reload_timer <= 0.0 and _uses_ammo():
		_ammo_in_mag = _weapon.ammo

func _can_fire() -> bool:
	if _reload_timer > 0.0 or _shot_timer > 0.0:
		return false
	if _weapon.fire_rate <= 0.0:
		return false
	if _uses_ammo() and _ammo_in_mag <= 0:
		_start_reload()
		return false
	return true

func _start_reload() -> void:
	if not _uses_ammo():
		return
	var reload_time := maxf(0.0, _weapon.cooldown)
	if reload_time <= 0.0:
		_ammo_in_mag = _weapon.ammo
		return
	_reload_timer = reload_time

func _consume_ammo() -> void:
	if not _uses_ammo():
		return
	_ammo_in_mag -= 1
	if _ammo_in_mag <= 0:
		_start_reload()

# --- Firing ---------------------------------------------------------------

func _fire(target: Node2D) -> void:
	if not _muzzle or not is_instance_valid(_muzzle):
		return

	var projectile := _create_projectile()
	if not projectile:
		return

	_configure_projectile(projectile, target)
	get_tree().root.add_child(projectile)
	_trigger_muzzle_flash()

	_shot_timer = 1.0 / maxf(_weapon.fire_rate, 0.001)
	_consume_ammo()

func _create_projectile() -> Projectile:
	if _projectile_scene:
		return _projectile_scene.instantiate() as Projectile
	if _projectile_template and is_instance_valid(_projectile_template):
		return _projectile_template.duplicate() as Projectile
	return null

func _configure_projectile(projectile: Projectile, target: Node2D) -> void:
	projectile.global_position = _muzzle.global_position
	projectile.direction = (_muzzle.global_position.direction_to(target.global_position)).normalized()
	projectile.speed = _weapon.projectile_speed
	projectile.damage_hull = _weapon.hull_damage
	projectile.damage_shield = _weapon.shield_damage
	projectile.is_beam = _weapon.is_beam
	projectile.source_ship = _ship

func _trigger_muzzle_flash() -> void:
	# The weapon owns a `muzzle_flash` node bundling its flash animation
	# (`flash`) and firing sound (`audio`). Firing enables the flash sprite,
	# plays the animation and the audio, then hides the flash again.
	if not _muzzle_flash or not is_instance_valid(_muzzle_flash):
		return

	var flash := _get_child_case_insensitive(_muzzle_flash, "flash") as AnimatedSprite2D
	var flash_lifetime := 0.1
	if flash:
		flash.visible = true
		if flash.sprite_frames:
			flash.frame = 0
			flash.play()
			var animation_name: StringName = flash.animation
			var frame_count := flash.sprite_frames.get_frame_count(animation_name)
			var animation_speed := maxf(0.01, flash.sprite_frames.get_animation_speed(animation_name))
			var computed_lifetime := frame_count / animation_speed
			flash_lifetime = computed_lifetime if computed_lifetime > 0.05 else 0.05
		_schedule_flash_hide(flash, flash_lifetime)

	var audio := _get_child_case_insensitive(_muzzle_flash, "audio") as AudioStreamPlayer2D
	if audio:
		audio.play()

func _schedule_flash_hide(flash: AnimatedSprite2D, lifetime: float) -> void:
	get_tree().create_timer(lifetime).timeout.connect(func() -> void:
		if is_instance_valid(flash):
			flash.stop()
			flash.visible = false
	)

func _get_child_case_insensitive(parent: Node, child_name: String) -> Node:
	var lowered := child_name.to_lower()
	for child in parent.get_children():
		if str(child.name).to_lower() == lowered:
			return child
	return null
