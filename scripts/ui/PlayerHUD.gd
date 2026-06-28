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

# Hangar detail widgets (center stage + stats + currency header + actions).
var _hangar_prestige_label: Label
var _hangar_tech_label: Label
var _hangar_portrait: TextureRect
var _hangar_name_label: Label
var _hangar_desc_label: Label
var _hangar_stats_label: Label
var _hangar_purchase_button: Button
var _hangar_deploy_button: Button

var _shop_faction: FactionData = null
# Ships currently listed in the hangar (filtered to valid ShipData entries).
var _hangar_ships: Array = []
# Ship currently highlighted in the hangar detail view (not yet deployed).
var _hangar_selected: ShipData = null

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

	# Full-screen hangar overlay. Used both for the start-of-match picker and for
	# swapping/redeploying the active ship from the homebase hangar.
	_build_hangar()

# Builds the hangar overlay: a currency header, a scrollable ship list on the
# left, the selected ship's portrait + role blurb in the center, its stats on
# the right, and Purchase / Deploy actions along the bottom.
func _build_hangar() -> void:
	_ship_select_panel = Panel.new()
	_ship_select_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ship_select_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_ship_select_panel.visible = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.05, 0.09, 0.96)
	_ship_select_panel.add_theme_stylebox_override("panel", bg)
	add_child(_ship_select_panel)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 48)
	root.add_theme_constant_override("margin_right", 48)
	root.add_theme_constant_override("margin_top", 32)
	root.add_theme_constant_override("margin_bottom", 32)
	_ship_select_panel.add_child(root)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	root.add_child(column)

	# Header: title on the left, prestige + tech-point balances on the right.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	column.add_child(header)
	_ship_select_title = _make_label("HANGAR")
	_ship_select_title.add_theme_font_size_override("font_size", 32)
	header.add_child(_ship_select_title)
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(header_spacer)
	_hangar_prestige_label = _make_label("Prestige: 0")
	_hangar_prestige_label.add_theme_font_size_override("font_size", 22)
	header.add_child(_hangar_prestige_label)
	_hangar_tech_label = _make_label("Tech Points: 0")
	_hangar_tech_label.add_theme_font_size_override("font_size", 22)
	header.add_child(_hangar_tech_label)

	_ship_select_subtitle = _make_label("Choose a ship to deploy")
	_ship_select_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_ship_select_subtitle)

	# Body: ship list | center portrait | stats.
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	column.add_child(body)

	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(360, 0)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(list_scroll)
	_ship_select_buttons = VBoxContainer.new()
	_ship_select_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ship_select_buttons.add_theme_constant_override("separation", 6)
	list_scroll.add_child(_ship_select_buttons)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8)
	body.add_child(center)
	_hangar_portrait = TextureRect.new()
	_hangar_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hangar_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hangar_portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hangar_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hangar_portrait.custom_minimum_size = Vector2(0, 320)
	_hangar_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_hangar_portrait)
	_hangar_name_label = _make_label("")
	_hangar_name_label.add_theme_font_size_override("font_size", 28)
	_hangar_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_hangar_name_label)
	_hangar_desc_label = _make_label("")
	_hangar_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hangar_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_hangar_desc_label)

	var stats_box := VBoxContainer.new()
	stats_box.custom_minimum_size = Vector2(320, 0)
	stats_box.add_theme_constant_override("separation", 6)
	body.add_child(stats_box)
	stats_box.add_child(_make_label("// STATS"))
	_hangar_stats_label = _make_label("")
	stats_box.add_child(_hangar_stats_label)

	# Footer: Purchase (spend prestige) and Deploy (launch the owned ship).
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	column.add_child(footer)
	_hangar_purchase_button = Button.new()
	_hangar_purchase_button.custom_minimum_size = Vector2(220, 48)
	_hangar_purchase_button.focus_mode = Control.FOCUS_NONE
	_hangar_purchase_button.pressed.connect(_on_hangar_purchase_pressed)
	footer.add_child(_hangar_purchase_button)
	_hangar_deploy_button = Button.new()
	_hangar_deploy_button.custom_minimum_size = Vector2(220, 48)
	_hangar_deploy_button.focus_mode = Control.FOCUS_NONE
	_hangar_deploy_button.pressed.connect(_on_hangar_deploy_pressed)
	footer.add_child(_hangar_deploy_button)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(footer_spacer)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(120, 48)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(hide_ship_selection)
	footer.add_child(close_button)

# Populates and shows the hangar for the given faction. Each ship becomes a
# clickable row; selecting one shows its detail, and the footer Purchase/Deploy
# buttons spend prestige / emit EventBus.player_ship_selected respectively.
func show_ship_selection(faction: FactionData, ships: Array, subtitle: String = "Choose a ship to deploy") -> void:
	if not _ship_select_panel:
		return
	_shop_faction = faction
	_hangar_ships = []
	for entry in ships:
		var ship_data := entry as ShipData
		if ship_data:
			_hangar_ships.append(ship_data)
	_ship_select_title.text = "HANGAR — %s" % faction.get_faction_short_name() if faction else "HANGAR"
	_ship_select_subtitle.text = subtitle

	# Default the detail view to the faction's current ship, otherwise the first
	# owned ship, otherwise the first listed ship.
	var initial: ShipData = GameState.get_current_ship(faction)
	if not initial or not _hangar_ships.has(initial):
		initial = _hangar_ships[0] if not _hangar_ships.is_empty() else null

	_refresh_ship_list()
	_select_hangar_ship(initial)
	_refresh_currencies()
	_ship_select_panel.visible = true
	# Swap the hidden in-game reticle for the system cursor so the player can see
	# the pointer while interacting with the full-screen hangar overlay.
	if _pointer_reticle:
		_pointer_reticle.set_active(false)

func hide_ship_selection() -> void:
	if _ship_select_panel:
		_ship_select_panel.visible = false
	_shop_faction = null
	_hangar_selected = null
	# Restore the in-game reticle once the hangar overlay closes.
	if _pointer_reticle:
		_pointer_reticle.set_active(true)

func is_ship_selection_visible() -> bool:
	return _ship_select_panel != null and _ship_select_panel.visible

# Rebuilds the scrollable ship list, reflecting ownership and affordability and
# highlighting the ship currently shown in the detail view.
func _refresh_ship_list() -> void:
	if not _ship_select_buttons:
		return
	for child in _ship_select_buttons.get_children():
		child.queue_free()
	if _hangar_ships.is_empty():
		_ship_select_buttons.add_child(_make_label("No ships configured"))
		return
	for entry in _hangar_ships:
		_ship_select_buttons.add_child(_make_ship_button(entry as ShipData))

func _make_ship_button(ship_data: ShipData) -> Button:
	var button := Button.new()
	button.icon = ship_data.get_hangar_icon()
	button.expand_icon = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 64)
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = true
	button.button_pressed = ship_data == _hangar_selected
	var owned: bool = GameState.is_ship_owned(_shop_faction, ship_data)
	var status := ""
	if owned:
		status = "OWNED" if not ship_data.is_starter else "FREE"
	else:
		status = "★ %d" % int(ship_data.purchase_cost)
		if not GameState.can_afford_ship(_shop_faction, ship_data):
			status += " (LOCKED)"
			button.modulate = Color(1.0, 0.6, 0.6)
	button.text = "%s\n%s T%d   %s" % [ship_data.name, ship_data.get_ship_class_name(), ship_data.tier, status]
	button.pressed.connect(_on_ship_button_pressed.bind(ship_data))
	return button

# A list row was clicked: show that ship in the detail view (does NOT deploy).
func _on_ship_button_pressed(ship_data: ShipData) -> void:
	_select_hangar_ship(ship_data)

# Updates the center portrait, name, role blurb, stats and the footer buttons to
# reflect the chosen ship and the faction's economy.
func _select_hangar_ship(ship_data: ShipData) -> void:
	_hangar_selected = ship_data
	if not ship_data:
		_hangar_name_label.text = ""
		_hangar_desc_label.text = ""
		_hangar_stats_label.text = ""
		_hangar_portrait.texture = null
		_update_action_buttons()
		_refresh_ship_list()
		return
	_hangar_portrait.texture = ship_data.get_hangar_portrait()
	_hangar_name_label.text = ship_data.name
	_hangar_desc_label.text = ship_data.description
	_hangar_stats_label.text = "\n".join([
		"HULL       %d" % int(ship_data.max_hull),
		"SHIELD     %d" % int(ship_data.max_shield),
		"ENERGY     %d" % int(ship_data.max_capacitor),
		"SPEED      %d" % int(ship_data.max_speed),
		"TURN RATE  %d" % int(ship_data.turn_speed * 10.0),
	])
	_update_action_buttons()
	_refresh_ship_list()

# Toggles the Purchase / Deploy buttons based on whether the selected ship is
# owned and affordable.
func _update_action_buttons() -> void:
	var ship_data := _hangar_selected
	if not ship_data:
		_hangar_purchase_button.disabled = true
		_hangar_purchase_button.text = "Purchase Ship"
		_hangar_deploy_button.disabled = true
		_hangar_deploy_button.text = "Deploy"
		return
	var owned: bool = GameState.is_ship_owned(_shop_faction, ship_data)
	if owned:
		_hangar_purchase_button.disabled = true
		_hangar_purchase_button.text = "Owned"
		_hangar_deploy_button.disabled = false
		_hangar_deploy_button.text = "Deploy"
	else:
		var affordable: bool = GameState.can_afford_ship(_shop_faction, ship_data)
		_hangar_purchase_button.disabled = not affordable
		_hangar_purchase_button.text = "Purchase ★ %d" % int(ship_data.purchase_cost)
		_hangar_deploy_button.disabled = true
		_hangar_deploy_button.text = "Deploy"

func _refresh_currencies() -> void:
	_hangar_prestige_label.text = "★ %d  PRESTIGE" % int(GameState.get_prestige(_shop_faction))
	_hangar_tech_label.text = "◆ %d  TECH POINTS" % int(GameState.get_tech_points(_shop_faction))

# Purchase spends prestige to unlock the selected ship (Milestone 7).
func _on_hangar_purchase_pressed() -> void:
	if not _hangar_selected or not _shop_faction:
		return
	if GameState.purchase_ship(_shop_faction, _hangar_selected):
		_refresh_currencies()
		_select_hangar_ship(_hangar_selected)

# Deploy launches the selected owned ship: persist the choice, then ask Main to
# (re)spawn it via the existing player_ship_selected signal.
func _on_hangar_deploy_pressed() -> void:
	if not _hangar_selected or not _shop_faction:
		return
	if not GameState.is_ship_owned(_shop_faction, _hangar_selected):
		return
	GameState.set_current_ship(_shop_faction, _hangar_selected)
	var deployed := _hangar_selected
	hide_ship_selection()
	EventBus.player_ship_selected.emit(deployed)

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
	# Keep the hangar's currencies and affordability live so passive prestige
	# income can unlock a locked ship while the player is browsing.
	if is_ship_selection_visible():
		_refresh_currencies()
		_update_action_buttons()

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
