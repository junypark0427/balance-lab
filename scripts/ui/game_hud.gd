extends Control
const UI = preload("res://scripts/ui/lab_ui.gd")
const SUCCESS_SCENE = preload("res://scenes/ui/mission_success.tscn")
@onready var game = $"../.."
var pause_menu: Control
var _timer: Label
var _state: Label
var _falls: Label
var _resume: Button
var _debug: Label
var success_menu: Control
var _pause_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	$"../Instructions".hide()
	$"../Status".hide()
	_debug = $"../InputDebug"
	_debug.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_debug.offset_left = 48
	_debug.offset_right = -48
	_debug.offset_top = -340
	_debug.offset_bottom = -130
	_debug.add_theme_font_size_override("font_size", 16)
	_apply_diagnostics()
	_build_header()
	_build_footer()
	_build_pause()
	_build_success()
	_decorate_platform()

func _apply_diagnostics() -> void:
	_debug.visible = Session.diagnostics_enabled
	var camera: Camera3D = game.get_node("Camera3D")
	if camera.has_method("set_diagnostics_visible"):
		camera.set_diagnostics_visible(_debug.visible)
	else:
		camera.size = 30.0 if _debug.visible else 24.0
		camera.v_offset = -3.0 if _debug.visible else 0.0

func _decorate_platform() -> void:
	var platform: Node3D = game.get_node("Platform")
	var board_size: Vector3 = platform.get_node("MeshInstance3D").mesh.get_aabb().size
	var material := StandardMaterial3D.new()
	material.albedo_color = UI.CYAN
	material.emission_enabled = true
	material.emission = UI.CYAN
	material.emission_energy_multiplier = 1.3
	for side in [-1.0, 1.0]:
		for across in [true, false]:
			var strip := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(board_size.x, 0.06, 0.06) if across else Vector3(0.06, 0.06, board_size.z)
			strip.mesh = mesh
			strip.material_override = material
			platform.add_child(strip)
			strip.position = Vector3(0, -0.08, side * (board_size.z * 0.5 + 0.02)) if across else Vector3(side * (board_size.x * 0.5 + 0.02), -0.08, 0)

func _build_header() -> void:
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.offset_left = 48
	margin.offset_top = 32
	margin.offset_right = -48
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)
	var level := _card(row)
	level.custom_minimum_size.x = 400
	level.add_child(UI.label("LEVEL  " + Session.CATALOG.LEVELS[game.level_index].id, 17, UI.CYAN))
	level.add_child(UI.label(Session.CATALOG.LEVELS[game.level_index].title, 28))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var time_box := _card(row)
	time_box.custom_minimum_size.x = 220
	time_box.add_child(UI.label("ELAPSED TIME", 15, UI.MUTED))
	_timer = UI.label("00:00.0", 33)
	_timer.name = "ElapsedTime"
	time_box.add_child(_timer)
	var state_box := _card(row)
	state_box.custom_minimum_size.x = 330
	state_box.add_child(UI.label("EXPERIMENT STATUS", 15, UI.MUTED))
	_state = UI.label("IN PROGRESS", 25, UI.CYAN)
	_state.name = "GameState"
	state_box.add_child(_state)
	var pause := UI.button("II   PAUSE", false)
	_pause_button = pause
	pause.name = "PauseButton"
	pause.custom_minimum_size = Vector2(160, 88)
	row.add_child(pause)
	pause.pressed.connect(set_paused.bind(true))

func _card(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel(Color("081727e8"), Color("2e4b60"), 6))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	return box

func _build_footer() -> void:
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	margin.offset_left = 48
	margin.offset_right = -48
	margin.offset_top = -116
	margin.offset_bottom = -32
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)
	var p1 := _card(row)
	p1.custom_minimum_size.x = 360
	p1.add_child(UI.label("PLAYER 1     /     ROLL", 15, UI.CYAN))
	p1.add_child(UI.label("A  /  D", 28))
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(center)
	_falls = UI.label("FALLS  00     ·     R  RETRY     ·     F3  DIAGNOSTICS", 17, UI.MUTED)
	_falls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_falls)
	var hint := UI.label("TILT TOGETHER, REACH FURTHER", 18, UI.WHITE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(hint)
	var p2 := _card(row)
	p2.custom_minimum_size.x = 360
	p2.add_child(UI.label("PLAYER 2     /     PITCH", 15, UI.ORANGE))
	p2.add_child(UI.label("↑  /  ↓", 28))

func _build_pause() -> void:
	pause_menu = Control.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	UI.full_rect(pause_menu)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.04, 0.075, 0.88)
	pause_menu.add_child(shade)
	UI.full_rect(shade)
	var center := CenterContainer.new()
	pause_menu.add_child(center)
	UI.full_rect(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 560
	panel.add_theme_stylebox_override("panel", UI.panel(Color("0a1b2ef5"), UI.CYAN, 14))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var tag := UI.label("EXPERIMENT ON HOLD", 17, UI.CYAN)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag)
	var title := UI.label("PAUSED", 58)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	UI.line(box)
	_resume = UI.button("RESUME", true)
	_resume.name = "ResumeButton"
	box.add_child(_resume)
	_resume.pressed.connect(set_paused.bind(false))
	var restart := UI.button("RESTART")
	restart.name = "RestartButton"
	box.add_child(restart)
	restart.pressed.connect(_restart_level)
	var menu := UI.button("MAIN MENU")
	menu.name = "MainMenuButton"
	box.add_child(menu)
	menu.pressed.connect(func(): Session.change_scene(Session.MENU_SCENE))
	var note := UI.label("ESC TO RETURN TO THE EXPERIMENT", 15, UI.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	pause_menu.hide()

func _build_success() -> void:
	success_menu = SUCCESS_SCENE.instantiate()
	add_child(success_menu)
	success_menu.retry_requested.connect(_restart_level)
	success_menu.lobby_requested.connect(func(): Session.change_scene(Session.MENU_SCENE))
	game.mission_succeeded.connect(_on_mission_success)

func _restart_level() -> void:
	Session.change_scene(game.scene_file_path)

func _on_mission_success(clear_time: float) -> void:
	pause_menu.hide()
	_pause_button.disabled = true
	success_menu.present(clear_time, Session.CATALOG.LEVELS[game.level_index].id, Session.CATALOG.LEVELS[game.level_index].get("final", false))

func set_paused(value: bool) -> void:
	if Session.transitioning or game.goal_reached:
		return
	get_tree().paused = value
	pause_menu.visible = value
	if value:
		_resume.grab_focus()
	else:
		get_viewport().gui_release_focus()

func _process(_delta: float) -> void:
	var elapsed: float = game.elapsed_seconds
	_timer.text = "%02d:%02d.%d" % [int(elapsed / 60.0), int(elapsed) % 60, int(elapsed * 10.0) % 10]
	_state.text = "PAUSED" if get_tree().paused else game.game_status
	_state.add_theme_color_override("font_color", UI.ORANGE if get_tree().paused else UI.CYAN)
	_falls.text = "FALLS  %02d     ·     R  RETRY     ·     F3  DIAGNOSTICS" % game.failure_count

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		Session.diagnostics_enabled = not Session.diagnostics_enabled
		_apply_diagnostics()
		Session.save_preferences()
		get_viewport().set_input_as_handled()
