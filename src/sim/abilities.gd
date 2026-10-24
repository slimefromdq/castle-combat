class_name Abilities
## Hero abilities: casting, aiming, and the effects they leave behind (dashes,
## knockbacks, stuns, slows, shields, buffs, channels). Abilities aim themselves:
## the enemy hero in reach first, then the nearest enemy unit, then where you face.
## Casting cancels a basic-attack windup; stunned or dashing heroes can't cast; the
## Relay carrier can't use movement abilities.


## Why a cast would fail, or "" if it can go now.
static func cast_problem(sim: MatchSim, h: HeroState, slot: int) -> String:
	if not h.alive:
		return "knocked out"
	if not h.ability_unlocked(slot):
		return "locked"
	if h.cooldowns[slot] > 0.0:
		return "cooling down"
	if h.is_stunned(sim.time) or h.is_forced():
		return "busy"
	var a := h.data.abilities[slot]
	if a.is_movement and h.carrying_relay:
		return "carrying the Relay"
	if a.effect == &"blade_rush" and _aim_hero(sim, h, a.reach) == null:
		return "no enemy hero in reach"
	if a.effect == &"power_shot" and aim_any(sim, h, a.reach) == null:
		return "nothing in reach"
	return ""


static func try_cast(sim: MatchSim, h: HeroState, slot: int, move: Vector2) -> bool:
	if cast_problem(sim, h, slot) != "":
		return false
	var a := h.data.abilities[slot]
	CombatSystem.cancel(sim, h)
	h.channel = null
	var key := sim.next_cast_key()
	var info := {"hero": h.id, "team": h.team, "slot": slot, "ability": a.id, "pos": h.pos}
	match a.effect:
		&"bash":
			var t := _aim_hero(sim, h, a.reach)
			var dir := _dir(h, move, t)
			var length := a.distance if t == null else clampf(h.pos.distance_to(t.pos) - 1.0, 0.0, a.distance)
			var knock := a.knockback + _perk_value(h, slot, &"knockback_bonus")
			_force(sim, h, dir * length, a.travel_time, func() -> void: _bash_impact(sim, h, a, knock, key))
		&"shield":
			h.shield_hp = h.max_hp * a.shield_fraction
			h.shield_until = sim.time + a.duration
		&"slam":
			info.radius = a.radius
			for e in _enemies_near(sim, h, h.pos, a.radius):
				_hit(sim, h, e, a, key)
				if e is HeroState:
					_stun(sim, e, a.stun)
		&"dash":
			_force(sim, h, _dir(h, move, null) * a.distance, a.travel_time, Callable())
		&"flurry":
			h.flurry_bonus = a.attack_speed_bonus
			h.flurry_until = sim.time + a.duration
		&"blade_rush":
			var t := _aim_hero(sim, h, a.reach)
			var d := t.pos - h.pos
			var dir := d.normalized() if d.length() > 0.01 else h.facing
			var tid := t.id
			_force(sim, h, dir * (d.length() + 1.2), a.travel_time, func() -> void:
				var target := sim.get_entity(tid)
				if target != null and target.alive:
					_hit(sim, h, target, a, key))
		&"power_shot":
			var t := aim_any(sim, h, a.reach)
			info.target = t.id
			_hit(sim, h, t, a, key)
		&"recoil":
			info.radius = a.radius
			for e in _enemies_near(sim, h, h.pos, a.radius):
				if e is HeroState:
					e.slow_amount = a.slow
					e.slow_until = sim.time + a.duration
			var them := sim.heroes[1 - h.team]
			var away := (h.pos - them.pos).normalized() if them.alive and them.pos.distance_to(h.pos) < 10.0 and them.pos != h.pos else -h.facing
			_force(sim, h, away * a.distance, a.travel_time, Callable(), false)
		&"barrage":
			var reach := a.reach + _perk_value(h, slot, &"reach_bonus")
			var t: SimEntity = _aim_hero(sim, h, reach)
			if t == null:
				t = aim_any(sim, h, reach)
			h.channel = a
			h.channel_point = t.pos if t != null else h.pos + h.facing * 6.0
			h.channel_pulses_left = a.pulses
			h.channel_next = sim.time + a.duration / maxf(1.0, a.pulses)
			h.channel_key = key
			info.point = h.channel_point
			info.radius = a.radius
	h.cooldowns[slot] = h.ability_cooldown(slot)
	sim.emit_event(&"ability_cast", info)
	Items.on_cast(sim, h, slot)
	return true


## Per-tick upkeep after movement: cooldowns, expiring effects, channel pulses.
static func tick(sim: MatchSim) -> void:
	for h in sim.heroes:
		for i in h.cooldowns.size():
			h.cooldowns[i] = maxf(0.0, h.cooldowns[i] - sim.dt)
		if sim.time >= h.shield_until:
			h.shield_hp = 0.0
		if h.channel == null:
			continue
		if not h.alive or h.moving or h.is_stunned(sim.time):
			h.channel = null
			sim.emit_event(&"channel_ended", {"hero": h.id})
			continue
		if sim.time + 0.0001 >= h.channel_next:
			var a := h.channel
			for e in _enemies_near(sim, h, h.channel_point, a.radius, h.has_special(&"siege_battery") > 0.0):
				_hit(sim, h, e, a, h.channel_key)
			sim.emit_event(&"barrage_pulse", {"hero": h.id, "point": h.channel_point, "radius": a.radius})
			h.channel_pulses_left -= 1
			h.channel_next += a.duration / maxf(1.0, a.pulses)
			if h.channel_pulses_left <= 0:
				h.channel = null
				sim.emit_event(&"channel_ended", {"hero": h.id})


## Moves a hero along its dash or knockback. Returns true while it is being moved.
static func move_forced(sim: MatchSim, h: HeroState) -> bool:
	if not h.is_forced():
		return false
	h.pos = Movement.slide(sim, h, h.pos, h.forced_vel * sim.dt)
	h.forced_ticks -= 1
	if h.forced_ticks == 0:
		var action := h.forced_action
		h.forced_action = Callable()
		if action.is_valid():
			action.call()
	return true


## Damage changes from perks and shields. Returns the damage that reaches HP.
static func modify_hero_damage(sim: MatchSim, source: SimEntity, target: HeroState, amount: float) -> float:
	if source is HeroState:
		var finisher := (source as HeroState).has_special(&"finisher")
		if finisher > 0.0 and target.hp < target.max_hp * 0.35:
			amount *= 1.0 + finisher
	if target.shield_hp > 0.0 and sim.time < target.shield_until:
		amount *= 1.0 - target.has_special(&"bulwark_guard")
		var absorbed := minf(target.shield_hp, amount)
		target.shield_hp -= absorbed
		amount -= absorbed
	return amount


static func _bash_impact(sim: MatchSim, h: HeroState, a: AbilityData, knock: float, key: int) -> void:
	for e in _enemies_near(sim, h, h.pos, a.radius):
		_hit(sim, h, e, a, key)
		if e is HeroState and e.alive:
			var away := (e.pos - h.pos)
			away = away.normalized() if away.length() > 0.01 else h.facing
			_force(sim, e, away * knock, 0.25, Callable(), false)


static func _hit(sim: MatchSim, h: HeroState, e: SimEntity, a: AbilityData, key: int) -> void:
	var dmg := a.damage if e is HeroState or a.minion_damage <= 0.0 else a.minion_damage
	sim.emit_event(&"ability_hit", {"hero": h.id, "target": e.id, "damage": dmg, "ability": a.id})
	sim.apply_damage(e, dmg, h, &"ability")
	if e is HeroState:
		sim.on_hero_hit(h, e, key)


static func _stun(sim: MatchSim, e: HeroState, seconds: float) -> void:
	e.stun_until = maxf(e.stun_until, sim.time + seconds)
	CombatSystem.cancel(sim, e)
	e.channel = null


## Starts a dash or knockback: cover `offset` in `seconds`, then run `action`.
static func _force(sim: MatchSim, h: HeroState, offset: Vector2, seconds: float, action: Callable, turn := true) -> void:
	var ticks := maxi(1, roundi(seconds / sim.dt))
	h.forced_vel = offset / (ticks * sim.dt)
	h.forced_ticks = ticks
	h.forced_action = action
	if turn and offset.length() > 0.01:
		h.facing = offset.normalized()
	CombatSystem.cancel(sim, h)
	h.channel = null


static func _dir(h: HeroState, move: Vector2, toward: SimEntity) -> Vector2:
	if toward != null and toward.pos != h.pos:
		return (toward.pos - h.pos).normalized()
	if move.length() > 0.15:
		return move.normalized()
	return h.facing


static func _aim_hero(sim: MatchSim, h: HeroState, reach: float) -> HeroState:
	var them := sim.heroes[1 - h.team]
	if them.alive and h.pos.distance_to(them.pos) <= reach + them.radius \
			and ArenaGeometry.has_line_of_sight(sim.arena, h.pos, them.pos):
		return them
	return null


## The enemy hero in reach, else the nearest valid enemy unit in reach and sight.
static func aim_any(sim: MatchSim, h: HeroState, reach: float) -> SimEntity:
	var best: SimEntity = _aim_hero(sim, h, reach)
	if best != null:
		return best
	for e: SimEntity in sim.entities.values():
		if e is HeroState or not CombatSystem.is_valid_target(sim, h, e) or e.team == h.team:
			continue
		if h.pos.distance_to(e.pos) > reach + e.radius or not ArenaGeometry.has_line_of_sight(sim.arena, h.pos, e.pos):
			continue
		if best == null or h.pos.distance_squared_to(e.pos) < h.pos.distance_squared_to(best.pos):
			best = e
	return best


## Enemy heroes and minions (and exposed structures if asked) within radius of p.
static func _enemies_near(sim: MatchSim, h: HeroState, p: Vector2, radius: float, structures := false) -> Array[SimEntity]:
	var out: Array[SimEntity] = []
	var them := sim.heroes[1 - h.team]
	if them.alive and them.pos.distance_to(p) <= radius + them.radius:
		out.append(them)
	for m in sim.minions:
		if m.alive and m.team != h.team and m.pos.distance_to(p) <= radius + m.radius:
			out.append(m)
	if structures:
		for s in sim.structures:
			if s.alive and s.team != h.team and sim.is_exposed(s) and s.pos.distance_to(p) <= radius + s.radius:
				out.append(s)
	return out


static func _perk_value(h: HeroState, slot: int, property: StringName) -> float:
	var sum := 0.0
	for p in h.owned_perks():
		if p.ability_index == slot:
			sum += float(p.get(property))
	return sum
