extends SceneTree
## Imported geometry + Jolt + camera integration. Synthetic input is not a human keyboard test.
var _failures: int = 0
var _game: Node3D
var _platform: AnimatableBody3D
var _ball: RigidBody3D
var _camera: Camera3D
var _reset_transform: Transform3D
var _reset_linear: Vector3
var _reset_angular: Vector3
var _path: Array[Vector3] = []

func _initialize() -> void: call_deferred("_run")
func _check(condition: bool, label: String) -> void:
	print("[LEVEL02] %s %s" % ["PASS" if condition else "FAIL", label])
	if not condition: _failures += 1
func _frames(count: int) -> void:
	for frame in range(count): await physics_frame
func _capture(name_: String) -> void:
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		RenderingServer.force_draw()
		_check(root.get_texture().get_image().save_png("/tmp/balance-level02-" + name_ + ".png") == OK, "Capture " + name_)
func _reset_observed() -> void:
	var state := PhysicsServer3D.body_get_direct_state(_ball.get_rid())
	_reset_transform = state.transform
	_reset_linear = state.linear_velocity
	_reset_angular = state.angular_velocity
func _place(point: Vector3, velocity: Vector3 = Vector3.ZERO) -> void:
	_ball.global_transform = Transform3D(Basis.IDENTITY, _platform.to_global(point))
	_ball.linear_velocity = _platform.global_basis * velocity
	_ball.angular_velocity = Vector3.ZERO
	_ball.sleeping = false
func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _compare_restitution() -> void:
	var measured: Array[float] = []
	for improved in [false, true]:
		var fixture = load("res://scenes/main.tscn").instantiate()
		root.add_child(fixture)
		current_scene = fixture
		var body: RigidBody3D = fixture.get_node("Ball")
		var board = fixture.get_node("Platform")
		board.set_physics_process(false)
		board.debug_logging = false
		fixture.get_node("TiltInput").debug_logging = false
		if improved:
			var material: PhysicsMaterial = body.physics_material_override.duplicate()
			material.friction = 0.24
			material.bounce = 0.22
			body.physics_material_override = material
		await _frames(5)
		body.global_transform = Transform3D(Basis.IDENTITY, Vector3(-2.6, 0.7, 3.4))
		body.linear_velocity = Vector3(3, 0, 0)
		body.angular_velocity = Vector3(0, 0, -6)
		var incoming: float = 3
		var outgoing: float = 0
		var peak_height: float = 0
		for frame in range(70):
			await physics_frame
			peak_height = maxf(peak_height, body.position.y)
			if body.linear_velocity.x < -0.01:
				outgoing = -body.linear_velocity.x
				break
			incoming = body.linear_velocity.x
		measured.append(outgoing / incoming)
		_check(peak_height < 0.9, "Controlled grounded impact does not touch the old ceiling")
		print("[LEVEL02] Impact profile improved=", improved, " incoming=", incoming, " outgoing=", outgoing)
		root.remove_child(fixture)
		fixture.queue_free()
		await _frames(3)
	_check(measured[0] > 0.02 and measured[0] < 0.09 and measured[1] > 0.16 and measured[1] < 0.3, "Measured weak old restitution and moderate new restitution before tuning the level")

func _find_route(space: PhysicsDirectSpaceState3D) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1
	var step: float = 0.4
	var start := Vector2i(roundi(_platform.start_position.x / step), roundi(_platform.start_position.z / step))
	var finish := Vector2i(roundi(_platform.goal_position.x / step), roundi(_platform.goal_position.z / step))
	var half: Vector2 = _platform.floor_size * 0.5 - Vector2.ONE
	var queue: Array[Vector2i] = [start]
	var previous: Dictionary = {start: start}
	var blocked: Dictionary = {}
	var index: int = 0
	while index < queue.size():
		var cell: Vector2i = queue[index]
		index += 1
		if cell == finish:
			var cells: Array[Vector2i] = [cell]
			while cell != start:
				cell = previous[cell]
				cells.append(cell)
			cells.reverse()
			# Keep bends, then merge straight sections only when a swept sphere fits.
			var anchor: int = 0
			while anchor < cells.size() - 1:
				var next: int = anchor + 1
				for candidate in range(anchor + 2, cells.size()):
					var from_ := Vector3(cells[anchor].x * step, 1.15, cells[anchor].y * step)
					var to := Vector3(cells[candidate].x * step, 1.15, cells[candidate].y * step)
					query.transform = Transform3D(Basis.IDENTITY, from_)
					query.motion = to - from_
					var sweep: PackedFloat32Array = space.cast_motion(query)
					if sweep[0] < 0.999: break
					next = candidate
				_path.append(Vector3(cells[next].x * step, 0.7, cells[next].y * step))
				anchor = next
			_path.append(_platform.goal_position)
			return true
		for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			if previous.has(next) or blocked.has(next) or absf(next.x * step) > half.x or absf(next.y * step) > half.y:
				continue
			query.motion = Vector3.ZERO
			query.transform = Transform3D(Basis.IDENTITY, Vector3(next.x * step, 1.15, next.y * step))
			if space.intersect_shape(query, 1).is_empty():
				previous[next] = cell
				queue.append(next)
			else:
				blocked[next] = true
	return false

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var session = root.get_node("Session")
	session.diagnostics_enabled = false
	await _compare_restitution()
	_game = load("res://scenes/level_02.tscn").instantiate()
	root.add_child(_game)
	current_scene = _game
	_platform = _game.get_node("Platform")
	_ball = _game.get_node("Ball")
	_camera = _game.get_node("Camera3D")
	var source = _game.get_node("TiltInput")
	source.debug_logging = false
	_platform.debug_logging = false
	_ball.respawned.connect(_reset_observed)
	_check(_platform.get_node("TinkerModel").mesh.resource_path == "res://prototypes/tinkercad/Grand Fulffy/tinker.obj", "Original OBJ is referenced in place")
	_check(_platform.get_node("TinkerModel").scale.is_equal_approx(Vector3.ONE * 0.1), "OBJ uses uniform 0.1 scale with a Z-up to Y-up rotation")
	_check(_platform.floor_size == Vector2(20.6, 40.8), "Rectangular floor is derived from actual 185.898 x 388 model bounds plus margin")
	var total_triangles: int = 0
	var visual_bounds := AABB()
	var first: bool = true
	for part in _platform.get_node("ImportedParts").get_children():
		total_triangles += part.mesh.get_faces().size() / 3
		visual_bounds = part.get_aabb() if first else visual_bounds.merge(part.get_aabb())
		first = false
	_check(total_triangles == _platform.get_node("TinkerModel").mesh.get_faces().size() / 3 and visual_bounds.size.is_equal_approx(Vector3(18.5898, 3.9, 38.8)), "Every original OBJ triangle is retained with original proportions")
	_check(_platform.component_count == 19 and _platform.wall_proxy_count == 14, "Nineteen original solids have separate proxies; fourteen walls have vertical guards")
	var valid_colliders: bool = true
	var floor_contact: bool = true
	for shape in get_nodes_in_group("level02_model_collisions"):
		valid_colliders = valid_colliders and shape.get_parent() == _platform and shape.shape is ConvexPolygonShape3D
		var minimum: float = INF
		for point in shape.shape.points: minimum = minf(minimum, point.y)
		floor_contact = floor_contact and absf(minimum - 0.2) < 0.001
	_check(valid_colliders and floor_contact, "Convex proxies share the platform body and meet the floor exactly; no trimesh")
	_check(get_nodes_in_group("level02_perimeter_collisions").size() == 4 and not _platform.has_node("EscapeCeiling"), "Four perimeter guards and no horizontal ceiling")
	_check(is_equal_approx(_ball.physics_material_override.bounce, 0.22) and is_equal_approx(_ball.physics_material_override.friction, 0.24) and is_equal_approx(_ball.linear_damp, 0.05) and is_equal_approx(_ball.angular_damp, 0.1), "Level-specific modest restitution with unchanged light damping")
	await _frames(100)
	_check(_ball.position.distance_to(Vector3(_platform.start_position.x, 0.8, _platform.start_position.z)) < 0.08, "Ball settles on the original starting plate")
	_check(_ball.fall_height <= -12 and _camera.is_current(), "Long board has a safe fall plane and active follow camera")
	await _capture("follow")
	var initial_transform: Transform3D = _camera.global_transform
	_ball.freeze = true
	_key(KEY_D, true)
	_key(KEY_UP, true)
	await _frames(45)
	_check(source.get_tilt_axes() == Vector2(1, -1) and _platform.rotation_degrees.x < -1 and _platform.rotation_degrees.z < -1, "Existing simultaneous keyboard input tilts both axes")
	_key(KEY_D, false)
	_key(KEY_UP, false)
	await _frames(140)
	_check(_platform.rotation.length() < 0.001, "Release smoothly levels the board")
	# Camera follows translations smoothly and never adopts platform roll.
	_ball.global_position = Vector3(4, 0.8, 0)
	await _frames(1)
	_check(_camera.global_position.distance_to(initial_transform.origin) < 10, "Camera does not snap to a teleported ball")
	await _frames(120)
	_check(absf(_camera.focus.x - 4) < 0.15 and absf(_camera.focus.z + 2.4) < 0.15 and absf(_camera.global_basis.x.y) < 0.0001, "Smooth follow keeps world-up orientation and forward look-ahead")
	var screen_position: Vector2 = _camera.unproject_position(_ball.global_position)
	_check(screen_position.y > root.get_visible_rect().size.y * 0.5 and screen_position.y < root.get_visible_rect().size.y * 0.85, "Ball is framed below center")
	var column: MeshInstance3D
	for part in _platform.get_node("ImportedParts").get_children():
		if part.get_aabb().size.y > 3.5:
			column = part
			break
	var column_bounds: AABB = column.get_aabb()
	_ball.position = Vector3(column_bounds.get_center().x, 0.7, column_bounds.position.z - 0.7)
	await _frames(120)
	_check(column.transparency > 0.6, "Only an occluding imported solid fades to keep the ball visible")
	await _capture("occlusion")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		var frame: Image = root.get_texture().get_image()
		var point: Vector2 = _camera.unproject_position(_ball.global_position) * Vector2(frame.get_size()) / root.get_visible_rect().size
		var pixel: Color = frame.get_pixel(int(point.x), int(point.y))
		_check(pixel.r > pixel.b * 1.5 and pixel.g > pixel.b * 1.2, "Rendered orange ball remains visible through the faded column")
	_ball.global_position = Vector3(100, 0.8, -100)
	await _frames(120)
	_check(_camera.focus_bounds.grow(0.01).has_point(Vector2(_camera.focus.x, _camera.focus.z)), "Follow focus is clamped at map ends")
	_ball.freeze = false
	_ball.request_reset()
	await _frames(180)
	_check(_camera.focus.z > 15.5 and _ball.spawn_local_position == _platform.start_position, "Reset naturally returns the camera and ball to this map's start")
	var space := _game.get_world_3d().direct_space_state
	_check(_find_route(space), "A ball-sized collision-free route connects both model end plates")
	print("[LEVEL02] Planned route waypoints: ", _path)
	# CCD / restitution against an actual perimeter wall, at its clear end section.
	_place(Vector3(7.8, 0.7, 18.4), Vector3(8, 0, 0))
	var rebound: float = 0
	var crossed: bool = false
	for frame in range(60):
		await physics_frame
		rebound = minf(rebound, _ball.linear_velocity.x)
		crossed = crossed or _ball.position.x > 9.95
	_check(not crossed and rebound < -0.7 and rebound > -3.0, "Actual wall collision produces moderate rebound without tunneling")
	# Fire at a thin diagonal wall from the imported OBJ, rather than only testing the perimeter.
	var wall_center := Vector3(6.36935, 0.7, 5.5424)
	var wall_normal := Vector3(-sin(deg_to_rad(22.5)), 0, cos(deg_to_rad(22.5)))
	_place(wall_center + wall_normal * 2.0, -wall_normal * 25.0)
	var stayed_on_side: bool = true
	var convex_rebound: float = 0
	for frame in range(30):
		await physics_frame
		stayed_on_side = stayed_on_side and (_ball.position - wall_center).dot(wall_normal) > 0.4
		convex_rebound = maxf(convex_rebound, _ball.linear_velocity.dot(wall_normal))
	_check(stayed_on_side and convex_rebound > 2.0, "CCD catches a fast ball on an actual thin diagonal OBJ wall")
	_ball.request_reset()
	await _frames(90)
	# Verify reset on a tilted long board, then return to neutral before path traversal.
	source.use_sensor_input = true
	source.set_sensor_axes(Vector2(1, 1))
	await _frames(220)
	var physics_transform: Transform3D = PhysicsServer3D.body_get_state(_platform.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
	_check(absf(_platform.rotation_degrees.x) > 14.9 and physics_transform.basis.is_equal_approx(_platform.global_basis), "Floor and all compound proxies rotate together at the existing 15 degree limit")
	_check(_camera.global_basis.is_equal_approx(initial_transform.basis), "Camera orientation stays world-upright while the platform tilts")
	_place(Vector3(30, -25, 0), Vector3(4, -5, 3))
	for frame in range(30):
		await physics_frame
		if _game.failure_count > 0: break
	_check(_game.failure_count == 1 and _reset_transform.origin.distance_to(_platform.to_global(_platform.start_position)) < 0.001 and _reset_linear == Vector3.ZERO and _reset_angular == Vector3.ZERO, "Fall reset clears momentum at the LEVEL02 start, including while tilted")
	source.set_sensor_axes(Vector2.ZERO)
	await _frames(160)
	_ball.request_reset()
	await _frames(100)
	var stable: bool = true
	var extremes := [Vector2(0, 1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 1)]
	var peak_height: float = 0
	var falls_before_stress: int = _game.failure_count
	var previous_angles: Vector3 = _platform.rotation_degrees
	for frame in range(720):
		source.set_sensor_axes(extremes[int(frame / 90) % extremes.size()])
		await physics_frame
		var at: Vector3 = _platform.to_local(_ball.global_position)
		peak_height = maxf(peak_height, at.y)
		stable = stable and absf(at.x) < _platform.floor_size.x * 0.5 and absf(at.z) < _platform.floor_size.y * 0.5
		stable = stable and absf(_platform.rotation_degrees.x - previous_angles.x) < 8.0 / 60.0 + 0.001 and absf(_platform.rotation_degrees.z - previous_angles.z) < 8.0 / 60.0 + 0.001
		previous_angles = _platform.rotation_degrees
	_check(stable and _game.failure_count == falls_before_stress and peak_height < 3.5, "Rate-limited long platform does not launch the ball out during repeated full-input reversals")
	source.set_sensor_axes(Vector2.ZERO)
	await _frames(250)
	_ball.request_reset()
	await _frames(100)
	var before_falls: int = _game.failure_count
	var start_time: float = _game.elapsed_seconds
	var reached: int = 0
	for target in _path:
		for frame in range(1500):
			await physics_frame
			if _game.goal_reached: break
			var at: Vector3 = _platform.to_local(_ball.global_position)
			var velocity: Vector3 = _platform.global_basis.inverse() * _ball.linear_velocity
			var error := Vector2(target.x - at.x, target.z - at.z)
			var speed := Vector2(velocity.x, velocity.z)
			if error.length() < 0.32 and speed.length() < 0.5:
				reached += 1
				break
			source.set_sensor_axes((error * 0.35 - speed * 0.75).clamp(Vector2.ONE * -0.65, Vector2.ONE * 0.65))
		if _game.goal_reached: break
	_check(_game.goal_reached and _game.failure_count == before_falls, "Real ball reaches the opposite Goal through the OBJ using tilt only")
	print("[LEVEL02] Traversal ", _game.elapsed_seconds - start_time, "s; reached waypoints ", reached, "/", _path.size())
	await _frames(3)
	_check(_ball.freeze and not _platform.is_physics_processing() and _game.get_node("HUD/GameplayUI").success_menu.visible, "Existing mission success UI stops physics and controls")
	await _frames(30)
	await _capture("success")
	print("[LEVEL02] Failures: ", _failures)
	quit(0 if _failures == 0 else 1)
