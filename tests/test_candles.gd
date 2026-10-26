extends TestCase
## Phase I: the longer map, the back alleys and the votive candles.


func _cfg() -> MatchConfig:
	return MatchController.CONFIG


## Jumps the clock without stepping minutes of ticks.
func _at(sim: MatchSim, t: float) -> void:
	sim.tick = int(round(t / sim.dt))
	sim.time = sim.tick * sim.dt


func _park_far(sim: MatchSim) -> void:
	# Both heroes out of the way, on their own halves.
	place(sim.heroes[0], Vector2(0, -15))
	place(sim.heroes[1], Vector2(0, 15))


func test_map_is_about_fifteen_percent_longer() -> void:
	var a := MatchController.ARENA
	check_near(a.half_length, 46.305 * 1.15, 0.05, "lane is 15% longer than before")
	check(a.alleys.size() == 4, "two alleys per half (got %d)" % a.alleys.size())
	for alley in a.alleys:
		check(alley in a.floors, "alley %s is walkable ground" % alley)
		var twin := false
		for other in a.alleys:
			if other.is_equal_approx(ArenaData.mirror_rect(alley)):
				twin = true
		check(twin, "alley %s has a mirrored twin" % alley)


func test_alleys_sit_between_outer_tower_and_guardian() -> void:
	var a := MatchController.ARENA
	var outer_y := a.structure_positions[0].y
	var guardian_y := a.structure_positions[1].y
	for alley in a.alleys:
		var local := alley if alley.get_center().y < 0.0 else ArenaData.mirror_rect(alley)
		check(local.position.y > guardian_y and local.end.y < outer_y, "alley %s lies between the towers" % alley)


func test_six_candles_mirrored_on_open_ground() -> void:
	var sim := new_sim()
	var spots := sim.arena.all_candles()
	check(spots.size() == 6, "six candles (got %d)" % spots.size())
	for p in spots:
		check(spots.has(-p), "candle %s has a mirrored twin" % p)
		var on_floor := false
		for f in sim.arena.floors:
			if f.has_point(p):
				on_floor = true
		check(on_floor, "candle %s is on walkable ground" % p)
		for w in sim.arena.walls:
			check(not w.grow(0.6).has_point(p), "candle %s is clear of walls" % p)
		for b in sim.arena.bushes:
			check(not b.has_point(p), "candle %s is not hidden in a bush" % p)
		check(p.distance_to(sim.relay.origin) > 3.0 and p.distance_to(-sim.relay.origin) > 3.0, "candle %s is clear of the Relay" % p)


func test_candles_light_at_first_time() -> void:
	var sim := new_sim()
	_park_far(sim)
	sim.step([null, null])
	check(sim.pickups.lit_candles().is_empty(), "no candles at the start")
	_at(sim, _cfg().candle_first_time)
	sim.step([null, null])
	check(sim.pickups.lit_candles().size() == 6, "all six light at %d s" % int(_cfg().candle_first_time))


func test_standing_on_a_candle_takes_it() -> void:
	var sim := new_sim()
	_park_far(sim)
	_at(sim, _cfg().candle_first_time)
	sim.step([null, null])
	var c: PickupController.Candle = sim.pickups.candles[0]
	var blue := sim.heroes[0]
	place(blue, c.pos)
	var xp := blue.xp
	var gold := blue.gold
	var taken := []
	sim.sim_event.connect(func(type: StringName, data: Dictionary) -> void:
		if type == &"candle_taken":
			taken.append(data))
	run_ticks(sim, int(ceil(_cfg().candle_take_time / sim.dt)) + 1)
	check(taken.size() == 1, "taken once")
	check(not c.lit, "snuffed after being taken")
	check(blue.xp - xp >= _cfg().candle_xp - 0.01, "pays at least %d XP (got %.1f)" % [int(_cfg().candle_xp), blue.xp - xp])
	check(blue.xp - xp < _cfg().candle_xp + 2.0, "and not much more at even levels")
	check(blue.gold - gold >= _cfg().candle_gold * 0.99, "pays %d gold (got %.1f)" % [int(_cfg().candle_gold), blue.gold - gold])
	check_near(c.lit_at, sim.time + _cfg().candle_respawn_time, 0.1, "relights a minute later")


func test_trailing_hero_gets_catch_up_xp() -> void:
	var sim := new_sim()
	_park_far(sim)
	sim.heroes[1].level = 3
	_at(sim, _cfg().candle_first_time)
	sim.step([null, null])
	var blue := sim.heroes[0]
	place(blue, sim.pickups.candles[0].pos)
	var xp := blue.xp
	run_ticks(sim, int(ceil(_cfg().candle_take_time / sim.dt)) + 1)
	check(blue.xp - xp >= _cfg().candle_xp * (1.0 + 2.0 * _cfg().catch_up_per_level) - 0.01, "two levels behind pays +50%")


func test_a_contested_candle_is_not_taken() -> void:
	var sim := new_sim()
	_at(sim, _cfg().candle_first_time)
	var c: PickupController.Candle = sim.pickups.candles[2]
	place(sim.heroes[0], c.pos + Vector2(0.4, 0))
	place(sim.heroes[1], c.pos - Vector2(0.4, 0))
	run_ticks(sim, int(2.0 / sim.dt))
	check(c.lit, "nobody takes it while both stand on it")


func test_damage_restarts_the_take() -> void:
	var sim := new_sim()
	_park_far(sim)
	_at(sim, _cfg().candle_first_time)
	var c: PickupController.Candle = sim.pickups.candles[0]
	var blue := sim.heroes[0]
	place(blue, c.pos)
	var hits := 0
	for i in int(2.0 / sim.dt):
		if i % 6 == 0:
			sim.apply_damage(blue, 1.0, sim.heroes[1], &"ability")
			hits += 1
		sim.step([null, null])
	check(c.lit, "being hit every 0.2 s keeps it lit (%d hits)" % hits)


func test_snuffed_candle_relights() -> void:
	var sim := new_sim()
	_park_far(sim)
	_at(sim, _cfg().candle_first_time)
	var c: PickupController.Candle = sim.pickups.candles[0]
	place(sim.heroes[0], c.pos)
	run_ticks(sim, int(ceil(_cfg().candle_take_time / sim.dt)) + 1)
	check(not c.lit, "taken")
	place(sim.heroes[0], Vector2(0, -15))
	_at(sim, c.lit_at)
	sim.step([null, null])
	check(c.lit, "relit on time")


func test_a_hero_can_walk_into_each_home_alley() -> void:
	# Through the gaps: steer with the bot's own pathing from the lane to each candle.
	var sim := new_sim()
	var bot := BotSource.new()
	bot.team = MatchSim.BLUE
	bot._sim = sim
	var blue := sim.heroes[0]
	place(sim.heroes[1], Vector2(0, 40))
	for c in sim.pickups.candles:
		var local := MatchSim.to_team_space(MatchSim.BLUE, c.pos)
		if local.y > 0.0:
			continue
		place(blue, Vector2(0, -27))
		var reached := false
		for i in int(12.0 / sim.dt):
			var cmd := PlayerCommand.new()
			cmd.move = bot._toward(blue, c.pos)
			sim.step([cmd, null])
			if blue.pos.distance_to(c.pos) < 0.8:
				reached = true
				break
		check(reached, "reached the candle at %s from mid-lane (stopped at %s)" % [c.pos, blue.pos])


func test_bots_take_candles_in_a_real_match() -> void:
	var sim := new_sim(true, 1, 2)
	var a := BotSource.new()
	a.team = MatchSim.BLUE
	var b := BotSource.new()
	b.team = MatchSim.RED
	var taken := [0, 0]
	sim.sim_event.connect(func(type: StringName, data: Dictionary) -> void:
		if type == &"candle_taken":
			taken[data.team] += 1)
	for i in int(4.0 * 60.0 / sim.dt):
		sim.step([a.build_command(sim), b.build_command(sim)])
	check(taken[0] > 0 and taken[1] > 0, "both bots take candles in 4 minutes (got %s)" % [taken])
