extends TestCase
## The diamond map: geometry (tightened to 22 m with pillars for Duel First), honey
## fruit, the Relay rules and the faster-to-start sprint.


func _cfg() -> MatchConfig:
	return MatchController.CONFIG


## Jumps the clock without stepping minutes of ticks.
func _at(sim: MatchSim, t: float) -> void:
	sim.tick = int(round(t / sim.dt))
	sim.time = sim.tick * sim.dt


func _park_far(sim: MatchSim) -> void:
	place(sim.heroes[0], Vector2(0, -26))
	place(sim.heroes[1], Vector2(0, 26))


# ------------------------------------------------------------------ geometry

func test_diamond_is_22_m_wide_and_towers_sit_16_m_out() -> void:
	var a := MatchController.ARENA
	check(a.has_diamond(), "the map has a diamond")
	check_near(a.diamond_half_width * 2.0, 22.0, 0.01, "22 m at its widest")
	check_near(absf(a.structure_positions[0].y), 16.0, 0.01, "Outer Towers 16 m from the centre")
	check(a.shoulder_y() < absf(a.structure_positions[1].y), "Guardians stand where the diamond has narrowed back into the lane")
	check(a.in_bounds(Vector2(10.0, 0.0), 0.5), "the widest point is walkable")
	check(not a.in_bounds(Vector2(13.0, 0.0), 0.0), "the old 32 m edge is gone")
	check(not a.in_bounds(Vector2(9.0, -40.0), 0.0), "beside the lane near the bases is not")


func test_everything_on_the_diamond_is_mirrored_and_reachable() -> void:
	var a := MatchController.ARENA
	var fruit := ArenaData.mirrored(a.fruits)
	check(fruit.size() == 4, "4 honey fruit")
	for p: Vector2 in fruit:
		check(fruit.has(-p), "%s has a mirrored twin" % p)
		check(a.in_bounds(p, 0.8), "%s is on walkable ground" % p)
		for w in a.walls:
			check(not w.grow(0.6).has_point(p), "%s is clear of walls" % p)
	check(absf(fruit[0].y - fruit[1].y) > 4.0, "a side's two fruit sit apart along the lane")
	for pk in a.pockets:
		check(a.in_bounds(pk.position, 0.0) and a.in_bounds(pk.end, 0.0), "Relay spot %s sits inside the diamond" % pk)
		for w in a.walls:
			check(not w.intersects(pk.grow(0.5)), "Relay spot %s is clear of walls" % pk)
	var long := a.long_drop
	var half := MatchController.CONFIG.relay_long_size * 0.5
	check(a.in_bounds(long - Vector2(half, half), 0.0) and a.in_bounds(long + Vector2(half, half), 0.0), "the long drop is on walkable ground")


func test_four_pillars_stand_on_the_diamond_flanks() -> void:
	var a := MatchController.ARENA
	var pillars: Array[Rect2] = []
	for w in a.walls:
		if w.size.x < 2.0 and w.size.y < 2.0:
			pillars.append(w)
	check(pillars.size() == 4, "4 pillars (got %d)" % pillars.size())
	for w in pillars:
		var c := w.get_center()
		check(absf(c.x) > a.lane_half_width, "pillar %s stays off the lane, so troopers never snag" % c)
		check(a.in_diamond(c, 0.6), "pillar %s stands on the diamond" % c)
	check(not ArenaGeometry.has_line_of_sight(a, Vector2(-9.2, -6.2), Vector2(-5.5, -6.2)), "a pillar blocks a shot behind it")


func test_heroes_cant_walk_off_the_diamond() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	place(sim.heroes[1], Vector2(0, 30))
	place(blue, Vector2(8.0, -4.0))
	run_ticks(sim, int(3.0 / sim.dt), Vector2(1, 0.3).normalized())
	check(sim.arena.in_bounds(blue.pos, blue.radius - 0.01), "stopped at the diamond's edge (at %s)" % blue.pos)
	check(blue.pos.y > -3.0 and blue.pos.x > 9.5, "slid along the edge toward the widest point instead of sticking (at %s)" % blue.pos)


func test_sight_doesnt_cut_across_outside_the_map() -> void:
	var a := MatchController.ARENA
	check(ArenaGeometry.has_line_of_sight(a, Vector2(-7, -10), Vector2(7, -10)), "across the diamond: clear")
	check(not ArenaGeometry.has_line_of_sight(a, Vector2(10, -1), Vector2(4, -45)), "from the diamond's side to behind the shoulder: blocked")


# ------------------------------------------------------------------ honey fruit

func test_fruit_heals_over_time_and_damage_stops_it() -> void:
	var sim := new_sim()
	_park_far(sim)
	_at(sim, _cfg().fruit_first_time)
	run_ticks(sim, 1)
	var f: Fruits.Fruit = sim.fruits.fruits[0]
	check(f.ripe, "ripe at %d s" % int(_cfg().fruit_first_time))
	var blue := sim.heroes[0]
	blue.hp = blue.max_hp * 0.5
	place(blue, f.pos)
	run_ticks(sim, int((_cfg().fruit_eat_time + 0.1) / sim.dt))
	check(not f.ripe, "eaten")
	var hp := blue.hp
	run_ticks(sim, int(1.0 / sim.dt))
	check(blue.hp > hp, "healing over time")
	sim.apply_damage(blue, 1.0, sim.heroes[1])
	hp = blue.hp
	run_ticks(sim, int(1.0 / sim.dt))
	check_near(blue.hp, hp, 0.01, "damage ends the heal")
	check(blue.hp < blue.max_hp * (0.5 + _cfg().fruit_heal) + 1.0, "a small heal, at most %d%%" % roundi(_cfg().fruit_heal * 100.0))


# ------------------------------------------------------------------ Relay and sprint

func _carry(sim: MatchSim) -> HeroState:
	var blue := sim.heroes[0]
	_at(sim, _cfg().first_relay_time)
	run_ticks(sim, 1)
	place(blue, sim.relay.pos)
	run_ticks(sim, int((_cfg().relay_pickup_time + 0.2) / sim.dt))
	return blue


func test_carrier_is_faster_and_cant_sprint() -> void:
	var sim := new_sim()
	place(sim.heroes[1], Vector2(0, 30))
	var blue := _carry(sim)
	check(blue.carrying_relay, "carrying")
	check(blue.carry_speed_mult > 1.0, "the carrier moves faster")
	run_ticks(sim, int(4.0 / sim.dt), Vector2(0, -1))
	check(not blue.sprinting, "no sprinting with the Relay")


func test_any_enemy_hero_damage_knocks_it_off_for_three_seconds() -> void:
	var sim := new_sim()
	var red := sim.heroes[1]
	place(red, Vector2(0, 30))
	var blue := _carry(sim)
	sim.apply_damage(blue, 5.0, red, &"ability")
	check(not blue.carrying_relay and sim.relay.state == RelayController.State.DROPPED, "any hit from the enemy hero knocks it off")
	run_ticks(sim, int(2.5 / sim.dt))
	check(not blue.carrying_relay, "nobody can pick it up for 3 s")
	run_ticks(sim, int(1.0 / sim.dt))
	check(blue.carrying_relay, "then it can be taken again")


func test_relay_fizzles_on_the_third_knock_off() -> void:
	var sim := new_sim()
	var red := sim.heroes[1]
	place(red, Vector2(0, 30))
	var blue := _carry(sim)
	var fizzled := [false]
	sim.sim_event.connect(func(type: StringName, _d: Dictionary) -> void:
		if type == &"relay_fizzled":
			fizzled[0] = true)
	for i in 3:
		place(blue, sim.relay.pos)
		run_ticks(sim, int((_cfg().relay_drop_lockout + _cfg().relay_pickup_time + 0.3) / sim.dt))
		if blue.carrying_relay:
			sim.apply_damage(blue, 5.0, red)
	check(fizzled[0] and sim.relay.state == RelayController.State.DORMANT, "gone after three knock-offs")


func test_relay_fizzles_twenty_seconds_after_the_first_knock_off() -> void:
	var sim := new_sim()
	var red := sim.heroes[1]
	place(red, Vector2(0, 30))
	var blue := _carry(sim)
	sim.apply_damage(blue, 5.0, red)
	run_ticks(sim, int((_cfg().relay_fizzle_time + 0.3) / sim.dt))
	check(sim.relay.state == RelayController.State.DORMANT, "gone %d s after the first knock-off" % int(_cfg().relay_fizzle_time))


func test_sprint_starts_sooner_and_is_slower() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	place(sim.heroes[1], Vector2(0, 30))
	place(blue, Vector2(0, -45))
	_at(sim, 10.0)
	run_ticks(sim, int((_cfg().sprint_build_time + 0.1) / sim.dt), Vector2(0, 1))
	check(blue.sprinting, "sprinting after %.1f s" % _cfg().sprint_build_time)
	check_near(blue.sprint_mult, 1.45 * 0.92, 0.01, "8% slower than before")


# ------------------------------------------------------------------ bots

func test_bots_use_the_diamond_in_a_real_match() -> void:
	var sim := new_sim(true, 1, 2)
	var a := BotSource.new()
	a.team = MatchSim.BLUE
	var b := BotSource.new()
	b.team = MatchSim.RED
	var seen := {"relay": 0}
	sim.sim_event.connect(func(type: StringName, _d: Dictionary) -> void:
		if type == &"relay_picked_up": seen.relay += 1
	)
	var off_map := 0
	for i in int(4.0 * 60.0 / sim.dt):
		sim.step([a.build_command(sim), b.build_command(sim)])
		for h in sim.heroes:
			if h.alive and not sim.arena.in_bounds(h.pos, h.radius - 0.05):
				off_map += 1
	check(off_map == 0, "bots stay on walkable ground (%d ticks off)" % off_map)
	check(seen.relay > 0, "bots pick up the Relay in 4 minutes (%s)" % [seen])
