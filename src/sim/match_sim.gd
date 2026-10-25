class_name MatchSim
extends RefCounted
## The authoritative match. Pure logic on a 2D plane: no nodes, meshes or input devices,
## so tests and headless bot runs can step it directly. Views only read from it.

## Fired for things views, HUD and metrics care about: windup_started, windup_cancelled,
## attack_fired, unit_killed, hero_respawned, wave_spawned, match_over, aggro_called,
## and the relay_* events from RelayController.
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
var relay := RelayController.new()
## Skillshots in flight (Abilities).
var skillshots: Array[Skillshot] = []
## Multiplies last-hit gold while an ability hit resolves (Last Call, Sleight of Hand).
var kill_gold_mult := 1.0
## Team of the first hero to reach the ultimate level (Lv5), or -1 while nobody has.
var ult_race_winner := -1
## Banners dropped by special troopers: {"id", "pos", "expires_at"} (see Waves).
var banners: Array[Dictionary] = []
## Per team: a banner was taken, so that team's next wave spawns buffed.
var banner_pending: Array[bool] = [false, false]
## Siege minions each team has earned (Relay deliveries) for its next wave.
var pending_siege: Array[int] = [0, 0]
var over := false
## Overtime (Pacing): structures weakened, tankier waves, longer respawns.
var overtime := false
## Per team: true once the enemy Guardian has fallen (its minions become power minions).
var power_minions: Array[bool] = [false, false]
## Winning team once the match is over, else -1.
var winner := -1
var _next_id := 1
var _next_cast_key := 1


## decks[team] is that hero's six-card item deck (an empty deck means no shopping).
func setup(cfg: MatchConfig, arena_data: ArenaData, hero_picks: Array[HeroData], tiers: Array[StructureData], minion_data: Dictionary = {}, decks: Array = []) -> void:
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
	skillshots.clear()
	banners.clear()
	banner_pending = [false, false]
	kill_gold_mult = 1.0
	ult_race_winner = -1
	next_wave_time = cfg.first_wave_time
	waves_spawned = 0
	pending_siege = [0, 0]
	over = false
	overtime = false
	power_minions = [false, false]
	winner = -1
	_next_id = 1
	_next_cast_key = 1
	for team in [BLUE, RED]:
		for tier in tiers.size():
			var s := StructureState.new()
			s.setup(tiers[tier], tier, team, to_team_space(team, arena.structure_positions[tier]))
			_register(s)
			structures.append(s)
		var h := HeroState.new()
		h.setup(hero_picks[team], team, to_team_space(team, arena.hero_spawn))
		h.gold = cfg.starting_gold
		if team < decks.size():
			h.deck.assign(decks[team])
		_register(h)
		heroes.append(h)
	relay.setup(self)


## Advances one fixed tick. commands[team] is that team's PlayerCommand (or null).
func step(commands: Array) -> void:
	if over:
		return
	for e: SimEntity in entities.values():
		e.prev_pos = e.pos
	for h in heroes:
		h._now = time
	_respawn_heroes()
	_heal_at_base()
	Economy.tick(self)
	Items.tick(self)
	Leveling.tick(self)
	Waves.tick(self)
	Pacing.tick(self)
	for team in [BLUE, RED]:
		var cmd: PlayerCommand = commands[team] if team < commands.size() else null
		if cmd == null:
			cmd = PlayerCommand.new()
		var hero := heroes[team]
		_apply_target_command(hero, cmd)
		if cmd.drop_relay:
			relay.request_drop(self, hero)
		if cmd.sell_slot >= 0:
			Economy.try_sell(self, hero, cmd.sell_slot)
		if cmd.buy_slot >= 0:
			Economy.try_buy(self, hero, cmd.buy_slot)
		if cmd.masterwork_slot >= 0:
			Economy.try_masterwork(self, hero, cmd.masterwork_slot)
		if cmd.buy_scroll:
			Economy.try_siege_scroll(self, hero)
		if cmd.perk_pick >= 0:
			Leveling.pick_perk(self, hero, cmd.perk_pick)
		if cmd.cast_slot >= 0:
			Abilities.try_cast(self, hero, cmd.cast_slot, cmd.move)
		Sprint.tick(self, hero, cmd)
		if Abilities.move_forced(self, hero):
			hero.moving = true  # Dashing or knocked back: no attacking meanwhile.
			hero.still_since = time
		elif hero.is_stunned(time):
			hero.moving = false
		else:
			Movement.move_hero(self, hero, cmd.move, dt)
	Abilities.tick(self)
	if minion_types.size() > 0 and time + 0.0001 >= next_wave_time:
		_spawn_wave()
	for m in minions:
		MinionAI.tick(self, m)
	MinionAI.separate(self)
	for hero in heroes:
		_update_preferred_target(hero)
		var may_attack := hero.alive and not hero.moving and not hero.is_stunned(time) and not hero.is_busy_casting()
		CombatSystem.tick_attack(self, hero, may_attack, Targeting.for_hero.bind(self, hero))
	for s in structures:
		var previous := s.attack_target
		# Locked structures stay dormant: no attacks until the one in front falls.
		CombatSystem.tick_attack(self, s, s.alive and is_exposed(s) and not s.is_busy(time), func() -> SimEntity: return Targeting.for_structure(self, s, previous))
	relay.tick(self)
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


## Deals damage and returns the HP actually removed. kind is &"basic", &"ability" or
## &"item" (see Items): hero sources add item bonuses, hero targets apply their items,
## perks and shields, and hero hits then trigger on-hit item effects.
func apply_damage(target: SimEntity, amount: float, source: SimEntity, kind := &"basic") -> float:
	if not target.alive or amount <= 0.0:
		return 0.0
	if target is StructureState and (not is_exposed(target) or time < target.immune_until):
		return 0.0
	var hero_src := source as HeroState
	if hero_src != null:
		reveal(hero_src)
	if target is HeroState and source != null and source.team != target.team:
		reveal(target)
	if hero_src != null:
		amount = Items.outgoing(self, hero_src, target, amount, kind)
	var raw := amount
	if target is StructureState:
		amount = Pacing.structure_damage_taken(self, target, amount, source)
	if target is HeroState:
		amount = Items.incoming(self, source, target, amount, kind)
		amount = Abilities.modify_hero_damage(self, source, target, amount)
		if hero_src != null and hero_src.team != target.team:
			target.last_hero_damage_time = time
			target.last_hero_combat_time = time
			hero_src.last_hero_combat_time = time
	var dealt := minf(target.hp, maxf(0.0, amount))
	if amount > 0.0 and target is HeroState:
		target.last_damaged_time = time
		Sprint.stop(self, target)
	if amount > 0.0:
		target.hp = maxf(0.0, target.hp - amount)
		if target.hp <= 0.0:
			_kill(target, source)
	if hero_src != null:
		Items.after_hit(self, hero_src, target, dealt, raw, kind)
	return dealt


## Heals a hero, less while it has Wounds (Thorncut). Returns the HP restored.
func heal(h: HeroState, amount: float) -> float:
	if not h.alive or amount <= 0.0:
		return 0.0
	if time < h.wounds_until:
		amount *= 1.0 - h.wounds_amount
	var before := h.hp
	h.hp = minf(h.max_hp, h.hp + amount)
	return h.hp - before


## Hero-hit aggro. Called when a hero's attack lands on the enemy hero: the victim's
## minions near the attacker, and the victim's towers that can reach the attacker,
## switch to the attacker at once (any windup on something else is dropped).
## key groups hits from one ability cast (Barrage pulses) so the Relay counts them once.
func on_hero_hit(attacker: HeroState, victim: HeroState, key := -1) -> void:
	relay.on_hero_hit(self, attacker, victim, key)
	var called: Array[int] = []
	for m in minions:
		if m.alive and m.team == victim.team and m.pos.distance_to(attacker.pos) <= config.minion_call_radius:
			_call_unit(m, attacker, config.minion_call_duration)
			called.append(m.id)
	for s in structures:
		if s.alive and s.team == victim.team and CombatSystem.in_range(self, s, attacker):
			_call_unit(s, attacker, config.tower_call_duration)
			called.append(s.id)
	if not called.is_empty():
		emit_event(&"aggro_called", {"attacker": attacker.id, "units": called})


func _call_unit(u: SimEntity, attacker: HeroState, duration: float) -> void:
	if u.is_winding_up() and u.attack_target != attacker.id:
		CombatSystem.cancel(self, u)
	u.called_target = attacker.id
	u.called_until = time + duration


func next_cast_key() -> int:
	_next_cast_key += 1
	return _next_cast_key


## A Relay delivery: one siege minion joins this team's next wave.
func queue_siege(team: int) -> void:
	pending_siege[team] += 1


func spawn_minion(data: MinionData, team: int, at: Vector2) -> MinionState:
	var m := MinionState.new()
	m.setup(data, team, at)
	m.spawn_wave = waves_spawned
	Pacing.scale_minion(self, m)
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
	Economy.on_kill(self, target, source)
	if target is MinionState:
		Waves.on_minion_killed(self, target)
	if target is HeroState:
		target.deaths += 1
		target.respawn_at = time + Pacing.respawn_delay(self, target)
		target.clear_effects()
		relay.on_hero_killed(self, target)
		Leveling.on_knockout(self, target)
	elif target is StructureState:
		target.blocks_movement = false
		Pacing.on_structure_killed(self, target)
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
			h.clear_effects()
			emit_event(&"hero_respawned", {"id": h.id, "team": h.team})


func _heal_at_base() -> void:
	for h in heroes:
		if h.alive and h.hp < h.max_hp and can_heal_at_base(h):
			heal(h, h.max_hp * config.base_heal_per_second * dt)


## True while this hero stands on its own healing pad and its Guardian still stands.
func can_heal_at_base(h: HeroState) -> bool:
	if h.pos.distance_to(to_team_space(h.team, arena.heal_pad)) > arena.heal_pad_radius:
		return false
	for s in structures_of(h.team):
		if s.is_guardian() and not s.alive:
			return false
	return true


func _apply_target_command(hero: HeroState, cmd: PlayerCommand) -> void:
	if cmd.target_id > 0:
		var t := get_entity(cmd.target_id)
		if CombatSystem.is_valid_target(self, hero, t) or CombatSystem.can_deny(self, hero, t):
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
		var special := Waves.special_for_wave(self, waves_spawned)
		if special != null:
			var sm := spawn_minion(special, team, to_team_space(team, spawn + Waves.special_offset(special)))
			emit_event(&"special_spawned", {"id": sm.id, "team": team, "kind": special.special, "wave": waves_spawned})
		var siege: MinionData = minion_types.get(&"siege")
		while pending_siege[team] > 0 and siege != null:
			pending_siege[team] -= 1
			var m := spawn_minion(siege, team, to_team_space(team, spawn + Vector2(0.0, -2.6)))
			m.is_siege = true
			emit_event(&"siege_spawned", {"id": m.id, "team": team})
		if banner_pending[team]:
			banner_pending[team] = false
			for m in minions:
				if m.team == team and m.spawn_wave == waves_spawned:
					Waves.apply_banner(self, m)
			emit_event(&"banner_wave", {"team": team})
	emit_event(&"wave_spawned", {"wave": waves_spawned})


func _remove_dead_minions() -> void:
	for i in range(minions.size() - 1, -1, -1):
		var m := minions[i]
		if not m.alive:
			entities.erase(m.id)
			minions.remove_at(i)


## The index of the bush at p, or -1.
func bush_at(p: Vector2) -> int:
	for i in arena.bushes.size():
		if arena.bushes[i].has_point(p):
			return i
	return -1


## True if the enemy hero can't see this hero: it stands in a bush, hasn't just given
## itself away, and the enemy hero is neither in the same bush nor right next to it.
func is_hidden(h: HeroState) -> bool:
	if not h.alive or time < h.revealed_until:
		return false
	var bush := bush_at(h.pos)
	if bush < 0:
		return false
	var them := heroes[1 - h.team]
	if them.alive and (bush_at(them.pos) == bush or them.pos.distance_to(h.pos) <= config.bush_reveal_radius):
		return false
	return true


## Attacking, casting and hero damage give a bush hider away for a moment.
func reveal(h: HeroState) -> void:
	h.revealed_until = maxf(h.revealed_until, time + config.bush_reveal_time)


## A fresh id for something that is not an entity (banners).
func new_id() -> int:
	_next_id += 1
	return _next_id - 1


func _register(e: SimEntity) -> void:
	e.id = _next_id
	_next_id += 1
	entities[e.id] = e
