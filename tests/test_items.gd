extends TestCase
## Item effects (Items), damage kinds, healing and selling.


func _item(id: StringName) -> ItemData:
	for item in MatchController.ITEMS:
		if item.id == id:
			return item
	return null


## Vanguard (blue) vs Scout (red), no waves, both holding the given items.
func _sim(blue_items: Array = [], red_items: Array = [], red_hero := 1) -> MatchSim:
	var sim := new_sim(false, 0, red_hero)
	for id: StringName in blue_items:
		_give(sim.heroes[0], id)
	for id: StringName in red_items:
		_give(sim.heroes[1], id)
	place(sim.heroes[0], Vector2(0, -20))
	place(sim.heroes[1], Vector2(0, 20))
	return sim


func _give(h: HeroState, id: StringName) -> void:
	h.items.append(_item(id))
	h.recompute_stats()
	h.hp = h.max_hp


func test_damage_kinds_and_ability_bonuses() -> void:
	var sim := _sim([&"titan_core"])
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	var hp := red.hp
	sim.apply_damage(red, 100.0, blue, &"basic")
	check_near(hp - red.hp, 100.0, 0.01, "Titan Core leaves basic attacks alone")
	hp = red.hp
	sim.apply_damage(red, 100.0, blue, &"ability")
	check_near(hp - red.hp, 135.0, 0.01, "+35% ability damage")


func test_trooper_cleaver_and_siege_banner() -> void:
	var sim := _sim([&"trooper_cleaver", &"siege_banner"])
	var blue := sim.heroes[0]
	var m := sim.spawn_minion(melee(), MatchSim.RED, Vector2(0, 0))
	var hp := m.hp
	sim.apply_damage(m, 10.0, blue)
	check_near(hp - m.hp, 14.0, 0.01, "+40% against troopers")
	var tower := sim.structures_of(MatchSim.RED)[0]
	hp = tower.hp
	sim.apply_damage(tower, 100.0, blue)
	check_near(hp - tower.hp, 115.0 * (1.0 - Pacing.structure_resist(sim, tower)), 0.01, "+15% against structures (before tower resist)")


func test_warding_cloak_resists_abilities_only() -> void:
	var sim := _sim([], [&"warding_cloak"])
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	var hp := red.hp
	sim.apply_damage(red, 100.0, blue, &"ability")
	check_near(hp - red.hp, 75.0, 0.01, "-25% ability damage")
	hp = red.hp
	sim.apply_damage(red, 100.0, blue, &"item")
	check_near(hp - red.hp, 75.0, 0.01, "item damage counts too")
	hp = red.hp
	sim.apply_damage(red, 100.0, blue, &"basic")
	check_near(hp - red.hp, 100.0, 0.01, "basic attacks are not resisted")


func test_aegis_blocks_one_big_ability_then_recharges() -> void:
	var sim := _sim([], [&"aegis_mirror"])
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	var hp := red.hp
	sim.apply_damage(red, 40.0, blue, &"ability")
	check_near(hp - red.hp, 40.0, 0.01, "small hits are not blocked")
	hp = red.hp
	sim.apply_damage(red, 120.0, blue, &"ability")
	check_near(hp - red.hp, 0.0, 0.01, "a big hit is blocked")
	hp = red.hp
	sim.apply_damage(red, 120.0, blue, &"ability")
	check_near(hp - red.hp, 120.0, 0.01, "the next one lands while it recharges")
	run_ticks(sim, int(30.5 / sim.dt))
	hp = red.hp
	sim.apply_damage(red, 120.0, blue, &"ability")
	check_near(hp - red.hp, 0.0, 0.01, "ready again after 30 s")


func test_bloodthirst_lifesteal_and_low_hp_attack_speed() -> void:
	var sim := _sim([&"bloodthirst_blade"])
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	blue.hp = blue.max_hp * 0.8
	var hp := blue.hp
	sim.apply_damage(red, 100.0, blue, &"basic")
	check_near(blue.hp - hp, 12.0, 0.01, "basic attacks heal 12%")
	hp = blue.hp
	sim.apply_damage(red, 100.0, blue, &"ability")
	check_near(blue.hp - hp, 0.0, 0.01, "abilities don't lifesteal")
	var normal := blue.current_interval(sim.time)
	blue.hp = blue.max_hp * 0.4
	check_near(blue.current_interval(sim.time), normal / 1.2, 0.001, "+20% attack speed below half health")


func test_thorncut_wounds_cut_healing() -> void:
	var sim := _sim([&"thorncut"], [&"bloodthirst_blade"])
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	red.hp = red.max_hp * 0.5
	check_near(sim.heal(red, 100.0), 100.0, 0.01, "full healing before Wounds")
	sim.apply_damage(red, 10.0, blue, &"basic")
	check(sim.time < red.wounds_until, "a hit applies Wounds")
	check_near(sim.heal(red, 100.0), 50.0, 0.01, "Wounds halve healing")
	run_ticks(sim, int(4.5 / sim.dt))
	check_near(sim.heal(red, 100.0), 100.0, 0.01, "Wounds wear off after 4 s")


func test_wounds_cut_base_healing_too() -> void:
	var sim := _sim()
	var red := sim.heroes[1]
	var core := sim.structures_of(MatchSim.RED)[2]
	place(red, core.pos + Vector2(0, -3))
	red.hp = red.max_hp * 0.5
	var hp := red.hp
	run_ticks(sim, 10)
	var full := red.hp - hp
	red.wounds_amount = 0.5
	red.wounds_until = sim.time + 10.0
	hp = red.hp
	run_ticks(sim, 10)
	check_near(red.hp - hp, full * 0.5, 0.5, "base healing is halved by Wounds")


func test_spark_band_after_a_cast() -> void:
	var sim := _sim([&"spark_band"])
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	var hp := red.hp
	sim.apply_damage(red, 10.0, blue, &"basic")
	check_near(hp - red.hp, 10.0, 0.01, "no bonus without a cast")
	Items.on_cast(sim, blue, 0)
	hp = red.hp
	sim.apply_damage(red, 10.0, blue, &"basic")
	check_near(hp - red.hp, 55.0, 0.01, "+45 on the next basic attack")
	hp = red.hp
	sim.apply_damage(red, 10.0, blue, &"basic")
	check_near(hp - red.hp, 10.0, 0.01, "only once per cast")


func test_overcharge_gem_on_big_ability_hits() -> void:
	var sim := _sim([&"overcharge_gem"], [&"warding_cloak"])
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	var hp := red.hp
	sim.apply_damage(red, 50.0, blue, &"ability")
	check_near(hp - red.hp, 56.0 * 0.75, 0.01, "small hit: just +12%, then resisted")
	hp = red.hp
	sim.apply_damage(red, 100.0, blue, &"ability")
	var expected := 112.0 * 0.75 + red.max_hp * 0.06 * 0.75
	check_near(hp - red.hp, expected, 0.01, "big hit adds 6% max HP (both resisted)")


func test_stormcrown_storm_and_ult_cooldown() -> void:
	var sim := _sim([&"stormcrown"])
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	blue.level = 6
	check_near(blue.ability_cooldown(2), blue.data.abilities[2].cooldown * 0.75, 0.01, "-25% ultimate cooldown")
	check_near(blue.ability_cooldown(1), blue.data.abilities[1].cooldown, 0.01, "other abilities unchanged")
	place(blue, Vector2(0, -3))
	place(red, Vector2(0, 3))
	red.attack_damage = 0.0
	blue.attack_damage = 0.0
	var hp := red.hp
	Items.on_cast(sim, blue, 2)
	run_ticks(sim, int(1.7 / sim.dt))
	check_near(hp - red.hp, red.max_hp * 0.07 * 3.0, 1.0, "three strikes of 7% max HP")


func test_reapers_rhythm_frenzy() -> void:
	var sim := _sim([&"reapers_rhythm"])
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	blue.hp = blue.max_hp * 0.5
	for i in 5:
		sim.apply_damage(red, 10.0, blue, &"basic")
	check(blue.frenzy_left == 5, "the 5th attack starts a Frenzy")
	var hp := blue.hp
	var red_hp := red.hp
	sim.apply_damage(red, 40.0, blue, &"basic")
	check_near(blue.hp - hp, 10.0, 0.01, "Frenzy attacks heal 25%")
	check(sim.time < red.shred_until, "and shred the enemy hero")
	red_hp = red.hp
	sim.apply_damage(red, 100.0, blue, &"ability")
	check_near(red_hp - red.hp, 115.0, 0.01, "shredded: +15% damage from you")
	for i in 4:
		sim.apply_damage(red, 1.0, blue, &"basic")
	check(blue.frenzy_left == 0, "Frenzy lasts five attacks")


func test_selling_refunds_half_and_frees_the_slot() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	blue.deck = MatchController.deck_from(MatchController.DEFAULT_DECK)
	blue.gold = 2000.0
	var cmd := PlayerCommand.new()
	cmd.buy_slot = 1
	sim.step([cmd, null])
	var charm := blue.deck[1]
	check(blue.owns(charm), "bought")
	var gold := blue.gold
	cmd = PlayerCommand.new()
	cmd.sell_slot = 1
	sim.step([cmd, null])
	check(not blue.owns(charm), "sold")
	check_near(blue.gold - gold, charm.cost * 0.5 + MatchController.CONFIG.passive_gold_per_second * sim.dt, 0.01, "half the price back")
	check_near(blue.max_hp, blue.data.max_hp, 0.01, "its stats are gone")
	check(blue.hp <= blue.max_hp, "health is capped to the new maximum")
	check(Economy.sell_problem(sim, blue, 1) != "", "can't sell what you don't own")


func test_bot_sells_an_early_item_for_a_late_one() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	blue.deck = MatchController.bot_deck(blue.data)
	var bot := BotSource.new()
	bot.team = MatchSim.BLUE
	blue.gold = 10000.0
	for i in 12:
		sim.step([bot.build_command(sim), null])
	var late := false
	for item in blue.items:
		late = late or item.tier == ItemData.Tier.LATE
	check(blue.items.size() == MatchController.CONFIG.max_items, "slots full")
	check(late, "bought a late item by selling an early one")
