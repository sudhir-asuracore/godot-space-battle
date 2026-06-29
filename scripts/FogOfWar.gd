extends Node2D
class_name FogOfWar

# In-world fog of war (PRD section 9 future work: minimap / radar). The whole
# player faction shares vision: captured planets, the homebase and every allied
# ship reveal a circular radar area (ranges defined in GameState). Everything
# outside the union of those circles is darkened.
#
# Implementation: each frame we read the viewport's canvas transform to find the
# world rectangle currently on screen, walk it as a coarse grid, and draw a dark
# cell wherever the cell is NOT inside any of the faction's vision circles. Cells
# inside vision are simply left undrawn, so the live world shows through. Drawing
# sits above the world (high z_index) but below the HUD (a separate CanvasLayer).

# World units between fog cells. Smaller = crisper fog edge but more draw calls.
const CELL_WORLD_SIZE: float = 220.0
# Opacity of fogged cells.
const FOG_COLOR: Color = Color(0.02, 0.03, 0.06, 0.82)
# Soft edge: cells within this distance (world units) of a vision edge fade out
# so the reveal doesn't look hard-clipped.
const EDGE_SOFTEN: float = 320.0

var _player_faction: FactionData = null
var _game_state: Node = null
var _enabled: bool = true

func _ready() -> void:
	z_index = 1000
	z_as_relative = false
	_game_state = get_node_or_null(^"/root/GameState")

func setup(player_faction: FactionData) -> void:
	_player_faction = player_faction
	queue_redraw()

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	visible = enabled
	queue_redraw()

func _process(_delta: float) -> void:
	if _enabled and _player_faction:
		queue_redraw()

func _draw() -> void:
	if not _enabled or not _player_faction or not _game_state:
		return
	if not _game_state.has_method("get_vision_sources"):
		return
	var sources: Array = _game_state.get_vision_sources(_player_faction)

	var viewport := get_viewport()
	if not viewport:
		return
	# World rectangle currently visible on screen, derived from the canvas
	# transform (camera-agnostic). screen = ct * world  ->  world = ct^-1 * screen.
	var ct := viewport.get_canvas_transform()
	var inv := ct.affine_inverse()
	var view_size: Vector2 = viewport.get_visible_rect().size
	var top_left: Vector2 = inv * Vector2.ZERO
	var bottom_right: Vector2 = inv * view_size
	var world_min := Vector2(minf(top_left.x, bottom_right.x), minf(top_left.y, bottom_right.y))
	var world_max := Vector2(maxf(top_left.x, bottom_right.x), maxf(top_left.y, bottom_right.y))

	# Snap the grid origin to the cell size so cells stay stable as the camera
	# pans (prevents the fog from shimmering).
	var start_x: float = floorf(world_min.x / CELL_WORLD_SIZE) * CELL_WORLD_SIZE
	var start_y: float = floorf(world_min.y / CELL_WORLD_SIZE) * CELL_WORLD_SIZE

	var cell := Vector2(CELL_WORLD_SIZE, CELL_WORLD_SIZE)
	var x: float = start_x
	while x <= world_max.x:
		var y: float = start_y
		while y <= world_max.y:
			var center := Vector2(x + CELL_WORLD_SIZE * 0.5, y + CELL_WORLD_SIZE * 0.5)
			var alpha: float = _fog_alpha_at(center, sources)
			if alpha > 0.0:
				var c := FOG_COLOR
				c.a *= alpha
				draw_rect(Rect2(Vector2(x, y), cell), c)
			y += CELL_WORLD_SIZE
		x += CELL_WORLD_SIZE

# Returns 0 (fully revealed) .. 1 (fully fogged) for a world point: 0 inside any
# vision circle, fading in over EDGE_SOFTEN just past each circle's edge.
func _fog_alpha_at(world_pos: Vector2, sources: Array) -> float:
	var nearest_outside: float = INF
	for source in sources:
		var d: float = world_pos.distance_to(source["position"])
		var r: float = float(source["range"])
		if d <= r:
			return 0.0
		nearest_outside = minf(nearest_outside, d - r)
	if nearest_outside <= EDGE_SOFTEN:
		return clampf(nearest_outside / EDGE_SOFTEN, 0.0, 1.0)
	return 1.0
