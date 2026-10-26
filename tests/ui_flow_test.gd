extends SceneTree
## Native GUI input / scene integration. Does not verify a physical macOS keyboard.
var _failures: int = 0
var _session: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	print("[UI TEST] %s %s" % ["PASS" if value else "FAIL", label])
	if not value:
		_failures += 1

func _frames(count: int = 3) -> void:
	for index in range(count):
		await process_frame

func _click(button: BaseButton) -> void:
	await _frames()
	var center: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
	await _frames()

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)

func _wait_scene(path: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path and not _session.transitioning:
			await _frames(4)
			return true
	return false

func _capture(name: String) -> void:
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await create_timer(0.35, true).timeout
		await process_frame
		RenderingServer.force_draw()
		_check(root.get_texture().get_image().save_png("/tmp/balance-lab-" + name + ".png") == OK, "Capture " + name)

func _inside_screen(node: Node) -> bool:
	if node is Control and node.is_visible_in_tree() and (node is BaseButton or node is Label):
		if not root.get_visible_rect().encloses(node.get_global_rect()):
			print("[UI TEST] Clipped control: ", node.get_path(), " ", node.get_global_rect())
			return false
	for child in node.get_children():
		if not _inside_screen(child):
			return false
	return true

func _run() -> void:
	_session = root.get_node("Session")
	_session.preferences_path = "/tmp/balance-lab-ui-test-settings.cfg"
	_session.diagnostics_enabled = false
	_session.fullscreen_enabled = false
	_session.reduced_motion = false
	_session.apply_fullscreen()
	change_scene_to_file("res://scenes/menu.tscn")
	await _frames(15)
	_check(ProjectSettings.get_setting("display/window/size/viewport_width") == 1920 and ProjectSettings.get_setting("display/window/size/viewport_height") == 1080, "1920x1080 design resolution")
	var menu = current_scene.get_node("CanvasLayer/MenuUI")
	_check(menu.page == "home" and menu.find_child("StartButton", true, false) is Button, "Home uses real Godot buttons")
	for resolution in [Vector2i(960, 540), Vector2i(1280, 800), Vector2i(1024, 768)]:
		root.size = resolution
		await _frames(5)
		_check(_inside_screen(menu), "Home UI fits " + str(resolution))
	root.size = Vector2i(1280, 720)
	await _frames(5)
	await _capture("menu")
	await _click(menu.find_child("LevelSelectButton", true, false))
	_check(menu.page == "levels", "LEVEL SELECT routes to level directory")
	_check(_inside_screen(menu), "Level directory stays within viewport")
	_check(not menu.find_child("Level01", true, false).disabled and not menu.find_child("Level02", true, false).disabled and not menu.find_child("Level03", true, false).disabled and not menu.find_child("Level04", true, false).disabled, "All four implemented maps are selectable")
	await _capture("levels")
	await _click(menu.find_child("BackButton", true, false))
	await _click(menu.find_child("SettingsButton", true, false))
	_check(menu.page == "settings", "SETTINGS opens settings page")
	_check(_inside_screen(menu), "Settings stays within viewport")
	await _click(menu.find_child("InputDiagnosticsToggle", true, false))
	_check(_session.diagnostics_enabled and FileAccess.file_exists(_session.preferences_path), "Diagnostics toggle works and saves preferences")
	var config := ConfigFile.new()
	config.load(_session.preferences_path)
	_check(config.get_value("display", "diagnostics", false), "Saved diagnostics preference can be read back")
	await _click(menu.find_child("ReducedMotionToggle", true, false))
	_check(_session.reduced_motion, "Reduced motion toggle changes actual state")
	await _capture("settings")
	await _click(menu.find_child("BackButton", true, false))
	await _click(menu.find_child("StartButton", true, false))
	_check(await _wait_scene("res://scenes/main.tscn"), "GAME START transitions to existing playable scene")
	var game = current_scene
	var hud = game.get_node("HUD/GameplayUI")
	_check(not game.get_node("Ball").freeze and game.get_node("Platform").input_source == game.get_node("TiltInput"), "Game retains live physics and cooperative input connection")
	_check(_inside_screen(hud), "Gameplay HUD stays within viewport")
	_check(game.get_node("HUD/InputDebug").visible, "Saved diagnostics preference is applied in game")
	_key(KEY_F3)
	await _frames()
	_check(not game.get_node("HUD/InputDebug").visible, "F3 toggles live input diagnostics")
	await _capture("gameplay")
	_key(KEY_ESCAPE)
	await _frames()
	_check(paused and hud.pause_menu.visible, "ESC opens pause menu")
	_check(_inside_screen(hud.pause_menu), "Pause menu stays within viewport")
	var position: Vector3 = game.get_node("Ball").global_position
	var elapsed: float = game.elapsed_seconds
	var ticks: int = game.get_node("Platform").physics_tick_count
	await create_timer(0.25, true).timeout
	_check(position.is_equal_approx(game.get_node("Ball").global_position) and game.elapsed_seconds == elapsed and game.get_node("Platform").physics_tick_count == ticks, "Pause stops ball physics, tilt processing and elapsed time")
	await _capture("pause")
	await _click(hud.find_child("ResumeButton", true, false))
	_check(not paused and not hud.pause_menu.visible, "RESUME restores gameplay")
	await create_timer(0.15).timeout
	_check(game.elapsed_seconds > elapsed, "Elapsed time resumes")
	game.failure_count = 3
	game.elapsed_seconds = 42
	var old_id: int = game.get_instance_id()
	_key(KEY_ESCAPE)
	await _frames()
	await _click(hud.find_child("RestartButton", true, false))
	_check(await _wait_scene("res://scenes/main.tscn"), "RESTART reloads the level")
	_check(current_scene.get_instance_id() != old_id and current_scene.failure_count == 0 and current_scene.elapsed_seconds < 2 and not paused, "Restart resets timer, failure count and pause state")
	hud = current_scene.get_node("HUD/GameplayUI")
	_key(KEY_ESCAPE)
	await _frames()
	await _click(hud.find_child("MainMenuButton", true, false))
	_check(await _wait_scene("res://scenes/menu.tscn") and not paused, "MAIN MENU returns safely from a paused game")
	menu = current_scene.get_node("CanvasLayer/MenuUI")
	await _click(menu.find_child("LevelSelectButton", true, false))
	await _click(menu.find_child("Level01", true, false))
	_check(await _wait_scene("res://scenes/main.tscn"), "Available level card opens playable map")
	# LEVEL02 uses the same navigation, pause and result flows with its own map metadata.
	_session.change_scene("res://scenes/menu.tscn")
	await _wait_scene("res://scenes/menu.tscn")
	menu = current_scene.get_node("CanvasLayer/MenuUI")
	await _click(menu.find_child("LevelSelectButton", true, false))
	await _click(menu.find_child("Level02", true, false))
	_check(await _wait_scene("res://scenes/level_02.tscn") and _session.selected_level == 1, "LEVEL SELECT enters LEVEL02")
	game = current_scene
	hud = game.get_node("HUD/GameplayUI")
	_check(game.level_index == 1 and game.get_node("Camera3D").has_method("set_diagnostics_visible"), "LEVEL02 uses its own metadata and follow camera")
	_key(KEY_ESCAPE)
	await _frames()
	_check(paused and hud.pause_menu.visible, "LEVEL02 pause works")
	await _click(hud.find_child("RestartButton", true, false))
	_check(await _wait_scene("res://scenes/level_02.tscn") and not paused, "LEVEL02 restart stays on LEVEL02")
	game = current_scene
	var ball: RigidBody3D = game.get_node("Ball")
	ball.global_transform = Transform3D(Basis.IDENTITY, game.get_node("Platform/Goal").global_position)
	ball.linear_velocity = Vector3.ZERO
	await create_timer(0.3).timeout
	hud = game.get_node("HUD/GameplayUI")
	_check(game.goal_reached and hud.success_menu.visible, "LEVEL02 uses existing success result")
	await _click(hud.success_menu.find_child("RetryButton", true, false))
	_check(await _wait_scene("res://scenes/level_02.tscn") and not current_scene.goal_reached, "LEVEL02 result Retry reloads correct map")
	game = current_scene
	ball = game.get_node("Ball")
	ball.global_transform = Transform3D(Basis.IDENTITY, game.get_node("Platform/Goal").global_position)
	ball.linear_velocity = Vector3.ZERO
	await create_timer(0.3).timeout
	await _click(game.get_node("HUD/GameplayUI").success_menu.find_child("LobbyButton", true, false))
	_check(await _wait_scene("res://scenes/menu.tscn") and not paused, "LEVEL02 result Lobby returns to existing menu")
	# LEVEL03 uses the same navigation, pause and result flows with its own map metadata.
	_session.change_scene("res://scenes/menu.tscn")
	await _wait_scene("res://scenes/menu.tscn")
	menu = current_scene.get_node("CanvasLayer/MenuUI")
	await _click(menu.find_child("LevelSelectButton", true, false))
	await _click(menu.find_child("Level03", true, false))
	_check(await _wait_scene("res://scenes/level_03.tscn") and _session.selected_level == 2, "LEVEL SELECT enters LEVEL03")
	game = current_scene
	hud = game.get_node("HUD/GameplayUI")
	_check(game.level_index == 2 and game.get_node("Camera3D").has_method("set_diagnostics_visible"), "LEVEL03 uses its own metadata and follow camera")
	_key(KEY_ESCAPE)
	await _frames()
	_check(paused and hud.pause_menu.visible, "LEVEL03 pause works")
	await _click(hud.find_child("RestartButton", true, false))
	_check(await _wait_scene("res://scenes/level_03.tscn") and not paused, "LEVEL03 restart stays on LEVEL03")
	game = current_scene
	ball = game.get_node("Ball")
	ball.global_transform = Transform3D(Basis.IDENTITY, game.get_node("Platform/Goal").global_position)
	ball.linear_velocity = Vector3.ZERO
	await create_timer(0.3).timeout
	hud = game.get_node("HUD/GameplayUI")
	_check(game.goal_reached and hud.success_menu.visible, "LEVEL03 uses existing success result")
	await _click(hud.success_menu.find_child("RetryButton", true, false))
	_check(await _wait_scene("res://scenes/level_03.tscn") and not current_scene.goal_reached, "LEVEL03 result Retry reloads correct map")
	game = current_scene
	ball = game.get_node("Ball")
	ball.global_transform = Transform3D(Basis.IDENTITY, game.get_node("Platform/Goal").global_position)
	ball.linear_velocity = Vector3.ZERO
	await create_timer(0.3).timeout
	await _click(game.get_node("HUD/GameplayUI").success_menu.find_child("LobbyButton", true, false))
	_check(await _wait_scene("res://scenes/menu.tscn") and not paused, "LEVEL03 result Lobby returns to existing menu")
	# LEVEL04 uses the same navigation, pause and result flows with its own map metadata.
	_session.change_scene("res://scenes/menu.tscn")
	await _wait_scene("res://scenes/menu.tscn")
	menu = current_scene.get_node("CanvasLayer/MenuUI")
	await _click(menu.find_child("LevelSelectButton", true, false))
	await _click(menu.find_child("Level04", true, false))
	_check(await _wait_scene("res://scenes/level_04.tscn") and _session.selected_level == 3, "LEVEL SELECT enters LEVEL04")
	game = current_scene
	hud = game.get_node("HUD/GameplayUI")
	_check(game.level_index == 3 and game.get_node("Camera3D").has_method("set_diagnostics_visible"), "LEVEL04 uses its own metadata and follow camera")
	_key(KEY_ESCAPE)
	await _frames()
	_check(paused and hud.pause_menu.visible, "LEVEL04 pause works")
	await _click(hud.find_child("RestartButton", true, false))
	_check(await _wait_scene("res://scenes/level_04.tscn") and not paused, "LEVEL04 restart stays on LEVEL04")
	game = current_scene
	ball = game.get_node("Ball")
	ball.global_transform = Transform3D(Basis.IDENTITY, game.get_node("Platform/Goal").global_position)
	ball.linear_velocity = Vector3.ZERO
	await create_timer(0.3).timeout
	hud = game.get_node("HUD/GameplayUI")
	_check(game.goal_reached and hud.success_menu.visible and "FINAL EXPERIMENT" in hud.success_menu._level.text, "LEVEL04 shows final experiment completion without a new ending system")
	await _click(hud.success_menu.find_child("RetryButton", true, false))
	_check(await _wait_scene("res://scenes/level_04.tscn") and not current_scene.goal_reached, "LEVEL04 result Retry reloads correct map")
	game = current_scene
	ball = game.get_node("Ball")
	ball.global_transform = Transform3D(Basis.IDENTITY, game.get_node("Platform/Goal").global_position)
	ball.linear_velocity = Vector3.ZERO
	await create_timer(0.3).timeout
	await _click(game.get_node("HUD/GameplayUI").success_menu.find_child("LobbyButton", true, false))
	_check(await _wait_scene("res://scenes/menu.tscn") and not paused, "LEVEL04 result Lobby returns to existing menu")
	_check(_session.CATALOG.LEVELS.size() == 4 and not current_scene.find_child("Level05", true, false), "Catalog ends at LEVEL04")
	_session.start_level(4)
	await _frames()
	_check(current_scene.scene_file_path == "res://scenes/menu.tscn" and not _session.transitioning, "Nonexistent LEVEL05 cannot be opened")
	print("[UI TEST] Failures: ", _failures)
	quit(0 if _failures == 0 else 1)
