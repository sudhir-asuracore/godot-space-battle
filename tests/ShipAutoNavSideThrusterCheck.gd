extends SceneTree

# Regression test for auto-navigation side-thruster rendering.
# Manual steering drives the left/right thruster VFX from the turn input, but
# auto-navigation previously left _side_thrust_intensity untouched, so the side
# thrusters never lit while the ship turned onto its path. This test drives the
# real _process_movement over a turn and asserts the correct side thruster fires.

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

	# Point straight ahead (+x) with the target straight below: the ship must
	# turn its nose to the right (clockwise / positive rate), which by the manual
	# convention fires the LEFT-hand thrusters. Keep the target far so arrival
	# braking does not interfere with the turn we are measuring.
	ship.global_rotation = 0.0
	ship.velocity = Vector2.ZERO
	var destination := Vector2(0.0, 4000.0)
	ship.set_target(destination)

	var delta := 1.0 / 60.0
	var max_left: float = 0.0
	var max_right: float = 0.0

	# Sample the first part of the turn, before the ship aligns with the target.
	for _i in range(30):
		ship.call("_process_movement", delta)
		var side: Dictionary = ship.get("_side_thrust_intensity")
		max_left = maxf(max_left, float(side[&"left"]))
		max_right = maxf(max_right, float(side[&"right"]))

	# Turning right must fire the left-hand thrusters during auto-navigation.
	if max_left <= 0.0:
		failures.append("Left-hand side thrusters never fired during auto-nav right turn")

	ship.queue_free()

	if failures.is_empty():
		print("[TEST] ShipAutoNavSideThrusterCheck passed")
		quit(0)
		return

	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)
