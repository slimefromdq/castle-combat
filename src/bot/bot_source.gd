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
## Items the bot buys, in order, when they are in its deck. Early items get sold to
## make room for later ones.
const WISHLISTS := {
	&"vanguard": [&"mending_charm", &"trooper_cleaver", &"overcharge_gem", &"stormcrown", &"aegis_mirror"],
	&"scout": [&"trooper_cleaver", &"whetstone", &"bloodthirst_blade", &"reapers_rhythm", &"duelists_crest"],
	&"gunner": [&"mending_charm", &"whetstone", &"executioners_edge", &"duelists_crest", &"titan_core"],
}
## The counter item the bot slots in as its first mid item against each enemy hero.
const COUNTERS := {
	&"gunner": &"warding_cloak",
	&"vanguard": &"overcharge_gem",
	&"scout": &"thorncut",
}
var _points: Array[Vector2] = []
## Items the bot sold this match (it never buys them back).
var _sold := {}


func reset() -> void:
	_healing = false
	_sold.clear()


func build_command(sim: MatchSim) -> PlayerCommand:
	var cmd := _decide(sim)
	var me := sim.heroes[team]
	if me.alive and not sim.over:
		cmd.cast_slot = _choose_ability(sim, me, cmd)
		_dodge_slam(sim, me, cmd)
	return cmd


## A Guardian winding up a slam nearby: walk straight out of it (baiting the slam and
## then hitting the recovering Guardian is the intended play).
func _dodge_slam(sim: MatchSim, me: HeroState, cmd: PlayerCommand) -> void:
	for s in sim.structures:
		if s.alive and s.team != team and s.is_guardian() and s.slam_at >= 0.0 \
				and me.pos.distance_to(s.pos) <= s.data.slam_radius + me.radius + 1.0:
			var away := me.pos - s.pos
			cmd.move = away.normalized() if away.length() > 0.01 else -MatchSim.forward(team)
			cmd.cast_slot = -1
			return


## Which ability to use this tick (-1 for none). Simple rules per kit; the bot avoids
## starting a hero fight that would call the enemy wave or tower, like its basic attacks.
func _choose_ability(sim: MatchSim, me: HeroState, cmd: PlayerCommand) -> int:
	var them := sim.heroes[1 - team]
	var d := me.pos.distance_to(them.pos) if them.alive else INF
	var my_hp := me.hp / me.max_hp
	var their_hp := them.hp / them.max_hp if them.alive else 1.0
	var their_front := sim.front_structure(1 - team)
	var safe := _enemy_minions_near(sim, me.pos, sim.config.minion_call_radius) <= 1 \
			and not (their_front != null and CombatSystem.in_range(sim, their_front, me, 0.5))
	var fight := them.alive and (safe or their_hp < 0.35)
	var ready := func(i: int) -> bool: return Abilities.cast_problem(sim, me, i) == ""
	match me.data.id:
		&"vanguard":
			if ready.call(1) and my_hp < 0.6 and d < 6.0:
				return 1
			if ready.call(2) and fight and d < 4.0 and (their_hp < 0.6 or my_hp < 0.4):
				return 2
			if ready.call(0) and fight and d < 4.5 and my_hp >= their_hp - 0.1:
				return 0
		&"scout":
			if ready.call(0) and _healing and d < 6.0 and cmd.move != Vector2.ZERO:
				return 0  # Escape toward home.
			if ready.call(2) and fight and d < 8.0 and (them.hp < 220.0 or (their_hp < 0.5 and my_hp > 0.5)):
				return 2
			if ready.call(1) and fight and me.attack_target == them.id:
				return 1
			if ready.call(0) and fight and their_hp < 0.35 and d > 3.0 and d < 7.0:
				cmd.move = (them.pos - me.pos).normalized()
				return 0
		&"gunner":
			if ready.call(1) and them.alive and d < 2.6 and them.attack_range < 3.0:
				return 1
			if ready.call(2) and fight and d < 9.0 and (their_hp < 0.7 or them.is_stunned(sim.time)):
				return 2
			if ready.call(0) and fight and d < 8.5:
				return 0
	return -1


func _decide(sim: MatchSim) -> PlayerCommand:
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
	var shop := _shop(sim, me)
	cmd.buy_slot = shop.x
	cmd.sell_slot = shop.y
	if last_hit:
		cmd.target_id = _last_hit_target(sim, me)

	# 1. Low on health: walk to the healing pad behind the Core, then come back.
	#    A carrier keeps going unless it is nearly dead.
	if me.hp < me.max_hp * (0.2 if me.carrying_relay else 0.35):
		_healing = true
	elif me.hp > me.max_hp * 0.9:
		_healing = false
	var pad := MatchSim.to_team_space(team, sim.arena.heal_pad)
	if _healing and (me.pos.distance_to(pad) > sim.arena.heal_pad_radius or sim.can_heal_at_base(me)):
		cmd.drop_relay = me.carrying_relay
		# Far from home and nobody close: recall (stand still) instead of walking.
		var far := me.pos.distance_to(pad) > 12.0
		var quiet := not (them.alive and them.pos.distance_to(me.pos) < 10.0) \
				and _enemy_minions_near(sim, me.pos, 7.0) == 0
		if far and quiet and not me.carrying_relay:
			cmd.recall = me.recall_at < 0.0
			return cmd
		if me.pos.distance_to(pad) > 1.0:
			cmd.move = _toward(me, _around_core(sim, me, pad))
		return cmd
	_healing = false  # The pad is off once our Guardian falls: fight on.

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
		var drop_off := relay.delivery_point(sim, team)
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
## The healing pad sits behind the Core: step around the Core's side first.
func _around_core(sim: MatchSim, me: HeroState, goal: Vector2) -> Vector2:
	var core: StructureState = sim.structures_of(team)[sim.structures_of(team).size() - 1]
	var local := MatchSim.to_team_space(team, me.pos)
	var core_local := MatchSim.to_team_space(team, core.pos)
	var clearance := core.radius + me.radius + 0.6
	if core.alive and local.y > core_local.y - 0.3 and absf(local.x - core_local.x) < clearance:
		var side := 1.0 if local.x >= core_local.x else -1.0
		return MatchSim.to_team_space(team, Vector2(core_local.x + side * (clearance + 0.3), core_local.y))
	return goal


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


## A minion our next hit would kill: an enemy one (last hit) or, failing that, one of
## our own that is low enough to deny.
func _last_hit_target(sim: MatchSim, me: HeroState) -> int:
	var deny := 0
	for m in sim.minions:
		if m.hp > me.attack_damage or not CombatSystem.in_range(sim, me, m):
			continue
		if CombatSystem.is_valid_target(sim, me, m):
			return m.id
		# Deny only when it costs their hero gold, or we'd thin our own wave for nothing.
		var them := sim.heroes[1 - team]
		if deny == 0 and CombatSystem.can_deny(sim, me, m) and them.alive \
				and them.pos.distance_to(m.pos) <= sim.config.minion_gold_radius:
			deny = m.id
	return deny


## The wishlist with the counter for this matchup moved in as the first mid item.
func _wishlist(sim: MatchSim, me: HeroState) -> Array:
	var wish: Array = WISHLISTS.get(me.data.id, []).duplicate()
	var counter: StringName = COUNTERS.get(sim.heroes[1 - team].data.id, &"")
	if counter != &"" and _deck_slot(me, counter) >= 0 and not wish.has(counter):
		wish.insert(mini(2, wish.size()), counter)
	return wish


## (buy slot, sell slot) for this tick, -1 for none. Saves up for the next wishlist
## item; when slots are full, sells the cheapest lower-tier item once that covers it.
func _shop(sim: MatchSim, me: HeroState) -> Vector2i:
	for id: StringName in _wishlist(sim, me):
		var slot := _deck_slot(me, id)
		if slot < 0 or me.owns(me.deck[slot]) or _sold.has(id):
			continue
		var want := me.deck[slot]
		var problem := Economy.buy_problem(sim, me, slot)
		if problem == "":
			return Vector2i(slot, -1)
		if problem != "item slots full":
			return Vector2i(-1, -1)
		var sell := -1
		for i in me.deck.size():
			var it := me.deck[i]
			if me.owns(it) and it.tier < want.tier and (sell < 0 or it.cost < me.deck[sell].cost):
				sell = i
		if sell >= 0 and me.gold + Economy.sell_value(sim, me.deck[sell]) + 0.0001 >= want.cost:
			_sold[me.deck[sell].id] = true
			return Vector2i(-1, sell)
		return Vector2i(-1, -1)
	return Vector2i(-1, -1)


func _deck_slot(me: HeroState, id: StringName) -> int:
	for i in me.deck.size():
		if me.deck[i].id == id:
			return i
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
