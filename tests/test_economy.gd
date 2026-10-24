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
	var six := MatchController.deck_from([0, 1, 2, 3, 4, 5])
	check(Economy.is_valid_deck(six, pool, 6), "six distinct items is a valid deck")
	check(not Economy.is_valid_deck(MatchController.deck_from([0, 1, 2, 3, 4]), pool, 6), "five is not")
	check(not Economy.is_valid_deck(MatchController.deck_from([0, 1, 2, 3, 4, 4]), pool, 6), "duplicates are not")
	var stranger := ItemData.new()
	var bad := MatchController.deck_from([0, 1, 2, 3, 4])
	bad.append(stranger)
	check(not Economy.is_valid_deck(bad, pool, 6), "items outside the pool are not")
	check(Economy.is_valid_deck(MatchController.deck_from(MatchController.DEFAULT_DECK), pool, 6), "default deck is valid")
	check(Economy.is_valid_deck(MatchController.deck_from(MatchController.BOT_DECK), pool, 6), "bot deck is valid")
	check(MatchController.ITEMS.size() >= 8, "pool has at least eight items")


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
	var shell := _slot(blue, &"iron_shell")
	_buy(sim, shell)
	check(blue.owns(_item(&"iron_shell")), "bought Iron Shell")
	check_near(blue.gold, 1200.0 - 350.0 + MatchController.CONFIG.passive_gold_per_second * sim.dt, 0.01, "paid 350")
	check_near(blue.max_hp, blue.data.max_hp * 1.12, 0.01, "+12% max HP")
	check_near(blue.hp, blue.max_hp - 100.0, 0.01, "extra max HP is added to current HP too")
	_buy(sim, _slot(blue, &"grip_gloves"))
	check_near(blue.attack_damage, blue.data.attack_damage * 1.08, 0.01, "+8% damage")
	_buy(sim, _slot(blue, &"quickstring"))
	check_near(blue.attack_interval, blue.data.attack_interval / 1.1, 0.001, "+10% attack speed")


func test_speed_and_range_items() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	blue.gold = 2000.0
	blue.deck = MatchController.deck_from([0, 6, 1, 2, 3, 4])
	_buy(sim, 0)
	_buy(sim, 1)
	check_near(blue.move_speed(), blue.data.move_speed * 1.08, 0.001, "+8% move speed")
	check_near(blue.attack_range, blue.data.attack_range * 1.07, 0.001, "+7% range")


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
	_buy(sim, 6)
	_buy(sim, -1)
	check(blue.items.is_empty(), "only slots 0-5 of your own deck")


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
	check_near(blue.gold, before + melee().gold_bounty, 0.01, "a killing blow from farther away still pays")
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
	_buy(sim, _slot(blue, &"iron_shell"))
	sim.apply_damage(blue, blue.max_hp, sim.heroes[1])
	run_ticks(sim, int(MatchController.CONFIG.respawn_time / sim.dt) + 2)
	check(blue.alive and blue.owns(_item(&"iron_shell")), "item kept after respawn")
	check_near(blue.hp, blue.data.max_hp * 1.12, 0.01, "respawns with the bigger health pool")


func test_siege_banner_boosts_nearby_minions() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	blue.gold = 500.0
	_buy(sim, _slot(blue, &"siege_banner"))
	var tower := sim.structures_of(MatchSim.RED)[0]
	var m := sim.spawn_minion(melee(), MatchSim.BLUE, tower.pos + Vector2(0, -1.5))
	place(blue, m.pos + Vector2(0, -3))
	check_near(Economy.minion_structure_mult(sim, m), 1.12, 0.001, "+12% near the banner")
	place(blue, m.pos + Vector2(0, -20))
	check_near(Economy.minion_structure_mult(sim, m), 1.0, 0.001, "no bonus far away")


func test_recovery_sigil_heals_after_a_quiet_spell() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	blue.gold = 400.0
	_buy(sim, _slot(blue, &"recovery_sigil"))
	sim.apply_damage(blue, 200.0, sim.heroes[1])
	var hurt := blue.hp
	run_ticks(sim, int(6.0 / sim.dt))
	check_near(blue.hp, hurt, 0.01, "no healing within 7 s of hero damage")
	run_ticks(sim, int(3.0 / sim.dt))
	check(blue.hp > hurt + 1.0, "healing after 7 s")


func test_bots_buy_items_at_a_reasonable_pace() -> void:
	var sim := MatchSim.new()
	var picks: Array[HeroData] = [MatchController.HEROES[0], MatchController.HEROES[2]]
	var deck := MatchController.deck_from(MatchController.BOT_DECK)
	sim.setup(MatchController.CONFIG, MatchController.ARENA, picks, MatchController.TIERS, MatchController.MINIONS, [deck, deck])
	var a := BotSource.new()
	a.team = MatchSim.BLUE
	var b := BotSource.new()
	b.team = MatchSim.RED
	for i in int(6.0 * 60.0 / sim.dt):
		sim.step([a.build_command(sim), b.build_command(sim)])
	for h in sim.heroes:
		check(h.items.size() >= 2, "%s bought 2+ items in 6 min (got %d, %d gold left)" % [h.data.display_name, h.items.size(), int(h.gold)])
		check(h.gold >= 0.0, "gold never negative")
