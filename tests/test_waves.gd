extends TestCase
## Minion waves and a full match against the bot (Codex criteria 2 and 7).


func _count(sim: MatchSim, team: int) -> int:
	var n := 0
	for m in sim.minions:
		if m.team == team:
			n += 1
	return n


func test_waves_spawn_on_schedule() -> void:
	var sim := new_sim(true)
	var cfg := MatchController.CONFIG
	run_ticks(sim, int(cfg.first_wave_time / sim.dt) - 1)
	check(sim.minions.is_empty(), "nothing before the first wave")
	run_ticks(sim, 2)
	var per_wave := cfg.wave_melee + cfg.wave_ranged
	check(_count(sim, MatchSim.BLUE) == per_wave and _count(sim, MatchSim.RED) == per_wave, "first wave: %d each" % per_wave)
	run_ticks(sim, int(cfg.wave_interval / sim.dt))
	check(sim.waves_spawned == 2, "second wave after the interval")


func test_waves_are_mirror_images() -> void:
	var sim := new_sim(true)
	run_ticks(sim, int(MatchController.CONFIG.first_wave_time / sim.dt) + 1)
	var blue: Array[Vector2] = []
	var red: Array[Vector2] = []
	for m in sim.minions:
		(blue if m.team == MatchSim.BLUE else red).append(m.pos)
	for p in blue:
		var twin := false
		for q in red:
			if q.is_equal_approx(-p):
				twin = true
		check(twin, "blue minion at %s has a red twin" % p)


func test_waves_meet_and_fight() -> void:
	var sim := new_sim(true)
	var kills := [0]
	sim.sim_event.connect(func(type: StringName, data: Dictionary) -> void:
		if type == &"unit_killed" and data.kind == SimEntity.Kind.MINION:
			kills[0] += 1)
	run_ticks(sim, int(40.0 / sim.dt))
	check(kills[0] > 0, "minions killed each other in the first 40 s")
	for s in sim.structures:
		check(s.alive, "even waves alone don't take structures this early")


func test_bot_beats_an_idle_opponent() -> void:
	var sim := new_sim(true)
	var bot := BotSource.new()
	bot.team = MatchSim.BLUE
	var limit := int(20.0 * 60.0 / sim.dt)
	for i in limit:
		if sim.over:
			break
		sim.step([bot.build_command(sim), null])
	check(sim.over and sim.winner == MatchSim.BLUE, "bot destroyed the idle side's Core within 20 min (t=%.0fs)" % sim.time)


func test_bot_vs_bot_stays_healthy() -> void:
	var sim := new_sim(true, 1, 2)
	var a := BotSource.new()
	a.team = MatchSim.BLUE
	var b := BotSource.new()
	b.team = MatchSim.RED
	var peak := 0
	for i in int(5.0 * 60.0 / sim.dt):
		sim.step([a.build_command(sim), b.build_command(sim)])
		peak = maxi(peak, sim.minions.size())
	check(peak < 60, "minions don't pile up forever (peak %d)" % peak)
	for h in sim.heroes:
		check(absf(h.pos.x) < 11.0 and absf(h.pos.y) < 43.0, "hero stayed on the map")
