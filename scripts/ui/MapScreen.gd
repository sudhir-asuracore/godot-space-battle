extends Panel
class_name MapScreen

# System Map overlay (opened with the M key). Mirrors the Hangar Store pattern:
# a full-screen Panel whose layout is built here in code (it references the
# GameState / EventBus autoload globals, so — like PlayerHUD — it is validated by
# source inspection rather than the headless --script harness).
#
# Layout (see the issue mock-up):
#   * Top    : header bar with Prestige + Research/Tech points (like the hangar).
#   * Center : mini solar system — planet positions, ownership highlight, allied
#              and (only in-vision) enemy ship symbols, fog of war.
#   * Left   : allied fleet list with each ship's hull / shield state.
#   * Bottom : Deploy bar. The deploy button only activates when the player ship
#              is NOT already on the map AND a hangar-capable planet is selected.
#   * Fog of war + planet identification are read from GameState so the map shows
#              exactly what the faction can currently see / has discovered.

signal map_opened
signal map_closed

var _player_faction: FactionData = null
var _enemy_faction: FactionData = null
var _player_home_planet: Planet = null
var _enemy_home_planet: Planet = null

var _prestige_label: Label
var _tech_label: Label
var _fleet_list: VBoxContainer
var _deploy_button: Button
var _deploy_hint: Label
var _map_canvas: MapCanvas

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.03, 0.06, 0.98)
	add_theme_stylebox_override("panel", bg)
	_build_ui()

func setup(player_faction: FactionData, enemy_faction: FactionData) -> void:
	_player_faction = player_faction
	_enemy_faction = enemy_faction
	if _map_canvas:
		_map_canvas.setup(player_faction, enemy_faction)

func configure_endpoints(player_home_planet: Planet, enemy_home_planet: Planet) -> void:
	_player_home_planet = player_home_planet
	_enemy_home_planet = enemy_home_planet
	if _map_canvas:
		_map_canvas.configure_endpoints(player_home_planet, enemy_home_planet)

# --- Show / hide -------------------------------------------------------------

func show_map() -> void:
	visible = true
	if _map_canvas:
		_map_canvas.set_selected_planet(null)
	_refresh_header()
	_refresh_fleet()
	_refresh_deploy()
	map_opened.emit()

func hide_map() -> void:
	visible = false
	map_closed.emit()

func is_map_visible() -> bool:
	return visible

func toggle_map() -> void:
	if visible:
		hide_map()
	else:
		show_map()

# --- UI construction ---------------------------------------------------------

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	_build_header(root)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)

	_build_fleet_panel(body)
	_build_map_panel(body)

	_build_deploy_bar(root)

func _build_header(root: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	root.add_child(header)

	var back := Button.new()
	back.text = "‹ BACK"
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(110, 40)
	back.pressed.connect(hide_map)
	header.add_child(back)

	var title := Label.new()
	title.text = "SYSTEM MAP"
	title.add_theme_font_size_override("font_size", 32)
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_prestige_label = Label.new()
	_prestige_label.add_theme_font_size_override("font_size", 22)
	_prestige_label.text = "★ 0  PRESTIGE"
	header.add_child(_prestige_label)

	_tech_label = Label.new()
	_tech_label.add_theme_font_size_override("font_size", 22)
	_tech_label.text = "◆ 0  RESEARCH"
	header.add_child(_tech_label)

func _build_fleet_panel(body: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	body.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	var header := Label.new()
	header.text = "// ALLY FLEET"
	header.add_theme_font_size_override("font_size", 18)
	col.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_fleet_list = VBoxContainer.new()
	_fleet_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fleet_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_fleet_list)

func _build_map_panel(body: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0.015, 0.02, 0.045, 1.0)
	inner.set_border_width_all(1)
	inner.border_color = Color(0.2, 0.4, 0.6, 0.4)
	panel.add_theme_stylebox_override("panel", inner)
	body.add_child(panel)

	_map_canvas = MapCanvas.new()
	_map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_canvas.planet_selected.connect(_on_planet_selected)
	panel.add_child(_map_canvas)

func _build_deploy_bar(root: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	root.add_child(bar)

	_deploy_hint = Label.new()
	_deploy_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deploy_hint.text = ""
	bar.add_child(_deploy_hint)

	_deploy_button = Button.new()
	_deploy_button.text = "DEPLOY"
	_deploy_button.focus_mode = Control.FOCUS_NONE
	_deploy_button.custom_minimum_size = Vector2(260, 48)
	_deploy_button.pressed.connect(_on_deploy_pressed)
	bar.add_child(_deploy_button)

# --- Live refresh ------------------------------------------------------------

func _process(_delta: float) -> void:
	if not visible:
		return
	_refresh_header()
	_refresh_fleet()
	_refresh_deploy()

func _refresh_header() -> void:
	if not _player_faction:
		return
	_prestige_label.text = "★ %d  PRESTIGE" % int(GameState.get_prestige(_player_faction))
	_tech_label.text = "◆ %d  RESEARCH" % int(GameState.get_tech_points(_player_faction))

# Rebuilds the allied fleet list from the live "ships" group: every ship of the
# player's faction with its hull / shield state.
func _refresh_fleet() -> void:
	if not _fleet_list:
		return
	for child in _fleet_list.get_children():
		child.queue_free()
	var ships := _allied_ships()
	if ships.is_empty():
		var empty := Label.new()
		empty.text = "No ships deployed"
		empty.modulate = Color(0.7, 0.7, 0.75)
		_fleet_list.add_child(empty)
		return
	for ship in ships:
		_fleet_list.add_child(_make_fleet_entry(ship))

func _make_fleet_entry(ship: Ship) -> Control:
	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 2)

	var ship_name: String = ship.ship_data.name if ship.ship_data else String(ship.name)
	var name_label := Label.new()
	var suffix := "  (YOU)" if ship.is_player_ship else ""
	name_label.text = "%s%s" % [ship_name, suffix]
	entry.add_child(name_label)

	var hull := _make_stat_bar(Color(0.2, 0.9, 0.3), ship.current_hull, ship.max_hull)
	entry.add_child(hull)
	var shield := _make_stat_bar(Color(0.2, 0.6, 1.0), ship.current_shield, ship.max_shield)
	entry.add_child(shield)
	return entry

func _make_stat_bar(color: Color, value: float, max_value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 12)
	bar.show_percentage = false
	bar.max_value = maxf(1.0, max_value)
	bar.value = clampf(value, 0.0, bar.max_value)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	return bar

# Deploy is offered only while the player has NO living ship on the map (the
# fleet was lost / not yet deployed) and a hangar-capable, allied planet is
# selected. The ship deployed is the faction's currently chosen hangar ship.
func _refresh_deploy() -> void:
	if not _deploy_button:
		return
	var has_ship := _player_has_living_ship()
	var selected: Planet = _map_canvas.get_selected_planet() if _map_canvas else null
	var current_ship: ShipData = GameState.get_current_ship(_player_faction) if _player_faction else null

	# The deploy option only appears while the player ship is NOT on the map.
	_deploy_button.visible = not has_ship
	if has_ship:
		_deploy_hint.text = "Your ship is deployed on the map."
		return
	if not current_ship:
		_deploy_button.disabled = true
		_deploy_button.text = "NO SHIP SELECTED"
		_deploy_hint.text = "Pick a ship in the Hangar first, then choose a deploy location."
		return
	if not _is_deployable_planet(selected):
		_deploy_button.disabled = true
		_deploy_button.text = "SELECT DEPLOY LOCATION"
		_deploy_hint.text = "Select a friendly hangar planet (or your homebase) to deploy from."
		return
	_deploy_button.disabled = false
	_deploy_button.text = "DEPLOY: %s" % current_ship.name
	_deploy_hint.text = "Deploy from %s" % _planet_label(selected)

func _on_planet_selected(_planet: Planet) -> void:
	_refresh_deploy()

func _on_deploy_pressed() -> void:
	if _player_has_living_ship():
		return
	var selected: Planet = _map_canvas.get_selected_planet() if _map_canvas else null
	if not _is_deployable_planet(selected):
		return
	var current_ship: ShipData = GameState.get_current_ship(_player_faction)
	if not current_ship:
		return
	var deploy_pos: Vector2 = (selected as Node2D).global_position
	hide_map()
	EventBus.map_deploy_requested.emit(current_ship, deploy_pos)

# --- Helpers -----------------------------------------------------------------

func _allied_ships() -> Array:
	var result: Array = []
	if not _player_faction:
		return result
	for node in get_tree().get_nodes_in_group(&"ships"):
		var ship := node as Ship
		if ship and is_instance_valid(ship) and ship.faction_data == _player_faction and not ship.is_dead:
			result.append(ship)
	return result

func _player_has_living_ship() -> bool:
	for node in get_tree().get_nodes_in_group(&"ships"):
		var ship := node as Ship
		if ship and is_instance_valid(ship) and ship.is_player_ship and not ship.is_dead:
			return true
	return false

# A planet can be deployed from when it can host a hangar AND the player either
# controls it or it is the player's homebase world.
func _is_deployable_planet(planet: Planet) -> bool:
	if not planet or not is_instance_valid(planet):
		return false
	if not (planet.has_method("supports_hangar") and planet.supports_hangar()):
		return false
	if planet == _player_home_planet:
		return true
	return planet.owning_faction == _player_faction

func _planet_label(planet: Planet) -> String:
	if planet == _player_home_planet:
		return "HOMEBASE"
	if planet.planet_data:
		return planet.planet_data.get_type_name()
	return String(planet.name)
