extends TestCase
## Phase 2 (diamond rework, part 3): the switch and the long Relay.


func _cfg() -> MatchConfig:
	return MatchController.CONFIG


func _at(sim: MatchSim, t: float) -> void:
	sim.tick = int(round(t / sim.dt))
	sim.time = sim.tick * sim.dt


func _ticks(seconds: float, sim: MatchSim) -> int:
	return int(ceil(seconds / sim.dt))


func _events(sim: MatchSim, type: StringName) -> Array:
	var got: Array = []
	sim.sim_event.connect(func(t: StringName, d: Dictionary) -> void:
		if t == type:
			got.append(d)
	)
	return got


# ------------------------------------------------------------------ the switch

func test_phase_two_starts_on_the_clock() -> void:
	var sim := new_sim()
	var got := _events(sim, &"phase_two")
	run_ticks(sim, 2)
	check(sim.phase == 1, "phase 1 at the start")
	_at(sim, _cfg().phase_two_time - 0.5)
	run_ticks(sim, 1)
	check(sim.phase == 1, "still phase 1 just before %d s" % int(_cfg().phase_two_time))
	run_ticks(sim, _ticks(1.0, sim))
	check(sim.phase == 2 and got.size() == 1, "phase 2 at %d s" % int(_cfg().phase_two_time))
	run_ticks(sim, 5)
	check(got.size() == 1, "announced once")


func test_phase_two_starts_when_the_first_tower_falls() -> void:
	var sim := new_sim()
	var got := _events(sim, &"phase_two")
	var tower := sim.structures_of(MatchSim.RED)[0]
	tower.hp = 0.0
	tower.alive = false
	run_ticks(sim, 1)
	check(sim.phase == 2, "a fallen Outer Tower starts phase 2 early")
	check(got.size() == 1 and got[0].tower, "the event says a tower did it")


# ------------------------------------------------------------------ long Relay

func _carrying(sim: MatchSim) -> void:
	sim.relay.next_spawn_time = sim.time
	run_ticks(sim, 1)
	place(sim.heroes[0], sim.relay.origin)
	place(sim.heroes[1], Vector2(0, 44))
	run_ticks(sim, _ticks(_cfg().relay_pickup_time, sim) + 1)


func test_long_drop_sits_deep_in_the_enemy_half() -> void:
	var a := MatchController.ARENA
	var sim := new_sim()
	sim.phase = 2
	for team in [MatchSim.BLUE, MatchSim.RED]:
		var r := sim.relay.long_rect(sim, team)
		var c := MatchSim.to_team_space(team, r.get_center())
		check(c.y > absf(a.structure_positions[0].y), "team %d's drop is past the enemy Outer Tower" % team)
		for corner in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]:
			check(a.in_bounds(corner, 0.3), "corner %s is on walkable ground" % corner)
		for w in a.walls:
			check(not w.intersects(r), "clear of walls")
	check(sim.relay.long_rect(sim, 0).get_center().is_equal_approx(-sim.relay.long_rect(sim, 1).get_center()), "mirrored")


func test_long_drop_is_closed_in_phase_one() -> void:
	var sim := new_sim()
	_carrying(sim)
	check(sim.heroes[0].carrying_relay, "carrying")
	check(not sim.relay.long_rect(sim, MatchSim.BLUE).has_area(), "no long drop yet")
	sim.phase = 2
	check(sim.relay.long_rect(sim, MatchSim.BLUE).has_area(), "open in phase 2")


func test_long_delivery_pays_more_and_adds_a_siege() -> void:
	var sim := new_sim()
	sim.phase = 2
	var delivered := _events(sim, &"relay_delivered")
	var gold := _events(sim, &"gold_awarded")
	_carrying(sim)
	var r := sim.relay.long_rect(sim, MatchSim.BLUE)
	place(sim.heroes[0], r.get_center())
	run_ticks(sim, _ticks(_cfg().relay_deliver_time, sim) + 1)
	check(delivered.size() == 1 and delivered[0].long, "delivered at the long drop")
	var paid := 0.0
	for g in gold:
		if g.reason == &"relay":
			paid += g.amount
	check_near(paid, _cfg().relay_gold_base * _cfg().relay_long_gold_mult, 0.01, "x%.2f gold" % _cfg().relay_long_gold_mult)
	check(sim.pending_siege[MatchSim.BLUE] == 1 + _cfg().relay_long_extra_siege, "an extra siege minion (%d)" % sim.pending_siege[MatchSim.BLUE])


func test_enemy_on_the_long_drop_blocks_it() -> void:
	var sim := new_sim()
	sim.phase = 2
	_carrying(sim)
	var r := sim.relay.long_rect(sim, MatchSim.BLUE)
	place(sim.heroes[0], r.get_center() + Vector2(-0.8, 0))
	place(sim.heroes[1], r.get_center() + Vector2(0.8, 0))
	sim.heroes[1].stun_until = sim.time + 10.0
	run_ticks(sim, _ticks(_cfg().relay_deliver_time, sim) + 2)
	check(sim.relay.state == RelayController.State.CARRIED and sim.relay.contested, "contested: no delivery")
