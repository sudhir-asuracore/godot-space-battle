extends Camera2D

@export var min_zoom: float = 0.05
@export var max_zoom: float = 2.5
@export var zoom_speed: float = 0.1
@export var move_speed: float = 600.0 # Pixels per second at zoom 1.0

var drag_start: Vector2 = Vector2.ZERO
var dragging: bool = false

func _ready():
	# Start zoomed out slightly so the user sees the sun and first planet immediately
	zoom = Vector2(0.75, 0.75)

func _process(delta):
	# Keyboard movement (WASD or Arrow keys)
	var move_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_dir.x += 1
		
	if move_dir != Vector2.ZERO:
		position += move_dir.normalized() * (move_speed / zoom.x) * delta

func _unhandled_input(event):
	# Pan with mouse click dragging (Left, Right, or Middle click)
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if event.pressed:
				drag_start = get_viewport().get_mouse_position()
				dragging = true
			else:
				dragging = false
				
		# Zoom with mouse scroll wheel
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			adjust_zoom(1.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			adjust_zoom(1.0 / 1.15)
			
	elif event is InputEventMouseMotion and dragging:
		var current_pos = get_viewport().get_mouse_position()
		var delta_pos = current_pos - drag_start
		# Scale movement based on zoom level so it feels consistent
		position -= delta_pos / zoom.x
		drag_start = current_pos

func adjust_zoom(factor: float):
	var new_zoom = zoom.x * factor
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)
