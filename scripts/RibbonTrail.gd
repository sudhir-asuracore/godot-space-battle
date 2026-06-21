extends Line2D
class_name RibbonTrail

var _max_points: int = 50
var _lifetime: float = 1.0
var _point_times: Array[float] = []
var _target: Node2D = null
var _is_emitting: bool = true

func _ready() -> void:
	z_as_relative = false
	z_index = -1
	
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	antialiased = false # Disable AA as it can conflict with shaders
	
	texture_mode = Line2D.LINE_TEXTURE_STRETCH
	
	# Default width curve for tapering (engine is at the end of points array)
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0.2)) # Tail end
	curve.add_point(Vector2(1, 1.0)) # Engine end
	width_curve = curve
	
	# Create a white texture if none exists to ensure UV generation
	if not texture:
		var image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		texture = ImageTexture.create_from_image(image)

func setup(data: ShipData) -> void:
	if not data: return
	
	width = data.trail_thickness
	_max_points = data.trail_length
	_lifetime = data.trail_lifetime
	
	# Make material unique to this instance so parameters don't bleed between ships
	if material:
		material = material.duplicate()
		material.set_shader_parameter("base_color", data.trail_color)
		material.set_shader_parameter("brightness", data.trail_brightness)

func set_target(target: Node2D) -> void:
	_target = target

func set_emitting(emitting: bool) -> void:
	_is_emitting = emitting

func stop_emitting() -> void:
	_is_emitting = false

func _process(delta: float) -> void:
	# Update existing points
	var i = 0
	while i < _point_times.size():
		_point_times[i] += delta
		if _point_times[i] > _lifetime:
			_point_times.remove_at(i)
			remove_point(i)
		else:
			i += 1
	
	# Add new point
	if _is_emitting and is_instance_valid(_target):
		var pos = _target.global_position
		
		if points.size() == 0 or points[-1].distance_to(pos) > 1.0:
			add_point(pos)
			_point_times.append(0.0)
		
		if points.size() > _max_points:
			remove_point(0)
			_point_times.remove_at(0)

	# If not emitting and no points left, clean up only if we don't have a target anymore
	if not _is_emitting and points.size() == 0 and not is_instance_valid(_target):
		queue_free()

func reset() -> void:
	clear_points()
	_point_times.clear()
