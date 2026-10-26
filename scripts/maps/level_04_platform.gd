extends "res://scripts/maps/tinkercad_platform.gd"
const OBJ = preload("res://scripts/maps/obj_geometry.gd")
@export var source_obj: String = "res://prototypes/tinkercad/tinker.obj"
## Independent margins: keep the C-shaped exit open, but prevent outer-ring bypasses.
@export var floor_edge_margin: Vector2 = Vector2(0, 0.6)
var solid_count: int = 0
var ring_solid_count: int = 0
var ring_proxy_count: int = 0
var source_triangle_count: int = 0
var proxy_count: int = 0
var ring_polygons: Array[PackedVector2Array] = []
var object_bounds: Dictionary = {}

func model_to_local(point: Vector3) -> Vector3:
	return Vector3((point.x - _center.x) * model_scale, _base_y + point.z * model_scale, -(point.y - _center.y) * model_scale)

func _ready() -> void:
	super._ready()
	_source.position.y = _base_y
	# The original round green disc is above the floor. Do not overlay a square marker.
	$GoalMarker.hide()

func _build_perimeter() -> void:
	floor_size = (Vector2(source_bounds.size.x, source_bounds.size.y) * model_scale + floor_edge_margin * 2).snapped(Vector2.ONE * 0.1)
	floor_size.x = ceilf((source_bounds.size.x * model_scale + floor_edge_margin.x * 2) * 10) / 10
	$MeshInstance3D.mesh.size = Vector3(floor_size.x, floor_thickness, floor_size.y)
	$CollisionShape3D.shape.size = $MeshInstance3D.mesh.size
	super._build_perimeter()

func _build_imported_parts() -> void:
	var parts := Node3D.new()
	parts.name = "ImportedParts"
	add_child(parts)
	var solids: Array[Dictionary] = OBJ.read_model(source_obj)
	var crossbar_edge: float = -INF
	for candidate in solids:
		if candidate.object == "obj_0": crossbar_edge = candidate.bounds.position.y
	for solid: Dictionary in solids:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_smooth_group(-1)
		var faces: PackedVector3Array = solid.faces
		for i in range(0, faces.size(), 3):
			for j in [0, 2, 1]: surface.add_vertex(model_to_local(faces[i + j]))
		surface.generate_normals()
		var visual := MeshInstance3D.new()
		visual.name = solid.name
		visual.mesh = surface.commit()
		visual.material_override = _material(solid.color, 0.35)
		visual.add_to_group("level02_visual_parts")
		parts.add_child(visual)
		object_bounds[solid.name] = visual.get_aabb()
		source_triangle_count += faces.size() / 3
		if solid.object == "obj_7": ring_solid_count += 1
		if OBJ.is_convex(faces, solid.points):
			var points := PackedVector3Array()
			for raw: Vector3 in solid.points:
				var point: Vector3 = raw
				# The source C consists of overlapping boxes at its two corners.
				# Trim only their hidden overlap; the union and opening are identical.
				if solid.object in ["obj_2", "obj_3"] and crossbar_edge > -INF:
					point.y = minf(point.y, crossbar_edge)
				points.append(model_to_local(point))
			_add_proxy(solid, points)
		else:
			var bounds: AABB = solid.bounds
			var polygons: Array[PackedVector2Array] = OBJ.extrusion_polygons(faces, bounds.end.z)
			for polygon in polygons:
				var points := PackedVector3Array()
				var local_polygon := PackedVector2Array()
				for point in polygon:
					var at: Vector3 = model_to_local(Vector3(point.x, point.y, bounds.position.z))
					local_polygon.append(Vector2(at.x, at.z))
					points.append(at)
					points.append(model_to_local(Vector3(point.x, point.y, bounds.end.z)))
				ring_polygons.append(local_polygon)
				_add_proxy(solid, points)
				ring_proxy_count += 1
		solid_count += 1
	component_count = solid_count
	_source.hide()

func _add_proxy(solid: Dictionary, points: PackedVector3Array) -> void:
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	shape.margin = 0.001
	var collider := CollisionShape3D.new()
	collider.name = solid.name + "Proxy%d" % proxy_count
	collider.shape = shape
	collider.set_meta("source_object", solid.object)
	collider.set_meta("source_solid", solid.name)
	collider.add_to_group("level04_model_collisions")
	add_child(collider)
	proxy_count += 1
