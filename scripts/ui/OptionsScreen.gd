extends Control
class_name OptionsScreen

const TITLE_SCENE_PATH := "res://ui/TitleScreen.tscn"

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

const ACTION_DEFAULT_KEYS := {
	&"ability_1": KEY_1,
	&"reverse_thrust": KEY_R,
	&"strafe_left": KEY_Q,
	&"strafe_right": KEY_E
}

const ACTION_LABELS := {
	&"ability_1": "Ability 1",
	&"reverse_thrust": "Reverse Thrust",
	&"strafe_left": "Strafe Left",
	&"strafe_right": "Strafe Right"
}

const KEY_OPTIONS := [
	{"label": "1", "key": KEY_1},
	{"label": "2", "key": KEY_2},
	{"label": "3", "key": KEY_3},
	{"label": "Q", "key": KEY_Q},
	{"label": "E", "key": KEY_E},
	{"label": "R", "key": KEY_R},
	{"label": "Space", "key": KEY_SPACE},
	{"label": "Left Shift", "key": KEY_SHIFT}
]

@onready var _master_slider: HSlider = $MainPanel/VBox/MasterVolumeSlider as HSlider
@onready var _sfx_slider: HSlider = $MainPanel/VBox/SfxVolumeSlider as HSlider
@onready var _action_selector: OptionButton = $MainPanel/VBox/ActionRow/ActionSelector as OptionButton
@onready var _key_selector: OptionButton = $MainPanel/VBox/KeyRow/KeySelector as OptionButton
@onready var _status_label: Label = $MainPanel/VBox/StatusLabel as Label
@onready var _apply_button: Button = $MainPanel/VBox/ApplyButton as Button
@onready var _back_button: Button = $MainPanel/VBox/BackButton as Button
@onready var _main_panel: PanelContainer = $MainPanel as PanelContainer
@onready var _main_vbox: VBoxContainer = $MainPanel/VBox as VBoxContainer
@onready var _overlay: ColorRect = $Overlay as ColorRect
@onready var _header_label: Label = $MainPanel/VBox/Header as Label
@onready var _audio_header: Label = $MainPanel/VBox/AudioHeader as Label
@onready var _bindings_header: Label = $MainPanel/VBox/BindingsHeader as Label
@onready var _master_label: Label = $MainPanel/VBox/MasterLabel as Label
@onready var _sfx_label: Label = $MainPanel/VBox/SfxLabel as Label
@onready var _action_label: Label = $MainPanel/VBox/ActionRow/ActionLabel as Label
@onready var _key_label: Label = $MainPanel/VBox/KeyRow/KeyLabel as Label

var _selected_action: StringName = &"ability_1"

func _ready() -> void:
	AudioManager.start_menu_ambient()
	_register_default_actions()
	_configure_sliders()
	_populate_action_selector()
	_populate_key_selector()
	_sync_key_selector_with_action(_selected_action)
	_apply_theme()

	_master_slider.value_changed.connect(_on_master_volume_changed)
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_action_selector.item_selected.connect(_on_action_selected)
	_key_selector.item_selected.connect(_on_key_selected)
	_apply_button.pressed.connect(_on_apply_pressed)
	_back_button.pressed.connect(_on_back_pressed)

func _apply_theme() -> void:
	_apply_screen_theme()
	_apply_button_theme(_apply_button, true)
	_apply_button_theme(_back_button)
	_apply_option_theme(_action_selector)
	_apply_option_theme(_key_selector)
	_apply_slider_theme(_master_slider)
	_apply_slider_theme(_sfx_slider)

func _apply_screen_theme() -> void:
	_overlay.color = THEME_OVERLAY
	_main_vbox.add_theme_constant_override(&"separation", 10)
	_apply_panel_theme(_main_panel)

	_header_label.add_theme_color_override(&"font_color", THEME_ACCENT)
	_audio_header.add_theme_color_override(&"font_color", THEME_BORDER)
	_bindings_header.add_theme_color_override(&"font_color", THEME_BORDER)

	for label: Label in [_master_label, _sfx_label, _action_label, _key_label]:
		label.add_theme_color_override(&"font_color", THEME_TEXT)

	_status_label.add_theme_color_override(&"font_color", THEME_TEXT_MUTED)

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
	button.add_theme_stylebox_override(&"focus", hover_style)
	button.add_theme_stylebox_override(&"disabled", disabled_style)

func _apply_option_theme(option_button: OptionButton) -> void:
	option_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	option_button.add_theme_color_override(&"font_color", THEME_TEXT)
	option_button.add_theme_color_override(&"font_hover_color", THEME_TEXT)
	option_button.add_theme_color_override(&"font_pressed_color", THEME_ACCENT_TEXT)

	var normal_style := _make_row_style(THEME_ROW_BG, THEME_BORDER_DIM, 2)
	var hover_style := _make_row_style(THEME_ROW_BG.lerp(THEME_BORDER, 0.1), THEME_BORDER, 3)
	var pressed_style := _make_row_style(THEME_ACCENT_BG, THEME_ACCENT, 3)

	option_button.add_theme_stylebox_override(&"normal", normal_style)
	option_button.add_theme_stylebox_override(&"hover", hover_style)
	option_button.add_theme_stylebox_override(&"pressed", pressed_style)

func _apply_slider_theme(slider: HSlider) -> void:
	slider.add_theme_color_override(&"font_color", THEME_TEXT)
	slider.add_theme_color_override(&"font_hover_color", THEME_TEXT)
	slider.add_theme_color_override(&"font_pressed_color", THEME_TEXT)

	var slider_track := _make_row_style(THEME_ROW_BG, THEME_BORDER_DIM, 1)
	slider_track.content_margin_left = 8
	slider_track.content_margin_top = 4
	slider_track.content_margin_right = 8
	slider_track.content_margin_bottom = 4

	var slider_hover_track := _make_row_style(THEME_ROW_BG.lerp(THEME_BORDER, 0.1), THEME_BORDER, 2)
	slider_hover_track.content_margin_left = 8
	slider_hover_track.content_margin_top = 4
	slider_hover_track.content_margin_right = 8
	slider_hover_track.content_margin_bottom = 4

	slider.add_theme_stylebox_override(&"slider", slider_track)
	slider.add_theme_stylebox_override(&"grabber_area", slider_track)
	slider.add_theme_stylebox_override(&"grabber_area_highlight", slider_hover_track)

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
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	return style

func _register_default_actions() -> void:
	for action_name: StringName in ACTION_DEFAULT_KEYS.keys():
		_ensure_key_action(action_name, ACTION_DEFAULT_KEYS[action_name])

func _ensure_key_action(action_name: StringName, key_code: Key) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	var key_event := InputEventKey.new()
	key_event.keycode = key_code
	InputMap.action_add_event(action_name, key_event)

func _configure_sliders() -> void:
	_master_slider.min_value = -30.0
	_master_slider.max_value = 6.0
	_master_slider.step = 0.5
	_sfx_slider.min_value = -30.0
	_sfx_slider.max_value = 6.0
	_sfx_slider.step = 0.5

	_master_slider.value = _get_bus_volume_db(&"Master")
	var sfx_bus: StringName = &"Player_SFX" if AudioServer.get_bus_index(&"Player_SFX") != -1 else &"Master"
	_sfx_slider.value = _get_bus_volume_db(sfx_bus)

func _get_bus_volume_db(bus_name: StringName) -> float:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return 0.0
	return AudioServer.get_bus_volume_db(bus_index)

func _set_bus_volume_db(bus_name: StringName, volume_db: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	AudioServer.set_bus_volume_db(bus_index, volume_db)

func _populate_action_selector() -> void:
	_action_selector.clear()
	for action_name: StringName in ACTION_DEFAULT_KEYS.keys():
		var action_label: String = str(ACTION_LABELS.get(action_name, str(action_name)))
		_action_selector.add_item(action_label)
		_action_selector.set_item_metadata(_action_selector.item_count - 1, action_name)

func _populate_key_selector() -> void:
	_key_selector.clear()
	for key_data in KEY_OPTIONS:
		_key_selector.add_item(str(key_data["label"]))
		_key_selector.set_item_metadata(_key_selector.item_count - 1, key_data["key"])

func _sync_key_selector_with_action(action_name: StringName) -> void:
	var current_key: Key = _get_current_action_key(action_name)
	for index: int in _key_selector.item_count:
		var option_key: Variant = _key_selector.get_item_metadata(index)
		if option_key == current_key:
			_key_selector.select(index)
			return

func _get_current_action_key(action_name: StringName) -> Key:
	for action_event: InputEvent in InputMap.action_get_events(action_name):
		if action_event is InputEventKey:
			return (action_event as InputEventKey).keycode
	return ACTION_DEFAULT_KEYS.get(action_name, KEY_NONE)

func _on_master_volume_changed(value: float) -> void:
	_set_bus_volume_db(&"Master", value)

func _on_sfx_volume_changed(value: float) -> void:
	if AudioServer.get_bus_index(&"Player_SFX") != -1:
		_set_bus_volume_db(&"Player_SFX", value)
	if AudioServer.get_bus_index(&"Enemy_SFX") != -1:
		_set_bus_volume_db(&"Enemy_SFX", value)

func _on_action_selected(index: int) -> void:
	_play_menu_click()
	_selected_action = _action_selector.get_item_metadata(index) as StringName
	_sync_key_selector_with_action(_selected_action)

func _on_key_selected(_index: int) -> void:
	_play_menu_click()

func _on_apply_pressed() -> void:
	_play_menu_click()
	if _key_selector.selected < 0:
		_status_label.text = "Select a key before applying."
		return

	var selected_key: Key = _key_selector.get_item_metadata(_key_selector.selected)
	for action_event: InputEvent in InputMap.action_get_events(_selected_action):
		InputMap.action_erase_event(_selected_action, action_event)

	var new_event := InputEventKey.new()
	new_event.keycode = selected_key
	InputMap.action_add_event(_selected_action, new_event)

	_status_label.text = "%s bound to %s" % [
		str(ACTION_LABELS.get(_selected_action, str(_selected_action))),
		OS.get_keycode_string(selected_key)
	]

func _on_back_pressed() -> void:
	_play_menu_click()
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)

func _play_menu_click() -> void:
	AudioManager.play_menu_click()
