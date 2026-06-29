extends Camera2D
class_name GameCamera

@export var min_zoom: float = 0.3
@export var max_zoom: float = 4.0
# Fixed amount each zoom in/out moves the camera by (one discrete step).
@export var zoom_step: float = 0.2
# How quickly the current zoom eases toward the target zoom (higher = snappier).
@export var zoom_smoothing: float = 10.0
@export var move_speed: float = 1800.0 # Keyboard movement speed

var target_node: Node2D = null
var follow_target: bool = true

# Zoom level the camera is easing toward; the actual zoom lerps to this each frame.
var _target_zoom: float = 1.0

var _drag_start: Vector2 = Vector2.ZERO
var _dragging: bool = false

func _ready() -> void:
	# Start at default 100% zoom
	_target_zoom = 1.0
	zoom = Vector2(1.0, 1.0)

func _physics_process(delta: float) -> void:
	# Keep follow movement in the physics tick so it stays in sync with physics-driven ships.
	if follow_target and target_node:
		global_position = global_position.lerp(target_node.global_position, 6.0 * delta)

func _process(delta: float) -> void:
	# Keyboard movement (WASD or Arrow keys)
	var move_dir: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_dir.x += 1
		
	if move_dir != Vector2.ZERO:
		# Decouple camera follow if user manual controls movement
		follow_target = false
		position += move_dir.normalized() * (move_speed / zoom.x) * delta

	# Smoothly ease the actual zoom toward the stepped target zoom.
	if not is_equal_approx(zoom.x, _target_zoom):
		var t: float = clamp(zoom_smoothing * delta, 0.0, 1.0)
		var smoothed: float = lerp(zoom.x, _target_zoom, t)
		if is_equal_approx(smoothed, _target_zoom):
			smoothed = _target_zoom
		zoom = Vector2(smoothed, smoothed)

func _unhandled_input(event: InputEvent) -> void:
	# Relock camera on Spacebar
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		follow_target = true
		
	# Pan with mouse click dragging (RESTRICTED TO RIGHT OR MIDDLE CLICK to free up left click)
	elif event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if event.pressed:
				_drag_start = get_viewport().get_mouse_position()
				_dragging = true
			else:
				_dragging = false
				
		# Zoom using Input Map actions (e.g. Wheel Up / Wheel Down)
		elif event.is_action_pressed("zoom_in"):
			step_zoom(1)
		elif event.is_action_pressed("zoom_out"):
			step_zoom(-1)
			
	elif event is InputEventMouseMotion and _dragging:
		# Decouple camera follow if user manual drags
		follow_target = false
		var current_pos: Vector2 = get_viewport().get_mouse_position()
		var delta_pos: Vector2 = current_pos - _drag_start
		position -= delta_pos / zoom.x
		_drag_start = current_pos

# Move the target zoom by a number of discrete steps (positive = zoom in,
# negative = zoom out). The actual zoom then eases toward this target in _process.
func step_zoom(steps: int) -> void:
	_target_zoom = clamp(_target_zoom + zoom_step * float(steps), min_zoom, max_zoom)

# Current zoom expressed as a discrete step level (1 = most zoomed out), used
# for the HUD readout instead of a percentage. Anchored to min_zoom so the
# value increases by one for every zoom step.
func get_zoom_level() -> int:
	return roundi((_target_zoom - min_zoom) / zoom_step) + 1
