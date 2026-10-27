extends SceneTree
## ICE regression: actual shader pixels and HUD overlay order, without USB hardware.
const PATHS := ["res://scenes/main.tscn", "res://scenes/level_02.tscn", "res://scenes/level_03.tscn", "res://scenes/level_04.tscn"]
var failures: int = 0
var passes: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	print("[ICE REGRESSION] ", "PASS " if ok else "FAIL ", description)
	if ok:
		passes += 1
	else:
		failures += 1

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame

func clear_scene() -> void:
	paused = false
	if current_scene != null:
		var old: Node = current_scene
		current_scene = null
		old.queue_free()
	await frames()

func make_level(path: String, icy: bool) -> Node:
	await clear_scene()
	root.get_node("Session").ice_mode_enabled = icy
	var game: Node = load(path).instantiate()
	game.get_node("Platform").debug_logging = false
	game.get_node("TiltInput").debug_logging = false
	root.add_child(game)
	current_scene = game
	await frames()
	return game

func shader_pixels(material: ShaderMaterial) -> void:
	if DisplayServer.get_name() == "headless":
		print("[ICE REGRESSION] SKIP shader pixels: run with a graphics renderer")
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 128)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.8
	viewport.add_child(world)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = BoxMesh.new()
	floor_mesh.mesh.size = Vector3(4, 0.2, 4)
	floor_mesh.material_override = material
	viewport.add_child(floor_mesh)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -20, 0)
	light.light_energy = 0.5
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.0
	camera.position = Vector3(0, 6, 3)
	viewport.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.make_current()
	await RenderingServer.frame_post_draw
	await frames()
	RenderingServer.force_draw()
	var pixel: Color = viewport.get_texture().get_image().get_pixel(64, 64)
	check(pixel.b > pixel.r * 1.25 and pixel.g > pixel.r * 1.15, "Shader renders blue ice instead of the white fallback: " + str(pixel))
	viewport.queue_free()
	await frames()

func run() -> void:
	var session: Node = root.get_node("Session")
	session.diagnostics_enabled = false
	session.reduced_motion = true
	session.fullscreen_enabled = false
	session.apply_fullscreen()
	root.size = Vector2i(1280, 720)
	for path: String in PATHS:
		var game: Node = await make_level(path, true)
		var hud: Control = game.get_node("HUD/GameplayUI")
		var badge: Control = hud.get_node("IceModeBadge")
		check(badge.get_index() < hud.pause_menu.get_index(), path + " ICE badge is behind PauseMenu")
		check(badge.get_index() < hud.success_menu.get_index(), path + " ICE badge is behind Mission Success")
		hud.set_paused(true)
		await frames()
		check(paused and hud.pause_menu.visible, path + " pause still works")
		hud.set_paused(false)
		var material: ShaderMaterial = game.get_node("Platform/MeshInstance3D").material_override
		if path == PATHS[0]:
			await shader_pixels(material)
		var ball: RigidBody3D = game.get_node("Ball")
		check(is_equal_approx(ball.physics_material_override.friction, 0.02) and is_equal_approx(ball.linear_damp, 0.012), path + " ICE physics unchanged by visual fixes")
		game = await make_level(path, false)
		check(game.find_child("IceModeBadge", true, false) == null and game.get_node("Platform/MeshInstance3D").material_override == null, path + " normal mode has no ICE override")
		ball = game.get_node("Ball")
		check(is_equal_approx(ball.linear_damp, 0.05) and is_equal_approx(ball.angular_damp, 0.1), path + " normal damping preserved")
	await clear_scene()
	print("[ICE REGRESSION] RESULTS: %d passed, %d failed" % [passes, failures])
	quit(1 if failures else 0)
