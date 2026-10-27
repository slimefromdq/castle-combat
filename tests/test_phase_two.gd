extends TestCase
## Phase 2 (diamond rework, part 3): the switch, moon buffs from Pwees and the long Relay.


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


# ------------------------------------------------------------------ moon buffs

func _kill_pwee(sim: MatchSim, camp_index: int, hero: HeroState) -> void:
	if sim.time < _cfg().camp_first_time:
		_at(sim, _cfg().camp_first_time)
		run_ticks(sim, 1)
	var pwee := sim.camps.monster_of(sim, sim.camps.camps[camp_index])
	sim.apply_damage(pwee, pwee.max_hp * 10.0, hero, &"ability")


func test_phase_one_pwees_give_no_moon() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	_kill_pwee(sim, 0, blue)
	check(blue.moon_at(sim.time) == HeroState.MOON_NONE, "no moon before phase 2")


func test_your_pwee_gives_waxing_and_theirs_gives_waning() -> void:
	var sim := new_sim()
	var got := _events(sim, &"moon_gained")
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	sim.phase = 2
	check(sim.camps.side_of(sim.camps.camps[0]) == MatchSim.BLUE, "the first camp is on blue's half")
	_kill_pwee(sim, 0, blue)
	check(blue.moon_at(sim.time) == HeroState.MOON_WAXING, "blue's own Pwee: Waxing")
	check_near(blue.moon_until - sim.time, _cfg().moon_time, 0.05, "lasts %d s" % int(_cfg().moon_time))
	_kill_pwee(sim, 1, red)
	check(red.moon_at(sim.time) == HeroState.MOON_WAXING, "red's own Pwee: Waxing")
	sim.camps.camps[0].respawn_at = sim.time
	run_ticks(sim, 1)
	_kill_pwee(sim, 0, red)
	check(red.moon_at(sim.time) == HeroState.MOON_WANING, "red invading blue's Pwee: Waning")
	check(got.size() == 3, "an event per moon (%d)" % got.size())


func test_waxing_hits_harder_and_cools_down_faster() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	var m := sim.spawn_minion(melee(), MatchSim.RED, Vector2(0, 30))
	var plain := Items.outgoing(sim, blue, m, 100.0, &"ability")
	blue.moon = HeroState.MOON_WAXING
	blue.moon_until = sim.time + 10.0
	var waxed := Items.outgoing(sim, blue, m, 100.0, &"ability")
	check_near(waxed - plain, 100.0 * _cfg().moon_waxing_damage, 0.01, "+%d%% damage" % roundi(_cfg().moon_waxing_damage * 100.0))
	blue.cooldowns[0] = 10.0
	run_ticks(sim, _ticks(1.0, sim))
	check_near(10.0 - blue.cooldowns[0], 1.0 + _cfg().moon_waxing_haste, 0.05, "cooldowns tick %d%% faster" % roundi(_cfg().moon_waxing_haste * 100.0))


func test_waning_takes_less_hero_damage_and_ends_on_death() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	place(blue, Vector2(0, -26))
	place(red, Vector2(0, 26))
	blue.max_hp = 99999.0
	blue.hp = blue.max_hp
	var plain := sim.apply_damage(blue, 100.0, red, &"item")
	blue.moon = HeroState.MOON_WANING
	blue.moon_until = sim.time + 10.0
	var waned := sim.apply_damage(blue, 100.0, red, &"item")
	check_near(waned / plain, 1.0 - _cfg().moon_waning_guard, 0.001, "%d%% less damage from the enemy hero" % roundi(_cfg().moon_waning_guard * 100.0))
	var m := sim.spawn_minion(melee(), MatchSim.RED, Vector2(0, 30))
	blue.hp = 500.0
	var before := blue.hp
	Items.after_hit(sim, blue, m, 100.0, 100.0, &"basic")
	check_near(blue.hp - before, 100.0 * (_cfg().moon_waning_lifesteal + Items.hero_lifesteal(blue)), 0.5, "basic attacks heal")
	sim.apply_damage(blue, 99999.0, red, &"item")
	check(blue.moon_at(sim.time) == HeroState.MOON_NONE, "a knockout ends the moon")


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
