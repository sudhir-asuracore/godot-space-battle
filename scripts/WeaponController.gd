extends Node2D
class_name WeaponController

const WEAPON_COVERAGE_OVERLAY_SCRIPT := preload("res://scripts/WeaponCoverageOverlay.gd")

@onready var _ship: Ship = get_parent() as Ship
@onready var _targeting: TargetingController = get_parent().get_node(^"TargetingController")

const MUZZLE_NODE_PREFIX := "muzzle_"

# Prefix identifying a self-contained weapon node instanced on the ship
# (e.g. weapon_left_0, weapon_right_1). Each such node is a full weapon scene
# bundling its sprite, muzzle marker, muzzle flash + audio and the projectile
# it fires. This is the new self-reliant weapon model that coexists with the
# legacy muzzle_<type>_<side>_<index> marker pattern below.
const WEAPON_NODE_PREFIX := "weapon_"

# Every muzzle marker on the ship, parsed from nodes named
# muzzle_<weapon_type>_<side>_<index>. A legacy single "Muzzle" node is also
# supported. The primary muzzle is used as the representative point for audio.
var _muzzles: Array[Dictionary] = []
var _primary_muzzle: Marker2D = null

# Self-contained weapon modules discovered on the ship. Each entry is a
# WeaponModule node that fully manages its own range, aiming, coverage grid,
# fire cadence, projectile, muzzle flash and audio. The controller only acts as
# a coordinator that forwards the locked target to them. See
# _resolve_weapon_modules().
var _weapon_modules: Array[Node] = []

# True once each discovered module has been handed its WeaponData. The ship's
# `ship_data` may not be assigned yet when this node enters the tree (e.g. the
# spawner calls add_child() before setting ship_data), so configuration is
# deferred until ship_data is available rather than done eagerly in _ready().
var _modules_configured: bool = false

var _shot_timer: float = 0.0
var _reload_timer: float = 0.0
var _ammo_in_mag: int = -1
var _active_weapon: WeaponData
var _shots_since_fire_audio: int = 0
var _fire_audio_weapon: WeaponData
var _coverage_overlay = null

const PROJECTILE_SCENE = preload("res://scenes/common/weapons/Projectile.tscn")

func _ready() -> void:
	_resolve_muzzles()
	_resolve_weapon_modules()
	_ensure_coverage_overlay()

func _resolve_muzzles() -> void:
	_muzzles.clear()
	_primary_muzzle = null

	var parent := get_parent()
	if not parent:
		return

	# Legacy single "Muzzle" node support for older ship scenes.
	var legacy_muzzle := parent.get_node_or_null(^"Muzzle") as Marker2D
	if legacy_muzzle:
		_muzzles.append({"node": legacy_muzzle, "weapon_type": &"", "side": &"", "index": 0})

	for child in parent.get_children():
		var marker := child as Marker2D
		if not marker:
			continue
		var muzzle_metadata := _parse_muzzle_node_name(marker.name)
		if muzzle_metadata.is_empty():
			continue
		muzzle_metadata["node"] = marker
		_muzzles.append(muzzle_metadata)

	_muzzles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_type: String = str(a.get("weapon_type", &""))
		var b_type: String = str(b.get("weapon_type", &""))
		if a_type != b_type:
			return a_type < b_type
		var a_side: String = str(a.get("side", &""))
		var b_side: String = str(b.get("side", &""))
		if a_side != b_side:
			return a_side < b_side
		return int(a.get("index", 0)) < int(b.get("index", 0))
	)

	if not _muzzles.is_empty():
		_primary_muzzle = _muzzles[0].get("node") as Marker2D

func _resolve_weapon_modules() -> void:
	# Discover self-contained WeaponModule nodes (weapon_<key>_<side>_<index>)
	# instanced on the ship. Each module owns everything about itself, so the
	# controller only has to tell it which WeaponData it fires and then forward
	# the locked target every frame.
	#
	# Only the nodes are collected here; resolving each module's WeaponData and
	# calling configure() is deferred to _ensure_modules_configured() because
	# the ship's `ship_data` is often assigned after this node enters the tree.
	_weapon_modules.clear()
	_modules_configured = false

	var parent := get_parent()
	if not parent:
		return

	for child in parent.get_children():
		# A self-contained weapon is any weapon_* node running the WeaponModule
		# script (detected via its configure()/tick() API so this works even
		# before the editor has registered the class_name).
		if not str(child.name).begins_with(WEAPON_NODE_PREFIX):
			continue
		if not (child.has_method("configure") and child.has_method("tick")):
			continue
		_weapon_modules.append(child)

	_weapon_modules.sort_custom(func(a: Node, b: Node) -> bool:
		return str(a.name if a else "") < str(b.name if b else "")
	)

func _ensure_modules_configured() -> void:
	# Configure each discovered module with the WeaponData declared by the ship.
	# Runs once ship_data is available; until then modules stay inert (their
	# tick() is a no-op without a weapon), which avoids configuring them with a
	# null weapon when the spawner sets ship_data after add_child().
	if _modules_configured or _weapon_modules.is_empty():
		return
	if not _ship or not _ship.ship_data:
		return

	for module in _weapon_modules:
		var weapon_key := _parse_weapon_node_key(module.name)
		var weapon: WeaponData = _ship.ship_data.get_ship_weapon(weapon_key)
		module.configure(weapon, _ship)

	_modules_configured = true

func _parse_weapon_node_key(node_name: StringName) -> StringName:
	# Self-contained weapon nodes are named weapon_<key>_<side>_<index>
	# (e.g. weapon_cannonlarge_right_0). The ship declares which WeaponData a
	# slot fires under the "weapon_<key>" key, so we strip the trailing
	# <side>_<index> and return the leading "weapon_<key>" portion.
	var raw_name: String = str(node_name)
	if not raw_name.begins_with(WEAPON_NODE_PREFIX):
		return &""

	var parts: PackedStringArray = raw_name.split("_")
	# Need at least weapon, key, side, index.
	if parts.size() < 4:
		return &""

	# Drop the last two segments (side, index); the rest (minus the leading
	# "weapon") is the weapon key, rejoined to support multi-word keys.
	var key_segments: PackedStringArray = parts.slice(1, parts.size() - 2)
	if key_segments.is_empty():
		return &""
	return StringName(WEAPON_NODE_PREFIX + "_".join(key_segments))

func _parse_muzzle_node_name(node_name: StringName) -> Dictionary:
	# Expected pattern: muzzle_<weapon_type>_<side>_<index>
	# e.g. muzzle_cannon_left_0, muzzle_gattling_front_0.
	var raw_name: String = str(node_name)
	if not raw_name.begins_with(MUZZLE_NODE_PREFIX):
		return {}

	var parts: PackedStringArray = raw_name.split("_")
	if parts.size() != 4:
		return {}
	if parts[0] != "muzzle":
		return {}

	var weapon_type: String = parts[1]
	var side: String = parts[2]
	var index_text: String = parts[3]
	if weapon_type.is_empty() or side.is_empty() or not index_text.is_valid_int():
		return {}

	return {
		"weapon_type": StringName(weapon_type),
		"side": StringName(side),
		"index": int(index_text),
	}

func _muzzle_audio_position() -> Vector2:
	if _primary_muzzle and is_instance_valid(_primary_muzzle):
		return _primary_muzzle.global_position
	if _ship:
		return _ship.global_position
	return global_position

func _get_weapon_for_muzzle(muzzle_entry: Dictionary, fallback_weapon: WeaponData) -> WeaponData:
	var weapon_type: StringName = muzzle_entry.get("weapon_type", &"")
	if weapon_type != &"" and _ship and _ship.ship_data:
		var mapped: WeaponData = _ship.ship_data.get_muzzle_weapon(weapon_type)
		if mapped:
			return mapped
	return fallback_weapon

func _process(delta: float) -> void:
	var active := _can_process_weapon_logic()

	# Self-contained weapon modules manage their own range, aiming, coverage
	# grid and firing; the controller only forwards the locked target to them.
	_tick_weapon_modules(delta, active)

	if not active:
		_set_coverage_overlay_visible(false)
		return

	# Legacy / basic_weapon path for ships not yet migrated to weapon modules.
	var weapon: WeaponData = _get_active_weapon_data()
	if not weapon:
		_set_coverage_overlay_visible(false)
		return

	_update_coverage_overlay(weapon)

	_sync_weapon_state(weapon)
	_tick_timers(delta, weapon)
	_after_weapon_tick(delta, weapon)

	if _should_auto_fire(weapon):
		_attempt_fire(weapon)

func _tick_weapon_modules(delta: float, active: bool) -> void:
	if _weapon_modules.is_empty():
		return
	_ensure_modules_configured()
	var target: Node2D = _get_locked_target() if active else null
	for module in _weapon_modules:
		module.tick(delta, target, active)

func _can_process_weapon_logic() -> bool:
	return _ship != null and not _ship.is_dead

func _get_active_weapon_data() -> WeaponData:
	if not _ship or not _ship.ship_data:
		return null
	# Weapon modules drive themselves, so the controller-level weapon is only
	# the legacy basic_weapon (used for muzzle markers and the ship-level grid).
	return _ship.ship_data.basic_weapon

func _after_weapon_tick(_delta: float, _weapon: WeaponData) -> void:
	pass

func _should_auto_fire(weapon: WeaponData) -> bool:
	return weapon.auto_fire and _get_locked_target() != null

func _get_locked_target() -> Node2D:
	if not _targeting:
		return null
	return _targeting.locked_target

func _attempt_fire(weapon: WeaponData) -> void:
	if not _can_fire_weapon(weapon):
		return

	var target: Node2D = _get_fire_target(weapon)
	if not target:
		return

	if not _is_target_in_range(target, weapon):
		return

	if not _fire(target, weapon):
		return

	_start_shot_cooldown(weapon)
	_consume_ammo(weapon)
	_on_weapon_fired(target, weapon)

func _can_fire_weapon(weapon: WeaponData) -> bool:
	if _reload_timer > 0.0 or _shot_timer > 0.0:
		return false

	if weapon.fire_rate <= 0.0:
		return false

	if _is_out_of_ammo(weapon):
		_start_reload(weapon)
		return false

	return true

func _get_fire_target(_weapon: WeaponData) -> Node2D:
	return _get_locked_target()

func _is_target_in_range(target: Node2D, weapon: WeaponData) -> bool:
	if not _ship:
		return false
	var dist: float = _ship.global_position.distance_to(target.global_position)
	return dist <= weapon.weapon_range

func _start_shot_cooldown(weapon: WeaponData) -> void:
	_shot_timer = 1.0 / maxf(weapon.fire_rate, 0.001)

func _on_weapon_fired(_target: Node2D, _weapon: WeaponData) -> void:
	pass

func _sync_weapon_state(weapon: WeaponData) -> void:
	if _active_weapon == weapon:
		if _uses_ammo(weapon):
			_ammo_in_mag = clampi(_ammo_in_mag, 0, weapon.ammo)
		return

	_active_weapon = weapon
	_shot_timer = 0.0
	_reload_timer = 0.0
	if _uses_ammo(weapon):
		_ammo_in_mag = weapon.ammo
	else:
		_ammo_in_mag = -1

func _tick_timers(delta: float, weapon: WeaponData) -> void:
	if _shot_timer > 0.0:
		_shot_timer = maxf(0.0, _shot_timer - delta)

	if _reload_timer <= 0.0:
		return

	_reload_timer = maxf(0.0, _reload_timer - delta)
	if _reload_timer <= 0.0 and _uses_ammo(weapon):
		_ammo_in_mag = weapon.ammo
		_on_reload_finished(weapon)

func _uses_ammo(weapon: WeaponData) -> bool:
	return weapon != null and weapon.ammo > 0

func _is_out_of_ammo(weapon: WeaponData) -> bool:
	return _uses_ammo(weapon) and _ammo_in_mag <= 0

func _consume_ammo(weapon: WeaponData) -> void:
	if not _uses_ammo(weapon):
		return

	_ammo_in_mag -= 1
	if _ammo_in_mag <= 0:
		_start_reload(weapon)

func _start_reload(weapon: WeaponData) -> void:
	if not _uses_ammo(weapon):
		return

	var reload_time: float = _get_reload_time(weapon)
	if reload_time <= 0.0:
		_ammo_in_mag = weapon.ammo
		_on_reload_finished(weapon)
		return

	_reload_timer = reload_time
	_on_reload_started(weapon, reload_time)

func _get_reload_time(weapon: WeaponData) -> float:
	return maxf(0.0, weapon.cooldown)

func _on_reload_started(_weapon: WeaponData, _reload_time: float) -> void:
	pass

func _on_reload_finished(_weapon: WeaponData) -> void:
	pass

func _fire(target: Node2D, weapon: WeaponData) -> bool:
	# Self-contained weapon modules fire themselves (see WeaponModule); this
	# path only covers the legacy muzzle markers used by ships that still rely
	# on the ship-level basic_weapon.
	if _muzzles.is_empty():
		return false
	return _fire_legacy_muzzles(target, weapon)

func _fire_legacy_muzzles(target: Node2D, weapon: WeaponData) -> bool:
	if not PROJECTILE_SCENE:
		print("Error: Projectile scene not preloaded!")
		return false

	_play_fire_audio(weapon)

	# Fire a projectile from every muzzle, each using the projectile mapped to
	# its weapon type (falling back to the ship's basic weapon).
	var fired_any: bool = false
	for muzzle_entry in _muzzles:
		var muzzle_node := muzzle_entry.get("node") as Marker2D
		if not muzzle_node or not is_instance_valid(muzzle_node):
			continue

		var muzzle_weapon: WeaponData = _get_weapon_for_muzzle(muzzle_entry, weapon)
		if not muzzle_weapon:
			continue

		_spawn_muzzle_flash(muzzle_weapon, muzzle_node)

		var projectile: Projectile = _create_projectile()
		if not projectile:
			continue

		_configure_projectile(projectile, muzzle_node, target, muzzle_weapon)
		_add_projectile_to_world(projectile)
		_after_projectile_spawned(projectile, target, muzzle_weapon)
		fired_any = true

	return fired_any

func _create_projectile() -> Projectile:
	return PROJECTILE_SCENE.instantiate() as Projectile

func _configure_projectile(projectile: Projectile, muzzle: Node2D, target: Node2D, weapon: WeaponData) -> void:
	projectile.global_position = muzzle.global_position
	projectile.direction = (muzzle.global_position.direction_to(target.global_position)).normalized()
	projectile.speed = weapon.projectile_speed
	projectile.damage_hull = weapon.hull_damage
	projectile.damage_shield = weapon.shield_damage
	projectile.source_ship = _ship

func _add_projectile_to_world(projectile: Projectile) -> void:
	get_tree().root.add_child(projectile)

func _after_projectile_spawned(_projectile: Projectile, _target: Node2D, _weapon: WeaponData) -> void:
	pass

func _play_fire_audio(weapon: WeaponData) -> void:
	if not weapon.fire_audio:
		return

	if _fire_audio_weapon != weapon:
		_fire_audio_weapon = weapon
		_shots_since_fire_audio = 0

	var once_per_ammo: int = maxi(1, weapon.fire_audio_once_per_ammo)
	if _shots_since_fire_audio % once_per_ammo != 0:
		_shots_since_fire_audio += 1
		return
	_shots_since_fire_audio += 1

	var audio_manager := get_node_or_null(^"/root/AudioManager")
	if not audio_manager:
		return

	var game_state := get_node_or_null(^"/root/GameState")
	var player_faction: FactionData = game_state.get(&"player_faction") if game_state else null

	var is_player_shot: bool = false
	if _ship.faction_data != null and player_faction != null:
		is_player_shot = _ship.faction_data == player_faction
	audio_manager.call("play_weapon_fire", weapon.fire_audio, _muzzle_audio_position(), is_player_shot, _ship)

func _spawn_muzzle_flash(weapon: WeaponData, muzzle: Marker2D) -> void:
	if not weapon.muzzle_flash:
		return
	if not muzzle or not is_instance_valid(muzzle):
		return

	var muzzle_flash_instance := weapon.muzzle_flash.instantiate() as Node2D
	if not muzzle_flash_instance:
		return

	muzzle.add_child(muzzle_flash_instance)
	muzzle_flash_instance.position = Vector2.ZERO
	muzzle_flash_instance.rotation = 0.0
	muzzle_flash_instance.scale = Vector2.ONE * maxf(0.0, weapon.muzzle_flash_scale)

	var flash_sprite := muzzle_flash_instance.get_node_or_null(^"flash") as AnimatedSprite2D
	var flash_lifetime := 0.1
	if flash_sprite and flash_sprite.sprite_frames:
		flash_sprite.speed_scale = maxf(0.01, weapon.muzzle_flash_speed_scale)
		flash_sprite.play()
		var animation_name: StringName = flash_sprite.animation
		var frame_count := flash_sprite.sprite_frames.get_frame_count(animation_name)
		var animation_speed := maxf(0.01, flash_sprite.sprite_frames.get_animation_speed(animation_name) * flash_sprite.speed_scale)
		var computed_lifetime := frame_count / animation_speed
		flash_lifetime = computed_lifetime if computed_lifetime > 0.05 else 0.05

	get_tree().create_timer(flash_lifetime).timeout.connect(muzzle_flash_instance.queue_free)

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

func _update_coverage_overlay(weapon: WeaponData) -> void:
	_ensure_coverage_overlay()
	if not _coverage_overlay:
		return

	var should_show := _ship != null and _ship.is_player_ship and weapon.show_coverage_grid and weapon.weapon_range > 0.0
	_coverage_overlay.set_overlay_visible(should_show)
	if not should_show:
		return

	_coverage_overlay.set_coverage(weapon.weapon_range, 0.0, weapon.attack_cone_degrees)
