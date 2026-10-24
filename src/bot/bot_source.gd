class_name BotSource
extends CommandSource
## A simple utility bot, good enough to test the loop. Each tick it picks one intent:
## retreat when hurt, defend its front structure, punish a weak hero, or hold the lane
## behind its own minions. It sees only what a player could see, and it obeys the same
## rule as everyone: it has to stand still to attack.

## Last-hits: the bot taps a minion its next attack would kill.
var last_hit := true
var _healing := false


func reset() -> void:
	_healing = false


func build_command(sim: MatchSim) -> PlayerCommand:
	var cmd := PlayerCommand.new()
	var me := sim.heroes[team]
	if not me.alive or sim.over:
		return cmd
	var them := sim.heroes[1 - team]
	var fwd := MatchSim.forward(team)
	var home := sim.front_structure(team)
	var their_front := sim.front_structure(1 - team)
	if last_hit:
		cmd.target_id = _last_hit_target(sim, me)

	# 1. Low on health: walk home and heal at the Core, then come back.
	if me.hp < me.max_hp * 0.35:
		_healing = true
	elif me.hp > me.max_hp * 0.9:
		_healing = false
	if _healing:
		var core: StructureState = sim.structures_of(team)[sim.structures_of(team).size() - 1]
		var spot := core.pos + fwd * 3.0
		if me.pos.distance_to(spot) > 1.0:
			cmd.move = _toward(me, spot)
		return cmd

	# 2. Never tank a tower: leave its range if it is shooting us or nothing of ours is there.
	if their_front != null and me.pos.distance_to(their_front.pos) < their_front.attack_range + their_front.radius + 0.8:
		var covered := _ally_minion_near(sim, their_front.pos, their_front.attack_range + their_front.radius)
		if their_front.attack_target == me.id or not covered:
			cmd.move = _toward(me, their_front.pos - fwd * (their_front.attack_range + their_front.radius + 2.0))
			return cmd

	var goal: Vector2
	var engage: SimEntity = null
	var threat := _threat_near(sim, home, 8.0)
	if threat != null:
		# 3. Defend the front structure.
		engage = threat
		goal = threat.pos
	elif them.alive and them.hp < them.max_hp * 0.35 and me.hp > me.max_hp * 0.5 \
			and (their_front == null or them.pos.distance_to(their_front.pos) > their_front.attack_range + 1.0):
		# 4. Punish a weak hero who is away from their tower.
		engage = them
		goal = them.pos
	elif them.alive and me.pos.distance_to(them.pos) < 8.0 and me.hp / me.max_hp >= them.hp / them.max_hp - 0.1:
		# 5. Even or better trade: fight the hero.
		engage = them
		goal = them.pos
	elif their_front != null and sim.is_exposed(their_front) \
			and _ally_minion_near(sim, their_front.pos, their_front.attack_range * 0.8):
		# 6. Siege: our minions are soaking tower shots, so hit the structure.
		engage = their_front
		goal = their_front.pos
		if cmd.target_id == 0:
			cmd.target_id = their_front.id  # Focus the structure instead of the nearest minion.
	else:
		# 7. Hold the lane just behind our most advanced minion, short of tower range.
		var lead := _lead_minion(sim, fwd)
		goal = (lead.pos - fwd * 1.5) if lead != null else (home.pos + fwd * 3.0 if home != null else me.pos)
		if their_front != null and goal.distance_to(their_front.pos) < their_front.attack_range + their_front.radius + 1.0:
			goal = their_front.pos - fwd * (their_front.attack_range + their_front.radius + 1.5)
		engage = _nearest_enemy_near(sim, me, goal, 6.0)
		if engage is StructureState:
			engage = null

	if engage != null and CombatSystem.in_range(sim, me, engage, -0.2):
		return cmd  # Stand still: the attack happens on its own.
	if engage != null:
		cmd.move = _toward(me, engage.pos)
	elif me.pos.distance_to(goal) > 0.6:
		cmd.move = _toward(me, goal)
	return cmd


func _toward(me: HeroState, p: Vector2) -> Vector2:
	var d := p - me.pos
	return d.normalized() if d.length() > 0.05 else Vector2.ZERO


func _last_hit_target(sim: MatchSim, me: HeroState) -> int:
	for m in sim.minions:
		if CombatSystem.is_valid_target(sim, me, m) and m.hp <= me.attack_damage and CombatSystem.in_range(sim, me, m):
			return m.id
	return 0


func _threat_near(sim: MatchSim, s: StructureState, radius: float) -> SimEntity:
	if s == null:
		return null
	var best: SimEntity = null
	for m in sim.minions:
		if m.team != team and m.pos.distance_to(s.pos) < radius and (best == null or m.pos.distance_to(s.pos) < best.pos.distance_to(s.pos)):
			best = m
	var them := sim.heroes[1 - team]
	if best == null and them.alive and them.pos.distance_to(s.pos) < radius:
		best = them
	return best


func _lead_minion(sim: MatchSim, fwd: Vector2) -> MinionState:
	var best: MinionState = null
	for m in sim.minions:
		if m.team == team and (best == null or m.pos.dot(fwd) > best.pos.dot(fwd)):
			best = m
	return best


func _nearest_enemy_near(sim: MatchSim, me: HeroState, around: Vector2, radius: float) -> SimEntity:
	var best: SimEntity = null
	for m in sim.minions:
		if CombatSystem.is_valid_target(sim, me, m) and m.pos.distance_to(around) < radius \
				and (best == null or m.pos.distance_to(me.pos) < best.pos.distance_to(me.pos)):
			best = m
	var them := sim.heroes[1 - team]
	if them.alive and them.pos.distance_to(around) < radius and (best == null or them.pos.distance_to(me.pos) < best.pos.distance_to(me.pos)):
		best = them
	if best == null:
		var front := sim.front_structure(1 - team)
		if front != null and front.pos.distance_to(around) < radius + front.radius:
			best = front
	return best


func _ally_minion_near(sim: MatchSim, p: Vector2, radius: float) -> bool:
	for m in sim.minions:
		if m.team == team and m.pos.distance_to(p) < radius:
			return true
	return false
