extends SceneTree
## Jolt integration tests. Synthetic input checks physics, not macOS keyboard focus.
## godot --headless --path . --script res://tests/ball_physics_test.gd
## Add -- --capture with a graphics display to save a rolling-ball frame.

var _failures: int = 0
var _respawns: int = 0
var _reset_transform: Transform3D
var _reset_linear: Vector3
var _reset_angular: Vector3
var _ball: RigidBody3D


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	print("[PHYSICS TEST] %s %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		_failures += 1


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func _on_respawned() -> void:
	_respawns += 1
	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(_ball.get_rid())
	_reset_transform = state.transform
	_reset_linear = state.linear_velocity
	_reset_angular = state.angular_velocity


func _place(position: Vector3, velocity: Vector3 = Vector3.ZERO) -> void:
	_ball.global_transform = Transform3D(Basis.IDENTITY, position)
	_ball.linear_velocity = velocity
	_ball.angular_velocity = Vector3.ZERO
	_ball.sleeping = false


func _run() -> void:
	print("[PHYSICS TEST] Jolt simulation with synthetic input; physical keyboard delivery is not tested.")
	root.size = Vector2i(1152, 720)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	_ball = scene.get_node("Ball")
	var platform = scene.get_node("Platform")
	var source = scene.get_node("TiltInput")
	var status: Label = scene.get_node("HUD/Status")
	var goal: Area3D = platform.get_node("Goal")
	# Isolate the rolling/reset cases from the terminal mission-completion rule.
	goal.monitoring = false
	source.debug_logging = false
	platform.debug_logging = false
	source.use_sensor_input = true
	_ball.respawned.connect(_on_respawned)
	_check(not _ball.freeze and _ball.gravity_scale == 1.0 and _ball.continuous_cd, "Ball is dynamic, affected by gravity and uses CCD")
	_check(platform.get_node("MeshInstance3D").mesh.size == Vector3(16, 0.4, 16) and platform.get_node("CollisionShape3D").shape.size == Vector3(16, 0.4, 16), "16x16 visual platform and collision dimensions match")
	_check(_ball.get_node("MeshInstance3D").mesh.radius == _ball.get_node("CollisionShape3D").shape.radius, "Ball visual and collision radii match")
	await _frames(12)
	_check(_ball.position.y < 1.0 and _ball.linear_velocity.y < 0, "Gravity lowers ball from initial position")
	await _frames(90)
	_check(absf(_ball.position.y - 0.7) < 0.06 and absf(_ball.linear_velocity.y) < 0.1, "Ball settles on the platform without sinking or bouncing indefinitely")
	source.set_sensor_axes(Vector2(1, -1))
	await _frames(120)
	_check(_ball.position.x > 0.5 and _ball.position.z < -0.5, "Diagonal tilt rolls ball right and toward far edge")
	_check(_ball.linear_velocity.length() > 0.5 and _ball.angular_velocity.length() > 0.5, "Ball develops both translational and rotational momentum")
	_check(platform.to_local(_ball.global_position).y > 0.64, "Rolling ball remains above platform collision surface")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("/tmp/balance-lab-physics-preview.png") == OK, "Rendered rolling-ball frame saved")
	# Returning to neutral must not instantly erase the ball's momentum.
	var before: Vector3 = _ball.position
	source.set_sensor_axes(Vector2.ZERO)
	await _frames(12)
	_check(_ball.position.distance_to(before) > 0.1 and _ball.linear_velocity.length() > 0.2, "Ball keeps inertia while the platform returns to neutral")
	await _frames(120)
	_ball.request_reset()
	await _frames(60)
	_check(_reset_linear == Vector3.ZERO and _reset_angular == Vector3.ZERO and _reset_transform.basis.is_equal_approx(Basis.IDENTITY), "Reset clears linear velocity, angular velocity and orientation in physics state")
	_check(_ball.position.distance_to(Vector3(0, 0.7, 0)) < 0.08 and scene.failure_count == 0, "Manual reset restores center without counting a failure")
	# Give a rolling ball moderate momentum on a level plane to test damping/friction.
	_ball.linear_velocity = Vector3(1.5, 0, 0)
	_ball.angular_velocity = Vector3(0, 0, -3.0)
	await _frames(6)
	var coast_speed: float = _ball.linear_velocity.length()
	await _frames(90)
	_check(_ball.linear_velocity.length() < coast_speed and _ball.position.y > 0.64, "Friction and damping gradually reduce rolling speed on a level platform")
	# An actual off-edge fall must produce one failure and respawn, not just a manual teleport below the threshold.
	_place(Vector3(8.8, 1.1, 0), Vector3(1, 0, 0))
	var respawns_before: int = _respawns
	for frame in range(180):
		await _frames(1)
		if _respawns > respawns_before:
			break
	_check(scene.failure_count == 1 and _respawns == respawns_before + 1, "Off-platform gravity fall counts exactly one failure and respawns")
	_check(status.text.begins_with("Falls: 1") and _reset_transform.origin.distance_to(platform.to_global(_ball.spawn_local_position)) < 0.001, "Failure feedback persists and respawn uses platform-relative start position")
	_check(_reset_linear == Vector3.ZERO and _reset_angular == Vector3.ZERO and _reset_transform.basis.is_equal_approx(Basis.IDENTITY), "Falling respawn clears all momentum and rotation")
	await _frames(60)
	_check(scene.failure_count == 1 and absf(_ball.position.y - 0.7) < 0.06, "Respawn settles without repeated failures")
	# CCD must catch a fast downward ball before the -6 failure plane.
	_place(Vector3(0, 3, 0), Vector3(0, -80, 0))
	await _frames(60)
	_check(scene.failure_count == 1 and absf(_ball.position.y - 0.7) < 0.1, "CCD prevents a fast ball tunneling through the platform")
	# Continue holding tilt across a real fall and respawn.
	source.set_sensor_axes(Vector2(-1, 0))
	await _frames(90)
	_place(Vector3(10, 1, 0))
	respawns_before = _respawns
	for frame in range(180):
		await _frames(1)
		if _respawns > respawns_before:
			break
	_check(scene.failure_count == 2 and _reset_transform.origin.distance_to(platform.to_global(_ball.spawn_local_position)) < 0.001, "Respawn remains safe while input holds the platform tilted")
	await _frames(30)
	_check(_ball.linear_velocity.x < -0.1 and platform.rotation_degrees.z > 14.9, "Controls and rolling resume after a tilted-platform respawn")
	# Completion is now terminal until the result screen reloads the map.
	source.set_sensor_axes(Vector2.ZERO)
	await _frames(120)
	goal.monitoring = true
	await _frames(3)
	_place(goal.global_position + Vector3.UP * 0.1)
	await _frames(15)
	_check(status.text.begins_with("GOAL!") and scene.goal_reached, "Expanded goal detects the physical ball and completes mission")
	_check(_ball.freeze and not platform.is_physics_processing(), "Mission completion locks ball and platform until retry")
	print("[PHYSICS TEST] Failures: ", _failures)
	quit(0 if _failures == 0 else 1)
