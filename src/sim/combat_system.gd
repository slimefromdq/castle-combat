class_name CombatSystem
## The basic-attack contract, shared by heroes, minions and structures:
##   1. A unit that may attack picks a valid target in range and line of sight.
##   2. It winds up. Anything that stops it attacking (moving, death, target gone) cancels.
##   3. When the windup ends the attack fires and the damage lands at once, on the locked
##      target, wherever it is. Projectiles are cosmetic, so a fired attack can't miss.


static func is_valid_target(sim: MatchSim, attacker: SimEntity, target: SimEntity) -> bool:
	if target == null or not target.alive or target.team < 0:
		return false
	if target.team == attacker.team:
		# A deny: only the hero's own tapped minion, and only once it is low enough.
		return attacker is HeroState and attacker.preferred_target == target.id and can_deny(sim, attacker, target)
	if target is StructureState and not sim.is_exposed(target):
		return false
	return true


## True if this hero may tap its own minion to deny it.
static func can_deny(sim: MatchSim, hero: SimEntity, target: SimEntity) -> bool:
	return hero is HeroState and target is MinionState and target.alive and target.team == hero.team \
			and target.hp <= target.max_hp * sim.config.deny_hp_fraction + 0.0001
	if target is StructureState and not sim.is_exposed(target):
		return false
	return true


## Centre distance minus the target's radius, so big structures can be hit from their edge.
static func in_range(sim: MatchSim, attacker: SimEntity, target: SimEntity, slack := 0.0) -> bool:
	if attacker.pos.distance_to(target.pos) > attacker.attack_range + target.radius + slack:
		return false
	return ArenaGeometry.has_line_of_sight(sim.arena, attacker.pos, target.pos)


## Advances one unit's attack by one tick. choose_target is called only when a new
## windup may start, and returns a SimEntity or null.
static func tick_attack(sim: MatchSim, a: SimEntity, may_attack: bool, choose_target: Callable) -> void:
	a.cooldown_left = maxf(0.0, a.cooldown_left - sim.dt)
	if not a.alive or not may_attack:
		cancel(sim, a)
		return
	if a.is_winding_up():
		var t: SimEntity = sim.get_entity(a.attack_target)
		if not is_valid_target(sim, a, t) or not in_range(sim, a, t, sim.config.windup_range_slack):
			cancel(sim, a)
			return
		a.windup_left -= sim.dt
		if a.windup_left <= 0.0001:
			fire(sim, a, t)
		return
	if a.cooldown_left > 0.0 or a.attack_damage <= 0.0:
		return
	var target: SimEntity = choose_target.call()
	if target == null:
		return
	a.attack_target = target.id
	a.windup_left = a.attack_windup
	sim.emit_event(&"windup_started", {"attacker": a.id, "target": target.id})


static func cancel(sim: MatchSim, a: SimEntity) -> void:
	if a.is_winding_up():
		a.windup_left = -1.0
		sim.emit_event(&"windup_cancelled", {"attacker": a.id})
	a.attack_target = 0


static func fire(sim: MatchSim, a: SimEntity, t: SimEntity) -> void:
	a.windup_left = -1.0
	a.attack_target = 0
	a.cooldown_left = maxf(0.0, a.attack_interval - a.attack_windup)
	var damage := a.attack_damage
	if a is MinionState and t is StructureState:
		damage *= a.data.structure_damage_mult * Economy.minion_structure_mult(sim, a)
	var called := a is StructureState and a.is_called(sim.time) and a.called_target == t.id
	if called:
		damage *= sim.config.tower_call_damage_mult
	sim.emit_event(&"attack_fired", {"attacker": a.id, "target": t.id, "damage": damage, "from": a.pos, "to": t.pos, "called": called})
	sim.apply_damage(t, damage, a)
	if a is HeroState and t is HeroState:
		sim.on_hero_hit(a, t)
