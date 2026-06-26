extends Control
class_name DebugPanel

# In-game developer overlay. Adds a "Debug" button that opens a popup menu with
# cheats / diagnostics:
#   • Infinite Hull Health — makes the player ship's hull invulnerable.
#   • Performance — toggles a live diagnostics panel (RAM, GPU/VRAM, FPS) anchored
#     to the bottom-left corner of the screen.

const MENU_INFINITE_HULL := 0
const MENU_PERFORMANCE := 1

var _ship: Ship = null

var _debug_button: Button
var _menu: PopupMenu
var _perf_panel: Panel
var _perf_label: Label
var _perf_visible: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()

func setup(ship: Ship) -> void:
	_ship = ship
	_sync_menu_state()

func _build_ui() -> void:
	# Debug button sits just below the controls/help panel in the top-left.
	_debug_button = Button.new()
	_debug_button.text = "Debug"
	_debug_button.focus_mode = Control.FOCUS_NONE
	_debug_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_debug_button.position = Vector2(15, 135)
	_debug_button.custom_minimum_size = Vector2(90, 30)
	_debug_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_debug_button.pressed.connect(_on_debug_button_pressed)
	add_child(_debug_button)

	_menu = PopupMenu.new()
	_menu.add_check_item("Infinite Hull Health", MENU_INFINITE_HULL)
	_menu.add_check_item("Performance", MENU_PERFORMANCE)
	_menu.id_pressed.connect(_on_menu_id_pressed)
	add_child(_menu)

	# Performance overlay: bottom-left corner, hidden until toggled on.
	_perf_panel = Panel.new()
	_perf_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_perf_panel.position = Vector2(15, -150)
	_perf_panel.custom_minimum_size = Vector2(230, 135)
	_perf_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_perf_panel.visible = false
	add_child(_perf_panel)

	_perf_label = Label.new()
	_perf_label.position = Vector2(10, 8)
	_perf_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_perf_panel.add_child(_perf_label)

func _on_debug_button_pressed() -> void:
	_sync_menu_state()
	_menu.position = Vector2i(_debug_button.global_position) + Vector2i(0, int(_debug_button.size.y))
	_menu.reset_size()
	_menu.popup()

func _sync_menu_state() -> void:
	var hull_idx := _menu.get_item_index(MENU_INFINITE_HULL)
	if hull_idx != -1:
		var enabled: bool = _ship != null and is_instance_valid(_ship) and _ship.infinite_hull
		_menu.set_item_checked(hull_idx, enabled)
	var perf_idx := _menu.get_item_index(MENU_PERFORMANCE)
	if perf_idx != -1:
		_menu.set_item_checked(perf_idx, _perf_visible)

func _on_menu_id_pressed(id: int) -> void:
	match id:
		MENU_INFINITE_HULL:
			_toggle_infinite_hull()
		MENU_PERFORMANCE:
			_toggle_performance()

func _toggle_infinite_hull() -> void:
	if not _ship or not is_instance_valid(_ship):
		return
	_ship.infinite_hull = not _ship.infinite_hull
	# Top the hull back up the moment invulnerability is switched on.
	if _ship.infinite_hull:
		_ship.current_hull = _ship.max_hull

func _toggle_performance() -> void:
	_perf_visible = not _perf_visible
	_perf_panel.visible = _perf_visible

func _process(_delta: float) -> void:
	if not _perf_visible:
		return
	_perf_label.text = _build_perf_text()

func _build_perf_text() -> String:
	var fps: int = int(Engine.get_frames_per_second())
	var frame_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var ram_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	var vram_mb: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0)
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	return "PERFORMANCE\nFPS: %d\nFrame: %.1f ms\nRAM: %.1f MB\nGPU VRAM: %.1f MB\nDraw calls: %d" % [fps, frame_ms, ram_mb, vram_mb, draw_calls]
