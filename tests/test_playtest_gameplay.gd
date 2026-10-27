extends TestCase
## Lucy's 2026-10-25 playtest batch: bushes, Core breathing room, siege scrolls.


func _cfg() -> MatchConfig:
	return MatchController.CONFIG


func _level_to(sim: MatchSim, h: HeroState, level: int) -> void:
	Leveling.gain(sim, h, float(sim.config.level_xp[level - 1]) - h.xp + 0.01)


func test_bushes_are_point_symmetric_and_on_the_ground() -> void:
	var arena := MatchController.ARENA
	check(arena.bushes.size() >= 6, "bushes on the map (got %d)" % arena.bushes.size())
	for b in arena.bushes:
		var twin := false
		for c in arena.bushes:
			if c.position.is_equal_approx(-b.position - b.size) and c.size.is_equal_approx(b.size):
				twin = true
		check(twin, "bush %s has a mirrored twin" % b)
		var on_floor := arena.in_bounds(b.position) and arena.in_bounds(b.end) \
				and arena.in_bounds(Vector2(b.position.x, b.end.y)) and arena.in_bounds(Vector2(b.end.x, b.position.y))
		check(on_floor, "bush %s sits on walkable ground" % b)


func test_a_hero_in_a_bush_is_hidden() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	var bush := sim.arena.bushes[0]
	place(blue, bush.get_center())
	place(red, bush.get_center() + Vector2(0, 8))
	check(sim.is_hidden(blue), "hidden in the bush")
	check(not CombatSystem.is_valid_target(sim, red, blue), "the enemy hero can't target you")
	var m := sim.spawn_minion(melee(), MatchSim.RED, bush.get_center() + Vector2(1.5, 0))
	check(not CombatSystem.is_valid_target(sim, m, blue), "nor can their troopers")
	place(red, bush.get_center() + Vector2(0, _cfg().bush_reveal_radius - 0.2))
	check(not sim.is_hidden(blue), "an enemy right next to you sees you")
	place(red, bush.get_center() + Vector2(0, 8))
	sim.apply_damage(m, 10.0, blue)
	check(not sim.is_hidden(blue), "attacking gives you away")
	sim.time += _cfg().bush_reveal_time + 0.1
	check(sim.is_hidden(blue), "hidden again after a moment")
	place(blue, Vector2(0, 0))
	check(not sim.is_hidden(blue), "out in the open")


func test_core_is_immune_for_a_while_after_its_guardian_falls() -> void:
	var sim := new_sim()
	var red := sim.structures_of(MatchSim.RED)
	var blue := sim.heroes[0]
	sim.apply_damage(red[0], red[0].max_hp * 2.0, blue)
	sim.apply_damage(red[1], red[1].max_hp * 2.0, blue)
	var core := red[2]
	check(sim.is_exposed(core), "the Core is exposed")
	check(sim.apply_damage(core, 100.0, blue) == 0.0, "but takes no damage yet")
	sim.time += _cfg().core_immunity_time + 0.05
	check(sim.apply_damage(core, 100.0, blue) > 0.0, "after %d s it can be hit" % _cfg().core_immunity_time)


func test_siege_scrolls() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	place(blue, MatchSim.to_team_space(blue.team, sim.arena.heal_pad))
	blue.gold = 5000.0
	_level_to(sim, blue, sim.config.siege_scroll_level - 1)
	check(Economy.siege_scroll_problem(sim, blue).begins_with("siege scrolls at level"), "locked before level 7")
	_level_to(sim, blue, sim.config.siege_scroll_level)
	var first := Economy.siege_scroll_cost(sim, blue)
	check(Economy.try_siege_scroll(sim, blue), "bought one")
	check(sim.pending_siege[0] == 1, "a siege trooper joins the next wave")
	check_near(blue.gold, 5000.0 - first, 0.01, "paid")
	check(Economy.siege_scroll_cost(sim, blue) > first, "the next one costs more")
	for i in _cfg().siege_scroll_max:
		Economy.try_siege_scroll(sim, blue)
	check(sim.pending_siege[0] == _cfg().siege_scroll_max, "at most %d waiting" % _cfg().siege_scroll_max)
