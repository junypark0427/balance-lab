extends AnimatableBody3D
## Only consumes normalized axes; knows nothing about keyboards or sensors.

@export var input_source: TiltInput
@export_range(0.0, 30.0, 0.1) var max_tilt_degrees: float = 15.0
@export_range(0.1, 20.0, 0.1) var tilt_response: float = 5.0
@export var debug_logging: bool = true
@export_range(0.05, 2.0, 0.05) var debug_interval: float = 0.2
var last_received_axes: Vector2 = Vector2.ZERO
var physics_tick_count: int = 0
var peak_tilt_degrees: Vector2 = Vector2.ZERO
var _tilt: Vector2 = Vector2.ZERO
var _debug_elapsed: float = 0.0


func _ready() -> void:
	_tilt = Vector2(rotation.x, rotation.z)
	if not is_instance_valid(input_source):
		push_error("Platform: input_source is not assigned. Assign Main/TiltInput in the Inspector.")
	elif debug_logging:
		print("[Platform] input_source=", input_source.get_path(), " limit=+/-", max_tilt_degrees, " deg")


func _physics_process(delta: float) -> void:
	var axes: Vector2 = Vector2.ZERO
	if is_instance_valid(input_source):
		axes = input_source.get_tilt_axes().clamp(Vector2(-1.0, -1.0), Vector2.ONE)
	last_received_axes = axes
	physics_tick_count += 1
	var limit: float = deg_to_rad(maxf(max_tilt_degrees, 0.0))
	var weight: float = 1.0 - exp(-tilt_response * delta)
	# Positive X rotation lowers the near edge; negative Z lowers the right edge.
	# Keep our own angles because AnimatableBody3D synchronizes transforms to physics.
	_tilt = Vector2(
		clampf(lerpf(_tilt.x, axes.y * limit, weight), -limit, limit),
		clampf(lerpf(_tilt.y, -axes.x * limit, weight), -limit, limit)
	)
	if axes == Vector2.ZERO and _tilt.length_squared() < 0.00000001:
		_tilt = Vector2.ZERO
	rotation = Vector3(_tilt.x, 0.0, _tilt.y)
	peak_tilt_degrees = peak_tilt_degrees.max(Vector2(absf(rotation_degrees.x), absf(rotation_degrees.z)))
	if debug_logging:
		_debug_elapsed += delta
		if _debug_elapsed >= debug_interval:
			_debug_elapsed = fmod(_debug_elapsed, debug_interval)
			print("[Platform] Player 1=%.2f Player 2=%.2f X=%.2f deg Z=%.2f deg" % [
				axes.x, axes.y, rotation_degrees.x, rotation_degrees.z
			])
