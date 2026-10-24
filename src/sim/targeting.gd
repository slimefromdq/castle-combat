class_name Targeting
## Who each kind of unit shoots at. Everything here is deterministic: ties go to the
## lower entity id, so replays and tests always agree.


## GDD 6: tapped target if valid, else enemy hero > last-hittable minion > nearest other
## hostile unit > exposed structure. All subject to range and line of sight.
static func for_hero(sim: MatchSim, hero: HeroState) -> SimEntity:
	var preferred: SimEntity = sim.get_entity(hero.preferred_target)
	if _ok(sim, hero, preferred):
		return preferred
	var enemy_hero := sim.heroes[1 - hero.team]
	if _ok(sim, hero, enemy_hero):
		return enemy_hero
	var last_hit: SimEntity = null
	var nearest: SimEntity = null
	for m in sim.minions:
		if not _ok(sim, hero, m):
			continue
		if m.hp <= hero.attack_damage and (last_hit == null or m.hp < last_hit.hp):
			last_hit = m
		if nearest == null or _closer(hero, m, nearest):
			nearest = m
	if last_hit != null:
		return last_hit
	if nearest != null:
		return nearest
	return _nearest_structure(sim, hero, 0.0)


## GDD 5: opposing minions first, then heroes, then the next exposed structure.
## search adds to attack range so minions can notice and walk toward things.
static func for_minion(sim: MatchSim, m: MinionState, search: float) -> SimEntity:
	var best: SimEntity = null
	for other in sim.minions:
		if _in_reach(sim, m, other, search) and (best == null or _closer(m, other, best)):
			best = other
	if best != null:
		return best
	for h in sim.heroes:
		if _in_reach(sim, m, h, search) and (best == null or _closer(m, h, best)):
			best = h
	if best != null:
		return best
	return _nearest_structure(sim, m, search)


## Towers prefer hostile minions, then hostile heroes. They stick to a target while it stays valid.
static func for_structure(sim: MatchSim, s: StructureState, previous_id: int) -> SimEntity:
	var previous: SimEntity = sim.get_entity(previous_id)
	if _ok(sim, s, previous):
		return previous
	var best: SimEntity = null
	for m in sim.minions:
		if _ok(sim, s, m) and (best == null or _closer(s, m, best)):
			best = m
	if best != null:
		return best
	for h in sim.heroes:
		if _ok(sim, s, h) and (best == null or _closer(s, h, best)):
			best = h
	return best


static func _ok(sim: MatchSim, a: SimEntity, t: SimEntity) -> bool:
	return CombatSystem.is_valid_target(sim, a, t) and CombatSystem.in_range(sim, a, t)


static func _in_reach(sim: MatchSim, a: SimEntity, t: SimEntity, search: float) -> bool:
	if not CombatSystem.is_valid_target(sim, a, t):
		return false
	if a.pos.distance_to(t.pos) > a.attack_range + t.radius + search:
		return false
	return ArenaGeometry.has_line_of_sight(sim.arena, a.pos, t.pos)


static func _nearest_structure(sim: MatchSim, a: SimEntity, search: float) -> SimEntity:
	var best: SimEntity = null
	for s in sim.structures:
		if _in_reach(sim, a, s, search) and (best == null or _closer(a, s, best)):
			best = s
	return best


static func _closer(from: SimEntity, x: SimEntity, y: SimEntity) -> bool:
	var dx := from.pos.distance_squared_to(x.pos)
	var dy := from.pos.distance_squared_to(y.pos)
	return dx < dy or (is_equal_approx(dx, dy) and x.id < y.id)
