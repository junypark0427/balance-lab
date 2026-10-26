extends "res://tests/level_03_test.gd"
const ROUTE = preload("res://tests/physics_route.gd")
var min_radius: float = INF
var exited_start: bool = false
var entered_rings: bool = false
var exited_rings: bool = false
var local_clearance: float = INF
var peak_speed: float = 0

func check(ok: bool, label: String) -> void:
	print("[LEVEL04] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok: failures += 1
func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await process_frame
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png("/tmp/balance-level04/" + label + ".png") == OK, "Screenshot " + label)
func physics_trace() -> void:
	if not is_traversing: return
	trace_frames += 1
	var at: Vector3 = board.to_local(ball.global_position)
	max_height = maxf(max_height, at.y)
	peak_speed = maxf(peak_speed, ball.linear_velocity.length())
	var radial: float = Vector2(at.x + 0.15, at.z + 0.14).length()
	min_radius = minf(min_radius, radial)
	if at.z < 10.3: exited_start = true
	if radial < 6.8: entered_rings = true
	if entered_rings and at.z < -8.8: exited_rings = true
	var state := PhysicsServer3D.body_get_direct_state(ball.get_rid())
	for i in range(state.get_contact_count()):
		if state.get_contact_collider(i) != board.get_rid(): continue
		var id: int = state.get_contact_collider_shape(i)
		var node: Object = board.shape_owner_get_owner(board.shape_find_owner(id))
		if node is Node:
			var label: String = node.get_meta("source_solid", node.name)
			contacts[label] = int(contacts.get(label, 0)) + 1
	# Record EVERY physical frame; position and velocity are observations, never writes.
	trace.store_csv_line(PackedStringArray([str(trace_frames),str(game.elapsed_seconds - route_start),str(waypoint),str(at.x),str(at.y),str(at.z),str(ball.linear_velocity.x),str(ball.linear_velocity.y),str(ball.linear_velocity.z),str(board.rotation_degrees.x),str(board.rotation_degrees.z)]))

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/balance-level04")
	root.size = Vector2i(1280,720)
	root.get_node("Session").diagnostics_enabled = false
	game = load("res://scenes/level_04.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	board = game.get_node("Platform")
	ball = game.get_node("Ball")
	source = game.get_node("TiltInput")
	camera = game.get_node("Camera3D")
	board.debug_logging = false
	source.debug_logging = false
	source.use_sensor_input = "--keyboard" not in OS.get_cmdline_user_args()
	ball.contact_monitor = true
	ball.max_contacts_reported = 32
	physics_frame.connect(physics_trace)
	print("[LEVEL04] floor=",board.floor_size," solids=",board.solid_count," ring solids=",board.ring_solid_count," ring pieces=",board.ring_proxy_count," total proxies=",board.proxy_count)
	check(board.source_triangle_count == 1460 and board.solid_count == 17 and board.ring_solid_count == 8,"All original triangles and eight separated central solids retained")
	check(board.ring_proxy_count > 7 and not board.has_node("EscapeCeiling"),"Curved ring walls decomposed without concave/trimesh or a ceiling")
	check(is_equal_approx(ball.get_node("CollisionShape3D").shape.radius,0.55),"LEVEL04-only ball radius 0.55, equivalent to 5.5 source units at scale 0.1")
	await frames(100)
	check(ball.position.distance_to(Vector3(board.start_position.x,0.95,13)) < 0.12,"Ball settles on the original round blue start disc")
	await capture("start")
	var space := game.get_world_3d().direct_space_state
	var half: Vector2 = board.floor_size*0.5-Vector2.ONE*0.98
	if "--inner" in OS.get_cmdline_user_args():
		# Deliberately exercise the preserved inner passages, not a teleport.
		var checkpoint := Vector3(-0.15, 1.03, 2.1)
		path = ROUTE.plan(space,board.start_position,checkpoint,half)
		var onward: Array[Vector3] = ROUTE.plan(space,checkpoint,board.goal_position,half)
		if onward.is_empty(): path.clear()
		else: path.append_array(onward)
	else:
		path = ROUTE.plan(space,board.start_position,board.goal_position,half)
	check(not path.is_empty(),"Ball-sized static route exists with the actual floor, wall and ring proxies")
	print("[LEVEL04] Path=",path)
	if path.is_empty(): quit(1);return
	trace = FileAccess.open("/tmp/balance-level04/traversal.csv",FileAccess.WRITE)
	trace.store_csv_line(PackedStringArray(["frame","seconds","waypoint","local_x","local_y","local_z","vx","vy","vz","tilt_x","tilt_z"]))
	route_start = game.elapsed_seconds
	is_traversing = true
	var falls: int = game.failure_count
	var stuck: bool = false
	for i in range(path.size()):
		waypoint=i
		var reached: bool = false
		for f in range(3600):
			await physics_frame
			if game.goal_reached:reached=true;break
			var at: Vector3=board.to_local(ball.global_position)
			var velocity: Vector3=board.global_basis.inverse()*ball.linear_velocity
			var error := Vector2(path[i].x-at.x,path[i].z-at.z)
			var speed := Vector2(velocity.x,velocity.z)
			if error.length()<0.2 and speed.length()<0.35:reached=true;break
			axes((error*0.3-speed*0.9).clamp(Vector2.ONE* -0.5,Vector2.ONE*0.5))
		if not reached:
			print("[LEVEL04] STUCK waypoint=",i," target=",path[i]," actual=",board.to_local(ball.global_position)," speed=",ball.linear_velocity)
			stuck=true;break
		print("[LEVEL04] Reached ",i," t=",game.elapsed_seconds-route_start," local=",board.to_local(ball.global_position))
		if i % 3 == 0:await capture("section_%02d"%i)
		if game.goal_reached:break
	axes(Vector2.ZERO)
	is_traversing=false
	trace.close()
	print("[LEVEL04] contacts=",contacts," min radius=",min_radius," peak local height=",max_height," elapsed=",game.elapsed_seconds-route_start)
	check(not stuck and game.goal_reached and game.failure_count==falls,"Actual RigidBody reaches Goal continuously using tilt inputs only")
	if "--inner" in OS.get_cmdline_user_args(): check(min_radius < 2.5,"Actual ball traverses the inner circular corridor as well as the outer annulus")
	check(exited_start and entered_rings and exited_rings,"Ball physically exits C walls, enters the ring region and exits toward Goal")
	await frames(40)
	check(ball.freeze and not board.is_physics_processing() and game.get_node("HUD/GameplayUI").success_menu.visible,"Mission Success stops physics and displays the final result")
	await capture("success" if game.goal_reached else "failure")
	print("[LEVEL04] Failures: ",failures)
	quit(0 if failures==0 else 1)
