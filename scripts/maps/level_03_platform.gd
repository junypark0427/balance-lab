extends "res://scripts/maps/tinkercad_platform.gd"
## Preserve OBJ solids and MTL colors. Only the non-convex gate needs decomposition.
## No internal vertical guards: ramps, domes and the underpass remain traversable.
@export var source_obj: String = "res://prototypes/tinkercad/3rd map/Amazing Densor-Uusam/tinker.obj"
@export var portal_object: String = "obj_12"
## Reposition the existing seven pyramids; source meshes and slopes stay unchanged.
@export var pyramid_slalom_enabled: bool = true
@export_range(5.15, 5.6, 0.05) var pyramid_lane_spacing: float = 5.25
@export_range(5.0, 10.0, 0.1) var pyramid_row_gap: float = 6.2
@export var pyramid_entry_z: float = -18.0
@export_range(1.0, 1.4, 0.05) var pyramid_exit_spread: float = 1.3
var original_object_bounds: Dictionary = {}
var object_bounds: Dictionary = {}
var proxy_count: int = 0
var source_triangle_count: int = 0
var portal_clearance: Vector2

func _ready() -> void:
	super._ready()
	# The green plate extends below Z=0. Z=0, rather than the lowest marker,
	# is the common base of all walls. Keep that base flush with the floor.
	_source.position.y = _base_y
	# The original green plate's top is coplanar with the floor (z-fighting).
	# Keep its source geometry/collision, but render only the existing raised marker.
	var original_goal: MeshInstance3D = $ImportedParts/obj_20
	original_goal.hide()
	var marker: MeshInstance3D = $GoalMarker
	marker.mesh = marker.mesh.duplicate()
	var marker_size: Vector3 = object_bounds["obj_20"].size
	marker.mesh.size = Vector3(marker_size.x, 0.02, marker_size.z)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func model_to_local(point: Vector3) -> Vector3:
	return Vector3((point.x - _center.x) * model_scale, _base_y + point.z * model_scale, -(point.y - _center.y) * model_scale)

func _build_imported_parts() -> void:
	var vertices: Array[Vector3] = []
	var objects: Array[Dictionary] = []
	var object: Dictionary = {}
	for line in FileAccess.get_file_as_string(source_obj).split("\n"):
		var words: PackedStringArray = line.replace("\t", " ").split(" ", false)
		if words.is_empty(): continue
		match words[0]:
			"o":
				object = {"name": words[1], "faces": [], "material": ""}
				objects.append(object)
			"v": vertices.append(Vector3(float(words[1]), float(words[2]), float(words[3])))
			"usemtl": object.material = words[1]
			"f":
				# The supplied export is triangulated. Keep every face; convert OBJ
				# counterclockwise fronts to Godot clockwise fronts at rendering time.
				for i in range(2, words.size() - 1):
					object.faces.append(Vector3i(int(words[1].get_slice("/", 0)) - 1, int(words[i].get_slice("/", 0)) - 1, int(words[i + 1].get_slice("/", 0)) - 1))
	var colors: Dictionary = {}
	var material_name: String = ""
	for line in FileAccess.get_file_as_string(source_obj.get_base_dir().path_join("obj.mtl")).split("\n"):
		var words: PackedStringArray = line.split(" ", false)
		if words.is_empty(): continue
		if words[0] == "newmtl": material_name = words[1]
		elif words[0] == "Kd": colors[material_name] = Color(float(words[1]), float(words[2]), float(words[3]))
	var parts := Node3D.new()
	parts.name = "ImportedParts"
	add_child(parts)
	for data in objects:
		var first: Vector3i = data.faces[0]
		var raw_bounds := AABB(model_to_local(vertices[first.x]), Vector3.ZERO)
		for face: Vector3i in data.faces:
			for id in [face.x, face.y, face.z]:
				raw_bounds = raw_bounds.expand(model_to_local(vertices[id]))
		original_object_bounds[data.name] = raw_bounds
		var adjustment: Vector3 = _placement_offset(data.name, raw_bounds)
		var unique: Dictionary = {}
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_smooth_group(-1)
		for face: Vector3i in data.faces:
			# OBJ uses counterclockwise fronts; Godot requires clockwise fronts.
			# Retain even the export's zero-area triangles; they do not affect the hull.
			for id in [face.x, face.z, face.y]:
				var point: Vector3 = model_to_local(vertices[id]) + adjustment
				unique[point] = true
				surface.add_vertex(point)
			source_triangle_count += 1
		surface.generate_normals()
		var visual := MeshInstance3D.new()
		visual.name = data.name
		visual.mesh = surface.commit()
		visual.material_override = _material(colors.get(data.material, Color.WHITE), 0.35)
		visual.add_to_group("level02_visual_parts") # Shared follow-camera occlusion contract.
		parts.add_child(visual)
		object_bounds[data.name] = visual.get_aabb()
		var points := PackedVector3Array(unique.keys())
		if data.name == portal_object:
			_build_portal(data.name, points)
		else:
			# All other exported objects were checked against their triangle planes:
			# they are convex, including both cylinders, the dome and seven pyramids.
			_add_proxy(data.name, points)
		component_count += 1
	_source.hide()

func _add_proxy(label: String, points: PackedVector3Array) -> void:
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	shape.margin = 0.002
	var collider := CollisionShape3D.new()
	collider.name = label + "Collision"
	collider.shape = shape
	collider.set_meta("source_object", label.get_slice("_piece", 0))
	collider.add_to_group("level03_model_collisions")
	add_child(collider)
	proxy_count += 1

func _build_portal(label: String, points: PackedVector3Array) -> void:
	var xs: Array[float] = []
	var ys: Array[float] = []
	var bounds: AABB = object_bounds[label]
	for p in points:
		if not xs.has(p.x): xs.append(p.x)
		if not ys.has(p.y): ys.append(p.y)
	xs.sort()
	ys.sort()
	if xs.size() != 4 or ys.size() != 3:
		push_error("LEVEL03: gate geometry changed; rebuild its exact three convex pieces.")
		return
	portal_clearance = Vector2(xs[2] - xs[1], ys[1] - ys[0])
	# Two solid uprights and the actual thin lintel. They meet at faces only.
	var sections := [
		AABB(Vector3(xs[0], ys[0], bounds.position.z), Vector3(xs[1] - xs[0], bounds.size.y, bounds.size.z)),
		AABB(Vector3(xs[1], ys[1], bounds.position.z), Vector3(xs[2] - xs[1], ys[2] - ys[1], bounds.size.z)),
		AABB(Vector3(xs[2], ys[0], bounds.position.z), Vector3(xs[3] - xs[2], bounds.size.y, bounds.size.z))
	]
	for i in range(sections.size()):
		var corners := PackedVector3Array()
		for j in range(8): corners.append(sections[i].get_endpoint(j))
		_add_proxy(label + "_piece%d" % i, corners)

func _placement_offset(label: String, bounds: AABB) -> Vector3:
	if not pyramid_slalom_enabled: return Vector3.ZERO
	var index: int = label.trim_prefix("obj_").to_int() - 13
	if index < 0 or index > 6: return Vector3.ZERO
	var target: Vector2
	if index < 4:
		# Four pyramids make three precise entries: x=-spacing, 0, +spacing.
		target = Vector2((float(index) - 1.5) * pyramid_lane_spacing, pyramid_entry_z)
	else:
		# Offset exits require a sideways correction rather than a straight run.
		target = Vector2((float(index) - 5.0) * pyramid_lane_spacing * pyramid_exit_spread, pyramid_entry_z - pyramid_row_gap)
	return Vector3(target.x - bounds.get_center().x, 0, target.y - bounds.get_center().z)
