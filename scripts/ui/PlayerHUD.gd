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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()

func setup(ship: Ship, player_faction: FactionData, enemy_faction: FactionData, ability: AbilityController) -> void:
	_ship = ship
	_player_faction = player_faction
	_enemy_faction = enemy_faction
	_ability = ability

func _build_ui() -> void:
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
