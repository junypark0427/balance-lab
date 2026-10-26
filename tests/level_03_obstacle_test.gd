extends SceneTree
## Isolated contact experiments. Setup places a ball; these are NOT a route-clear claim.
var failures: int = 0
var game: Node3D
var board
var ball: RigidBody3D
var source
var seen: Dictionary = {}
var normal_y: float = 0
var reset_linear: Vector3
var reset_angular: Vector3
var reset_at: Vector3

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("[LEVEL03 FIXTURE] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in range(n): await physics_frame
func place(at: Vector3, velocity: Vector3 = Vector3.ZERO) -> void:
	ball.global_transform = Transform3D(Basis.IDENTITY, board.to_global(at))
	ball.linear_velocity = velocity
	ball.angular_velocity = Vector3.ZERO
	ball.sleeping = false
	seen.clear()
	normal_y = 0
func record_contacts() -> void:
	var state := PhysicsServer3D.body_get_direct_state(ball.get_rid())
	for i in range(state.get_contact_count()):
		if state.get_contact_collider(i) != board.get_rid(): continue
		var index: int = state.get_contact_collider_shape(i)
		var node = board.shape_owner_get_owner(board.shape_find_owner(index))
		if node is Node:
			seen[node.get_meta("source_object", node.name)] = true
			normal_y = maxf(normal_y, absf(state.get_contact_local_normal(i).y))
func observe_reset() -> void:
	var state := PhysicsServer3D.body_get_direct_state(ball.get_rid())
	reset_at = state.transform.origin
	reset_linear = state.linear_velocity
	reset_angular = state.angular_velocity
func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	var camera: Camera3D = game.get_node("Camera3D")
	camera.focus = camera._desired_focus()
	camera._place_camera()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/balance-level03/fixture_" + label + ".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/balance-level03")
	root.size = Vector2i(1280, 720)
	root.get_node("Session").diagnostics_enabled = false
	game = load("res://scenes/level_03.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	board = game.get_node("Platform")
	ball = game.get_node("Ball")
	source = game.get_node("TiltInput")
	board.debug_logging = false
	source.debug_logging = false
	source.use_sensor_input = true
	ball.contact_monitor = true
	ball.max_contacts_reported = 32
	physics_frame.connect(record_contacts)
	ball.respawned.connect(observe_reset)
	await frames(10)
	# Verify exact convexity from the visible original triangles, not color labels.
	var all_convex: bool = true
	var fronts_outward: bool = true
	for visual in board.get_node("ImportedParts").get_children():
		if visual.name == "obj_12": continue
		var faces: PackedVector3Array = visual.mesh.get_faces()
		for f in range(0, faces.size(), 3):
			var cross_: Vector3 = (faces[f + 1] - faces[f]).cross(faces[f + 2] - faces[f])
			# The two source cylinders contain 192 zero-area cap triangles.
			# They have no front/back or reliable generated normal, so exclude them.
			if cross_.length() < 0.000001: continue
			var n: Vector3 = cross_.normalized()
			var center: Vector3 = (faces[f] + faces[f + 1] + faces[f + 2]) / 3
			fronts_outward = fronts_outward and (-n).dot(center - visual.get_aabb().get_center()) >= -0.001
			var low: float = INF
			var high: float = -INF
			for p in faces:
				var d: float = n.dot(p - faces[f])
				low = minf(low, d)
				high = maxf(high, d)
			if low < -0.0003 and high > 0.0003: all_convex = false
	check(fronts_outward, "Non-degenerate render triangles face outward in Godot clockwise convention")
	check(all_convex, "Every unsplit source solid is actually convex; convex proxies preserve domes/cylinders/pyramids")
	for label in ["obj_7", "obj_8"]:
		var bounds: AABB = board.object_bounds[label]
		var at := Vector3(bounds.end.x + 1.3, 0.7, bounds.get_center().z - 0.2)
		place(at, Vector3(-3, 0, -0.8))
		var rebound: float = 0
		var peak: float = 0
		for i in range(130):
			await physics_frame
			rebound = maxf(rebound, ball.linear_velocity.x)
			peak = maxf(peak, ball.position.y)
		check(seen.has(label) and rebound > 0.1 and peak < 1.2, label + " actual curved side contact rebounds, redirects and stays grounded")
		print("[LEVEL03 FIXTURE] ", label, " rebound=", rebound, " peak_y=", peak, " at=", ball.position)
	# Dome and pyramid fixtures start just outside a real sloping triangle.
	# Gravity must produce a downhill roll/slide, never an invisible rectangular ledge.
	for label in ["obj_11", "obj_13", "obj_14", "obj_15", "obj_16", "obj_17", "obj_18", "obj_19"]:
		var visual: MeshInstance3D = board.get_node("ImportedParts/" + label)
		var faces: PackedVector3Array = visual.mesh.get_faces()
		var point := Vector3.ZERO
		var best: float = INF
		var normal := Vector3.UP
		var bounds: AABB = visual.get_aabb()
		for f in range(0, faces.size(), 3):
			var center: Vector3 = (faces[f] + faces[f + 1] + faces[f + 2]) / 3
			var n: Vector3 = (faces[f + 1] - faces[f]).cross(faces[f + 2] - faces[f]).normalized()
			if n.y < 0: n = -n
			if n.y < 0.2 or n.y > 0.85 or center.y < bounds.size.y * 0.25: continue
			var score: float = absf(center.y - bounds.size.y * 0.5)
			if score < best:
				best = score
				point = center + n * 0.52
				normal = n
		check(best < INF, label + " has an actual inclined source face")
		place(point)
		await frames(10)
		await capture(label + "_slope")
		var start_height: float = ball.position.y
		var peak_angular: float = 0
		for i in range(180):
			await physics_frame
			peak_angular = maxf(peak_angular, ball.angular_velocity.length())
		check(seen.has(label) and ball.position.y < start_height - 0.5 and peak_angular > 0.5, label + " actual slope contact descends and rotates without sticking")
		print("[LEVEL03 FIXTURE] ", label, " start=", point, " face_normal=", normal, " end=", ball.position, " angular_peak=", peak_angular)
	# High-speed impacts on an original straight and diagonal wall.
	for label in ["obj_0", "obj_2"]:
		var faces: PackedVector3Array = board.get_node("ImportedParts/" + label).mesh.get_faces()
		var area: float = 0
		var center := Vector3.ZERO
		var normal := Vector3.ZERO
		var bounds: AABB = board.object_bounds[label]
		for f in range(0, faces.size(), 3):
			var cross_: Vector3 = (faces[f + 1] - faces[f]).cross(faces[f + 2] - faces[f])
			var n: Vector3 = cross_.normalized()
			if absf(n.y) > 0.01 or cross_.length() <= area: continue
			area = cross_.length()
			center = (faces[f] + faces[f + 1] + faces[f + 2]) / 3
			normal = n if n.dot(center - bounds.get_center()) > 0 else -n
		center.y = 0.7
		place(center + normal * 2.0, -normal * 25.0)
		var stayed_on_side: bool = true
		var rebound: float = 0
		for i in range(30):
			await physics_frame
			stayed_on_side = stayed_on_side and (ball.position - center).dot(normal) > 0.45
			rebound = maxf(rebound, ball.linear_velocity.dot(normal))
		check(seen.has(label) and stayed_on_side and rebound > 1.0, label + " CCD stops a 25m/s impact on the actual thin wall")
	# Gate collision queries check both open passage and the solid lintel.
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1
	query.transform.origin = Vector3(0.55, 0.9, -6.0)
	query.motion = Vector3(0, 0, -4.0)
	var space := game.get_world_3d().direct_space_state
	check(space.cast_motion(query)[0] > 0.999, "Ball-sized sweep passes under the original gate")
	query.transform.origin.y = 2.2
	check(space.cast_motion(query)[0] < 0.999, "The original thin lintel still collides above the opening")
	# Input, shared body transforms, reset and camera behavior under the long board tilt.
	ball.request_reset()
	source.set_sensor_axes(Vector2(1, -1))
	await frames(300)
	check(board.rotation_degrees.x < -14.8 and board.rotation_degrees.z < -14.8, "Both unchanged cooperative axes reach the 15-degree limit")
	var transform_: Transform3D = PhysicsServer3D.body_get_state(board.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
	check(transform_.basis.is_equal_approx(board.global_basis), "All floor, gate and obstacle proxies share the same moving body transform")
	var camera: Camera3D = game.get_node("Camera3D")
	check(absf(camera.global_basis.x.y) < 0.0001 and camera.focus_bounds.grow(0.05).has_point(Vector2(camera.focus.x, camera.focus.z)), "Camera stays world-upright and its focus remains inside map bounds")
	place(Vector3(0, -40, 0), Vector3(3, -4, 2))
	await frames(15)
	check(game.failure_count > 0 and reset_at.distance_to(board.to_global(board.start_position)) < 0.001 and reset_linear == Vector3.ZERO and reset_angular == Vector3.ZERO, "Fall resets at this tilted map's start and clears both velocities")
	source.set_sensor_axes(Vector2.ZERO)
	await frames(320)
	ball.request_reset()
	await frames(100)
	check(board.rotation.length() < 0.001 and camera.focus.z > 34, "Neutral return and smooth camera return work after respawn")
	await capture("reset")
	var stable: bool = true
	var peak_height: float = 0
	var falls_before: int = game.failure_count
	var extremes := [Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1)]
	for frame in range(960):
		source.set_sensor_axes(extremes[int(frame / 120) % extremes.size()])
		await physics_frame
		var at: Vector3 = board.to_local(ball.global_position)
		peak_height = maxf(peak_height, at.y)
		stable = stable and absf(at.x) < board.floor_size.x * 0.5 and absf(at.z) < board.floor_size.y * 0.5
	check(stable and game.failure_count == falls_before, "Repeated full-input reversals keep the ball within the board in this stress run")
	print("[LEVEL03 FIXTURE] Reversal stress peak local height=", peak_height)
	source.set_sensor_axes(Vector2.ZERO)
	await frames(320)
	if "--capture" in OS.get_cmdline_user_args():
		# Inspect the final green surface without triggering Mission Success.
		var goal_at: Vector3 = board.to_global(board.goal_position)
		camera.set_process(false)
		camera.global_position = goal_at + Vector3(0, 8, 7)
		camera.look_at(goal_at)
		camera.size = 8
		game.get_node("HUD").hide()
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/balance-level03/goal_surface.png")
		# A diagnostic overview, separate from the normal tracking camera framing.
		root.size = Vector2i(900, 1500)
		game.get_node("HUD").hide()
		camera.set_process(false)
		camera.global_position = Vector3(0, 100, 35)
		camera.look_at(Vector3.ZERO)
		camera.size = 100
		for part in board.get_node("ImportedParts").get_children():
			part.transparency = 0
			part.material_override.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/balance-level03/overview.png")
	print("[LEVEL03 FIXTURE] Failures: ", failures)
	quit(0 if failures == 0 else 1)
