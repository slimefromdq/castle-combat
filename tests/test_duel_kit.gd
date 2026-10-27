extends TestCase
## Duel First, part 2: Tricks, CC grace, interrupt refunds and the shutdown bounty.


func _cfg() -> MatchConfig:
	return MatchController.CONFIG


func _sim_with(blue_trick: StringName, red_trick := &"barrier") -> MatchSim:
	var sim := MatchSim.new()
	var picks: Array[HeroData] = [MatchController.HEROES[0], MatchController.HEROES[1]]
	sim.setup(_cfg(), MatchController.ARENA, picks, MatchController.TIERS, {}, [], [blue_trick, red_trick])
	place(sim.heroes[0], Vector2(0, -2))
	place(sim.heroes[1], Vector2(0, 30))
	return sim


func _use(sim: MatchSim, move := Vector2.ZERO, aim := Vector2.ZERO) -> void:
	var a := PlayerCommand.new()
	a.move = move
	a.aim = aim
	a.use_trick = true
	sim.step([a, PlayerCommand.new()])


func _count(sim: MatchSim, type: StringName) -> Array:
	var got := []
	sim.sim_event.connect(func(t: StringName, d: Dictionary) -> void:
		if t == type: got.append(d))
	return got


# ------------------------------------------------------------------ tricks

func test_tricks_come_from_setup_and_default_to_blink() -> void:
	var sim := _sim_with(&"brand", &"cleanse")
	check(sim.heroes[0].trick == &"brand" and sim.heroes[1].trick == &"cleanse", "each seat gets its pick")
	var plain := new_sim()
	check(plain.heroes[0].trick == &"blink", "no pick: Blink")


func test_blink_hops_the_way_you_aim_then_cools_down() -> void:
	var sim := _sim_with(&"blink")
	var blue := sim.heroes[0]
	var start := blue.pos
	_use(sim, Vector2.ZERO, Vector2(0, 1))
	check_near(blue.pos.y - start.y, _cfg().trick_blink_distance, 0.3, "hopped forward")
	check_near(blue.trick_cd, _cfg().trick_blink_cooldown - sim.dt, 0.05, "on cooldown")
	var before := blue.pos
	_use(sim, Vector2.ZERO, Vector2(0, 1))
	check(blue.pos.distance_to(before) < 0.5, "can't Blink again while cooling down")


func test_blink_stops_short_of_walls_and_not_while_stunned() -> void:
	var sim := _sim_with(&"blink")
	var blue := sim.heroes[0]
	place(blue, Vector2(0, -50))
	_use(sim, Vector2.ZERO, Vector2(0, -1))
	check(sim.arena.in_bounds(blue.pos, blue.radius - 0.01) and not Movement.is_blocked(sim, blue, blue.pos), "landed on open ground (%s)" % blue.pos)
	var sim2 := _sim_with(&"blink")
	Abilities.stun(sim2, sim2.heroes[0], 1.0)
	check(Tricks.problem(sim2, sim2.heroes[0]) != "", "no Blink while stunned")


func test_cleanse_breaks_a_stun_and_grants_immunity() -> void:
	var sim := _sim_with(&"cleanse")
	var blue := sim.heroes[0]
	Abilities.stun(sim, blue, 2.0)
	check(blue.is_stunned(sim.time), "stunned")
	_use(sim)
	check(not blue.is_stunned(sim.time), "Cleanse ends the stun")
	Abilities.stun(sim, blue, 2.0)
	check(not blue.is_stunned(sim.time), "a stun right after slides off")


func test_barrier_shields_for_a_moment() -> void:
	var sim := _sim_with(&"barrier")
	var blue := sim.heroes[0]
	_use(sim)
	check_near(blue.shield_hp, blue.max_hp * _cfg().trick_barrier_shield, 0.5, "shield of 15% max HP")
	check(blue.shield_until > sim.time, "it lasts a while")


func test_brand_burns_and_wounds_on_the_next_hero_hit() -> void:
	var sim := _sim_with(&"brand")
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	place(red, Vector2(0, 0))
	_use(sim)
	check(blue.brand_armed_until > sim.time, "armed")
	var landed := _count(sim, &"brand_landed")
	sim.apply_damage(red, 10.0, blue, &"basic")
	check(landed.size() == 1, "goes off on the hit")
	check(red.wounds_until > sim.time and red.wounds_amount >= _cfg().trick_brand_wounds - 0.001, "healing cut")
	var before := red.hp
	run_ticks(sim, int(_cfg().trick_brand_burn_time / sim.dt) + 2)
	check(before - red.hp > _cfg().trick_brand_burn * 0.9, "burned for %.0f" % (before - red.hp))
	sim.apply_damage(red, 10.0, blue, &"basic")
	check(landed.size() == 1, "one Brand per use")


# ------------------------------------------------------------------ CC grace

func test_a_new_stun_slides_off_right_after_one_ends() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	Abilities.stun(sim, blue, 1.0)
	var resisted := _count(sim, &"cc_resisted")
	run_ticks(sim, int(1.2 / sim.dt))
	check(not blue.is_stunned(sim.time), "the first stun ended")
	Abilities.stun(sim, blue, 1.0)
	check(not blue.is_stunned(sim.time), "a second stun inside the grace slides off")
	check(resisted.size() == 1, "an Immune pop")
	run_ticks(sim, int(_cfg().cc_grace_time / sim.dt) + 2)
	Abilities.stun(sim, blue, 1.0)
	check(blue.is_stunned(sim.time), "after the grace, stuns land again")


func test_stun_then_knockback_from_one_hit_both_land() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	Abilities.stun(sim, blue, 0.5)
	check(Abilities.displace(sim, blue, Vector2(0, 2), 0.3), "a knockback during the stun still lands")
	check(blue.forced_ticks > 0 and not blue.forced_self, "pushed")


func test_roots_and_knockbacks_respect_the_grace() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	Kits.root(sim, blue, 0.5)
	run_ticks(sim, int(0.75 / sim.dt))
	Kits.root(sim, blue, 1.0)
	check(not blue.is_rooted(), "a root inside the grace slides off")
	check(not Abilities.displace(sim, blue, Vector2(0, 2), 0.3), "so does a knockback")


# ------------------------------------------------------------------ interrupts

func test_interrupting_a_charge_refunds_the_interrupters_cooldown() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	red.cooldowns[0] = red.ability_cooldown(0)
	red.last_cast_slot = 0
	red.last_cast_time = sim.time
	blue.charging_since = sim.time
	var got := _count(sim, &"interrupted")
	Abilities.stun(sim, blue, 0.5)
	check(got.size() == 1, "Interrupted!")
	check_near(red.cooldowns[0], red.ability_cooldown(0) * (1.0 - _cfg().interrupt_refund), 0.01, "30% of the cooldown back")


func test_a_stun_cuts_off_a_dash() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	Abilities.force(sim, blue, Vector2(0, 4), 0.3)
	var got := _count(sim, &"interrupted")
	Abilities.stun(sim, blue, 0.5)
	check(blue.forced_ticks == 0, "the dash stops")
	check(got.size() == 1, "and counts as an interrupt")


func test_plain_stuns_and_structure_stuns_pay_no_refund() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	red.cooldowns[0] = 5.0
	red.last_cast_slot = 0
	red.last_cast_time = sim.time
	Abilities.stun(sim, blue, 0.5)
	check_near(red.cooldowns[0], 5.0, 0.001, "nothing was interrupted: no refund")
	var sim2 := new_sim()
	var b2 := sim2.heroes[0]
	var r2 := sim2.heroes[1]
	r2.cooldowns[0] = 5.0
	r2.last_cast_slot = 0
	r2.last_cast_time = sim2.time
	b2.charging_since = sim2.time
	Abilities._stun(sim2, b2, 0.5, false)
	check_near(r2.cooldowns[0], 5.0, 0.001, "a Core stun refunds nothing")


# ------------------------------------------------------------------ shutdown bounty

func _ko(sim: MatchSim, victim: HeroState) -> void:
	sim.apply_damage(victim, victim.hp + 10000.0, sim.heroes[1 - victim.team], &"basic")
	victim.alive = true
	victim.hp = victim.max_hp


func test_bounty_needs_a_streak_and_grows_with_the_clock() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_ko(sim, red)
	check(blue.streak == 1 and Economy.shutdown_bounty(sim, blue) == 0.0, "one knockout: no bounty yet")
	_ko(sim, red)
	check_near(Economy.shutdown_bounty(sim, blue), _cfg().shutdown_gold_start, 1.0, "two in a row: 200")
	sim.time = _cfg().shutdown_gold_end_time
	check_near(Economy.shutdown_bounty(sim, blue), _cfg().shutdown_gold_end, 1.0, "1000 by 11:00")
	sim.time = _cfg().shutdown_gold_end_time * 0.5
	check_near(Economy.shutdown_bounty(sim, blue), (_cfg().shutdown_gold_start + _cfg().shutdown_gold_end) * 0.5, 1.0, "halfway")


func test_shutdown_pays_the_killer_and_resets_the_streak() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_ko(sim, red)
	_ko(sim, red)
	var shut := _count(sim, &"shutdown")
	var before := red.gold
	_ko(sim, blue)
	check(shut.size() == 1, "a shutdown")
	check(red.gold - before >= _cfg().shutdown_gold_start, "the bounty on top of knockout gold (+%.0f)" % (red.gold - before))
	check(blue.streak == 0 and red.streak == 1, "streaks reset and start")
