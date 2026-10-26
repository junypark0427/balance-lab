extends "res://tests/level_03_obstacle_test.gd"
const OBJ = preload("res://scripts/maps/obj_geometry.gd")
var contact_pieces: Dictionary = {}
func record_contacts() -> void:
	super.record_contacts()
	var state := PhysicsServer3D.body_get_direct_state(ball.get_rid())
	for i in range(state.get_contact_count()):
		if state.get_contact_collider(i) != board.get_rid(): continue
		var index: int = state.get_contact_collider_shape(i)
		var node = board.shape_owner_get_owner(board.shape_find_owner(index))
		if node is Node and str(node.name).begins_with("obj_7_part0Proxy"): contact_pieces[node.name] = true
func check(ok: bool, label: String) -> void:
	print("[LEVEL04 GEOMETRY] %s %s" % ["PASS" if ok else "FAIL",label])
	if not ok: failures+=1
func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/balance-level04")
	root.size=Vector2i(1280,720)
	root.get_node("Session").diagnostics_enabled=false
	game=load("res://scenes/level_04.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	board=game.get_node("Platform")
	ball=game.get_node("Ball")
	source=game.get_node("TiltInput")
	board.debug_logging=false
	source.debug_logging=false
	source.use_sensor_input=true
	ball.contact_monitor=true
	ball.max_contacts_reported=32
	physics_frame.connect(record_contacts)
	ball.respawned.connect(observe_reset)
	await frames(100)
	var convex_only: bool=true
	for node in get_nodes_in_group("level04_model_collisions"):
		convex_only=convex_only and node.shape is ConvexPolygonShape3D and node.get_parent()==board
	check(convex_only,"All 78 model proxies are convex children of one moving platform")
	# Independently compare actual Jolt point occupancy against original top triangles.
	var caps: Array[PackedVector2Array]=[]
	for solid:Dictionary in OBJ.read_model(board.source_obj):
		var bounds:AABB=solid.bounds
		if bounds.position.z>5.5 or bounds.end.z<5.5:continue
		var faces:PackedVector3Array=solid.faces
		for i in range(0,faces.size(),3):
			if absf(faces[i].z-bounds.end.z)>0.001 or absf(faces[i+1].z-bounds.end.z)>0.001 or absf(faces[i+2].z-bounds.end.z)>0.001:continue
			var triangle:=PackedVector2Array()
			for j in range(3):triangle.append(Vector2(faces[i+j].x,faces[i+j].y))
			if OBJ.polygon_area(triangle)>0.00001:caps.append(triangle)
	var space:=game.get_world_3d().direct_space_state
	var point:=PhysicsPointQueryParameters3D.new()
	point.collision_mask=1
	var tested:int=0
	var mismatch:int=0
	for x in range(-80,81,2):
		for y in range(-80,81,2):
			var raw:=Vector2(x+0.037,y+0.071)
			var expected:bool=false
			for triangle in caps:
				if Geometry2D.is_point_in_polygon(raw,triangle):expected=true;break
			point.position=board.model_to_local(Vector3(raw.x,raw.y,5.5))
			var actual:bool=not space.intersect_point(point,1).is_empty()
			tested+=1
			if actual!=expected:
				mismatch+=1
				if mismatch<=3:print("[LEVEL04 GEOMETRY] Occupancy mismatch ",raw," expected=",expected)
	check(mismatch==0,"Original ring openings match Jolt occupancy at %d sampled points"%tested)
	var sphere:=SphereShape3D.new()
	sphere.radius=0.55
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=sphere
	query.collision_mask=1
	query.transform.origin=Vector3(board.start_position.x,1.03,13.6)
	query.motion=Vector3(3.3,0,0)
	check(space.cast_motion(query)[0]>0.999,"The C-shaped start exit stays open for the actual ball")
	var side_blocked:bool=true
	for side in [-1.0,1.0]:
		query.transform.origin=Vector3(side*8.2,1.03,5.5)
		query.motion=Vector3(0,0,-11)
		side_blocked=side_blocked and space.cast_motion(query)[0]<0.999
	check(side_blocked,"Neither perimeter side has a ball-width route outside the ring")
	# Test the actual inner and outer faces of the same curved wall.
	var visual:MeshInstance3D=board.get_node("ImportedParts/obj_7_part0")
	var faces:PackedVector3Array=visual.mesh.get_faces()
	var seam_start := Vector3.ZERO
	var seam_normal := Vector3.ZERO
	for outside in [true,false]:
		var selected:=Vector3.ZERO
		var normal:=Vector3.ZERO
		var score:float=INF
		for i in range(0,faces.size(),3):
			var n:Vector3=-(faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).normalized()
			if absf(n.y)>0.01:continue
			var center:Vector3=(faces[i]+faces[i+1]+faces[i+2])/3
			var radial:=Vector2(center.x+0.15,center.z+0.14).normalized()
			if (Vector2(n.x,n.z).dot(radial)>0)!=outside:continue
			var cost:float=absf(radial.x-radial.y)
			if cost<score:score=cost;selected=center;normal=n
		selected.y=0.76
		if outside: seam_start=selected; seam_normal=normal
		for impact_speed in [3.0,25.0]:
			place(selected+normal*1.1,-normal*impact_speed)
			var rebound:float=0
			var crossed:bool=false
			for i in range(100 if impact_speed<10 else 20):
				await physics_frame
				rebound=maxf(rebound,ball.linear_velocity.dot(normal))
				crossed=crossed or (ball.position-selected).dot(normal)<0.45
			check(seen.has("obj_7") and rebound>0.1 and not crossed,"Curved wall %s face collides at %.0fm/s without tunneling"%["outer" if outside else "inner",impact_speed])
	# Hold the actual ball against a curved wall while tilting tangentially across seams.
	place(seam_start + seam_normal * 0.56)
	contact_pieces.clear()
	var began: Vector3 = ball.position
	var peak_spin: float = 0
	for i in range(360):
		var at: Vector3 = board.to_local(ball.global_position)
		var radial := Vector2(at.x + 0.15, at.z + 0.14).normalized()
		var tangent := Vector2(-radial.y, radial.x)
		source.set_sensor_axes(-radial * 0.12 + tangent * 0.28)
		await physics_frame
		peak_spin = maxf(peak_spin, ball.angular_velocity.length())
	check(contact_pieces.size() >= 3 and board.to_local(ball.global_position).distance_to(began) > 1.0 and peak_spin > 0.5,"Tilt-only wall following crosses several convex seams without getting stuck")
	print("[LEVEL04 GEOMETRY] Seam contacts=",contact_pieces.size()," end=",board.to_local(ball.global_position)," spin=",peak_spin)
	source.set_sensor_axes(Vector2.ZERO)
	await frames(220)
	# Existing low diagonal bar at the goal side, where its source base is below floor.
	place(Vector3(3.8,0.76,10.5),Vector3(-25,0,0))
	await frames(30)
	check(seen.has("obj_0") or seen.has("obj_3"),"CCD catches a fast actual impact on the original start walls")
	ball.request_reset()
	source.set_sensor_axes(Vector2(1,-1))
	await frames(240)
	var actual:Transform3D=PhysicsServer3D.body_get_state(board.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM)
	check(board.rotation_degrees.x<-14.9 and board.rotation_degrees.z<-14.9 and actual.basis.is_equal_approx(board.global_basis),"Input reaches both 15-degree limits; floor and every proxy share the physics rotation")
	var camera:Camera3D=game.get_node("Camera3D")
	check(absf(camera.global_basis.x.y)<0.0001,"Follow camera stays world-upright during platform tilt")
	place(Vector3(20,-30,0),Vector3(3,-4,1))
	await frames(15)
	check(game.failure_count>0 and reset_at.distance_to(board.to_global(board.start_position))<0.001 and reset_linear==Vector3.ZERO and reset_angular==Vector3.ZERO,"Fall reset uses LEVEL04 spawn and zeroes both velocities")
	source.set_sensor_axes(Vector2.ZERO)
	await frames(250)
	ball.request_reset()
	await frames(100)
	check(board.rotation.length()<0.001 and camera.focus.z>10,"Neutral return and camera reset recover smoothly")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
		camera.set_process(false)
		camera.global_position=Vector3(0,40,18)
		camera.look_at(Vector3.ZERO)
		camera.size=36
		game.get_node("HUD").hide()
		for part in board.get_node("ImportedParts").get_children():
			part.transparency=0
			part.material_override.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/balance-level04/overview.png")
	print("[LEVEL04 GEOMETRY] Failures: ",failures)
	quit(0 if failures==0 else 1)
