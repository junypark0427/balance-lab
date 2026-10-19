extends SceneTree
## Run with: godot --headless --path . --script res://tests/tilt_smoke_test.gd
## Add -- --capture to save an actual rendered frame (requires a graphics display).

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	print("[TEST] %s %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		_failures += 1


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _capture(path: String) -> void:
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var error: Error = root.get_texture().get_image().save_png(path)
		_check(error == OK, "Rendered frame saved: " + path)


func _run() -> void:
	print("[TEST] SYNTHETIC INPUT ONLY: InputEventKey injection does not verify macOS keyboard delivery or editor focus.")
	root.size = Vector2i(1152, 720)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var source = scene.get_node("TiltInput")
	var platform = scene.get_node("Platform")
	var ball = scene.get_node("Ball")
	var camera = scene.get_node("Camera3D")
	_check(not ball.freeze and ball.get_node("CollisionShape3D").shape != null, "Default scene enables ball physics and retains collision")
	# Isolate the input/platform regression from moving-ball gameplay.
	ball.freeze = true
	var initial_ball: Transform3D = ball.global_transform
	var initial_camera: Transform3D = camera.global_transform
	await _frames(3)
	_check(camera.is_current(), "Main camera is active")
	var direction: Vector3 = (platform.global_position - camera.global_position).normalized()
	_check((-camera.global_basis.z).dot(direction) > 0.99999, "Camera looks at platform center")
	_check(platform.input_source == source and not source.use_sensor_input, "Keyboard adapter is connected to platform")
	_check(ball.freeze and ball.get_node("CollisionShape3D").shape != null, "Ball is frozen with collision retained")
	for mapping in [["tilt_left", KEY_A], ["tilt_right", KEY_D], ["tilt_forward", KEY_UP], ["tilt_backward", KEY_DOWN]]:
		var events: Array[InputEvent] = InputMap.action_get_events(mapping[0])
		_check(not events.is_empty() and events[0].physical_keycode == mapping[1], "Input Map: " + mapping[0])
	# Inject synthetic events with physical key codes; this does not exercise the OS keyboard path.
	_key(KEY_A, true)
	await _frames(45)
	_check(absf(platform.rotation_degrees.x) < 0.001 and platform.rotation_degrees.z > 1, "Player 1 alone changes only Z rotation")
	_key(KEY_A, false)
	await _frames(130)
	_key(KEY_UP, true)
	await _frames(45)
	_check(platform.rotation_degrees.x < -1 and absf(platform.rotation_degrees.z) < 0.001, "Player 2 alone changes only X rotation")
	_key(KEY_UP, false)
	await _frames(130)
	_key(KEY_A, true)
	_key(KEY_UP, true)
	await _frames(12)
	_check(source.get_tilt_axes() == Vector2(-1, -1), "A+Up produces simultaneous Player 1/2 input")
	_check(platform.rotation_degrees.x < -0.1 and platform.rotation_degrees.x > -15 and platform.rotation_degrees.z > 0.1 and platform.rotation_degrees.z < 15, "Both axes tilt gradually around platform center")
	await _frames(100)
	_check(platform.rotation_degrees.x < -14.9 and platform.rotation_degrees.z > 14.9, "A+Up reaches intended tilt directions")
	var physical_transform: Transform3D = PhysicsServer3D.body_get_state(platform.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
	_check(physical_transform.basis.is_equal_approx(platform.global_basis), "Physics body and visible platform share rotation")
	await _capture("/tmp/balance-lab-tilt-diagonal.png")
	_key(KEY_D, true)
	_key(KEY_DOWN, true)
	await _frames(3)
	_check(source.get_tilt_axes() == Vector2.ZERO, "Opposite keys cancel independently")
	_key(KEY_A, false)
	_key(KEY_UP, false)
	await _frames(112)
	_check(source.get_tilt_axes() == Vector2.ONE and platform.rotation_degrees.x > 14.9 and platform.rotation_degrees.z < -14.9, "D+Down tilts both axes in opposite directions")
	_check(platform.position == Vector3.ZERO, "Platform pivot stays at center")
	_check(ball.global_transform.is_equal_approx(initial_ball) and ball.linear_velocity == Vector3.ZERO and ball.angular_velocity == Vector3.ZERO, "Ball stays at initial position and rotation during tilt")
	_key(KEY_D, false)
	_key(KEY_DOWN, false)
	await _frames(12)
	_check(absf(platform.rotation_degrees.x) > 0.1 and absf(platform.rotation_degrees.x) < 14.9, "Release returns gradually toward neutral")
	await _frames(130)
	_check(platform.rotation.length() < 0.001, "Release returns both axes to neutral")
	_key(KEY_R, true)
	await _frames(3)
	_key(KEY_R, false)
	_check(ball.global_transform.is_equal_approx(initial_ball) and not ball._reset_requested, "R works while frozen without queuing a later reset")
	# Check both endpoints and all diagonal tilts, including every platform corner.
	source.use_sensor_input = true
	var all_visible: bool = true
	var clear_of_hud: bool = true
	var bounded: bool = true
	var above_backdrop: bool = true
	for axes in [Vector2(2, 2), Vector2(-2, 2), Vector2(2, -2), Vector2(-2, -2)]:
		source.set_sensor_axes(axes)
		await _frames(100)
		bounded = bounded and absf(platform.rotation_degrees.x) <= 15.0001 and absf(platform.rotation_degrees.z) <= 15.0001
		var lowest_corner: float = INF
		for x in [-8.0, 8.0]:
			for y in [-0.2, 0.2]:
				for z in [-8.0, 8.0]:
					lowest_corner = minf(lowest_corner, platform.to_global(Vector3(x, y, z)).y)
					all_visible = all_visible and camera.is_position_in_frustum(platform.to_global(Vector3(x, y, z)))
					var screen_point: Vector2 = camera.unproject_position(platform.to_global(Vector3(x, y, z)))
					clear_of_hud = clear_of_hud and screen_point.y < scene.get_node("HUD/InputDebug").get_global_rect().position.y
		# Frustum checks alone cannot detect a decorative floor cutting through the board.
		for decoration in scene.get_node("LabEnvironment").get_children():
			if decoration is MeshInstance3D and decoration.is_visible_in_tree():
				var bounds: AABB = decoration.get_aabb()
				for endpoint in range(8):
					above_backdrop = above_backdrop and decoration.to_global(bounds.get_endpoint(endpoint)).y < lowest_corner - 0.25
		all_visible = all_visible and camera.is_position_in_frustum(ball.global_position) and camera.is_position_in_frustum(platform.get_node("GoalMarker").global_position)
		if axes == Vector2(2, 2) or axes == Vector2(-2, -2):
			await _capture("/tmp/balance-lab-floor-clear-%s.png" % ("right" if axes.x > 0 else "left"))
	_check(bounded, "Both axes stay within +/-15 degrees with oversized sensor input")
	_check(all_visible, "Platform corners, ball and goal remain in camera frustum at all diagonal extremes")
	_check(above_backdrop, "Decorative floor, grid and light frame stay below the entire board at all diagonal extremes")
	_check(clear_of_hud or not scene.get_node("HUD/InputDebug").visible, "Visible diagnostic panel stays clear of platform at diagonal extremes")
	_check(camera.global_transform.is_equal_approx(initial_camera), "Camera remains fixed during input")
	source.set_sensor_axes(Vector2.ZERO)
	await _frames(130)
	source.use_sensor_input = false
	_check(ball.global_transform.is_equal_approx(initial_ball), "Frozen ball remains stationary throughout test")
	await _capture("/tmp/balance-lab-tilt-preview.png")
	print("[TEST] Failures: ", _failures)
	quit(0 if _failures == 0 else 1)
