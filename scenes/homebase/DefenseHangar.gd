extends Area2D
class_name DefenseHangar

var faction_data: FactionData = null
var homebase: Homebase = null

func configure(faction: FactionData, owner_homebase: Homebase) -> void:
	faction_data = faction
	homebase = owner_homebase

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	if GameState.player_faction and faction_data != GameState.player_faction:
		return

	var ships: Array = []
	if faction_data:
		ships = faction_data.hangar_ship_options.duplicate()

	EventBus.hangar_shop_requested.emit(faction_data, ships)