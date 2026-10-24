extends TestCase
## Hero levels, perks and abilities.

const VANGUARD := 0
const SCOUT := 1
const GUNNER := 2

var events: Array = []


func _sim(blue: int, red: int) -> MatchSim:
	var sim := new_sim(false, blue, red)
	place(sim.heroes[0], Vector2(0, -2.0))
	place(sim.heroes[1], Vector2(0, 2.0))
	events.clear()
	sim.sim_event.connect(func(type: StringName, data: Dictionary) -> void: events.append([type, data]))
	return sim


func _level(sim: MatchSim, h: HeroState, lv: int) -> void:
	Leveling.gain(sim, h, float(sim.config.level_xp[lv - 1]) - h.xp + 0.01)


func _cast(sim: MatchSim, slot: int, move := Vector2.ZERO) -> void:
	var cmd := PlayerCommand.new()
	cmd.cast_slot = slot
	cmd.move = move
	sim.step([cmd, null])


func _still(h: HeroState) -> void:
	h.attack_damage = 0.0


func _count(type: StringName) -> int:
	var n := 0
	for e in events:
		if e[0] == type:
			n += 1
	return n


# --- Levels -------------------------------------------------------------------

func test_level_curve_and_unlocks() -> void:
	var sim := _sim(VANGUARD, SCOUT)
	var blue := sim.heroes[0]
	check(blue.level == 1 and blue.ability_unlocked(0) and not blue.ability_unlocked(1), "level 1: first ability only")
	_level(sim, blue, 3)
	check(blue.level == 3 and blue.ability_unlocked(1) and not blue.ability_unlocked(2), "level 3: second ability")
	check(blue.owned_perks().size() == 1, "one perk by level 3")
	_level(sim, blue, 6)
	check(blue.level == 6 and blue.ability_unlocked(2) and blue.owned_perks().size() == 3, "level 6: ultimate and capstone")
	Leveling.gain(sim, blue, 10000.0)
	check(blue.level == 6, "level 6 is the cap")
	check(_count(&"level_up") == 5, "five level-ups")


func test_passive_xp() -> void:
	var sim := _sim(VANGUARD, SCOUT)
	run_ticks(sim, sim.config.tick_rate * 10)
	check_near(sim.heroes[0].xp, 10.0 * sim.config.passive_xp_per_second, 0.05, "XP trickles in over time")


func test_minion_xp_follows_the_gold_rule() -> void:
	var sim := _sim(VANGUARD, SCOUT)
	var blue := sim.heroes[0]
	var m := sim.spawn_minion(melee(), MatchSim.RED, blue.pos + Vector2(2, 0))
	sim.apply_damage(m, m.max_hp, sim.structures_of(MatchSim.BLUE)[0])
	check_near(blue.xp, melee().xp_bounty, 0.01, "nearby minion death gives XP")
	var far := sim.spawn_minion(melee(), MatchSim.RED, blue.pos + Vector2(0, 20))
	sim.apply_damage(far, far.max_hp, sim.structures_of(MatchSim.BLUE)[0])
	check_near(blue.xp, melee().xp_bounty, 0.01, "nothing from far away")


func test_knockout_xp_and_catch_up() -> void:
	var sim := _sim(VANGUARD, SCOUT)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level(sim, red, 3)
	var before := blue.xp
	sim.apply_damage(red, red.max_hp * 2.0, blue)
	var expected: float = (sim.config.ko_xp + 2 * sim.config.ko_xp_per_level_above) * (1.0 + 2 * sim.config.catch_up_per_level)
	check_near(blue.xp - before, expected, 0.01, "knockout XP, bonus for a higher victim, catch-up for trailing")


func test_perks_change_stats() -> void:
	var sim := _sim(VANGUARD, SCOUT)
	var blue := sim.heroes[0]
	_level(sim, blue, 2)
	check_near(blue.max_hp, blue.data.max_hp * 1.1, 0.01, "Thick Hide: +10% max HP")
	_level(sim, blue, 4)
	check_near(blue.ability_cooldown(0), blue.data.abilities[0].cooldown - 3.0, 0.001, "Battering Ram cuts Shield Bash cooldown")


# --- Casting rules ------------------------------------------------------------

func test_locked_abilities_and_cooldowns() -> void:
	var sim := _sim(SCOUT, VANGUARD)
	var blue := sim.heroes[0]
	_cast(sim, 1)
	check(_count(&"ability_cast") == 0, "level 2 ability is locked at level 1")
	_cast(sim, 0, Vector2.LEFT)
	check(_count(&"ability_cast") == 1, "Dash cast")
	run_ticks(sim, 10)
	_cast(sim, 0, Vector2.LEFT)
	check(_count(&"ability_cast") == 1, "on cooldown")
	run_ticks(sim, int(blue.data.abilities[0].cooldown / sim.dt))
	_cast(sim, 0, Vector2.RIGHT)
	check(_count(&"ability_cast") == 2, "ready again after the cooldown")


func test_carrier_cannot_dash() -> void:
	var sim := _sim(SCOUT, VANGUARD)
	sim.heroes[0].carrying_relay = true
	_cast(sim, 0, Vector2.LEFT)
	check(_count(&"ability_cast") == 0, "no movement abilities while carrying the Relay")


# --- Kits ---------------------------------------------------------------------

func test_scout_dash_moves_five_metres() -> void:
	var sim := _sim(SCOUT, VANGUARD)
	var blue := sim.heroes[0]
	place(blue, Vector2(0, -12))
	place(sim.heroes[1], Vector2(0, 30))
	_cast(sim, 0, Vector2(0, 1))
	run_ticks(sim, 10)
	check_near(blue.pos.distance_to(Vector2(0, -12)), 5.0, 0.15, "dashed 5 m")


func test_shield_bash_hits_and_knocks_back() -> void:
	var sim := _sim(VANGUARD, SCOUT)
	var red := sim.heroes[1]
	_still(red)
	place(red, Vector2(0, 2.5))
	var start := red.pos
	_cast(sim, 0)
	run_ticks(sim, 20)
	check(red.hp < red.max_hp, "bash damaged the Scout")
	check(red.pos.distance_to(start) > 2.0, "and knocked it back (moved %.1f m)" % red.pos.distance_to(start))


func test_bulwark_absorbs_damage() -> void:
	var sim := _sim(VANGUARD, SCOUT)
	var blue := sim.heroes[0]
	_level(sim, blue, 3)
	_cast(sim, 1)
	var hp := blue.hp
	sim.apply_damage(blue, 100.0, sim.heroes[1])
	check_near(blue.hp, hp, 0.01, "shield soaked the hit")
	run_ticks(sim, int(5.0 / sim.dt))
	check(blue.shield_hp == 0.0, "shield expires")


func test_earthshaker_stuns() -> void:
	var sim := _sim(VANGUARD, SCOUT)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level(sim, blue, 5)
	_cast(sim, 2)
	check(red.is_stunned(sim.time) and red.hp < red.max_hp, "slam damaged and stunned the Scout")
	var at := red.pos
	run_ticks(sim, 15, Vector2.ZERO, Vector2.UP)
	check(red.pos == at, "a stunned hero can't move")
	check(not red.is_winding_up(), "or attack")
	run_ticks(sim, 40, Vector2.ZERO, Vector2.UP)
	check(red.pos != at, "moves again after the stun")


func test_flurry_speeds_up_attacks() -> void:
	var sim := _sim(SCOUT, VANGUARD)
	var blue := sim.heroes[0]
	_level(sim, blue, 3)
	_cast(sim, 1)
	check_near(blue.current_interval(sim.time), blue.attack_interval / 1.6, 0.001, "+60% attack speed")


func test_blade_rush_needs_a_target_and_hits_it() -> void:
	var sim := _sim(SCOUT, VANGUARD)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level(sim, blue, 5)
	place(red, Vector2(0, 30))
	_cast(sim, 2)
	check(_count(&"ability_cast") == 0, "no enemy hero in reach: nothing happens, no cooldown")
	place(red, Vector2(0, 4))
	_still(red)
	_cast(sim, 2)
	run_ticks(sim, 12)
	check(red.hp <= red.max_hp - blue.data.abilities[2].damage + 0.01, "Blade Rush hit")
	check(blue.pos.y > red.pos.y, "and went through")


func test_power_shot_reaches_past_basic_range() -> void:
	var sim := _sim(GUNNER, VANGUARD)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	place(red, blue.pos + Vector2(0, 8.0))
	_cast(sim, 0)
	check_near(red.hp, red.max_hp - blue.data.abilities[0].damage, 0.01, "110 damage at 8 m")


func test_recoil_hops_away_and_slows() -> void:
	var sim := _sim(GUNNER, VANGUARD)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level(sim, blue, 3)
	place(red, blue.pos + Vector2(0, 1.5))
	_cast(sim, 1)
	run_ticks(sim, 10)
	check(blue.pos.y < -4.0, "hopped back from the Vanguard (y %.1f)" % blue.pos.y)
	check(red.slow_until > sim.time and red.move_speed() < red.data.move_speed, "Vanguard slowed")


func test_barrage_pulses_and_counts_once_for_the_relay() -> void:
	var sim := _sim(GUNNER, VANGUARD)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level(sim, blue, 5)
	blue.attack_damage = 0.0
	place(red, blue.pos + Vector2(0, 7.0))
	_still(red)
	red.carrying_relay = true
	sim.relay.state = RelayController.State.CARRIED
	sim.relay.carrier_id = red.id
	_cast(sim, 2)
	run_ticks(sim, int(2.0 / sim.dt))
	check(_count(&"barrage_pulse") == 4, "four pulses")
	check_near(red.hp, red.max_hp - 4 * blue.data.abilities[2].damage, 0.01, "all four hit")
	check(sim.relay.state == RelayController.State.CARRIED, "one cast counts as one hit for interception")


func test_moving_cancels_barrage() -> void:
	var sim := _sim(GUNNER, VANGUARD)
	var blue := sim.heroes[0]
	_level(sim, blue, 5)
	place(sim.heroes[1], blue.pos + Vector2(0, 7.0))
	_cast(sim, 2)
	run_ticks(sim, 5, Vector2.LEFT)
	run_ticks(sim, 60)
	check(_count(&"barrage_pulse") < 4, "walking away stopped the barrage")


func test_finisher_and_bastion() -> void:
	var sim := _sim(SCOUT, VANGUARD)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level(sim, blue, 6)
	red.hp = red.max_hp * 0.3
	var hp := red.hp
	sim.apply_damage(red, 100.0, blue)
	check_near(hp - red.hp, 130.0, 0.01, "Finisher: +30% on a low hero")
	var sim2 := _sim(VANGUARD, SCOUT)
	var v := sim2.heroes[0]
	_level(sim2, v, 6)
	_cast(sim2, 1)
	var shield := v.shield_hp
	sim2.apply_damage(v, 100.0, sim2.heroes[1])
	check_near(shield - v.shield_hp, 70.0, 0.01, "Bastion: 30% less while Bulwark holds")
