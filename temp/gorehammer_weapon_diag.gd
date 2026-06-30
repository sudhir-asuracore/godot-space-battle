extends SceneTree

const SHIP_SCENE := preload("res://scenes/factions/zarak/ships/Zarak_Ship_Frigate_Gorehammer.tscn")
const SHIP_DATA_PATH := "res://resources/factions/zarak/ships/gorehammer.tres"

var _seen: Dictionary = {}

func _initialize() -> void:
	var ship_data := load(SHIP_DATA_PATH) as ShipData
	var ship := SHIP_SCENE.instantiate() as Ship
	ship.ship_data = ship_data
	get_root().add_child.call_deferred(ship)
	await process_frame
	await process_frame
	ship.global_position = Vector2.ZERO
	ship.global_rotation = 0.0

	var target := Node2D.new()
	get_root().add_child(target)
	target.global_position = Vector2.RIGHT * 200.0

	var targeting := ship.get_node(^"TargetingController") as TargetingController
	targeting.locked_target = target

	# Let the game loop run naturally and track every projectile ever spawned,
	# tagging each by source muzzle position so we can tell cannons from gattling.
	for i in range(150):
		await process_frame
		_scan(ship)

	var cannon_shots := 0
	var gattling_shots := 0
	for key in _seen:
		var x: float = _seen[key]
		if x > 40.0:
			gattling_shots += 1   # gattling muzzle sits ~ x=79 (forward)
		else:
			cannon_shots += 1     # cannons sit ~ x=4..10
	print("[DEBUG_LOG] total projectiles seen=", _seen.size(),
		" cannon-ish=", cannon_shots, " gattling-ish=", gattling_shots)
	quit(0)

func _scan(ship: Node2D) -> void:
	for child in get_root().get_children():
		if child is Projectile:
			var id := child.get_instance_id()
			if not _seen.has(id):
				# record spawn x relative to ship to attribute source
				_seen[id] = (child.global_position - ship.global_position).x
