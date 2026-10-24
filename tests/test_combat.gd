extends TestCase
## The basic-attack contract (Codex acceptance criterion 1) and target priority.

var events: Array = []


func _watch(sim: MatchSim) -> void:
	events.clear()
	sim.sim_event.connect(func(type: StringName, data: Dictionary) -> void: events.append([type, data]))


func _count(type: StringName, attacker_id: int) -> int:
	var n := 0
	for e in events:
		if e[0] == type and e[1].get("attacker", -1) == attacker_id:
			n += 1
	return n


## Blue Vanguard and red Scout face off in mid-lane, inside Vanguard's range.
func _duel() -> MatchSim:
	var sim := new_sim()
	place(sim.heroes[0], Vector2(0, -1.0))
	place(sim.heroes[1], Vector2(0, 1.0))
	_watch(sim)
	return sim


func test_moving_never_winds_up() -> void:
	var sim := _duel()
	var blue := sim.heroes[0]
	for i in 60:
		run_ticks(sim, 1, Vector2.RIGHT if i % 2 == 0 else Vector2.LEFT)
	check(_count(&"windup_started", blue.id) == 0, "a moving hero must never start a windup")
	check(_count(&"attack_fired", blue.id) == 0, "a moving hero must never fire")


func test_stopping_in_range_winds_up_then_fires() -> void:
	var sim := _duel()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	run_ticks(sim, 1)
	check(blue.is_winding_up(), "windup starts on the first still tick")
	check(blue.attack_target == red.id, "enemy hero is the default target")
	run_ticks(sim, int(ceil(blue.attack_windup / sim.dt)) + 1)
	check(_count(&"attack_fired", blue.id) == 1, "fires once the windup completes")
	check_near(red.hp, red.max_hp - blue.attack_damage, 0.01, "damage landed")


func test_moving_before_fire_cancels() -> void:
	var sim := _duel()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	run_ticks(sim, 3)
	check(blue.is_winding_up(), "winding up")
	run_ticks(sim, 1, Vector2.LEFT)
	check(not blue.is_winding_up(), "movement cancelled the windup")
	check(_count(&"windup_cancelled", blue.id) == 1, "cancel event emitted")
	check(red.hp == red.max_hp, "no damage from a cancelled attack")


func test_fired_attack_lands_even_if_target_runs() -> void:
	var sim := _duel()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	# Red starts running the moment blue begins winding up; blue stays put.
	run_ticks(sim, 1)
	var fired := run_until(sim, func() -> bool: return _count(&"attack_fired", blue.id) > 0, 30, Vector2.ZERO)
	check(fired, "attack fired")
	var hp_after_fire := red.hp
	# Now both move: the shot already landed and cannot be dodged.
	run_ticks(sim, 15, Vector2.LEFT, Vector2.UP)
	check_near(hp_after_fire, red.max_hp - blue.attack_damage, 0.01, "guaranteed hit applied at fire time")
	check_near(red.hp, hp_after_fire, 0.01, "no extra or lost damage afterwards")


func test_target_slipping_out_of_range_cancels_without_damage() -> void:
	var sim := _duel()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	run_ticks(sim, 1)
	place(red, Vector2(0, 8.0))
	run_ticks(sim, 1)
	check(not blue.is_winding_up(), "target out of reach cancels the windup")
	run_ticks(sim, 15)
	check(red.hp == red.max_hp, "no damage")


func test_enemy_hero_beats_minions_by_default() -> void:
	var sim := _duel()
	var m := sim.spawn_minion(melee(), MatchSim.RED, Vector2(0.8, -1.0))
	run_ticks(sim, 1)
	check(sim.heroes[0].attack_target == sim.heroes[1].id, "hero chosen over a minion (%d)" % m.id)


func test_last_hittable_minion_beats_other_minions() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	place(blue, Vector2(0, -1.0))
	place(sim.heroes[1], Vector2(0, 30.0))
	var healthy := sim.spawn_minion(melee(), MatchSim.RED, Vector2(0.5, -0.2))
	var weak := sim.spawn_minion(melee(), MatchSim.RED, Vector2(-1.2, -1.0))
	weak.hp = blue.attack_damage - 1.0
	run_ticks(sim, 1)
	check(blue.attack_target == weak.id, "last-hittable minion first (healthy=%d)" % healthy.id)


func test_tap_lets_you_last_hit_with_enemy_hero_nearby() -> void:
	var sim := _duel()
	var blue := sim.heroes[0]
	var weak := sim.spawn_minion(melee(), MatchSim.RED, Vector2(-1.0, -0.5))
	weak.hp = 10.0
	run_ticks(sim, 20, Vector2.ZERO, Vector2.ZERO, weak.id)
	check(not weak.alive, "tapped minion was killed")
	var killed_by_blue := false
	for e in events:
		if e[0] == &"unit_killed" and e[1].id == weak.id and e[1].killer == blue.id:
			killed_by_blue = true
	check(killed_by_blue, "the last hit belongs to the blue hero")


func test_tap_override_expires_out_of_range() -> void:
	var sim := _duel()
	var blue := sim.heroes[0]
	var far := sim.spawn_minion(melee(), MatchSim.RED, Vector2(4.0, 15.0))
	run_ticks(sim, 1, Vector2.ZERO, Vector2.ZERO, far.id)
	check(blue.preferred_target == far.id, "override set")
	run_ticks(sim, int(MatchController.CONFIG.override_leash_time / sim.dt) + 5)
	check(blue.preferred_target == 0, "override dropped after the leash time")


func test_hero_knockout_and_respawn() -> void:
	var sim := new_sim()
	var red := sim.heroes[1]
	place(red, Vector2(0, 5))
	sim.apply_damage(red, red.max_hp + 10.0, sim.heroes[0])
	check(not red.alive, "knocked out")
	run_ticks(sim, int(MatchController.CONFIG.respawn_time / sim.dt) - 3)
	check(not red.alive, "still waiting to respawn")
	run_ticks(sim, 5)
	check(red.alive and red.hp == red.max_hp, "respawned at full health")
	check(red.pos == red.spawn_pos, "respawned at base")
