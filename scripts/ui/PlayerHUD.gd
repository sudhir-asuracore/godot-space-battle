extends Control
class_name PlayerHUD

# Player HUD (PRD section 15.1): hull, shield, capacitor, prestige,
# owned planets, majority control, enemy homebase shield, ability cooldown.

var _ship: Ship = null
var _player_faction: FactionData = null
var _enemy_faction: FactionData = null
var _ability: AbilityController = null

var _hull_bar: ProgressBar
var _shield_bar: ProgressBar
var _cap_bar: ProgressBar
var _prestige_label: Label
var _planets_label: Label
var _majority_label: Label
var _shield_label: Label
var _ability_label: Label
var _target_label: Label
var _ship_select_panel: Panel
var _ship_select_title: Label
var _ship_select_subtitle: Label
var _ship_select_buttons: VBoxContainer
var _abilities_bar: AbilitiesBar
var _pointer_reticle: PointerReticle
var _planet_bar: SystemPlanetBar

var _shop_faction: FactionData = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	EventBus.hangar_shop_requested.connect(_on_hangar_shop_requested)

func setup(ship: Ship, player_faction: FactionData, enemy_faction: FactionData, ability: AbilityController) -> void:
	_ship = ship
	_player_faction = player_faction
	_enemy_faction = enemy_faction
	_ability = ability
	if _abilities_bar:
		_abilities_bar.setup(ship, ability)
	if _pointer_reticle:
		_pointer_reticle.setup(ship)
	if _planet_bar:
		_planet_bar.setup(player_faction, enemy_faction)

# Provides the system's two homebase planets so the top planet bar can orient
# itself (player end on the left) and highlight the homebase nodes.
func configure_system_endpoints(player_home_planet: Planet, enemy_home_planet: Planet) -> void:
	if _planet_bar:
		_planet_bar.configure_endpoints(player_home_planet, enemy_home_planet)

func _build_ui() -> void:
	_abilities_bar = AbilitiesBar.new()
	_abilities_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_abilities_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_abilities_bar)

	_pointer_reticle = PointerReticle.new()
	_pointer_reticle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pointer_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pointer_reticle)

	# Top-of-screen planet array showing system control between both factions.
	_planet_bar = SystemPlanetBar.new()
	_planet_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_planet_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_planet_bar)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(15, -250)
	panel.custom_minimum_size = Vector2(330, 235)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(10, 8)
	vbox.custom_minimum_size = Vector2(310, 0)
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)
	
	vbox.add_child(_make_label("Hull"))
	_hull_bar = _make_bar(Color(0.2, 0.9, 0.3))
	vbox.add_child(_hull_bar)
	
	vbox.add_child(_make_label("Shield"))
	_shield_bar = _make_bar(Color(0.2, 0.6, 1.0))
	vbox.add_child(_shield_bar)
	
	vbox.add_child(_make_label("Capacitor"))
	_cap_bar = _make_bar(Color(1.0, 0.8, 0.2))
	vbox.add_child(_cap_bar)
	
	_prestige_label = _make_label("Prestige: 0")
	vbox.add_child(_prestige_label)
	_planets_label = _make_label("Planets: 0 / 0")
	vbox.add_child(_planets_label)
	_majority_label = _make_label("Majority: --")
	vbox.add_child(_majority_label)
	_shield_label = _make_label("Enemy Shield: UP")
	vbox.add_child(_shield_label)
	_ability_label = _make_label("[1] Afterburner: READY")
	vbox.add_child(_ability_label)
	_target_label = _make_label("Target: none")
	vbox.add_child(_target_label)

	# Ship selection panel: lists the faction's available ships as clickable
	# buttons. Used both for the start-of-match picker and for swapping the
	# active ship from the hangar.
	_ship_select_panel = Panel.new()
	_ship_select_panel.set_anchors_preset(Control.PRESET_CENTER)
	_ship_select_panel.position = Vector2(-220, -180)
	_ship_select_panel.custom_minimum_size = Vector2(440, 360)
	_ship_select_panel.size = Vector2(440, 360)
	_ship_select_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_ship_select_panel.visible = false
	add_child(_ship_select_panel)

	var select_box := VBoxContainer.new()
	select_box.position = Vector2(18, 16)
	select_box.custom_minimum_size = Vector2(404, 328)
	select_box.add_theme_constant_override("separation", 8)
	select_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ship_select_panel.add_child(select_box)

	_ship_select_title = _make_label("Select Ship")
	select_box.add_child(_ship_select_title)

	_ship_select_subtitle = _make_label("Choose a ship to deploy")
	_ship_select_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	select_box.add_child(_ship_select_subtitle)

	_ship_select_buttons = VBoxContainer.new()
	_ship_select_buttons.custom_minimum_size = Vector2(404, 0)
	_ship_select_buttons.add_theme_constant_override("separation", 6)
	select_box.add_child(_ship_select_buttons)

# Populates and shows the ship selection panel for the given faction. Each ship
# becomes a clickable button that emits EventBus.player_ship_selected.
func show_ship_selection(faction: FactionData, ships: Array, subtitle: String = "Choose a ship to deploy") -> void:
	if not _ship_select_panel:
		return
	_shop_faction = faction
	_ship_select_title.text = "%s Hangar" % faction.name if faction else "Select Ship"
	_ship_select_subtitle.text = subtitle

	for child in _ship_select_buttons.get_children():
		child.queue_free()

	var has_ships := false
	for entry in ships:
		var ship_data := entry as ShipData
		if not ship_data:
			continue
		has_ships = true
		_ship_select_buttons.add_child(_make_ship_button(ship_data))

	if not has_ships:
		_ship_select_buttons.add_child(_make_label("No ships configured"))

	_ship_select_panel.visible = true

func hide_ship_selection() -> void:
	if _ship_select_panel:
		_ship_select_panel.visible = false
	_shop_faction = null

func is_ship_selection_visible() -> bool:
	return _ship_select_panel != null and _ship_select_panel.visible

func _make_ship_button(ship_data: ShipData) -> Button:
	var button := Button.new()
	button.text = "%s  —  %s (Tier %d)" % [ship_data.name, ship_data.ship_class, ship_data.tier]
	button.custom_minimum_size = Vector2(404, 40)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_ship_button_pressed.bind(ship_data))
	return button

func _on_ship_button_pressed(ship_data: ShipData) -> void:
	hide_ship_selection()
	EventBus.player_ship_selected.emit(ship_data)

func _on_hangar_shop_requested(faction: FactionData, ships: Array) -> void:
	if not faction:
		return
	# Toggle the panel off when the same faction's hangar is clicked again.
	if is_ship_selection_visible() and faction == _shop_faction:
		hide_ship_selection()
		return
	show_ship_selection(faction, ships, "Select a ship to deploy from the hangar")

func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _make_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(300, 14)
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _process(_delta: float) -> void:
	if not _ship or not is_instance_valid(_ship):
		return
	
	if _ship.is_dead:
		_hull_bar.value = 0
		_shield_bar.value = 0
	else:
		_hull_bar.max_value = max(1.0, _ship.max_hull)
		_hull_bar.value = max(0.0, _ship.current_hull)
		_shield_bar.max_value = max(1.0, _ship.max_shield)
		_shield_bar.value = max(0.0, _ship.current_shield)
		_cap_bar.max_value = max(1.0, _ship.max_capacitor)
		_cap_bar.value = max(0.0, _ship.current_capacitor)
	
	_prestige_label.text = "Prestige: %d" % int(GameState.get_prestige(_player_faction))
	
	var owned: int = GameState.get_planet_count(_player_faction)
	var total: int = GameState.get_total_planets()
	_planets_label.text = "Planets: %d / %d" % [owned, total]
	
	var majority: FactionData = GameState.get_majority_faction()
	if majority == _player_faction:
		_majority_label.text = "Majority: YOU control the system"
	elif majority == _enemy_faction:
		_majority_label.text = "Majority: ENEMY controls the system"
	else:
		_majority_label.text = "Majority: contested"
	
	var enemy_shield_up: bool = GameState.is_homebase_shield_active(_enemy_faction)
	_shield_label.text = "Enemy Shield: %s" % ("UP (capture majority)" if enemy_shield_up else "DOWN - SIEGE!")
	
	if _ability:
		var cd: float = _ability.get_ability_1_cooldown()
		if cd <= 0.0:
			_ability_label.text = "[1] Afterburner: READY"
		else:
			_ability_label.text = "[1] Afterburner: %.1fs" % cd
	
	var tgt: Node2D = null
	if _ship.has_node("TargetingController"):
		tgt = (_ship.get_node("TargetingController") as TargetingController).locked_target
	if tgt and is_instance_valid(tgt):
		_target_label.text = "Target: %s" % tgt.name
	else:
		_target_label.text = "Target: none"
