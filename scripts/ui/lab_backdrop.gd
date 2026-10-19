extends Node3D
## Original lab set made entirely from Godot primitives. Decorative, no physics.
@export var display_board: bool = true
@export var own_camera: bool = true
var _demo_ball: MeshInstance3D
var _clock: float = 0.0
var _orange: StandardMaterial3D
var _blue: StandardMaterial3D

func _material(color: Color, metal: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.28 if metal > 0.5 else 0.65
	if emission > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m

func _mesh(mesh: Mesh, position: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	if parent == null:
		parent = self
	parent.add_child(instance)
	instance.position = position
	return instance

func _box(size: Vector3, at: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(mesh, at, material, parent)

func _ring(at: Vector3, radius: float, thickness: float, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 80
	mesh.ring_segments = 12
	return _mesh(mesh, at, material, parent)

func _ready() -> void:
	var steel := _material(Color("23384a"), 0.85)
	var dark := _material(Color("0b1827"), 0.65)
	var ceramic := _material(Color("c4d0dc"), 0.35)
	var floor_mat := _material(Color("112235"), 0.75)
	_orange = _material(Color("ff6326"), 0.35, 1.8)
	_blue = _material(Color("39c5ff"), 0.3, 2.0)
	var seam := _material(Color("264659"), 0.4, 0.3)
	_box(Vector3(65, 0.2, 65), Vector3(0, -2.4, 0), floor_mat)
	for i in range(-12, 13):
		_box(Vector3(0.025, 0.01, 50), Vector3(i * 2.0, -2.29, 0), seam)
		_box(Vector3(50, 0.01, 0.025), Vector3(0, -2.29, i * 2.0), seam)
	if not own_camera and not display_board:
		for side in [-1.0, 1.0]:
			_box(Vector3(25, 0.08, 0.10), Vector3(0, -2.1, side * 12), _blue)
			_box(Vector3(0.10, 0.08, 25), Vector3(side * 12, -2.1, 0), _orange)
			for z in [-6.0, 6.0]:
				_box(Vector3(1.3, 2.0, 1.3), Vector3(side * 6, -1.3, z), steel)
		return
	# Structural ribs and illuminated strips define the room, rather than a flat background.
	for side in [-1.0, 1.0]:
		for depth in [-8.0, -1.0, 6.0]:
			_box(Vector3(0.65, 12, 0.7), Vector3(side * 12, 3.7, depth), steel)
			_box(Vector3(0.1, 5.4, 0.12), Vector3(side * 11.63, 4.7, depth + 0.4), _blue)
			_box(Vector3(1.0, 0.24, 1.2), Vector3(side * 12, -1.7, depth), dark)
		_box(Vector3(0.35, 0.35, 26), Vector3(side * 11.5, 9.1, 0), steel)
		_box(Vector3(0.10, 0.06, 25), Vector3(side * 11.3, 8.88, 0), _orange)
		_box(Vector3(0.2, 0.8, 22), Vector3(side * 13, -1.2, 0), steel)
		_box(Vector3(0.12, 0.09, 22), Vector3(side * 12.8, -0.75, 0), _orange)
		# Frosted observation panels and console desks.
		var glass := _material(Color(0.08, 0.2, 0.32, 0.22), 0.3)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var pane := _box(Vector3(5.4, 5.0, 0.09), Vector3(side * 10.3, 3.3, -6.2), glass)
		pane.rotation_degrees.y = side * -23
		_box(Vector3(4.3, 0.6, 1.5), Vector3(side * 10, -0.2, -5), ceramic)
		_box(Vector3(3.8, 0.04, 0.05), Vector3(side * 10, 0.12, -4.23), _orange)
		var screen := _box(Vector3(2.3, 1.3, 0.10), Vector3(side * 10, 1.0, -5.4), _blue)
		screen.rotation_degrees.x = -12
	_box(Vector3(26, 0.7, 0.5), Vector3(0, 9.7, -7), steel)
	_box(Vector3(26, 0.08, 0.09), Vector3(0, 9.3, -6.7), _orange)
	_ring(Vector3(0, 10.4, -0.5), 8.5, 0.25, steel)
	_ring(Vector3(0, 10.1, -0.5), 8.1, 0.055, _orange)
	_ring(Vector3(0, 10.05, -0.5), 7.6, 0.025, _blue)
	# Quiet starfield behind the observation window.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.035
	star_mesh.height = 0.07
	for index in range(100):
		_mesh(star_mesh, Vector3(rng.randf_range(-35, 35), rng.randf_range(-2, 17), -23), _blue)
	if display_board:
		_create_board(dark, ceramic, steel)
	if own_camera:
		var camera := Camera3D.new()
		add_child(camera)
		camera.position = Vector3(0, 9.5, 19)
		camera.look_at(Vector3(0, 3.5, 0))
		camera.fov = 57
		camera.current = true
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color("061020")
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color("6694bd")
		environment.ambient_light_energy = 0.48
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment.glow_enabled = true
		environment.glow_intensity = 0.65
		environment.ssr_enabled = true
		var sky := Sky.new()
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color("102d51")
		sky_material.sky_horizon_color = Color("81a4bc")
		sky_material.ground_horizon_color = Color("785643")
		sky_material.ground_bottom_color = Color("0c1827")
		sky.sky_material = sky_material
		environment.sky = sky
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		environment.fog_enabled = true
		environment.fog_light_color = Color("102a45")
		environment.fog_density = 0.007
		var world := WorldEnvironment.new()
		world.environment = environment
		add_child(world)
		var key := DirectionalLight3D.new()
		add_child(key)
		key.rotation_degrees = Vector3(-48, -25, 0)
		key.light_color = Color("b6d5ff")
		key.light_energy = 1.8
		key.shadow_enabled = true
		key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		key.directional_shadow_max_distance = 35
		key.shadow_blur = 2.0
		for side in [-1, 1]:
			var light := OmniLight3D.new()
			add_child(light)
			light.position = Vector3(side * 7, 4, 4)
			light.light_color = Color("ff8c47") if side < 0 else Color("4dafff")
			light.light_energy = 5
			light.omni_range = 18

func _create_board(dark: Material, ceramic: Material, steel: Material) -> void:
	var board := Node3D.new()
	add_child(board)
	board.position = Vector3(0, -0.3, 4)
	board.rotation_degrees.y = -8
	_box(Vector3(21, 0.7, 11.5), Vector3.ZERO, dark, board)
	_box(Vector3(20.4, 0.18, 11), Vector3(0, 0.44, 0), ceramic, board)
	for side in [-1.0, 1.0]:
		_box(Vector3(20.8, 0.12, 0.09), Vector3(0, 0.05, side * 5.75), _blue, board)
		_box(Vector3(0.09, 0.12, 11.3), Vector3(side * 10.45, 0.05, 0), _orange, board)
		_box(Vector3(20, 0.8, 0.3), Vector3(0, 0.9, side * 5.4), ceramic, board)
		_box(Vector3(0.3, 0.8, 10.8), Vector3(side * 10.1, 0.9, 0), ceramic, board)
	# Abstract exhibition maze; it is deliberately separate from the playable map.
	for wall in [Vector4(-6, -3, 4, 0), Vector4(-1, -3, 0, 3), Vector4(4, -3, 6, 0), Vector4(-7, 0, 0, 3), Vector4(-3, 1, 5, 0), Vector4(2, 0, 0, 4), Vector4(6, 0, 4, 0), Vector4(-6, 3, 5, 0), Vector4(-1, 3, 0, 3), Vector4(5, 3, 5, 0)]:
		var size := Vector3(maxf(wall.z, 0.3), 0.9, maxf(wall.w, 0.3))
		_box(size, Vector3(wall.x, 0.95, wall.y), ceramic, board)
		_box(Vector3(size.x, 0.06, size.z + 0.03), Vector3(wall.x, 0.58, wall.y), _orange, board)
	for x in [-8, -4, 0, 4, 8]:
		_box(Vector3(1.5, 1.4, 1.8), Vector3(x, -0.9, 0), steel, board)
	_ring(Vector3(6.7, 0.58, 3.2), 0.9, 0.045, _blue, board)
	_ring(Vector3(6.7, 1.6, 3.2), 0.72, 0.025, _blue, board)
	var beam := _material(Color(0.12, 0.75, 1, 0.08), 0, 1.5)
	beam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.7
	cylinder.bottom_radius = 0.9
	cylinder.height = 2.5
	_mesh(cylinder, Vector3(6.7, 1.8, 3.2), beam, board)
	var sphere := SphereMesh.new()
	sphere.radius = 0.65
	sphere.height = 1.3
	_demo_ball = _mesh(sphere, Vector3(-4, 1.2, 3.7), _material(Color("b7cde4"), 0.94), board)
	_ring(Vector3(-4, 0.58, 3.7), 0.85, 0.018, _orange, board)

func _process(delta: float) -> void:
	if not is_instance_valid(_demo_ball) or Session.reduced_motion:
		return
	_clock += delta
	_demo_ball.position.x = -4.0 + sin(_clock * 0.32) * 1.3
	_demo_ball.rotation.z = -_demo_ball.position.x / 0.65
