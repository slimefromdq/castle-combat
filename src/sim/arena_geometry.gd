class_name ArenaGeometry
## Small geometry helpers for circles, segments and axis-aligned walls.


static func circle_hits_rect(center: Vector2, r: float, rect: Rect2) -> bool:
	var closest := Vector2(
		clampf(center.x, rect.position.x, rect.end.x),
		clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_squared_to(closest) < r * r


static func segment_hits_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var p := rect.position
	var q := rect.end
	var corners: Array[Vector2] = [p, Vector2(q.x, p.y), q, Vector2(p.x, q.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null:
			return true
	return false


## Walls block sight; units never do.
static func has_line_of_sight(arena: ArenaData, a: Vector2, b: Vector2) -> bool:
	for wall in arena.walls:
		if segment_hits_rect(a, b, wall):
			return false
	return true
