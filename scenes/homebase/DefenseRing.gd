extends Node2D
class_name DefenseRing

var _faction_data: FactionData
var _homebase: Homebase

func configure(faction_data: FactionData, homebase: Homebase) -> void:
	_faction_data = faction_data
	_homebase = homebase
	for child in get_children():
		if child.has_method("configure"):
			child.call("configure", _faction_data, _homebase)