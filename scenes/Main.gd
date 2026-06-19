extends Node2D
class_name GameMain

@onready var _ship: Ship = $Ship as Ship
@onready var _path_line: Line2D = $PathLine as Line2D
@onready var _camera: GameCamera = $Camera2D as GameCamera
@onready var _zoom_label: Label = $HUD/Control/ZoomPanel/Label as Label

func _ready() -> void:
	# Programmatically register required Input Map actions to follow docs/conventions.md
	_register_input_action("navigate", MOUSE_BUTTON_LEFT)
	_register_input_action("zoom_in", MOUSE_BUTTON_WHEEL_UP)
	_register_input_action("zoom_out", MOUSE_BUTTON_WHEEL_DOWN)

	# Configure the camera to follow the player ship automatically on launch
	if _camera and _ship:
		_camera.target_node = _ship
		_camera.follow_target = true
		
	# Setup the visual trajectory path line look
	if _path_line:
		_path_line.width = 3.0
		_path_line.default_color = Color(0.0, 0.8, 1.0, 0.45) # Glowing semi-transparent cyan
		_path_line.clear_points()
		_path_line.visible = false

func _unhandled_input(event: InputEvent) -> void:
	# Set destination target on Left Click using the "navigate" action
	if event.is_action_pressed("navigate"):
		var click_pos: Vector2 = get_global_mouse_position()
		if _ship:
			_ship.set_target(click_pos)
		if _camera:
			# Re-engage camera lock when navigation starts
			_camera.follow_target = true

func _process(_delta: float) -> void:
	# 1. Draw and update the visual trajectory path line
	if _path_line and _ship:
		if _ship.is_moving:
			_path_line.visible = true
			_path_line.clear_points()
			_path_line.add_point(_ship.global_position)
			_path_line.add_point(_ship.target_position)
		else:
			_path_line.visible = false
			
	# 2. Update the dynamic zoom level display in real-time
	if _zoom_label and _camera:
		var percentage: int = roundi(_camera.zoom.x * 100.0)
		_zoom_label.text = "Zoom: %d%%" % percentage

# Helper function to programmatically register MouseButton inputs into Godot's InputMap
func _register_input_action(action_name: String, button_index: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		var ev: InputEventMouseButton = InputEventMouseButton.new()
		ev.button_index = button_index
		InputMap.action_add_event(action_name, ev)
