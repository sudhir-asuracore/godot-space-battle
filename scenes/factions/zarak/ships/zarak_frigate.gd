extends Ship

const SHIP_NAME := "Zarak Frigate"
# Resource this ship represents. Used as a safety net so the scene stays linked
# to its own ship/faction data even when instantiated directly (e.g. tests or
# standalone scenes) without a spawner assigning ship_data.
const DEFAULT_SHIP_DATA_PATH := "res://resources/factions/zarak/ships/zarak_frigate.tres"

func _before_ship_ready() -> void:
	if ship_data == null:
		ship_data = load(DEFAULT_SHIP_DATA_PATH) as ShipData

func _after_ship_ready() -> void:
	if ship_data and ship_data.name.is_empty():
		ship_data.name = SHIP_NAME
