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


## A fresh match with Vanguard (blue) vs Scout (red).
func new_sim() -> MatchSim:
	var sim := MatchSim.new()
	var picks: Array[HeroData] = [MatchController.HEROES[0], MatchController.HEROES[1]]
	sim.setup(MatchController.CONFIG, MatchController.ARENA, picks, MatchController.TIERS)
	return sim


## Steps the sim with the given move for blue (sim space) and nothing for red.
func run_ticks(sim: MatchSim, ticks: int, blue_move := Vector2.ZERO, red_move := Vector2.ZERO) -> void:
	for i in ticks:
		var a := PlayerCommand.new()
		a.move = blue_move
		var b := PlayerCommand.new()
		b.move = red_move
		sim.step([a, b])
