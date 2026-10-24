class_name TestCase
extends RefCounted
## Minimal test base (the project avoids third-party plugins, so no GUT).
## Every method starting with "test_" is run by tests/run_tests.gd.

var failures: Array[String] = []
var _current := ""


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("%s: %s" % [_current, message])


func check_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(actual - expected) <= tolerance, "%s (got %.4f, expected %.4f)" % [message, actual, expected])


## A fresh match with Vanguard (blue) vs Scout (red). Waves are off unless asked for,
## so tests control exactly which units exist.
func new_sim(with_waves := false, blue := 0, red := 1) -> MatchSim:
	var sim := MatchSim.new()
	var picks: Array[HeroData] = [MatchController.HEROES[blue], MatchController.HEROES[red]]
	sim.setup(MatchController.CONFIG, MatchController.ARENA, picks, MatchController.TIERS, MatchController.MINIONS if with_waves else {})
	return sim


func melee() -> MinionData:
	return MatchController.MINIONS[&"melee"]


## Puts a hero somewhere quiet in mid-lane, facing nothing.
func place(e: SimEntity, at: Vector2) -> void:
	e.pos = at
	e.prev_pos = at


## Steps the sim with the given move for blue (sim space) and nothing for red.
func run_ticks(sim: MatchSim, ticks: int, blue_move := Vector2.ZERO, red_move := Vector2.ZERO, blue_target := 0) -> void:
	for i in ticks:
		var a := PlayerCommand.new()
		a.move = blue_move
		a.target_id = blue_target if i == 0 else 0
		var b := PlayerCommand.new()
		b.move = red_move
		sim.step([a, b])


## Steps until cond.call() is true or max_ticks pass. Returns true if cond became true.
func run_until(sim: MatchSim, cond: Callable, max_ticks: int, blue_move := Vector2.ZERO) -> bool:
	for i in max_ticks:
		if cond.call():
			return true
		run_ticks(sim, 1, blue_move)
	return cond.call()
