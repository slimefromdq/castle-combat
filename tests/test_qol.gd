extends TestCase
## Sprinting, shop range, deny gold and the basic-attack items (Lucy's playtest notes).


func _item(id: StringName) -> ItemData:
	for item in MatchController.ITEMS:
		if item.id == id:
			return item
	return null


func _sim() -> MatchSim:
	var sim := new_sim()
	var deck := MatchController.deck_from(MatchController.DEFAULT_DECK)
	sim.heroes[0].deck = deck
	sim.heroes[1].deck = deck
	place(sim.heroes[0], Vector2(0, -2))
	place(sim.heroes[1], Vector2(0, 20))
	return sim


func _step(sim: MatchSim, blue: PlayerCommand) -> void:
	sim.step([blue, null])


func _walk(sim: MatchSim, dir: Vector2, seconds: float) -> void:
	run_ticks(sim, int(round(seconds / sim.dt)), dir)


func test_sprint_after_moving_out_of_combat() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	place(blue, Vector2(0, 0))
	_walk(sim, Vector2(0, -1), sim.config.sprint_build_time - 0.2)
	check(not blue.sprinting, "no sprint before the build-up")
	var walk := blue.move_speed()
	_walk(sim, Vector2(0, -1), 0.4)
	check(blue.sprinting, "sprinting after %.1f s" % sim.config.sprint_build_time)
	check_near(blue.move_speed(), walk * sim.config.sprint_speed_mult, 0.01, "faster")
	_walk(sim, Vector2(0.3, -1).normalized(), 1.0)
	check(blue.sprinting, "a gentle curve keeps it")
	_walk(sim, Vector2(1, 0), 0.1)
	check(not blue.sprinting, "a sharp turn ends it")


func test_sprint_ends_on_stop_damage_cast_and_combat() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	place(blue, Vector2(0, 0))
	_walk(sim, Vector2(0, -1), sim.config.sprint_build_time + 0.2)
	check(blue.sprinting, "sprinting")
	run_ticks(sim, 1)
	check(not blue.sprinting and blue.sprint_build == 0.0, "stopping (to attack) ends it")
	_walk(sim, Vector2(0, -1), sim.config.sprint_build_time + 0.2)
	check(blue.sprinting, "sprinting again")
	var m := sim.spawn_minion(melee(), MatchSim.RED, Vector2(5, 0))
	sim.apply_damage(blue, 1.0, m)
	check(not blue.sprinting, "any damage ends it")
	_walk(sim, Vector2(0, -1), sim.config.sprint_build_time + 0.2)
	check(not blue.sprinting, "no build-up for a while after being hit")
	_walk(sim, Vector2(0, 1), sim.config.sprint_build_time + 0.2)
	check(blue.sprinting, "back to sprinting once out of combat")
	sim.apply_damage(red, 1.0, blue)
	_walk(sim, Vector2(0, 1), 0.1)
	check(not blue.sprinting, "hitting the enemy hero puts you in combat")
	blue.carrying_relay = true
	_walk(sim, Vector2(0, -1), sim.config.sprint_combat_delay + sim.config.sprint_build_time + 0.5)
	check(not blue.sprinting, "no sprinting with the Relay")


func test_shop_only_near_your_structures() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	blue.gold = 5000.0
	check(not Economy.in_shop_range(sim, blue), "mid-lane: no shop")
	check(Economy.buy_problem(sim, blue, 0) != "", "can't buy mid-lane")
	var tower := sim.structures_of(MatchSim.BLUE)[0]
	place(blue, tower.pos + Vector2(0, 3))
	check(Economy.in_shop_range(sim, blue), "next to your Outer Tower")
	var guardian := sim.structures_of(MatchSim.BLUE)[1]
	place(blue, guardian.pos + Vector2(0, 2))
	check(not Economy.in_shop_range(sim, blue), "a dormant Guardian is no shop")
	place(blue, sim.arena.heal_pad)
	check(Economy.in_shop_range(sim, blue), "your base always is")
	_step(sim, PlayerCommand.new())
	var cmd := PlayerCommand.new()
	cmd.buy_slot = 0
	_step(sim, cmd)
	check(blue.items.size() == 1, "bought at base")
	place(blue, Vector2(0, -2))
	cmd = PlayerCommand.new()
	cmd.sell_slot = 0
	_step(sim, cmd)
	check(blue.items.size() == 1, "can't sell mid-lane either")
	tower.hp = 0.0
	tower.alive = false
	place(blue, guardian.pos + Vector2(0, -2))
	check(Economy.in_shop_range(sim, blue), "the Guardian is your shop once the tower falls")


func test_denying_pays_the_denier() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	var m := sim.spawn_minion(melee(), MatchSim.BLUE, Vector2(0.8, -2.0))
	var gold := blue.gold
	sim.apply_damage(m, m.hp + 1.0, blue)
	check(not m.alive, "denied")
	check_near(blue.gold - gold, melee().gold_bounty * sim.config.deny_self_gold_fraction * Pacing.gold_mult(sim), 0.01, "the denier gets a share")


func test_whetstone_and_executioners_edge() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	blue.items.append(_item(&"whetstone"))
	blue.recompute_stats()
	check_near(blue.attack_damage, blue.data.attack_damage * 1.15, 0.01, "Whetstone +15% damage")
	blue.items.append(_item(&"executioners_edge"))
	blue.recompute_stats()
	var hp := red.hp
	sim.apply_damage(red, 100.0, blue, &"basic")
	check_near(hp - red.hp, 100.0, 0.01, "no bonus on a healthy hero")
	red.hp = red.max_hp * 0.4
	hp = red.hp
	sim.apply_damage(red, 100.0, blue, &"basic")
	check_near(hp - red.hp, 130.0, 0.01, "+30% below half health")
	red.hp = red.max_hp * 0.4
	hp = red.hp
	sim.apply_damage(red, 100.0, blue, &"ability")
	check_near(hp - red.hp, 100.0, 0.01, "basic attacks only")


func test_duelists_crest_every_third_hit() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	blue.items.append(_item(&"duelists_crest"))
	blue.recompute_stats()
	var hits: Array[float] = []
	for i in 3:
		var hp := red.hp
		sim.apply_damage(red, 10.0, blue, &"basic")
		hits.append(hp - red.hp)
	check_near(hits[0], 10.0, 0.01, "first hit plain")
	check_near(hits[2], 10.0 + red.max_hp * 0.07, 0.01, "third hit adds 7% max HP")
	var m := sim.spawn_minion(melee(), MatchSim.RED, Vector2(0, 0))
	for i in 3:
		sim.apply_damage(m, 1.0, blue, &"basic")
	check(blue.crest_count == 0, "minion hits don't count")
