class_name Kits
## Round-2 hero kits: Ahab, Slayer, Huddle, Poppet and Tot. Abilities (src/sim/abilities.gd)
## calls in here for their effects, so the first three heroes stay as they were. The
## occult heroes (Serpent, Fermata, KOSMONAUT) live in OccultKits, reached from here.
##
## Shared pieces they introduce:
##   roots (can't walk, can still attack and cast), silence (can't cast), short untouchable
##   phases, damage over time (bleeds, Latch Cloud), traps, delayed casts (telegraphed
##   whale and axe), Buzz stacks (Huddle) and Blood Debt (Tot: damage postponed, cancelled
##   by hitting the enemy hero, paid in full if his ultimate fails).

## Tot's trait: this share of every hit he takes is postponed into Debt.
const DEBT_SHARE := 0.35
## Debt drains into real damage this fast (HP per second).
const DEBT_DRAIN := 30.0
## Absolute Rule: a knockout this long after it ends still forgives the Debt.
const RULE_GRACE := 1.0
## Buzz: stacks that set off an Overwhelm, its damage and slow.
const BUZZ_STACKS := 5
const OVERWHELM_DAMAGE := 50.0
const OVERWHELM_AP := 0.5
const OVERWHELM_SLOW := 0.25
const OVERWHELM_SLOW_TIME := 1.0
## Displacement: a hero Ahab hooks or flings into his tower's range draws it this long.
const DISPLACE_DRAW_TIME := 2.0
## Threaded Needle reels Poppet in this fast (m/s).
const REEL_SPEED := 18.0

## True while a damage-over-time tick or an Overwhelm is dealing damage, so they don't
## add Buzz of their own.
static var _quiet := false


# ---------------------------------------------------------------- casting

## Why this kit's cast would fail, or "".
static func cast_problem(sim: MatchSim, h: HeroState, slot: int, a: AbilityData, recast: bool) -> String:
	if sim.time < h.silence_until:
		return "silenced"
	if recast:
		return ""
	if a.is_movement and h.is_rooted() and a.effect != &"shed_skin":
		return "rooted"
	match a.effect:
		&"keelhaul":
			if Abilities.aim_unit(sim, h, a.reach) == null:
				return "no one in reach"
		&"swarm_storm":
			if Abilities.aim_hero(sim, h, a.reach) == null:
				return "no hero in reach"
		&"cut_to_ribbons":
			if Abilities.aim_unit(sim, h, a.reach) == null:
				return "no one in reach"
	return ""


## Casts one of the round-2 abilities. Returns false if the cooldown should not start
## (a follow-up cast).
static func cast(sim: MatchSim, h: HeroState, slot: int, a: AbilityData, move: Vector2, recast: bool, key: int, info: Dictionary) -> bool:
	match a.effect:
		&"harpoon":
			var reach := a.reach + h.has_special(&"long_line")
			var t := Abilities.aim_unit(sim, h, reach * 1.1)
			var shot := Abilities.launch(sim, h, a, Abilities.aim_dir(h, move, t), a.damage, a.minion_damage, key)
			shot.left = reach
		&"keelhaul":
			_keelhaul(sim, h, a, key)
		&"white_whale", &"headsmans_axe":
			var reach := a.reach + (h.has_special(&"thar_she_blows") if a.effect == &"white_whale" else 0.0)
			var t := Abilities.aim_unit(sim, h, reach)
			h.delayed = a
			h.delayed_at = sim.time + a.delay
			h.delayed_dir = Abilities.aim_dir(h, move, t)
			h.delayed_key = key
			h.delayed_reach = reach
			info.delay = a.delay
			info.dir = h.delayed_dir
			info.length = reach
			info.width = a.width
		&"bear_trap":
			_set_trap(sim, h, a, move)
		&"recoil_bolt":
			var t := Abilities.aim_unit(sim, h, a.reach * 1.1)
			var dir := Abilities.aim_dir(h, move, t)
			Abilities.launch(sim, h, a, dir, a.damage, a.minion_damage, key)
			Abilities.force(sim, h, -dir * a.distance, a.travel_time, false)
			h.facing = dir
		&"latch_cloud":
			var t := Abilities.aim_hero(sim, h, a.reach * 1.1)
			Abilities.launch(sim, h, a, Abilities.aim_dir(h, move, t), a.damage, a.damage, key).heroes_only = true
		&"scatter":
			_scatter(sim, h, a, move, info)
		&"swarm_storm":
			_engulf(sim, h, a)
		&"threaded_needle":
			if recast:
				_reel(sim, h)
				return false
			var t := Abilities.aim_unit(sim, h, a.reach * 1.1)
			Abilities.launch(sim, h, a, Abilities.aim_dir(h, move, t), a.damage, a.minion_damage, key)
			if h.cooldowns[slot] > 0.0 and h.bonus_charges[slot] > 0:
				h.bonus_charges[slot] -= 1
				return false  # Pincushion's second charge.
		&"wind_up_key":
			_wind_up(sim, h, a, key)
		&"cut_to_ribbons":
			_ribbons(sim, h, a)
		&"sovereign_sweep":
			_sweep(sim, h, a, move, key, info)
		&"borrowed_time":
			h.borrowed_until = sim.time + a.duration
			h.haste_bonus = a.move_speed_bonus
			h.haste_until = sim.time + a.buff_duration
			var lunge := h.has_special(&"charge_of_faith")
			if lunge > 0.0:
				Abilities.force(sim, h, Abilities.aim_dir(h, move, Abilities.aim_hero(sim, h, 6.0)) * lunge, 0.25)
		&"absolute_rule":
			_absolute_rule(sim, h, a, move)
		_:
			return OccultKits.cast(sim, h, slot, a, move, recast, key, info)
	return true


## A charge-based slot (Pincushion) may cast while cooling down if a charge is left.
static func has_spare_charge(h: HeroState, slot: int) -> bool:
	return h.bonus_charges[slot] > 0


static func max_bonus_charges(h: HeroState, slot: int) -> int:
	if slot == 0 and h.has_special(&"pincushion") > 0.0:
		return int(h.has_special(&"pincushion")) - 1
	return 0


# ---------------------------------------------------------------- per tick

static func tick(sim: MatchSim) -> void:
	for h in sim.heroes:
		_tick_charges(sim, h)
		if not h.alive:
			continue
		_tick_delayed(sim, h)
		_tick_thread(sim, h)
		_tick_engulf(sim, h)
		_tick_ribbons(sim, h)
		_tick_debt(sim, h)
	_tick_traps(sim)
	_tick_dots(sim)
	_tick_clouds(sim)
	OccultKits.tick(sim)


static func _tick_charges(_sim: MatchSim, h: HeroState) -> void:
	for slot in h.bonus_charges.size():
		var cap := max_bonus_charges(h, slot)
		if h.bonus_charges[slot] > cap:
			h.bonus_charges[slot] = cap
		if h.cooldowns[slot] <= 0.0 and h.bonus_charges[slot] < cap and h.alive:
			h.bonus_charges[slot] += 1
			h.cooldowns[slot] = h.ability_cooldown(slot)


# ---------------------------------------------------------------- Ahab

static func _keelhaul(sim: MatchSim, h: HeroState, a: AbilityData, key: int) -> void:
	var t := Abilities.aim_unit(sim, h, a.reach)
	if t == null:
		return
	var away := h.pos - t.pos
	away = away.normalized() if away.length() > 0.01 else -h.facing
	var goal := h.pos + away * (a.distance + h.radius)
	if h.has_special(&"heave_ho") > 0.0 and h.aim != Vector2.ZERO:
		goal = h.pos + h.aim * (a.distance + h.radius)
	Abilities.hit(sim, h, t, a, key)
	if not t.alive:
		return
	sim.emit_event(&"flung", {"hero": h.id, "target": t.id, "from": t.pos, "to": goal})
	if t is HeroState:
		Abilities.force(sim, t, goal - t.pos, a.travel_time, false)
		Abilities.interrupt(sim, t)
		_displaced_by(t, h, &"fling", goal)
	else:
		t.pos = Abilities.free_spot(sim, t, goal, h.pos)


## The hook lands: pull the target in front of Ahab.
static func _hooked(sim: MatchSim, s: Skillshot, e: SimEntity) -> void:
	var h := s.owner
	Abilities.hit(sim, h, e, s.ability, s.key, s.damage if e is HeroState else s.minion_damage)
	if not e.alive:
		return
	var from_me := e.pos - h.pos
	var dir := from_me.normalized() if from_me.length() > 0.01 else h.facing
	var spot := h.pos + dir * (h.radius + e.radius + 0.5)
	sim.emit_event(&"hooked", {"hero": h.id, "target": e.id, "from": e.pos, "to": spot})
	if e is HeroState:
		Abilities.force(sim, e, spot - e.pos, 0.3, false)
		Abilities.interrupt(sim, e)
		_displaced_by(e, h, &"hook", spot)
		var barb := h.perk_with(&"barbed_hook")
		if barb != null:
			slow(sim, e, barb.special_value, barb.special_duration)
	else:
		e.pos = Abilities.free_spot(sim, e, spot, e.pos)


static func _displaced_by(victim: HeroState, by: HeroState, how: StringName, goal: Vector2) -> void:
	victim.forced_by = by.id
	victim.forced_how = how
	victim.forced_goal = goal


## A forced move ends (called by Abilities.move_forced): walls, towers and perks.
static func forced_ended(sim: MatchSim, victim: HeroState) -> void:
	if victim.forced_by == 0:
		return
	var by := sim.get_entity(victim.forced_by) as HeroState
	var how := victim.forced_how
	var blocked := victim.pos.distance_to(victim.forced_goal) > 0.6
	victim.forced_by = 0
	victim.forced_how = &""
	if by == null or not victim.alive:
		return
	match how:
		&"hook", &"fling":
			draw_onto(sim, by, victim, DISPLACE_DRAW_TIME, false)
			if how == &"fling" and blocked:
				var overboard := by.has_special(&"man_overboard")
				if overboard > 0.0:
					Abilities.stun(sim, victim, overboard)
		&"whale":
			var gang := by.perk_with(&"press_gang")
			draw_onto(sim, by, victim, gang.special_duration if gang != null else DISPLACE_DRAW_TIME, gang != null)
		&"pin":
			if blocked:
				root(sim, victim, by.has_special(&"pinned"))
		&"rule":
			_rule_landed(sim, victim)


## The owner's towers that can reach the victim (and, if asked, its troopers nearby)
## turn on the victim, as if the victim had hit the owner.
static func draw_onto(sim: MatchSim, owner: HeroState, victim: HeroState, seconds: float, troopers: bool) -> void:
	var called: Array[int] = []
	for st in sim.structures:
		if st.alive and st.team == owner.team and sim.is_exposed(st) and CombatSystem.in_range(sim, st, victim):
			sim.call_unit(st, victim, seconds)
			called.append(st.id)
	if troopers:
		for m in sim.minions:
			if m.alive and m.team == owner.team and m.pos.distance_to(victim.pos) <= sim.config.minion_call_radius:
				sim.call_unit(m, victim, seconds)
				called.append(m.id)
	if not called.is_empty():
		sim.emit_event(&"aggro_called", {"attacker": victim.id, "units": called})


# ---------------------------------------------------------------- delayed casts

static func _tick_delayed(sim: MatchSim, h: HeroState) -> void:
	if h.delayed == null or sim.time + 0.0001 < h.delayed_at:
		return
	var a := h.delayed
	h.delayed = null
	match a.effect:
		&"white_whale":
			_breach(sim, h, a)
		&"headsmans_axe":
			var shot := Abilities.launch(sim, h, a, h.delayed_dir, a.damage, a.minion_damage, h.delayed_key)
			shot.pierce = true
			shot.left = h.delayed_reach


static func _breach(sim: MatchSim, h: HeroState, a: AbilityData) -> void:
	var origin := h.pos
	var dir := h.delayed_dir
	var length := h.delayed_reach
	var end := origin + dir * length
	sim.emit_event(&"whale_breach", {"hero": h.id, "team": h.team, "from": origin, "to": end, "width": a.width})
	for e in Abilities.enemies_near(sim, h, origin + dir * length * 0.5, length * 0.5 + a.width + 1.0):
		var along := clampf((e.pos - origin).dot(dir), 0.0, length)
		if (origin + dir * along).distance_to(e.pos) > a.width + e.radius:
			continue
		Abilities.hit(sim, h, e, a, h.delayed_key)
		if not e.alive:
			continue
		var spot := Abilities.free_spot(sim, e, end, origin + dir * along)
		if e is HeroState:
			Abilities.stun(sim, e, a.stun)
			Abilities.force(sim, e, spot - e.pos, a.travel_time, false)
			_displaced_by(e, h, &"whale", spot)
		else:
			e.pos = spot


# ---------------------------------------------------------------- Slayer

static func trap_limit(h: HeroState, a: AbilityData) -> int:
	var more := int(h.has_special(&"set_and_forget"))
	return more if more > 0 else maxi(1, a.pulses)


static func _set_trap(sim: MatchSim, h: HeroState, a: AbilityData, move: Vector2) -> void:
	var them := Abilities.aim_hero(sim, h, a.reach + 0.5)
	var dir := Abilities.aim_dir(h, move, them)
	var spot := h.pos + dir * a.reach * 0.7
	if them != null and (h.aim == Vector2.ZERO or h.aim.dot((them.pos - h.pos).normalized()) > 0.8):
		spot = them.pos
	spot = Abilities.free_spot(sim, h, spot, h.pos)
	var mine: Array = sim.traps.filter(func(t: Dictionary) -> bool: return t.owner == h.id)
	while mine.size() >= trap_limit(h, a):
		var oldest: Dictionary = mine.pop_front()
		sim.traps.erase(oldest)
		sim.emit_event(&"trap_gone", {"id": oldest.id})
	var trap := {"id": sim.new_id(), "owner": h.id, "team": h.team, "pos": spot, "armed_at": sim.time + a.delay, "ability": a}
	sim.traps.append(trap)
	sim.emit_event(&"trap_set", {"id": trap.id, "hero": h.id, "team": h.team, "pos": spot, "armed_at": trap.armed_at})


static func _tick_traps(sim: MatchSim) -> void:
	for i in range(sim.traps.size() - 1, -1, -1):
		var t: Dictionary = sim.traps[i]
		if sim.time < t.armed_at:
			continue
		var owner := sim.get_entity(t.owner) as HeroState
		var victim := sim.heroes[1 - int(t.team)]
		if owner == null or not victim.alive or victim.is_untargetable() or victim.is_forced():
			continue
		var a: AbilityData = t.ability
		if victim.pos.distance_to(t.pos) > a.radius + victim.radius * 0.5:
			continue
		sim.traps.remove_at(i)
		sim.emit_event(&"trap_sprung", {"id": t.id, "hero": owner.id, "target": victim.id, "pos": t.pos})
		Abilities.hit(sim, owner, victim, a, sim.next_cast_key())
		if victim.alive:
			root(sim, victim, a.root)
			var jaws := owner.perk_with(&"serrated_jaws")
			if jaws != null:
				add_dot(sim, owner, victim, victim.max_hp * jaws.special_value, jaws.special_duration, 4)


static func _bolt_hit(sim: MatchSim, s: Skillshot, e: SimEntity) -> void:
	var h := s.owner
	var a := s.ability
	Abilities.hit(sim, h, e, a, s.key, s.damage if e is HeroState else s.minion_damage)
	if not (e is HeroState) or not e.alive:
		return
	slow(sim, e, a.slow, a.slow_time)
	var mark := h.perk_with(&"hunters_mark")
	if mark != null:
		e.hunt_mark_by = h.id
		e.hunt_mark_left = int(mark.special_value_2)
		e.hunt_mark_until = sim.time + mark.special_duration
		sim.emit_event(&"marked", {"hero": h.id, "target": e.id})
	var pin := h.perk_with(&"pinned")
	if pin != null:
		var goal: Vector2 = e.pos + s.dir * pin.special_value_2
		Abilities.force(sim, e, goal - e.pos, 0.15, false)
		_displaced_by(e, h, &"pin", goal)


static func _axe_hit(sim: MatchSim, s: Skillshot, e: SimEntity) -> void:
	var h := s.owner
	var a := s.ability
	if not (e is HeroState):
		Abilities.hit(sim, h, e, a, s.key, s.minion_damage)
		return
	var hero := e as HeroState
	var rooted := hero.is_rooted()
	Abilities.hit(sim, h, hero, a, s.key, s.damage + hero.max_hp * a.extra)
	if hero.alive and a.bleed_fraction > 0.0:
		var bleed := hero.max_hp * a.bleed_fraction * (0.5 if s.returning else 1.0)
		if rooted:
			Abilities.hit(sim, h, hero, a, s.key, bleed)  # A trapped target takes it all at once.
		else:
			add_dot(sim, h, hero, bleed, a.bleed_time, 6)
	if not hero.alive:
		var trophy := h.has_special(&"trophy")
		if trophy > 0.0:
			h.cooldowns[2] = maxf(0.0, h.cooldowns[2] - h.ability_cooldown(2) * trophy)


## A skillshot ran out or hit a wall: Boomerang sends the axe back once.
static func skillshot_ended(sim: MatchSim, s: Skillshot) -> void:
	if s.ability.effect == &"latch_cloud" and s.hits.is_empty() and s.owner.alive:
		# A miss hangs in the air: the enemy hero walking into it gets latched.
		var cloud := {"id": sim.new_id(), "shot": s, "pos": s.pos, "until": sim.time + LATCH_LINGER, "team": s.owner.team}
		sim.clouds.append(cloud)
		sim.emit_event(&"cloud_lingering", {"id": cloud.id, "pos": s.pos, "until": cloud.until, "team": cloud.team})
		return
	if s.ability.effect != &"headsmans_axe" or s.returning:
		return
	var h := s.owner
	var back := h.has_special(&"boomerang")
	if back <= 0.0 or not h.alive:
		return
	var to := h.pos - s.pos
	if to.length() < 0.5:
		return
	var shot := Abilities.launch(sim, h, s.ability, to.normalized(), s.ability.damage * back, s.ability.minion_damage * back, s.key)
	shot.pierce = true
	shot.returning = true
	shot.pos = s.pos
	shot.left = to.length()
	h.facing = -to.normalized() if to.length() > 0.01 else h.facing


# ---------------------------------------------------------------- Huddle

## A missed Latch Cloud lingers this long, and latches onto a hero this close to it.
const LATCH_LINGER := 2.0
const LATCH_LINGER_RADIUS := 1.2


static func _tick_clouds(sim: MatchSim) -> void:
	for i in range(sim.clouds.size() - 1, -1, -1):
		var c: Dictionary = sim.clouds[i]
		var s: Skillshot = c.shot
		var them := sim.heroes[1 - int(c.team)]
		if sim.time >= c.until or not s.owner.alive:
			sim.clouds.remove_at(i)
			sim.emit_event(&"cloud_gone", {"id": c.id})
			continue
		if them.alive and not them.is_untargetable() and them.pos.distance_to(c.pos) <= LATCH_LINGER_RADIUS + them.radius:
			sim.clouds.remove_at(i)
			sim.emit_event(&"cloud_gone", {"id": c.id})
			_latched(sim, s, them)

static func _latched(sim: MatchSim, s: Skillshot, e: SimEntity) -> void:
	var h := s.owner
	var a := s.ability
	var per := a.damage + HeroStats.ability_bonus(h, a)
	add_dot(sim, h, e, per * a.pulses, a.duration, a.pulses, 2, a.id)
	sim.emit_event(&"latched", {"hero": h.id, "target": e.id, "until": sim.time + a.duration})
	if e is HeroState:
		e.latched_until = sim.time + a.duration
		e.latched_by = h.id
	if e is HeroState:
		var honey := h.has_special(&"honey")
		if honey > 0.0:
			slow(sim, e, honey, a.duration)


static func _scatter(sim: MatchSim, h: HeroState, a: AbilityData, move: Vector2, info: Dictionary) -> void:
	var dir := Abilities.aim_dir(h, move, null)
	var dist := a.distance + h.has_special(&"swarm_through")
	var from := h.pos
	var to := Abilities.free_spot(sim, h, from + dir * dist, from)
	h.pos = to
	h.prev_pos = to
	h.phase_until = sim.time + a.duration
	info.from = from
	info.to = to
	sim.emit_event(&"scattered", {"hero": h.id, "team": h.team, "from": from, "to": to})
	var them := sim.heroes[1 - h.team]
	if them.alive and not them.is_untargetable():
		var seg := to - from
		var along := clampf((them.pos - from).dot(seg.normalized()), 0.0, seg.length()) if seg.length() > 0.01 else 0.0
		if (from + seg.normalized() * along).distance_to(them.pos) <= 1.0 + them.radius:
			add_buzz(sim, h, them)
	var regroup := h.has_special(&"regroup")
	if regroup > 0.0:
		sim.heal(h, h.max_hp * regroup)


static func _engulf(sim: MatchSim, h: HeroState, a: AbilityData) -> void:
	var t := Abilities.aim_hero(sim, h, a.reach)
	if t == null:
		return
	var nest := h.has_special(&"nest")
	var dur := a.duration + nest
	h.engulf_target = t.id
	h.engulf_ability = a
	h.engulf_until = sim.time + dur
	h.engulf_left = a.pulses + int(round(nest * a.pulses / a.duration))
	h.engulf_next = sim.time + a.duration / a.pulses
	h.engulf_key = sim.next_cast_key()
	t.engulfed_by = h.id
	slow(sim, t, a.slow, dur)
	var smother := h.perk_with(&"smother")
	if smother != null:
		t.silence_until = sim.time + smother.special_duration
		Abilities.interrupt(sim, t)
	CombatSystem.cancel(sim, h)
	sim.emit_event(&"engulfed", {"hero": h.id, "target": t.id, "until": h.engulf_until})


static func _tick_engulf(sim: MatchSim, h: HeroState) -> void:
	if h.engulf_target == 0:
		return
	var t := sim.get_entity(h.engulf_target) as HeroState
	if t == null or not t.alive or sim.time >= h.engulf_until or h.is_stunned(sim.time):
		end_engulf(sim, h)
		return
	h.pos = t.pos + Vector2(0.0, 0.01)
	h.prev_pos = h.pos
	if sim.time + 0.0001 >= h.engulf_next and h.engulf_left > 0:
		h.engulf_left -= 1
		h.engulf_next += h.engulf_ability.duration / h.engulf_ability.pulses
		_quiet = true
		Abilities.hit(sim, h, t, h.engulf_ability, h.engulf_key)
		_quiet = false
		if h.engulf_left % 2 == 0 and t.alive:
			add_buzz(sim, h, t)


static func end_engulf(sim: MatchSim, h: HeroState) -> void:
	if h.engulf_target == 0:
		return
	var t := sim.get_entity(h.engulf_target) as HeroState
	if t != null and t.engulfed_by == h.id:
		t.engulfed_by = 0
	h.engulf_target = 0
	h.engulf_until = 0.0
	sim.emit_event(&"engulf_ended", {"hero": h.id})


## Buzz from the swarm. At the threshold the swarm overwhelms: damage and a slow.
## Stacks it takes to Overwhelm (Hive Mind lowers it).
static func buzz_need(h: HeroState) -> int:
	return int(h.has_special(&"hive_mind")) if h.has_special(&"hive_mind") > 0.0 else BUZZ_STACKS


static func add_buzz(sim: MatchSim, h: HeroState, t: HeroState) -> void:
	if h.data.hero_trait != &"buzz" or not t.alive or t.team == h.team:
		return
	if t.buzz_from != h.id:
		t.buzz = 0
		t.buzz_from = h.id
	t.buzz += 1
	var need := buzz_need(h)
	sim.emit_event(&"buzz", {"hero": h.id, "target": t.id, "stacks": t.buzz, "need": need})
	if t.buzz < need:
		return
	t.buzz = 0
	sim.emit_event(&"overwhelm", {"hero": h.id, "target": t.id, "pos": t.pos})
	_quiet = true
	sim.apply_damage(t, OVERWHELM_DAMAGE + OVERWHELM_AP * h.ability_power, h, &"ability")
	_quiet = false
	if t.alive:
		slow(sim, t, OVERWHELM_SLOW, OVERWHELM_SLOW_TIME)


# ---------------------------------------------------------------- Poppet

static func _needle_hit(sim: MatchSim, s: Skillshot, e: SimEntity) -> void:
	var h := s.owner
	Abilities.hit(sim, h, e, s.ability, s.key, s.damage if e is HeroState else s.minion_damage)
	if e is HeroState and e.alive:
		thread(sim, h, e as HeroState, s.ability)


static func thread(sim: MatchSim, h: HeroState, e: HeroState, a: AbilityData) -> void:
	h.thread_target = e.id
	h.thread_until = sim.time + a.duration
	h.thread_ability = a
	h.recast_until[0] = sim.time + a.recast_window
	sim.emit_event(&"threaded", {"hero": h.id, "target": e.id, "until": h.thread_until})


static func end_thread(sim: MatchSim, h: HeroState) -> void:
	if h.thread_target == 0:
		return
	h.thread_target = 0
	h.thread_until = 0.0
	h.recast_until[0] = 0.0
	sim.emit_event(&"thread_ended", {"hero": h.id})


static func _reel(sim: MatchSim, h: HeroState) -> void:
	var t := sim.get_entity(h.thread_target) as HeroState
	if t == null or not t.alive:
		end_thread(sim, h)
		return
	var to := t.pos - h.pos
	var dist := maxf(0.0, to.length() - h.radius - t.radius - 0.3)
	end_thread(sim, h)
	if dist > 0.05:
		Abilities.force(sim, h, to.normalized() * dist, maxf(0.08, dist / REEL_SPEED))
	sim.emit_event(&"reeled", {"hero": h.id, "target": t.id})


static func _tick_thread(sim: MatchSim, h: HeroState) -> void:
	if h.thread_target == 0:
		return
	var t := sim.get_entity(h.thread_target) as HeroState
	if t == null or not t.alive or sim.time >= h.thread_until:
		end_thread(sim, h)
		return
	var a := h.thread_ability
	var tight := h.perk_with(&"tight_stitch")
	var snap_at := tight.special_value if tight != null else a.radius
	if h.pos.distance_to(t.pos) <= snap_at:
		return
	end_thread(sim, h)
	sim.emit_event(&"thread_snapped", {"hero": h.id, "target": t.id, "pos": t.pos})
	Abilities.hit(sim, h, t, a, sim.next_cast_key(), a.extra + 0.4 * h.ability_power)
	if tight != null and t.alive:
		root(sim, t, tight.special_value_2)


static func _wind_up(sim: MatchSim, h: HeroState, a: AbilityData, key: int) -> void:
	var stare := h.has_special(&"stare_down")
	sim.emit_event(&"head_spin", {"hero": h.id, "team": h.team, "pos": h.pos, "radius": a.radius})
	var them := sim.heroes[1 - h.team]
	if them.alive and not them.is_untargetable() and not sim.is_hidden(them) and h.pos.distance_to(them.pos) <= a.radius + them.radius:
		var to_me := (h.pos - them.pos).normalized() if h.pos != them.pos else them.facing
		if stare > 0.0 or them.facing.dot(to_me) > 0.2:
			Abilities.hit(sim, h, them, a, key)
			if them.alive:
				Abilities.stun(sim, them, stare if stare > 0.0 else a.stun)
				sim.emit_event(&"terrified", {"hero": h.id, "target": them.id})
	h.frenzy_until = sim.time + a.duration + h.has_special(&"overwound")
	h.frenzy_bonus = a.attack_speed_bonus
	h.frenzy_hits = 0
	h.frenzy_ability = a


static func _ribbons(sim: MatchSim, h: HeroState, a: AbilityData) -> void:
	var t := Abilities.aim_unit(sim, h, a.reach)
	if t == null:
		return
	var to := t.pos - h.pos
	var dist := maxf(0.0, to.length() - h.radius - t.radius - 0.2)
	if dist > 0.05:
		Abilities.force(sim, h, to.normalized() * dist, a.travel_time)
	if t is HeroState:
		root(sim, t, a.root + a.travel_time)
	h.ribbons_target = t.id
	h.ribbons_ability = a
	h.ribbons_left = a.pulses
	h.ribbons_next = sim.time + a.travel_time + a.duration / a.pulses
	h.ribbons_key = sim.next_cast_key()
	h.ribbons_threaded = t.id == h.thread_target and sim.time < h.thread_until
	sim.emit_event(&"ribbons", {"hero": h.id, "target": t.id})


static func _tick_ribbons(sim: MatchSim, h: HeroState) -> void:
	if h.ribbons_target == 0 or sim.time + 0.0001 < h.ribbons_next:
		return
	var t := sim.get_entity(h.ribbons_target)
	var a := h.ribbons_ability
	if t == null or not t.alive or h.is_stunned(sim.time):
		h.ribbons_target = 0
		return
	h.ribbons_left -= 1
	h.ribbons_next += a.duration / a.pulses
	sim.emit_event(&"snip", {"hero": h.id, "target": t.id})
	Abilities.hit(sim, h, t, a, h.ribbons_key)
	var ripper := h.perk_with(&"seam_ripper")
	if ripper != null and t is HeroState:
		t.armor_cut = minf(ripper.special_value_2, (t.armor_cut if sim.time < t.armor_cut_until else 0.0) + ripper.special_value)
		t.armor_cut_until = sim.time + ripper.special_duration
	if h.ribbons_left > 0 and t.alive:
		return
	h.ribbons_target = 0
	if t is HeroState and t.alive:
		if h.ribbons_threaded:
			Abilities.hit(sim, h, t, a, h.ribbons_key, (t.max_hp - t.hp) * a.extra)
		if t.alive and h.has_special(&"stitched_up") > 0.0 and h.data.abilities[0].effect == &"threaded_needle":
			thread(sim, h, t, h.data.abilities[0])


## Basic attacks during Wind-Up: every 3rd snip bleeds.
static func after_basic(sim: MatchSim, h: HeroState, t: SimEntity) -> void:
	if sim.time < h.frenzy_until and h.frenzy_ability != null and t.team != h.team:
		h.frenzy_hits += 1
		if h.frenzy_hits % 3 == 0:
			var a := h.frenzy_ability
			add_dot(sim, h, t, a.extra + 0.5 * h.attack_damage, a.bleed_time, 4)


# ---------------------------------------------------------------- Tot

static func _sweep(sim: MatchSim, h: HeroState, a: AbilityData, move: Vector2, key: int, info: Dictionary) -> void:
	if a.hp_cost > 0.0:
		add_debt(sim, h, h.max_hp * a.hp_cost)
	var dir := Abilities.aim_dir(h, move, Abilities.aim_unit(sim, h, a.radius + 1.0))
	h.facing = dir
	info.dir = dir
	info.radius = a.radius
	for e in Abilities.enemies_near(sim, h, h.pos, a.radius):
		var to := e.pos - h.pos
		if to.length() > 1.0 and to.normalized().dot(dir) < 0.34:
			continue
		Abilities.hit(sim, h, e, a, key)


static func _absolute_rule(sim: MatchSim, h: HeroState, a: AbilityData, move: Vector2) -> void:
	var them := Abilities.aim_hero(sim, h, a.distance + 1.5)
	var dir := Abilities.aim_dir(h, move, them)
	var dist := a.distance
	if them != null and h.aim == Vector2.ZERO:
		dist = clampf(h.pos.distance_to(them.pos) - h.radius - them.radius - 0.2, 0.0, a.distance)
	var goal := h.pos + dir * dist
	h.rule_ability = a
	h.rule_until = sim.time + a.travel_time + a.duration
	h.rule_end = h.rule_until + RULE_GRACE
	h.rule_bonus = h.has_special(&"zealot") if h.has_special(&"zealot") > 0.0 else a.extra
	if dist > 0.05:
		Abilities.force(sim, h, goal - h.pos, a.travel_time)
		_displaced_by(h, h, &"rule", goal)
	else:
		_rule_landed(sim, h)
	sim.emit_event(&"rule_started", {"hero": h.id, "team": h.team, "until": h.rule_until})


static func _rule_landed(sim: MatchSim, h: HeroState) -> void:
	var a := h.rule_ability
	if a == null:
		return
	sim.emit_event(&"rule_landed", {"hero": h.id, "team": h.team, "pos": h.pos, "radius": a.radius})
	var key := sim.next_cast_key()
	for e in Abilities.enemies_near(sim, h, h.pos, a.radius):
		Abilities.hit(sim, h, e, a, key)


static func rule_active(sim: MatchSim, h: HeroState) -> bool:
	return h.rule_ability != null and sim.time < h.rule_end


static func add_debt(sim: MatchSim, h: HeroState, amount: float) -> void:
	if amount <= 0.0:
		return
	h.debt += amount
	sim.emit_event(&"debt_changed", {"hero": h.id, "debt": h.debt})


## How much of an incoming hit is postponed into Debt.
static func defer_share(sim: MatchSim, h: HeroState) -> float:
	if sim.time < h.borrowed_until or (h.rule_ability != null and sim.time < h.rule_until):
		return 1.0
	return DEBT_SHARE if h.data.hero_trait == &"blood_debt" else 0.0


static func _tick_debt(sim: MatchSim, h: HeroState) -> void:
	if h.rule_ability != null and sim.time >= h.rule_end:
		# The rule failed: the whole Debt lands at once.
		h.rule_ability = null
		sim.emit_event(&"rule_failed", {"hero": h.id, "debt": h.debt})
		_pay(sim, h, h.debt)
		return
	if h.debt <= 0.0 or rule_active(sim, h):
		return
	var drain := DEBT_DRAIN * (1.0 - h.has_special(&"iron_faith")) * (1.0 - h.passive_special(&"debt_slow"))
	_pay(sim, h, minf(h.debt, drain * sim.dt))


## Debt turns into real damage. If it knocks him out, the enemy hero gets the credit.
static func _pay(sim: MatchSim, h: HeroState, amount: float) -> void:
	if amount <= 0.0:
		return
	h.debt = maxf(0.0, h.debt - amount)
	h.hp -= amount
	if h.hp <= 0.0:
		h.hp = 0.0
		sim.kill(h, sim.heroes[1 - h.team])


static func cancel_debt(sim: MatchSim, h: HeroState, amount: float) -> void:
	if h.debt <= 0.0 or amount <= 0.0:
		return
	if sim.time < h.wounds_until:
		amount *= 1.0 - h.wounds_amount  # Thorncut cuts this "healing" too.
	h.debt = maxf(0.0, h.debt - amount)
	sim.emit_event(&"debt_changed", {"hero": h.id, "debt": h.debt})


static func _forgive(sim: MatchSim, h: HeroState) -> void:
	var divine := h.has_special(&"divine_right")
	h.debt = 0.0
	h.rule_ability = null
	sim.heal(h, h.max_hp * (divine if divine > 0.0 else 0.2))
	if divine > 0.0 and h.data.abilities.size() > 1:
		h.cooldowns[1] = 0.0
	sim.emit_event(&"rule_forgiven", {"hero": h.id})
	sim.emit_event(&"debt_changed", {"hero": h.id, "debt": 0.0})


# ---------------------------------------------------------------- damage hooks

## Before a hit reaches a hero's HP: untouchable phases, the swarm riding its victim,
## then Debt. Shields have already soaked their share.
static func incoming(sim: MatchSim, source: SimEntity, target: HeroState, amount: float) -> float:
	if amount <= 0.0:
		return amount
	if sim.time < target.phase_until:
		return 0.0
	if target.engulf_target != 0 and source != null and source.id == target.engulf_target:
		return 0.0
	var share := defer_share(sim, target)
	if share > 0.0:
		add_debt(sim, target, amount * share)
		amount *= 1.0 - share
	return amount


## After damage lands: Debt cancelled by hitting the enemy hero, and Buzz.
static func after_damage(sim: MatchSim, src: HeroState, target: SimEntity, dealt: float, kind: StringName) -> void:
	if not (target is HeroState) or target.team == src.team or dealt <= 0.0:
		return
	if kind == &"basic":
		OccultKits.on_basic_hit(sim, src, target as HeroState)
	if kind == &"basic" or kind == &"ability":
		if src.debt > 0.0:
			var share := 1.0 if kind == &"ability" or (sim.time < src.borrowed_until and src.has_special(&"ruthless") > 0.0) else 0.5
			cancel_debt(sim, src, dealt * share)
		if not _quiet:
			add_buzz(sim, src, target as HeroState)


## Extra basic-attack damage: Hunter's Mark and Absolute Rule. -1 = a miss.
static func basic_damage(sim: MatchSim, h: HeroState, t: SimEntity, damage: float) -> float:
	if h.engulfed_by != 0:
		h.miss_flip = not h.miss_flip
		if h.miss_flip:
			return -1.0  # Half the attacks of a hero inside the swarm miss.
	if t is HeroState:
		var victim := t as HeroState
		if victim.hunt_mark_by == h.id and victim.hunt_mark_left > 0 and sim.time < victim.hunt_mark_until:
			victim.hunt_mark_left -= 1
			damage *= 1.0 + h.has_special(&"hunters_mark")
	if h.rule_ability != null and sim.time < h.rule_until and t.team != h.team:
		damage += h.debt * h.rule_bonus
	return damage


static func on_kill(sim: MatchSim, target: SimEntity, source: SimEntity) -> void:
	if target is HeroState:
		var winner := sim.heroes[1 - target.team]
		if rule_active(sim, winner):
			_forgive(sim, winner)
		elif winner.debt > 0.0:
			winner.debt = 0.0  # A takedown wipes the Debt.
			sim.emit_event(&"debt_changed", {"hero": winner.id, "debt": 0.0})
	elif target is MinionState and source is HeroState:
		var tithe := (source as HeroState).has_special(&"tithe")
		if tithe > 0.0:
			cancel_debt(sim, source, tithe)


# ---------------------------------------------------------------- statuses

static func root(sim: MatchSim, e: HeroState, seconds: float) -> void:
	if seconds <= 0.0:
		return
	e.root_until = maxf(e.root_until, sim.time + seconds)
	sim.emit_event(&"rooted", {"hero": e.id, "until": e.root_until})


static func slow(sim: MatchSim, e: HeroState, amount: float, seconds: float) -> void:
	if amount <= 0.0 or seconds <= 0.0:
		return
	if sim.time >= e.slow_until or amount >= e.slow_amount:
		e.slow_amount = amount
	e.slow_until = maxf(e.slow_until, sim.time + seconds)


## Damage over time: `total` spread over `ticks` hits across `seconds`. buzz_every > 0 adds
## a Buzz every that many ticks (Latch Cloud).
static func add_dot(sim: MatchSim, src: HeroState, target: SimEntity, total: float, seconds: float, ticks: int, buzz_every := 0, ability_id := &"bleed") -> void:
	if total <= 0.0 or ticks <= 0:
		return
	sim.dots.append({"src": src.id, "target": target.id, "per": total / ticks, "every": seconds / ticks,
			"next": sim.time + seconds / ticks, "left": ticks, "buzz_every": buzz_every, "count": 0, "ability": ability_id})
	sim.emit_event(&"dot_started", {"hero": src.id, "target": target.id, "until": sim.time + seconds, "ability": ability_id})


static func _tick_dots(sim: MatchSim) -> void:
	for i in range(sim.dots.size() - 1, -1, -1):
		var d: Dictionary = sim.dots[i]
		var t := sim.get_entity(d.target)
		var src := sim.get_entity(d.src) as HeroState
		if t == null or not t.alive or src == null:
			sim.dots.remove_at(i)
			continue
		if sim.time + 0.0001 < d.next:
			continue
		d.next += d.every
		d.left -= 1
		d.count += 1
		_quiet = true
		var dealt := sim.apply_damage(t, d.per, src, &"ability")
		_quiet = false
		sim.emit_event(&"dot_tick", {"hero": src.id, "target": t.id, "amount": dealt, "ability": d.ability})
		if d.buzz_every > 0 and d.count % d.buzz_every == 0 and t is HeroState and t.alive:
			add_buzz(sim, src, t as HeroState)
		if d.left <= 0:
			sim.dots.remove_at(i)


# ---------------------------------------------------------------- skillshots

## Skillshot hits for the round-2 kits. Returns false if the effect isn't one of them.
static func skillshot_hit(sim: MatchSim, s: Skillshot, e: SimEntity) -> bool:
	match s.ability.effect:
		&"harpoon":
			_hooked(sim, s, e)
		&"recoil_bolt":
			_bolt_hit(sim, s, e)
		&"headsmans_axe":
			_axe_hit(sim, s, e)
		&"latch_cloud":
			_latched(sim, s, e)
		&"threaded_needle":
			_needle_hit(sim, s, e)
		&"fang_dart":
			OccultKits.fang_hit(sim, s, e)
		_:
			return false
	return true


## Busy with a kit action that stops basic attacks.
static func is_busy(h: HeroState) -> bool:
	return h.engulf_target != 0 or h.ribbons_target != 0 or h.delayed != null


static func clear(h: HeroState) -> void:
	h.root_until = 0.0
	h.phase_until = 0.0
	h.silence_until = 0.0
	h.delayed = null
	h.thread_target = 0
	h.thread_until = 0.0
	h.frenzy_until = 0.0
	h.ribbons_target = 0
	h.engulf_target = 0
	h.engulf_until = 0.0
	h.engulfed_by = 0
	h.buzz = 0
	h.debt = 0.0
	h.borrowed_until = 0.0
	h.rule_ability = null
	h.hunt_mark_left = 0
	h.armor_cut = 0.0
	h.armor_cut_until = 0.0
	h.forced_by = 0
	h.forced_how = &""
	OccultKits.clear(h)
