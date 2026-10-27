extends TestCase
## The diamond map (Lucy's rework, part 2): geometry, walk-over pickups, Pwee camps, the
## Tarot altar, honey fruit, the new Relay rules and the faster-to-start sprint.


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

func test_diamond_is_32_m_wide_and_towers_sit_16_m_out() -> void:
	var a := MatchController.ARENA
	check(a.has_diamond(), "the map has a diamond")
	check_near(a.diamond_half_width * 2.0, 32.0, 0.01, "32 m at its widest")
	check_near(absf(a.structure_positions[0].y), 16.0, 0.01, "Outer Towers 16 m from the centre")
	check(a.shoulder_y() < absf(a.structure_positions[1].y), "Guardians stand where the diamond has narrowed back into the lane")
	check(a.in_bounds(Vector2(15.0, 0.0), 0.5), "the widest point is walkable")
	check(not a.in_bounds(Vector2(9.0, -40.0), 0.0), "beside the lane near the bases is not")


func test_everything_on_the_diamond_is_mirrored_and_reachable() -> void:
	var a := MatchController.ARENA
	for list in [ArenaData.mirrored(a.pickups), ArenaData.mirrored(a.camps), ArenaData.mirrored(a.altars), ArenaData.mirrored(a.fruits)]:
		for p: Vector2 in list:
			check(list.has(-p), "%s has a mirrored twin" % p)
			check(a.in_bounds(p, 0.8), "%s is on walkable ground" % p)
			for w in a.walls:
				check(not w.grow(0.6).has_point(p), "%s is clear of walls" % p)
	check(ArenaData.mirrored(a.pickups).size() == 20, "20 pickups")
	for pk in a.pockets:
		check(a.in_bounds(pk.position, 0.0) and a.in_bounds(pk.end, 0.0), "Relay spot %s sits inside the diamond" % pk)


func test_heroes_cant_walk_off_the_diamond() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	place(sim.heroes[1], Vector2(0, 30))
	place(blue, Vector2(12.0, -2.0))
	run_ticks(sim, int(3.0 / sim.dt), Vector2(1, -1).normalized())
	check(sim.arena.in_bounds(blue.pos, blue.radius - 0.01), "stopped at the diamond's edge (at %s)" % blue.pos)
	check(blue.pos.x > 12.5, "slid along the edge instead of sticking")


func test_sight_doesnt_cut_across_outside_the_map() -> void:
	var a := MatchController.ARENA
	check(ArenaGeometry.has_line_of_sight(a, Vector2(-8, -14), Vector2(8, -14)), "across the diamond: clear")
	check(not ArenaGeometry.has_line_of_sight(a, Vector2(13, -2), Vector2(4, -45)), "from the diamond's side to behind the shoulder: blocked")


# ------------------------------------------------------------------ pickups

func test_pickups_appear_and_are_taken_by_walking_over() -> void:
	var sim := new_sim()
	_park_far(sim)
	check(sim.pickups.active().is_empty(), "nothing at the start")
	_at(sim, _cfg().pickup_first_time)
	run_ticks(sim, 1)
	check(sim.pickups.active().size() == 20, "all 20 appear at %d s" % int(_cfg().pickup_first_time))
	var blue := sim.heroes[0]
	var p: PickupController.Pickup = sim.pickups.pickups[0]
	var gold := blue.gold
	var xp := blue.xp
	place(blue, p.pos)
	run_ticks(sim, 1)
	check(not p.up, "taken at once, no waiting")
	if p.kind == PickupController.SPARK:
		check(blue.xp > xp, "a spark gives XP")
	else:
		check(blue.gold > gold, "a coin gives gold")
	check_near(p.up_at - sim.time, _cfg().pickup_respawn_time, 0.1, "back in %d s" % int(_cfg().pickup_respawn_time))


func test_pickup_kinds_are_mixed_and_mirrored() -> void:
	var sim := new_sim()
	_park_far(sim)
	_at(sim, _cfg().pickup_first_time)
	run_ticks(sim, 1)
	var sparks := 0
	var half := sim.arena.pickups.size()
	for i in half:
		check(sim.pickups.pickups[i].kind == sim.pickups.pickups[i + half].kind, "pickup %d matches its mirror" % i)
		if sim.pickups.pickups[i].kind == PickupController.SPARK:
			sparks += 1
	check(sparks > 0 and sparks < half, "some coins and some sparks (%d sparks of %d)" % [sparks, half])


# ------------------------------------------------------------------ camps

func _camp(sim: MatchSim) -> NeutralCamps.Camp:
	_at(sim, _cfg().camp_first_time)
	run_ticks(sim, 1)
	return sim.camps.camps[0]


func test_pwee_pays_for_hits_then_the_rest_on_the_kill() -> void:
	var sim := new_sim()
	_park_far(sim)
	var c := _camp(sim)
	var pwee := sim.camps.monster_of(sim, c)
	check(pwee != null and pwee.team < 0, "a neutral Pwee is up")
	var blue := sim.heroes[0]
	blue.max_hp = 99999.0
	blue.hp = blue.max_hp
	var g0 := blue.gold
	sim.apply_damage(pwee, pwee.max_hp * 0.3, blue)
	var after_hit := blue.gold - g0
	check(after_hit > 0.0, "a hit pays gold right away")
	sim.apply_damage(pwee, pwee.max_hp * 0.5, blue)
	var after_two := blue.gold - g0
	var mult := Pacing.gold_mult(sim)
	check_near(after_two, _cfg().camp_gold * _cfg().camp_damage_share * 0.8 * mult, 0.5, "80% of its HP pays 80% of the hit half")
	sim.apply_damage(pwee, pwee.max_hp, blue)
	check(not pwee.alive, "dead")
	check_near(blue.gold - g0, _cfg().camp_gold * mult, 0.5, "the kill pays the rest")
	check_near(c.respawn_at - sim.time, _cfg().camp_respawn_time, 0.1, "back in %d s" % int(_cfg().camp_respawn_time))


func test_pwee_fights_back_and_resets_without_refilling_rewards() -> void:
	var sim := new_sim()
	_park_far(sim)
	var c := _camp(sim)
	var pwee := sim.camps.monster_of(sim, c)
	var blue := sim.heroes[0]
	place(blue, c.home + Vector2(-1.5, 0))
	blue.max_hp = 99999.0
	blue.hp = blue.max_hp
	sim.apply_damage(pwee, pwee.max_hp * 0.4, blue)
	run_ticks(sim, int(2.0 / sim.dt))
	check(blue.hp < blue.max_hp, "the Pwee hits back")
	place(blue, c.home + Vector2(-_cfg().camp_leash - 3.0, 0))
	run_ticks(sim, int(8.0 / sim.dt))
	check_near(pwee.hp, pwee.max_hp, 1.0, "leashed: it went home and healed")
	var paid := c.paid
	sim.apply_damage(pwee, pwee.max_hp * 0.4, blue)
	check(c.paid <= _cfg().camp_damage_share + 0.0001 and c.paid >= paid, "the damage share doesn't refill")


func test_troopers_and_towers_ignore_pwees() -> void:
	var sim := new_sim()
	var c := _camp(sim)
	var pwee := sim.camps.monster_of(sim, c)
	var m := sim.spawn_minion(melee(), MatchSim.RED, c.home + Vector2(-0.8, 0))
	check(not CombatSystem.is_valid_target(sim, m, pwee), "troopers can't target a Pwee")
	check(CombatSystem.is_valid_target(sim, sim.heroes[0], pwee), "heroes can")


# ------------------------------------------------------------------ Tarot altar

func test_altar_take_and_pick() -> void:
	var sim := new_sim()
	_park_far(sim)
	_at(sim, _cfg().tarot_first_time)
	run_ticks(sim, 1)
	check(sim.altar.up, "the altar is up at %d s" % int(_cfg().tarot_first_time))
	var first_spot := sim.altar.pos
	var blue := sim.heroes[0]
	place(blue, sim.altar.pos)
	run_ticks(sim, int((_cfg().tarot_take_time + 0.2) / sim.dt))
	check(not sim.altar.up, "taken")
	check(sim.altar.offers[0].size() == 3, "three cards drawn")
	var g := blue.gold
	var offer: Array = sim.altar.offers[0]
	var k := offer.find(&"pentacles")
	if k < 0:
		k = 0
	sim.altar.pick(sim, blue, k)
	check(sim.altar.offers[0].is_empty(), "picked")
	if offer[k] == &"pentacles":
		check(blue.gold > g, "Pentacles pays gold")
	_at(sim, sim.altar.next_at)
	run_ticks(sim, 1)
	check(sim.altar.up and sim.altar.pos.is_equal_approx(-first_spot), "the next altar is on the other side")


func test_altar_auto_picks_and_swords_boost_damage() -> void:
	var sim := new_sim()
	_park_far(sim)
	var blue := sim.heroes[0]
	sim.altar.offers[0] = [&"swords", &"cups", &"wands"]
	sim.altar.offered_at[0] = sim.time
	run_ticks(sim, int((_cfg().tarot_pick_time + 0.2) / sim.dt))
	check(sim.altar.offers[0].is_empty(), "the first card is picked when time runs out")
	check(sim.time < blue.tarot_swords_until, "Swords is running")
	var m := sim.spawn_minion(melee(), MatchSim.RED, Vector2(0, -20))
	m.max_hp = 9999.0
	m.hp = m.max_hp
	var dealt := sim.apply_damage(m, 100.0, blue)
	check(dealt > 100.0, "Swords adds damage (%.1f)" % dealt)


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
	var took := {"pickup": 0, "camp": 0, "altar": 0}
	sim.sim_event.connect(func(type: StringName, _d: Dictionary) -> void:
		if type == &"pickup_taken": took.pickup += 1
		elif type == &"camp_cleared": took.camp += 1
		elif type == &"altar_taken": took.altar += 1
	)
	for i in int(4.0 * 60.0 / sim.dt):
		sim.step([a.build_command(sim), b.build_command(sim)])
	check(took.pickup > 0, "bots walk over pickups (%s)" % [took])
	check(took.camp > 0 or took.altar > 0, "bots take a Pwee or the altar in 4 minutes (%s)" % [took])
