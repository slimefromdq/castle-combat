class_name BotSource
extends CommandSource
## M0 placeholder bot: patrols its own half and pauses, so there is something to watch
## and the stop/move states are visible. The real utility-based bot arrives in M1.

const PAUSE := 1.5
const PATROL: Array[Vector2] = [Vector2(0, -8.5), Vector2(-3.5, -15), Vector2(3.5, -15)]

var _waypoints: Array[Vector2] = []
var _index := 0
var _wait := 0.0


func reset() -> void:
	_waypoints.clear()
	_index = 0
	_wait = 0.0


func build_command(sim: MatchSim) -> PlayerCommand:
	var cmd := PlayerCommand.new()
	var hero := sim.heroes[team]
	if _waypoints.is_empty():
		for p in PATROL:
			_waypoints.append(MatchSim.to_team_space(team, p))
	if _wait > 0.0:
		_wait -= sim.dt
		return cmd
	var to_goal := _waypoints[_index] - hero.pos
	if to_goal.length() < 0.4:
		_index = (_index + 1) % _waypoints.size()
		_wait = PAUSE
		return cmd
	cmd.move = to_goal.normalized()
	return cmd
