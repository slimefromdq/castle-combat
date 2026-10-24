extends TestCase
## The map must be fair: point-symmetric, with nothing spawning inside a wall.


func test_walls_are_point_symmetric() -> void:
	var walls := MatchController.ARENA.walls
	for w in walls:
		var mirrored := ArenaData.mirror_rect(w)
		var found := false
		for other in walls:
			if other.position.is_equal_approx(mirrored.position) and other.size.is_equal_approx(mirrored.size):
				found = true
		check(found, "wall %s has no mirrored twin %s" % [w, mirrored])


func test_floors_and_pockets_are_point_symmetric() -> void:
	for list: Array[Rect2] in [MatchController.ARENA.floors, MatchController.ARENA.pockets]:
		for r in list:
			var m := ArenaData.mirror_rect(r)
			var found := false
			for other in list:
				if other.position.is_equal_approx(m.position) and other.size.is_equal_approx(m.size):
					found = true
			check(found, "rect %s has no mirrored twin" % r)


func test_structures_sit_on_the_lane_in_order() -> void:
	var a := MatchController.ARENA
	check(a.structure_positions.size() == 3, "expected outer, inner, core")
	for i in a.structure_positions.size():
		var p := a.structure_positions[i]
		check(absf(p.x) < a.lane_half_width, "structure %d is off the lane" % i)
		check(p.y < 0.0, "blue structure %d should be on blue's half" % i)
		if i > 0:
			check(p.y < a.structure_positions[i - 1].y, "tier %d should be behind tier %d" % [i, i - 1])


func test_spawns_are_clear() -> void:
	var sim := new_sim()
	for h in sim.heroes:
		check(not Movement.is_blocked(sim, h, h.pos), "hero %d spawns inside something" % h.team)


func test_pillars_block_line_of_sight_between_pocket_and_lane() -> void:
	var a := MatchController.ARENA
	check(not ArenaGeometry.has_line_of_sight(a, Vector2(-8, 0), Vector2(0, 0)), "left pillar should block sight")
	check(ArenaGeometry.has_line_of_sight(a, Vector2(-8, 4), Vector2(0, 4)), "pocket entrance should not block sight")
	check(ArenaGeometry.has_line_of_sight(a, Vector2(0, -20), Vector2(0, 20)), "lane should be open end to end")
