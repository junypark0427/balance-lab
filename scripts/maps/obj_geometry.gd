extends RefCounted
## Read OBJ solids without changing the source. Convex extrusion pieces preserve holes.
static var _models: Dictionary = {}

static func read_model(path: String) -> Array[Dictionary]:
	if _models.has(path): return _models[path]
	var vertices: Array[Vector3] = []
	var objects: Array[Dictionary] = []
	var current: Dictionary = {}
	var material_path: String = ""
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var w: PackedStringArray = line.replace("\t", " ").split(" ", false)
		if w.is_empty(): continue
		match w[0]:
			"mtllib": material_path = path.get_base_dir().path_join(w[1])
			"o":
				current = {"name": w[1], "faces": [], "material": ""}
				objects.append(current)
			"v": vertices.append(Vector3(float(w[1]), float(w[2]), float(w[3])))
			"usemtl": current.material = w[1]
			"f":
				for i in range(2, w.size() - 1):
					current.faces.append(Vector3i(int(w[1].get_slice("/", 0)) - 1, int(w[i].get_slice("/", 0)) - 1, int(w[i + 1].get_slice("/", 0)) - 1))
	var colors: Dictionary = {}
	var key: String = ""
	for line in FileAccess.get_file_as_string(material_path).split("\n"):
		var w: PackedStringArray = line.split(" ", false)
		if w.is_empty(): continue
		if w[0] == "newmtl": key = w[1]
		elif w[0] == "Kd": colors[key] = Color(float(w[1]), float(w[2]), float(w[3]))
	var solids: Array[Dictionary] = []
	for object in objects:
		var parents: Dictionary = {}
		for face: Vector3i in object.faces:
			for id in [face.x, face.y, face.z]:
				if not parents.has(id): parents[id] = id
			parents[_root(parents, face.y)] = _root(parents, face.x)
			parents[_root(parents, face.z)] = _root(parents, face.x)
		var split: Dictionary = {}
		for face: Vector3i in object.faces:
			var root: int = _root(parents, face.x)
			if not split.has(root): split[root] = PackedVector3Array()
			for id in [face.x, face.y, face.z]: split[root].append(vertices[id])
		var part: int = 0
		for triangles: PackedVector3Array in split.values():
			var unique: Dictionary = {}
			for point in triangles: unique[point] = true
			var bounds := AABB(triangles[0], Vector3.ZERO)
			for point in unique: bounds = bounds.expand(point)
			solids.append({"name": object.name + "_part%d" % part, "object": object.name, "faces": triangles, "points": PackedVector3Array(unique.keys()), "bounds": bounds, "color": colors[object.material]})
			part += 1
	_models[path] = solids
	return solids

static func _root(parents: Dictionary, index: int) -> int:
	while parents[index] != index:
		parents[index] = parents[parents[index]]
		index = parents[index]
	return index

static func is_convex(faces: PackedVector3Array, points: PackedVector3Array) -> bool:
	for i in range(0, faces.size(), 3):
		var cross_: Vector3 = (faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i])
		if cross_.length() < 0.000001: continue
		var n: Vector3 = cross_.normalized()
		var low: float = INF
		var high: float = -INF
		for point in points:
			var d: float = n.dot(point - faces[i])
			low = minf(low, d)
			high = maxf(high, d)
		if low < -0.002 and high > 0.002: return false
	return true

static func polygon_area(polygon: PackedVector2Array) -> float:
	var area: float = 0
	for i in range(polygon.size()): area += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return absf(area) * 0.5

static func extrusion_polygons(faces: PackedVector3Array, top: float) -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	for i in range(0, faces.size(), 3):
		if absf(faces[i].z - top) > 0.001 or absf(faces[i + 1].z - top) > 0.001 or absf(faces[i + 2].z - top) > 0.001: continue
		var triangle := PackedVector2Array()
		for j in range(3): triangle.append(Vector2(faces[i + j].x, faces[i + j].y))
		if polygon_area(triangle) > 0.000001: polygons.append(triangle)
	# Merge adjacent triangles only if their convex hull adds NO area.
	# Thus a ring opening or a concave arc can never be filled by a larger hull.
	var changed: bool = true
	while changed:
		changed = false
		for i in range(polygons.size()):
			for j in range(i + 1, polygons.size()):
				var shared: int = 0
				for a in polygons[i]:
					for b in polygons[j]:
						if a.distance_squared_to(b) < 0.0000001: shared += 1
				if shared < 2: continue
				var combined: PackedVector2Array = polygons[i].duplicate()
				combined.append_array(polygons[j])
				var hull: PackedVector2Array = Geometry2D.convex_hull(combined)
				if hull.size() > 1 and hull[0].is_equal_approx(hull[-1]): hull.remove_at(hull.size() - 1)
				var total: float = polygon_area(polygons[i]) + polygon_area(polygons[j])
				if absf(polygon_area(hull) - total) > maxf(0.0001, total * 0.000001): continue
				polygons[i] = hull
				polygons.remove_at(j)
				changed = true
				break
			if changed: break
	return polygons
