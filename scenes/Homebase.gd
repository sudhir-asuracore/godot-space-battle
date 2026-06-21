extends StaticBody2D
class_name Homebase

@export var faction_data: FactionData
@export var max_hull: float = 2000.0

var current_hull: float
var is_shield_active: bool = true

@onready var _shield_sprite: Sprite2D = $ShieldSprite # Visual indicator

func _ready() -> void:
	current_hull = max_hull
	GameState.register_homebase(faction_data)
	EventBus.homebase_shield_toggled.connect(_on_shield_toggled)
	EventBus.homebase_shield_warning.connect(_on_shield_warning)
	is_shield_active = GameState.is_homebase_shield_active(faction_data)
	if faction_data:
		$Sprite2D.modulate = faction_data.primary_color
	_update_shield_visual()

func _on_shield_toggled(faction: FactionData, active: bool) -> void:
	# GameState emits this for the homebase owner whose shield state changed.
	if faction == faction_data:
		is_shield_active = active
		_update_shield_visual()
		if active:
			print("Homebase ", faction_data.name, " shield is back ONLINE")
		else:
			print("Homebase ", faction_data.name, " shield is DOWN")

func _on_shield_warning(faction: FactionData, will_be_active: bool) -> void:
	if faction == faction_data:
		if will_be_active:
			print("WARNING: Homebase ", faction_data.name, " shield reactivating soon")
		else:
			print("WARNING: Homebase ", faction_data.name, " shield dropping soon")

func _update_shield_visual() -> void:
	if _shield_sprite:
		_shield_sprite.visible = is_shield_active

func take_damage(hull_dmg: float, _shield_dmg: float, _attacker: Node2D = null) -> void:
	if is_shield_active:
		# Shield interlock absorbs 100% of hull damage (PRD section 11.6).
		return
		
	current_hull -= hull_dmg
	print("Homebase ", faction_data.name, " health: ", current_hull)
	if current_hull <= 0:
		_die()

func _die() -> void:
	print("Homebase ", faction_data.name, " DESTROYED!")
	EventBus.homebase_destroyed.emit(faction_data)
	EventBus.match_ended.emit(_other_faction())
	queue_free()

func _other_faction() -> FactionData:
	# The winner is whichever faction did NOT just lose its homebase.
	var majority := GameState.get_majority_faction()
	if majority and majority != faction_data:
		return majority
	return null

func is_enemy() -> bool:
	return true # For targeting
	
