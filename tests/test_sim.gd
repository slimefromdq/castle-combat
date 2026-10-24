extends TestCase
## Match setup and the fixed tick.


func test_setup_creates_two_heroes_and_six_structures() -> void:
	var sim := new_sim()
	check(sim.heroes.size() == 2, "two heroes")
	check(sim.structures.size() == 6, "three structures per team")
	check(sim.entities.size() == 8, "all units registered by id")
	check(sim.heroes[0].team == MatchSim.BLUE and sim.heroes[1].team == MatchSim.RED, "hero teams")


func test_red_side_is_blue_side_rotated() -> void:
	var sim := new_sim()
	check(sim.heroes[1].pos.is_equal_approx(-sim.heroes[0].pos), "red spawn mirrors blue")
	var blue := sim.structures_of(MatchSim.BLUE)
	var red := sim.structures_of(MatchSim.RED)
	for i in 3:
		check(red[i].pos.is_equal_approx(-blue[i].pos), "structure tier %d mirrors" % i)


func test_only_outer_towers_start_exposed() -> void:
	var sim := new_sim()
	for s in sim.structures:
		check(sim.is_exposed(s) == (s.tier == 0), "tier %d exposure at start" % s.tier)


func test_structures_unlock_in_order() -> void:
	var sim := new_sim()
	var red := sim.structures_of(MatchSim.RED)
	red[0].alive = false
	check(sim.is_exposed(red[1]), "inner exposed after outer falls")
	check(not sim.is_exposed(red[2]), "core still locked while inner stands")
	red[1].alive = false
	check(sim.is_exposed(red[2]), "core exposed after both towers fall")
	check(not sim.is_exposed(sim.structures_of(MatchSim.BLUE)[1]), "blue unaffected")


func test_fixed_tick_counts_time() -> void:
	var sim := new_sim()
	run_ticks(sim, MatchController.CONFIG.tick_rate)
	check(sim.tick == MatchController.CONFIG.tick_rate, "tick count")
	check_near(sim.time, 1.0, 0.0001, "30 ticks = 1 second")
