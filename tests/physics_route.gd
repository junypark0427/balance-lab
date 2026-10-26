extends RefCounted
## Static queries plan targets only. A separate controller must physically traverse them.
static func plan(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, half: Vector2, radius: float = 0.6, step: float = 0.2, center_height: float = 1.03) -> Array[Vector3]:
	var path: Array[Vector3] = []
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1
	var begin := Vector2i(roundi(from.x / step), roundi(from.z / step))
	var finish := Vector2i(roundi(to.x / step), roundi(to.z / step))
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
					query.transform.origin = Vector3(cells[anchor].x * step, center_height, cells[anchor].y * step)
					query.motion = Vector3(cells[candidate].x * step, center_height, cells[candidate].y * step) - query.transform.origin
					if space.cast_motion(query)[0] < 0.999: break
					next = candidate
				path.append(Vector3(cells[next].x * step, center_height, cells[next].y * step))
				anchor = next
			path.append(to)
			return path
		for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			if previous.has(next) or blocked.has(next) or absf(next.x * step) > half.x or absf(next.y * step) > half.y: continue
			query.motion = Vector3.ZERO
			query.transform.origin = Vector3(next.x * step, center_height, next.y * step)
			if space.intersect_shape(query, 1).is_empty():
				# Node clearance alone cannot catch thin walls between samples.
				query.transform.origin = Vector3(cell.x * step, center_height, cell.y * step)
				query.motion = Vector3(direction.x * step, 0, direction.y * step)
				if space.cast_motion(query)[0] < 0.999:
					continue
				previous[next] = cell
				queue.append(next)
			else: blocked[next] = true
	return path
