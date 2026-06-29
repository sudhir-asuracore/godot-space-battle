extends Panel
class_name HangarStore

# Standalone Hangar Store overlay (Milestone 7). Previously this UI was built
# entirely in code inside PlayerHUD; it now lives in its own scene
# (ui/HangarStore.tscn) so the layout — backgrounds, portraits, custom textures —
# can be authored visually in the editor. PlayerHUD instances this scene and
# delegates its show/hide API to it.
#
# The store spends prestige to purchase ships, deploys an owned ship via the
# existing EventBus.player_ship_selected signal, and exposes a tech-point header.

# Emitted when the store is shown / hidden so the owner (PlayerHUD) can swap the
# in-game pointer reticle for the system cursor while the overlay is open.
signal store_opened
signal store_closed

@onready var _title_label: Label = $Margin/Column/Header/TitleLabel
@onready var _prestige_label: Label = $Margin/Column/Header/PrestigeLabel
@onready var _tech_label: Label = $Margin/Column/Header/TechLabel
@onready var _subtitle_label: Label = $Margin/Column/SubtitleLabel
@onready var _ship_list: VBoxContainer = $Margin/Column/Body/ListScroll/ShipList
@onready var _portrait: TextureRect = $Margin/Column/Body/Center/Portrait
@onready var _name_label: Label = $Margin/Column/Body/Center/NameLabel
@onready var _desc_label: Label = $Margin/Column/Body/Center/DescLabel
@onready var _stats_label: Label = $Margin/Column/Body/StatsBox/StatsLabel
@onready var _purchase_button: Button = $Margin/Column/Footer/PurchaseButton
@onready var _deploy_button: Button = $Margin/Column/Footer/DeployButton
@onready var _close_button: Button = $Margin/Column/Footer/CloseButton

var _shop_faction: FactionData = null
# Ships currently listed in the hangar (filtered to valid ShipData entries).
var _hangar_ships: Array = []
# Ship currently highlighted in the detail view (not yet deployed).
var _hangar_selected: ShipData = null

func _ready() -> void:
	visible = false
	_purchase_button.pressed.connect(_on_purchase_pressed)
	_deploy_button.pressed.connect(_on_deploy_pressed)
	_close_button.pressed.connect(hide_ship_selection)
	EventBus.hangar_shop_requested.connect(_on_hangar_shop_requested)

# Populates and shows the hangar for the given faction. Each ship becomes a
# clickable row; selecting one shows its detail, and the footer Purchase/Deploy
# buttons spend prestige / emit EventBus.player_ship_selected respectively.
func show_ship_selection(faction: FactionData, ships: Array, subtitle: String = "Choose a ship to deploy") -> void:
	_shop_faction = faction
	_hangar_ships = []
	for entry in ships:
		var ship_data := entry as ShipData
		if ship_data:
			_hangar_ships.append(ship_data)
	_title_label.text = "HANGAR — %s" % faction.get_faction_short_name() if faction else "HANGAR"
	_subtitle_label.text = subtitle

	# Default the detail view to the faction's current ship, otherwise the first
	# owned ship, otherwise the first listed ship.
	var initial: ShipData = GameState.get_current_ship(faction)
	if not initial or not _hangar_ships.has(initial):
		initial = _hangar_ships[0] if not _hangar_ships.is_empty() else null

	_refresh_ship_list()
	_select_hangar_ship(initial)
	_refresh_currencies()
	visible = true
	store_opened.emit()

func hide_ship_selection() -> void:
	visible = false
	_shop_faction = null
	_hangar_selected = null
	store_closed.emit()

func is_ship_selection_visible() -> bool:
	return visible

# Rebuilds the scrollable ship list, reflecting ownership and affordability and
# highlighting the ship currently shown in the detail view.
func _refresh_ship_list() -> void:
	if not _ship_list:
		return
	for child in _ship_list.get_children():
		child.queue_free()
	if _hangar_ships.is_empty():
		_ship_list.add_child(_make_label("No ships configured"))
		return
	for entry in _hangar_ships:
		_ship_list.add_child(_make_ship_button(entry as ShipData))

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
		_name_label.text = ""
		_desc_label.text = ""
		_stats_label.text = ""
		_portrait.texture = null
		_update_action_buttons()
		_refresh_ship_list()
		return
	_portrait.texture = ship_data.get_hangar_portrait()
	_name_label.text = ship_data.name
	_desc_label.text = ship_data.description
	_stats_label.text = "\n".join([
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
		_purchase_button.disabled = true
		_purchase_button.text = "Purchase Ship"
		_deploy_button.disabled = true
		_deploy_button.text = "Deploy"
		return
	var owned: bool = GameState.is_ship_owned(_shop_faction, ship_data)
	if owned:
		_purchase_button.disabled = true
		_purchase_button.text = "Owned"
		_deploy_button.disabled = false
		_deploy_button.text = "Deploy"
	else:
		var affordable: bool = GameState.can_afford_ship(_shop_faction, ship_data)
		_purchase_button.disabled = not affordable
		_purchase_button.text = "Purchase ★ %d" % int(ship_data.purchase_cost)
		_deploy_button.disabled = true
		_deploy_button.text = "Deploy"

func _refresh_currencies() -> void:
	_prestige_label.text = "★ %d  PRESTIGE" % int(GameState.get_prestige(_shop_faction))
	_tech_label.text = "◆ %d  TECH POINTS" % int(GameState.get_tech_points(_shop_faction))

# Purchase spends prestige to unlock the selected ship (Milestone 7).
func _on_purchase_pressed() -> void:
	if not _hangar_selected or not _shop_faction:
		return
	if GameState.purchase_ship(_shop_faction, _hangar_selected):
		_refresh_currencies()
		_select_hangar_ship(_hangar_selected)

# Deploy launches the selected owned ship: persist the choice, then ask Main to
# (re)spawn it via the existing player_ship_selected signal.
func _on_deploy_pressed() -> void:
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

func _process(_delta: float) -> void:
	# Keep the hangar's currencies and affordability live so passive prestige
	# income can unlock a locked ship while the player is browsing.
	if is_ship_selection_visible():
		_refresh_currencies()
		_update_action_buttons()
