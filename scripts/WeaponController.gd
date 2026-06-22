extends Node2D
class_name WeaponController

@onready var _ship: Ship = get_parent() as Ship
@onready var _targeting: TargetingController = get_parent().get_node(^"TargetingController")
@onready var _muzzle: Marker2D = get_parent().get_node(^"Muzzle")

var _cooldown_timer: float = 0.0

const PROJECTILE_SCENE = preload("res://scenes/Projectile.tscn")

func _process(delta: float) -> void:
	if _cooldown_timer > 0:
		_cooldown_timer -= delta
		
	if not _ship.ship_data or not _ship.ship_data.basic_weapon:
		return
		
	var weapon = _ship.ship_data.basic_weapon
	if weapon.auto_fire and _targeting.locked_target:
		_attempt_fire()

func _attempt_fire() -> void:
	if _cooldown_timer > 0:
		return
		
	var target = _targeting.locked_target
	if not target:
		return
		
	var weapon = _ship.ship_data.basic_weapon
	
	var dist = _ship.global_position.distance_to(target.global_position)
	if dist <= weapon.weapon_range:
		_fire(target, weapon)
		_cooldown_timer = weapon.cooldown

func _fire(target: Node2D, weapon: WeaponData) -> void:
	if not PROJECTILE_SCENE:
		print("Error: Projectile scene not preloaded!")
		return

	_play_fire_audio(weapon)
		
	# Instantiate projectile
	var projectile = PROJECTILE_SCENE.instantiate()
	
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

	var audio_manager := get_node_or_null(^"/root/AudioManager")
	if not audio_manager:
		return

	var game_state := get_node_or_null(^"/root/GameState")
	var player_faction = game_state.get(&"player_faction") if game_state else null

	var is_player_shot: bool = false
	if _ship.faction_data != null and player_faction != null:
		is_player_shot = _ship.faction_data == player_faction
	audio_manager.call("play_weapon_fire", weapon.fire_audio, _muzzle.global_position, is_player_shot, _ship)
