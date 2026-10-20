extends "res://scripts/platform_controller.gd"
## Geometry comes from the imported OBJ. Each disconnected solid becomes ONE convex proxy.
## All collision shapes are direct children of this existing moving platform body.
@export_range(0.01, 1.0, 0.01) var model_scale: float = 0.1
@export_range(0.5, 5.0, 0.1) var floor_margin: float = 1.0
@export_range(0.2, 2.0, 0.1) var floor_thickness: float = 0.4
@export_range(0.3, 4.0, 0.1) var outer_wall_height: float = 1.1
@export_range(0.15, 1.0, 0.05) var outer_wall_thickness: float = 0.4
@export_range(2.0, 8.0, 0.1) var escape_wall_height: float = 3.5
@export_range(0.05, 0.3, 0.01) var minimum_proxy_thickness: float = 0.12
@export var start_position: Vector3 = Vector3(-0.1562, 1.1, 18.4)
@export var goal_position: Vector3 = Vector3(2.6438, 0.8, -18.4)
var floor_size: Vector2
var source_bounds: AABB
var component_count: int = 0
var wall_proxy_count: int = 0
var _center: Vector3
var _base_y: float
var _source: MeshInstance3D
var _steel: StandardMaterial3D
var _cyan: StandardMaterial3D
var _orange: StandardMaterial3D

func _ready() -> void:
	_source = $TinkerModel
	source_bounds = _source.mesh.get_aabb()
	_center = source_bounds.get_center()
	_base_y = floor_thickness * 0.5
	floor_size = Vector2(ceilf((source_bounds.size.x * model_scale + floor_margin * 2) * 10 - 0.001) / 10, ceilf((source_bounds.size.y * model_scale + floor_margin * 2) * 10 - 0.001) / 10)
	$MeshInstance3D.mesh = $MeshInstance3D.mesh.duplicate()
	$MeshInstance3D.mesh.size = Vector3(floor_size.x, floor_thickness, floor_size.y)
	$CollisionShape3D.shape = $CollisionShape3D.shape.duplicate()
	$CollisionShape3D.shape.size = $MeshInstance3D.mesh.size
	_source.rotation_degrees = Vector3(-90, 0, 0)
	_source.scale = Vector3.ONE * model_scale
	_source.position = Vector3(-_center.x * model_scale, _base_y - source_bounds.position.z * model_scale, _center.y * model_scale)
	_steel = _material(Color("b2c5d6"), 0.65)
	_cyan = _material(Color("39c5ff"), 0.35, 0.5)
	_orange = _material(Color("c78042"), 0.6)
	_build_imported_parts()
	_build_perimeter()
	$Goal.position = goal_position
	$GoalMarker.position = Vector3(goal_position.x, _base_y + 0.115, goal_position.z)
	var ball = get_parent().get_node("Ball")
	ball.spawn_local_position = start_position
	ball.position = transform * start_position
	# A long board's low end can lie below the old -6 plane while still supporting the ball.
	ball.fall_height = -maxf(12.0, floor_size.length() * 0.5 * sin(deg_to_rad(max_tilt_degrees)) + 4.0)
	super._ready()

func _material(color: Color, metal: float, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = 0.38
	if glow > 0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material

func model_to_local(point: Vector3) -> Vector3:
	return Vector3((point.x - _center.x) * model_scale, _base_y + (point.z - source_bounds.position.z) * model_scale, -(point.y - _center.y) * model_scale)

func _find(parents: Array[int], index: int) -> int:
	while parents[index] != index:
		parents[index] = parents[parents[index]]
		index = parents[index]
	return index

func _build_imported_parts() -> void:
	var faces: PackedVector3Array = _source.mesh.get_faces()
	var ids: Dictionary = {}
	var vertices: Array[Vector3] = []
	var parents: Array[int] = []
	var triangles: Array[Vector3i] = []
	for offset in range(0, faces.size(), 3):
		var indices: Array[int] = []
		for corner in range(3):
			var point: Vector3 = faces[offset + corner]
			var key: Vector3 = point.snapped(Vector3.ONE * 0.001)
			if not ids.has(key):
				ids[key] = vertices.size()
				parents.append(vertices.size())
				vertices.append(point)
			indices.append(ids[key])
		parents[_find(parents, indices[1])] = _find(parents, indices[0])
		parents[_find(parents, indices[2])] = _find(parents, indices[0])
		triangles.append(Vector3i(indices[0], indices[1], indices[2]))
	var components: Dictionary = {}
	for index in range(vertices.size()):
		var root_id: int = _find(parents, index)
		if not components.has(root_id):
			components[root_id] = []
		components[root_id].append(index)
	var parts := Node3D.new()
	parts.name = "ImportedParts"
	add_child(parts)
	for root_id: int in components:
		var indices: Array = components[root_id]
		var bounds := AABB(vertices[indices[0]], Vector3.ZERO)
		var points := PackedVector3Array()
		for index: int in indices:
			bounds = bounds.expand(vertices[index])
			points.append(model_to_local(vertices[index]))
		var wall: bool = indices.size() == 8 and bounds.size.z > 2.0
		var marker: bool = bounds.size.z < 2.0
		var material: Material = _steel
		if marker:
			material = _cyan if bounds.get_center().y < 0 else _material(Color("38df80"), 0.25, 0.3)
		elif indices.size() > 8 and bounds.size.z <= 10.1:
			material = _orange
		# Render the exact imported triangles, separated only to fade individual occluders.
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_smooth_group(-1)
		for triangle in triangles:
			if _find(parents, triangle.x) == root_id:
				for index in [triangle.x, triangle.y, triangle.z]:
					surface.add_vertex(model_to_local(vertices[index]))
		surface.generate_normals()
		var visual := MeshInstance3D.new()
		visual.name = "OBJPart%02d" % component_count
		visual.mesh = surface.commit()
		visual.material_override = material
		visual.add_to_group("level02_visual_parts")
		parts.add_child(visual)
		if wall:
			points = _extend_wall(points)
			wall_proxy_count += 1
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		shape.margin = 0.002
		var collider := CollisionShape3D.new()
		collider.name = "OBJProxy%02d" % component_count
		collider.shape = shape
		collider.add_to_group("level02_model_collisions")
		collider.set_meta("source_bounds", bounds)
		collider.set_meta("vertical_guard", wall)
		add_child(collider)
		component_count += 1
	_source.hide()

func _extend_wall(points: PackedVector3Array) -> PackedVector3Array:
	# Increase the SAME solid vertically, never stack overlapping wall colliders or a ceiling.
	var center := Vector2.ZERO
	for p in points:
		center += Vector2(p.x, p.z)
	center /= points.size()
	var xx: float = 0
	var zz: float = 0
	var xz: float = 0
	for p in points:
		var d := Vector2(p.x, p.z) - center
		xx += d.x * d.x
		zz += d.y * d.y
		xz += d.x * d.y
	var angle: float = 0.5 * atan2(2 * xz, xx - zz)
	var normal := Vector2(-sin(angle), cos(angle))
	var low: float = INF
	var high: float = -INF
	for p in points:
		var projection: float = Vector2(p.x, p.z).dot(normal)
		low = minf(low, projection)
		high = maxf(high, projection)
	var inflation: float = maxf(0, minimum_proxy_thickness - (high - low)) * 0.5
	for index in range(points.size()):
		var p: Vector3 = points[index]
		var shift: Vector2 = normal * inflation * signf(Vector2(p.x, p.z).dot(normal) - (low + high) * 0.5)
		p.x += shift.x
		p.z += shift.y
		if p.y > _base_y + 0.01:
			p.y = maxf(p.y, _base_y + escape_wall_height)
		points[index] = p
	return points

func _box_visual(name_: String, size_: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name_
	var mesh := BoxMesh.new()
	mesh.size = size_
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	add_child(instance)
	return instance

func _build_perimeter() -> void:
	var collision_height: float = maxf(outer_wall_height, escape_wall_height)
	for side in [-1.0, 1.0]:
		for along_x in [true, false]:
			var span: float = floor_size.x if along_x else floor_size.y
			var size_ := Vector3(span, outer_wall_height, outer_wall_thickness) if along_x else Vector3(outer_wall_thickness, outer_wall_height, span)
			var at := Vector3(0, _base_y + outer_wall_height * 0.5, side * (floor_size.y - outer_wall_thickness) * 0.5) if along_x else Vector3(side * (floor_size.x - outer_wall_thickness) * 0.5, _base_y + outer_wall_height * 0.5, 0)
			var name_: String = ("End" if along_x else "Side") + ("Positive" if side > 0 else "Negative")
			var visual := _box_visual(name_, size_, at, _steel)
			visual.add_to_group("level02_visual_parts")
			var trim_size: Vector3 = size_
			trim_size.y = 0.035
			var trim_at: Vector3 = at
			trim_at.y = _base_y + outer_wall_height
			var trim := _box_visual(name_ + "Trim", trim_size, trim_at, _cyan)
			trim.add_to_group("level02_visual_parts")
			var collider := CollisionShape3D.new()
			collider.name = name_ + "Collision"
			var shape := BoxShape3D.new()
			shape.size = Vector3(size_.x, collision_height, size_.z)
			collider.shape = shape
			collider.position = Vector3(at.x, _base_y + collision_height * 0.5, at.z)
			collider.add_to_group("level02_perimeter_collisions")
			add_child(collider)
