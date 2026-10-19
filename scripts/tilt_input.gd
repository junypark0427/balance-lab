class_name TiltInput
extends Node
## Input adapter. Sensor adapters can call set_sensor_axes() with normalized axes.

signal diagnostics_changed

@export var use_sensor_input: bool = false
@export var debug_logging: bool = true
var input_event_count: int = 0
var last_key_event: String = "No key event received"
var last_press_event: String = "None"
var last_event_axes: Vector2 = Vector2.ZERO
var _sensor_axes: Vector2 = Vector2.ZERO
var _last_debug_state: String = ""


func _ready() -> void:
	# Sample and report input before the platform's physics callback.
	process_physics_priority = -10
	if debug_logging:
		print("[TiltInput READY] node=", get_path(), " script=", get_script().resource_path)


func _input(event: InputEvent) -> void:
	# Observe delivery without consuming events or changing the control path.
	if not event is InputEventKey or event.echo:
		return
	input_event_count += 1
	var matches: PackedStringArray = []
	for action: StringName in [&"tilt_left", &"tilt_right", &"tilt_forward", &"tilt_backward"]:
		if InputMap.has_action(action) and event.is_action(action):
			matches.append(action)
	last_event_axes = get_tilt_axes()
	last_key_event = "%s physical=%d(%s) keycode=%d(%s) matches=[%s]" % [
		"DOWN" if event.pressed else "UP",
		event.physical_keycode, OS.get_keycode_string(event.physical_keycode),
		event.keycode, OS.get_keycode_string(event.keycode), ",".join(matches)
	]
	if event.pressed:
		last_press_event = last_key_event
	if debug_logging:
		print("[TiltInput _input #%d] %s unicode=%d window=%d P1=%.2f P2=%.2f" % [
			input_event_count, last_key_event, event.unicode, event.window_id,
			last_event_axes.x, last_event_axes.y
		])
	diagnostics_changed.emit()


func get_pressed_keys() -> PackedStringArray:
	var keys: PackedStringArray = []
	if Input.is_physical_key_pressed(KEY_A):
		keys.append("A")
	if Input.is_physical_key_pressed(KEY_D):
		keys.append("D")
	if Input.is_physical_key_pressed(KEY_UP):
		keys.append("Up")
	if Input.is_physical_key_pressed(KEY_DOWN):
		keys.append("Down")
	return keys


func _physics_process(_delta: float) -> void:
	if not debug_logging:
		return
	var keys: PackedStringArray = get_pressed_keys()
	var axes: Vector2 = get_tilt_axes()
	var state: String = "source=%s keys=[%s] Player 1=%.2f Player 2=%.2f" % [
		"sensor" if use_sensor_input else "keyboard", ", ".join(keys), axes.x, axes.y
	]
	# Compare keys as well as axes: A+D must log even though its net axis is zero.
	if state != _last_debug_state:
		print("[TiltInput] ", state)
		_last_debug_state = state


func set_sensor_axes(axes: Vector2) -> void:
	_sensor_axes = axes.clamp(Vector2(-1.0, -1.0), Vector2.ONE)


func get_tilt_axes() -> Vector2:
	if use_sensor_input:
		return _sensor_axes
	# X: left/right, Y: forward/back. Opposite keys cancel each other.
	return Vector2(
		Input.get_axis("tilt_left", "tilt_right"),
		Input.get_axis("tilt_forward", "tilt_backward")
	)
