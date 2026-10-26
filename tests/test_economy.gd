extends TestCase
## Gold, decks and items (GDD 8 and Codex criterion 6).



func _item(id: StringName) -> ItemData:
	for item in MatchController.ITEMS:
		if item.id == id:
			return item
	return null


## A no-wave sim where both heroes hold the default deck.
func _sim() -> MatchSim:
	var sim := MatchSim.new()
	var picks: Array[HeroData] = [MatchController.HEROES[0], MatchController.HEROES[1]]
	var deck := MatchController.deck_from(MatchController.DEFAULT_DECK)
	sim.setup(MatchController.CONFIG, MatchController.ARENA, picks, MatchController.TIERS, {}, [deck, deck])
	place(sim.heroes[0], Vector2(0, -20))
	place(sim.heroes[1], Vector2(0, 20))
	return sim


func _slot(h: HeroState, id: StringName) -> int:
	for i in h.deck.size():
		if h.deck[i].id == id:
			return i
	return -1


func _buy(sim: MatchSim, slot: int) -> void:
	var cmd := PlayerCommand.new()
	cmd.buy_slot = slot
	sim.step([cmd, null])


func test_passive_income() -> void:
	var sim := _sim()
	run_ticks(sim, MatchController.CONFIG.tick_rate * 10)
	check_near(sim.heroes[0].gold, 10.0 * MatchController.CONFIG.passive_gold_per_second, 0.01, "2 gold per second")


func test_deck_rules() -> void:
	var pool := MatchController.ITEMS
	var n := MatchController.CONFIG.deck_size
	check(n == 8, "decks hold eight cards")
	var full := MatchController.deck_from([0, 1, 2, 3, 4, 5, 6, 7])
	check(Economy.is_valid_deck(full, pool, n), "eight distinct items is a valid deck")
	check(not Economy.is_valid_deck(MatchController.deck_from([0, 1, 2, 3, 4, 5, 6]), pool, n), "seven is not")
	check(not Economy.is_valid_deck(MatchController.deck_from([0, 1, 2, 3, 4, 5, 6, 6]), pool, n), "duplicates are not")
	var stranger := ItemData.new()
	var bad := MatchController.deck_from([0, 1, 2, 3, 4, 5, 6])
	bad.append(stranger)
	check(not Economy.is_valid_deck(bad, pool, n), "items outside the pool are not")
	check(Economy.is_valid_deck(MatchController.deck_from(MatchController.DEFAULT_DECK), pool, n), "default deck is valid")
	for id: StringName in MatchController.BOT_DECKS:
		check(Economy.is_valid_deck(MatchController.deck_from(MatchController.BOT_DECKS[id]), pool, n), "%s bot deck is valid" % id)
	check(MatchController.ITEMS.size() >= 12, "pool has at least twelve items")
	var tiers := [0, 0, 0]
	for item in pool:
		tiers[item.tier] += 1
	check(tiers[0] >= 3 and tiers[1] >= 3 and tiers[2] >= 3, "early, mid and late items all exist")


func test_cannot_buy_without_gold() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	_buy(sim, 0)
	check(blue.items.is_empty(), "nothing bought with no gold")
	check(blue.gold >= 0.0, "gold never negative")


func test_buying_spends_gold_and_applies_stats() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	blue.gold = 1200.0
	blue.hp = blue.max_hp - 100.0
	_buy(sim, _slot(blue, &"mending_charm"))
	check(blue.owns(_item(&"mending_charm")), "bought Mending Charm")
	check_near(blue.gold, 1200.0 - 175.0 + MatchController.CONFIG.passive_gold_per_second * sim.dt, 0.01, "paid 175")
	check_near(blue.max_hp, blue.data.max_hp * 1.06, 0.01, "+6% max HP")
	check_near(blue.hp, blue.max_hp - 100.0, 0.01, "extra max HP is added to current HP too")
	_buy(sim, _slot(blue, &"trooper_cleaver"))
	check_near(blue.attack_damage, blue.data.attack_damage + 3.0, 0.01, "+3 ATK")


func test_fleet_sandals_double_out_of_combat() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	blue.gold = 400.0
	blue.deck = MatchController.deck_from([2, 0, 1, 3, 4, 5, 6, 7])
	_buy(sim, 0)
	check_near(blue.move_speed(), blue.data.move_speed * 1.16, 0.001, "+16% while out of hero combat")
	sim.apply_damage(blue, 10.0, sim.heroes[1])
	blue._now = sim.time
	check_near(blue.move_speed(), blue.data.move_speed * 1.08, 0.001, "+8% in a fight")


func test_no_duplicates_and_three_item_cap() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	blue.gold = 5000.0
	_buy(sim, 0)
	_buy(sim, 0)
	check(blue.items.size() == 1, "can't buy the same item twice")
	for slot in range(1, 6):
		_buy(sim, slot)
	check(blue.items.size() == MatchController.CONFIG.max_items, "three items at most (got %d)" % blue.items.size())
	check(Economy.buy_problem(sim, blue, 5) != "", "a fourth purchase is refused")


func test_cards_outside_the_deck_cannot_be_bought() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	blue.gold = 5000.0
	_buy(sim, MatchController.CONFIG.deck_size)
	_buy(sim, -1)
	check(blue.items.is_empty(), "only the slots of your own deck")


func test_minion_gold_for_being_nearby() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	var radius := MatchController.CONFIG.minion_gold_radius
	var tower := sim.structures_of(MatchSim.BLUE)[0]
	var near := sim.spawn_minion(melee(), MatchSim.RED, blue.pos + Vector2(radius - 0.5, 0))
	var before_red := red.gold
	sim.apply_damage(near, near.max_hp, tower)
	check_near(blue.gold, melee().gold_bounty, 0.01, "an enemy minion dying within the radius pays, whoever killed it")
	check_near(red.gold, before_red, 0.01, "its own side gets nothing")
	var far := sim.spawn_minion(melee(), MatchSim.RED, blue.pos + Vector2(0, radius + 1.0))
	var before := blue.gold
	sim.apply_damage(far, far.max_hp, tower)
	check_near(blue.gold, before, 0.01, "nothing from outside the radius")
	var sniped := sim.spawn_minion(melee(), MatchSim.RED, blue.pos + Vector2(0, radius + 1.0))
	sim.apply_damage(sniped, sniped.max_hp, blue)
	check_near(blue.gold, before + melee().gold_bounty * (1.0 + MatchController.CONFIG.last_hit_bonus), 0.01, "a killing blow from farther away still pays, with the last-hit bonus")
	var own := sim.spawn_minion(melee(), MatchSim.BLUE, blue.pos + Vector2(1, 0))
	before = blue.gold
	sim.apply_damage(own, own.max_hp, red)
	check_near(blue.gold, before, 0.01, "your own minions pay you nothing")


func test_knocked_out_heroes_collect_nothing() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	var m := sim.spawn_minion(melee(), MatchSim.RED, blue.pos + Vector2(1, 0))
	blue.alive = false
	sim.apply_damage(m, m.max_hp, sim.structures_of(MatchSim.BLUE)[0])
	check_near(blue.gold, 0.0, 0.01, "dead heroes don't collect")


func test_knockout_pays_the_other_hero() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	sim.apply_damage(red, red.max_hp, sim.structures_of(MatchSim.BLUE)[0])
	check_near(blue.gold, MatchController.CONFIG.hero_ko_gold, 0.01, "knockout gold, even when a tower finished it")


func test_items_survive_a_knockout() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	blue.gold = 400.0
	_buy(sim, _slot(blue, &"mending_charm"))
	sim.apply_damage(blue, blue.max_hp * 2.0, sim.heroes[1])
	run_ticks(sim, int(MatchController.CONFIG.respawn_time / sim.dt) + 2)
	check(blue.alive and blue.owns(_item(&"mending_charm")), "item kept after respawn")
	check_near(blue.hp, blue.data.max_hp * 1.06, 0.01, "respawns with the bigger health pool")


func test_siege_banner_boosts_nearby_minions() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	blue.gold = 1000.0
	blue.deck = MatchController.bot_deck(MatchController.HEROES[0])
	_buy(sim, _slot(blue, &"siege_banner"))
	var tower := sim.structures_of(MatchSim.RED)[0]
	var m := sim.spawn_minion(melee(), MatchSim.BLUE, tower.pos + Vector2(0, -1.5))
	place(blue, m.pos + Vector2(0, -3))
	check_near(Economy.minion_structure_mult(sim, m), 1.2, 0.001, "+20% near the banner")
	place(blue, m.pos + Vector2(0, -20))
	check_near(Economy.minion_structure_mult(sim, m), 1.0, 0.001, "no bonus far away")


func test_mending_charm_heals_after_a_quiet_spell() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	blue.gold = 400.0
	_buy(sim, _slot(blue, &"mending_charm"))
	sim.apply_damage(blue, 200.0, sim.heroes[1])
	var hurt := blue.hp
	run_ticks(sim, int(4.0 / sim.dt))
	check_near(blue.hp, hurt, 0.01, "no healing within 5 s of hero damage")
	run_ticks(sim, int(3.0 / sim.dt))
	check(blue.hp > hurt + 1.0, "healing after 5 s")


func test_bots_buy_items_at_a_reasonable_pace() -> void:
	var sim := MatchSim.new()
	var picks: Array[HeroData] = [MatchController.HEROES[0], MatchController.HEROES[2]]
	var decks := [MatchController.bot_deck(picks[0]), MatchController.bot_deck(picks[1])]
	sim.setup(MatchController.CONFIG, MatchController.ARENA, picks, MatchController.TIERS, MatchController.MINIONS, decks)
	var a := BotSource.new()
	a.team = MatchSim.BLUE
	var b := BotSource.new()
	b.team = MatchSim.RED
	for i in int(6.0 * 60.0 / sim.dt):
		sim.step([a.build_command(sim), b.build_command(sim)])
	for h in sim.heroes:
		check(h.items.size() >= 2, "%s bought 2+ items in 6 min (got %d, %d gold left)" % [h.data.display_name, h.items.size(), int(h.gold)])
		check(h.gold >= 0.0, "gold never negative")


func test_deny_your_own_low_minion() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	place(blue, Vector2(0, -1.0))
	place(red, Vector2(4.0, 1.0))
	red.attack_damage = 0.0
	var own := sim.spawn_minion(melee(), MatchSim.BLUE, Vector2(0.8, -1.0))
	own.attack_damage = 0.0
	run_ticks(sim, 1, Vector2.ZERO, Vector2.ZERO, own.id)
	check(blue.preferred_target == 0, "a healthy own minion can't be tapped")
	own.hp = 40.0
	var gold_before := red.gold
	# The minion keeps walking up the lane, so blue has a moment to land it.
	run_ticks(sim, 16, Vector2.ZERO, Vector2.ZERO, own.id)
	check(not own.alive, "blue denied its own low minion")
	check_near(red.gold - gold_before - MatchController.CONFIG.passive_gold_per_second * 16 * sim.dt, melee().gold_bounty * 0.5, 0.05, "red collects only half")


func test_auto_target_never_picks_your_own_minion() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	place(blue, Vector2(0, -1.0))
	var own := sim.spawn_minion(melee(), MatchSim.BLUE, Vector2(0.8, -1.0))
	own.hp = 5.0
	own.attack_damage = 0.0
	run_ticks(sim, 30)
	check(own.alive, "no deny without a tap")
