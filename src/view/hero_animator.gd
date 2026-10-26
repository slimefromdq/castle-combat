class_name HeroAnimator
extends RefCounted
## One animator for every hero: idle breathing, walk cycle, sprint lean, attack windup
## and follow-through, casts, the ultimate's pose and hit stagger. Each hero's AnimStyle
## tunes it. Timing comes from the sim (windup progress, when a shot fired or an ability
## was cast, when damage landed), so a pose never runs ahead of or behind the game.
##
## It only moves each hero's "Body/Pose" node (position, rotation, scale), never the
## parts inside, so replacing a body with drawn or modelled art keeps the animation.

var sim: MatchSim
var _styles := {}
## Per hero id: walk phase, last strike time, last cast time and slot.
var _state := {}


func reset(match_sim: MatchSim) -> void:
	sim = match_sim
	_state.clear()


func on_sim_event(type: StringName, data: Dictionary) -> void:
	match type:
		&"attack_fired":
			_st(data.attacker).fired = sim.time
		&"ability_cast":
			var st := _st(data.hero)
			st.cast_at = sim.time
			st.cast_slot = data.slot


func _st(id: int) -> Dictionary:
	if not _state.has(id):
		_state[id] = {"phase": 0.0, "fired": -10.0, "cast_at": -10.0, "cast_slot": 0}
	return _state[id]


func style(h: HeroState) -> AnimStyle:
	if not _styles.has(h.data.shape):
		_styles[h.data.shape] = AnimStyle.for_shape(h.data.shape)
	return _styles[h.data.shape]


## alpha: how far between the last two ticks, so poses are as smooth as positions.
func animate(h: HeroState, pose: Node3D, alpha: float, delta: float) -> void:
	var s := style(h)
	var st := _st(h.id)
	var now := sim.time + (alpha - 1.0) * sim.dt
	var clock := Time.get_ticks_msec() / 1000.0 + h.id * 0.37
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO  # Degrees: x = lean (negative is forward), y = twist, z = roll.
	var scale := Vector3.ONE

	# Idle breathing and sway.
	var breath := sin(clock * s.breathe_rate)
	scale.y += s.breathe * breath
	scale.x -= s.breathe * 0.5 * breath
	scale.z -= s.breathe * 0.5 * breath
	rot.z += s.idle_sway_deg * sin(clock * s.breathe_rate * 0.5)

	# Walk: phase advances with distance travelled, so feet don't skate.
	var moved := h.pos.distance_to(h.prev_pos)
	var speed := moved / sim.dt
	var walk := clampf(speed / maxf(h.data.move_speed, 0.1), 0.0, 1.0) if h.alive else 0.0
	st.phase = fmod(st.phase + speed * delta * s.steps_per_m * PI, TAU * 100.0)
	var step := sin(st.phase)
	pos.y += absf(step) * s.walk_bob * walk
	rot.z += step * s.walk_roll_deg * walk
	rot.x -= s.walk_lean_deg * walk
	pos.x += step * s.walk_slide * walk
	if h.sprinting:
		rot.x -= h.data.sprint_lean_deg
		pos.y += absf(sin(clock * 14.0)) * h.data.sprint_bob

	# Basic attack: pull back through the windup, then strike and settle.
	if h.is_winding_up():
		var p := h.windup_progress()
		rot.x += s.windup_pull_deg * p
		pos.z += 0.1 * p * s.strike_size
		scale.y -= 0.05 * p
		if s.strike == AnimStyle.Strike.SWING:
			rot.y += 35.0 * p * s.strike_size
	var since_fire: float = now - st.fired
	if since_fire >= 0.0 and since_fire < s.strike_time:
		var punch := _punch(since_fire / s.strike_time)
		match s.strike:
			AnimStyle.Strike.LUNGE:
				pos.z -= 0.28 * punch * s.strike_size
				rot.x -= 14.0 * punch * s.strike_size
			AnimStyle.Strike.RECOIL:
				pos.z += 0.12 * punch * s.strike_size
				rot.x += 10.0 * punch * s.strike_size
			AnimStyle.Strike.SWING:
				rot.y -= 45.0 * punch * s.strike_size
				rot.x -= 8.0 * punch * s.strike_size
			AnimStyle.Strike.HOP:
				pos.y += 0.25 * punch * s.strike_size
				scale *= 1.0 + 0.08 * punch

	# Casts and the ultimate.
	var is_ult: bool = st.cast_slot == 2
	var length := s.ult_time if is_ult else s.cast_time
	var since_cast: float = now - st.cast_at
	if since_cast >= 0.0 and since_cast < length:
		var c := since_cast / length
		var posed := _cast_pose(s.ult if is_ult else s.cast, c, 1.6 if is_ult else 1.0, pos, rot, scale)
		pos = posed[0]
		rot = posed[1]
		scale = posed[2]

	# Hit stagger.
	var since_hit := now - h.last_damaged_time
	if h.alive and since_hit >= 0.0 and since_hit < 0.2:
		var k := 1.0 - since_hit / 0.2
		rot.x += s.stagger_deg * k
		pos.z += 0.06 * k

	pose.position = pos
	pose.rotation_degrees = rot
	pose.scale = scale


## c: 0..1 through the cast. size: 1 for Q/E, bigger for the ult. Returns [pos, rot, scale].
static func _cast_pose(kind: AnimStyle.Cast, c: float, size: float, pos: Vector3, rot: Vector3, scale: Vector3) -> Array:
	var arc := sin(PI * c)
	match kind:
		AnimStyle.Cast.RAISE:
			scale.y += 0.12 * arc * size
			pos.y += 0.12 * arc * size
			rot.x += 8.0 * arc * size
		AnimStyle.Cast.SPIN:
			rot.y += 360.0 * _ease_out(c) * (2.0 if size > 1.0 else 1.0)
			pos.y += 0.08 * arc * size
		AnimStyle.Cast.STOMP:
			# Up, then slam down with a squash.
			if c < 0.5:
				pos.y += 0.35 * sin(PI * c * 2.0) * size
			else:
				var sq := sin(PI * (c - 0.5) * 2.0)
				scale.y -= 0.18 * sq * size
				scale.x += 0.1 * sq * size
				scale.z += 0.1 * sq * size
		AnimStyle.Cast.BOW:
			rot.x -= 24.0 * arc * size
		AnimStyle.Cast.LEAP:
			pos.y += 0.55 * arc * size
			rot.x -= 10.0 * arc
			if c > 0.85:
				scale.y -= 0.2 * sin(PI * (c - 0.85) / 0.15)
		AnimStyle.Cast.GROW:
			scale *= 1.0 + 0.16 * arc * size
			pos.y += 0.05 * arc
	return [pos, rot, scale]


## After the match: the winner repeats their ult pose as a victory dance, the loser
## hangs their head. t = seconds since the match ended.
func celebrate(h: HeroState, pose: Node3D, t: float, won: bool) -> void:
	var s := style(h)
	if won:
		var beat := 1.1
		var posed := _cast_pose(s.ult, fmod(t, beat) / beat, 1.3, Vector3.ZERO, Vector3.ZERO, Vector3.ONE)
		pose.position = posed[0] + Vector3(0, absf(sin(t * 6.0)) * 0.06, 0)
		pose.rotation_degrees = posed[1]
		pose.scale = posed[2]
	else:
		var k := clampf(t / 0.6, 0.0, 1.0)
		pose.position = Vector3.ZERO
		pose.rotation_degrees = Vector3(-28.0 * k, 0, 4.0 * sin(t * 1.5) * k)
		pose.scale = Vector3(1.0, 1.0 - 0.08 * k, 1.0)


## A quick snap to 1, then a slower settle back to 0.
static func _punch(t: float) -> float:
	if t < 0.2:
		return t / 0.2
	var r := 1.0 - (t - 0.2) / 0.8
	return r * r


static func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)
