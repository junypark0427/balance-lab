extends SceneTree
## Real Area3D overlap / native GUI integration; not a physical keyboard test.
var _failures: int = 0
var _completions: int = 0
var _session: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	print("[MISSION TEST] %s %s" % ["PASS" if condition else "FAIL", message])
	if not condition:
		_failures += 1

func _frames(count: int = 3) -> void:
	for index in range(count):
		await physics_frame

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _click(button: BaseButton) -> void:
	for index in range(3):
		await process_frame
	var center: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	root.push_input(motion, true)
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = center
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		root.push_input(click, true)

func _wait_scene(path: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path and not _session.transitioning:
			await _frames()
			return true
	return false

func _on_completion(_time: float) -> void:
	_completions += 1

func _place(ball: RigidBody3D, at: Vector3) -> void:
	ball.global_transform = Transform3D(Basis.IDENTITY, at)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.sleeping = false

func _run() -> void:
	_session = root.get_node("Session")
	_session.preferences_path = "/tmp/balance-lab-mission-test-settings.cfg"
	_session.reduced_motion = false
	_session.diagnostics_enabled = false
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(10)
	var game = current_scene
	var goal: Area3D = game.get_node("Platform/Goal")
	var ball: RigidBody3D = game.get_node("Ball")
	var platform = game.get_node("Platform")
	var mission = game.get_node("MissionController")
	var hud = game.get_node("HUD/GameplayUI")
	game.mission_succeeded.connect(_on_completion)
	var supports: Array[Node] = get_nodes_in_group("platform_supports")
	_check(supports.size() == 4 and supports.all(func(node): return not node.visible), "Four decorative platform supports are invisible")
	_check(mission.goal == goal and mission.ball == ball and mission.platform == platform, "Mission references use actual Goal, Ball and Platform nodes")
	_check(not game.goal_reached and not hud.success_menu.visible, "Result screen starts hidden with an active mission")
	# A different body deliberately shares the ball's layer; identity must still reject it.
	var other := StaticBody3D.new()
	other.collision_layer = 2
	other.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	shape.shape.radius = 0.3
	other.add_child(shape)
	game.add_child(other)
	other.global_position = goal.global_position
	await _frames(8)
	_check(goal.overlaps_body(other) and not game.goal_reached and _completions == 0, "Area3D overlaps a non-ball body without completing")
	other.queue_free()
	await _frames()
	game.elapsed_seconds = 65.432
	_place(ball, goal.global_position + Vector3.UP * 0.1)
	await _frames(10)
	_check(game.goal_reached and mission.is_completed and _completions == 1, "Actual ball overlap completes once")
	_check(game.game_status == "COMPLETE" and hud.success_menu.visible, "Success state and modal result screen are shown")
	_check(hud.success_menu.find_child("SuccessTitle", true, false).text == "MISSION SUCCESS!", "Requested mission success title is displayed")
	var saved_time: float = game.clear_time
	_check(saved_time == game.elapsed_seconds and saved_time >= 65.432 and saved_time < 66, "Completion snapshots the elapsed time")
	_check(hud.success_menu.find_child("ClearTime", true, false).text.begins_with("01:05."), "Result shows correctly formatted clear time")
	_check(ball.freeze and ball.linear_velocity == Vector3.ZERO and ball.angular_velocity == Vector3.ZERO, "Ball is safely frozen after the physics callback")
	_check(not platform.is_physics_processing() and platform.last_received_axes == Vector2.ZERO, "Platform no longer consumes control input")
	_check(not goal.monitoring, "Goal monitoring is disabled after completion")
	_check(get_nodes_in_group("mission_success_particles").size() == 1, "One native particle burst is created")
	await create_timer(0.5, true).timeout
	_check(hud.success_menu.modulate.a > 0.99 and hud.success_menu._panel.scale.is_equal_approx(Vector2.ONE), "Result fade and scale animation finishes")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("/tmp/balance-lab-mission-success.png") == OK, "Rendered success screen captured")
	var rotation: Vector3 = platform.rotation
	var ball_position: Vector3 = ball.global_position
	_key(KEY_D, true)
	_key(KEY_UP, true)
	await _frames(30)
	_check(game.get_node("TiltInput").get_tilt_axes() == Vector2(1, -1), "Input adapter still reports keys for diagnostics")
	_check(platform.rotation.is_equal_approx(rotation) and ball.global_position.is_equal_approx(ball_position), "Held cooperative inputs do not move the completed level")
	_key(KEY_D, false)
	_key(KEY_UP, false)
	goal.body_entered.emit(ball)
	mission.completed.emit()
	await _frames()
	_check(_completions == 1 and game.clear_time == saved_time, "Repeated goal/completion signals cannot repeat success or replace time")
	_check(game.elapsed_seconds == saved_time, "Elapsed timer remains stopped after success")
	_key(KEY_R, true)
	_key(KEY_R, false)
	ball.fell.emit()
	ball.respawned.emit()
	await _frames()
	_check(game.goal_reached and game.failure_count == 0 and ball.global_position.is_equal_approx(ball_position), "Retry key and late physics signals cannot undo completed mission")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await _frames()
	_check(not paused and not hud.pause_menu.visible, "ESC cannot overlay pause menu on result screen")
	var previous_id: int = game.get_instance_id()
	await _click(hud.success_menu.find_child("RetryButton", true, false))
	_check(await _wait_scene("res://scenes/main.tscn"), "RETRY routes to the current map scene")
	game = current_scene
	_check(game.get_instance_id() != previous_id and not game.goal_reached and game.clear_time == -1 and game.elapsed_seconds < 2, "Retry creates a fresh mission and timer")
	_check(not game.get_node("Ball").freeze and game.get_node("Platform").is_physics_processing() and not game.get_node("HUD/GameplayUI").success_menu.visible, "Retry restores physics, platform controls and hidden result screen")
	# Move the goal to another quadrant; no code changes should be needed.
	goal = game.get_node("Platform/Goal")
	goal.position = Vector3(-4, 0.7, 3.5)
	game.get_node("Platform/GoalMarker").position = Vector3(-4, 0.215, 3.5)
	await _frames()
	_place(game.get_node("Ball"), goal.global_position + Vector3.UP * 0.1)
	await _frames(10)
	_check(game.goal_reached, "Goal at a different position completes using the same controller")
	hud = game.get_node("HUD/GameplayUI")
	await create_timer(0.45, true).timeout
	await _click(hud.success_menu.find_child("LobbyButton", true, false))
	_check(await _wait_scene(_session.MENU_SCENE) and not paused, "LOBBY opens the existing menu scene")
	_check(current_scene.get_node("CanvasLayer/MenuUI").page == "home", "Lobby destination is the real home menu")
	_session.reduced_motion = true
	_session.start_level(0)
	await _wait_scene("res://scenes/main.tscn")
	game = current_scene
	_place(game.get_node("Ball"), game.get_node("Platform/Goal").global_position + Vector3.UP * 0.1)
	await _frames(10)
	_check(game.goal_reached and get_nodes_in_group("mission_success_particles").is_empty(), "Reduced motion keeps success functional without particles")
	print("[MISSION TEST] Failures: ", _failures)
	quit(0 if _failures == 0 else 1)
