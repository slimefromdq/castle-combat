class_name Abilities
## Hero abilities: casting, follow-up casts, and the effects they leave behind (dashes,
## skillshots, shields, channels, vanish). Abilities aim themselves: the enemy hero in
## reach first, then the nearest enemy unit, then where you face or move. Skillshots fly
## toward that aim and can be dodged. Casting cancels a basic-attack windup; stunned or
## dashing heroes can't cast; the Relay carrier can't use movement abilities.
##
## Follow-up casts press the same button again: Jose's second dash (only after the first
## volley hits) and charged-shot release, Jack's teleport to his cloak and his burst out
## of the shadows.

## A charged shot fires by itself this long after reaching full charge.
const AUTO_RELEASE_GRACE := 0.75


## The ability a slot casts right now. Jack's ultimate is the enemy hero's ultimate
## (null when there is nothing to copy).
static func ability_for(sim: MatchSim, h: HeroState, slot: int) -> AbilityData:
	var a := h.data.abilities[slot]
	if a.effect != &"encore":
		return a
	var them := sim.heroes[1 - h.team]
	if them.data.abilities.size() < 3 or them.data.abilities[2].effect == &"encore":
		return null
	return them.data.abilities[2]


## True if pressing this slot now is a follow-up cast rather than a fresh one.
static func can_recast(sim: MatchSim, h: HeroState, slot: int) -> bool:
	match h.data.abilities[slot].effect:
		&"sweet_talk":
			return h.is_charging()
		&"vanish":
			return h.is_vanished()
	return sim.time < h.recast_until[slot]


## Why a cast would fail, or "" if it can go now.
static func cast_problem(sim: MatchSim, h: HeroState, slot: int) -> String:
	if not h.alive:
		return "knocked out"
	if not h.ability_unlocked(slot):
		return "locked"
	if h.is_stunned(sim.time) or h.is_forced():
		return "busy"
	var a := ability_for(sim, h, slot)
	if a == null:
		return "nothing to copy"
	var recast := can_recast(sim, h, slot)
	var kit := Kits.cast_problem(sim, h, slot, a, recast)
	if kit != "":
		return kit
	if Kits.is_busy(h):
		return "busy"
	if recast:
		if (a.effect == &"cloak_toss" or a.effect == &"threaded_needle") and h.carrying_relay:
			return "carrying the Relay"
		return ""
	if h.cooldowns[slot] > 0.0 and not Kits.has_spare_charge(h, slot):
		return "cooling down"
	if h.is_vanished():
		return "in the shadows"
	if h.is_charging() and slot != 0:
		return "charging"
	if a.is_movement and h.carrying_relay:
		return "carrying the Relay"
	return ""


static func try_cast(sim: MatchSim, h: HeroState, slot: int, move: Vector2) -> bool:
	if cast_problem(sim, h, slot) != "":
		return false
	var a := ability_for(sim, h, slot)
	var recast := can_recast(sim, h, slot)
	CombatSystem.cancel(sim, h)
	# Casting anything else ends a channel, except Showstopper's dash mid-dance.
	if h.channel != null and not (slot == 0 and h.has_special(&"showstopper") > 0.0):
		_end_channel(sim, h)
	sim.reveal(h)
	var key := sim.next_cast_key()
	var info := {"hero": h.id, "team": h.team, "slot": slot, "ability": a.id, "pos": h.pos, "recast": recast}
	var start_cooldown := true
	match a.effect:
		&"cleave":
			info.radius = a.radius
			_cleave(sim, h, a, key)
		&"oath":
			give_shield(sim, h, a)
			h.haste_bonus = a.move_speed_bonus
			h.haste_until = sim.time + a.buff_duration
		&"judgment_blade":
			var t := aim_unit(sim, h, a.reach * 1.15)
			_launch(sim, h, a, _dir(h, move, t), a.damage, a.minion_damage, key).stop_at_hero = true
		&"spin_dash":
			var dir := _dir(h, move, null)
			_force(sim, h, dir * a.distance, a.travel_time)
			h.forced_volley = a
			h.forced_key = key
			h.forced_recast = recast
			if recast:
				h.recast_until[slot] = 0.0
				start_cooldown = false
		&"sweet_talk":
			if recast:
				_release_shot(sim, h, a, move, key)
			else:
				h.charging_since = sim.time
				info.charging = true
				start_cooldown = false
		&"last_tango":
			info.radius = a.radius
			h.channel = a
			h.channel_point = h.pos
			h.channel_pulses_left = a.pulses
			h.channel_next = sim.time + a.duration / maxf(1.0, a.pulses)
			h.channel_key = key
		&"cloak_toss":
			if recast:
				_teleport_to_cloak(sim, h, key)
				start_cooldown = false
			else:
				var t := aim_unit(sim, h, a.reach * 1.15)
				var shot := _launch(sim, h, a, _dir(h, move, t), a.damage, a.minion_damage, key)
				shot.pierce = true
				h.cloak_shot_id = shot.id
				h.cloak_pos = h.pos
				h.recast_until[slot] = sim.time + a.recast_window
		&"vanish":
			if recast:
				_burst(sim, h, a, key)
				start_cooldown = false
			else:
				h.vanish_until = sim.time + a.duration
				_shake_aggro(sim, h)
		_:
			start_cooldown = Kits.cast(sim, h, slot, a, move, recast, key, info)
	if start_cooldown:
		h.cooldowns[slot] = h.ability_cooldown(slot)
	if h.data.abilities[slot].effect == &"encore":
		info.copied = a.id
		_stage_presence(sim, h)
	sim.emit_event(&"ability_cast", info)
	Items.on_cast(sim, h, slot)
	return true


## Per-tick upkeep after movement: cooldowns, expiring effects, channel pulses, skillshots.
static func tick(sim: MatchSim) -> void:
	for h in sim.heroes:
		for i in h.cooldowns.size():
			h.cooldowns[i] = maxf(0.0, h.cooldowns[i] - sim.dt)
		if sim.time >= h.shield_until:
			h.shield_hp = 0.0
			h.shatter_armed = false
			h.charge_ready = false
		# Out of the shadows when time runs out: the burst goes off by itself.
		if h.vanish_until > 0.0 and sim.time + 0.0001 >= h.vanish_until:
			h.vanish_until = 0.0
			if h.alive:
				_burst(sim, h, h.data.abilities[1], sim.next_cast_key())
		if h.is_charging():
			var st := h.data.abilities[1]
			if not h.alive or h.is_stunned(sim.time):
				h.charging_since = -1.0
				h.cooldowns[1] = h.ability_cooldown(1) * 0.5
				sim.emit_event(&"charge_cancelled", {"hero": h.id})
			elif sim.time - h.charging_since >= st.charge_time + AUTO_RELEASE_GRACE:
				_release_shot(sim, h, st, Vector2.ZERO, sim.next_cast_key())
		_tick_channel(sim, h)
	Kits.tick(sim)
	_tick_skillshots(sim)


static func _tick_channel(sim: MatchSim, h: HeroState) -> void:
	if h.channel == null:
		return
	var a := h.channel
	if not h.alive or h.is_stunned(sim.time) or (h.moving and a.move_mult <= 0.0):
		_end_channel(sim, h)
		return
	h.channel_point = h.pos  # The dance moves with Jose.
	if sim.time + 0.0001 < h.channel_next:
		return
	var heal := 0.0
	var tango := h.has_special(&"bloody_tango")
	for e in enemies_near(sim, h, h.channel_point, a.radius):
		var dealt := _hit(sim, h, e, a, h.channel_key)
		heal += dealt * tango
	if heal > 0.0:
		sim.heal(h, heal)
	sim.emit_event(&"channel_pulse", {"hero": h.id, "point": h.channel_point, "radius": a.radius})
	h.channel_pulses_left -= 1
	h.channel_next += a.duration / maxf(1.0, a.pulses)
	if h.channel_pulses_left <= 0:
		_end_channel(sim, h)


static func _end_channel(sim: MatchSim, h: HeroState) -> void:
	if h.channel == null:
		return
	h.channel = null
	sim.emit_event(&"channel_ended", {"hero": h.id})


## Moves a hero along its dash or knockback. Returns true while it is being moved.
static func move_forced(sim: MatchSim, h: HeroState) -> bool:
	if not h.is_forced():
		return false
	h.pos = Movement.slide(sim, h, h.pos, h.forced_vel * sim.dt)
	h.forced_ticks -= 1
	if h.forced_ticks == 0:
		var volley := h.forced_volley
		h.forced_volley = null
		if volley != null:
			_volley(sim, h, volley, h.forced_key, h.forced_recast)
		Kits.forced_ended(sim, h)
	return true


## Damage changes on a hero target: the shadows make Jack immune, shields soak damage,
## and Shatter's shield bursts if it breaks early. Returns the damage that reaches HP.
static func modify_hero_damage(sim: MatchSim, source: SimEntity, target: HeroState, amount: float) -> float:
	if target.is_untargetable():
		return 0.0
	if target.shield_hp > 0.0 and sim.time < target.shield_until:
		var absorbed := minf(target.shield_hp, amount)
		target.shield_hp -= absorbed
		amount -= absorbed
		if target.shield_hp <= 0.0001 and target.shatter_armed:
			target.shatter_armed = false
			_shatter(sim, target)
	return Kits.incoming(sim, source, target, amount)


## Basic-attack damage from a hero, after perks. Returns -1 for a miss (blinded).
static func basic_damage(sim: MatchSim, h: HeroState, t: SimEntity, damage: float) -> float:
	if sim.time < h.blind_until:
		return -1.0
	var mult := 1.0
	var steady := h.has_special(&"steadfast")
	if steady > 0.0 and sim.time - h.still_since >= h.perk_with(&"steadfast").special_duration:
		mult += steady
	if sim.time < h.crit_until:
		h.crit_until = 0.0
		mult += h.has_special(&"smooth_operator")
		sim.emit_event(&"basic_crit", {"hero": h.id, "target": t.id})
	if t is HeroState and sim.time < t.mark_until and t.marked_by == h.id:
		mult += h.has_special(&"lady_killer")
	if t is HeroState and sim.time < t.judged_until and t.judged_by == h.id:
		t.judged_until = 0.0
		mult += h.has_special(&"judgment")
		sim.emit_event(&"judgment_struck", {"hero": h.id, "target": t.id})
	return Kits.basic_damage(sim, h, t, damage * mult)


## After a hero's basic attack lands: Charge's knockback, Encore's dash refund.
static func after_basic(sim: MatchSim, h: HeroState, t: SimEntity) -> void:
	if h.charge_ready and t is HeroState and t.alive and sim.time < h.shield_until:
		h.charge_ready = false
		var away := t.pos - h.pos
		away = away.normalized() if away.length() > 0.01 else h.facing
		var victim := t as HeroState
		_force(sim, victim, away * h.has_special(&"charge"), 0.25, false)
		_interrupt(sim, victim)
	var encore := h.has_special(&"encore")
	if encore > 0.0:
		h.cooldowns[0] = maxf(0.0, h.cooldowns[0] - encore)
	Kits.after_basic(sim, h, t)


## A shield from Oath (and Sanctuary), arming Shatter and Charge if picked.
static func give_shield(sim: MatchSim, h: HeroState, a: AbilityData) -> void:
	h.shield_hp = maxf(h.shield_hp if sim.time < h.shield_until else 0.0, h.max_hp * a.shield_fraction + HeroStats.support_bonus(h, a))
	h.shield_until = sim.time + a.duration
	h.shatter_armed = h.has_special(&"shatter") > 0.0
	h.charge_ready = h.has_special(&"charge") > 0.0


# ------------------------------------------------------------------ Avery

static func _cleave(sim: MatchSim, h: HeroState, a: AbilityData, key: int) -> void:
	var heal := 0.0
	var mercy := h.has_special(&"mercy")
	for e in enemies_near(sim, h, h.pos, a.radius):
		_hit(sim, h, e, a, key)
		heal += (a.heal_per_hero + HeroStats.support_bonus(h, a)) * (mercy if mercy > 0.0 else 1.0) if e is HeroState else a.heal_per_minion
	var healed := sim.heal(h, heal)
	if healed > 0.0:
		sim.emit_event(&"hero_healed", {"hero": h.id, "team": h.team, "amount": healed})


static func _shatter(sim: MatchSim, h: HeroState) -> void:
	var perk := h.perk_with(&"shatter")
	var key := sim.next_cast_key()
	sim.emit_event(&"shield_shattered", {"hero": h.id, "team": h.team, "pos": h.pos, "radius": perk.special_value_2})
	for e in enemies_near(sim, h, h.pos, perk.special_value_2):
		sim.emit_event(&"ability_hit", {"hero": h.id, "target": e.id, "damage": perk.special_value, "ability": &"shatter"})
		sim.apply_damage(e, perk.special_value, h, &"ability")
		if e is HeroState:
			sim.on_hero_hit(h, e, key)


## Judgment Blade lands on a hero: stun it and pull it in front of the caster.
static func _judgment_hit(sim: MatchSim, s: Skillshot, e: HeroState) -> void:
	var h := s.owner
	_stun(sim, e, s.ability.stun)
	var from_me := e.pos - h.pos
	var dir := from_me.normalized() if from_me.length() > 0.01 else h.facing
	var spot := h.pos + dir * (h.radius + e.radius + 0.6)
	_force(sim, e, spot - e.pos, 0.3, false)
	var judgment := h.perk_with(&"judgment")
	if judgment != null:
		e.judged_until = sim.time + judgment.special_duration
		e.judged_by = h.id
	if h.has_special(&"sanctuary") > 0.0 and h.data.abilities.size() > 1 and h.data.abilities[1].effect == &"oath":
		give_shield(sim, h, h.data.abilities[1])


# ------------------------------------------------------------------ Jose

## End of a spin dash: shoot the nearest enemy. The first dash's volley must hit for the
## second dash to open up.
static func _volley(sim: MatchSim, h: HeroState, a: AbilityData, key: int, was_recast: bool) -> void:
	var smooth := h.perk_with(&"smooth_operator")
	if smooth != null:
		h.crit_until = sim.time + smooth.special_duration
	var t := aim_unit(sim, h, a.reach)
	if t != null:
		sim.emit_event(&"volley", {"hero": h.id, "target": t.id, "from": h.pos})
		_hit(sim, h, t, a, key)
	if not was_recast:
		h.recast_until[0] = sim.time + a.recast_window if t != null else 0.0


static func _release_shot(sim: MatchSim, h: HeroState, a: AbilityData, move: Vector2, key: int) -> void:
	var frac := clampf((sim.time - h.charging_since) / maxf(0.01, a.charge_time), 0.0, 1.0)
	h.charging_since = -1.0
	var dmg := lerpf(a.damage, a.max_damage, frac)
	var ratio := a.minion_damage / a.damage if a.minion_damage > 0.0 and a.damage > 0.0 else 1.0
	var t := aim_unit(sim, h, a.reach * 1.1)
	var shot := _launch(sim, h, a, _dir(h, move, t), dmg, dmg * ratio, key)
	shot.charge = frac
	h.cooldowns[1] = h.ability_cooldown(1)


# ------------------------------------------------------------------ Jack

static func _teleport_to_cloak(sim: MatchSim, h: HeroState, key: int) -> void:
	var from := h.pos
	var to := h.cloak_pos
	var flying := cloak_in_flight(sim, h)
	if flying != null:
		to = flying.pos
		flying.done = true
		h.cloak_shot_id = 0
	to = _free_spot(sim, h, to, from)
	h.pos = to
	h.prev_pos = to
	h.recast_until[0] = 0.0
	sim.emit_event(&"teleported", {"hero": h.id, "team": h.team, "from": from, "to": to})
	var decoy := h.perk_with(&"misdirection")
	if decoy != null:
		h.decoy_until = sim.time + decoy.special_duration
		h.decoy_pos = from
		_shake_aggro(sim, h)
	if h.is_vanished():
		_burst(sim, h, h.data.abilities[1], key)


## Bursting out of the shadows: damage around Jack.
static func _burst(sim: MatchSim, h: HeroState, a: AbilityData, key: int) -> void:
	h.vanish_until = 0.0
	sim.emit_event(&"vanish_burst", {"hero": h.id, "team": h.team, "pos": h.pos, "radius": a.radius})
	var hit_hero := false
	var blind := h.perk_with(&"smoke_and_mirrors")
	for e in enemies_near(sim, h, h.pos, a.radius):
		_hit(sim, h, e, a, key)
		if e is HeroState:
			hit_hero = true
			if blind != null:
				e.blind_until = sim.time + blind.special_duration
	var refund := h.has_special(&"vanishing_act")
	if hit_hero and refund > 0.0:
		h.cooldowns[0] = maxf(0.0, h.cooldowns[0] - h.ability_cooldown(0) * refund)


## Stage Presence: casting the copied ultimate grants a shield and ability damage.
static func _stage_presence(sim: MatchSim, h: HeroState) -> void:
	var p := h.perk_with(&"stage_presence")
	if p == null:
		return
	h.shield_hp = maxf(h.shield_hp if sim.time < h.shield_until else 0.0, h.max_hp * p.special_value)
	h.shield_until = sim.time + p.special_duration
	h.power_bonus = p.special_value_2
	h.power_until = sim.time + p.special_duration


## Troopers and towers lose track of this hero (vanish, Misdirection).
static func _shake_aggro(sim: MatchSim, h: HeroState) -> void:
	for u: SimEntity in sim.entities.values():
		if u is HeroState or u.team == h.team:
			continue
		if u.attack_target == h.id:
			CombatSystem.cancel(sim, u)
		if u.called_target == h.id:
			u.called_target = 0


## The nearest spot to `p` (walking back toward `back`) where the hero fits.
static func _free_spot(sim: MatchSim, h: SimEntity, p: Vector2, back: Vector2) -> Vector2:
	var step := (back - p).normalized() * 0.25 if back.distance_to(p) > 0.01 else Vector2.ZERO
	for i in 40:
		if not Movement.is_blocked(sim, h, p):
			return p
		p += step
	return back


# ------------------------------------------------------------------ skillshots

## Jack's cloak while it is still flying, or null once it has landed.
static func cloak_in_flight(sim: MatchSim, h: HeroState) -> Skillshot:
	if h.cloak_shot_id == 0:
		return null
	for s in sim.skillshots:
		if s.id == h.cloak_shot_id:
			return s
	return null


static func _launch(sim: MatchSim, h: HeroState, a: AbilityData, dir: Vector2, dmg: float, minion_dmg: float, key: int) -> Skillshot:
	var s := Skillshot.new()
	s.id = key
	s.owner = h
	s.ability = a
	s.pos = h.pos
	s.dir = dir
	s.speed = a.speed
	s.width = a.width
	s.left = a.reach
	var bonus := HeroStats.ability_bonus(h, a)
	s.damage = dmg + bonus
	s.minion_damage = (minion_dmg if minion_dmg > 0.0 else dmg) + bonus
	s.key = key
	h.facing = dir
	sim.skillshots.append(s)
	sim.emit_event(&"skillshot_launched", {"id": s.id, "hero": h.id, "ability": a.id})
	return s


static func _tick_skillshots(sim: MatchSim) -> void:
	for i in range(sim.skillshots.size() - 1, -1, -1):
		var s := sim.skillshots[i]
		if not s.done:
			_advance(sim, s)
		if s.done:
			Kits.skillshot_ended(sim, s)
			if s.ability.effect == &"cloak_toss" and s.owner.cloak_shot_id == s.id:
				s.owner.cloak_pos = s.pos
				s.owner.cloak_shot_id = 0
			sim.skillshots.remove_at(i)
			sim.emit_event(&"skillshot_ended", {"id": s.id, "pos": s.pos})


static func _advance(sim: MatchSim, s: Skillshot) -> void:
	var step := minf(s.speed * sim.dt, s.left)
	var to := s.pos + s.dir * step
	if not ArenaGeometry.has_line_of_sight(sim.arena, s.pos, to):
		s.done = true
		return
	# Everything the segment touches this tick, nearest first.
	var touched: Array = []
	for e in _skillshot_targets(sim, s):
		var along := clampf((e.pos - s.pos).dot(s.dir), 0.0, step)
		if (s.pos + s.dir * along).distance_to(e.pos) <= s.width + e.radius:
			touched.append([along, e])
	touched.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0] or (x[0] == y[0] and x[1].id < y[1].id))
	for pair in touched:
		var e: SimEntity = pair[1]
		if e is MinionState and e.shield_left > 0:
			# A Shieldbearer's shield stops the shot outright.
			e.shield_left -= 1
			s.pos += s.dir * float(pair[0])
			s.done = true
			sim.emit_event(&"shield_blocked", {"id": e.id, "pos": s.pos, "shot": s.id})
			return
		s.hits[e.id] = true
		_skillshot_hit(sim, s, e)
		if not s.pierce and (not s.stop_at_hero or e is HeroState):
			s.pos += s.dir * float(pair[0])
			s.done = true
			return
	s.pos = to
	s.left -= step
	if s.left <= 0.0001:
		s.done = true


static func _skillshot_targets(sim: MatchSim, s: Skillshot) -> Array[SimEntity]:
	var out: Array[SimEntity] = []
	var them := sim.heroes[1 - s.owner.team]
	if them.alive and not them.is_untargetable() and not s.hits.has(them.id):
		out.append(them)
	if s.heroes_only:
		return out
	for m in sim.minions:
		if m.alive and m.team != s.owner.team and not s.hits.has(m.id):
			out.append(m)
	return out


static func _skillshot_hit(sim: MatchSim, s: Skillshot, e: SimEntity) -> void:
	var h := s.owner
	var dmg := s.damage if e is HeroState else s.minion_damage
	match s.ability.effect:
		&"sweet_talk":
			var last_call := h.has_special(&"last_call")
			if e is MinionState and last_call > 0.0:
				if e.hp <= e.max_hp * last_call:
					dmg = e.hp * 10.0  # Last Call finishes off low troopers.
				sim.kill_gold_mult = 2.0
			_hit(sim, h, e, s.ability, s.key, dmg)
			sim.kill_gold_mult = 1.0
			var lady := h.perk_with(&"lady_killer")
			if e is HeroState and lady != null:
				e.mark_until = sim.time + lady.special_duration
				e.marked_by = h.id
		&"cloak_toss":
			var sleight := h.has_special(&"sleight_of_hand")
			if e is MinionState and sleight > 0.0:
				sim.kill_gold_mult = 1.0 + sleight
			_hit(sim, h, e, s.ability, s.key, dmg)
			sim.kill_gold_mult = 1.0
		&"judgment_blade":
			_hit(sim, h, e, s.ability, s.key, dmg)
			if e is HeroState and e.alive:
				_judgment_hit(sim, s, e)
		_:
			if not Kits.skillshot_hit(sim, s, e):
				_hit(sim, h, e, s.ability, s.key, dmg)


# ------------------------------------------------------------------ helpers

## Deals an ability hit (dmg < 0 = the ability's own numbers). Returns HP removed.
static func _hit(sim: MatchSim, h: HeroState, e: SimEntity, a: AbilityData, key: int, dmg := -1.0) -> float:
	if dmg < 0.0:
		dmg = a.damage if e is HeroState or a.minion_damage <= 0.0 else a.minion_damage
		dmg += HeroStats.ability_bonus(h, a)
	sim.emit_event(&"ability_hit", {"hero": h.id, "target": e.id, "damage": dmg, "ability": a.id})
	var dealt := sim.apply_damage(e, dmg, h, &"ability")
	if e is HeroState:
		sim.on_hero_hit(h, e, key)
	return dealt


static func _stun(sim: MatchSim, e: HeroState, seconds: float) -> void:
	e.stun_until = maxf(e.stun_until, sim.time + seconds)
	_interrupt(sim, e)


## Stuns and knockbacks cut off attacks, channels and charges.
static func _interrupt(sim: MatchSim, e: HeroState) -> void:
	CombatSystem.cancel(sim, e)
	_end_channel(sim, e)
	if e.is_charging():
		e.charging_since = -1.0
		e.cooldowns[1] = e.ability_cooldown(1) * 0.5
		sim.emit_event(&"charge_cancelled", {"hero": e.id})


## Starts a dash or knockback: cover `offset` in `seconds`.
static func _force(sim: MatchSim, h: HeroState, offset: Vector2, seconds: float, turn := true) -> void:
	var ticks := maxi(1, roundi(seconds / sim.dt))
	h.forced_vel = offset / (ticks * sim.dt)
	h.forced_ticks = ticks
	h.forced_volley = null
	if turn and offset.length() > 0.01:
		h.facing = offset.normalized()
	CombatSystem.cancel(sim, h)


## Aim: the player's own aim if they gave one (a real skillshot), else a target if
## there is one (bots), else the way you're moving, else the way you face.
static func _dir(h: HeroState, move: Vector2, toward: SimEntity) -> Vector2:
	if h.aim != Vector2.ZERO:
		h.facing = h.aim
		return h.aim
	if toward != null and toward.pos != h.pos:
		return (toward.pos - h.pos).normalized()
	if move.length() > 0.15:
		return move.normalized()
	return h.facing


static func _aim_hero(sim: MatchSim, h: HeroState, reach: float) -> HeroState:
	var them := sim.heroes[1 - h.team]
	if them.alive and not them.is_untargetable() and not sim.is_hidden(them) and h.pos.distance_to(them.pos) <= reach + them.radius \
			and ArenaGeometry.has_line_of_sight(sim.arena, h.pos, them.pos):
		return them
	return null


## The enemy hero in reach, else the nearest valid enemy unit in reach and sight
## (exposed structures included).
static func aim_any(sim: MatchSim, h: HeroState, reach: float) -> SimEntity:
	var best: SimEntity = _aim_hero(sim, h, reach)
	if best != null:
		return best
	for e: SimEntity in sim.entities.values():
		if e is HeroState or not CombatSystem.is_valid_target(sim, h, e) or e.team == h.team:
			continue
		if h.pos.distance_to(e.pos) > reach + e.radius or not ArenaGeometry.has_line_of_sight(sim.arena, h.pos, e.pos):
			continue
		if best == null or h.pos.distance_squared_to(e.pos) < h.pos.distance_squared_to(best.pos) \
				or (is_equal_approx(h.pos.distance_squared_to(e.pos), h.pos.distance_squared_to(best.pos)) and e.id < best.id):
			best = e
	return best


## Like aim_any, but heroes and troopers only (abilities don't aim at buildings).
static func aim_unit(sim: MatchSim, h: HeroState, reach: float) -> SimEntity:
	var best: SimEntity = _aim_hero(sim, h, reach)
	if best != null:
		return best
	for m in sim.minions:
		if not m.alive or m.team == h.team:
			continue
		if h.pos.distance_to(m.pos) > reach + m.radius or not ArenaGeometry.has_line_of_sight(sim.arena, h.pos, m.pos):
			continue
		if best == null or h.pos.distance_squared_to(m.pos) < h.pos.distance_squared_to(best.pos):
			best = m
	return best


## Enemy heroes and minions within radius of p (a hero in the shadows can't be hit).
static func enemies_near(sim: MatchSim, h: HeroState, p: Vector2, radius: float) -> Array[SimEntity]:
	var out: Array[SimEntity] = []
	var them := sim.heroes[1 - h.team]
	if them.alive and not them.is_untargetable() and them.pos.distance_to(p) <= radius + them.radius:
		out.append(them)
	for m in sim.minions:
		if m.alive and m.team != h.team and m.pos.distance_to(p) <= radius + m.radius:
			out.append(m)
	return out


# ------------------------------------------------------------------ for Kits

static func hit(sim: MatchSim, h: HeroState, e: SimEntity, a: AbilityData, key: int, dmg := -1.0) -> float:
	return _hit(sim, h, e, a, key, dmg)


static func launch(sim: MatchSim, h: HeroState, a: AbilityData, dir: Vector2, dmg: float, minion_dmg: float, key: int) -> Skillshot:
	return _launch(sim, h, a, dir, dmg, minion_dmg, key)


static func aim_dir(h: HeroState, move: Vector2, toward: SimEntity) -> Vector2:
	return _dir(h, move, toward)


static func aim_hero(sim: MatchSim, h: HeroState, reach: float) -> HeroState:
	return _aim_hero(sim, h, reach)


static func force(sim: MatchSim, h: HeroState, offset: Vector2, seconds: float, turn := true) -> void:
	_force(sim, h, offset, seconds, turn)


static func interrupt(sim: MatchSim, e: HeroState) -> void:
	_interrupt(sim, e)


static func stun(sim: MatchSim, e: HeroState, seconds: float) -> void:
	_stun(sim, e, seconds)


static func free_spot(sim: MatchSim, mover: SimEntity, p: Vector2, back: Vector2) -> Vector2:
	return _free_spot(sim, mover, p, back)
