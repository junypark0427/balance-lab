extends SceneTree
## Real Jolt traversal: no teleports, impulses or velocity writes during the route.
## Fixture placement/reset checks are separate from the continuous start-to-goal run.
var failures: int = 0
var game: Node3D
var board
var ball: RigidBody3D
var source
var camera: Camera3D
var path: Array[Vector3] = []
var contacts: Dictionary = {}
var trace: FileAccess
var is_traversing: bool = false
var waypoint: int = 0
var trace_frames: int = 0
var route_start: float = 0
var max_height: float = 0
var gate_crossed: bool = false
var _key_state: Dictionary = {}

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	print("[LEVEL03] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in range(n): await physics_frame
func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await process_frame
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png("/tmp/balance-level03/" + label + ".png") == OK, "Screenshot " + label)
func key(code: Key, down: bool) -> void:
	if _key_state.get(code, false) == down: return
	_key_state[code] = down
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
func axes(value: Vector2) -> void:
	if "--keyboard" in OS.get_cmdline_user_args():
		# Pulse/release the four actual key events to regulate tilt, rather than
		# replacing keyboard axes with analog sensor data. Full press/release still
		# travels through InputMap -> TiltInput -> the unchanged platform controller.
		var actual: Vector2 = Vector2(-board.rotation_degrees.z, board.rotation_degrees.x) / board.max_tilt_degrees
		key(KEY_A, value.x < -0.002 and actual.x > value.x)
		key(KEY_D, value.x > 0.002 and actual.x < value.x)
		key(KEY_UP, value.y < -0.002 and actual.y > value.y)
		key(KEY_DOWN, value.y > 0.002 and actual.y < value.y)
	else:
		source.set_sensor_axes(value)
func physics_trace() -> void:
	if not is_traversing: return
	trace_frames += 1
	var at: Vector3 = board.to_local(ball.global_position)
	max_height = maxf(max_height, at.y)
	var state := PhysicsServer3D.body_get_direct_state(ball.get_rid())
	for i in range(state.get_contact_count()):
		if state.get_contact_collider(i) != board.get_rid(): continue
		var id: int = state.get_contact_collider_shape(i)
		var node: Object = board.shape_owner_get_owner(board.shape_find_owner(id))
		if node is Node:
			var name_: String = node.get_meta("source_object", node.name)
			contacts[name_] = int(contacts.get(name_, 0)) + 1
	if at.z < -7.2 and at.z > -9.4 and absf(at.x - 0.55) < 0.5 and at.y < 1.4: gate_crossed = true
	if trace_frames % 30 == 0:
		trace.store_csv_line(PackedStringArray([str(game.elapsed_seconds - route_start), str(waypoint), str(at.x), str(at.y), str(at.z), str(ball.linear_velocity.x), str(ball.linear_velocity.y), str(ball.linear_velocity.z), str(board.rotation_degrees.x), str(board.rotation_degrees.z)]))

func find_path() -> bool:
	var space := game.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = 0.66
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1
	var step: float = 0.4
	var begin := Vector2i(roundi(board.start_position.x / step), roundi(board.start_position.z / step))
	var finish := Vector2i(roundi(board.goal_position.x / step), roundi(board.goal_position.z / step))
	var half: Vector2 = board.floor_size * 0.5 - Vector2.ONE
	var queue: Array[Vector2i] = [begin]
	var previous: Dictionary = {begin: begin}
	var blocked: Dictionary = {}
	var index: int = 0
	while index < queue.size():
		var cell: Vector2i = queue[index]
		index += 1
		if cell == finish:
			var cells: Array[Vector2i] = [cell]
			while cell != begin:
				cell = previous[cell]
				cells.append(cell)
			cells.reverse()
			var anchor: int = 0
			while anchor < cells.size() - 1:
				var next: int = anchor + 1
				for candidate in range(anchor + 2, cells.size()):
					query.transform = Transform3D(Basis.IDENTITY, Vector3(cells[anchor].x * step, 1.0, cells[anchor].y * step))
					query.motion = Vector3(cells[candidate].x * step, 1.0, cells[candidate].y * step) - query.transform.origin
					if space.cast_motion(query)[0] < 0.999: break
					next = candidate
				path.append(Vector3(cells[next].x * step, 0.7, cells[next].y * step))
				anchor = next
			path.append(board.goal_position)
			return true
		for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			if previous.has(next) or blocked.has(next) or absf(next.x * step) > half.x or absf(next.y * step) > half.y: continue
			query.motion = Vector3.ZERO
			query.transform = Transform3D(Basis.IDENTITY, Vector3(next.x * step, 1.0, next.y * step))
			if space.intersect_shape(query, 1).is_empty():
				previous[next] = cell
				queue.append(next)
			else: blocked[next] = true
	return false

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/balance-level03")
	root.size = Vector2i(1280, 720)
	root.get_node("Session").diagnostics_enabled = false
	game = load("res://scenes/level_03.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	board = game.get_node("Platform")
	ball = game.get_node("Ball")
	source = game.get_node("TiltInput")
	camera = game.get_node("Camera3D")
	board.debug_logging = false
	source.debug_logging = false
	ball.contact_monitor = true
	ball.max_contacts_reported = 32
	source.use_sensor_input = "--keyboard" not in OS.get_cmdline_user_args()
	physics_frame.connect(physics_trace)
	check(board.floor_size == Vector2(22.1, 81.1), "Floor derives from the actual rectangular 201 x 791 OBJ")
	check(board.source_bounds.size.is_equal_approx(Vector3(201, 791, 61)), "Source bounds include the original below-floor goal plate")
	check(board.component_count == 21 and board.source_triangle_count == 2076 and board.proxy_count == 23, "All 21 original objects / 2076 triangles retained; gate alone split into three convex pieces")
	check(board.portal_clearance.is_equal_approx(Vector2(2.2006, 1.9003)), "Actual opening preserves width 2.2006 and height 1.9003 for a diameter-1 ball")
	var valid: bool = true
	for collider in get_nodes_in_group("level03_model_collisions"):
		valid = valid and collider.get_parent() == board and collider.shape is ConvexPolygonShape3D
	check(valid and not board.has_node("EscapeCeiling"), "All model proxies share the rotating body; no ceiling or internal guard extensions")
	check(not board.get_node("ImportedParts/obj_20").visible and board.get_node("GoalMarker").position.y - 0.01 > 0.2, "Only one raised green goal marker is visible; no coplanar green plate")
	var slalom_ok: bool = true
	for index in range(13, 20):
		var label: String = "obj_%d" % index
		var bounds: AABB = board.object_bounds[label]
		var original: AABB = board.original_object_bounds[label]
		slalom_ok = slalom_ok and bounds.size.is_equal_approx(original.size)
		var expected_z: float = board.pyramid_entry_z if index < 17 else board.pyramid_entry_z - board.pyramid_row_gap
		slalom_ok = slalom_ok and absf(bounds.get_center().z - expected_z) < 0.001
	check(slalom_ok, "Seven original pyramids form offset rows without changing their size or slopes")
	await frames(100)
	check(ball.position.distance_to(Vector3(-0.05, 0.8, 38.55)) < 0.1, "Ball settles at original cyan start marker")
	check(camera.is_current() and camera.get_parent() == game, "World-upright shared follow camera is active")
	await capture("start")
	var probe := SphereShape3D.new()
	probe.radius = 0.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = 1
	var no_straight_shortcut: bool = true
	for entry_x in [-board.pyramid_lane_spacing, 0.0, board.pyramid_lane_spacing]:
		query.transform.origin = Vector3(entry_x, 1.0, board.pyramid_entry_z + 3.0)
		query.motion = Vector3(0, 0, -board.pyramid_row_gap - 6.0)
		no_straight_shortcut = no_straight_shortcut and game.get_world_3d().direct_space_state.cast_motion(query)[0] < 0.999
	check(no_straight_shortcut, "Every first-row entry needs a lateral correction before the offset exit row")
	check(find_path(), "Ball-sized collision query finds a route through the real gate, not around the map edge")
	print("[LEVEL03] Route: ", path)
	if path.is_empty(): quit(1); return
	trace = FileAccess.open("/tmp/balance-level03/traversal.csv", FileAccess.WRITE)
	trace.store_csv_line(PackedStringArray(["seconds", "waypoint", "local_x", "local_y", "local_z", "vx", "vy", "vz", "tilt_x", "tilt_z"]))
	route_start = game.elapsed_seconds
	is_traversing = true
	var falls: int = game.failure_count
	var stuck: bool = false
	for i in range(path.size()):
		waypoint = i
		var target: Vector3 = path[i]
		var reached: bool = false
		for f in range(3600):
			await physics_frame
			if game.goal_reached: reached = true; break
			var at: Vector3 = board.to_local(ball.global_position)
			var velocity: Vector3 = board.global_basis.inverse() * ball.linear_velocity
			var error := Vector2(target.x - at.x, target.z - at.z)
			var speed := Vector2(velocity.x, velocity.z)
			if error.length() < 0.32 and speed.length() < 0.5: reached = true; break
			axes((error * 0.35 - speed * 0.75).clamp(Vector2.ONE * -0.65, Vector2.ONE * 0.65))
		if not reached:
			print("[LEVEL03] STUCK waypoint=", i, " target=", target, " actual=", board.to_local(ball.global_position), " velocity=", ball.linear_velocity)
			stuck = true
			break
		print("[LEVEL03] Reached waypoint ", i, " t=", game.elapsed_seconds - route_start, " at=", board.to_local(ball.global_position))
		if i in [1, 3, 5, 7, 9, 10, 11, 12]: await capture("section_%d" % i)
		if game.goal_reached: break
	axes(Vector2.ZERO)
	is_traversing = false
	trace.close()
	print("[LEVEL03] Contacts ", contacts, " peak_height=", max_height, " elapsed=", game.elapsed_seconds - route_start)
	check(not stuck and game.goal_reached and game.failure_count == falls, "Continuous real RigidBody traversal reaches Goal using tilt inputs only, without reset/teleport/velocity edits")
	check(gate_crossed, "Ball physically crosses beneath the gate lintel")
	await frames(40)
	check(game.get_node("HUD/GameplayUI").success_menu.visible and ball.freeze and not board.is_physics_processing(), "Mission success stops controls, ball and timer and shows results")
	await capture("success" if game.goal_reached else "failure")
	print("[LEVEL03] Failures: ", failures)
	quit(0 if failures == 0 else 1)
