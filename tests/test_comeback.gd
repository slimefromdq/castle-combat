extends TestCase
## Underdog Relay (Comeback): only for a hero who has lost more structures AND is behind
## in level or net worth.


func _kill_outer(sim: MatchSim, team: int) -> StructureState:
	var t := sim.structures_of(team)[0]
	t.hp = 0.0
	t.alive = false
	return t


## Blue lost its Outer Tower; red is a level up. The Relay is about to appear.
func _underdog_sim() -> MatchSim:
	var sim := new_sim()
	_kill_outer(sim, MatchSim.BLUE)
	sim.heroes[1].level = 3
	sim.heroes[1].xp = 300.0
	sim.heroes[1].gold = 900.0
	place(sim.heroes[0], Vector2(0, -36))
	place(sim.heroes[1], Vector2(0, 30))
	sim.relay.next_spawn_time = 0.0
	run_ticks(sim, 1)
	return sim


func test_progress_alone_is_not_enough() -> void:
	var sim := new_sim()
	sim.heroes[1].level = 4
	sim.heroes[1].gold = 3000.0
	check(Comeback.underdog(sim) == -1, "behind in level and gold but no structure lost: no underdog")
	_kill_outer(sim, MatchSim.BLUE)
	sim.heroes[1].level = 1
	sim.heroes[1].gold = 0.0
	check(Comeback.underdog(sim) == -1, "lost a tower but even otherwise: no underdog")
	sim.heroes[1].gold = 250.0
	check(Comeback.underdog(sim) == -1, "a small gold lead doesn't count")
	sim.heroes[1].level = 2
	check(Comeback.underdog(sim) == MatchSim.BLUE, "a tower down and a level behind: underdog")
	_kill_outer(sim, MatchSim.RED)
	check(Comeback.underdog(sim) == -1, "even on structures again: no underdog")


func test_underdog_relay_spawns_at_their_tower_and_pays_on_delivery() -> void:
	var sim := _underdog_sim()
	var blue := sim.heroes[0]
	var guardian := sim.structures_of(MatchSim.BLUE)[1]
	check(sim.relay.underdog == MatchSim.BLUE, "Underdog Relay for blue")
	check(sim.relay.pos.distance_to(guardian.pos) < guardian.radius + 4.0, "it appears in front of blue's Guardian")
	guardian.hp = guardian.max_hp * 0.5
	var gold := blue.gold
	var xp := blue.xp
	place(blue, sim.relay.origin)
	run_ticks(sim, int(sim.config.relay_pickup_time / sim.dt) + 2)
	check(blue.carrying_relay, "blue picked it up")
	place(blue, sim.relay.delivery_point(sim, MatchSim.BLUE))
	run_ticks(sim, int(sim.config.relay_deliver_time / sim.dt) + 2)
	check(not blue.carrying_relay, "delivered at home")
	check(blue.gold - gold > sim.config.relay_gold_base + 100.0, "catch-up gold on top of the normal reward (got %d)" % int(blue.gold - gold))
	check(blue.xp - xp > 50.0, "catch-up XP")
	check(guardian.hp > guardian.max_hp * 0.65, "the Guardian is repaired")


func test_the_leader_must_carry_it_home_and_gets_no_bonus() -> void:
	var sim := _underdog_sim()
	var red := sim.heroes[1]
	place(sim.heroes[0], Vector2(0, -42))
	place(red, sim.relay.origin)
	run_ticks(sim, int(sim.config.relay_pickup_time / sim.dt) + 2)
	check(red.carrying_relay, "red stole it")
	check(not sim.relay.in_delivery_zone(sim, MatchSim.RED, red.pos), "red can't deliver at blue's tower")
	var red_front := sim.front_structure(MatchSim.RED)
	check(sim.relay.in_delivery_zone(sim, MatchSim.RED, sim.relay.delivery_point(sim, MatchSim.RED)), "red's drop-off is its own front structure")
	check(sim.relay.delivery_point(sim, MatchSim.RED).distance_to(red_front.pos) < red_front.radius + 3.0, "next to it")
	var gold := red.gold
	place(red, sim.relay.delivery_point(sim, MatchSim.RED))
	run_ticks(sim, int(sim.config.relay_deliver_time / sim.dt) + 2)
	check(not red.carrying_relay, "delivered")
	check(red.gold - gold < sim.config.relay_gold_base + 20.0, "only the normal reward")
