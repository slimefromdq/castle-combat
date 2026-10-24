extends TestCase
## Hero-hit aggro: hitting the enemy hero calls their nearby minions and towers onto you.

var events: Array = []


func _watch(sim: MatchSim) -> void:
	events.clear()
	sim.sim_event.connect(func(type: StringName, data: Dictionary) -> void: events.append([type, data]))


func _count(type: StringName) -> int:
	var n := 0
	for e in events:
		if e[0] == type:
			n += 1
	return n


func _fired_by(attacker_id: int) -> Array:
	var out := []
	for e in events:
		if e[0] == &"attack_fired" and e[1].attacker == attacker_id:
			out.append(e[1])
	return out


## Blue Vanguard and red Scout in mid-lane, plus a red minion busy with a blue minion.
func _skirmish() -> Dictionary:
	var sim := new_sim()
	place(sim.heroes[0], Vector2(0, -1.0))
	place(sim.heroes[1], Vector2(0, 1.0))
	var red_minion := sim.spawn_minion(melee(), MatchSim.RED, Vector2(3.0, -1.0))
	var blue_minion := sim.spawn_minion(melee(), MatchSim.BLUE, Vector2(3.0, -1.8))
	_watch(sim)
	return {"sim": sim, "red_minion": red_minion, "blue_minion": blue_minion}


func test_hitting_the_hero_calls_their_nearby_minions() -> void:
	var s := _skirmish()
	var sim: MatchSim = s.sim
	var blue := sim.heroes[0]
	var m: MinionState = s.red_minion
	run_ticks(sim, 3)
	check(m.attack_target != blue.id, "before the hit the red minion fights the blue minion")
	var hit := run_until(sim, func() -> bool: return _fired_by(blue.id).size() > 0, 60)
	check(hit, "blue hit the red hero")
	check(m.called_target == blue.id and m.is_called(sim.time), "red minion switched to blue at once")
	var swung := run_until(sim, func() -> bool: return m.attack_target == blue.id, 60)
	check(swung, "red minion goes for blue")


func test_minions_beyond_the_call_radius_ignore_it() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	place(blue, Vector2(0, -1.0))
	place(red, Vector2(0, 1.0))
	var far := sim.spawn_minion(melee(), MatchSim.RED, Vector2(0, -1.0 - MatchController.CONFIG.minion_call_radius - 1.0))
	sim.on_hero_hit(blue, red)
	check(far.called_target == 0, "a minion outside the radius is not called")


func test_hitting_a_minion_calls_nobody() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	place(blue, Vector2(0, -1.0))
	place(sim.heroes[1], Vector2(0, 30.0))
	var target := sim.spawn_minion(melee(), MatchSim.RED, Vector2(0.8, -1.0))
	var other := sim.spawn_minion(melee(), MatchSim.RED, Vector2(-2.0, -1.0))
	_watch(sim)
	run_ticks(sim, 40, Vector2.ZERO, Vector2.ZERO, target.id)
	check(_fired_by(blue.id).size() > 0, "blue attacked the minion")
	check(_count(&"aggro_called") == 0 and other.called_target == 0, "minion hits do not call for help")


func test_your_minions_fight_back() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	place(blue, Vector2(0, -1.0))
	place(red, Vector2(0, 1.0))
	var guard := sim.spawn_minion(melee(), MatchSim.BLUE, Vector2(1.5, -1.0))
	sim.on_hero_hit(red, blue)
	check(guard.called_target == red.id, "blue's minion turns on the red hero who hit blue")


func test_call_expires_and_minion_goes_back_to_minions() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	place(blue, Vector2(0, -1.0))
	place(red, Vector2(0, 30.0))
	var m := sim.spawn_minion(melee(), MatchSim.RED, Vector2(2.5, -1.0))
	var foe := sim.spawn_minion(melee(), MatchSim.BLUE, Vector2(3.2, -1.0))
	sim.on_hero_hit(blue, red)
	check(Targeting.for_minion(sim, m, 5.0) == blue, "called minion picks blue over a minion")
	sim.time += MatchController.CONFIG.minion_call_duration + 0.1
	check(not m.is_called(sim.time), "call wore off")
	check(Targeting.for_minion(sim, m, 5.0) == foe, "back to minions first")


func test_called_minion_gives_up_past_the_leash() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	place(blue, Vector2(0, -1.0))
	place(red, Vector2(0, 30.0))
	var m := sim.spawn_minion(melee(), MatchSim.RED, Vector2(2.0, -1.0))
	sim.on_hero_hit(blue, red)
	place(blue, Vector2(0, -1.0 - MatchController.CONFIG.minion_call_leash - 2.0))
	check(Targeting.for_minion(sim, m, 5.0) != blue, "kited out of the leash")
	check(m.called_target == 0, "call cleared")


func test_hitting_a_hero_under_their_tower_calls_the_tower() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	var tower := sim.structures_of(MatchSim.RED)[0]
	place(blue, tower.pos + Vector2(0, -4.0))
	place(red, tower.pos + Vector2(0, -2.6))
	var bait := sim.spawn_minion(melee(), MatchSim.BLUE, tower.pos + Vector2(2.0, -3.0))
	bait.max_hp = 99999.0
	bait.hp = bait.max_hp
	_watch(sim)
	run_ticks(sim, 1)
	check(tower.attack_target == bait.id, "tower starts on the minion")
	var hit := run_until(sim, func() -> bool: return _fired_by(blue.id).size() > 0, 60)
	check(hit, "blue hit red under red's tower")
	check(tower.called_target == blue.id, "tower was called onto blue")
	var shot := run_until(sim, func() -> bool:
		for f in _fired_by(tower.id):
			if f.target == blue.id:
				return true
		return false, 90)
	check(shot, "tower shot blue")
	for f in _fired_by(tower.id):
		if f.target == blue.id:
			check_near(f.damage, tower.attack_damage * MatchController.CONFIG.tower_call_damage_mult, 0.01, "called tower shot hits hard")
			break


func test_towers_out_of_range_are_not_called() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	place(blue, Vector2(0, -1.0))
	place(red, Vector2(0, 1.0))
	sim.on_hero_hit(blue, red)
	for s in sim.structures:
		check(s.called_target == 0, "tower %d far away is not called" % s.id)
