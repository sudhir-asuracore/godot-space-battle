extends SceneTree

# Reproduction / regression test for the Zarak Gorehammer auto-navigation wobble.
# Before the fix the ship held its peak turn rate until the heading was almost
# aligned, then could not brake its angular velocity in time, so it overshot the
# target heading and oscillated (wobbled) left and right. This test drives the
# real movement code over many frames and asserts the heading converges onto the
# target without overshooting (no sign flips of the heading error).

const SHIP_DATA := preload("res://resources/factions/zarak/ships/gorehammer.tres")
const FACTION := preload("res://resources/factions/zarak/zarak_confedaracy.tres")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var ship := SHIP_DATA.ship_scene.instantiate() as Ship
	ship.ship_data = SHIP_DATA
	ship.faction_data = FACTION
	ship.global_position = Vector2.ZERO
	root.add_child(ship)
	await process_frame

	# Start the ship pointing straight ahead (+x) with a target straight below
	# it, so it must rotate ~90 degrees. Keep the target far away so arrival
	# braking does not interfere with the turn we are measuring.
	ship.global_rotation = 0.0
	ship.velocity = Vector2.ZERO
	var destination := Vector2(0.0, 4000.0)
	var target_angle := (destination - ship.global_position).angle()
	ship.set_target(destination)

	var delta := 1.0 / 60.0
	var sign_flips := 0
	var prev_sign := 0
	var max_abs_error := 0.0

	# Simulate a few seconds of navigation.
	for _i in range(600):
		ship.call("_process_movement", delta)
		var err: float = angle_difference(ship.global_rotation, target_angle)
		max_abs_error = maxf(max_abs_error, absf(err))
		var s := signf(err)
		if absf(err) > 0.01 and s != 0.0:
			if prev_sign != 0 and s != float(prev_sign):
				sign_flips += 1
			prev_sign = int(s)

	var final_error: float = absf(angle_difference(ship.global_rotation, target_angle))
	var final_angular: float = absf(float(ship.get("_angular_velocity")))

	# The heading error must never change sign: the ship should approach the
	# target heading and stop, not overshoot and swing back (the wobble).
	if sign_flips > 0:
		failures.append("Ship overshot its target heading %d time(s) (wobble)" % sign_flips)
	# It must actually settle on the target heading.
	if final_error > 0.05:
		failures.append("Ship failed to align with target heading (error %.4f rad)" % final_error)
	# And its turn must have braked to a stop.
	if final_angular > 0.05:
		failures.append("Ship did not brake its turn (angular velocity %.4f rad/s)" % final_angular)

	ship.queue_free()

	if failures.is_empty():
		print("[TEST] ShipAutoNavTurnBrakingCheck passed")
		quit(0)
		return

	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)
