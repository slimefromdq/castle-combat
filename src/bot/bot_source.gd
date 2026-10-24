class_name BotSource
extends CommandSource
## A simple utility bot, good enough to test the loop. Each tick it picks one intent:
## retreat when hurt, run or chase the Relay, defend its front structure, punish a weak
## hero, trade when the enemy's minions won't punish it, or hold the lane behind its own
## minions. It sees only what a player could see, and it obeys the same rule as
## everyone: it has to stand still to attack.

## Last-hits: the bot taps a minion its next attack would kill.
var last_hit := true
var _healing := false
var _sim: MatchSim
## Items the bot buys, in order, when it can afford them and they are in its deck.
const WISHLISTS := {
	&"vanguard": [&"iron_shell", &"grip_gloves", &"quickstring", &"recovery_sigil"],
	&"scout": [&"grip_gloves", &"fleet_sandals", &"quickstring", &"iron_shell"],
	&"gunner": [&"quickstring", &"grip_gloves", &"watchful_lens", &"iron_shell"],
}
var _points: Array[Vector2] = []


func reset() -> void:
	_healing = false


func build_command(sim: MatchSim) -> PlayerCommand:
	var cmd := PlayerCommand.new()
	_sim = sim
	var me := sim.heroes[team]
	if not me.alive or sim.over:
		return cmd
	var them := sim.heroes[1 - team]
	var fwd := MatchSim.forward(team)
	var home := sim.front_structure(team)
	var their_front := sim.front_structure(1 - team)
	var relay := sim.relay
	cmd.buy_slot = _next_purchase(sim, me)
	if last_hit:
		cmd.target_id = _last_hit_target(sim, me)

	# 1. Low on health: walk home and heal at the Core, then come back.
	#    A carrier keeps going unless it is nearly dead.
	if me.hp < me.max_hp * (0.2 if me.carrying_relay else 0.35):
		_healing = true
	elif me.hp > me.max_hp * 0.9:
		_healing = false
	if _healing:
		cmd.drop_relay = me.carrying_relay
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
	var callers := _enemy_minions_near(sim, me.pos, sim.config.minion_call_radius)
	var under_their_tower := their_front != null and CombatSystem.in_range(sim, their_front, me, 0.5)
	var relay_dist := me.pos.distance_to(relay.pos)
	var their_relay_dist := them.pos.distance_to(relay.pos) if them.alive else INF
	if me.carrying_relay:
		# R1. Carry it to the delivery pocket and stand in the middle until it lands.
		var drop_off := relay.delivery_rect(sim).get_center()
		if me.pos.distance_to(drop_off) > 0.6:
			cmd.move = _toward(me, drop_off)
		return cmd
	elif relay.state == RelayController.State.CARRIED and them.carrying_relay and them.alive \
			and me.hp > me.max_hp * 0.45 and me.pos.distance_to(them.pos) < 20.0:
		# R2. Intercept: two hits knock the Relay loose.
		engage = them
		goal = them.pos
		cmd.target_id = them.id
	elif threat != null:
		# 3. Defend the front structure.
		engage = threat
		goal = threat.pos
	elif relay.is_available(sim.time) and me.hp > me.max_hp * 0.5 and relay_dist < 26.0 \
			and relay_dist <= their_relay_dist + 2.0:
		# R3. Go for the Relay when we would get there first (or tie).
		goal = relay.pos
		if relay_dist < 3.0:
			cmd.move = _toward(me, relay.pos) if relay_dist > 0.3 else Vector2.ZERO
			return cmd
	elif them.alive and them.hp < them.max_hp * 0.35 and me.hp > me.max_hp * 0.5 \
			and (their_front == null or them.pos.distance_to(their_front.pos) > their_front.attack_range + 1.0):
		# 4. Punish a weak hero who is away from their tower, whatever their minions do.
		engage = them
		goal = them.pos
		cmd.target_id = them.id
	elif them.alive and me.pos.distance_to(them.pos) < 8.0 and me.hp / me.max_hp >= them.hp / them.max_hp - 0.1 \
			and callers <= 1 and not under_their_tower:
		# 5. Even or better trade, and hitting them won't pull their wave or tower onto us.
		engage = them
		goal = them.pos
		cmd.target_id = them.id
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

	# Farming near their hero: tap a minion (ranged ones first) so the automatic
	# target isn't their hero, which would call their wave or tower onto us.
	if engage != them and cmd.target_id == 0 and them.alive and CombatSystem.in_range(sim, me, them):
		cmd.target_id = _safe_farm_target(sim, me)
	if engage != null and CombatSystem.in_range(sim, me, engage, -0.2):
		return cmd  # Stand still: the attack happens on its own.
	if engage != null:
		cmd.move = _toward(me, engage.pos)
	elif me.pos.distance_to(goal) > 0.6:
		cmd.move = _toward(me, goal)
	return cmd


## Direction to walk toward p, going around walls through the pocket entrances.
func _toward(me: HeroState, p: Vector2) -> Vector2:
	var next := _next_waypoint(_sim, me, p)
	var d := next - me.pos
	return d.normalized() if d.length() > 0.05 else Vector2.ZERO


## Straight line if it is clear, else the best route through one or two waypoints.
func _next_waypoint(sim: MatchSim, me: HeroState, goal: Vector2) -> Vector2:
	if sim == null or _clear(sim, me.pos, goal, me.radius):
		return goal
	var points := _waypoints(sim)
	var best := goal
	var best_len := INF
	for a in points:
		if not _clear(sim, me.pos, a, me.radius):
			continue
		var first := me.pos.distance_to(a)
		if _clear(sim, a, goal, me.radius):
			if first + a.distance_to(goal) < best_len:
				best_len = first + a.distance_to(goal)
				best = a
			continue
		for b in points:
			if b != a and _clear(sim, a, b, me.radius) and _clear(sim, b, goal, me.radius):
				var total := first + a.distance_to(b) + b.distance_to(goal)
				if total < best_len:
					best_len = total
					best = a
	return best


func _clear(sim: MatchSim, a: Vector2, b: Vector2, r: float) -> bool:
	for wall in sim.arena.walls:
		if ArenaGeometry.segment_hits_rect(a, b, wall.grow(r + 0.1)):
			return false
	return true


## Two points per pocket entrance: one just inside the pocket, one out in the lane.
func _waypoints(sim: MatchSim) -> Array[Vector2]:
	if _points.is_empty():
		for pocket in sim.arena.pockets:
			var c := pocket.get_center()
			var side := signf(c.x)
			var inner_x := c.x - side * 0.5
			var outer_x := side * (sim.arena.lane_half_width - 1.5)
			for sy in [-1.0, 1.0]:
				var y: float = sy * (pocket.size.y / 2.0 + 1.5) / 2.0
				_points.append(Vector2(inner_x, y))
				_points.append(Vector2(outer_x, y))
	return _points


func _last_hit_target(sim: MatchSim, me: HeroState) -> int:
	for m in sim.minions:
		if CombatSystem.is_valid_target(sim, me, m) and m.hp <= me.attack_damage and CombatSystem.in_range(sim, me, m):
			return m.id
	return 0


## The first wishlist item the bot can buy right now (deck slot), or -1.
func _next_purchase(sim: MatchSim, me: HeroState) -> int:
	var wishlist: Array = WISHLISTS.get(me.data.id, [])
	for id: StringName in wishlist:
		for slot in me.deck.size():
			if me.deck[slot].id == id and not me.owns(me.deck[slot]):
				# Save for this one rather than buying something further down the list.
				return slot if Economy.buy_problem(sim, me, slot) == "" else -1
	return -1


func _enemy_minions_near(sim: MatchSim, p: Vector2, radius: float) -> int:
	var n := 0
	for m in sim.minions:
		if m.team != team and m.alive and m.pos.distance_to(p) <= radius:
			n += 1
	return n


## A minion in range to hit instead of the hero: ranged minions first, then the weakest.
func _safe_farm_target(sim: MatchSim, me: HeroState) -> int:
	var best: MinionState = null
	for m in sim.minions:
		if not CombatSystem.is_valid_target(sim, me, m) or not CombatSystem.in_range(sim, me, m):
			continue
		if best == null or (m.data.shape == "ranged" and best.data.shape != "ranged") \
				or (m.data.shape == best.data.shape and m.hp < best.hp):
			best = m
	return best.id if best != null else 0


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
