extends Camera2D
class_name GameCamera

@export var min_zoom: float = 0.3
@export var max_zoom: float = 4.0
@export var zoom_speed: float = 0.15
@export var move_speed: float = 1800.0 # Keyboard movement speed

var target_node: Node2D = null
var follow_target: bool = true

var _drag_start: Vector2 = Vector2.ZERO
var _dragging: bool = false

func _ready() -> void:
	# Start at default 100% zoom
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
			adjust_zoom(1.15)
		elif event.is_action_pressed("zoom_out"):
			adjust_zoom(1.0 / 1.15)
			
	elif event is InputEventMouseMotion and _dragging:
		# Decouple camera follow if user manual drags
		follow_target = false
		var current_pos: Vector2 = get_viewport().get_mouse_position()
		var delta_pos: Vector2 = current_pos - _drag_start
		position -= delta_pos / zoom.x
		_drag_start = current_pos

func adjust_zoom(factor: float) -> void:
	var new_zoom: float = zoom.x * factor
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)
