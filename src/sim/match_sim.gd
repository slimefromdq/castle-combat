class_name MatchSim
extends RefCounted
## The authoritative match. Pure logic on a 2D plane: no nodes, meshes or input devices,
## so tests and headless bot runs can step it directly. Views only read from it.

## Fired for things views, HUD and metrics care about (attack fired, KO, Relay changes...).
signal sim_event(type: StringName, data: Dictionary)

const BLUE := 0
const RED := 1

var config: MatchConfig
var arena: ArenaData
var dt := 1.0 / 30.0
var tick := 0
var time := 0.0
var entities: Dictionary = {}
## Indexed by team.
var heroes: Array[HeroState] = []
var structures: Array[StructureState] = []
var _next_id := 1


func setup(cfg: MatchConfig, arena_data: ArenaData, hero_picks: Array[HeroData], tiers: Array[StructureData]) -> void:
	config = cfg
	arena = arena_data
	dt = 1.0 / float(cfg.tick_rate)
	tick = 0
	time = 0.0
	entities.clear()
	heroes.clear()
	structures.clear()
	_next_id = 1
	for team in [BLUE, RED]:
		for tier in tiers.size():
			var s := StructureState.new()
			s.setup(tiers[tier], tier, team, to_team_space(team, arena.structure_positions[tier]))
			_register(s)
			structures.append(s)
		var h := HeroState.new()
		h.setup(hero_picks[team], team, to_team_space(team, arena.hero_spawn))
		_register(h)
		heroes.append(h)


## Advances one fixed tick. commands[team] is that team's PlayerCommand (or null).
func step(commands: Array) -> void:
	for e: SimEntity in entities.values():
		e.prev_pos = e.pos
	for team in [BLUE, RED]:
		var cmd: PlayerCommand = commands[team] if team < commands.size() else null
		if cmd == null:
			cmd = PlayerCommand.new()
		Movement.move_hero(self, heroes[team], cmd.move, dt)
	tick += 1
	time = tick * dt


## Converts a blue-side layout position to the given team's side.
static func to_team_space(team: int, blue_pos: Vector2) -> Vector2:
	return blue_pos if team == BLUE else -blue_pos


## A structure can take damage only after every lower tier on its team has fallen.
func is_exposed(s: StructureState) -> bool:
	for other in structures:
		if other.team == s.team and other.tier < s.tier and other.alive:
			return false
	return true


func structures_of(team: int) -> Array[StructureState]:
	var out: Array[StructureState] = []
	for s in structures:
		if s.team == team:
			out.append(s)
	return out


func emit_event(type: StringName, data: Dictionary = {}) -> void:
	sim_event.emit(type, data)


func _register(e: SimEntity) -> void:
	e.id = _next_id
	_next_id += 1
	entities[e.id] = e
