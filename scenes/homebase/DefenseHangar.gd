extends Area2D
class_name DefenseHangar

# How close (in world units) the player ship must be to the hangar for a click
# to open the purchase/upgrade store. Clicks made from farther away fall through
# to ship navigation instead of opening the store.
@export var interaction_range: float = 800.0

var faction_data: FactionData = null
var homebase: Homebase = null
var max_hull: float = 1.0
var current_hull: float = 1.0
var is_destroyed: bool = false

var _repair_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("homebase_defenses")
	_apply_destroyed_state()

func configure(faction: FactionData, owner_homebase: Homebase) -> void:
	faction_data = faction
	homebase = owner_homebase
	max_hull = maxf(1.0, faction_data.defense_structure_max_hull) if faction_data else 420.0
	current_hull = max_hull
	is_destroyed = false
	_repair_cooldown = 0.0
	_apply_destroyed_state()

func _process(delta: float) -> void:
	if not faction_data:
		return
	_process_repair(delta)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if is_destroyed:
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	var game_state := get_node_or_null(^"/root/GameState")
	var player_faction: FactionData = game_state.player_faction if game_state and "player_faction" in game_state else null
	if player_faction and faction_data != player_faction:
		return

	# Only open the store when the player ship is parked near the hangar. A click
	# from farther away is left unhandled so it still routes the ship there
	# (Main._unhandled_input "navigate"), without popping up the store.
	var player_ship := _get_player_ship()
	if player_ship == null or player_ship.global_position.distance_to(global_position) > interaction_range:
		return

	var ships: Array = []
	if faction_data:
		ships = faction_data.hangar_ship_options.duplicate()

	var event_bus := get_node_or_null(^"/root/EventBus")
	if event_bus:
		event_bus.call("emit_signal", &"hangar_shop_requested", faction_data, ships)
	# Consume the click so the ship doesn't also navigate into the hangar.
	_viewport.set_input_as_handled()

# Returns the live player ship (from the shared "ships" group) or null when none
# is alive, used to gate hangar interaction by distance.
func _get_player_ship() -> Node2D:
	for node in get_tree().get_nodes_in_group("ships"):
		var ship := node as Ship
		if ship and ship.is_player_ship and not ship.is_dead:
			return ship
	return null

func take_damage(hull_dmg: float, _shield_dmg: float, _attacker: Node2D = null) -> void:
	if hull_dmg <= 0.0:
		return

	current_hull = maxf(0.0, current_hull - hull_dmg)
	_repair_cooldown = _get_auto_repair_delay()
	if current_hull <= 0.0:
		_set_destroyed_state(true)

func _process_repair(delta: float) -> void:
	if _repair_cooldown > 0.0:
		_repair_cooldown = maxf(0.0, _repair_cooldown - delta)
		return

	if current_hull >= max_hull:
		return

	current_hull = min(max_hull, current_hull + _get_auto_repair_rate() * delta)
	if is_destroyed and current_hull > 0.0:
		_set_destroyed_state(false)

func _set_destroyed_state(destroyed: bool) -> void:
	if is_destroyed == destroyed:
		return
	is_destroyed = destroyed
	_apply_destroyed_state()

func _apply_destroyed_state() -> void:
	visible = not is_destroyed
	input_pickable = not is_destroyed
	monitorable = not is_destroyed

func _get_auto_repair_rate() -> float:
	if not faction_data:
		return 0.0
	return maxf(0.0, faction_data.defense_structure_auto_repair_rate)

func _get_auto_repair_delay() -> float:
	if not faction_data:
		return 0.0
	return maxf(0.0, faction_data.defense_structure_auto_repair_delay)

func is_enemy() -> bool:
	return not is_destroyed