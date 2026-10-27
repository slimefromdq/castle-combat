class_name RelayController
extends RefCounted
## The Relay objective (GDD 7) as an explicit state machine:
##   DORMANT -> SPAWNED -> CARRIED <-> DROPPED -> (delivered or expired) -> DORMANT
## Delivered and expired are moments, not states: they emit an event and go dormant.
## Either hero may pick it up; both deliver to the same pocket, opposite the pickup.
## In phase 2 each hero may instead carry it to their long drop deep in the enemy half
## for a bigger reward (Lucy's long Relay; see long_rect and MatchConfig "Phase 2").

enum State { DORMANT, SPAWNED, CARRIED, DROPPED }

var state := State.DORMANT
var pos := Vector2.ZERO
var prev_pos := Vector2.ZERO
## Where this activation's Relay appears and where it returns after a drop.
var origin := Vector2.ZERO
## Indices into ArenaData.pockets.
var pickup_pocket := 0
var delivery_pocket := 1
## Activations so far (the next pickup pocket alternates from relay_first_pocket).
var activations := 0
var next_spawn_time := 0.0
var warned := false
## SPAWNED: when an untouched Relay disappears.
var expire_at := 0.0
## CARRIED: the carrying hero's id.
var carrier_id := 0
## DROPPED: nobody may pick it up before this; it goes home at return_at.
var lock_until := 0.0
var return_at := 0.0
## Seconds each team's hero has spent picking it up / delivering it.
var pickup_progress: Array[float] = [0.0, 0.0]
var deliver_progress := 0.0
## True on ticks where an enemy hero in the delivery pocket is blocking delivery.
var contested := false
## Fought over too long (Lucy): knock-offs this activation, and when the first one
## happened. The Relay fizzles out on relay_fizzle_knocks knock-offs, or
## relay_fizzle_time seconds after the first, whichever comes first.
var knocks := 0
var first_knock_at := -1.0
var fizzle_warned := false
## Times of enemy-hero hits on the current carrier, for the interception rule.
var _hits: Array[float] = []
var _hit_keys: Array[int] = []


func setup(sim: MatchSim) -> void:
	state = State.DORMANT
	activations = 0
	next_spawn_time = sim.config.first_relay_time
	warned = false
	carrier_id = 0
	_hits.clear()
	_hit_keys.clear()
	_reset_progress()
	_reset_fight()
	_choose_pockets(sim)
	pos = origin
	prev_pos = origin


func is_available(time: float) -> bool:
	return state == State.SPAWNED or (state == State.DROPPED and time >= lock_until)


func carrier(sim: MatchSim) -> HeroState:
	if state != State.CARRIED:
		return null
	return sim.get_entity(carrier_id) as HeroState


func delivery_rect(sim: MatchSim) -> Rect2:
	return sim.arena.pockets[delivery_pocket]


## The long drop for a team (phase 2): a square deep in the enemy half, or an empty
## Rect2 when the map has none or phase 2 hasn't started.
func long_rect(sim: MatchSim, team: int) -> Rect2:
	if sim.phase < 2 or sim.arena.long_drop == Vector2.ZERO:
		return Rect2()
	var c := sim.arena.long_drop if team == MatchSim.BLUE else -sim.arena.long_drop
	var size := Vector2.ONE * sim.config.relay_long_size
	return Rect2(c - size * 0.5, size)


func pickup_rect(sim: MatchSim) -> Rect2:
	return sim.arena.pockets[pickup_pocket]


## Called once per tick by MatchSim, after movement and attacks.
func tick(sim: MatchSim) -> void:
	prev_pos = pos
	var cfg := sim.config
	if first_knock_at >= 0.0 and state != State.DORMANT:
		var left := first_knock_at + cfg.relay_fizzle_time - sim.time
		if not fizzle_warned and left <= cfg.relay_fizzle_warning:
			fizzle_warned = true
			sim.emit_event(&"relay_fizzling", {"at": first_knock_at + cfg.relay_fizzle_time})
		if left <= 0.0001:
			_fizzle(sim)
			return
	match state:
		State.DORMANT:
			if not warned and sim.time + 0.0001 >= next_spawn_time - cfg.relay_warning_time:
				warned = true
				sim.emit_event(&"relay_warning", {"pocket": pickup_pocket, "at": next_spawn_time})
			if sim.time + 0.0001 >= next_spawn_time:
				_spawn(sim)
		State.SPAWNED:
			if _tick_pickup(sim):
				return
			if sim.time + 0.0001 >= expire_at:
				_finish(sim, &"relay_expired", -1)
		State.DROPPED:
			if _tick_pickup(sim):
				return
			if sim.time + 0.0001 >= return_at:
				state = State.SPAWNED
				pos = origin
				prev_pos = origin
				expire_at = sim.time + cfg.relay_return_expire_time
				_reset_progress()
				sim.emit_event(&"relay_returned", {})
		State.CARRIED:
			_tick_carried(sim)


## Manual drop (the carrier's PlayerCommand.drop_relay).
func request_drop(sim: MatchSim, hero: HeroState) -> void:
	if state == State.CARRIED and carrier_id == hero.id:
		_drop(sim, &"manual")


func on_hero_killed(sim: MatchSim, hero: HeroState) -> void:
	if state == State.CARRIED and carrier_id == hero.id:
		_drop(sim, &"knocked_out")


## Any damage from the enemy hero knocks the Relay off its carrier (Lucy): basic attacks,
## skillshots, abilities, traps, damage over time. Troopers and towers never do.
func on_enemy_damage(sim: MatchSim, attacker: HeroState, victim: HeroState) -> void:
	if state == State.CARRIED and victim.id == carrier_id and attacker.team != victim.team:
		_drop(sim, &"intercepted")


## Interception: enough enemy-hero hits on the carrier inside the rolling window.
## Minion and tower hits never count (GDD 7.5).
## key >= 0 groups the pulses of one ability cast: they count as a single hit.
func on_hero_hit(sim: MatchSim, attacker: HeroState, victim: HeroState, key := -1) -> void:
	if state != State.CARRIED or victim.id != carrier_id or attacker.team == victim.team:
		return
	var window := sim.config.relay_intercept_window
	while not _hits.is_empty() and sim.time - _hits[0] > window + 0.0001:
		_hits.remove_at(0)
		_hit_keys.remove_at(0)
	if key >= 0 and _hit_keys.has(key):
		return
	_hits.append(sim.time)
	_hit_keys.append(key)
	if _hits.size() >= sim.config.relay_intercept_hits:
		_drop(sim, &"intercepted")


func _spawn(sim: MatchSim) -> void:
	state = State.SPAWNED
	pos = origin
	prev_pos = origin
	expire_at = sim.time + sim.config.relay_expire_time
	_reset_progress()
	sim.emit_event(&"relay_spawned", {"pocket": pickup_pocket, "delivery": delivery_pocket})


## Standing inside the pickup radius fills that hero's progress; leaving resets it.
## While both heroes are inside, neither makes progress. Returns true on a pickup.
func _tick_pickup(sim: MatchSim) -> bool:
	if not is_available(sim.time):
		return false
	var inside: Array[HeroState] = []
	for h in sim.heroes:
		if h.alive and h.pos.distance_to(pos) <= sim.config.relay_pickup_radius:
			inside.append(h)
		else:
			pickup_progress[h.team] = 0.0
	if inside.size() != 1:
		return false
	var h := inside[0]
	pickup_progress[h.team] += sim.dt
	if pickup_progress[h.team] + 0.0001 < sim.config.relay_pickup_time:
		return false
	state = State.CARRIED
	carrier_id = h.id
	h.carrying_relay = true
	h.carry_speed_mult = sim.config.relay_carrier_speed_mult
	pos = h.pos
	_hits.clear()
	_hit_keys.clear()
	_reset_progress()
	sim.emit_event(&"relay_picked_up", {"hero": h.id, "team": h.team})
	return true


func _tick_carried(sim: MatchSim) -> void:
	var h := carrier(sim)
	if h == null or not h.alive:
		_drop(sim, &"knocked_out")
		return
	pos = h.pos
	var pocket := delivery_rect(sim)
	var far := long_rect(sim, h.team)
	var long := far.has_area() and far.has_point(h.pos)
	if long:
		pocket = far
	var enemy := sim.heroes[1 - h.team]
	contested = enemy.alive and pocket.has_point(enemy.pos)
	if not pocket.has_point(h.pos):
		deliver_progress = 0.0
		return
	if contested:
		return  # Paused, not reset: the carrier keeps what they have built up.
	deliver_progress += sim.dt
	if deliver_progress + 0.0001 >= sim.config.relay_deliver_time:
		Pacing.on_relay_delivered(sim, h, activations, long)
		_release_carrier(sim)
		_finish(sim, &"relay_delivered", h.team, long)


func _drop(sim: MatchSim, reason: StringName) -> void:
	var h := carrier(sim)
	if h != null:
		pos = h.pos
	_release_carrier(sim)
	if reason != &"manual":
		knocks += 1
		if first_knock_at < 0.0:
			first_knock_at = sim.time
		if knocks >= sim.config.relay_fizzle_knocks:
			sim.emit_event(&"relay_dropped", {"reason": reason, "pos": pos})
			_fizzle(sim)
			return
	state = State.DROPPED
	lock_until = sim.time + sim.config.relay_drop_lockout
	return_at = sim.time + sim.config.relay_drop_return_time
	_reset_progress()
	sim.emit_event(&"relay_dropped", {"reason": reason, "pos": pos})


func _release_carrier(sim: MatchSim) -> void:
	var h := sim.get_entity(carrier_id) as HeroState
	if h != null:
		h.carrying_relay = false
	carrier_id = 0
	_hits.clear()
	_hit_keys.clear()


## Ends this activation (delivered or expired) and schedules the next one on the other side.
func _finish(sim: MatchSim, event: StringName, team: int, long := false) -> void:
	state = State.DORMANT
	activations += 1
	next_spawn_time = sim.time + sim.config.relay_interval
	warned = false
	_reset_progress()
	_reset_fight()
	sim.emit_event(event, {"team": team, "long": long})
	_choose_pockets(sim)


func _choose_pockets(sim: MatchSim) -> void:
	var n := sim.arena.pockets.size()
	if n == 0:
		return
	pickup_pocket = (sim.config.relay_first_pocket + activations) % n
	delivery_pocket = (pickup_pocket + 1) % n
	origin = sim.arena.pockets[pickup_pocket].get_center()


## Fought over too long: the Relay vanishes and the next one is scheduled as usual.
func _fizzle(sim: MatchSim) -> void:
	_release_carrier(sim)
	var at := pos
	_finish(sim, &"relay_expired", -1)
	sim.emit_event(&"relay_fizzled", {"pos": at})


func _reset_fight() -> void:
	knocks = 0
	first_knock_at = -1.0
	fizzle_warned = false


func _reset_progress() -> void:
	pickup_progress = [0.0, 0.0]
	deliver_progress = 0.0
	contested = false
