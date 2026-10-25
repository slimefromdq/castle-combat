class_name Movement
## Moves units on the plane: walls are solid boxes, structures are solid circles.
## No physics engine; units slide along whatever blocks them.


static func move_hero(sim: MatchSim, hero: HeroState, input: Vector2, dt: float) -> void:
	if not hero.alive:
		hero.moving = false
		return
	var v := input.limit_length(1.0)
	if v.length() < sim.config.move_dead_zone:
		hero.moving = false
		return
	hero.moving = true
	hero.still_since = sim.time
	hero.facing = v.normalized()
	hero.pos = slide(sim, hero, hero.pos, v * hero.move_speed() * dt)


## Tries the full step, then each axis alone, so walking into a wall at an angle slides
## along it. A blocked try is shortened until it just touches, so heroes reach walls flush.
static func slide(sim: MatchSim, mover: SimEntity, from: Vector2, delta: Vector2) -> Vector2:
	var tries: Array[Vector2] = [delta, Vector2(delta.x, 0.0), Vector2(0.0, delta.y)]
	for d in tries:
		if d.length_squared() < 0.0000001:
			continue
		var c := _push_out_of_circles(sim, mover, from + d)
		if not is_blocked(sim, mover, c):
			return c
	# Nothing fits whole: take the longest part of the full step that does.
	var lo := 0.0
	var hi := 1.0
	for i in 8:
		var mid := (lo + hi) * 0.5
		if is_blocked(sim, mover, from + delta * mid):
			hi = mid
		else:
			lo = mid
	return from + delta * lo


static func is_blocked(sim: MatchSim, mover: SimEntity, p: Vector2) -> bool:
	for wall in sim.arena.walls:
		if ArenaGeometry.circle_hits_rect(p, mover.radius, wall):
			return true
	for s in sim.structures:
		if s != mover and s.alive and s.blocks_movement and p.distance_to(s.pos) < s.radius + mover.radius - 0.001:
			return true
	return false


static func _push_out_of_circles(sim: MatchSim, mover: SimEntity, p: Vector2) -> Vector2:
	for s in sim.structures:
		if s == mover or not s.alive or not s.blocks_movement:
			continue
		var min_dist := s.radius + mover.radius
		var away := p - s.pos
		if away.length() < min_dist:
			if away.length() < 0.0001:
				away = Vector2.RIGHT
			p = s.pos + away.normalized() * min_dist
	return p
