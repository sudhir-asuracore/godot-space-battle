extends Control
class_name TitleScreen

const FACTION_SELECTION_SCENE_PATH := "res://ui/FactionSelectionScreen.tscn"
const OPTIONS_SCENE_PATH := "res://ui/OptionsScreen.tscn"

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
const THEME_ACCENT := Color(0.844, 0.565, 0.0, 1.0)
const THEME_ACCENT_BG := Color(0.651, 0.416, 0.106, 0.824)

@onready var _play_button: Button = $MenuPanel/VBox/PlayButton as Button
@onready var _multiplayer_button: Button = $MenuPanel/VBox/MultiplayerButton as Button
@onready var _options_button: Button = $MenuPanel/VBox/OptionsButton as Button
@onready var _exit_button: Button = $MenuPanel/VBox/ExitButton as Button
@onready var _menu_panel: PanelContainer = $MenuPanel as PanelContainer
@onready var _menu_vbox: VBoxContainer = $MenuPanel/VBox as VBoxContainer
@onready var _title_label: Label = $MenuPanel/VBox/TitleLabel as Label
@onready var _subtitle_label: Label = $MenuPanel/VBox/SubtitleLabel as Label
@onready var _overlay: ColorRect = $Overlay as ColorRect
@onready var _planet: Node2D = $Planet02

func _ready() -> void:
	AudioManager.start_menu_ambient()
	_apply_screen_theme()

	_apply_button_theme(_play_button, true)
	_apply_button_theme(_multiplayer_button)
	_apply_button_theme(_options_button)
	_apply_button_theme(_exit_button)

	_multiplayer_button.disabled = true
	_multiplayer_button.tooltip_text = "Multiplayer will be available in a later milestone."

	_play_button.pressed.connect(_on_play_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)

func _process(delta: float) -> void:
	_planet.rotation += 0.01 * delta

func _apply_screen_theme() -> void:
	_overlay.color = THEME_OVERLAY
	_menu_vbox.add_theme_constant_override(&"separation", 12)

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
	panel_style.content_margin_left = 20
	panel_style.content_margin_top = 16
	panel_style.content_margin_right = 20
	panel_style.content_margin_bottom = 18
	_menu_panel.add_theme_stylebox_override(&"panel", panel_style)

	_title_label.add_theme_color_override(&"font_color", THEME_ACCENT)
	_subtitle_label.add_theme_color_override(&"font_color", THEME_TEXT_MUTED)

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

func _on_play_pressed() -> void:
	_play_menu_click()
	get_tree().change_scene_to_file(FACTION_SELECTION_SCENE_PATH)

func _on_options_pressed() -> void:
	_play_menu_click()
	get_tree().change_scene_to_file(OPTIONS_SCENE_PATH)

func _on_exit_pressed() -> void:
	_play_menu_click()
	AudioManager.stop_menu_ambient()
	get_tree().quit()

func _play_menu_click() -> void:
	AudioManager.play_menu_click()
