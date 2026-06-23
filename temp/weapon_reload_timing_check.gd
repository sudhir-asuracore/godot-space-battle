extends SceneTree

const SHIP_SCENE := preload("res://scenes/ship/Ship.tscn")
const SHIP_DATA_PATH := "res://resources/factions/zarak/ships/scout.tres"

const EXPECTED_FIRE_RATE := 64.0
const EXPECTED_AMMO := 128
const SIM_STEP := 1.0 / EXPECTED_FIRE_RATE

func _initialize() -> void:
	var ship_data := load(SHIP_DATA_PATH) as ShipData
	if not _require(ship_data != null, "ShipData should load"):
		return
	if not _require(ship_data.basic_weapon != null, "ShipData should define a basic weapon"):
		return

	var ship := SHIP_SCENE.instantiate() as Ship
	ship.ship_data = ship_data
	get_root().add_child.call_deferred(ship)

	var target := Node2D.new()
	target.global_position = ship.global_position + Vector2.RIGHT * 100.0
	get_root().add_child(target)
	await process_frame
	await process_frame

	var weapon: WeaponData = ship.ship_data.basic_weapon
	if not _require(is_equal_approx(weapon.fire_rate, EXPECTED_FIRE_RATE), "Gattling fire_rate should remain 64 shots/s"):
		return
	var ammo_value: Variant = weapon.get(&"ammo")
	if not _require(ammo_value is int and int(ammo_value) == EXPECTED_AMMO, "Weapon ammo should be configured to 128 rounds"):
		return

	var targeting := ship.get_node(^"TargetingController") as TargetingController
	targeting.locked_target = target
	var controller := ship.get_node(^"WeaponController") as WeaponController

	var initial_projectiles: int = _count_projectiles()
	_simulate_fire(controller, 2.0, SIM_STEP)
	var burst_projectiles: int = _count_projectiles() - initial_projectiles
	if not _require(burst_projectiles == EXPECTED_AMMO, "Expected 128 shots in 2 seconds at 64 shots/s"):
		return

	var reload_check_start: int = _count_projectiles()
	_simulate_fire(controller, weapon.cooldown * 0.5, SIM_STEP)
	if not _require(_count_projectiles() == reload_check_start, "Weapon should not fire during reload"):
		return

	_simulate_fire(controller, weapon.cooldown * 0.6, SIM_STEP)
	if not _require(_count_projectiles() > reload_check_start, "Weapon should resume firing after reload completes"):
		return

	ship.queue_free()
	target.queue_free()
	quit(0)

func _simulate_fire(controller: WeaponController, duration: float, step: float) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		controller._process(step)
		elapsed += step

func _count_projectiles() -> int:
	var count := 0
	for child in get_root().get_children():
		if child is Projectile:
			count += 1
	return count

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false