extends TestCase
## Movement: speed, dead zone, walls, structures and seat-relative input.


func test_hero_moves_at_its_speed() -> void:
	var sim := new_sim()
	var hero := sim.heroes[0]
	hero.pos = Vector2(2.5, -8.0)
	var start := hero.pos
	run_ticks(sim, 30, MatchSim.BLUE_FORWARD)
	check_near(hero.pos.distance_to(start), hero.data.move_speed, 0.01, "one second of movement")
	check(hero.moving, "flagged as moving")


func test_small_input_counts_as_standing_still() -> void:
	var sim := new_sim()
	var hero := sim.heroes[0]
	var start := hero.pos
	run_ticks(sim, 10, Vector2(0.1, 0))
	check(hero.pos == start, "inside dead zone should not move")
	check(not hero.moving, "not flagged as moving")


func test_releasing_input_stops_the_hero() -> void:
	var sim := new_sim()
	var hero := sim.heroes[0]
	run_ticks(sim, 5, Vector2.RIGHT)
	run_ticks(sim, 1)
	check(not hero.moving, "stopped on the first tick without input")


func test_lane_walls_stop_the_hero() -> void:
	var sim := new_sim()
	var hero := sim.heroes[0]
	hero.pos = Vector2(0, -40)  # Behind the diamond, where the lane has walls.
	run_ticks(sim, 120, Vector2.LEFT)
	check_near(hero.pos.x, -sim.arena.lane_half_width + hero.radius, 0.05, "rests against the left lane wall")


func test_hero_slides_along_a_wall_at_an_angle() -> void:
	var sim := new_sim()
	var hero := sim.heroes[0]
	hero.pos = Vector2(-4.4, -20)
	var y0 := hero.pos.y
	run_ticks(sim, 30, Vector2(-1, 1).normalized())
	check(hero.pos.y > y0 + 1.0, "kept moving along the wall")


func test_hero_cannot_walk_through_a_structure() -> void:
	var sim := new_sim()
	var hero := sim.heroes[0]
	var tower := sim.structures_of(MatchSim.BLUE)[0]
	hero.pos = tower.pos + Vector2(0, -4)
	var start_y := hero.pos.y
	run_ticks(sim, 90, MatchSim.BLUE_FORWARD)
	check(hero.pos.y > start_y + 1.0, "walked toward the tower")
	check(hero.pos.distance_to(tower.pos) >= tower.radius + hero.radius - 0.01, "never overlaps the tower")


func test_hero_can_enter_a_pocket() -> void:
	var sim := new_sim()
	var hero := sim.heroes[0]
	hero.pos = Vector2(-3, -4)
	run_ticks(sim, 60, Vector2.LEFT)
	check(hero.pos.x < -6.0, "walked through the lower pocket entrance (x=%.2f)" % hero.pos.x)


func test_red_seat_input_is_rotated() -> void:
	# Screen "up" arrives as +y from Input.get_vector; it means "toward the enemy".
	var up := Vector2(0, 1)
	check(LocalPlayerSource.screen_to_sim(up, MatchSim.BLUE) == MatchSim.forward(MatchSim.BLUE), "blue: screen up = toward red")
	check(LocalPlayerSource.screen_to_sim(up, MatchSim.RED) == MatchSim.forward(MatchSim.RED), "red: screen up = toward blue")
	check(LocalPlayerSource.screen_to_sim(Vector2.RIGHT, MatchSim.RED) == Vector2.LEFT, "red: left and right flip too")
