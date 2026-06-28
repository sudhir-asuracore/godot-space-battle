extends SceneTree

# Milestone 7 — verifies the hangar purchase/deploy loop end to end:
#   * ShipData resolves its hangar images from the ship scene's LOD sprites,
#   * GameState's prestige/tech-point economy and ship ownership behave,
#   * purchasing spends prestige, going broke is blocked (free starter remains),
#   * deploying persists the selection, and the EventBus/HUD wiring exists.
#
# NOTE: Like the other checks, scripts that reference the EventBus/GameState
# autoload *globals* (PlayerHUD) can't compile under the headless `--script`
# harness, so those are validated by source inspection; the live economy is
# exercised through the `/root/GameState` autoload node.

const ZARAK_FACTION_PATH := "res://resources/factions/zarak/zarak_confedaracy.tres"
const ZARAK_SCOUT_PATH := "res://resources/factions/zarak/ships/scout.tres"
const ZARAK_FRIGATE_PATH := "res://resources/factions/zarak/ships/zarak_frigate.tres"
const PLAYER_HUD_SCRIPT := "res://scripts/ui/PlayerHUD.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var scout := load(ZARAK_SCOUT_PATH) as ShipData
	var frigate := load(ZARAK_FRIGATE_PATH) as ShipData
	var faction := load(ZARAK_FACTION_PATH) as FactionData
	if not scout or not frigate or not faction:
		_fail(["Failed to load scout/frigate/faction resources"])
		return

	# 1. Hangar images resolve from the ship scene's LOD sprites.
	if frigate.get_hangar_portrait() == null:
		failures.append("Frigate get_hangar_portrait() returned null (expected lod_near texture)")
	if frigate.get_hangar_icon() == null:
		failures.append("Frigate get_hangar_icon() returned null (expected lod_medium texture)")

	# 2. Economy data on the resources is authored as designed.
	if not scout.is_starter:
		failures.append("Scout should be flagged is_starter (free fallback)")
	if scout.purchase_cost != 0.0:
		failures.append("Scout purchase_cost should be 0, got %s" % scout.purchase_cost)
	if frigate.is_starter:
		failures.append("Frigate must not be a starter")
	if frigate.purchase_cost <= 0.0:
		failures.append("Frigate purchase_cost should be positive, got %s" % frigate.purchase_cost)
	if frigate.description.is_empty():
		failures.append("Frigate should have a hangar description")

	# 3. EventBus exposes the new purchase/deploy/tech signals.
	var event_bus := root.get_node_or_null(^"/root/EventBus")
	if not event_bus:
		failures.append("EventBus autoload not found")
	else:
		for sig in ["ship_purchased", "ship_deployed", "tech_points_changed"]:
			if not event_bus.has_signal(sig):
				failures.append("EventBus is missing the %s signal" % sig)

	# 4. GameState purchase/deploy economy.
	var gs := root.get_node_or_null(^"/root/GameState")
	if not gs:
		failures.append("GameState autoload not found")
	else:
		gs.player_faction = faction
		gs.register_faction(faction)

		# Starter is owned for free; non-starter is locked until bought.
		if not gs.is_ship_owned(faction, scout):
			failures.append("Starter scout should be owned after registration")
		if gs.is_ship_owned(faction, frigate):
			failures.append("Frigate should NOT be owned before purchase")

		# Going broke never softlocks: the free starter stays affordable.
		gs.faction_prestige[faction] = 0.0
		if not gs.can_afford_ship(faction, scout):
			failures.append("Free starter must always be affordable, even when broke")
		if gs.can_afford_ship(faction, frigate):
			failures.append("Frigate should be unaffordable at 0 prestige")
		if gs.purchase_ship(faction, frigate):
			failures.append("purchase_ship should fail when broke")
		if gs.is_ship_owned(faction, frigate):
			failures.append("Frigate must not be owned after a failed purchase")

		# With enough prestige the purchase succeeds and spends exactly the cost.
		gs.faction_prestige[faction] = frigate.purchase_cost + 50.0
		if not gs.purchase_ship(faction, frigate):
			failures.append("purchase_ship should succeed when affordable")
		if not gs.is_ship_owned(faction, frigate):
			failures.append("Frigate should be owned after a successful purchase")
		if int(gs.get_prestige(faction)) != 50:
			failures.append("Purchase should spend the cost; expected 50 left, got %s" % gs.get_prestige(faction))
		# Re-buying an owned ship is free and idempotent.
		if not gs.purchase_ship(faction, frigate):
			failures.append("Re-purchasing an owned ship should return true")
		if int(gs.get_prestige(faction)) != 50:
			failures.append("Re-purchasing an owned ship must not spend prestige")

		# Tech points are a separate spendable currency.
		gs.add_tech_points(faction, 30.0)
		if int(gs.get_tech_points(faction)) != 30:
			failures.append("add_tech_points failed; expected 30, got %s" % gs.get_tech_points(faction))
		if not gs.spend_tech_points(faction, 10.0):
			failures.append("spend_tech_points should succeed with enough points")
		if gs.spend_tech_points(faction, 999.0):
			failures.append("spend_tech_points should fail when short")

		# Deploy persists the player's selection.
		gs.set_current_ship(faction, frigate)
		if gs.get_current_ship(faction) != frigate:
			failures.append("get_current_ship did not return the deployed ship")
		if gs.selected_ship_data_path != ZARAK_FRIGATE_PATH:
			failures.append("Deploy should persist selected_ship_data_path, got '%s'" % gs.selected_ship_data_path)

	# 5. The hangar HUD wires the new flow (source inspection).
	_check_source(PLAYER_HUD_SCRIPT, [
		"func _build_hangar",
		"func show_ship_selection",
		"func hide_ship_selection",
		"func is_ship_selection_visible",
		"func _make_ship_button",
		"func _on_hangar_purchase_pressed",
		"func _on_hangar_deploy_pressed",
		"get_hangar_portrait",
		"GameState.purchase_ship",
		"GameState.set_current_ship",
		"EventBus.player_ship_selected.emit",
	], failures)

	if failures.is_empty():
		print("[TEST] HangarPurchaseDeployCheck passed")
		quit(0)
		return
	_fail(failures)

func _check_source(path: String, needles: Array, failures: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		failures.append("Could not open %s for inspection" % path)
		return
	var text := file.get_as_text()
	file.close()
	for needle in needles:
		if not text.contains(needle):
			failures.append("%s is missing expected code: '%s'" % [path, needle])

func _fail(failures: Array[String]) -> void:
	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)
