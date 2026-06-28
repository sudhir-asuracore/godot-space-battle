extends Control
class_name FactionSelectionScreen

const TITLE_SCENE_PATH := "res://ui/TitleScreen.tscn"
const GAME_SCENE_PATH := "res://scenes/Main.tscn"

const THEME_TEXT := Color(0.83, 0.92, 0.98, 1.0)
const THEME_TEXT_MUTED := Color(0.5, 0.64, 0.73, 1.0)
const THEME_TEXT_DISABLED := Color(0.36, 0.46, 0.54, 1.0)
const THEME_ACCENT_TEXT := Color(0.12, 0.08, 0.02, 1.0)

const THEME_OVERLAY := Color(0.01, 0.06, 0.1, 0.56)
const THEME_PANEL_BG := Color(0.01, 0.03, 0.06, 0.92)
const THEME_ROW_BG := Color(0.01, 0.05, 0.08, 0.92)
const THEME_ROW_DISABLED_BG := Color(0.015, 0.02, 0.03, 0.9)
const THEME_BORDER := Color(0.35, 0.74, 0.86, 1.0)
const THEME_BORDER_DIM := Color(0.17, 0.36, 0.45, 1.0)
const THEME_ACCENT := Color(0.84, 0.64, 0.18, 1.0)
const THEME_ACCENT_BG := Color(0.41, 0.26, 0.05, 0.96)

const FACTION_CONFIG := {
	"Solaris": {
		"faction_path": "res://resources/factions/solarion_collective/solarion_collective.tres",
		"ship_path": "res://resources/factions/solarion_collective/ships/striker_lance.tres",
		"ship_scene_path": "res://scenes/factions/solarion/ships/StrikerLance.tscn",
		"enemy_faction_path": "res://resources/factions/zarak/zarak_confedaracy.tres",
		"enemy_ship_path": "res://resources/factions/zarak/ships/scout.tres",
		"enemy_ship_scene_path": "res://scenes/factions/zarak/ships/Scout.tscn"
	},
	"Zerek": {
		"faction_path": "res://resources/factions/zarak/zarak_confedaracy.tres",
		"ship_path": "res://resources/factions/zarak/ships/scout.tres",
		"ship_scene_path": "res://scenes/factions/zarak/ships/Scout.tscn",
		"enemy_faction_path": "res://resources/factions/solarion_collective/solarion_collective.tres",
		"enemy_ship_path": "res://resources/factions/solarion_collective/ships/striker_lance.tres",
		"enemy_ship_scene_path": "res://scenes/factions/solarion/ships/StrikerLance.tscn"
	},
	"Aegis": {
		"faction_path": "res://resources/factions/solarion_collective/solarion_collective.tres",
		"ship_path": "res://resources/factions/solarion_collective/ships/striker_lance.tres",
		"ship_scene_path": "res://scenes/factions/solarion/ships/StrikerLance.tscn",
		"enemy_faction_path": "res://resources/factions/zarak/zarak_confedaracy.tres",
		"enemy_ship_path": "res://resources/factions/zarak/ships/scout.tres",
		"enemy_ship_scene_path": "res://scenes/factions/zarak/ships/Scout.tscn"
	}
}

const FACTION_DESCRIPTIONS := {
	"Solaris": [
		"Frontline tacticians who trust precision strikes and coordinated wing maneuvers.",
		"White-hot engines and high discipline make Solaris fleets relentless in open space.",
		"Solaris commanders prefer elegant solutions: fast interception and perfect timing."
	],
	"Zerek": [
		"Heavy armor, overwhelming thrust, and siege doctrine define the Zerek war machine.",
		"Zerek captains absorb punishment before crushing targets with brutal close-range volleys.",
		"Industrial battlecraft and stubborn formations make Zerek difficult to dislodge."
	],
	"Aegis": [
		"Defensive specialists who shape the battlefield with resilient shield envelopes.",
		"Aegis doctrine favors controlled advances and strong capacitor management under pressure.",
		"Reliable hulls, adaptive command chains, and layered protection are Aegis trademarks."
	]
}

@onready var _solaris_button: Button = $LeftPanel/VBox/SolarisButton as Button
@onready var _zerek_button: Button = $LeftPanel/VBox/ZerekButton as Button
@onready var _aegis_button: Button = $LeftPanel/VBox/AegisButton as Button
@onready var _description_label: RichTextLabel = $RightPanel/VBox/DescriptionLabel as RichTextLabel
@onready var _play_button: Button = $PlayButton as Button
@onready var _back_button: Button = $BackButton as Button
@onready var _left_panel: PanelContainer = $LeftPanel as PanelContainer
@onready var _right_panel: PanelContainer = $RightPanel as PanelContainer
@onready var _left_vbox: VBoxContainer = $LeftPanel/VBox as VBoxContainer
@onready var _right_vbox: VBoxContainer = $RightPanel/VBox as VBoxContainer
@onready var _header_label: Label = $LeftPanel/VBox/Header as Label
@onready var _briefing_title: Label = $RightPanel/VBox/Title as Label
@onready var _overlay: ColorRect = $Overlay as ColorRect

var _selected_faction_name: String = ""

func _ready() -> void:
	randomize()
	AudioManager.start_menu_ambient()

	_apply_screen_theme()

	_apply_button_theme(_solaris_button)
	_apply_button_theme(_zerek_button)
	_apply_button_theme(_aegis_button)
	_apply_button_theme(_play_button, true)
	_apply_button_theme(_back_button)

	_solaris_button.pressed.connect(_on_faction_selected.bind("Solaris"))
	_zerek_button.pressed.connect(_on_faction_selected.bind("Zerek"))
	_aegis_button.pressed.connect(_on_faction_selected.bind("Aegis"))
	_play_button.pressed.connect(_on_play_pressed)
	_back_button.pressed.connect(_on_back_pressed)

	_play_button.disabled = true
	_description_label.text = "Select a faction to view command intelligence and unlock deployment."

func _apply_screen_theme() -> void:
	_overlay.color = THEME_OVERLAY
	_left_vbox.add_theme_constant_override(&"separation", 12)
	_right_vbox.add_theme_constant_override(&"separation", 10)

	_apply_panel_theme(_left_panel)
	_apply_panel_theme(_right_panel)

	_header_label.add_theme_color_override(&"font_color", THEME_ACCENT)
	_briefing_title.add_theme_color_override(&"font_color", THEME_ACCENT)

	_description_label.add_theme_color_override(&"default_color", THEME_TEXT)
	_description_label.add_theme_color_override(&"font_outline_color", THEME_TEXT_MUTED)
	var description_box := StyleBoxFlat.new()
	description_box.bg_color = THEME_ROW_BG
	description_box.border_width_left = 2
	description_box.border_width_top = 1
	description_box.border_width_right = 1
	description_box.border_width_bottom = 1
	description_box.border_color = THEME_BORDER_DIM
	description_box.corner_radius_top_left = 4
	description_box.corner_radius_top_right = 4
	description_box.corner_radius_bottom_left = 4
	description_box.corner_radius_bottom_right = 4
	description_box.content_margin_left = 16
	description_box.content_margin_top = 12
	description_box.content_margin_right = 16
	description_box.content_margin_bottom = 12
	_description_label.add_theme_stylebox_override(&"normal", description_box)

func _apply_panel_theme(panel: PanelContainer) -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = THEME_PANEL_BG
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = THEME_BORDER_DIM
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 18
	panel_style.content_margin_top = 14
	panel_style.content_margin_right = 18
	panel_style.content_margin_bottom = 16
	panel.add_theme_stylebox_override(&"panel", panel_style)

func _apply_button_theme(button: Button, is_primary: bool = false) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true

	button.add_theme_color_override(&"font_color", THEME_ACCENT_TEXT if is_primary else THEME_TEXT)
	button.add_theme_color_override(&"font_hover_color", THEME_ACCENT_TEXT if is_primary else THEME_TEXT)
	button.add_theme_color_override(&"font_pressed_color", THEME_ACCENT_TEXT)
	button.add_theme_color_override(&"font_disabled_color", THEME_TEXT_DISABLED)

	var normal_style := _make_row_style(
		THEME_ACCENT_BG if is_primary else THEME_ROW_BG,
		THEME_ACCENT if is_primary else THEME_BORDER_DIM,
		3 if is_primary else 2
	)
	var hover_style := _make_row_style(normal_style.bg_color.lerp(THEME_BORDER, 0.12), THEME_BORDER, 3)
	var pressed_style := _make_row_style(THEME_ACCENT_BG, THEME_ACCENT, 3)
	var disabled_style := _make_row_style(THEME_ROW_DISABLED_BG, THEME_BORDER_DIM, 1)

	button.add_theme_stylebox_override(&"normal", normal_style)
	button.add_theme_stylebox_override(&"hover", hover_style)
	button.add_theme_stylebox_override(&"pressed", pressed_style)
	button.add_theme_stylebox_override(&"hover_pressed", pressed_style)
	button.add_theme_stylebox_override(&"focus", hover_style)
	button.add_theme_stylebox_override(&"disabled", disabled_style)

func _make_row_style(bg_color: Color, border_color: Color, left_border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = left_border_width
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 16
	style.content_margin_top = 12
	style.content_margin_right = 12
	style.content_margin_bottom = 12
	return style

func _on_faction_selected(faction_name: String) -> void:
	_play_menu_click()
	_selected_faction_name = faction_name
	_solaris_button.button_pressed = faction_name == "Solaris"
	_zerek_button.button_pressed = faction_name == "Zerek"
	_aegis_button.button_pressed = faction_name == "Aegis"

	_play_button.disabled = false
	_description_label.text = _build_random_description(faction_name)

func _build_random_description(faction_name: String) -> String:
	var descriptions: Array = FACTION_DESCRIPTIONS.get(faction_name, [])
	if descriptions.is_empty():
		return "[color=#d6a74a][b]%s[/b][/color]\n\nNo intelligence data available." % faction_name
	var random_index: int = randi_range(0, descriptions.size() - 1)
	return "[color=#d6a74a][b]%s[/b][/color]\n\n%s" % [faction_name, str(descriptions[random_index])]

func _on_play_pressed() -> void:
	if _selected_faction_name.is_empty():
		return
	_play_menu_click()
	AudioManager.stop_menu_ambient()

	var selected_config: Dictionary = FACTION_CONFIG.get(_selected_faction_name, {})
	GameState.selected_faction_id = _selected_faction_name
	GameState.selected_faction_path = str(selected_config.get("faction_path", ""))
	GameState.selected_ship_data_path = str(selected_config.get("ship_path", ""))
	GameState.selected_ship_scene_path = str(selected_config.get("ship_scene_path", ""))
	GameState.selected_enemy_faction_path = str(selected_config.get("enemy_faction_path", ""))
	GameState.selected_enemy_ship_data_path = str(selected_config.get("enemy_ship_path", ""))
	GameState.selected_enemy_ship_scene_path = str(selected_config.get("enemy_ship_scene_path", ""))
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_back_pressed() -> void:
	_play_menu_click()
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)

func _play_menu_click() -> void:
	AudioManager.play_menu_click()
