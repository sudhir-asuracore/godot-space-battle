extends SceneTree

# Verifies that destroying a ship triggers its embedded "death_explosion" node.
# The Zarak Warbeast ships a Death_Explosion_Large instance that is hidden during
# normal play; when the hull is destroyed it must become visible, be reparented
# out of the (now hidden / soon-freed) ship, and start playing its blast.
# Run headless with:
#   godot --headless --script res://tests/ShipDeathExplosionCheck.gd

const FACTION_PATH := "res://resources/factions/zarak/zarak_confedaracy.tres"
const WARBEAST_PATH := "res://resources/factions/zarak/ships/warbeast.tres"
const WARBEAST_SCENE := "res://scenes/factions/zarak/ships/Zarak_Ship_Dread_Warbeast.tscn"
const DEATH_EXPLOSION_NODE := "death_explosion"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var faction := load(FACTION_PATH) as FactionData
	var ship_data := load(WARBEAST_PATH) as ShipData
	var packed := load(WARBEAST_SCENE) as PackedScene
	if not faction or not ship_data or not packed:
		push_error("[TEST] Failed to load warbeast resources")
		quit(1)
		return

	var ship := packed.instantiate() as Ship
	root.add_child(ship)
	ship.ship_data = ship_data
	ship.faction_data = faction
	ship.update_stats()
	await process_frame

	# Before death the explosion must exist, be hidden and parented to the ship.
	var death_explosion := ship.get_node_or_null(DEATH_EXPLOSION_NODE) as Node2D
	if death_explosion == null:
		push_error("[TEST] Warbeast has no '%s' node" % DEATH_EXPLOSION_NODE)
		ship.free()
		quit(1)
		return
	if death_explosion.visible:
		failures.append("death_explosion is visible before the ship is destroyed")
	if not death_explosion.get_parent() == ship:
		failures.append("death_explosion is not a child of the ship before death")

	# Destroy the ship with overkill damage.
	ship.take_damage(ship.max_hull + ship.max_shield + 1000.0, ship.max_shield + 1000.0, null)
	await process_frame

	if not ship.is_dead:
		failures.append("Ship did not register as dead after overkill damage")
	if not is_instance_valid(death_explosion):
		failures.append("death_explosion was freed immediately instead of playing")
	else:
		if not death_explosion.visible:
			failures.append("death_explosion did not become visible on death")
		if death_explosion.get_parent() == ship:
			failures.append("death_explosion was not reparented out of the hidden ship")

		# The explosion should be actively playing: either the audio is firing or
		# at least one flash sprite has been switched on.
		var audio := death_explosion.get_node_or_null("AudioStreamPlayer2D") as AudioStreamPlayer2D
		var audio_playing := audio != null and audio.playing
		var any_flash_visible := false
		for child in death_explosion.get_children():
			if child is AnimatedSprite2D and child.visible:
				any_flash_visible = true
				break
		if not (audio_playing or any_flash_visible):
			failures.append("death_explosion did not start playing (no audio, no visible flash)")

	if is_instance_valid(death_explosion):
		death_explosion.queue_free()
	if is_instance_valid(ship):
		ship.queue_free()
	await process_frame

	if failures.is_empty():
		print("[DEBUG_LOG] ShipDeathExplosionCheck PASSED")
		quit(0)
		return
	for f in failures:
		push_error("[TEST] %s" % f)
	quit(1)
