extends StaticBody2D
class_name Planet

@export var planet_data: PlanetData
@export var owning_faction: FactionData = null

var capture_progress: float = 0.0 # 0 to capture_required
var capturing_faction: FactionData = null

@onready var _capture_zone: Area2D = $CaptureZone
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _capture_ring_visual: Line2D = $CaptureRingVisual

func _ready() -> void:
	add_to_group("planets")
	var game_state := get_node_or_null(^"/root/GameState")
	if game_state and "planet_ownership" in game_state:
		game_state.planet_ownership[self] = owning_faction
	if planet_data:
		# Set up collision and capture zone based on data
		var circle = CircleShape2D.new()
		circle.radius = planet_data.capture_radius
		_capture_zone.get_node("CollisionShape2D").shape = circle
		
		# Setup ring visual
		_draw_ring()

func _draw_ring() -> void:
	_capture_ring_visual.clear_points()
	var segments = 64
	for i in range(segments + 1):
		var angle = (float(i) / segments) * TAU
		_capture_ring_visual.add_point(Vector2(cos(angle), sin(angle)) * planet_data.capture_radius)
	
	_update_ring_color()

func _update_ring_color() -> void:
	if owning_faction:
		_capture_ring_visual.default_color = owning_faction.primary_color
	else:
		_capture_ring_visual.default_color = Color(1, 1, 1, 0.3)

func _physics_process(delta: float) -> void:
	_evaluate_capture(delta)

func _evaluate_capture(delta: float) -> void:
	var ships = _capture_zone.get_overlapping_bodies()
	
	var faction_pressures = {} # FactionData -> count
	
	for body in ships:
		if body is Ship and not body.is_dead:
			var faction = body.faction_data
			if faction:
				faction_pressures[faction] = faction_pressures.get(faction, 0) + 1
	
	if faction_pressures.size() == 0:
		# Decay progress if no one is here? PRD doesn't say, but usually yes.
		return
		
	if faction_pressures.size() == 1:
		var faction = faction_pressures.keys()[0]
		_apply_pressure(faction, faction_pressures[faction], delta)
	else:
		# Contested
		# Find faction with most pressure
		var max_p = 0
		var best_f = null
		var second_p = 0
		
		for f in faction_pressures:
			if faction_pressures[f] > max_p:
				second_p = max_p
				max_p = faction_pressures[f]
				best_f = f
			elif faction_pressures[f] > second_p:
				second_p = faction_pressures[f]
				
		if max_p > second_p:
			_apply_pressure(best_f, max_p - second_p, delta)

func _apply_pressure(faction: FactionData, pressure: float, delta: float) -> void:
	if owning_faction == faction:
		capture_progress = planet_data.capture_required
		return
		
	if capturing_faction != faction:
		if capture_progress > 0:
			# Neutralize first
			capture_progress -= pressure * delta * 10.0
			if capture_progress <= 0:
				capture_progress = 0
				capturing_faction = faction
		else:
			capturing_faction = faction
			
	if capturing_faction == faction:
		capture_progress += pressure * delta * 10.0
		if capture_progress >= planet_data.capture_required:
			capture_progress = planet_data.capture_required
			_capture_planet(faction)

func _capture_planet(faction: FactionData) -> void:
	owning_faction = faction
	_update_ring_color()
	var event_bus := get_node_or_null(^"/root/EventBus")
	if event_bus:
		event_bus.call("emit_signal", &"planet_captured", self, faction)
	print("Planet captured by ", faction.name)
