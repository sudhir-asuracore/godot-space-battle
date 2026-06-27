extends Control
class_name SystemPlanetBar

# Top-of-screen planet array (PRD section 15.1 HUD).
#
# Renders every planet in the solar system as a node along a horizontal track,
# with a faction marker at each end ("ALLIED CONTROL" on the left, "ENEMY
# CONTROL" on the right). Each planet node is coloured by its current owner so
# the player can read system control at a glance.
#
# Contested planets (someone is actively capturing) pulse with the attacker's
# colour, and homebase planets get a bright ring. This makes the bar double as
# an alert when a faction is attacking / taking over a player planet or
# homebase.
#
# Faction-end markers currently use a simple drawn diamond as a DUMMY icon;
# these are intended to be swapped for real faction artwork later.

const NEUTRAL_COLOR := Color(0.55, 0.55, 0.6, 1.0)
const TRACK_COLOR := Color(1.0, 1.0, 1.0, 0.18)

const BAR_HEIGHT := 92.0
const NODE_RADIUS := 13.0
# Horizontal room reserved on each side for the faction marker + label.
const END_MARGIN := 190.0
const ICON_RADIUS := 26.0
const LABEL_FONT_SIZE := 15

var _player_faction: FactionData = null
var _enemy_faction: FactionData = null
var _player_home_planet: Planet = null
var _enemy_home_planet: Planet = null

# Planets in left-to-right display order (oriented so the player end is left).
var _ordered_planets: Array[Planet] = []

var _pulse_t: float = 0.0
var _font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size = Vector2(0, BAR_HEIGHT)
	# Anchored top-wide, so the drawing uses BAR_HEIGHT directly rather than the
	# control's own size.y (which the anchors keep at the offset value).
	_font = ThemeDB.fallback_font
	var event_bus := get_node_or_null(^"/root/EventBus")
	if event_bus and event_bus.has_signal(&"planet_captured"):
		event_bus.connect(&"planet_captured", _on_planet_captured)

func setup(player_faction: FactionData, enemy_faction: FactionData) -> void:
	_player_faction = player_faction
	_enemy_faction = enemy_faction
	_refresh_planets()
	queue_redraw()

# Supplies the two homebase planets so the bar can orient itself (player end on
# the left) and highlight the homebase nodes.
func configure_endpoints(player_home_planet: Planet, enemy_home_planet: Planet) -> void:
	_player_home_planet = player_home_planet
	_enemy_home_planet = enemy_home_planet
	_refresh_planets()
	queue_redraw()

func _on_planet_captured(_planet: Planet, _new_owner: FactionData) -> void:
	# Membership of the system does not change on capture, but refresh anyway in
	# case planets were spawned after the initial setup call.
	_refresh_planets()
	queue_redraw()

# Collects the live planets from the scene, sorts them into orbit order, and
# orients the list so the player's homebase end sits on the left.
func _refresh_planets() -> void:
	_ordered_planets.clear()
	var planets := get_tree().get_nodes_in_group(&"planets")
	for node in planets:
		var planet := node as Planet
		if planet and is_instance_valid(planet):
			_ordered_planets.append(planet)

	_ordered_planets.sort_custom(_compare_planet_order)

	# Orient: if the enemy homebase ends up before the player homebase, flip the
	# whole array so the player ("allied") side is always drawn on the left.
	if _player_home_planet and _enemy_home_planet:
		var player_idx := _ordered_planets.find(_player_home_planet)
		var enemy_idx := _ordered_planets.find(_enemy_home_planet)
		if player_idx != -1 and enemy_idx != -1 and enemy_idx < player_idx:
			_ordered_planets.reverse()

func _compare_planet_order(a: Planet, b: Planet) -> bool:
	return _planet_order_key(a) < _planet_order_key(b)

# Planets are named "Planet_<n>" in spawn (orbit) order; use that index as the
# stable sort key, falling back to the instance id for anything unnamed.
func _planet_order_key(planet: Planet) -> int:
	var parts := String(planet.name).split("_")
	if parts.size() >= 2 and parts[parts.size() - 1].is_valid_int():
		return int(parts[parts.size() - 1])
	return planet.get_instance_id()

func _process(delta: float) -> void:
	_pulse_t += delta
	# The contested-planet pulse is animated, so redraw continuously while the
	# bar is visible.
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var center_y: float = BAR_HEIGHT * 0.5
	var track_left: float = END_MARGIN
	var track_right: float = max(END_MARGIN + 1.0, w - END_MARGIN)

	# Connecting track behind the planet nodes.
	draw_line(Vector2(track_left, center_y), Vector2(track_right, center_y), TRACK_COLOR, 2.0, true)

	var count: int = _ordered_planets.size()
	for i in range(count):
		var planet := _ordered_planets[i]
		if not is_instance_valid(planet):
			continue
		var x: float = track_left
		if count > 1:
			x = lerpf(track_left, track_right, float(i) / float(count - 1))
		else:
			x = (track_left + track_right) * 0.5
		_draw_planet_node(Vector2(x, center_y), planet)

	# Faction markers at both ends (DUMMY icons for now).
	_draw_faction_marker(Vector2(END_MARGIN * 0.5, center_y), _player_faction, "ALLIED CONTROL", _player_faction_color())
	_draw_faction_marker(Vector2(w - END_MARGIN * 0.5, center_y), _enemy_faction, "ENEMY CONTROL", _enemy_faction_color())

func _draw_planet_node(pos: Vector2, planet: Planet) -> void:
	var owner_faction: FactionData = planet.owning_faction
	var fill: Color = owner_faction.primary_color if owner_faction else NEUTRAL_COLOR

	# Contested alert: a different faction is actively capturing this planet.
	var attacker: FactionData = planet.capturing_faction
	var is_contested: bool = attacker != null and attacker != owner_faction and planet.capture_progress > 0.0
	if is_contested:
		var pulse: float = 0.5 + 0.5 * sin(_pulse_t * 6.0)
		var alert: Color = attacker.primary_color
		alert.a = 0.35 + 0.45 * pulse
		draw_circle(pos, NODE_RADIUS + 8.0 + 3.0 * pulse, alert)

	# Homebase planets get a bright outer ring in the owner/faction colour.
	var is_home: bool = planet == _player_home_planet or planet == _enemy_home_planet
	if is_home:
		var ring: Color = fill
		ring.a = 1.0
		draw_arc(pos, NODE_RADIUS + 4.0, 0.0, TAU, 48, ring, 2.5, true)

	# Dark border for contrast, then the coloured body.
	draw_circle(pos, NODE_RADIUS + 1.5, Color(0.05, 0.06, 0.08, 1.0))
	draw_circle(pos, NODE_RADIUS, fill)
	# Subtle highlight to give the node a planet-like sheen.
	draw_circle(pos - Vector2(NODE_RADIUS * 0.3, NODE_RADIUS * 0.3), NODE_RADIUS * 0.35, Color(1, 1, 1, 0.18))

# Draws a placeholder faction icon (diamond) plus its control label. Replace the
# drawn diamond with real faction artwork when available.
func _draw_faction_marker(center: Vector2, faction: FactionData, fallback_label: String, color: Color) -> void:
	var r: float = ICON_RADIUS
	var diamond := PackedVector2Array([
		center + Vector2(0, -r),
		center + Vector2(r, 0),
		center + Vector2(0, r),
		center + Vector2(-r, 0),
	])
	draw_colored_polygon(diamond, color)
	# Outline.
	var outline := diamond
	outline.append(diamond[0])
	draw_polyline(outline, Color(0, 0, 0, 0.6), 2.0, true)
	# Inner accent dot.
	draw_circle(center, r * 0.32, Color(1, 1, 1, 0.85))

	if _font:
		var label: String = fallback_label
		var text_size: Vector2 = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, LABEL_FONT_SIZE)
		var text_pos := Vector2(center.x - text_size.x * 0.5, center.y + r + LABEL_FONT_SIZE + 2.0)
		draw_string(_font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, color)

func _player_faction_color() -> Color:
	return _player_faction.primary_color if _player_faction else Color(0.2, 0.6, 1.0)

func _enemy_faction_color() -> Color:
	return _enemy_faction.primary_color if _enemy_faction else Color(1.0, 0.25, 0.2)
