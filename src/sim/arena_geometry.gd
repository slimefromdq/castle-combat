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


## Walls block sight; units never do. On the diamond map, so does leaving walkable
## ground (a line from the diamond's side to the lane behind its shoulder).
static func has_line_of_sight(arena: ArenaData, a: Vector2, b: Vector2) -> bool:
	for wall in arena.walls:
		if segment_hits_rect(a, b, wall):
			return false
	return segment_in_bounds(arena, a, b)


## True if every point on a-b is on walkable ground (sampled every half metre).
static func segment_in_bounds(arena: ArenaData, a: Vector2, b: Vector2, r := 0.0) -> bool:
	if not arena.has_diamond():
		return true
	# The lane strip and the diamond are each convex: a segment with both ends inside
	# one of them stays inside it.
	if arena.in_lane(a, r) and arena.in_lane(b, r):
		return true
	if arena.in_diamond(a, r) and arena.in_diamond(b, r):
		return true
	var steps := maxi(1, ceili(a.distance_to(b) / 0.5))
	for i in steps + 1:
		if not arena.in_bounds(a.lerp(b, float(i) / steps), r):
			return false
	return true


## Widest point of the map from the centre line, walls included.
static func half_width(arena: ArenaData) -> float:
	var w := maxf(arena.lane_half_width, arena.diamond_half_width)
	for r in arena.walls + arena.floors:
		w = maxf(w, maxf(absf(r.position.x), absf(r.end.x)))
	return w
