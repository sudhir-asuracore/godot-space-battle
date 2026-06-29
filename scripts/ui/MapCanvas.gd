extends Control
class_name MapCanvas

# Central mini solar-system rendered for the System Map (MapScreen). Reads the
# live world (planets / ships / homebases groups) plus GameState fog-of-war and
# planet-identification state, then draws everything to scale inside its rect:
#
#   * orbit rings + the sun at the system centre,
#   * planets coloured by owner, ringed for homebases, with a discovery state:
#       - identified  -> name + type label,
#       - in vision but not identified -> "Unidentified",
#       - never seen / out of vision -> a dim "?" unexplored marker,
#   * allied ship symbols (always shown) and enemy ship symbols (only while
#     inside the faction's shared vision),
#   * a fog veil over regions outside the faction's vision circles,
#   * a highlight ring around the currently selected planet.
#
# Clicking near a planet selects it (used by the deploy flow).

signal planet_selected(planet: Planet)

const FOG_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const VISION_TINT := Color(0.25, 0.55, 0.8, 0.06)
const ORBIT_COLOR := Color(1, 1, 1, 0.07)
const NEUTRAL_COLOR := Color(0.55, 0.55, 0.6, 1.0)
const UNEXPLORED_COLOR := Color(0.45, 0.45, 0.5, 0.7)
const PLANET_RADIUS := 9.0
const SHIP_SIZE := 6.0
const SELECT_PICK_RADIUS := 26.0
# Fraction of the smaller canvas dimension used as the system's drawable radius.
const VIEW_RADIUS_FRACTION := 0.44

var _player_faction: FactionData = null
var _enemy_faction: FactionData = null
var _player_home_planet: Planet = null
var _enemy_home_planet: Planet = null
var _selected_planet: Planet = null
var _font: Font

# Cached world->canvas mapping rebuilt each draw.
var _center := Vector2.ZERO
var _scale := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	set_process(true)

func setup(player_faction: FactionData, enemy_faction: FactionData) -> void:
	_player_faction = player_faction
	_enemy_faction = enemy_faction
	queue_redraw()

func configure_endpoints(player_home_planet: Planet, enemy_home_planet: Planet) -> void:
	_player_home_planet = player_home_planet
	_enemy_home_planet = enemy_home_planet
	queue_redraw()

func set_selected_planet(planet: Planet) -> void:
	_selected_planet = planet
	queue_redraw()

func get_selected_planet() -> Planet:
	if _selected_planet and is_instance_valid(_selected_planet):
		return _selected_planet
	return null

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

# --- World -> canvas mapping -------------------------------------------------

func _rebuild_mapping(planets: Array) -> void:
	_center = size * 0.5
	# System extent = furthest planet from the sun (origin), with a margin.
	var max_world: float = 1.0
	for planet in planets:
		max_world = maxf(max_world, (planet as Node2D).global_position.length())
	var view_radius: float = minf(size.x, size.y) * VIEW_RADIUS_FRACTION
	_scale = view_radius / (max_world * 1.08)

func _to_canvas(world_pos: Vector2) -> Vector2:
	return _center + world_pos * _scale

# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	var planets := _planets()
	_rebuild_mapping(planets)

	var game_state := get_node_or_null(^"/root/GameState")

	# Revealed-area tint (subtle radar glow) under everything.
	if game_state and game_state.has_method("get_vision_sources") and _player_faction:
		for source in game_state.get_vision_sources(_player_faction):
			var c: Vector2 = _to_canvas(source["position"])
			var r: float = float(source["range"]) * _scale
			draw_circle(c, r, VISION_TINT)

	# Orbit rings (one per planet radius) + the sun.
	for planet in planets:
		var orbit_r: float = (planet as Node2D).global_position.length() * _scale
		draw_arc(_center, orbit_r, 0.0, TAU, 96, ORBIT_COLOR, 1.5, true)
	draw_circle(_center, 7.0, Color(1.0, 0.85, 0.35, 1.0))
	draw_circle(_center, 12.0, Color(1.0, 0.7, 0.2, 0.25))

	# Planets.
	for planet in planets:
		_draw_planet(planet, game_state)

	# Ships (allied always; enemy only while inside our vision).
	_draw_ships(game_state)

	# Fog veil over fogged regions (drawn last so it dims everything beneath).
	_draw_fog(planets, game_state)

	# Selection highlight on top of the fog so it stays readable.
	if get_selected_planet():
		var sel: Vector2 = _to_canvas((_selected_planet as Node2D).global_position)
		draw_arc(sel, PLANET_RADIUS + 7.0, 0.0, TAU, 48, Color(1, 1, 1, 0.9), 2.0, true)

func _draw_planet(planet: Planet, game_state: Node) -> void:
	var world_pos: Vector2 = (planet as Node2D).global_position
	var pos: Vector2 = _to_canvas(world_pos)

	var visible_now: bool = _is_visible(game_state, world_pos)
	var identified: bool = _is_identified(game_state, planet)
	var is_home: bool = planet == _player_home_planet or planet == _enemy_home_planet

	# Owner colour; unexplored (never identified and not currently visible) is a
	# dim grey "?" marker only.
	var owner_faction: FactionData = planet.owning_faction
	if not visible_now and not identified:
		draw_circle(pos, PLANET_RADIUS, Color(0.12, 0.13, 0.16, 1.0))
		draw_arc(pos, PLANET_RADIUS, 0.0, TAU, 32, UNEXPLORED_COLOR, 1.5, true)
		if _font:
			draw_string(_font, pos + Vector2(-4, 4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UNEXPLORED_COLOR)
		return

	var fill: Color = owner_faction.primary_color if owner_faction else NEUTRAL_COLOR
	if is_home:
		var ring: Color = fill
		ring.a = 1.0
		draw_arc(pos, PLANET_RADIUS + 4.0, 0.0, TAU, 48, ring, 2.0, true)
	draw_circle(pos, PLANET_RADIUS + 1.5, Color(0.05, 0.06, 0.08, 1.0))
	draw_circle(pos, PLANET_RADIUS, fill)

	if _font:
		var label: String
		if is_home and planet == _player_home_planet:
			label = "HOMEBASE"
		elif identified and planet.planet_data:
			label = "%s\n%s" % [planet.planet_data.name, planet.planet_data.get_type_name()]
		else:
			label = "Unidentified"
		draw_string(_font, pos + Vector2(PLANET_RADIUS + 6.0, 0.0), label.split("\n")[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.9, 0.95))
		var parts := label.split("\n")
		if parts.size() > 1:
			draw_string(_font, pos + Vector2(PLANET_RADIUS + 6.0, 14.0), parts[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.7, 0.8))

func _draw_ships(game_state: Node) -> void:
	for node in get_tree().get_nodes_in_group(&"ships"):
		var ship := node as Ship
		if not ship or not is_instance_valid(ship) or ship.is_dead:
			continue
		var is_ally: bool = ship.faction_data == _player_faction
		var world_pos: Vector2 = ship.global_position
		# Enemy ships only render when inside the faction's shared vision.
		if not is_ally and not _is_visible(game_state, world_pos):
			continue
		var pos: Vector2 = _to_canvas(world_pos)
		var color: Color
		if is_ally:
			color = _player_faction.primary_color if _player_faction else Color(0.3, 0.7, 1.0)
		else:
			color = _enemy_faction.primary_color if _enemy_faction else Color(1.0, 0.3, 0.25)
		# Simple chevron/diamond symbol.
		var pts := PackedVector2Array([
			pos + Vector2(0, -SHIP_SIZE),
			pos + Vector2(SHIP_SIZE, SHIP_SIZE),
			pos + Vector2(0, SHIP_SIZE * 0.4),
			pos + Vector2(-SHIP_SIZE, SHIP_SIZE),
		])
		draw_colored_polygon(pts, color)

func _draw_fog(planets: Array, game_state: Node) -> void:
	if not game_state or not game_state.has_method("get_vision_sources") or not _player_faction:
		return
	var sources: Array = game_state.get_vision_sources(_player_faction)
	# Coarse grid veil across the canvas; cells inside vision stay clear.
	var step := 16.0
	var y := 0.0
	while y < size.y:
		var x := 0.0
		while x < size.x:
			var canvas_center := Vector2(x + step * 0.5, y + step * 0.5)
			if not _canvas_point_visible(canvas_center, sources):
				draw_rect(Rect2(Vector2(x, y), Vector2(step, step)), FOG_COLOR)
			x += step
		y += step

func _canvas_point_visible(canvas_pos: Vector2, sources: Array) -> bool:
	for source in sources:
		var c: Vector2 = _to_canvas(source["position"])
		var r: float = float(source["range"]) * _scale
		if canvas_pos.distance_to(c) <= r:
			return true
	return false

# --- Queries -----------------------------------------------------------------

func _planets() -> Array:
	var result: Array = []
	for node in get_tree().get_nodes_in_group(&"planets"):
		var planet := node as Planet
		if planet and is_instance_valid(planet):
			result.append(planet)
	return result

func _is_visible(game_state: Node, world_pos: Vector2) -> bool:
	if not game_state or not game_state.has_method("is_position_visible") or not _player_faction:
		return true
	return game_state.is_position_visible(_player_faction, world_pos)

func _is_identified(game_state: Node, planet: Planet) -> bool:
	if not game_state or not game_state.has_method("is_planet_identified") or not _player_faction:
		return false
	return game_state.is_planet_identified(_player_faction, planet)

# --- Interaction -------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var click: Vector2 = mb.position
	var best: Planet = null
	var best_dist: float = SELECT_PICK_RADIUS
	for planet in _planets():
		var pos: Vector2 = _to_canvas((planet as Node2D).global_position)
		var d: float = pos.distance_to(click)
		if d <= best_dist:
			best_dist = d
			best = planet
	if best:
		set_selected_planet(best)
		planet_selected.emit(best)
		accept_event()
