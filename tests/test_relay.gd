extends TestCase
## The Relay state machine (GDD 7 and Codex criterion 5).

var events: Array = []


func _watch(sim: MatchSim) -> void:
	events.clear()
	sim.sim_event.connect(func(type: StringName, data: Dictionary) -> void: events.append([type, data]))


func _event(type: StringName) -> Dictionary:
	for e in events:
		if e[0] == type:
			return e[1]
	return {}


func _ticks(seconds: float, sim: MatchSim) -> int:
	return int(ceil(seconds / sim.dt))


## A sim whose Relay is already up, heroes parked far from it.
func _spawned() -> MatchSim:
	var sim := new_sim()
	_watch(sim)
	sim.relay.next_spawn_time = 0.0
	run_ticks(sim, 1)
	return sim


## Blue stands on the Relay until it picks it up.
func _blue_carrying() -> MatchSim:
	var sim := _spawned()
	place(sim.heroes[0], sim.relay.origin)
	run_ticks(sim, _ticks(MatchController.CONFIG.relay_pickup_time, sim) + 1)
	return sim


func test_first_relay_warns_then_spawns_on_schedule() -> void:
	var sim := new_sim()
	_watch(sim)
	var cfg := MatchController.CONFIG
	run_ticks(sim, _ticks(cfg.first_relay_time - cfg.relay_warning_time, sim) - 2)
	check(_event(&"relay_warning").is_empty(), "no warning too early")
	run_ticks(sim, 3)
	check(not _event(&"relay_warning").is_empty(), "warning %ds ahead" % int(cfg.relay_warning_time))
	check(sim.relay.state == RelayController.State.DORMANT, "not up yet")
	run_ticks(sim, _ticks(cfg.relay_warning_time, sim))
	check(sim.relay.state == RelayController.State.SPAWNED, "Relay up at %ds" % int(cfg.first_relay_time))
	check(sim.relay.pickup_pocket == cfg.relay_first_pocket, "fixed first pocket")
	check(sim.arena.pockets[sim.relay.pickup_pocket].has_point(sim.relay.pos), "Relay sits in its pocket")
	check(sim.relay.delivery_pocket != sim.relay.pickup_pocket, "delivery pocket is the other one")


func test_pickup_takes_time_and_resets_when_you_step_out() -> void:
	var sim := _spawned()
	var blue := sim.heroes[0]
	var half := _ticks(MatchController.CONFIG.relay_pickup_time * 0.6, sim)
	place(blue, sim.relay.origin)
	run_ticks(sim, half)
	check(sim.relay.state == RelayController.State.SPAWNED, "not picked up yet")
	place(blue, sim.relay.origin + Vector2(0, 3))
	run_ticks(sim, 1)
	place(blue, sim.relay.origin)
	run_ticks(sim, half)
	check(sim.relay.state == RelayController.State.SPAWNED, "stepping out reset the progress")
	run_ticks(sim, half)
	check(sim.relay.state == RelayController.State.CARRIED and sim.relay.carrier_id == blue.id, "blue picked it up")
	check(blue.carrying_relay, "blue knows it is carrying")


func test_both_heroes_on_it_blocks_pickup() -> void:
	var sim := _spawned()
	place(sim.heroes[0], sim.relay.origin + Vector2(0, -0.5))
	place(sim.heroes[1], sim.relay.origin + Vector2(0, 0.5))
	# Stop them fighting so this checks only the pickup rule.
	sim.heroes[0].attack_damage = 0.0
	sim.heroes[1].attack_damage = 0.0
	run_ticks(sim, _ticks(1.5, sim))
	check(sim.relay.state == RelayController.State.SPAWNED, "contested pickup never completes")


func test_carrier_is_slower() -> void:
	var sim := _blue_carrying()
	var blue := sim.heroes[0]
	place(blue, Vector2(0, -10))
	run_ticks(sim, 30, Vector2.DOWN)
	check_near(blue.pos.distance_to(Vector2(0, -10)), blue.data.move_speed * MatchController.CONFIG.relay_carrier_speed_mult, 0.05, "carrier moves at 90% speed")
	check(sim.relay.pos == blue.pos, "Relay travels with the carrier")


func test_one_hero_hit_forces_a_drop() -> void:
	var sim := _blue_carrying()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	check(MatchController.CONFIG.relay_intercept_hits == 1, "Lucy: one hit knocks it loose")
	sim.relay.on_hero_hit(sim, red, blue)
	check(sim.relay.state == RelayController.State.DROPPED, "one enemy-hero hit drops it")
	check(_event(&"relay_dropped").get("reason") == &"intercepted", "drop reason")
	check(not blue.carrying_relay, "blue no longer carrying")


func test_real_attacks_intercept_the_carrier() -> void:
	var sim := _blue_carrying()
	var blue := sim.heroes[0]
	place(blue, Vector2(0, -1.0))
	place(sim.heroes[1], Vector2(0, 1.0))
	blue.attack_damage = 0.0
	var dropped := run_until(sim, func() -> bool: return sim.relay.state == RelayController.State.DROPPED, _ticks(4.0, sim))
	check(dropped, "the red Scout's basic attacks knocked the Relay loose")


func test_minion_and_tower_hits_do_not_intercept() -> void:
	var sim := _blue_carrying()
	var blue := sim.heroes[0]
	var tower := sim.structures_of(MatchSim.RED)[0]
	place(blue, tower.pos + Vector2(0, -4.0))
	blue.max_hp = 99999.0
	blue.hp = blue.max_hp
	sim.spawn_minion(melee(), MatchSim.RED, blue.pos + Vector2(0.6, 0))
	blue.attack_damage = 0.0
	run_ticks(sim, _ticks(5.0, sim))
	check(blue.hp < blue.max_hp, "blue took tower and minion hits")
	check(sim.relay.state == RelayController.State.CARRIED, "still carrying")


func test_manual_drop_lockout_then_repickup() -> void:
	var sim := _blue_carrying()
	var blue := sim.heroes[0]
	var drop := PlayerCommand.new()
	drop.drop_relay = true
	sim.step([drop, null])
	check(sim.relay.state == RelayController.State.DROPPED, "manual drop")
	run_ticks(sim, _ticks(MatchController.CONFIG.relay_drop_lockout, sim) - 2)
	check(sim.relay.state == RelayController.State.DROPPED, "locked out right after the drop")
	run_ticks(sim, _ticks(MatchController.CONFIG.relay_pickup_time, sim) + 4)
	check(sim.relay.state == RelayController.State.CARRIED and sim.relay.carrier_id == blue.id, "picked up again after the lockout")


func test_dropped_relay_returns_home() -> void:
	var sim := _blue_carrying()
	var blue := sim.heroes[0]
	run_ticks(sim, 20, Vector2(1, 0))
	var drop := PlayerCommand.new()
	drop.drop_relay = true
	sim.step([drop, null])
	var dropped_at := sim.relay.pos
	place(blue, Vector2(0, -20))
	check(dropped_at != sim.relay.origin, "dropped away from home")
	run_ticks(sim, _ticks(MatchController.CONFIG.relay_drop_return_time, sim) + 1)
	check(sim.relay.state == RelayController.State.SPAWNED, "back to waiting for a pickup")
	check(sim.relay.pos == sim.relay.origin, "back at its pocket")


func test_knocked_out_carrier_drops_it() -> void:
	var sim := _blue_carrying()
	var blue := sim.heroes[0]
	place(blue, Vector2(-1, 3))
	sim.apply_damage(blue, blue.max_hp + 1.0, sim.heroes[1])
	check(sim.relay.state == RelayController.State.DROPPED, "dropped on knockout")
	check(sim.relay.pos == Vector2(-1, 3), "dropped where the carrier fell")


func test_only_one_carrier() -> void:
	var sim := _blue_carrying()
	var red := sim.heroes[1]
	place(red, sim.heroes[0].pos + Vector2(0.4, 0))
	red.attack_damage = 0.0
	sim.heroes[0].attack_damage = 0.0
	run_ticks(sim, _ticks(2.0, sim))
	check(sim.relay.carrier_id == sim.heroes[0].id, "red can't take it by standing on blue")


func test_delivery_queues_a_siege_minion() -> void:
	var sim := _blue_carrying()
	var blue := sim.heroes[0]
	var cfg := MatchController.CONFIG
	var first_pickup := sim.relay.pickup_pocket
	place(blue, sim.relay.delivery_rect(sim).get_center())
	run_ticks(sim, _ticks(cfg.relay_deliver_time, sim) - 2)
	check(sim.relay.state == RelayController.State.CARRIED, "delivery takes time")
	run_ticks(sim, 3)
	check(_event(&"relay_delivered").get("team") == MatchSim.BLUE, "blue delivered")
	check(sim.relay.state == RelayController.State.DORMANT, "Relay consumed")
	check(sim.pending_siege[MatchSim.BLUE] == 1 and sim.pending_siege[MatchSim.RED] == 0, "one siege minion queued for blue")
	check_near(sim.relay.next_spawn_time, sim.time + cfg.relay_interval, 0.1, "next Relay after the interval")
	check(sim.relay.pickup_pocket != first_pickup, "next Relay starts on the other side")
	check(not blue.carrying_relay, "carrier released")


func test_enemy_in_the_pocket_contests_delivery() -> void:
	var sim := _blue_carrying()
	var rect := sim.relay.delivery_rect(sim)
	place(sim.heroes[0], rect.get_center() + Vector2(0, -4))
	place(sim.heroes[1], rect.get_center() + Vector2(0, 4))
	run_ticks(sim, _ticks(2.0, sim))
	check(sim.relay.state == RelayController.State.CARRIED and sim.relay.contested, "contested: no delivery")
	place(sim.heroes[1], Vector2(0, 30))
	run_ticks(sim, _ticks(MatchController.CONFIG.relay_deliver_time, sim) + 1)
	check(sim.relay.state == RelayController.State.DORMANT, "delivered once the pocket is clear")


func test_untouched_relay_expires() -> void:
	var sim := _spawned()
	var cfg := MatchController.CONFIG
	run_ticks(sim, _ticks(cfg.relay_expire_time, sim) + 1)
	check(not _event(&"relay_expired").is_empty(), "expired")
	check(sim.relay.state == RelayController.State.DORMANT, "dormant until the next one")
	check(sim.relay.pickup_pocket != cfg.relay_first_pocket, "alternates sides")


func test_siege_minion_joins_the_next_wave() -> void:
	var sim := new_sim(true)
	sim.queue_siege(MatchSim.BLUE)
	run_ticks(sim, _ticks(MatchController.CONFIG.first_wave_time, sim) + 1)
	var blue_siege := 0
	var red_siege := 0
	for m in sim.minions:
		if m.is_siege:
			if m.team == MatchSim.BLUE:
				blue_siege += 1
			else:
				red_siege += 1
	check(blue_siege == 1 and red_siege == 0, "one blue siege minion (blue %d, red %d)" % [blue_siege, red_siege])
	check(sim.pending_siege[MatchSim.BLUE] == 0, "reward used up")
