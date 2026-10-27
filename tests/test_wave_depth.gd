extends TestCase
## Wave depth: last-hit bonus, special troopers, Shieldbearer shields, and the
## wave meeting point.


func _cfg() -> MatchConfig:
	return MatchController.CONFIG


func test_last_hit_pays_more_than_standing_near() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	place(blue, Vector2(0, -20))
	var tower := sim.structures_of(MatchSim.BLUE)[0]
	var near := sim.spawn_minion(melee(), MatchSim.RED, blue.pos + Vector2(1, 0))
	var gold := blue.gold
	sim.apply_damage(near, near.max_hp * 2.0, tower)
	check_near(blue.gold - gold, melee().gold_bounty, 0.01, "nearby: the plain bounty")
	var hit := sim.spawn_minion(melee(), MatchSim.RED, blue.pos + Vector2(1, 0))
	gold = blue.gold
	sim.apply_damage(hit, hit.max_hp * 2.0, blue)
	check_near(blue.gold - gold, melee().gold_bounty * (1.0 + _cfg().last_hit_bonus), 0.01, "last hit: +15%")


func test_every_fourth_wave_brings_a_special_trooper() -> void:
	var sim := new_sim(true)
	var kinds: Array = []
	sim.sim_event.connect(func(type: StringName, data: Dictionary) -> void:
		if type == &"special_spawned":
			kinds.append([data.wave, data.team, data.kind]))
	run_ticks(sim, int((_cfg().first_wave_time + _cfg().wave_interval * 7.0 + 0.5) / sim.dt))
	check(sim.waves_spawned == 8, "eight waves (got %d)" % sim.waves_spawned)
	check(kinds == [[4, 0, &"sapper"], [4, 1, &"sapper"], [8, 0, &"shieldbearer"], [8, 1, &"shieldbearer"]],
			"Sapper on wave 4, Shieldbearer on wave 8, for both teams (got %s)" % [kinds])


func test_special_trooper_stats() -> void:
	var sapper: MinionData = MatchController.MINIONS[&"sapper"]
	var shield: MinionData = MatchController.MINIONS[&"shieldbearer"]
	check(sapper.max_hp >= melee().max_hp and sapper.max_hp <= melee().max_hp * 1.2, "Sapper HP normal or slightly higher")
	check(sapper.structure_damage_mult >= melee().structure_damage_mult * 3.0, "Sapper hits structures far harder")
	check(shield.shield_blocks == 1, "Shieldbearer blocks one skillshot")


func test_shieldbearer_stops_the_first_skillshot() -> void:
	var sim := new_sim(false, 0, 1)
	var blue := sim.heroes[0]
	place(blue, Vector2(0, -6))
	place(sim.heroes[1], Vector2(4, 30))
	var bearer := sim.spawn_minion(MatchController.MINIONS[&"shieldbearer"], MatchSim.RED, Vector2(0, -3))
	var behind := sim.spawn_minion(melee(), MatchSim.RED, Vector2(0, -1.5))
	for m in [bearer, behind]:
		m.lane_dir = Vector2.ZERO
	var blade: AbilityData = blue.data.abilities[2]
	Abilities._launch(sim, blue, blade, Vector2(0, 1), 100.0, 100.0, 9001)
	for i in 30:
		Abilities._tick_skillshots(sim)
	check(bearer.shield_left == 0, "shield used up")
	check(bearer.hp == bearer.max_hp and behind.hp == behind.max_hp, "nobody behind the shield was hit")
	Abilities._launch(sim, blue, blade, Vector2(0, 1), 100.0, 100.0, 9002)
	for i in 30:
		Abilities._tick_skillshots(sim)
	check(bearer.hp < bearer.max_hp, "the next shot gets through")


func test_meeting_point_is_between_the_wave_fronts() -> void:
	var sim := new_sim()
	check(is_nan(Waves.meeting_y(sim)), "no troopers, no meeting point")
	sim.spawn_minion(melee(), MatchSim.BLUE, Vector2(0, -6))
	sim.spawn_minion(melee(), MatchSim.BLUE, Vector2(0, -2))
	check_near(Waves.meeting_y(sim), -2.0, 0.001, "one wave alone: its front")
	sim.spawn_minion(melee(), MatchSim.RED, Vector2(0, 4))
	sim.spawn_minion(melee(), MatchSim.RED, Vector2(0, 9))
	check_near(Waves.meeting_y(sim), 1.0, 0.001, "halfway between the two fronts")
