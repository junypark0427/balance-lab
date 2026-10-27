extends SceneTree
## Observer for HUMAN + REAL hardware testing. Never synthesizes axes/keys or moves the ball.
var _log: FileAccess
var _elapsed: float = 0
var _sample_elapsed: float = 0
var _print_elapsed: float = 0
var _seconds: float = 0
var _capture: String = ""
var _captured: bool = false

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var level: int = 0
	var output: String = "res://reports/sensors/live_game.csv"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--level="): level=argument.trim_prefix("--level=").to_int()
		if argument.begins_with("--seconds="): _seconds=argument.trim_prefix("--seconds=").to_float()
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
		if argument.begins_with("--capture="): _capture=argument.trim_prefix("--capture=")
	var paths: Array[String] = ["res://scenes/main.tscn","res://scenes/level_02.tscn","res://scenes/level_03.tscn","res://scenes/level_04.tscn"]
	if level<0 or level>=paths.size(): quit(2); return
	_log=FileAccess.open(output,FileAccess.WRITE)
	if _log == null: push_error("Cannot open live sensor log");quit(2);return
	_log.store_csv_line(PackedStringArray(["seconds","level","p1_sensor","p2_sensor","p1_input","p2_input","tilt_x","tilt_z","ball_x","ball_y","ball_z","speed","key_events","paused","goal","mode"]))
	var start_menu: bool = "--menu" in OS.get_cmdline_user_args()
	var game: Node = load("res://scenes/menu.tscn" if start_menu else paths[level]).instantiate()
	root.add_child(game)
	current_scene=game
	root.get_node("Session").selected_level=level
	if not start_menu: root.get_node("SensorHub").show_panel(true)
	print("[REAL SENSOR TEST] No generated input. C: INIT current pose. GAME START selects a level. Close this game window to finish.")

func _process(delta: float) -> bool:
	_elapsed+=delta; _sample_elapsed+=delta;_print_elapsed+=delta
	if _seconds>0 and _elapsed>=_seconds: quit();return false
	if _log==null or _sample_elapsed<0.1 or current_scene==null: return false
	_sample_elapsed=0
	var game: Node = current_scene
	if not game.has_node("TiltInput") or not game.has_node("Ball"): return false
	var hub: Node = root.get_node("SensorHub")
	var sensors: Vector2 = hub.get_axes()
	var source: Node = game.get_node("TiltInput")
	var axes: Vector2 = source.get_tilt_axes()
	var platform: Node3D = game.get_node("Platform")
	var ball: RigidBody3D = game.get_node("Ball")
	_log.store_csv_line(PackedStringArray([str(_elapsed),str(game.level_index+1),str(sensors.x),str(sensors.y),str(axes.x),str(axes.y),str(platform.rotation_degrees.x),str(platform.rotation_degrees.z),str(ball.position.x),str(ball.position.y),str(ball.position.z),str(ball.linear_velocity.length()),str(source.input_event_count),str(paused),str(game.goal_reached),source.get_source_label()]))
	if _print_elapsed>1:
		_print_elapsed=0;_log.flush()
		print("[REAL SENSOR] level=%d sensor=(%.2f,%.2f) input=(%.2f,%.2f) X/Z=(%.2f,%.2f) ball=%s paused=%s goal=%s" % [game.level_index+1,sensors.x,sensors.y,axes.x,axes.y,platform.rotation_degrees.x,platform.rotation_degrees.z,str(ball.position),paused,game.goal_reached])
	if not _captured and _elapsed>2 and not _capture.is_empty() and DisplayServer.get_name()!="headless":
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(_capture)
		_captured=true
	return false

func _finalize() -> void:
	if _log: _log.close()
