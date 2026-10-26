extends TestCase
## Phase II: nine levels, ultimates at 6, automatic hero passives at 3 and 8, and the
## side changes that came with them (Poppet's lifesteal, slower Debt, Latch Cloud).

const AVERY := 0
const JOSE := 1
const HUDDLE := 5
const POPPET := 6
const TOT := 7


func _level(sim: MatchSim, h: HeroState, lv: int) -> void:
	Leveling.gain(sim, h, float(sim.config.level_xp[lv - 1]) - h.xp + 0.01)


func test_nine_levels_with_a_rising_xp_table() -> void:
	var xp := MatchController.CONFIG.level_xp
	check(xp.size() == 9, "nine levels (got %d)" % xp.size())
	for i in range(1, xp.size()):
		check(xp[i] > xp[i - 1], "level %d needs more XP than level %d" % [i + 1, i])
	check(Leveling.ULT_LEVEL == 6 and Leveling.ABILITY_LEVELS == [1, 3, 6], "ultimate at level 6")
	check(Leveling.PERK_LEVELS == [2, 4, 7] and Leveling.PASSIVE_LEVELS == [3, 8], "perks at 2, 4, 7; passives at 3, 8")
	check(MatchController.CONFIG.siege_scroll_level == 7 and MatchController.CONFIG.masterwork_level == 8, "siege scrolls at 7, Masterworks at 8")


func test_every_hero_has_two_passives() -> void:
	for h in MatchController.HEROES:
		check(h.passives.size() == 2, "%s has a Lv3 and a Lv8 passive" % h.display_name)
		for p in h.passives:
			check(p != null and p.display_name != "" and p.summary != "", "%s: passive named and described" % h.display_name)


func test_passives_arrive_at_three_and_eight() -> void:
	var sim := new_sim(false, AVERY, JOSE)
	var avery := sim.heroes[0]
	_level(sim, avery, 2)
	check(avery.owned_passives().is_empty(), "nothing at level 2")
	var before := avery.max_hp
	_level(sim, avery, 3)
	var growth := avery.data.hp_per_level
	check_near(avery.max_hp - before, growth + 200.0, 0.01, "Iron Will: +200 max HP at level 3")
	_level(sim, avery, 7)
	var armor := avery.armor
	before = avery.max_hp
	_level(sim, avery, 8)
	check(avery.owned_passives().size() == 2, "both passives at level 8")
	check_near(avery.max_hp - before, growth + 250.0, 0.01, "Bastion: +250 max HP")
	check_near(avery.armor - armor, 10.0, 0.01, "and +10 Armor")


func test_jose_passives_speed_up_attacks() -> void:
	var sim := new_sim(false, JOSE, AVERY)
	var jose := sim.heroes[0]
	var base := jose.attack_interval
	_level(sim, jose, 3)
	check_near(jose.attack_interval, jose.data.attack_interval / 1.15, 0.0001, "Quick Draw: +15% attack speed")
	_level(sim, jose, 8)
	check_near(jose.attack_interval, jose.data.attack_interval / 1.25, 0.0001, "Dead Eye: +10% more")
	check(jose.attack_interval < base, "faster than at level 1")


func test_level_up_callout_names_the_passive() -> void:
	var sim := new_sim(false, AVERY, JOSE)
	var got := []
	sim.sim_event.connect(func(type: StringName, data: Dictionary) -> void:
		if type == &"level_up" and data.has("passive"):
			got.append(data.passive))
	_level(sim, sim.heroes[0], 8)
	check(got == ["Iron Will", "Bastion"], "level_up names the passive (got %s)" % [got])


func test_crown_level_surges_twice_as_hard() -> void:
	var sim := new_sim(false, AVERY, JOSE)
	var avery := sim.heroes[0]
	_level(sim, avery, 8)
	avery.hp = avery.max_hp * 0.4
	var hp := avery.hp
	var old_max := avery.max_hp
	_level(sim, avery, 9)
	check(avery.level == Leveling.CROWN_LEVEL, "reached the crown level")
	var expected := hp + (avery.max_hp - old_max) + avery.max_hp * sim.config.level_up_heal_fraction * 2.0
	check_near(avery.hp, expected, 0.5, "the crown level-up heals twice as much")


func test_poppet_lifesteal_grows_with_her_passives() -> void:
	var sim := new_sim(false, POPPET, AVERY)
	var poppet := sim.heroes[0]
	check_near(Items.hero_lifesteal(poppet), 0.10, 0.0001, "10% lifesteal from the start")
	_level(sim, poppet, 3)
	check_near(Items.hero_lifesteal(poppet), 0.14, 0.0001, "Tight Seams: 14%")
	_level(sim, poppet, 8)
	poppet.hp = poppet.max_hp * 0.5
	check_near(Items.hero_lifesteal(poppet), 0.14, 0.0001, "Restitched waits until she is low")
	poppet.hp = poppet.max_hp * 0.39
	check_near(Items.hero_lifesteal(poppet), 0.28, 0.0001, "below 40%: doubled")
	var avery := sim.heroes[1]
	place(avery, poppet.pos + Vector2(0, 1.0))
	var before := poppet.hp
	var dealt := sim.apply_damage(avery, 50.0, poppet, &"basic")
	Items.after_hit(sim, poppet, avery, dealt, 50.0, &"basic")
	check(poppet.hp > before, "her basic attacks heal her")
	check_near(Items.hero_lifesteal(sim.heroes[1]), 0.0, 0.0001, "nobody else has it")


func test_debt_drains_slower_and_slower_still_at_eight() -> void:
	var sim := new_sim(false, TOT, JOSE)
	var tot := sim.heroes[0]
	check_near(Kits.DEBT_DRAIN, 30.0, 0.001, "Debt drains 30 HP a second")
	_level(sim, tot, 8)
	tot.debt = 300.0
	tot.hp = tot.max_hp
	var before := tot.debt
	run_ticks(sim, int(1.0 / sim.dt))
	check_near(before - tot.debt, 30.0 * 0.75, 1.5, "Deferred Tribute: 25% slower")


func test_latch_cloud_flies_through_troopers_to_the_hero() -> void:
	var sim := new_sim(false, HUDDLE, JOSE)
	var huddle := sim.heroes[0]
	var jose := sim.heroes[1]
	place(huddle, Vector2(0, 0))
	place(jose, Vector2(0, 5))
	var m := sim.spawn_minion(melee(), MatchSim.RED, Vector2(0, 2.5))
	var latched := []
	sim.sim_event.connect(func(type: StringName, data: Dictionary) -> void:
		if type == &"latched":
			latched.append(data.target))
	var cmd := PlayerCommand.new()
	cmd.cast_slot = 0
	cmd.aim = Vector2(0, 1)
	sim.step([cmd, null])
	run_ticks(sim, int(1.0 / sim.dt))
	check(not latched.has(m.id), "the trooper in the way isn't latched")
	check(jose.latched_until > sim.time, "the hero behind it is")
	var ticks := []
	sim.sim_event.connect(func(type: StringName, data: Dictionary) -> void:
		if type == &"dot_tick" and data.ability == &"latch_cloud":
			ticks.append(data.amount))
	run_ticks(sim, int(3.0 / sim.dt))
	check(ticks.size() >= 4, "damage ticks are announced (got %d)" % ticks.size())
	check(jose.buzz > 0, "and Buzz stacks up")


func test_a_missed_latch_cloud_hangs_in_the_air() -> void:
	var sim := new_sim(false, HUDDLE, JOSE)
	var huddle := sim.heroes[0]
	var jose := sim.heroes[1]
	place(huddle, Vector2(0, 0))
	place(jose, Vector2(4, 30))
	var cmd := PlayerCommand.new()
	cmd.cast_slot = 0
	cmd.aim = Vector2(0, 1)
	sim.step([cmd, null])
	run_ticks(sim, int(1.0 / sim.dt))
	check(sim.clouds.size() == 1, "the miss lingers")
	var cloud: Dictionary = sim.clouds[0]
	place(jose, cloud.pos + Vector2(0.4, 0))
	run_ticks(sim, 2)
	check(sim.clouds.is_empty() and jose.latched_until > sim.time, "walking into it latches")
	place(jose, Vector2(4, 30))
	jose.latched_until = 0.0
	huddle.cooldowns[0] = 0.0
	sim.step([cmd, null])
	run_ticks(sim, int(1.0 / sim.dt))
	check(sim.clouds.size() == 1, "another miss")
	run_ticks(sim, int(2.2 / sim.dt))
	check(sim.clouds.is_empty() and jose.latched_until <= sim.time, "and it fades after 2 s")
