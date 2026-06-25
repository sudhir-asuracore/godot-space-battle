extends Control
class_name AbilitiesBar

# In-game abilities panel (PRD section 15.1).
# Shows up to five ability slots styled as sci-fi command boxes, anchored to
# the bottom-centre of the screen. Each slot displays a vector icon, the
# ability name, its hotkey number and a cooldown overlay.

const SLOT_COUNT := 5
const SLOT_SIZE := Vector2(104.0, 104.0)
const SLOT_GAP := 16.0
const KEY_BOX_SIZE := Vector2(34.0, 24.0)
const KEY_GAP := 8.0
const BOTTOM_MARGIN := 24.0

const ACCENT := Color(0.30, 0.80, 1.0)
const ACCENT_DIM := Color(0.30, 0.80, 1.0, 0.35)

var _ship: Ship = null
var _ability: AbilityController = null
var _slots: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_slots()
	resized.connect(_relayout)
	call_deferred("_relayout")

func setup(ship: Ship, ability: AbilityController) -> void:
	_ship = ship
	_ability = ability
	_refresh_slots()

func _build_slots() -> void:
	for i in range(SLOT_COUNT):
		var slot := Control.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.size = SLOT_SIZE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slot)

		var box := Panel.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_stylebox_override("panel", _make_slot_stylebox())
		slot.add_child(box)

		var icon := AbilityIcon.new()
		icon.color = ACCENT
		icon.position = Vector2(SLOT_SIZE.x * 0.19, SLOT_SIZE.y * 0.14)
		icon.size = Vector2(SLOT_SIZE.x * 0.62, SLOT_SIZE.y * 0.44)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)

		var name_label := Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.position = Vector2(3.0, SLOT_SIZE.y * 0.64)
		name_label.size = Vector2(SLOT_SIZE.x - 6.0, SLOT_SIZE.y * 0.32)
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", ACCENT)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(name_label)

		var overlay := ColorRect.new()
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.color = Color(0.0, 0.02, 0.05, 0.6)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.visible = false
		box.add_child(overlay)

		var cd_label := Label.new()
		cd_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_label.add_theme_font_size_override("font_size", 28)
		cd_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd_label.visible = false
		box.add_child(cd_label)

		var key_box := Panel.new()
		key_box.custom_minimum_size = KEY_BOX_SIZE
		key_box.size = KEY_BOX_SIZE
		key_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_box.add_theme_stylebox_override("panel", _make_key_stylebox())
		slot.add_child(key_box)

		var key_label := Label.new()
		key_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		key_label.text = str(i + 1)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_label.add_theme_font_size_override("font_size", 13)
		key_label.add_theme_color_override("font_color", ACCENT)
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_box.add_child(key_label)

		_slots.append({
			"slot": slot,
			"box": box,
			"icon": icon,
			"name": name_label,
			"overlay": overlay,
			"cd": cd_label,
			"key_box": key_box,
		})

func _relayout() -> void:
	if _slots.is_empty():
		return
	var total_width: float = SLOT_COUNT * SLOT_SIZE.x + (SLOT_COUNT - 1) * SLOT_GAP
	var start_x: float = (size.x - total_width) * 0.5
	var slot_y: float = size.y - BOTTOM_MARGIN - KEY_BOX_SIZE.y - KEY_GAP - SLOT_SIZE.y
	for i in range(_slots.size()):
		var entry: Dictionary = _slots[i]
		var slot: Control = entry["slot"]
		slot.position = Vector2(start_x + i * (SLOT_SIZE.x + SLOT_GAP), slot_y)
		var key_box: Panel = entry["key_box"]
		key_box.position = Vector2((SLOT_SIZE.x - KEY_BOX_SIZE.x) * 0.5, SLOT_SIZE.y + KEY_GAP)

func _refresh_slots() -> void:
	for i in range(_slots.size()):
		var entry: Dictionary = _slots[i]
		var ability: AbilityData = _get_ability(i + 1)
		var name_label: Label = entry["name"]
		var icon: AbilityIcon = entry["icon"]
		if ability:
			name_label.text = ability.name.to_upper()
			icon.icon_id = _icon_id_for(ability.name)
			icon.color = ACCENT
			name_label.add_theme_color_override("font_color", ACCENT)
		else:
			name_label.text = "EMPTY"
			icon.icon_id = ""
			icon.color = ACCENT_DIM
			name_label.add_theme_color_override("font_color", ACCENT_DIM)

func _get_ability(index: int) -> AbilityData:
	if not _ship or not _ship.ship_data:
		return null
	match index:
		1: return _ship.ship_data.ability_1
		2: return _ship.ship_data.ability_2
		3: return _ship.ship_data.ability_3
		4: return _ship.ship_data.ability_4
		5: return _ship.ship_data.ability_5
	return null

func _icon_id_for(ability_name: String) -> String:
	return ability_name.to_lower().strip_edges().replace(" ", "_")

func _process(_delta: float) -> void:
	if _slots.is_empty():
		return
	for i in range(_slots.size()):
		var entry: Dictionary = _slots[i]
		var ability: AbilityData = _get_ability(i + 1)
		var overlay: ColorRect = entry["overlay"]
		var cd_label: Label = entry["cd"]
		var remaining: float = _cooldown_for(i + 1)
		if ability and remaining > 0.0:
			overlay.visible = true
			cd_label.visible = true
			cd_label.text = "%.0f" % ceil(remaining)
		else:
			overlay.visible = false
			cd_label.visible = false

func _cooldown_for(index: int) -> float:
	# Only ability 1 currently has live cooldown logic in AbilityController.
	if index == 1 and _ability:
		return _ability.get_ability_1_cooldown()
	return 0.0

func _make_slot_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.07, 0.11, 0.55)
	sb.border_color = Color(0.20, 0.70, 0.95, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_expand_margin_all(0.0)
	return sb

func _make_key_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.07, 0.11, 0.7)
	sb.border_color = Color(0.20, 0.70, 0.95, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	return sb
