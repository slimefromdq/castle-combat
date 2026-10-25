extends TestCase
## Lucy's pacing overhaul: gold ramp, Relay rewards, structure resist, Guardians,
## power minions, minion scaling, respawn timers, overtime.


func _at(sim: MatchSim, seconds: float) -> void:
	sim.tick = roundi(seconds / sim.dt)
	sim.time = sim.tick * sim.dt


func _cfg() -> MatchConfig:
	return MatchController.CONFIG


func test_gold_ramps_up_over_time() -> void:
	var sim := new_sim()
	check_near(Pacing.gold_mult(sim), 1.0, 0.0001, "no bonus at the start")
	_at(sim, _cfg().gold_ramp_start + 300.0)
	check_near(Pacing.gold_mult(sim), 1.0 + 5.0 * _cfg().gold_ramp_per_minute, 0.0001, "+8% per minute after the ramp starts")
	var blue := sim.heroes[0]
	place(blue, Vector2(0, -20))
	var gold := blue.gold
	var m := sim.spawn_minion(melee(), MatchSim.RED, blue.pos + Vector2(1, 0))
	sim.apply_damage(m, m.max_hp * 3.0, blue)
	check_near(blue.gold - gold, melee().gold_bounty * (1.0 + MatchController.CONFIG.last_hit_bonus) * Pacing.gold_mult(sim), 0.01, "minion gold is scaled too")


func test_relay_rewards_grow_each_activation() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	Pacing.on_relay_delivered(sim, blue, 0)
	check(sim.pending_siege[0] == 1, "first Relay: one siege minion")
	check_near(blue.gold, _cfg().relay_gold_base, 0.01, "and a little gold")
	sim.pending_siege = [0, 0]
	blue.gold = 0.0
	Pacing.on_relay_delivered(sim, blue, 4)
	check(sim.pending_siege[0] == 3, "fifth Relay: three siege minions (got %d)" % sim.pending_siege[0])
	check_near(blue.gold, _cfg().relay_gold_base + 4.0 * _cfg().relay_gold_per_activation, 0.01, "and much more gold")


func test_structure_resist_decays_and_pays_gold() -> void:
	var sim := new_sim()
	var outer := sim.structures_of(MatchSim.RED)[0]
	var guardian := sim.structures_of(MatchSim.RED)[1]
	check_near(Pacing.structure_resist(sim, outer), 0.2, 0.0001, "outer towers start at +20%")
	check_near(Pacing.structure_resist(sim, guardian), 0.1, 0.0001, "Guardians start at +10%")
	var blue := sim.heroes[0]
	var hp := outer.hp
	sim.apply_damage(outer, 100.0, blue)
	check_near(hp - outer.hp, 80.0, 0.01, "early towers take 20% less")
	check_near(blue.gold, 20.0 * _cfg().resist_gold_per_damage, 0.01, "soaked damage pays gold")
	_at(sim, _cfg().resist_end_time)
	check_near(Pacing.structure_resist(sim, outer), -0.3, 0.0001, "down to -30% late")
	check_near(Pacing.structure_resist(sim, guardian), -0.3, 0.0001, "Guardians too")
	hp = outer.hp
	sim.apply_damage(outer, 100.0, blue)
	check_near(hp - outer.hp, 130.0, 0.01, "late towers take 30% more")


func test_structure_kills_pay_gold() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	var outer := sim.structures_of(MatchSim.RED)[0]
	sim.apply_damage(outer, outer.max_hp * 2.0, sim.heroes[1])
	check_near(blue.gold, outer.data.gold_bounty, 0.01, "an Outer Tower pays its bounty to the enemy hero")
	check(outer.data.gold_bounty >= 200.0, "and it is considerable")


## Red's Guardian with its Outer Tower already down (so it is active).
func _guardian(sim: MatchSim) -> StructureState:
	var outer := sim.structures_of(MatchSim.RED)[0]
	sim.apply_damage(outer, outer.max_hp * 5.0, sim.heroes[1])
	return sim.structures_of(MatchSim.RED)[1]


func test_guardian_beam_ramps_on_one_target() -> void:
	var sim := new_sim()
	var guardian := _guardian(sim)
	var m := sim.spawn_minion(melee(), MatchSim.BLUE, guardian.pos + Vector2(0, -4))
	m.attack_damage = 0.0
	m.max_hp = 100000.0
	m.hp = m.max_hp
	var hits: Array[float] = []
	sim.sim_event.connect(func(t: StringName, d: Dictionary) -> void:
		if t == &"attack_fired" and d.attacker == guardian.id:
			hits.append(d.damage))
	for i in int(8.0 / sim.dt):
		m.pos = guardian.pos + Vector2(0, -4)
		sim.step([null, null])
	check(hits.size() > 10, "the beam fires fast (%d shots)" % hits.size())
	if hits.size() > 1:
		check(hits[hits.size() - 1] > hits[0] * 2.5, "and grows on the same target (%.1f -> %.1f)" % [hits[0], hits[hits.size() - 1]])
		check(hits[hits.size() - 1] <= guardian.data.attack_damage * guardian.data.beam_max_mult + 0.01, "up to its cap")


func test_guardian_stomps_at_health_thresholds() -> void:
	var sim := new_sim()
	var guardian := _guardian(sim)
	var blue := sim.heroes[0]
	place(blue, guardian.pos + Vector2(0, -5.0))
	var m := sim.spawn_minion(melee(), MatchSim.BLUE, guardian.pos + Vector2(1.0, -3.0))
	m.attack_damage = 0.0
	sim.step([null, null])
	check(guardian.slam_at < 0.0, "no stomp at full health, however close you are")
	sim.apply_damage(guardian, guardian.max_hp * 0.45, sim.heroes[0])
	sim.step([null, null])
	check(guardian.slam_at >= 0.0, "dropping below 66% starts a stomp")
	var hp := blue.hp
	var m_hp := m.hp
	run_ticks(sim, int(guardian.data.slam_windup / sim.dt) + 2)
	check(blue.hp < hp - guardian.data.slam_damage * 0.5, "the stomp hits the hero hard")
	check(blue.is_stunned(sim.time), "and stuns")
	check(not m.alive or m.hp < m_hp - m.max_hp * 0.5, "and chunks the wave")
	run_ticks(sim, 10)
	check(blue.pos.distance_to(guardian.pos) > 5.0 + guardian.data.slam_knockback * 0.6, "and knocks the hero back")
	check(guardian.is_busy(sim.time), "the Guardian can't attack while it recovers")
	run_ticks(sim, int(5.0 / sim.dt))
	sim.apply_damage(guardian, guardian.max_hp * 0.1, sim.heroes[0])
	sim.step([null, null])
	check(guardian.slam_at < 0.0, "no second stomp until the next threshold")
	sim.apply_damage(guardian, guardian.max_hp * 0.25, sim.heroes[0])
	sim.step([null, null])
	check(guardian.slam_at >= 0.0, "below 33%: the second stomp")
	run_ticks(sim, int(guardian.data.slam_windup / sim.dt) + int(4.0 / sim.dt))
	sim.apply_damage(guardian, guardian.max_hp * 0.2, sim.heroes[0])
	sim.step([null, null])
	check(guardian.slam_at < 0.0, "and that's all of them")


func test_guardian_stomp_can_be_dodged() -> void:
	var sim := new_sim()
	var guardian := _guardian(sim)
	var blue := sim.heroes[0]
	place(blue, guardian.pos + Vector2(0, -5.0))
	sim.apply_damage(guardian, guardian.max_hp * 0.4, sim.heroes[1])
	sim.step([null, null])
	check(guardian.slam_at >= 0.0, "stomp started")
	var hp := blue.hp
	run_ticks(sim, int(guardian.data.slam_windup / sim.dt) + 2, Vector2(0, -1))
	check(blue.hp >= hp - 1.0, "walking out during the telegraph dodges it")
	check(guardian.is_busy(sim.time), "and the Guardian still has to recover")


func test_locked_structures_stay_dormant() -> void:
	var sim := new_sim()
	var guardian := sim.structures_of(MatchSim.RED)[1]
	sim.structures_of(MatchSim.RED)[0].attack_damage = 0.0  # Only the Guardian matters here.
	var blue := sim.heroes[0]
	place(blue, guardian.pos + Vector2(0, -4.0))
	var hp := blue.hp
	run_ticks(sim, 60)
	check(not guardian.is_winding_up() and guardian.attack_target == 0, "a locked Guardian doesn't attack")
	check_near(blue.hp, hp, 0.01, "so the hero is untouched")


func test_power_minions_after_a_guardian_falls() -> void:
	var sim := new_sim(true)
	var red := sim.structures_of(MatchSim.RED)
	var before := sim.spawn_minion(melee(), MatchSim.BLUE, Vector2(0, -2))
	var base_hp := before.max_hp
	sim.apply_damage(red[0], red[0].max_hp * 2.0, sim.heroes[0])
	sim.apply_damage(red[1], red[1].max_hp * 2.0, sim.heroes[0])
	check(sim.power_minions[MatchSim.BLUE], "blue's minions are powered up")
	check(not sim.power_minions[MatchSim.RED], "red's are not")
	check(before.is_power and before.max_hp > base_hp * 1.5, "minions already on the field upgrade too")
	var after := sim.spawn_minion(melee(), MatchSim.BLUE, Vector2(0, -2))
	check(after.is_power and after.speed_mult > 1.1, "new minions spawn as power minions")
	var theirs := sim.spawn_minion(melee(), MatchSim.RED, Vector2(0, 2))
	check(not theirs.is_power, "the other side's don't")


func test_minions_grow_slightly_over_time() -> void:
	var sim := new_sim()
	var early := sim.spawn_minion(melee(), MatchSim.BLUE, Vector2(0, -2))
	_at(sim, _cfg().minion_scale_start + 600.0)
	var late := sim.spawn_minion(melee(), MatchSim.BLUE, Vector2(0, -2))
	var ratio := late.max_hp / early.max_hp
	check_near(ratio, 1.0 + 10.0 * _cfg().minion_hp_per_minute, 0.001, "+2.5% HP per minute")
	check(ratio < 1.5, "only slightly stronger")


func test_respawn_grows_with_time_and_deaths() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	sim.apply_damage(blue, blue.max_hp * 3.0, sim.heroes[1])
	check_near(blue.respawn_at - sim.time, _cfg().respawn_time, 0.01, "short deaths early")
	_at(sim, 600.0)
	blue.alive = true
	blue.hp = blue.max_hp
	sim.apply_damage(blue, blue.max_hp * 3.0, sim.heroes[1])
	var expected := _cfg().respawn_time + 10.0 * _cfg().respawn_per_minute + _cfg().respawn_per_death
	check_near(blue.respawn_at - sim.time, expected, 0.01, "longer later and after more deaths")


func test_heal_pad_behind_the_core() -> void:
	var sim := new_sim()
	var blue := sim.heroes[0]
	var core := sim.structures_of(MatchSim.BLUE)[2]
	place(blue, core.pos + Vector2(0, 3.0))
	blue.hp = blue.max_hp * 0.5
	run_ticks(sim, 30)
	check_near(blue.hp, blue.max_hp * 0.5, 0.01, "no healing in front of the Core")
	place(blue, MatchSim.to_team_space(MatchSim.BLUE, sim.arena.heal_pad))
	run_ticks(sim, 30)
	check(blue.hp > blue.max_hp * 0.55, "the pad behind the Core heals")
	var mine := sim.structures_of(MatchSim.BLUE)
	sim.apply_damage(mine[0], mine[0].max_hp * 5.0, sim.heroes[1])
	sim.apply_damage(mine[1], mine[1].max_hp * 5.0, sim.heroes[1])
	var before := blue.hp
	run_ticks(sim, 30)
	check(blue.hp <= before + 0.01, "the pad shuts off once your Guardian falls")


func test_guardian_fall_shortens_your_respawn() -> void:
	var sim := new_sim()
	var red_hero := sim.heroes[1]
	_at(sim, 600.0)
	sim.apply_damage(red_hero, red_hero.max_hp * 3.0, sim.heroes[0])
	var left := red_hero.respawn_at - sim.time
	var red := sim.structures_of(MatchSim.RED)
	sim.apply_damage(red[0], red[0].max_hp * 5.0, sim.heroes[0])
	sim.apply_damage(red[1], red[1].max_hp * 5.0, sim.heroes[0])
	check_near(red_hero.respawn_at - sim.time, left * _cfg().guardian_fall_respawn_mult, 0.01, "a slashed revive timer")


func test_overtime_starts_and_weakens_structures() -> void:
	var sim := new_sim()
	_at(sim, _cfg().overtime_time - 1.0)
	sim.step([null, null])
	check(not sim.overtime, "not yet")
	_at(sim, _cfg().overtime_time)
	sim.step([null, null])
	check(sim.overtime, "overtime at 10:00 when no Guardian has fallen")
	var outer := sim.structures_of(MatchSim.RED)[0]
	var hp := outer.hp
	sim.apply_damage(outer, 100.0, sim.heroes[0])
	var resist := Pacing.structure_resist(sim, outer)
	check_near(hp - outer.hp, 100.0 * (1.0 - resist) * _cfg().overtime_structure_damage_taken, 0.01, "structures take much more damage")
	var m := sim.spawn_minion(melee(), MatchSim.BLUE, Vector2(0, -2))
	var minutes := Pacing.minutes_after(sim, _cfg().minion_scale_start)
	check_near(m.max_hp, melee().max_hp * (1.0 + _cfg().minion_hp_per_minute * minutes) * _cfg().overtime_minion_hp_mult, 0.01, "waves are tankier")


func test_overtime_waits_after_a_guardian_falls() -> void:
	var sim := new_sim()
	var red := sim.structures_of(MatchSim.RED)
	sim.apply_damage(red[0], red[0].max_hp * 5.0, sim.heroes[0])
	sim.apply_damage(red[1], red[1].max_hp * 5.0, sim.heroes[0])
	_at(sim, _cfg().overtime_time + 1.0)
	sim.step([null, null])
	check(not sim.overtime, "progress was made, so no overtime at 10:00")
	_at(sim, _cfg().overtime_late_time)
	sim.step([null, null])
	check(sim.overtime, "but it still comes later")
