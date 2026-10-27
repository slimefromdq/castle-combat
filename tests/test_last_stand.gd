extends TestCase
## Lucy's Core last stand: the heal pad stays on, a guarded Core takes no damage, overtime
## ends the guard, and the Core's slow stun. Also: banners are gone.


func _expose_red_core(sim: MatchSim) -> StructureState:
	var red := sim.structures_of(MatchSim.RED)
	for s in red.slice(0, 2):
		sim.apply_damage(s, s.max_hp * 2.0, sim.heroes[0])
	red[2].immune_until = 0.0
	return red[2]


func test_heal_pad_stays_on_after_the_guardian_falls() -> void:
	var sim := new_sim()
	var red_hero := sim.heroes[1]
	var red_guardian := sim.structures_of(MatchSim.RED)[1]
	_expose_red_core(sim)
	check(not red_guardian.alive, "red's Guardian is down")
	place(red_hero, MatchSim.to_team_space(MatchSim.RED, sim.arena.heal_pad))
	red_hero.hp = red_hero.max_hp * 0.5
	run_ticks(sim, 30)
	check(red_hero.hp > red_hero.max_hp * 0.5, "still heals on the pad")


func test_core_is_immune_while_its_hero_guards_it() -> void:
	var sim := new_sim()
	var core := _expose_red_core(sim)
	var red_hero := sim.heroes[1]
	place(sim.heroes[0], Vector2(0, -20))
	# In front of red's Core means toward blue, so smaller y.
	place(red_hero, core.pos + Vector2(1.0, -4.0))
	run_ticks(sim, 1)
	check(core.guarded, "hero in the front half circle guards the Core")
	var hp := core.hp
	sim.apply_damage(core, 300.0, sim.heroes[0])
	check(core.hp == hp, "a guarded Core takes no damage")
	place(red_hero, core.pos + Vector2(0, 3.0))
	run_ticks(sim, 1)
	check(not core.guarded, "behind the Core (toward the pad) doesn't count")
	place(red_hero, core.pos + Vector2(0, -9.5))
	run_ticks(sim, 1)
	check(not core.guarded, "too far in front doesn't count")
	sim.apply_damage(core, 300.0, sim.heroes[0])
	check(core.hp < hp, "unguarded, it takes damage")


func test_the_heal_pad_is_outside_the_guard_zone() -> void:
	var sim := new_sim()
	var core := sim.structures_of(MatchSim.BLUE)[2]
	var pad := sim.arena.heal_pad
	for off in [Vector2.ZERO, Vector2(0, sim.arena.heal_pad_radius), Vector2(sim.arena.heal_pad_radius, 0)]:
		check(not Pacing.in_guard_zone(sim, core, pad + off), "no spot on the pad guards the Core")


func test_a_dead_defender_does_not_guard() -> void:
	var sim := new_sim()
	var core := _expose_red_core(sim)
	var red_hero := sim.heroes[1]
	place(red_hero, core.pos + Vector2(0, -3.0))
	sim.kill(red_hero, sim.heroes[0])
	run_ticks(sim, 1)
	check(not core.guarded, "knocked out: the Core is open")


func test_overtime_removes_the_guard() -> void:
	var sim := new_sim()
	var core := _expose_red_core(sim)
	place(sim.heroes[1], core.pos + Vector2(0, -3.0))
	sim.overtime = true
	run_ticks(sim, 1)
	check(not core.guarded, "no immunity in overtime")


func test_core_stun_winds_up_then_stuns_without_damage() -> void:
	var sim := new_sim()
	var core := _expose_red_core(sim)
	var blue := sim.heroes[0]
	var cfg := sim.config
	place(sim.heroes[1], Vector2(6, 30))
	place(blue, core.pos + Vector2(2.0, -5.0))
	var m := sim.spawn_minion(melee(), MatchSim.BLUE, core.pos + Vector2(-2.0, -4.0))
	m.max_hp = 99999.0
	m.hp = m.max_hp
	blue.max_hp = 99999.0
	blue.hp = blue.max_hp
	run_ticks(sim, 1)
	check(core.stun_at > 0.0, "an enemy nearby starts the windup")
	check(not blue.is_stunned(sim.time), "nothing happens during the windup")
	var hero_hp := blue.hp
	run_until(sim, func() -> bool: return core.stun_at < 0.0, int((cfg.core_stun_windup + 0.5) / sim.dt))
	check(blue.is_stunned(sim.time), "the hero is stunned when it lands")
	check(sim.time < m.stun_until and m.stun_until - sim.time > cfg.core_stun_hero, "troopers are stunned longer")
	check(m.alive, "it doesn't kill the wave")
	check_near(core.stun_ready_at - sim.time, cfg.core_stun_interval, 0.1, "then it rests")
	check(blue.hp >= hero_hp - 400.0, "the stun itself does no damage (the Core may still shoot)")


func test_core_stun_misses_heroes_who_walk_out() -> void:
	var sim := new_sim()
	var core := _expose_red_core(sim)
	var blue := sim.heroes[0]
	place(sim.heroes[1], Vector2(6, 30))
	place(blue, core.pos + Vector2(2.0, -6.0))
	run_ticks(sim, 1)
	check(core.stun_at > 0.0, "windup started")
	place(blue, core.pos + Vector2(0, -12.0))
	run_until(sim, func() -> bool: return core.stun_at < 0.0, int(3.0 / sim.dt))
	check(not blue.is_stunned(sim.time), "out of the ring in time: no stun")


func test_no_core_stun_while_the_guardian_stands() -> void:
	var sim := new_sim()
	var core := sim.structures_of(MatchSim.RED)[2]
	place(sim.heroes[0], core.pos + Vector2(2.0, -5.0))
	run_ticks(sim, 5)
	check(core.stun_at < 0.0, "a locked Core never stuns")


func test_special_troopers_no_longer_drop_banners() -> void:
	var sim := new_sim()
	var sapper := sim.spawn_minion(MatchController.MINIONS[&"sapper"], MatchSim.RED, Vector2(0, 0))
	var before := sim.minions.size()
	sim.apply_damage(sapper, sapper.max_hp * 2.0, sim.structures_of(MatchSim.BLUE)[0])
	run_ticks(sim, 1)
	check(not ("banners" in sim), "the banner system is gone")
	check(sim.minions.size() == before - 1, "it just dies")
