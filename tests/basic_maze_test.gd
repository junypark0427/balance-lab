extends SceneTree
## Real Jolt collision/path tests. Synthetic keys/sensor axes do not verify OS keyboard delivery.
## godot --headless --path . --fixed-fps 60 --script res://tests/basic_maze_test.gd
## Add -- --capture with a graphics display to save the map and its tilt extremes.
var _failures: int = 0
var _wall_hit: bool = false
var _reset_transform: Transform3D
var _reset_linear: Vector3
var _reset_angular: Vector3
var _game: Node3D
var _ball: RigidBody3D
var _platform: AnimatableBody3D
var _maze: AnimatableBody3D

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	print("[MAZE TEST] %s %s" % ["PASS" if value else "FAIL", label])
	if not value:
		_failures += 1

func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame

func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func _capture(name: String) -> void:
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		# macOS may suppress automatic draws for a background window. Render explicitly.
		await process_frame
		RenderingServer.force_draw()
		_check(root.get_texture().get_image().save_png("/tmp/balance-lab-maze-" + name + ".png") == OK, "Capture " + name)

func _on_respawn() -> void:
	var state := PhysicsServer3D.body_get_direct_state(_ball.get_rid())
	_reset_transform = state.transform
	_reset_linear = state.linear_velocity
	_reset_angular = state.angular_velocity

func _has_path(space: PhysicsDirectSpaceState3D) -> bool:
	# Flood-fill ball-center space using a slightly oversized sphere above the floor.
	# This checks the actual collision shapes, including openings and corner clearance.
	var sphere := SphereShape3D.new()
	sphere.radius = 0.55
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1
	var start := Vector2i(roundi(_ball.position.x * 4), roundi(_ball.position.z * 4))
	var finish: Vector3 = _platform.get_node("Goal").position
	var target := Vector2i(roundi(finish.x * 4), roundi(finish.z * 4))
	var queue: Array[Vector2i] = [start]
	var seen: Dictionary = {start: true}
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		if cell == target:
			return true
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			if abs(next.x) > 29 or abs(next.y) > 29 or seen.has(next):
				continue
			seen[next] = true
			# Above the floor, with the sphere center still below the wall top.
			query.transform = Transform3D(Basis.IDENTITY, Vector3(next.x * 0.25, 0.8, next.y * 0.25))
			if space.intersect_shape(query, 1).is_empty():
				queue.append(next)
	return false

func _run() -> void:
	var session = root.get_node("Session")
	session.diagnostics_enabled = false
	_game = load("res://scenes/main.tscn").instantiate()
	root.add_child(_game)
	current_scene = _game
	_ball = _game.get_node("Ball")
	_platform = _game.get_node("Platform")
	_maze = _platform
	var source = _game.get_node("TiltInput")
	source.debug_logging = false
	_platform.debug_logging = false
	var camera: Camera3D = _game.get_node("Camera3D")
	var initial_camera: Transform3D = camera.global_transform
	_ball.respawned.connect(_on_respawn)
	_check(_ball.position == Vector3(-5.6, 1.1, 3.4) and _ball.spawn_local_position == _ball.position, "Ball starts at the inset left spawn; reset position matches")
	_check(_platform.get_node("Goal").position == Vector3(5.6, 0.7, 1.2), "Existing Goal is inset at the right corridor end")
	_check(_maze.scene_file_path == "res://scenes/maps/basic_maze.tscn" and _maze.sync_to_physics, "Replaceable maze scene uses the existing platform physics body and rotation pivot")
	var walls: Array[Node] = get_nodes_in_group("maze_wall_meshes")
	var shapes_match: bool = walls.size() == 10
	for wall in walls:
		var shape: CollisionShape3D = _maze.get_node(str(wall.name) + "Collision")
		shapes_match = shapes_match and shape.get_parent() == _maze and shape.position == wall.position and shape.shape.size == wall.mesh.size
		shapes_match = shapes_match and is_equal_approx(wall.mesh.size.y, 0.75) and is_equal_approx(minf(wall.mesh.size.x, wall.mesh.size.z), 0.32)
	_check(shapes_match, "Ten metal BoxMesh walls have matching direct-body box collisions, uniform height and thickness")
	var ceiling: CollisionShape3D = _platform.get_node("EscapeCeiling")
	var ceiling_bottom: float = ceiling.position.y - ceiling.shape.size.y * 0.5
	var ball_radius: float = _ball.get_node("CollisionShape3D").shape.radius
	_check(ceiling.get_parent() == _platform and ceiling.get_child_count() == 0 and ceiling.shape.size == Vector3(16, 0.2, 16), "Invisible collision-only ceiling covers the maze and shares the platform body")
	_check(_ball.spawn_local_position.y + ball_radius < ceiling_bottom and ceiling_bottom - 0.95 < ball_radius * 2, "Spawn clears the ceiling and the gap above walls is smaller than the ball diameter")
	await _frames(100)
	_check(_ball.position.distance_to(Vector3(-5.6, 0.7, 3.4)) < 0.08, "Gravity settles the ball safely inside the left starting corridor")
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	_check(_has_path(space), "Actual collision geometry admits a ball-sized connected path from spawn to Goal")
	var shortcut := PhysicsRayQueryParameters3D.create(_ball.position, _platform.get_node("Goal").position, 1)
	_check(not space.intersect_ray(shortcut).is_empty(), "Walls prevent a straight left-to-goal shortcut")
	await _capture("overview")
	# Exercise the unchanged keyboard -> adapter -> platform path with both players.
	_ball.freeze = true
	_key(KEY_D, true)
	_key(KEY_UP, true)
	await _frames(40)
	_check(source.get_tilt_axes() == Vector2(1, -1) and _platform.rotation_degrees.x < -1 and _platform.rotation_degrees.z < -1, "Synthetic D+Up drives independent X/Z rotations simultaneously")
	_key(KEY_D, false)
	_key(KEY_UP, false)
	await _frames(130)
	_check(_platform.rotation.length() < 0.001, "Both axes smoothly return to horizontal after release")
	source.use_sensor_input = true
	var attached: bool = true
	var visible: bool = true
	var unobscured: bool = true
	var sample_points: Array[Vector3] = [Vector3(-5.6, 0.7, 3.4), Vector3(-2.6, 0.7, 3.4), Vector3(-2.6, 0.7, -3.4), Vector3(5.6, 0.7, -3.4), Vector3(5.6, 0.7, 1.2)]
	# Physics rays must ignore the ceiling, which has no visible surface to occlude the view.
	ceiling.disabled = true
	await _frames(3)
	for axes in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		source.set_sensor_axes(axes)
		await _frames(100)
		var physical: Transform3D = PhysicsServer3D.body_get_state(_maze.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
		for wall in walls:
			attached = attached and (physical * wall.position).distance_to(wall.global_position) < 0.001
		for wall in walls:
			for endpoint in range(8):
				visible = visible and camera.is_position_in_frustum(wall.to_global(wall.get_aabb().get_endpoint(endpoint)))
		for point in sample_points:
			var top: Vector3 = _platform.to_global(point + Vector3.UP * 0.35)
			var ray := PhysicsRayQueryParameters3D.create(camera.global_position, top, 1)
			unobscured = unobscured and space.intersect_ray(ray).is_empty()
		_ball.global_position = _platform.to_global(Vector3(-5.6, 0.7, 3.4))
		await _capture("tilt-%d-%d" % [int(axes.x), int(axes.y)])
	_check(attached, "Maze physics body and all walls follow platform rotation at all four diagonal +/-15 degree extremes")
	_check(visible and camera.global_transform.is_equal_approx(initial_camera), "Fixed camera contains every wall at maximum tilt")
	_check(unobscured, "Walls do not cover the upper ball at spawn, turns or Goal across maximum tilt combinations")
	ceiling.disabled = false
	source.set_sensor_axes(Vector2.ZERO)
	await _frames(130)
	_ball.freeze = false
	_ball.request_reset()
	await _frames(90)
	# Roll into the first blocking wall using gravity, without directly setting velocity.
	_ball.contact_monitor = true
	_ball.max_contacts_reported = 8
	_ball.body_shape_entered.connect(func(_rid: RID, body: Node, body_shape_index: int, _local_shape_index: int):
		if body == _platform:
			var owner_node: Object = _platform.shape_owner_get_owner(_platform.shape_find_owner(body_shape_index))
			if owner_node is Node and owner_node.is_in_group("maze_wall_collisions"):
				_wall_hit = true
	)
	source.set_sensor_axes(Vector2(1, 0))
	var furthest_x: float = -INF
	for frame in range(300):
		await physics_frame
		furthest_x = maxf(furthest_x, _platform.to_local(_ball.global_position).x)
	_check(_wall_hit and furthest_x < -1.65 and _game.failure_count == 0, "Gravity rolls ball into the maze wall without passing through it")
	source.set_sensor_axes(Vector2.ZERO)
	await _frames(130)
	# Reproduce an upward kick that could previously carry the ball over a low wall.
	var leap_blocked: bool = true
	var roof_blocked: bool = true
	for outward in [false, true]:
		var launch := Vector3(-5.6 if outward else -2.6, 0.7, 3.4)
		_ball.global_transform = Transform3D(Basis.IDENTITY, _platform.to_global(launch))
		_ball.linear_velocity = _platform.global_basis * Vector3(-8 if outward else 8, 8, 0)
		_ball.angular_velocity = Vector3.ZERO
		for frame in range(90):
			await physics_frame
			var local_position: Vector3 = _platform.to_local(_ball.global_position)
			roof_blocked = roof_blocked and local_position.y < ceiling_bottom - ball_radius + 0.03
			leap_blocked = leap_blocked and (local_position.x > -6.55 if outward else local_position.x < -1.65)
	_check(roof_blocked, "Ceiling stops a fast upward-moving ball below its underside")
	_check(leap_blocked and _game.failure_count == 0, "Upward kicks cannot clear either an internal wall or the outside maze wall")
	_ball.request_reset()
	await _frames(90)
	var rapid_tilt_safe: bool = true
	var extremes := [Vector2(1, 1), Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1)]
	var corridor := PackedVector2Array([Vector2(-7.1, 1.9), Vector2(-4.1, 1.9), Vector2(-4.1, -4.9), Vector2(7.1, -4.9), Vector2(7.1, 2.9), Vector2(4.1, 2.9), Vector2(4.1, -1.9), Vector2(-1.1, -1.9), Vector2(-1.1, 4.9), Vector2(-7.1, 4.9)])
	for frame in range(360):
		source.set_sensor_axes(extremes[int(frame / 15) % extremes.size()])
		await physics_frame
		var local_position: Vector3 = _platform.to_local(_ball.global_position)
		# Moving kinematic contacts can have transient overlap; the ball must never clear a wall or leave the corridor.
		rapid_tilt_safe = rapid_tilt_safe and local_position.y - ball_radius < 0.9 and Geometry2D.is_point_in_polygon(Vector2(local_position.x, local_position.z), corridor)
	_check(rapid_tilt_safe and _game.failure_count == 0, "Rapid changes in both tilt axes cannot lift the ball over a wall or outside the corridor")
	source.set_sensor_axes(Vector2.ZERO)
	await _frames(130)
	# Preserve the existing off-platform failure/reset integration with the new spawn.
	_ball.global_position = Vector3(9, 1, 0)
	_ball.linear_velocity = Vector3(1, 0, 0)
	_ball.angular_velocity = Vector3(1, 2, 3)
	for frame in range(180):
		await physics_frame
		if _game.failure_count > 0:
			break
	_check(_game.failure_count == 1 and _reset_transform.origin.distance_to(_platform.to_global(_ball.spawn_local_position)) < 0.01, "Off-platform fall counts once and returns to the left spawn")
	_check(_reset_linear == Vector3.ZERO and _reset_angular == Vector3.ZERO and _reset_transform.basis.is_equal_approx(Basis.IDENTITY), "Fall reset clears speed, spin and orientation")
	await _frames(90)
	# Automated physical traversal: only normalized tilt input is supplied, never ball motion.
	var route_start: float = _game.elapsed_seconds
	var reached: int = 0
	for target in sample_points.slice(1):
		for frame in range(1800):
			await physics_frame
			if _game.goal_reached:
				break
			var at: Vector3 = _platform.to_local(_ball.global_position)
			var velocity: Vector3 = _platform.global_basis.inverse() * _ball.linear_velocity
			var error := Vector2(target.x - at.x, target.z - at.z)
			var speed := Vector2(velocity.x, velocity.z)
			if error.length() < 0.3 and speed.length() < 0.4:
				reached += 1
				break
			source.set_sensor_axes((error * 0.35 - speed * 0.7).clamp(Vector2.ONE * -0.65, Vector2.ONE * 0.65))
		if _game.goal_reached:
			break
	_check(reached >= 3 and _game.goal_reached and _game.failure_count == 1, "Real ball traverses all three turns and reaches Goal using tilt alone, without falls or teleports")
	print("[MAZE TEST] Automated traversal simulation time: %.1f seconds (not a human difficulty estimate)" % (_game.elapsed_seconds - route_start))
	await _frames(3)
	_check(_ball.freeze and not _platform.is_physics_processing() and _game.get_node("HUD/GameplayUI").success_menu.visible, "Existing Mission Success UI and control lock work after maze traversal")
	print("[MAZE TEST] Failures: ", _failures)
	quit(0 if _failures == 0 else 1)
