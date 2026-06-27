extends Ship

const SHIP_NAME := "Frigate"

func _after_ship_ready() -> void:
	if ship_data and ship_data.name.is_empty():
		ship_data.name = SHIP_NAME
