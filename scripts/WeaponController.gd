extends Node2D
class_name WeaponController

@onready var _ship: Ship = get_parent() as Ship
@onready var _targeting: TargetingController = get_parent().get_node(^"TargetingController")
@onready var _muzzle: Marker2D = get_parent().get_node(^"Muzzle")

var _shot_timer: float = 0.0
var _reload_timer: float = 0.0
var _ammo_in_mag: int = -1
var _active_weapon: WeaponData
var _shots_since_fire_audio: int = 0
var _fire_audio_weapon: WeaponData

const PROJECTILE_SCENE = preload("res://scenes/Projectile.tscn")

func _process(delta: float) -> void:
	if _ship.is_dead:
		return

	if not _ship.ship_data or not _ship.ship_data.basic_weapon:
		return

	var weapon: WeaponData = _ship.ship_data.basic_weapon
	_sync_weapon_state(weapon)
	_tick_timers(delta, weapon)

	if weapon.auto_fire and _targeting.locked_target:
		_attempt_fire(weapon)

func _attempt_fire(weapon: WeaponData) -> void:
	if _reload_timer > 0.0 or _shot_timer > 0.0:
		return

	if weapon.fire_rate <= 0.0:
		return

	if _is_out_of_ammo(weapon):
		_start_reload(weapon)
		return

	var target: Node2D = _targeting.locked_target
	if not target:
		return

	var dist: float = _ship.global_position.distance_to(target.global_position)
	if dist <= weapon.weapon_range:
		_fire(target, weapon)
		_shot_timer = 1.0 / maxf(weapon.fire_rate, 0.001)
		_consume_ammo(weapon)

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

	var reload_time: float = maxf(0.0, weapon.cooldown)
	if reload_time <= 0.0:
		_ammo_in_mag = weapon.ammo
		return

	_reload_timer = reload_time

func _fire(target: Node2D, weapon: WeaponData) -> void:
	if not PROJECTILE_SCENE:
		print("Error: Projectile scene not preloaded!")
		return

	_play_fire_audio(weapon)
	_spawn_muzzle_flash(weapon)
		
	# Instantiate projectile
	var projectile: Projectile = PROJECTILE_SCENE.instantiate() as Projectile
	
	# Set projectile properties
	projectile.global_position = _muzzle.global_position
	projectile.direction = (_muzzle.global_position.direction_to(target.global_position)).normalized()
	projectile.speed = weapon.projectile_speed
	projectile.damage_hull = weapon.hull_damage
	projectile.damage_shield = weapon.shield_damage
	projectile.source_ship = _ship
	
	# Add to main scene to avoid movement inheritance
	get_tree().root.add_child(projectile)
	
	# print("Firing at ", target.name)

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
	audio_manager.call("play_weapon_fire", weapon.fire_audio, _muzzle.global_position, is_player_shot, _ship)

func _spawn_muzzle_flash(weapon: WeaponData) -> void:
	if not weapon.muzzle_flash:
		return

	var muzzle_flash_instance := weapon.muzzle_flash.instantiate() as Node2D
	if not muzzle_flash_instance:
		return

	_muzzle.add_child(muzzle_flash_instance)
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
		flash_lifetime = maxf(0.05, float(frame_count) / animation_speed)

	get_tree().create_timer(flash_lifetime).timeout.connect(muzzle_flash_instance.queue_free)
