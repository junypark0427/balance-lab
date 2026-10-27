extends Label
## Observes the existing input path; never synthesizes input or steals focus.

@onready var source: TiltInput = $"../../TiltInput"
@onready var platform = $"../../Platform"
var _elapsed: float = 0.0
var _map_report: String = ""


func _ready() -> void:
	# The diagnostics itself must not intercept clicks or keyboard navigation.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	process_mode = Node.PROCESS_MODE_ALWAYS
	for mapping in [["tilt_left", KEY_A, "A"], ["tilt_right", KEY_D, "D"], ["tilt_forward", KEY_UP, "Up"], ["tilt_backward", KEY_DOWN, "Down"]]:
		var mapped: bool = false
		if InputMap.has_action(mapping[0]):
			for event in InputMap.action_get_events(mapping[0]):
				if event is InputEventKey and event.physical_keycode == mapping[1]:
					mapped = true
		_map_report += "%s:%s " % [mapping[2], "OK" if mapped else "MISSING"]
		if not mapped:
			push_warning("Input Map missing expected physical key: " + mapping[0])
	source.diagnostics_changed.connect(_refresh)
	get_window().focus_entered.connect(_on_focus_changed)
	get_window().focus_exited.connect(_on_focus_changed)
	print("[InputDebug READY] project=", ProjectSettings.globalize_path("res://"),
		" scene=", owner.scene_file_path, " map=", _map_report)
	_refresh()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.1:
		_elapsed = 0.0
		_refresh()


func _on_focus_changed() -> void:
	print("[InputDebug FOCUS] focused=", get_window().has_focus())
	_refresh()


func _refresh() -> void:
	var axes: Vector2 = source.get_tilt_axes()
	var focused_control: Control = get_viewport().gui_get_focus_owner()
	var gui_focus: String = str(focused_control.get_path()) if focused_control != null else "none"
	text = "INPUT TRACE v1 | Window focus:%s | Tree paused:%s | Speed:%.2f\n" % [get_window().has_focus(), get_tree().paused, Engine.time_scale]
	text += "Scene:%s | Map %s\n" % [owner.scene_file_path, _map_report]
	text += "TiltInput ready:%s _input:%s | Link:%s | %s\n" % [
		source.is_node_ready(), source.is_processing_input(), platform.input_source == source,
		source.get_source_label().to_upper()
	]
	text += "Events:%d | %s\n" % [source.input_event_count, source.last_key_event]
	text += "Last press: %s\n" % source.last_press_event
	text += "Keys:[%s] P1:%.2f P2:%.2f -> Platform:(%.2f,%.2f)\n" % [
		", ".join(source.get_pressed_keys()), axes.x, axes.y,
		platform.last_received_axes.x, platform.last_received_axes.y
	]
	text += "X:%.2f Z:%.2f deg | Peak:%.2f/%.2f | Physics:%s ticks:%d\n" % [
		platform.rotation_degrees.x, platform.rotation_degrees.z,
		platform.peak_tilt_degrees.x, platform.peak_tilt_degrees.y,
		platform.is_physics_processing() and platform.can_process(), platform.physics_tick_count
	]
	text += "GUI focus:%s | Embedded: Input mode, click game, Pause OFF" % gui_focus
