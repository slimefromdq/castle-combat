class_name OccultKits
## The occult heroes: Serpent, Fermata and KOSMONAUT. Kits (src/sim/kits.gd) calls in
## here for their abilities, ticks and hits.
##
##   Serpent: Venom stacks on the enemy hero and pops 2.5 s after the last one, harder the
##   more HP the target is missing (capped), but only while he is within 9 m. Fang Dart
##   adds two stacks, Shed Skin slips 4 m and sheds slows and roots, Snake Pit hatches
##   vipers that chase the enemy hero and bite in more venom.
##
##   Fermata: Ensemble, up to two instruments at once; each plays a final note (a small
##   burst) when it fades. Brass Section blasts a cone and knocks back, Strings plays in a
##   circle that chips and slows, Grand Finale sends out waves that push enemies away.
##
##   KOSMONAUT: Drone, it hovers at his shoulder or where he parked it, never wandering
##   on its own, and zaps the nearest enemy within 3 m every second. Launch Drone throws
##   it to a spot (hitting what it flies through; tap again to call it home), Pulse
##   bursts around it, Re-entry drops it on the spot below it after a telegraph.

# ---------------------------------------------------------------- Serpent

## Venom: stacks pop this long after the last one lands.
const VENOM_TIME := 2.5
## The pop needs Serpent this close to the target.
const VENOM_RANGE := 9.0
const VENOM_MAX := 8
## Damage per stack (plus a share of AP), raised by the target's missing HP share, and
## capped at a share of the target's max HP.
const VENOM_PER_STACK := 14.0
const VENOM_AP := 0.12
const VENOM_CAP := 0.3

# ---------------------------------------------------------------- Fermata

## Ensemble: instruments playing at once, and each one's final note.
const ENSEMBLE_MAX := 2
const NOTE_RADIUS := 2.0
const NOTE_DAMAGE := 30.0
const NOTE_AP := 0.2
## Brass Section: the cone's half-angle (degrees) and how far in front the tuba floats.
const BRASS_HALF_ANGLE := 35.0

# ---------------------------------------------------------------- KOSMONAUT

## Drone: flight speed (m/s), zap reach and rhythm, zap damage, and where it hovers when
## home (beside him and a little behind, the same way round all match: it never spins).
const DRONE_SPEED := 16.0
const ZAP_RANGE := 3.0
const ZAP_EVERY := 1.0
const ZAP_DAMAGE := 22.0
const ZAP_MINION_DAMAGE := 16.0
const ZAP_AP := 0.15
const HOME_SIDE := 0.9
const HOME_BACK := 0.4
## A parked drone flies home by itself when KOSMONAUT walks this far from it.
const LEASH := 12.0
## The drone's own size, for hitting what it flies through.
const DRONE_RADIUS := 0.6

## Stand-ins for hits that come from a trait, not an ability (for events and numbers).
static var _venom_ability: AbilityData
static var _zap_ability: AbilityData
static var _viper_body: SimEntity


static func _trait_ability(id: StringName) -> AbilityData:
	var a := AbilityData.new()
	a.id = id
	a.display_name = String(id).capitalize()
	return a


# ---------------------------------------------------------------- casting

static func cast_problem(_sim: MatchSim, h: HeroState, a: AbilityData) -> String:
	if a.effect == &"pulse" and h.reentry != null:
		return "drone falling"
	return ""


## Casts one of the occult abilities. Returns false if the cooldown should not start.
static func cast(sim: MatchSim, h: HeroState, slot: int, a: AbilityData, move: Vector2, recast: bool, key: int, info: Dictionary) -> bool:
	match a.effect:
		&"fang_dart":
			var t := Abilities.aim_unit(sim, h, a.reach * 1.1)
			Abilities.launch(sim, h, a, Abilities.aim_dir(h, move, t), a.damage, a.minion_damage, key)
		&"shed_skin":
			_shed(sim, h, a, move, info)
		&"snake_pit":
			_snake_pit(sim, h, a, move, key, info)
		&"brass_section":
			_brass(sim, h, a, move, key, info)
		&"strings":
			_strings(sim, h, a, move, key, info)
		&"grand_finale":
			h.finale = a
			h.finale_left = a.pulses + int(h.has_special(&"da_capo"))
			h.finale_next = sim.time
			h.finale_key = key
		&"launch_drone":
			if recast:
				recall(sim, h)
				return false
			_launch_drone(sim, h, a, move, slot, key, info)
		&"pulse":
			_pulse(sim, h, a, key)
		&"re_entry":
			_re_entry(sim, h, a, move, key, info)
	return true


## A point to drop something on: the enemy hero (else the nearest trooper) if it is in
## reach and you aimed at it (or didn't aim), else `share` of the reach where you aimed.
## Pulled back out of walls.
static func _ground_spot(sim: MatchSim, h: HeroState, reach: float, move: Vector2, share := 0.8) -> Vector2:
	var them := Abilities.aim_unit(sim, h, reach + 0.5)
	var dir := Abilities.aim_dir(h, move, them)
	var spot := h.pos + dir * reach * share
	if them != null and (h.aim == Vector2.ZERO or h.aim.dot((them.pos - h.pos).normalized()) > 0.8):
		spot = them.pos
	return _in_sight(sim, h.pos, spot)


## Walks `to` back toward `from` until there is a clear line between them.
static func _in_sight(sim: MatchSim, from: Vector2, to: Vector2) -> Vector2:
	for i in 20:
		if ArenaGeometry.has_line_of_sight(sim.arena, from, to):
			return to
		to = from.lerp(to, 0.85)
	return from


# ---------------------------------------------------------------- per tick

static func tick(sim: MatchSim) -> void:
	for h in sim.heroes:
		_tick_venom(sim, h)
		if not h.alive:
			continue
		_tick_finale(sim, h)
		_tick_drone(sim, h)
		_tick_reentry(sim, h)
	_tick_vipers(sim)
	_tick_instruments(sim)


# ---------------------------------------------------------------- Serpent

## A basic attack landed on the enemy hero.
static func on_basic_hit(sim: MatchSim, src: HeroState, target: HeroState) -> void:
	if src.data.hero_trait == &"venom":
		add_venom(sim, src, target, 1)


static func add_venom(sim: MatchSim, src: HeroState, t: HeroState, stacks: int) -> void:
	if not t.alive or t.team == src.team or stacks <= 0:
		return
	if t.venom_from != src.id:
		t.venom = 0
		t.venom_from = src.id
	t.venom = mini(VENOM_MAX, t.venom + stacks)
	t.venom_pops_at = sim.time + VENOM_TIME
	sim.emit_event(&"venom", {"hero": src.id, "target": t.id, "stacks": t.venom, "pops_at": t.venom_pops_at})


## What a pop of these stacks would deal right now.
static func venom_damage(src: HeroState, t: HeroState, stacks: int) -> float:
	var per := VENOM_PER_STACK + VENOM_AP * src.ability_power
	var missing := 1.0 - t.hp / maxf(1.0, t.max_hp)
	var dmg := stacks * per * (1.0 + missing) * (1.0 + src.has_special(&"thick_venom"))
	return minf(dmg, t.max_hp * VENOM_CAP)


static func _tick_venom(sim: MatchSim, t: HeroState) -> void:
	if t.venom <= 0 or sim.time + 0.0001 < t.venom_pops_at:
		return
	var stacks := t.venom
	t.venom = 0
	var src := sim.get_entity(t.venom_from) as HeroState
	if not t.alive:
		return
	if src == null or not src.alive or src.pos.distance_to(t.pos) > VENOM_RANGE:
		sim.emit_event(&"venom_fizzled", {"target": t.id, "pos": t.pos})
		return
	var dmg := venom_damage(src, t, stacks)
	if _venom_ability == null:
		_venom_ability = _trait_ability(&"venom")
	sim.emit_event(&"venom_pop", {"hero": src.id, "target": t.id, "pos": t.pos, "stacks": stacks, "damage": dmg})
	sim.emit_event(&"ability_hit", {"hero": src.id, "target": t.id, "damage": dmg, "ability": &"venom"})
	var dealt := sim.apply_damage(t, dmg, src, &"ability")
	var cold := src.has_special(&"cold_blood")
	if cold > 0.0:
		sim.heal(src, dealt * cold)
	var neuro := src.passive_special(&"neurotoxin")
	if neuro > 0.0 and t.alive:
		Kits.slow(sim, t, neuro, src.passive_with(&"neurotoxin").special_value_2)
	# The pop halves whatever is left of Shed Skin's cooldown.
	for i in src.data.abilities.size():
		if src.data.abilities[i].effect == &"shed_skin":
			src.cooldowns[i] *= 0.5


static func fang_hit(sim: MatchSim, s: Skillshot, e: SimEntity) -> void:
	var h := s.owner
	Abilities.hit(sim, h, e, s.ability, s.key, s.damage if e is HeroState else s.minion_damage)
	if e is HeroState and e.alive:
		add_venom(sim, h, e as HeroState, maxi(1, int(s.ability.extra)))


static func _shed(sim: MatchSim, h: HeroState, a: AbilityData, move: Vector2, info: Dictionary) -> void:
	var dir := Abilities.aim_dir(h, move, null)
	var dist := a.distance + h.has_special(&"slither")
	var from := h.pos
	# Slipping out of his skin leaves slows and roots behind with it.
	h.slow_until = 0.0
	h.root_until = 0.0
	Abilities.force(sim, h, dir * dist, a.travel_time)
	info.from = from
	info.dir = dir
	sim.emit_event(&"skin_shed", {"hero": h.id, "team": h.team, "pos": from, "dir": dir})


static func _snake_pit(sim: MatchSim, h: HeroState, a: AbilityData, move: Vector2, key: int, info: Dictionary) -> void:
	var spot := _ground_spot(sim, h, a.reach, move)
	var count := a.pulses + int(h.has_special(&"brood"))
	var hatch := sim.time + a.delay
	var until := hatch + a.duration + h.has_special(&"long_fangs")
	info.point = spot
	sim.emit_event(&"snake_pit", {"hero": h.id, "team": h.team, "pos": spot, "hatch_at": hatch, "until": until})
	for k in count:
		var ang := TAU * k / count
		var v := {"id": sim.new_id(), "owner": h.id, "team": h.team, "pos": spot + Vector2(cos(ang), sin(ang)) * 0.6,
				"hatch_at": hatch, "until": until, "next_bite": hatch + 0.15 * k, "ability": a, "key": key}
		sim.vipers.append(v)


static func _tick_vipers(sim: MatchSim) -> void:
	if _viper_body == null:
		_viper_body = SimEntity.new()
		_viper_body.radius = 0.2
	for i in range(sim.vipers.size() - 1, -1, -1):
		var v: Dictionary = sim.vipers[i]
		var owner := sim.get_entity(v.owner) as HeroState
		if owner == null or not owner.alive or sim.time >= v.until:
			sim.vipers.remove_at(i)
			sim.emit_event(&"viper_gone", {"id": v.id, "pos": v.pos})
			continue
		if sim.time < v.hatch_at:
			continue
		var a: AbilityData = v.ability
		var them := sim.heroes[1 - int(v.team)]
		if not them.alive or them.is_untargetable() or sim.is_hidden(them) or them.pos.distance_to(v.pos) > a.radius:
			continue
		var to: Vector2 = them.pos - v.pos
		var reach := them.radius + 0.35
		if to.length() > reach:
			v.pos = Movement.slide(sim, _viper_body, v.pos, to.normalized() * minf(a.speed * sim.dt, to.length() - reach))
		elif sim.time >= v.next_bite:
			v.next_bite = sim.time + a.extra
			sim.emit_event(&"viper_bite", {"id": v.id, "hero": owner.id, "target": them.id, "pos": v.pos})
			Abilities.hit(sim, owner, them, a, v.key)
			if them.alive:
				add_venom(sim, owner, them, 1)


# ---------------------------------------------------------------- Fermata

static func _summon(sim: MatchSim, h: HeroState, kind: StringName, pos: Vector2, dir: Vector2, a: AbilityData, lasts: float, key: int) -> Dictionary:
	var mine: Array = sim.instruments.filter(func(x: Dictionary) -> bool: return x.owner == h.id)
	while mine.size() >= ENSEMBLE_MAX:
		var oldest: Dictionary = mine.pop_front()
		sim.instruments.erase(oldest)
		_final_note(sim, h, oldest)
	var inst := {"id": sim.new_id(), "owner": h.id, "team": h.team, "kind": kind, "pos": pos, "dir": dir,
			"born": sim.time, "until": sim.time + lasts + h.passive_special(&"ovation"), "ability": a, "key": key,
			"every": 0.0, "next": 0.0}
	sim.instruments.append(inst)
	sim.emit_event(&"instrument", {"id": inst.id, "hero": h.id, "team": h.team, "kind": kind, "pos": pos, "until": inst.until})
	return inst


static func _final_note(sim: MatchSim, h: HeroState, inst: Dictionary) -> void:
	sim.emit_event(&"final_note", {"id": inst.id, "hero": h.id, "team": h.team, "pos": inst.pos, "radius": NOTE_RADIUS})
	if not h.alive:
		return
	var dmg := (NOTE_DAMAGE + NOTE_AP * h.ability_power) * (1.0 + h.has_special(&"crescendo"))
	var key := sim.next_cast_key()
	for e in Abilities.enemies_near(sim, h, inst.pos, NOTE_RADIUS):
		Abilities.hit(sim, h, e, inst.ability, key, dmg)


static func _brass(sim: MatchSim, h: HeroState, a: AbilityData, move: Vector2, key: int, info: Dictionary) -> void:
	var dir := Abilities.aim_dir(h, move, Abilities.aim_unit(sim, h, a.reach))
	h.facing = dir
	info.dir = dir
	info.length = a.reach
	_summon(sim, h, &"brass", h.pos + dir * 1.0, dir, a, a.duration, key)
	sim.emit_event(&"brass_blast", {"hero": h.id, "team": h.team, "pos": h.pos, "dir": dir, "length": a.reach, "angle": BRASS_HALF_ANGLE})
	var push := a.distance + h.has_special(&"fortissimo")
	var min_dot := cos(deg_to_rad(BRASS_HALF_ANGLE))
	for e in Abilities.enemies_near(sim, h, h.pos, a.reach):
		var to := e.pos - h.pos
		if to.length() > 1.0 and to.normalized().dot(dir) < min_dot:
			continue
		Abilities.hit(sim, h, e, a, key)
		if not e.alive:
			continue
		var away := to.normalized() if to.length() > 0.01 else dir
		if e is HeroState:
			Abilities.force(sim, e, away * push, a.travel_time, false)
			Abilities.interrupt(sim, e)
		else:
			e.pos = Abilities.free_spot(sim, e, e.pos + away * push, e.pos)


static func _strings(sim: MatchSim, h: HeroState, a: AbilityData, move: Vector2, key: int, info: Dictionary) -> void:
	var spot := _ground_spot(sim, h, a.reach, move)
	info.point = spot
	var inst := _summon(sim, h, &"strings", spot, h.facing, a, a.duration + h.has_special(&"sostenuto"), key)
	inst.every = a.duration / maxf(1.0, a.pulses)
	inst.next = sim.time + inst.every


static func _tick_instruments(sim: MatchSim) -> void:
	for i in range(sim.instruments.size() - 1, -1, -1):
		if i >= sim.instruments.size():
			continue
		var inst: Dictionary = sim.instruments[i]
		var h := sim.get_entity(inst.owner) as HeroState
		if h == null or not h.alive:
			sim.instruments.remove_at(i)
			sim.emit_event(&"instrument_gone", {"id": inst.id})
			continue
		if inst.kind == &"strings" and sim.time + 0.0001 >= inst.next and inst.next <= inst.until + 0.0001:
			inst.next += inst.every
			var a: AbilityData = inst.ability
			var slow := h.has_special(&"pizzicato") if h.has_special(&"pizzicato") > 0.0 else a.slow
			sim.emit_event(&"strings_pulse", {"id": inst.id, "pos": inst.pos, "radius": a.radius})
			for e in Abilities.enemies_near(sim, h, inst.pos, a.radius):
				Abilities.hit(sim, h, e, a, inst.key)
				if e is HeroState and e.alive:
					Kits.slow(sim, e, slow, inst.every + 0.15)
		if sim.time + 0.0001 >= inst.until:
			sim.instruments.remove_at(i)
			_final_note(sim, h, inst)


static func _tick_finale(sim: MatchSim, h: HeroState) -> void:
	if h.finale == null or h.finale_left <= 0 or sim.time + 0.0001 < h.finale_next:
		return
	var a := h.finale
	h.finale_left -= 1
	h.finale_next += a.duration / maxf(1.0, a.pulses)
	if h.finale_left <= 0:
		h.finale = null
	sim.emit_event(&"finale_wave", {"hero": h.id, "team": h.team, "pos": h.pos, "radius": a.radius})
	for e in Abilities.enemies_near(sim, h, h.pos, a.radius):
		Abilities.hit(sim, h, e, a, h.finale_key)
		if not e.alive:
			continue
		var to := e.pos - h.pos
		var away := to.normalized() if to.length() > 0.01 else h.facing
		if e is HeroState:
			Abilities.force(sim, e, away * a.distance, 0.2, false)
			Abilities.interrupt(sim, e)
		else:
			e.pos = Abilities.free_spot(sim, e, e.pos + away * a.distance, e.pos)


# ---------------------------------------------------------------- KOSMONAUT

static func zap_range(h: HeroState) -> float:
	var wide := h.passive_with(&"escape_velocity")
	return wide.special_value_2 if wide != null else ZAP_RANGE


static func drone_speed(h: HeroState) -> float:
	return DRONE_SPEED * (1.0 + h.passive_special(&"escape_velocity"))


static func has_drone(h: HeroState) -> bool:
	return h.data.hero_trait == &"drone" and h.alive


## Where the drone hovers when it is home: at his side, a little behind, always the same
## way round for his team.
static func drone_home(h: HeroState) -> Vector2:
	var fwd := MatchSim.forward(h.team)
	return h.pos + Vector2(fwd.y, -fwd.x) * HOME_SIDE - fwd * HOME_BACK


static func _launch_drone(sim: MatchSim, h: HeroState, a: AbilityData, move: Vector2, slot: int, key: int, info: Dictionary) -> void:
	var reach := a.reach + h.has_special(&"long_tether")
	var spot := _ground_spot(sim, h, reach, move, 1.0)
	if not h.drone_back:
		h.drone_pos = drone_home(h)  # It leaves from his side.
	h.drone_out = true
	h.drone_back = false
	h.drone_spot = spot
	h.drone_ability = a
	h.drone_key = key
	h.drone_hits.clear()
	h.recast_until[slot] = sim.time + 100000.0
	info.point = spot
	sim.emit_event(&"drone_launched", {"hero": h.id, "team": h.team, "from": h.drone_pos, "pos": spot})


## Call the drone home: it flies back, hitting what it passes again.
static func recall(sim: MatchSim, h: HeroState) -> void:
	if not h.drone_out:
		return
	h.drone_out = false
	h.drone_back = true
	h.drone_hits.clear()
	h.drone_key = sim.next_cast_key()
	for i in h.data.abilities.size():
		if h.data.abilities[i].effect == &"launch_drone":
			h.recast_until[i] = 0.0
	sim.emit_event(&"drone_recalled", {"hero": h.id, "team": h.team, "pos": h.drone_pos})


static func _tick_drone(sim: MatchSim, h: HeroState) -> void:
	if h.data.hero_trait != &"drone":
		return
	h.drone_prev = h.drone_pos
	if h.reentry != null:
		return  # Falling: it stays over the drop spot.
	if h.drone_out and h.pos.distance_to(h.drone_spot) > LEASH:
		recall(sim, h)
	var goal := h.drone_spot if h.drone_out else drone_home(h)
	var flying := h.drone_out or h.drone_back
	if not flying:
		h.drone_pos = goal  # Home: it simply keeps up with him.
	else:
		var to := goal - h.drone_pos
		var step := drone_speed(h) * sim.dt
		if to.length() <= step:
			h.drone_pos = goal
			if h.drone_back:
				h.drone_back = false
		else:
			h.drone_pos += to.normalized() * step
			_drone_flight_hits(sim, h)
			return  # No zaps in flight.
	_zap(sim, h)


## The drone hits each enemy it flies through once per trip.
static func _drone_flight_hits(sim: MatchSim, h: HeroState) -> void:
	var a := h.drone_ability
	if a == null:
		return
	for e in Abilities.enemies_near(sim, h, h.drone_pos, DRONE_RADIUS):
		if h.drone_hits.has(e.id):
			continue
		h.drone_hits[e.id] = true
		Abilities.hit(sim, h, e, a, h.drone_key)


## Every second the hovering drone zaps the nearest enemy in reach (the hero first).
static func _zap(sim: MatchSim, h: HeroState) -> void:
	if sim.time + 0.0001 < h.zap_next:
		return
	var reach := zap_range(h)
	var target: SimEntity = null
	var them := sim.heroes[1 - h.team]
	if them.alive and not them.is_untargetable() and not sim.is_hidden(them) and them.pos.distance_to(h.drone_pos) <= reach + them.radius:
		target = them
	else:
		for m in sim.minions:
			if m.alive and m.team != h.team and m.pos.distance_to(h.drone_pos) <= reach + m.radius:
				if target == null or m.pos.distance_squared_to(h.drone_pos) < target.pos.distance_squared_to(h.drone_pos):
					target = m
	if target == null:
		return
	h.zap_next = sim.time + ZAP_EVERY
	if _zap_ability == null:
		_zap_ability = _trait_ability(&"zap")
	var base := ZAP_DAMAGE if target is HeroState else ZAP_MINION_DAMAGE
	var dmg := (base + ZAP_AP * h.ability_power) * (1.0 + h.has_special(&"heavy_payload"))
	sim.emit_event(&"drone_zap", {"hero": h.id, "team": h.team, "from": h.drone_pos, "target": target.id})
	Abilities.hit(sim, h, target, _zap_ability, sim.next_cast_key(), dmg)


static func _pulse(sim: MatchSim, h: HeroState, a: AbilityData, key: int) -> void:
	var at := h.drone_pos if has_drone(h) else h.pos
	sim.emit_event(&"drone_pulse", {"hero": h.id, "team": h.team, "pos": at, "radius": a.radius})
	var cold := h.perk_with(&"cold_pulse")
	for e in Abilities.enemies_near(sim, h, at, a.radius):
		Abilities.hit(sim, h, e, a, key)
		if e is HeroState and e.alive:
			if cold != null:
				Kits.slow(sim, e, cold.special_value, cold.special_value_2)
			else:
				Kits.slow(sim, e, a.slow, a.slow_time)


static func _re_entry(sim: MatchSim, h: HeroState, a: AbilityData, move: Vector2, key: int, info: Dictionary) -> void:
	# KOSMONAUT drops his drone where it is; anyone else (Jack's Encore) calls one down
	# on the enemy hero or ahead of them.
	var spot := h.drone_pos if has_drone(h) else _ground_spot(sim, h, 7.0, move)
	var quick := h.has_special(&"quick_descent")
	h.reentry = a
	h.reentry_at = sim.time + (quick if quick > 0.0 else a.delay)
	h.reentry_pos = spot
	h.reentry_key = key
	info.point = spot
	sim.emit_event(&"reentry_started", {"hero": h.id, "team": h.team, "pos": spot, "at": h.reentry_at, "radius": reentry_radius(h, a)})


static func reentry_radius(h: HeroState, a: AbilityData) -> float:
	return a.radius + h.has_special(&"shockwave")


static func _tick_reentry(sim: MatchSim, h: HeroState) -> void:
	if h.reentry == null or sim.time + 0.0001 < h.reentry_at:
		return
	var a := h.reentry
	h.reentry = null
	var r := reentry_radius(h, a)
	sim.emit_event(&"reentry_landed", {"hero": h.id, "team": h.team, "pos": h.reentry_pos, "radius": r})
	for e in Abilities.enemies_near(sim, h, h.reentry_pos, r):
		Abilities.hit(sim, h, e, a, h.reentry_key)
		if e is HeroState and e.alive:
			Abilities.stun(sim, e, a.stun)
	if has_drone(h) and not h.drone_out:
		h.drone_back = true  # It was only borrowed: back to his side.


# ---------------------------------------------------------------- upkeep

## Busy with an occult kit action that stops basic attacks (none so far).
static func is_busy(_h: HeroState) -> bool:
	return false


static func clear(h: HeroState) -> void:
	h.venom = 0
	h.venom_from = 0
	h.finale = null
	h.finale_left = 0
	h.reentry = null
	h.drone_out = false
	h.drone_back = false
	h.drone_hits.clear()
	h.drone_pos = drone_home(h)
	h.drone_prev = h.drone_pos
