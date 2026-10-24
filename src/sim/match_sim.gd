class_name MatchSim
extends RefCounted
## The authoritative match. Pure logic on a 2D plane: no nodes, meshes or input devices,
## so tests and headless bot runs can step it directly. Views only read from it.

## Fired for things views, HUD and metrics care about: windup_started, windup_cancelled,
## attack_fired, unit_killed, hero_respawned, wave_spawned, match_over.
signal sim_event(type: StringName, data: Dictionary)

const BLUE := 0
const RED := 1
## Unit vector from blue's base toward red's. (Godot's Vector2.UP is (0, -1), so it is not used here.)
const BLUE_FORWARD := Vector2(0, 1)

var config: MatchConfig
var arena: ArenaData
var minion_types: Dictionary = {}
var dt := 1.0 / 30.0
var tick := 0
var time := 0.0
var entities: Dictionary = {}
## Indexed by team.
var heroes: Array[HeroState] = []
var structures: Array[StructureState] = []
var minions: Array[MinionState] = []
var next_wave_time := 0.0
var waves_spawned := 0
var over := false
## Winning team once the match is over, else -1.
var winner := -1
var _next_id := 1


func setup(cfg: MatchConfig, arena_data: ArenaData, hero_picks: Array[HeroData], tiers: Array[StructureData], minion_data: Dictionary = {}) -> void:
	config = cfg
	arena = arena_data
	minion_types = minion_data
	dt = 1.0 / float(cfg.tick_rate)
	tick = 0
	time = 0.0
	entities.clear()
	heroes.clear()
	structures.clear()
	minions.clear()
	next_wave_time = cfg.first_wave_time
	waves_spawned = 0
	over = false
	winner = -1
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
	if over:
		return
	for e: SimEntity in entities.values():
		e.prev_pos = e.pos
	_respawn_heroes()
	_heal_at_base()
	for team in [BLUE, RED]:
		var cmd: PlayerCommand = commands[team] if team < commands.size() else null
		if cmd == null:
			cmd = PlayerCommand.new()
		var hero := heroes[team]
		_apply_target_command(hero, cmd)
		Movement.move_hero(self, hero, cmd.move, dt)
	if minion_types.size() > 0 and time + 0.0001 >= next_wave_time:
		_spawn_wave()
	for m in minions:
		MinionAI.tick(self, m)
	MinionAI.separate(self)
	for hero in heroes:
		_update_preferred_target(hero)
		CombatSystem.tick_attack(self, hero, hero.alive and not hero.moving, Targeting.for_hero.bind(self, hero))
	for s in structures:
		var previous := s.attack_target
		CombatSystem.tick_attack(self, s, s.alive, func() -> SimEntity: return Targeting.for_structure(self, s, previous))
	_remove_dead_minions()
	tick += 1
	time = tick * dt


## Converts a blue-side layout position to the given team's side.
static func to_team_space(team: int, blue_pos: Vector2) -> Vector2:
	return blue_pos if team == BLUE else -blue_pos


## Unit vector from this team's base toward the enemy base.
static func forward(team: int) -> Vector2:
	return to_team_space(team, BLUE_FORWARD)


func get_entity(id: int) -> SimEntity:
	return entities.get(id, null)


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


## The lowest-tier structure still standing for a team (its current front line).
func front_structure(team: int) -> StructureState:
	for s in structures_of(team):
		if s.alive:
			return s
	return null


func apply_damage(target: SimEntity, amount: float, source: SimEntity) -> void:
	if not target.alive or amount <= 0.0:
		return
	if target is StructureState and not is_exposed(target):
		return
	target.hp = maxf(0.0, target.hp - amount)
	if target.hp <= 0.0:
		_kill(target, source)


func spawn_minion(data: MinionData, team: int, at: Vector2) -> MinionState:
	var m := MinionState.new()
	m.setup(data, team, at)
	_register(m)
	minions.append(m)
	return m


func emit_event(type: StringName, data: Dictionary = {}) -> void:
	sim_event.emit(type, data)


func _kill(target: SimEntity, source: SimEntity) -> void:
	target.alive = false
	target.windup_left = -1.0
	target.attack_target = 0
	var killer_team := source.team if source != null else -1
	emit_event(&"unit_killed", {"id": target.id, "kind": target.kind, "team": target.team, "killer": source.id if source != null else 0, "killer_team": killer_team})
	if target is HeroState:
		target.respawn_at = time + config.respawn_time
	elif target is StructureState:
		target.blocks_movement = false
		if target.tier == 2:
			over = true
			winner = 1 - target.team
			emit_event(&"match_over", {"winner": winner})


func _respawn_heroes() -> void:
	for h in heroes:
		if not h.alive and time + 0.0001 >= h.respawn_at:
			h.alive = true
			h.hp = h.max_hp
			h.pos = h.spawn_pos
			h.prev_pos = h.spawn_pos
			h.cooldown_left = 0.0
			h.preferred_target = 0
			emit_event(&"hero_respawned", {"id": h.id, "team": h.team})


func _heal_at_base() -> void:
	for h in heroes:
		if not h.alive or h.hp >= h.max_hp:
			continue
		var core := structures_of(h.team)[structures_of(h.team).size() - 1]
		if h.pos.distance_to(core.pos) <= config.base_heal_radius:
			h.hp = minf(h.max_hp, h.hp + h.max_hp * config.base_heal_per_second * dt)


func _apply_target_command(hero: HeroState, cmd: PlayerCommand) -> void:
	if cmd.target_id > 0:
		var t := get_entity(cmd.target_id)
		if CombatSystem.is_valid_target(self, hero, t):
			hero.preferred_target = t.id
			hero.preferred_lost_time = 0.0
			# Switching targets mid-windup restarts the windup on the new target.
			if hero.is_winding_up() and hero.attack_target != t.id:
				CombatSystem.cancel(self, hero)
	elif cmd.target_id < 0:
		hero.preferred_target = 0


## A tapped target is dropped when it dies or stays out of range/sight too long.
func _update_preferred_target(hero: HeroState) -> void:
	if hero.preferred_target == 0:
		return
	var t := get_entity(hero.preferred_target)
	if not CombatSystem.is_valid_target(self, hero, t):
		hero.preferred_target = 0
		return
	if CombatSystem.in_range(self, hero, t):
		hero.preferred_lost_time = 0.0
	else:
		hero.preferred_lost_time += dt
		if hero.preferred_lost_time > config.override_leash_time:
			hero.preferred_target = 0


func _spawn_wave() -> void:
	next_wave_time += config.wave_interval
	waves_spawned += 1
	var spawn := arena.minion_spawn
	for team in [BLUE, RED]:
		var melee: MinionData = minion_types.get(&"melee")
		var ranged: MinionData = minion_types.get(&"ranged")
		for i in config.wave_melee:
			var x := (float(i) - (config.wave_melee - 1) / 2.0) * 1.0
			spawn_minion(melee, team, to_team_space(team, spawn + Vector2(x, 0.0)))
		for i in config.wave_ranged:
			var x := (float(i) - (config.wave_ranged - 1) / 2.0) * 1.0
			spawn_minion(ranged, team, to_team_space(team, spawn + Vector2(x, -0.8)))
	emit_event(&"wave_spawned", {"wave": waves_spawned})


func _remove_dead_minions() -> void:
	for i in range(minions.size() - 1, -1, -1):
		var m := minions[i]
		if not m.alive:
			entities.erase(m.id)
			minions.remove_at(i)


func _register(e: SimEntity) -> void:
	e.id = _next_id
	_next_id += 1
	entities[e.id] = e
