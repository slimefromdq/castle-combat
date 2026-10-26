extends SceneTree
## Bot-vs-bot balance runs:  godot --headless --path . -s tools/bot_matches.gd -- [matches per pairing] [shard/shards]
## (a shard such as 0/3 plays every third pairing, so runs can be split across cores)
## Every pairing of different heroes, both seats, with the bots' perk picks rotated so
## each perk gets played. Prints win rates, match length, knockouts and level timings.

const MAX_TIME := 15.0 * 60.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var per_pair := int(args[0]) if args.size() > 0 else 4
	var shard := 0
	var shards := 1
	if args.size() > 1:
		shard = int(args[1].get_slice("/", 0))
		shards = int(args[1].get_slice("/", 1))
	var pair_index := -1
	var heroes := MatchController.HEROES
	var wins := {}
	var games := {}
	var rows: Array[String] = []
	var lengths: Array[float] = []
	var level_times := {3: [], 4: [], 5: [], 6: [], 7: [], 8: [], 9: []}
	var extra := {"ult_race": 0, "ult_race_won": 0, "masterworks": 0, "delivered": 0, "intercepted": 0, "spawned": 0, "scrolls": 0, "candles": 0, "candles_winner": 0, "candle_split": []}
	for h in heroes:
		wins[h.id] = 0
		games[h.id] = 0
	var perk_wins := {}
	var perk_games := {}
	for i in heroes.size():
		for j in heroes.size():
			if i == j:
				continue
			pair_index += 1
			if pair_index % shards != shard:
				continue
			var pair_wins := 0
			for n in per_pair:
				var picks_a := [n % 2, (n / 2) % 2, (n + 1) % 2]
				var picks_b := [(n + 1) % 2, n % 2, (n / 2) % 2]
				var r := _play(heroes[i], heroes[j], picks_a, picks_b, level_times, extra)
				games[heroes[i].id] += 1
				games[heroes[j].id] += 1
				lengths.append(r.time)
				if r.winner >= 0:
					var w: HeroData = heroes[i] if r.winner == 0 else heroes[j]
					wins[w.id] += 1
					if r.winner == 0:
						pair_wins += 1
				for side in 2:
					var hero: HeroData = heroes[i] if side == 0 else heroes[j]
					var picks: Array = picks_a if side == 0 else picks_b
					for tier in 3:
						var perk := hero.perks[tier * 2 + picks[tier]]
						perk_games[perk.id] = perk_games.get(perk.id, 0) + 1
						if r.winner == side:
							perk_wins[perk.id] = perk_wins.get(perk.id, 0) + 1
				rows.append("  %s (blue) vs %s (red): %s at %s, KOs %d-%d" % [heroes[i].display_name, heroes[j].display_name,
						"blue" if r.winner == 0 else ("red" if r.winner == 1 else "nobody"), _clock(r.time), r.kos[1], r.kos[0]])
			print("%s (blue) vs %s (red): blue won %d of %d" % [heroes[i].display_name, heroes[j].display_name, pair_wins, per_pair])
	print("")
	for row in rows:
		print(row)
	print("")
	for h in heroes:
		print("%s: won %d of %d" % [h.display_name, wins[h.id], games[h.id]])
	lengths.sort()
	print("Match length: median %s, shortest %s, longest %s" % [_clock(lengths[lengths.size() / 2]), _clock(lengths[0]), _clock(lengths[-1])])
	for lv: int in level_times:
		var t: Array = level_times[lv]
		t.sort()
		if not t.is_empty():
			print("Level %d reached: median %s" % [lv, _clock(t[t.size() / 2])])
	for h in heroes:
		var t5: Array = extra.get(h.id, [])
		t5.sort()
		if not t5.is_empty():
			print("%s reached Lv%d: median %s" % [h.display_name, Leveling.ULT_LEVEL, _clock(t5[t5.size() / 2])])
	print("Relays: %d spawned, %d delivered, %d knocked loose; siege scrolls read: %d" % [extra.spawned, extra.delivered, extra.intercepted, extra.scrolls])
	var split: Array = extra.candle_split
	split.sort()
	print("Candles: %d taken (%.1f a match), winners took %d; median gap between the two heroes %d" % [extra.candles, float(extra.candles) / maxf(1.0, lengths.size()), extra.candles_winner, split[split.size() / 2] if not split.is_empty() else 0])
	print("First to the ult level won %d of %d; Masterworks made: %d" % [extra.ult_race_won, extra.ult_race, extra.masterworks])
	print("")
	for id: StringName in perk_games:
		print("  %s: won %d of %d" % [id, perk_wins.get(id, 0), perk_games[id]])
	quit()


func _play(blue: HeroData, red: HeroData, picks_a: Array, picks_b: Array, level_times: Dictionary, extra: Dictionary) -> Dictionary:
	var sim := MatchSim.new()
	var picks: Array[HeroData] = [blue, red]
	sim.setup(MatchController.CONFIG, MatchController.ARENA, picks, MatchController.TIERS, MatchController.MINIONS,
			[MatchController.bot_deck(blue), MatchController.bot_deck(red)])
	var a := BotSource.new()
	a.team = 0
	a.perk_choices = picks_a
	var b := BotSource.new()
	b.team = 1
	b.perk_choices = picks_b
	var kos := [0, 0]
	var candles := [0, 0]
	var listen := func(type: StringName, data: Dictionary) -> void:
		if type == &"unit_killed" and data.kind == SimEntity.Kind.HERO:
			kos[data.team] += 1
		elif type == &"level_up" and level_times.has(data.level):
			level_times[data.level].append(sim.time)
			if data.level == Leveling.ULT_LEVEL:
				var who: StringName = sim.get_entity(data.hero).data.id
				if not extra.has(who):
					extra[who] = []
				extra[who].append(sim.time)
		elif type == &"masterwork":
			extra.masterworks += 1
		elif type == &"relay_delivered":
			extra.delivered += 1
		elif type == &"relay_spawned":
			extra.spawned += 1
		elif type == &"relay_dropped" and data.get("reason") == &"intercepted":
			extra.intercepted += 1
		elif type == &"siege_scroll":
			extra.scrolls += 1
		elif type == &"candle_taken":
			candles[data.team] += 1
	sim.sim_event.connect(listen)
	while not sim.over and sim.time < MAX_TIME:
		sim.step([a.build_command(sim), b.build_command(sim)])
	sim.sim_event.disconnect(listen)
	if sim.ult_race_winner >= 0 and sim.winner >= 0:
		extra.ult_race += 1
		if sim.ult_race_winner == sim.winner:
			extra.ult_race_won += 1
	extra.candles += candles[0] + candles[1]
	extra.candle_split.append(absi(candles[0] - candles[1]))
	if sim.winner >= 0:
		extra.candles_winner += candles[sim.winner]
	return {"winner": sim.winner, "time": sim.time, "kos": kos}


func _clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
