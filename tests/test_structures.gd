extends TestCase
## Towers, sequential vulnerability and the win condition (Codex criteria 2 and 7).


func test_locked_structures_ignore_damage() -> void:
	var sim := new_sim()
	var red := sim.structures_of(MatchSim.RED)
	sim.apply_damage(red[1], 500.0, sim.heroes[0])
	sim.apply_damage(red[2], 500.0, sim.heroes[0])
	check(red[1].hp == red[1].max_hp, "inner tower is invulnerable while the outer stands")
	check(red[2].hp == red[2].max_hp, "core is invulnerable while towers stand")


func test_heroes_cannot_target_locked_structures() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	var inner := sim.structures_of(MatchSim.RED)[1]
	place(blue, inner.pos + Vector2(0, -2.0))
	place(sim.heroes[1], Vector2(0, -30))
	run_ticks(sim, 1)
	check(blue.attack_target != inner.id, "locked inner tower is not a target")


func test_destroying_the_core_ends_the_match() -> void:
	var sim := new_sim()
	var red := sim.structures_of(MatchSim.RED)
	for s in red:
		sim.apply_damage(s, s.max_hp * 2.0, sim.heroes[0])
	check(not red[0].alive and not red[1].alive and red[2].alive, "the Core is immune right after its Guardian falls")
	sim.time = red[2].immune_until
	sim.apply_damage(red[2], red[2].max_hp * 2.0, sim.heroes[0])
	check(not red[0].alive and not red[1].alive and not red[2].alive, "all three fell in order")
	check(sim.over and sim.winner == MatchSim.BLUE, "blue wins when the red Core falls")
	var t := sim.tick
	run_ticks(sim, 10)
	check(sim.tick == t, "the sim stops after the match ends")


func test_towers_prefer_minions_over_heroes() -> void:
	var sim := new_sim()
	var tower := sim.structures_of(MatchSim.RED)[0]
	place(sim.heroes[0], tower.pos + Vector2(-2.0, -3.0))
	var m := sim.spawn_minion(melee(), MatchSim.BLUE, tower.pos + Vector2(2.0, -4.0))
	run_ticks(sim, 1)
	check(tower.attack_target == m.id, "tower shoots the minion first")


func test_towers_shoot_heroes_when_alone() -> void:
	var sim := new_sim()
	var tower := sim.structures_of(MatchSim.RED)[0]
	var blue := sim.heroes[0]
	place(blue, tower.pos + Vector2(0, -4.0))
	run_ticks(sim, 30)
	check(blue.hp < blue.max_hp, "tower damaged the lone hero")


func test_restart_returns_a_clean_state() -> void:
	var sim := new_sim(true)
	run_ticks(sim, 600)
	var picks: Array[HeroData] = [MatchController.HEROES[0], MatchController.HEROES[1]]
	sim.setup(MatchController.CONFIG, MatchController.ARENA, picks, MatchController.TIERS, MatchController.MINIONS)
	check(sim.tick == 0 and sim.time == 0.0, "clock reset")
	check(sim.minions.is_empty() and sim.entities.size() == 8, "only heroes and structures")
	check(not sim.over and sim.winner == -1, "no winner")
	for e: SimEntity in sim.entities.values():
		check(e.hp == e.max_hp and e.alive, "unit %d at full health" % e.id)


func test_minions_hard_focus_structures() -> void:
	var sim := new_sim()
	var tower := sim.structures_of(MatchSim.RED)[0]
	var mine := sim.spawn_minion(melee(), MatchSim.BLUE, tower.pos + Vector2(0, -(tower.radius + 0.6)))
	var theirs := sim.spawn_minion(melee(), MatchSim.RED, mine.pos + Vector2(0.6, 0))
	check(Targeting.for_minion(sim, mine, sim.config.minion_aggro_range) == tower, "a minion next to an enemy tower hits the tower, not the minion beside it")
	theirs.alive = false


func test_towers_drop_a_hero_for_minions() -> void:
	var sim := new_sim()
	var tower := sim.structures_of(MatchSim.RED)[0]
	var blue := sim.heroes[0]
	place(blue, tower.pos + Vector2(0, -4.0))
	check(Targeting.for_structure(sim, tower, 0) == blue, "a lone hero is the target")
	var m := sim.spawn_minion(melee(), MatchSim.BLUE, tower.pos + Vector2(1.0, -3.0))
	check(Targeting.for_structure(sim, tower, blue.id) == m, "once a minion is in range, an uncalled tower switches to it")
