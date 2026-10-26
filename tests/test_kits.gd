extends TestCase
## The round-2 kits: Ahab, Slayer, Huddle, Poppet and Tot (src/sim/kits.gd).

const AVERY := 0
const JOSE := 1
const JACK := 2
const AHAB := 3
const SLAYER := 4
const HUDDLE := 5
const POPPET := 6
const TOT := 7

var events: Array = []


func _sim(blue: int, red: int, red_at := Vector2(0, 2.0)) -> MatchSim:
	var sim := new_sim(false, blue, red)
	place(sim.heroes[0], Vector2(0, -2.0))
	place(sim.heroes[1], red_at)
	sim.heroes[1].attack_damage = 0.0
	events.clear()
	sim.sim_event.connect(func(type: StringName, data: Dictionary) -> void: events.append([type, data]))
	return sim


func _level(sim: MatchSim, h: HeroState, lv: int, picks: Array = []) -> void:
	Leveling.gain(sim, h, float(sim.config.level_xp[lv - 1]) - h.xp + 0.01)
	for p: int in picks:
		Leveling.pick_perk(sim, h, p)
	h.hp = h.max_hp
	sim.heroes[1 - h.team].hp = sim.heroes[1 - h.team].max_hp


func _cast(sim: MatchSim, slot: int, aim := Vector2.ZERO) -> void:
	var cmd := PlayerCommand.new()
	cmd.cast_slot = slot
	cmd.aim = aim
	sim.step([cmd, null])


func _count(type: StringName) -> int:
	var n := 0
	for e in events:
		if e[0] == type:
			n += 1
	return n


func _secs(sim: MatchSim, s: float) -> int:
	return int(ceil(s / sim.dt))


# --- Ahab -----------------------------------------------------------------------

func test_hook_pulls_the_hero_in() -> void:
	var sim := _sim(AHAB, JOSE, Vector2(0, 6))
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	blue.attack_damage = 0.0
	_cast(sim, 0)
	check(run_until(sim, func() -> bool: return _count(&"hooked") > 0, 40), "the hook landed")
	run_ticks(sim, 12)
	check(red.pos.distance_to(blue.pos) < 2.0, "pulled to Ahab (%.1f m)" % red.pos.distance_to(blue.pos))
	check(red.hp < red.max_hp, "and hurt")


func test_keelhaul_flings_behind() -> void:
	var sim := _sim(AHAB, JOSE, Vector2(0, -0.6))
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	blue.attack_damage = 0.0
	_level(sim, blue, 3)
	_cast(sim, 1)
	run_ticks(sim, 15)
	check(red.pos.y < blue.pos.y - 1.0, "landed behind Ahab (red y %.1f, Ahab y %.1f)" % [red.pos.y, blue.pos.y])


func test_white_whale_carries_and_stuns() -> void:
	var sim := _sim(AHAB, JOSE, Vector2(0, 3))
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	blue.attack_damage = 0.0
	_level(sim, blue, 5)
	var start := red.pos
	_cast(sim, 2)
	check(_count(&"ability_cast") == 1, "cast")
	check(_count(&"whale_breach") == 0, "telegraphed first")
	run_ticks(sim, _secs(sim, 0.7))
	check(_count(&"whale_breach") == 1, "breached")
	check(red.is_stunned(sim.time), "knocked up")
	run_ticks(sim, 25)
	check(red.pos.y > start.y + 2.0, "carried down the line (%.1f -> %.1f)" % [start.y, red.pos.y])


func test_jack_copies_the_whale() -> void:
	var sim := _sim(JACK, AHAB, Vector2(0, 3))
	var blue := sim.heroes[0]
	blue.attack_damage = 0.0
	_level(sim, blue, 5)
	_cast(sim, 2)
	run_ticks(sim, _secs(sim, 0.7))
	check(_count(&"whale_breach") == 1, "Jack summons Ahab's whale")


# --- Slayer -----------------------------------------------------------------------

func test_bear_trap_roots_after_arming() -> void:
	var sim := _sim(SLAYER, JOSE, Vector2(0, 2))
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	blue.attack_damage = 0.0
	_cast(sim, 0)
	check(sim.traps.size() == 1, "trap set")
	check(not red.is_rooted(), "not armed yet")
	run_ticks(sim, _secs(sim, 1.1))
	check(_count(&"trap_sprung") == 1, "sprung once armed")
	check(red.root_until > sim.time, "rooted")
	check(red.hp < red.max_hp, "and hurt")
	var at := red.pos
	run_ticks(sim, 10, Vector2.ZERO, Vector2(1, 0))
	check(red.pos.distance_to(at) < 0.01, "can't walk while rooted")


func test_trap_limit() -> void:
	var sim := _sim(SLAYER, JOSE, Vector2(8, 15))
	var blue := sim.heroes[0]
	for i in 3:
		blue.cooldowns[0] = 0.0
		_cast(sim, 0, Vector2(1, 0) if i % 2 == 0 else Vector2(-1, 0))
	check(sim.traps.size() == 2, "two traps at most (got %d)" % sim.traps.size())


func test_recoil_bolt_slows_and_kicks_back() -> void:
	var sim := _sim(SLAYER, JOSE, Vector2(0, 4))
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	blue.attack_damage = 0.0
	_level(sim, blue, 3)
	var start := blue.pos
	_cast(sim, 1)
	run_ticks(sim, 12)
	check(blue.pos.y < start.y - 2.0, "kicked back (%.1f m)" % (start.y - blue.pos.y))
	check(red.slow_until > sim.time, "the hero is slowed")


func test_headsmans_axe_takes_a_chunk() -> void:
	var sim := _sim(SLAYER, AVERY, Vector2(0, 5))
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	blue.attack_damage = 0.0
	_level(sim, blue, 5)
	_cast(sim, 2)
	run_ticks(sim, _secs(sim, 1.2))
	check(red.max_hp - red.hp > red.max_hp * 0.12 + 100.0, "big hit plus max HP (lost %d)" % int(red.max_hp - red.hp))
	check(sim.dots.size() == 1, "and a bleed")


# --- Huddle ------------------------------------------------------------------------

func test_buzz_overwhelms_at_five() -> void:
	var sim := _sim(HUDDLE, JOSE)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	for i in 4:
		sim.apply_damage(red, 10.0, blue, &"basic")
	check(red.buzz == 4 and _count(&"overwhelm") == 0, "four stacks")
	var hp := red.hp
	sim.apply_damage(red, 10.0, blue, &"basic")
	check(_count(&"overwhelm") == 1, "the fifth overwhelms")
	check(hp - red.hp > 40.0, "for real damage")
	check(red.slow_until > sim.time, "and a slow")
	check(red.buzz == 0, "stacks reset")


func test_latch_cloud_sticks_and_ticks() -> void:
	var sim := _sim(HUDDLE, JOSE, Vector2(0, 4))
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	blue.attack_damage = 0.0
	_cast(sim, 0)
	run_until(sim, func() -> bool: return _count(&"latched") > 0, 30)
	var hp := red.hp
	run_ticks(sim, _secs(sim, 3.1), Vector2.ZERO)
	check(hp - red.hp > 70.0, "ticked for its damage (%d)" % int(hp - red.hp))
	check(red.buzz >= 1 or _count(&"overwhelm") > 0, "and added Buzz")


func test_scatter_blinks_and_phases() -> void:
	var sim := _sim(HUDDLE, JOSE, Vector2(6, 6))
	var blue := sim.heroes[0]
	_level(sim, blue, 3)
	var start := blue.pos
	_cast(sim, 1, Vector2(-1, 0))
	check(blue.pos.distance_to(start) > 3.5, "reformed 4 m away")
	check(blue.is_untargetable(), "untouchable for a moment")


func test_swarm_storm_rides_the_hero() -> void:
	var sim := _sim(HUDDLE, JOSE, Vector2(0, 1.5))
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	red.attack_damage = 40.0
	_level(sim, blue, 5)
	_cast(sim, 2)
	check(blue.engulf_target == red.id, "engulfed")
	var hp := blue.hp
	run_ticks(sim, 20, Vector2.ZERO, Vector2(1, 0))
	check(blue.pos.distance_to(red.pos) < 0.2, "rides along")
	check(blue.hp == hp, "the engulfed hero can't hurt the swarm")
	run_ticks(sim, _secs(sim, 3.0))
	check(blue.engulf_target == 0, "ends after 3 s")


# --- Poppet --------------------------------------------------------------------------

func test_needle_threads_then_reels() -> void:
	var sim := _sim(POPPET, JOSE, Vector2(0, 4))
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	blue.attack_damage = 0.0
	_cast(sim, 0)
	check(run_until(sim, func() -> bool: return blue.thread_target == red.id, 30), "threaded")
	_cast(sim, 0)
	run_ticks(sim, 12)
	check(blue.pos.distance_to(red.pos) < 1.6, "reeled in (%.1f m)" % blue.pos.distance_to(red.pos))
	check(blue.cooldowns[0] > 0.0, "and the needle is cooling down")


func test_thread_snaps() -> void:
	var sim := _sim(POPPET, JOSE, Vector2(0, 4))
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	blue.attack_damage = 0.0
	_cast(sim, 0)
	run_until(sim, func() -> bool: return blue.thread_target == red.id, 30)
	var hp := red.hp
	place(red, Vector2(0, 8))
	run_ticks(sim, 1)
	check(_count(&"thread_snapped") == 1, "snapped past 7 m")
	check(red.hp < hp, "and it hurt")


func test_wind_up_key_freezes_a_facing_hero() -> void:
	var sim := _sim(POPPET, JOSE, Vector2(0, 2))
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	blue.attack_damage = 0.0
	_level(sim, blue, 3)
	red.facing = Vector2(0, -1)  # Looking at Poppet.
	_cast(sim, 1)
	check(red.is_stunned(sim.time), "frozen in terror")
	check(blue.current_interval(sim.time) < blue.attack_interval * 0.7, "her snips speed up")
	var sim2 := _sim(POPPET, JOSE, Vector2(0, 2))
	_level(sim2, sim2.heroes[0], 3)
	sim2.heroes[1].facing = Vector2(0, 1)  # Looking away.
	_cast(sim2, 1)
	check(not sim2.heroes[1].is_stunned(sim2.time), "looking away is safe")


func test_cut_to_ribbons() -> void:
	var sim := _sim(POPPET, AVERY, Vector2(0, 2))
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	blue.attack_damage = 0.0
	_level(sim, blue, 5)
	_cast(sim, 2)
	check(red.root_until > sim.time, "feet sewn down")
	run_ticks(sim, _secs(sim, 1.6))
	check(_count(&"snip") == 8, "eight snips (got %d)" % _count(&"snip"))
	check(red.hp < red.max_hp - 150.0, "real damage")


# --- Tot --------------------------------------------------------------------------------

func test_blood_debt_postpones_damage() -> void:
	var sim := _sim(TOT, JOSE)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	var hp := blue.hp
	sim.apply_damage(blue, 100.0, red, &"basic")
	check_near(hp - blue.hp, 65.0, 0.01, "65% lands now")
	check_near(blue.debt, 35.0, 0.01, "35% goes into Debt")
	run_ticks(sim, _secs(sim, 1.0))
	check(blue.debt < 0.01 and blue.hp < hp - 99.0, "Debt drains into real damage")


func test_hitting_the_hero_cancels_debt() -> void:
	var sim := _sim(TOT, JOSE)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	blue.debt = 100.0
	sim.apply_damage(red, 40.0, blue, &"basic")
	check_near(blue.debt, 80.0, 0.01, "basics cancel half their damage")
	sim.apply_damage(red, 40.0, blue, &"ability")
	check_near(blue.debt, 40.0, 0.01, "abilities cancel all of it")


func test_blood_price_sweep() -> void:
	var sim := _sim(TOT, JOSE, Vector2(0, 0))
	var blue := sim.heroes[0]
	blue.attack_damage = 0.0
	_cast(sim, 0)
	check(blue.debt == 0.0, "a landed sweep cancels more than it cost")
	var sim2 := _sim(TOT, JOSE, Vector2(10, 15))
	sim2.heroes[0].attack_damage = 0.0
	_cast(sim2, 0)
	check(sim2.heroes[0].debt > sim2.heroes[0].max_hp * 0.07, "a miss leaves Tot in debt")


func test_borrowed_time_defers_everything() -> void:
	var sim := _sim(TOT, JOSE)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level(sim, blue, 3)
	_cast(sim, 1)
	var hp := blue.hp
	sim.apply_damage(blue, 100.0, red, &"basic")
	check_near(blue.hp, hp, 0.01, "nothing lands now")
	check_near(blue.debt, 100.0, 0.01, "it all goes into Debt")


func test_absolute_rule_fails_and_lands_at_once() -> void:
	var sim := _sim(TOT, AVERY, Vector2(0, 2))
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	blue.attack_damage = 0.0
	_level(sim, blue, 5)
	_cast(sim, 2)
	run_ticks(sim, 12)
	place(red, Vector2(8, 14))  # Out of reach, so Tot's swings can't cancel Debt.
	var hp := blue.hp
	sim.apply_damage(blue, 200.0, red, &"basic")
	check_near(blue.hp, hp, 0.01, "deferred during the rule")
	run_ticks(sim, _secs(sim, 3.0))
	check(blue.debt > 199.0, "no drain while the rule holds")
	run_ticks(sim, _secs(sim, 3.5))
	check(_count(&"rule_failed") == 1, "the rule failed")
	check(blue.hp < hp - 199.0 and blue.debt < 0.01, "the whole Debt landed at once")


func test_absolute_rule_kill_forgives() -> void:
	var sim := _sim(TOT, JOSE, Vector2(0, 2))
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	blue.attack_damage = 0.0
	_level(sim, blue, 5)
	_cast(sim, 2)
	run_ticks(sim, 12)
	sim.apply_damage(blue, 300.0, red, &"basic")
	blue.hp = blue.max_hp * 0.4
	sim.apply_damage(red, red.hp + 50.0, blue, &"ability")
	check(not red.alive, "the enemy fell")
	check(blue.debt == 0.0, "all Debt forgiven")
	check(_count(&"rule_forgiven") == 1, "forgiven")
	check(blue.hp > blue.max_hp * 0.55, "and healed")
