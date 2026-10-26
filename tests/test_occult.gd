extends TestCase
## The occult heroes: Serpent, Fermata and KOSMONAUT (src/sim/occult_kits.gd).

const JOSE := 1
const JACK := 2
const SERPENT := 8
const FERMATA := 9
const KOSMONAUT := 10

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


func _cast(sim: MatchSim, slot: int, aim := Vector2.ZERO, move := Vector2.ZERO) -> void:
	var cmd := PlayerCommand.new()
	cmd.cast_slot = slot
	cmd.aim = aim
	cmd.move = move
	sim.step([cmd, null])


func _count(type: StringName) -> int:
	var n := 0
	for e in events:
		if e[0] == type:
			n += 1
	return n


func _last(type: StringName) -> Dictionary:
	for i in range(events.size() - 1, -1, -1):
		if events[i][0] == type:
			return events[i][1]
	return {}


func _secs(sim: MatchSim, s: float) -> int:
	return int(ceil(s / sim.dt))


func test_eleven_heroes_and_no_mirror() -> void:
	check(MatchController.HEROES.size() == 11, "eleven heroes")
	var ids := {}
	for i in MatchController.HEROES.size():
		var h := MatchController.HEROES[i]
		ids[h.id] = true
		check(h.passives.size() == 2, "%s has two passives" % h.display_name)
		check(MatchController.BOT_DECKS.has(h.id), "%s has a bot deck" % h.display_name)
		var bot_pick := MatchController.HEROES[(i + 1) % MatchController.HEROES.size()]
		check(bot_pick.id != h.id, "the bot never mirrors %s" % h.display_name)
	check(ids.size() == 11, "eleven different heroes")


# --- Serpent --------------------------------------------------------------------

func test_basics_add_venom_that_pops() -> void:
	var sim := _sim(SERPENT, JOSE, Vector2(0, 2.0))
	var red := sim.heroes[1]
	check(run_until(sim, func() -> bool: return red.venom >= 1, _secs(sim, 2.0)), "a basic attack adds Venom")
	sim.heroes[0].attack_damage = 0.0
	var before := red.hp
	check(run_until(sim, func() -> bool: return _count(&"venom_pop") > 0, _secs(sim, 3.0)), "the venom pops")
	check(red.hp < before and red.venom == 0, "the pop hurts and clears the stacks")


func test_venom_fizzles_when_serpent_is_far() -> void:
	var sim := _sim(SERPENT, JOSE, Vector2(0, 2.0))
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	OccultKits.add_venom(sim, blue, red, 3)
	place(blue, Vector2(0, -9.0))
	var hp := red.hp
	run_ticks(sim, _secs(sim, OccultKits.VENOM_TIME + 0.1))
	check(_count(&"venom_fizzled") == 1 and _count(&"venom_pop") == 0, "too far: it fizzles")
	check_near(red.hp, hp, 0.01, "no damage")


func test_venom_grows_with_missing_hp_and_is_capped() -> void:
	var sim := _sim(SERPENT, JOSE)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	var full := OccultKits.venom_damage(blue, red, 2)
	red.hp = red.max_hp * 0.5
	check(OccultKits.venom_damage(blue, red, 2) > full * 1.4, "more damage on a hurt target")
	check(OccultKits.venom_damage(blue, red, 8) <= red.max_hp * OccultKits.VENOM_CAP + 0.01, "capped at 30% max HP")


func test_fang_dart_adds_two_stacks() -> void:
	var sim := _sim(SERPENT, JOSE, Vector2(0, 5.0))
	sim.heroes[0].attack_damage = 0.0
	var red := sim.heroes[1]
	_cast(sim, 0)
	run_until(sim, func() -> bool: return red.venom > 0, _secs(sim, 1.0))
	check(red.venom == 2, "two stacks (got %d)" % red.venom)


func test_shed_skin_slips_out_of_roots_and_a_pop_halves_it() -> void:
	var sim := _sim(SERPENT, JOSE, Vector2(0, 2.0))
	var blue := sim.heroes[0]
	_level(sim, blue, 3)
	blue.attack_damage = 0.0
	Kits.root(sim, blue, 2.0)
	Kits.slow(sim, blue, 0.5, 2.0)
	var from := blue.pos
	_cast(sim, 1, Vector2(1, 0))
	run_ticks(sim, _secs(sim, 0.3))
	check(blue.pos.distance_to(from) > 3.5, "slithered about 4 m (got %.2f)" % blue.pos.distance_to(from))
	check(not blue.is_rooted() and sim.time >= blue.slow_until, "root and slow shed")
	var left := blue.cooldowns[1]
	OccultKits.add_venom(sim, blue, sim.heroes[1], 1)
	place(blue, sim.heroes[1].pos + Vector2(3, 0))
	run_until(sim, func() -> bool: return _count(&"venom_pop") > 0, _secs(sim, 3.0))
	check(blue.cooldowns[1] < (left - OccultKits.VENOM_TIME) * 0.6, "the pop halved the cooldown left")


func test_snake_pit_vipers_bite_in_venom() -> void:
	var sim := _sim(SERPENT, JOSE, Vector2(0, 4.0))
	var blue := sim.heroes[0]
	_level(sim, blue, 6)
	blue.attack_damage = 0.0
	_cast(sim, 2)
	check(sim.vipers.size() == 3, "three vipers")
	check(run_until(sim, func() -> bool: return _count(&"viper_bite") > 0, _secs(sim, 2.0)), "a viper bites")
	check(sim.heroes[1].venom >= 1, "bites add Venom")
	run_ticks(sim, _secs(sim, 5.0))
	check(sim.vipers.is_empty(), "the vipers are gone after 4 s")


func test_neurotoxin_slows_on_pop() -> void:
	var sim := _sim(SERPENT, JOSE, Vector2(0, 2.0))
	var blue := sim.heroes[0]
	_level(sim, blue, 8)
	blue.attack_damage = 0.0
	var red := sim.heroes[1]
	OccultKits.add_venom(sim, blue, red, 2)
	run_until(sim, func() -> bool: return _count(&"venom_pop") > 0, _secs(sim, 3.0))
	check(sim.time < red.slow_until and is_equal_approx(red.slow_amount, 0.4), "slowed 40% after the pop")


# --- Fermata --------------------------------------------------------------------

func test_brass_blasts_the_cone_and_knocks_back() -> void:
	var sim := _sim(FERMATA, JOSE, Vector2(0, 1.0))
	var blue := sim.heroes[0]
	blue.attack_damage = 0.0
	var red := sim.heroes[1]
	var hp := red.hp
	var from := red.pos
	_cast(sim, 0, Vector2(0, 1))
	run_ticks(sim, _secs(sim, 0.4))
	check(red.hp < hp, "the blast hurts")
	check(red.pos.distance_to(from) > 2.0, "knocked back (moved %.2f)" % red.pos.distance_to(from))
	check(sim.instruments.size() == 1, "the tuba floats")


func test_brass_misses_behind_her() -> void:
	var sim := _sim(FERMATA, JOSE, Vector2(0, -5.0))
	sim.heroes[0].attack_damage = 0.0
	var hp := sim.heroes[1].hp
	_cast(sim, 0, Vector2(0, 1))
	check_near(sim.heroes[1].hp, hp, 0.01, "nothing behind the cone")


func test_ensemble_holds_two_and_the_oldest_plays_out() -> void:
	var sim := _sim(FERMATA, JOSE, Vector2(0, 30.0))
	var blue := sim.heroes[0]
	_level(sim, blue, 3)
	_cast(sim, 0, Vector2(0, 1))
	_cast(sim, 1, Vector2(0, 1))
	check(sim.instruments.size() == 2, "two instruments")
	blue.cooldowns[0] = 0.0
	_cast(sim, 0, Vector2(1, 0))
	check(sim.instruments.size() == 2, "still two")
	check(_count(&"final_note") == 1, "the oldest played its final note")


func test_strings_chip_and_slow() -> void:
	var sim := _sim(FERMATA, JOSE, Vector2(0, 3.0))
	var blue := sim.heroes[0]
	_level(sim, blue, 3)
	blue.attack_damage = 0.0
	var red := sim.heroes[1]
	var hp := red.hp
	_cast(sim, 1)
	run_ticks(sim, _secs(sim, 1.2))
	check(red.hp < hp and sim.time < red.slow_until, "chipped and slowed")
	run_ticks(sim, _secs(sim, 3.5))
	check(_count(&"strings_pulse") == 8, "eight pulses (got %d)" % _count(&"strings_pulse"))
	check(_count(&"final_note") == 1, "then a final note")


func test_grand_finale_sends_four_waves() -> void:
	var sim := _sim(FERMATA, JOSE, Vector2(0, 1.5))
	var blue := sim.heroes[0]
	_level(sim, blue, 6)
	blue.attack_damage = 0.0
	var red := sim.heroes[1]
	var from := red.pos
	_cast(sim, 2)
	run_ticks(sim, _secs(sim, 2.0))
	check(_count(&"finale_wave") == 4, "four waves (got %d)" % _count(&"finale_wave"))
	check(red.pos.distance_to(blue.pos) > from.distance_to(blue.pos) + 1.0, "pushed away")


# --- KOSMONAUT ------------------------------------------------------------------

func test_drone_stays_put_at_his_side() -> void:
	var sim := _sim(KOSMONAUT, JOSE, Vector2(0, 30.0))
	var blue := sim.heroes[0]
	run_ticks(sim, 10)
	var home := OccultKits.drone_home(blue)
	check(blue.drone_pos.distance_to(home) < 0.01, "home: beside him")
	var first := blue.drone_pos
	run_ticks(sim, 30)
	check(blue.drone_pos.distance_to(first) < 0.01, "it doesn't wander while he stands still")


func test_drone_zaps_once_a_second() -> void:
	var sim := _sim(KOSMONAUT, JOSE, Vector2(0, 30.0))
	var blue := sim.heroes[0]
	blue.attack_damage = 0.0
	var red := sim.heroes[1]
	run_ticks(sim, 1)
	place(red, blue.drone_pos + Vector2(0, 2.0))
	run_ticks(sim, _secs(sim, 2.05))
	check(_count(&"drone_zap") == 2 or _count(&"drone_zap") == 3, "about one zap a second (got %d)" % _count(&"drone_zap"))
	check(red.hp < red.max_hp, "zaps hurt")


func test_launch_drone_parks_hits_and_comes_home() -> void:
	var sim := _sim(KOSMONAUT, JOSE, Vector2(0, 30.0))
	var blue := sim.heroes[0]
	blue.attack_damage = 0.0
	var red := sim.heroes[1]
	var hp := red.hp
	_cast(sim, 0, Vector2(1, 0))
	check(blue.drone_out and blue.drone_spot.distance_to(blue.pos + Vector2(8, 0)) < 0.6, "thrown 8 m out")
	place(red, blue.pos + Vector2(4, 0.2))  # Standing in its flight path.
	run_ticks(sim, _secs(sim, 0.8))
	check(red.hp < hp, "it hits what it flies through")
	check(blue.drone_pos.distance_to(blue.drone_spot) < 0.01, "and parks there")
	var parked := blue.drone_pos
	run_ticks(sim, 20)
	check(blue.drone_pos.distance_to(parked) < 0.01, "it stays parked")
	_cast(sim, 0)
	check(not blue.drone_out and blue.drone_back, "tap again: it flies home")
	run_ticks(sim, _secs(sim, 1.0))
	check(not blue.drone_back and blue.drone_pos.distance_to(OccultKits.drone_home(blue)) < 0.01, "home again")
	blue.cooldowns[0] = 0.0
	_cast(sim, 0, Vector2(1, 0))
	run_ticks(sim, _secs(sim, 0.8))
	place(blue, blue.drone_spot + Vector2(-OccultKits.LEASH - 1.0, 0))
	run_ticks(sim, 1)
	check(not blue.drone_out, "walking off leashes it back")


func test_pulse_bursts_around_the_drone() -> void:
	var sim := _sim(KOSMONAUT, JOSE, Vector2(0, 30.0))
	var blue := sim.heroes[0]
	_level(sim, blue, 3)
	blue.attack_damage = 0.0
	var red := sim.heroes[1]
	run_ticks(sim, 1)
	place(red, blue.drone_pos + Vector2(0, 1.5))
	blue.zap_next = 1000.0  # Only the Pulse counts here.
	var hp := red.hp
	_cast(sim, 1)
	check(red.hp < hp, "the Pulse hits")
	check(sim.time < red.slow_until, "and slows")


func test_re_entry_lands_after_a_second_and_stuns() -> void:
	var sim := _sim(KOSMONAUT, JOSE, Vector2(0, 30.0))
	var blue := sim.heroes[0]
	_level(sim, blue, 6)
	blue.attack_damage = 0.0
	var red := sim.heroes[1]
	run_ticks(sim, 1)
	place(red, blue.drone_pos)
	var spot := blue.drone_pos
	_cast(sim, 2)
	check(blue.reentry != null and blue.reentry_pos.distance_to(spot) < 0.5, "telegraphed where the drone is")
	var hp := red.hp
	run_ticks(sim, _secs(sim, 0.8))
	check(_count(&"reentry_landed") == 0, "not yet")
	run_ticks(sim, _secs(sim, 0.3))
	check(_count(&"reentry_landed") == 1 and red.hp < hp - 100.0, "it lands hard")
	check(red.is_stunned(sim.time), "and knocks up")


func test_jack_can_copy_the_new_ultimates() -> void:
	for ult in [SERPENT, FERMATA, KOSMONAUT]:
		var sim := _sim(JACK, ult, Vector2(0, 3.0))
		var blue := sim.heroes[0]
		blue.attack_damage = 0.0
		_level(sim, blue, 6)
		_cast(sim, 2)
		check(_count(&"ability_cast") == 1, "Jack casts %s's ultimate" % sim.heroes[1].data.display_name)
		run_ticks(sim, _secs(sim, 2.0))
		check(sim.heroes[1].hp < sim.heroes[1].max_hp, "and it hurts (%s)" % sim.heroes[1].data.display_name)
