extends Node
## A small scene router and persisted, functional preferences.
const CATALOG = preload("res://scripts/level_catalog.gd")
const MENU_SCENE := "res://scenes/menu.tscn"
var diagnostics_enabled: bool = false
var reduced_motion: bool = false
var fullscreen_enabled: bool = false
var selected_level: int = 0
var transitioning: bool = false
var preferences_path: String = "user://settings.cfg"
var _fade: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		diagnostics_enabled = config.get_value("display", "diagnostics", false)
		reduced_motion = config.get_value("display", "reduced_motion", false)
		fullscreen_enabled = config.get_value("display", "fullscreen", false)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color("030a13")
	_fade.modulate.a = 0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	apply_fullscreen()

func is_embedded() -> bool:
	return "--embedded" in OS.get_cmdline_args()

func apply_fullscreen() -> void:
	if DisplayServer.get_name() != "headless" and not is_embedded():
		get_window().mode = Window.MODE_FULLSCREEN if fullscreen_enabled else Window.MODE_WINDOWED

func save_preferences() -> Error:
	var config := ConfigFile.new()
	config.set_value("display", "diagnostics", diagnostics_enabled)
	config.set_value("display", "reduced_motion", reduced_motion)
	config.set_value("display", "fullscreen", fullscreen_enabled)
	return config.save(preferences_path)

func start_level(index: int = 0) -> void:
	if index < 0 or index >= CATALOG.LEVELS.size():
		return
	var level: Dictionary = CATALOG.LEVELS[index]
	if not level.unlocked or not ResourceLoader.exists(level.scene):
		return
	selected_level = index
	change_scene(level.scene)

func change_scene(path: String) -> void:
	if transitioning or not ResourceLoader.exists(path):
		return
	transitioning = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var duration: float = 0.05 if reduced_motion else 0.28
	await create_tween().tween_property(_fade, "modulate:a", 1.0, duration).finished
	get_tree().paused = false
	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("Cannot open scene: " + path)
	await get_tree().process_frame
	await create_tween().tween_property(_fade, "modulate:a", 0.0, duration).finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transitioning = false
