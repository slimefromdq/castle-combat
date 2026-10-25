extends TestCase
## Hero levels, perk picks, and the kits of Avery, Jose and Jack.

const AVERY := 0
const JOSE := 1
const JACK := 2

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


## Levels up and picks perks (0 or 1 per reached tier, in order).
func _level_pick(sim: MatchSim, h: HeroState, lv: int, picks: Array) -> void:
	_level(sim, h, lv)
	for p: int in picks:
		Leveling.pick_perk(sim, h, p)


func _cast(sim: MatchSim, slot: int, move := Vector2.ZERO) -> void:
	var cmd := PlayerCommand.new()
	cmd.cast_slot = slot
	cmd.move = move
	sim.step([cmd, null])


func _still(h: SimEntity) -> void:
	h.attack_damage = 0.0


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


# --- Levels and perks -----------------------------------------------------------

func test_level_curve_and_unlocks() -> void:
	var sim := _sim(AVERY, JOSE)
	var blue := sim.heroes[0]
	check(blue.level == 1 and blue.ability_unlocked(0) and not blue.ability_unlocked(1), "level 1: first ability only")
	_level(sim, blue, 3)
	check(blue.level == 3 and blue.ability_unlocked(1) and not blue.ability_unlocked(2), "level 3: second ability")
	check(blue.owned_perks().is_empty() and blue.pending_perk_tier() == 0, "the level 2 perk waits for a pick")
	Leveling.pick_perk(sim, blue, 1)
	check(blue.owned_perks().size() == 1 and blue.owned_perks()[0].id == &"steadfast", "picked the second option")
	_level(sim, blue, 6)
	check(blue.level == 6 and blue.ability_unlocked(2), "level 6: ultimate")
	Leveling.pick_perk(sim, blue, 0)
	Leveling.pick_perk(sim, blue, 1)
	var ids := blue.owned_perks().map(func(p: PerkData) -> StringName: return p.id)
	check(ids == [&"steadfast", &"shatter", &"sanctuary"], "one perk from each pair (got %s)" % [ids])
	check(not Leveling.pick_perk(sim, blue, 0), "nothing left to pick")
	Leveling.gain(sim, blue, 10000.0)
	check(blue.level == 6, "level 6 is the cap")
	check(_count(&"level_up") == 5, "five level-ups")


func test_every_hero_has_three_perk_pairs() -> void:
	for h: HeroData in MatchController.HEROES:
		check(h.perks.size() == 6, "%s has 6 perks" % h.display_name)
		check(h.abilities.size() == 3, "%s has 3 abilities" % h.display_name)


func test_unpicked_perk_is_picked_for_you() -> void:
	var sim := _sim(AVERY, JOSE)
	var blue := sim.heroes[0]
	_level(sim, blue, 2)
	run_ticks(sim, int((sim.config.perk_auto_pick_time - 1.0) / sim.dt))
	check(blue.owned_perks().is_empty(), "still waiting")
	run_ticks(sim, int(2.0 / sim.dt))
	check(blue.owned_perks().size() == 1 and blue.owned_perks()[0].id == &"mercy", "first option taken after the wait")


func test_perk_pick_command() -> void:
	var sim := _sim(AVERY, JOSE)
	var blue := sim.heroes[0]
	_level(sim, blue, 2)
	var cmd := PlayerCommand.new()
	cmd.perk_pick = 1
	sim.step([cmd, null])
	check(blue.perk_picks[0] == 1 and _count(&"perk_picked") == 1, "the command picks a perk")


func test_all_heroes_share_move_speed() -> void:
	var speed := MatchController.HEROES[0].move_speed
	for h: HeroData in MatchController.HEROES:
		check(h.move_speed == speed, "%s moves at the standard speed" % h.display_name)


func test_passive_xp() -> void:
	var sim := _sim(AVERY, JOSE)
	run_ticks(sim, sim.config.tick_rate * 10)
	check_near(sim.heroes[0].xp, 10.0 * sim.config.passive_xp_per_second, 0.05, "XP trickles in over time")


func test_minion_xp_follows_the_gold_rule() -> void:
	var sim := _sim(AVERY, JOSE)
	var blue := sim.heroes[0]
	var m := sim.spawn_minion(melee(), MatchSim.RED, blue.pos + Vector2(2, 0))
	sim.apply_damage(m, m.max_hp, sim.structures_of(MatchSim.BLUE)[0])
	check_near(blue.xp, melee().xp_bounty, 0.01, "nearby minion death gives XP")
	var far := sim.spawn_minion(melee(), MatchSim.RED, blue.pos + Vector2(0, 20))
	sim.apply_damage(far, far.max_hp, sim.structures_of(MatchSim.BLUE)[0])
	check_near(blue.xp, melee().xp_bounty, 0.01, "nothing from far away")


func test_knockout_xp_and_catch_up() -> void:
	var sim := _sim(AVERY, JOSE)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level(sim, red, 3)
	var before := blue.xp
	sim.apply_damage(red, red.max_hp * 2.0, blue)
	var expected: float = (sim.config.ko_xp + 2 * sim.config.ko_xp_per_level_above) * (1.0 + 2 * sim.config.catch_up_per_level)
	check_near(blue.xp - before, expected, 0.01, "knockout XP, bonus for a higher victim, catch-up for trailing")


# --- Casting rules ------------------------------------------------------------

func test_locked_abilities_and_cooldowns() -> void:
	var sim := _sim(AVERY, JOSE)
	var blue := sim.heroes[0]
	place(sim.heroes[1], Vector2(0, 30))
	_cast(sim, 1)
	check(_count(&"ability_cast") == 0, "level 3 ability is locked at level 1")
	_cast(sim, 0)
	check(_count(&"ability_cast") == 1, "Cleave cast")
	run_ticks(sim, 10)
	_cast(sim, 0)
	check(_count(&"ability_cast") == 1, "on cooldown")
	run_ticks(sim, int(blue.data.abilities[0].cooldown / sim.dt))
	_cast(sim, 0)
	check(_count(&"ability_cast") == 2, "ready again after the cooldown")


func test_carrier_cannot_dash_or_teleport() -> void:
	var sim := _sim(JOSE, AVERY)
	sim.heroes[0].carrying_relay = true
	_cast(sim, 0, Vector2.LEFT)
	check(_count(&"ability_cast") == 0, "no Spin Dash while carrying the Relay")
	var sim2 := _sim(JACK, AVERY)
	var jack := sim2.heroes[0]
	place(sim2.heroes[1], Vector2(0, 30))
	_cast(sim2, 0)
	run_ticks(sim2, 20)
	jack.carrying_relay = true
	_cast(sim2, 0)
	check(_count(&"teleported") == 0, "no cloak teleport while carrying the Relay")


# --- Avery ----------------------------------------------------------------------

func test_cleave_hits_around_and_heals_per_hit() -> void:
	var sim := _sim(AVERY, JOSE)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	place(red, Vector2(0, 0))
	_still(red)
	for x in [-1.5, 1.5]:
		_still(sim.spawn_minion(melee(), MatchSim.RED, blue.pos + Vector2(x, 0)))
	blue.hp = 400.0
	var a := blue.data.abilities[0]
	_cast(sim, 0)
	check_near(red.hp, red.max_hp - a.damage, 0.01, "Cleave hit the hero")
	check_near(blue.hp, 400.0 + a.heal_per_hero + 2 * a.heal_per_minion, 0.01, "healed per hero and trooper hit")


func test_mercy_doubles_healing_from_the_hero() -> void:
	var sim := _sim(AVERY, JOSE)
	var blue := sim.heroes[0]
	place(sim.heroes[1], Vector2(0, 0))
	_still(sim.heroes[1])
	_level_pick(sim, blue, 2, [0])
	blue.hp = 400.0
	_cast(sim, 0)
	check_near(blue.hp, 400.0 + 2.0 * blue.data.abilities[0].heal_per_hero, 0.01, "Mercy: double heal from the hero")


func test_steadfast_rewards_standing_still() -> void:
	var sim := _sim(AVERY, JOSE)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level_pick(sim, blue, 2, [1])
	var moving := Abilities.basic_damage(sim, blue, red, 100.0)
	check_near(moving, 100.0, 0.01, "no bonus right away")
	place(red, Vector2(0, 30))
	run_ticks(sim, 40)
	check_near(Abilities.basic_damage(sim, blue, red, 100.0), 120.0, 0.01, "+20% after standing still for 1 s")


func test_oath_shields_and_speeds_up() -> void:
	var sim := _sim(AVERY, JOSE)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	place(red, Vector2(0, 30))
	_level(sim, blue, 3)
	_cast(sim, 1)
	var a := blue.data.abilities[1]
	check_near(blue.shield_hp, blue.max_hp * a.shield_fraction, 0.01, "shield worth 20% max HP")
	check_near(blue.move_speed(), blue.data.move_speed * (1.0 + a.move_speed_bonus), 0.01, "+25% move speed")
	var hp := blue.hp
	sim.apply_damage(blue, 100.0, red)
	check_near(blue.hp, hp, 0.01, "shield soaked the hit")
	run_ticks(sim, int(5.0 / sim.dt))
	check(blue.shield_hp == 0.0 and blue.move_speed() == blue.data.move_speed, "both wear off")


func test_shatter_bursts_when_the_shield_breaks_early() -> void:
	var sim := _sim(AVERY, JOSE)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level_pick(sim, blue, 4, [0, 0])
	_still(red)
	place(red, Vector2(0, 0))
	_cast(sim, 1)
	sim.apply_damage(blue, blue.shield_hp + 10.0, red)
	check(_count(&"shield_shattered") == 1, "the shield shattered")
	check_near(red.hp, red.max_hp - blue.perk_with(&"shatter").special_value, 0.01, "and hurt the hero next to her")


func test_charge_knocks_back_with_the_next_slash() -> void:
	var sim := _sim(AVERY, JOSE)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level_pick(sim, blue, 4, [0, 1])
	_still(red)
	place(red, Vector2(0, 0))
	_cast(sim, 1)
	var start := red.pos
	run_until(sim, func() -> bool: return red.hp < red.max_hp, 40)
	run_ticks(sim, 10)
	check(red.pos.distance_to(start) > 2.0, "knocked back by the slash (moved %.1f m)" % red.pos.distance_to(start))


func test_judgment_blade_stuns_and_pulls() -> void:
	var sim := _sim(AVERY, JOSE)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level(sim, blue, 5)
	_still(red)
	place(red, Vector2(0, 5))
	_cast(sim, 2)
	run_until(sim, func() -> bool: return red.hp < red.max_hp, 20)
	check(red.is_stunned(sim.time), "stunned")
	check_near(red.max_hp - red.hp, blue.data.abilities[2].damage, 0.01, "took the blade's damage")
	run_ticks(sim, 12)
	check(red.pos.distance_to(blue.pos) < 2.2, "pulled next to Avery (%.1f m away)" % red.pos.distance_to(blue.pos))


func test_judgment_blade_can_be_dodged() -> void:
	var sim := _sim(AVERY, JOSE)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level(sim, blue, 5)
	_still(red)
	place(red, Vector2(0, 7))
	_cast(sim, 2)
	run_ticks(sim, 30, Vector2.ZERO, Vector2.RIGHT)
	check(red.hp == red.max_hp and not red.is_stunned(sim.time), "side-stepped the skillshot")


func test_judgment_and_sanctuary() -> void:
	var sim := _sim(AVERY, JOSE)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level_pick(sim, blue, 6, [0, 0, 0])
	_still(red)
	place(red, Vector2(0, 5))
	_cast(sim, 2)
	run_until(sim, func() -> bool: return red.is_stunned(sim.time), 20)
	check_near(Abilities.basic_damage(sim, blue, red, 100.0), 160.0, 0.01, "Judgment: +60% on the pulled hero")
	check_near(Abilities.basic_damage(sim, blue, red, 100.0), 100.0, 0.01, "only once")
	var sim2 := _sim(AVERY, JOSE)
	var b2 := sim2.heroes[0]
	_level_pick(sim2, b2, 6, [0, 0, 1])
	_still(sim2.heroes[1])
	place(sim2.heroes[1], Vector2(0, 5))
	_cast(sim2, 2)
	run_until(sim2, func() -> bool: return sim2.heroes[1].is_stunned(sim2.time), 20)
	check(b2.shield_hp > 0.0, "Sanctuary: landing the blade shields Avery")


# --- Jose -----------------------------------------------------------------------

func test_jose_basic_attack_grows_with_level() -> void:
	var sim := _sim(JOSE, AVERY)
	var blue := sim.heroes[0]
	_level(sim, blue, 5)
	check_near(blue.attack_damage, blue.data.attack_damage * (1.0 + 4 * blue.data.attack_damage_per_level), 0.01, "+8% basic damage per level")


func test_spin_dash_twice_only_after_a_hit() -> void:
	var sim := _sim(JOSE, AVERY)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	place(blue, Vector2(0, -12))
	place(red, Vector2(0, 30))
	_cast(sim, 0, Vector2.RIGHT)
	run_ticks(sim, 10)
	check_near(blue.pos.distance_to(Vector2(0, -12)), blue.data.abilities[0].distance, 0.15, "dashed 3.5 m")
	_cast(sim, 0, Vector2.RIGHT)
	check(_count(&"ability_cast") == 1, "missed volley: no second dash")
	var sim2 := _sim(JOSE, AVERY)
	var b2 := sim2.heroes[0]
	var r2 := sim2.heroes[1]
	place(b2, Vector2(0, -6))
	place(r2, Vector2(3.5, -2))
	_still(r2)
	b2.attack_damage = 0.0
	_cast(sim2, 0, Vector2.RIGHT)
	run_ticks(sim2, 10)
	check_near(r2.hp, r2.max_hp - b2.data.abilities[0].damage, 0.01, "the volley hit")
	var at := b2.pos
	_cast(sim2, 0, Vector2.LEFT)
	run_ticks(sim2, 10)
	check(b2.pos.distance_to(at) > 3.0, "second dash")
	check(r2.hp < r2.max_hp - b2.data.abilities[0].damage * 1.5, "with a second volley")
	_cast(sim2, 0, Vector2.LEFT)
	check(_count(&"ability_cast") == 2, "no third dash")


func test_smooth_operator_crits_after_a_dash() -> void:
	var sim := _sim(JOSE, AVERY)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level_pick(sim, blue, 2, [0])
	place(red, Vector2(0, 30))
	_cast(sim, 0, Vector2.RIGHT)
	run_ticks(sim, 8)
	check_near(Abilities.basic_damage(sim, blue, red, 100.0), 175.0, 0.01, "next basic crits")
	check_near(Abilities.basic_damage(sim, blue, red, 100.0), 100.0, 0.01, "just once")


func test_sweet_talk_charges_up() -> void:
	var sim := _sim(JOSE, AVERY)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level(sim, blue, 3)
	blue.attack_damage = 0.0
	_still(red)
	place(red, Vector2(0, 6))
	var a := blue.data.abilities[1]
	_cast(sim, 1)
	check(blue.is_charging(), "charging")
	run_ticks(sim, int(a.charge_time / sim.dt) + 1)
	_cast(sim, 1)
	check(not blue.is_charging() and blue.cooldowns[1] > 0.0, "released, cooldown started")
	run_until(sim, func() -> bool: return red.hp < red.max_hp, 20)
	check_near(red.max_hp - red.hp, a.max_damage, 0.01, "full charge: full damage")
	var sim2 := _sim(JOSE, AVERY)
	var b2 := sim2.heroes[0]
	var r2 := sim2.heroes[1]
	_level(sim2, b2, 3)
	b2.attack_damage = 0.0
	place(r2, Vector2(0, 6))
	_still(r2)
	_cast(sim2, 1)
	_cast(sim2, 1)
	run_until(sim2, func() -> bool: return r2.hp < r2.max_hp, 20)
	check(r2.max_hp - r2.hp < a.damage + 10.0, "quick tap: little damage (%.0f)" % (r2.max_hp - r2.hp))


func test_sweet_talk_fires_by_itself() -> void:
	var sim := _sim(JOSE, AVERY)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level(sim, blue, 3)
	blue.attack_damage = 0.0
	_still(red)
	place(red, Vector2(0, 6))
	_cast(sim, 1)
	run_ticks(sim, int(3.0 / sim.dt))
	check(not blue.is_charging() and red.hp < red.max_hp, "held too long: it fires")


func test_lady_killer_and_last_call() -> void:
	var sim := _sim(JOSE, AVERY)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level_pick(sim, blue, 4, [0, 0])
	blue.attack_damage = 0.0
	_still(red)
	place(red, Vector2(0, 6))
	_cast(sim, 1)
	_cast(sim, 1)
	run_until(sim, func() -> bool: return red.hp < red.max_hp, 20)
	check_near(Abilities.basic_damage(sim, blue, red, 100.0), 125.0, 0.01, "Lady Killer: marked hero takes +25%")
	var sim2 := _sim(JOSE, AVERY)
	var b2 := sim2.heroes[0]
	_level_pick(sim2, b2, 4, [0, 1])
	b2.attack_damage = 0.0
	place(sim2.heroes[1], Vector2(0, 30))
	var m := sim2.spawn_minion(melee(), MatchSim.RED, Vector2(0, 3))
	_still(m)
	m.hp = m.max_hp * 0.25
	_cast(sim2, 1)
	_cast(sim2, 1)
	run_until(sim2, func() -> bool: return not m.alive, 20)
	check(not m.alive, "Last Call finished the low trooper")
	var gold := _last(&"gold_awarded")
	check(gold.get("reason") == &"last_hit", "a last hit")
	check_near(gold.get("amount", 0.0), melee().gold_bounty * 2.0 * Pacing.gold_mult(sim2), 0.01, "for double gold")


func test_last_tango_dances_slowly_and_hits_around() -> void:
	var sim := _sim(JOSE, AVERY)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level(sim, blue, 5)
	_still(red)
	place(red, Vector2(0, 0))
	var a := blue.data.abilities[2]
	_cast(sim, 2)
	check(blue.is_channeling(), "dancing")
	var start := blue.pos
	run_ticks(sim, 30, Vector2.LEFT)
	check_near(blue.pos.distance_to(start), blue.data.move_speed * a.move_mult, 0.2, "moves slowly while dancing")
	run_ticks(sim, int(a.duration / sim.dt) + 5)
	check(_count(&"channel_pulse") == a.pulses, "six bursts")
	check(not blue.is_channeling(), "the dance ends")


func test_dash_ends_the_dance_unless_showstopper() -> void:
	var sim := _sim(JOSE, AVERY)
	var blue := sim.heroes[0]
	place(sim.heroes[1], Vector2(0, 30))
	_level_pick(sim, blue, 6, [0, 0, 1])
	_cast(sim, 2)
	_cast(sim, 0, Vector2.RIGHT)
	check(not blue.is_channeling(), "a dash ends the dance")
	var sim2 := _sim(JOSE, AVERY)
	var b2 := sim2.heroes[0]
	place(sim2.heroes[1], Vector2(0, 30))
	_level_pick(sim2, b2, 6, [0, 0, 0])
	_cast(sim2, 2)
	_cast(sim2, 0, Vector2.RIGHT)
	check(b2.is_channeling(), "Showstopper: still dancing after the dash")


func test_bloody_tango_heals() -> void:
	var sim := _sim(JOSE, AVERY)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level_pick(sim, blue, 6, [0, 0, 1])
	_still(red)
	blue.attack_damage = 0.0
	place(red, Vector2(0, 0))
	blue.hp = 200.0
	_cast(sim, 2)
	run_ticks(sim, int(3.5 / sim.dt))
	var dealt := red.max_hp - red.hp
	check(dealt > 0.0, "the dance hit")
	check_near(blue.hp, 200.0 + dealt * 0.25, 1.0, "healed for 25% of it")


# --- Jack -----------------------------------------------------------------------

func test_cloak_passes_through_and_teleports() -> void:
	var sim := _sim(JACK, AVERY)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_still(red)
	place(red, Vector2(0, 4))
	var m := sim.spawn_minion(melee(), MatchSim.RED, Vector2(0.3, 1))
	_still(m)
	m.max_hp = 1000.0
	m.hp = 1000.0
	blue.attack_damage = 0.0
	var a := blue.data.abilities[0]
	_cast(sim, 0)
	run_ticks(sim, 30)
	check_near(m.hp, 1000.0 - a.minion_damage, 0.01, "the cloak hit the trooper")
	check_near(red.hp, red.max_hp - a.damage, 0.01, "and passed on to the hero")
	_cast(sim, 0)
	check(_count(&"teleported") == 1, "teleported")
	check_near(blue.pos.distance_to(Vector2(0, -2 + a.reach)), 0.0, 0.3, "to where the cloak landed")


func test_vanish_is_immune_then_bursts() -> void:
	var sim := _sim(JACK, AVERY)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level(sim, blue, 3)
	_still(red)
	place(red, Vector2(0, 0))
	_cast(sim, 1)
	check(blue.is_vanished(), "vanished")
	var hp := blue.hp
	sim.apply_damage(blue, 200.0, red)
	check(blue.hp == hp, "immune in the shadows")
	check(not CombatSystem.is_valid_target(sim, red, blue), "and can't be targeted")
	check_near(blue.move_speed(), blue.data.move_speed * blue.data.abilities[1].move_mult, 0.01, "moves very slowly")
	_cast(sim, 1)
	check(not blue.is_vanished(), "recast bursts out")
	check_near(red.hp, red.max_hp - blue.data.abilities[1].damage, 0.01, "the burst hit")


func test_vanish_bursts_by_itself() -> void:
	var sim := _sim(JACK, AVERY)
	var blue := sim.heroes[0]
	_level(sim, blue, 3)
	place(sim.heroes[1], Vector2(0, 30))
	_cast(sim, 1)
	run_ticks(sim, int((blue.data.abilities[1].duration + 0.2) / sim.dt))
	check(not blue.is_vanished() and _count(&"vanish_burst") == 1, "out of the shadows when time runs out")


func test_cloak_vanish_teleport_combo() -> void:
	var sim := _sim(JACK, AVERY)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level(sim, blue, 3)
	blue.attack_damage = 0.0
	_still(red)
	place(red, Vector2(1.2, 5))
	_cast(sim, 0)
	run_ticks(sim, 2)
	_cast(sim, 1)
	run_ticks(sim, 25)
	var before := red.hp
	_cast(sim, 0)
	check(not blue.is_vanished(), "teleporting out of the shadows")
	check(_count(&"vanish_burst") == 1 and red.hp < before, "bursts at the cloak")


func test_smoke_and_mirrors_and_vanishing_act() -> void:
	var sim := _sim(JACK, AVERY)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level_pick(sim, blue, 4, [0, 0])
	_still(red)
	place(red, Vector2(0, 0))
	_cast(sim, 1)
	_cast(sim, 1)
	check(Abilities.basic_damage(sim, red, blue, 50.0) < 0.0, "Smoke and Mirrors: the hero's basics miss")
	var sim2 := _sim(JACK, AVERY)
	var b2 := sim2.heroes[0]
	var r2 := sim2.heroes[1]
	_level_pick(sim2, b2, 4, [0, 1])
	_still(r2)
	place(r2, Vector2(0, 0))
	b2.cooldowns[0] = 10.0
	_cast(sim2, 1)
	_cast(sim2, 1)
	check(b2.cooldowns[0] < 10.0 - b2.ability_cooldown(0) * 0.5 + 0.1, "Vanishing Act: half the cloak cooldown back")


func test_misdirection_shakes_troopers() -> void:
	var sim := _sim(JACK, AVERY)
	var blue := sim.heroes[0]
	_level_pick(sim, blue, 2, [1])
	place(sim.heroes[1], Vector2(0, 30))
	var m := sim.spawn_minion(melee(), MatchSim.RED, Vector2(0, 0))
	_cast(sim, 0, Vector2.LEFT)
	run_ticks(sim, 10)
	_cast(sim, 0)
	check(not CombatSystem.is_valid_target(sim, m, blue), "the trooper loses Jack")
	check(CombatSystem.is_valid_target(sim, sim.heroes[1], blue), "the hero doesn't")
	run_ticks(sim, int(2.0 / sim.dt))
	check(CombatSystem.is_valid_target(sim, m, blue), "until the decoy fades")


func test_sleight_of_hand_pays_more_for_cloak_kills() -> void:
	var sim := _sim(JACK, AVERY)
	var blue := sim.heroes[0]
	_level_pick(sim, blue, 2, [0])
	place(sim.heroes[1], Vector2(0, 30))
	var m := sim.spawn_minion(melee(), MatchSim.RED, Vector2(0, 3))
	_still(m)
	m.hp = 10.0
	_cast(sim, 0)
	run_until(sim, func() -> bool: return not m.alive, 20)
	check_near(_last(&"gold_awarded").get("amount", 0.0), melee().gold_bounty * 1.5 * Pacing.gold_mult(sim), 0.01, "+50% gold")


func test_encore_copies_the_enemy_ult() -> void:
	var sim := _sim(JACK, AVERY)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level(sim, blue, 5)
	check(red.level == 1, "Avery hasn't even unlocked her ult")
	_still(red)
	place(red, Vector2(0, 5))
	_cast(sim, 2)
	check(_last(&"ability_cast").get("copied") == &"judgment_blade", "Jack casts Judgment Blade")
	run_until(sim, func() -> bool: return red.is_stunned(sim.time), 20)
	run_ticks(sim, 12)
	check(red.pos.distance_to(blue.pos) < 2.2, "and pulls Avery to himself")
	check_near(blue.cooldowns[2], blue.ability_cooldown(2) - 33 * sim.dt, 0.5, "on Jack's own cooldown")
	var sim2 := _sim(JACK, JOSE)
	var b2 := sim2.heroes[0]
	_level(sim2, b2, 5)
	_cast(sim2, 2)
	check(b2.is_channeling() and b2.channel.effect == &"last_tango", "against Jose, Jack dances")


func test_quick_study_and_stage_presence() -> void:
	var sim := _sim(JACK, AVERY)
	var blue := sim.heroes[0]
	_level_pick(sim, blue, 6, [0, 0, 0])
	check_near(blue.ability_cooldown(2), blue.data.abilities[2].cooldown * 0.75, 0.01, "Quick Study: -25% cooldown")
	var sim2 := _sim(JACK, AVERY)
	var b2 := sim2.heroes[0]
	place(sim2.heroes[1], Vector2(0, 30))
	_level_pick(sim2, b2, 6, [0, 0, 1])
	_cast(sim2, 2)
	check_near(b2.shield_hp, b2.max_hp * 0.15, 0.01, "Stage Presence: a shield")
	var m := sim2.spawn_minion(melee(), MatchSim.RED, Vector2(0, 10))
	check_near(Items.outgoing(sim2, b2, m, 100.0, &"ability"), 125.0, 0.01, "and +25% ability damage")
