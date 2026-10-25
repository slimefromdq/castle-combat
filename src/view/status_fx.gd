class_name StatusFx
extends Node3D
## Ability visuals that follow hero state: shield bubble, stun halo, slow and haste
## rings, Wounds and Frenzy rings (items), Jose's dance zone and charge ring, marks and
## blindness, Jack's shadow, cloak and decoy. Plus skillshots in flight and one-shot
## rings for area casts.

var view: MatchView
## Per hero id: {"shield", "stun", "slow", "haste", "zone", ...} nodes.
var _parts: Dictionary = {}
## Skillshot id -> node.
var _shots: Dictionary = {}
var _rings: Array = []
var _pillars: Array = []
const MARKER_HEIGHT := 2.6
## Banner id -> node.
var _banners: Dictionary = {}
## Wave meeting marker: an arrow on each lane edge, and the smoothed drift (m/s, sim y).
var _marker: Array[MeshInstance3D] = []
var _meet_y := NAN
var _meet_time := 0.0
var _drift := 0.0
var _ring_mesh := TorusMesh.new()
## Sprint speed trail: short streaks left behind a sprinting hero, fading out.
var _streaks: Array = []
var _streak_mesh := BoxMesh.new()
var _next_streak := {}


func _ready() -> void:
	_streak_mesh.size = Vector3(0.14, 0.06, 1.4)
	_ring_mesh.inner_radius = 0.92
	_ring_mesh.outer_radius = 1.0
	_ring_mesh.rings = 48
	_ring_mesh.ring_segments = 4


func on_sim_event(type: StringName, data: Dictionary) -> void:
	match type:
		&"ability_cast":
			if data.has("radius") and not data.has("point"):
				_spawn_ring(data.pos, data.radius, Palette.team_color(data.team == view.local_seat).lightened(0.4))
		&"guardian_slam":
			var g: SimEntity = view.sim.get_entity(data.id)
			if g != null:
				_spawn_ring(g.pos, data.radius + 1.0, Color(1.0, 0.35, 0.2))
		&"sprint_started":
			var sh: HeroState = view.sim.get_entity(data.hero) as HeroState
			if sh != null:
				_spawn_ring(sh.pos, 1.3, sh.data.sprint_color)
		&"channel_pulse":
			var h: SimEntity = view.sim.get_entity(data.hero)
			_spawn_ring(data.point, data.radius, Palette.team_color(h != null and h.team == view.local_seat).lightened(0.2))
		&"vanish_burst":
			_spawn_ring(data.pos, data.radius, Color("9b6bff"))
		&"shield_shattered":
			_spawn_ring(data.pos, data.radius, Color(0.8, 0.95, 1.0))
		&"level_up":
			# Bright gold ring on every level-up; a wider double ring at the ultimate level.
			var lh: SimEntity = view.sim.get_entity(data.hero)
			if lh != null:
				var big: bool = data.level == Leveling.ULT_LEVEL
				_spawn_ring(lh.pos, 3.6 if big else 2.2, Color(1.0, 0.86, 0.35), 0.7 if big else 0.55)
				if big:
					_spawn_ring(lh.pos, 2.4, Color(1, 1, 1), 0.5)
		&"ult_race_won":
			var uh: SimEntity = view.sim.get_entity(data.hero)
			if uh != null:
				_spawn_pillar(uh.id, Palette.team_color(uh.team == view.local_seat).lightened(0.5))
		&"shield_blocked":
			_spawn_ring(data.pos, 1.2, Color(0.85, 0.95, 1.0), 0.4)
		&"banner_taken":
			var bh: SimEntity = view.sim.get_entity(data.hero)
			if bh != null:
				_spawn_ring(bh.pos, 2.0, Color("f5d76e"), 0.5)
		&"masterwork":
			var mh: SimEntity = view.sim.get_entity(data.hero)
			if mh != null:
				_spawn_ring(mh.pos, 1.8, Color("f5d76e"), 0.5)
		&"teleported":
			_spawn_ring(data.from, 1.2, Color("9b6bff"))
			_spawn_ring(data.to, 1.6, Color("c9a7ff"))


func render() -> void:
	var sim := view.sim
	for h in sim.heroes:
		var p := _parts_for(h)
		var at := view.unit_position(h.id)
		var shielded := h.alive and h.shield_hp > 0.0
		p.shield.visible = shielded
		p.shield.position = at + Vector3(0, 0.7, 0)
		p.stun.visible = h.alive and h.is_stunned(sim.time)
		p.stun.position = at + Vector3(0, 2.4, 0)
		p.stun.rotation.y = Time.get_ticks_msec() / 150.0
		p.slow.visible = h.alive and sim.time < h.slow_until
		p.slow.position = at + Vector3(0, 0.08, 0)
		p.haste.visible = h.alive and sim.time < h.haste_until
		p.haste.position = at + Vector3(0, 0.1, 0)
		p.haste.scale = Vector3(0.75, 0.03, 0.75) * (1.0 + 0.08 * sin(Time.get_ticks_msec() / 60.0))
		p.charge.visible = h.alive and h.is_charging()
		if p.charge.visible:
			var k := clampf((sim.time - h.charging_since) / h.data.abilities[1].charge_time, 0.0, 1.0)
			p.charge.position = at + Vector3(0, 0.12, 0)
			var r := lerpf(1.6, 0.6, k)
			p.charge.scale = Vector3(r, 0.04, r)
			(p.charge.material_override as StandardMaterial3D).albedo_color = Color(1.0, lerpf(0.9, 0.3, k), 0.2, 0.95) if k < 1.0 else Color(1, 1, 1, 0.95)
		p.mark.visible = h.alive and sim.time < h.mark_until
		p.mark.position = at + Vector3(0, 2.3, 0)
		p.mark.rotation.y = Time.get_ticks_msec() / 300.0
		p.blind.visible = h.alive and sim.time < h.blind_until
		p.blind.position = at + Vector3(0, 2.0, 0)
		p.shadow.visible = h.alive and h.is_vanished()
		p.shadow.position = at + Vector3(0, 0.05, 0)
		p.shadow.scale = Vector3.ONE * (1.0 + 0.1 * sin(Time.get_ticks_msec() / 80.0))
		p.decoy.visible = h.alive and sim.time < h.decoy_until
		p.decoy.position = MatchView.to_world(h.decoy_pos, 0.8)
		var cloak_open: bool = h.alive and sim.time < h.recast_until[0] and h.data.abilities[0].effect == &"cloak_toss" and h.cloak_shot_id == 0
		p.cloak.visible = cloak_open
		p.cloak.position = MatchView.to_world(h.cloak_pos, 0.06)
		p.cloak.rotation.y = Time.get_ticks_msec() / 500.0
		p.wounds.visible = h.alive and sim.time < h.wounds_until
		p.wounds.position = at + Vector3(0, 0.12, 0)
		p.frenzy.visible = h.alive and h.frenzy_left > 0
		p.frenzy.position = at + Vector3(0, 0.14, 0)
		p.frenzy.scale = Vector3.ONE * (0.6 + 0.06 * sin(Time.get_ticks_msec() / 45.0))
		p.zone.visible = h.alive and h.is_channeling()
		if p.zone.visible:
			var r := h.channel.radius
			p.zone.position = MatchView.to_world(h.channel_point, 0.06)
			p.zone.scale = Vector3(r, 0.03, r)
	for st in sim.structures:
		if st.is_guardian():
			_render_guardian(st)
	_render_skillshots(sim)
	_update_rings()
	_update_pillars()
	_render_banners(sim)
	_render_wave_marker(sim)
	_update_streaks(sim)


## Skillshots in flight: Judgment Blade a white crescent, Sweet Talk a bullet that grows
## with its charge, Jack's cloak a spinning violet square.
func _render_skillshots(sim: MatchSim) -> void:
	var live := {}
	for s in sim.skillshots:
		live[s.id] = true
		if not _shots.has(s.id):
			var node: MeshInstance3D
			match s.ability.effect:
				&"judgment_blade":
					node = UnitFactory.part(self, UnitFactory.box(Vector3(1.6, 0.12, 0.35)), Color(1.0, 0.97, 0.8, 0.95), Vector3.ZERO, Vector3.ZERO, true)
				&"cloak_toss":
					node = UnitFactory.part(self, UnitFactory.box(Vector3(0.9, 0.05, 0.9)), Color("7a4fd6"), Vector3.ZERO, Vector3.ZERO, true)
				_:
					var ball := SphereMesh.new()
					ball.radius = 0.18 + 0.18 * s.charge
					ball.height = ball.radius * 2.0
					node = UnitFactory.part(self, ball, Color(1.0, 0.85, 0.3) if s.charge < 1.0 else Color(1, 1, 1), Vector3.ZERO, Vector3.ZERO, true)
			_shots[s.id] = node
		var n: MeshInstance3D = _shots[s.id]
		n.position = MatchView.to_world(s.pos, 0.9)
		n.rotation.y = atan2(-s.dir.x, s.dir.y)
		if s.ability.effect == &"cloak_toss":
			n.rotation.y += Time.get_ticks_msec() / 60.0
	for id: int in _shots.keys():
		if not live.has(id):
			_shots[id].queue_free()
			_shots.erase(id)


## Guardian beam (always visible while it has a target, hotter as it ramps, with a
## marker on whoever it is burning), stomp telegraph and recovery label.
func _render_guardian(s: StructureState) -> void:
	var sim := view.sim
	if not _parts.has(s.id):
		var beam := MeshInstance3D.new()
		beam.mesh = UnitFactory.cylinder(1.0, 1.0, 1.0, 8)
		beam.material_override = UnitFactory.material(Color(1.0, 0.45, 0.2, 0.9), true)
		add_child(beam)
		_parts[s.id] = {
			"beam": beam,
			"mark": UnitFactory.part(self, _ring_mesh, Color(1.0, 0.3, 0.15, 0.95), Vector3.ZERO, Vector3.ZERO, true),
			"tele": UnitFactory.part(self, UnitFactory.cylinder(1.0, 1.0, 0.02, 48), Color(1.0, 0.2, 0.15, 0.3), Vector3.ZERO, Vector3.ZERO, true),
			"edge": UnitFactory.part(self, _ring_mesh, Color(1.0, 0.25, 0.2, 0.95), Vector3.ZERO, Vector3.ZERO, true),
			"rest": UnitFactory.label(self, "Recovering", 0.0, 40),
		}
	var p: Dictionary = _parts[s.id]
	var center := MatchView.to_world(s.pos, 0.0)
	var target := sim.get_entity(s.attack_target if s.attack_target != 0 else s.beam_target)
	var active := s.alive and sim.is_exposed(s) and not s.is_busy(sim.time)
	var firing := active and target != null and target.alive and CombatSystem.in_range(sim, s, target, 0.5) \
			and (s.is_winding_up() or sim.time - s.beam_last < 0.8)
	p.beam.visible = firing
	p.mark.visible = firing
	if firing:
		var from := center + Vector3(0, s.data.height + 0.6, 0)
		var to := view.unit_position(target.id) + Vector3(0, 0.6, 0)
		var ramp := 0.0
		if s.beam_target == target.id:
			ramp = clampf((sim.time - s.beam_since) * s.data.beam_ramp_per_second / maxf(0.01, s.data.beam_max_mult - 1.0), 0.0, 1.0)
		var width := lerpf(0.14, 0.34, ramp)
		var length := from.distance_to(to)
		p.beam.position = (from + to) / 2.0
		p.beam.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized())).scaled(Vector3(width, length, width))
		var hot := Color(1.0, lerpf(0.85, 0.15, ramp), lerpf(0.4, 0.1, ramp), 0.95)
		(p.beam.material_override as StandardMaterial3D).albedo_color = hot
		p.mark.position = view.unit_position(target.id) + Vector3(0, 0.07, 0)
		var r := target.radius + 0.55 + 0.08 * sin(Time.get_ticks_msec() / 70.0)
		p.mark.scale = Vector3(r, 0.05, r)
		(p.mark.material_override as StandardMaterial3D).albedo_color = hot
	# Stomp telegraph: the full area fills in red while the edge pulses, so the way out is clear.
	var winding := s.alive and s.slam_at >= 0.0
	p.tele.visible = winding
	p.edge.visible = winding
	if winding:
		var rad := s.data.slam_radius
		var k := clampf(1.0 - (s.slam_at - sim.time) / maxf(0.01, s.data.slam_windup), 0.0, 1.0)
		p.tele.position = center + Vector3(0, 0.05, 0)
		p.tele.scale = Vector3(rad * k, 1.0, rad * k)
		(p.tele.material_override as StandardMaterial3D).albedo_color.a = lerpf(0.15, 0.45, k)
		p.edge.position = center + Vector3(0, 0.1, 0)
		p.edge.scale = Vector3(rad, 0.06, rad)
		(p.edge.material_override as StandardMaterial3D).albedo_color.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 60.0)
	p.rest.visible = s.alive and sim.time < s.disabled_until
	p.rest.position = center + Vector3(0, s.data.height + 2.4, 0)


func _parts_for(h: HeroState) -> Dictionary:
	if _parts.has(h.id):
		return _parts[h.id]
	var team_c := Palette.team_color(h.team == view.local_seat)
	var bubble := SphereMesh.new()
	bubble.radius = 1.0
	bubble.height = 2.0
	var parts := {
		"shield": UnitFactory.part(self, bubble, Color(0.75, 0.9, 1.0, 0.28), Vector3.ZERO, Vector3.ZERO, true),
		"stun": UnitFactory.part(self, _ring_mesh, Color("ffe14d"), Vector3.ZERO, Vector3.ZERO, true),
		"slow": UnitFactory.part(self, _ring_mesh, Color(0.55, 0.8, 1.0, 0.8), Vector3.ZERO, Vector3.ZERO, true),
		"haste": UnitFactory.part(self, _ring_mesh, Color(1.0, 0.92, 0.55, 0.8), Vector3.ZERO, Vector3.ZERO, true),
		"charge": UnitFactory.part(self, _ring_mesh, Color(1.0, 0.8, 0.2, 0.95), Vector3.ZERO, Vector3.ZERO, true),
		"mark": UnitFactory.part(self, UnitFactory.box(Vector3(0.32, 0.32, 0.06)), Color("ff5c8a"), Vector3.ZERO, Vector3(0, 0, 45), true),
		"blind": UnitFactory.part(self, UnitFactory.box(Vector3(0.9, 0.16, 0.06)), Color(0.15, 0.12, 0.2, 0.9), Vector3.ZERO, Vector3.ZERO, true),
		"shadow": UnitFactory.part(self, UnitFactory.cylinder(1.1, 1.1, 0.04, 32), Color(0.2, 0.08, 0.35, 0.75), Vector3.ZERO, Vector3.ZERO, true),
		"decoy": UnitFactory.part(self, bubble, Color(0.6, 0.45, 1.0, 0.35), Vector3.ZERO, Vector3.ZERO, true),
		"cloak": UnitFactory.part(self, UnitFactory.box(Vector3(0.9, 0.05, 0.9)), Color("7a4fd6"), Vector3.ZERO, Vector3.ZERO, true),
		"zone": UnitFactory.part(self, _ring_mesh, Color(team_c.lightened(0.2), 0.9), Vector3.ZERO, Vector3.ZERO, true),
		"wounds": UnitFactory.part(self, _ring_mesh, Color(0.55, 0.05, 0.1, 0.9), Vector3.ZERO, Vector3.ZERO, true),
		"frenzy": UnitFactory.part(self, _ring_mesh, Color(1.0, 0.2, 0.25, 0.9), Vector3.ZERO, Vector3.ZERO, true),
	}
	parts.wounds.scale = Vector3(1.05, 0.03, 1.05)
	parts.shield.scale = Vector3(0.95, 0.95, 0.95)
	parts.stun.scale = Vector3(0.45, 0.05, 0.45)
	parts.slow.scale = Vector3(0.9, 0.03, 0.9)
	parts.decoy.scale = Vector3(0.6, 0.8, 0.6)
	_parts[h.id] = parts
	return parts


## A ring that grows to `radius` and fades: shows the area an ability just hit.
func _spawn_ring(p: Vector2, radius: float, color: Color, life := 0.35) -> void:
	var node := UnitFactory.part(self, _ring_mesh, color, MatchView.to_world(p, 0.1), Vector3.ZERO, true)
	_rings.append({"node": node, "t": 0.0, "r": radius, "life": life})


## Ult race: a column of light over the first hero to reach the ultimate level.
func _spawn_pillar(hero_id: int, color: Color) -> void:
	var node := UnitFactory.part(self, UnitFactory.cylinder(0.9, 1.2, 14.0, 24), Color(color, 0.55), Vector3.ZERO, Vector3.ZERO, true)
	_pillars.append({"node": node, "t": 0.0, "id": hero_id})


func _update_rings() -> void:
	var delta := get_process_delta_time()
	for i in range(_rings.size() - 1, -1, -1):
		var g: Dictionary = _rings[i]
		g.t += delta
		var k: float = g.t / g.life
		if k >= 1.0:
			g.node.queue_free()
			_rings.remove_at(i)
			continue
		var r: float = lerpf(0.3, g.r, k)
		g.node.scale = Vector3(r, 0.04, r)
		(g.node.material_override as StandardMaterial3D).albedo_color.a = 1.0 - k


## Banners on the ground: they bob, and blink in their last 4 seconds.
func _render_banners(sim: MatchSim) -> void:
	var live := {}
	for b in sim.banners:
		live[b.id] = true
		if not _banners.has(b.id):
			_banners[b.id] = UnitFactory.make_banner(self)
		var node: Node3D = _banners[b.id]
		node.position = MatchView.to_world(b.pos, 0.1 * sin(Time.get_ticks_msec() / 200.0))
		var left: float = b.expires_at - sim.time
		node.visible = left > 4.0 or int(Time.get_ticks_msec() / 150) % 2 == 0
	for id: int in _banners.keys():
		if not live.has(id):
			_banners[id].queue_free()
			_banners.erase(id)


## Where the waves meet: an arrow on each lane edge pointing the way the fight is
## drifting, in your color when it drifts toward the enemy base and theirs when it
## drifts toward yours; a flat diamond while it holds still.
func _render_wave_marker(sim: MatchSim) -> void:
	if _marker.is_empty():
		var arrow := PrismMesh.new()
		arrow.size = Vector3(0.9, 1.1, 0.08)
		for side in 2:
			_marker.append(UnitFactory.part(self, arrow, Color.WHITE, Vector3.ZERO, Vector3.ZERO, true))
	var y := Waves.meeting_y(sim)
	if is_nan(y):
		for m in _marker:
			m.visible = false
		_meet_y = NAN
		return
	var dt := sim.time - _meet_time
	if not is_nan(_meet_y) and dt > 0.0:
		_drift = lerpf(_drift, (y - _meet_y) / dt, clampf(dt * 1.5, 0.0, 1.0))
	if dt > 0.0 or is_nan(_meet_y):
		_meet_y = y
		_meet_time = sim.time
	# Toward +y is toward red's base; "forward" for the local seat.
	var toward_enemy := _drift * MatchSim.forward(view.local_seat).y
	var still := absf(_drift) < 0.25
	var color := Color(1, 1, 1, 0.85)
	if not still:
		color = Palette.team_color(toward_enemy > 0.0).lightened(0.25)
	for side in 2:
		var m := _marker[side]
		m.visible = true
		# Floats above the pocket pillars, which stand at mid-lane where waves often meet.
		var x: float = (side * 2 - 1) * (sim.arena.lane_half_width - 0.8)
		m.position = MatchView.to_world(Vector2(x, y), MARKER_HEIGHT)
		# The prism's tip is local +Y; laid flat it points to world -Z (sim +y).
		m.rotation_degrees = Vector3(-90, 0 if _drift >= 0.0 else 180, 0)
		m.scale = Vector3(1.0, 0.55, 1.0) if still else Vector3.ONE
		(m.material_override as StandardMaterial3D).albedo_color = color


func _update_pillars() -> void:
	var delta := get_process_delta_time()
	for i in range(_pillars.size() - 1, -1, -1):
		var g: Dictionary = _pillars[i]
		g.t += delta
		var k: float = g.t / 1.4
		if k >= 1.0:
			g.node.queue_free()
			_pillars.remove_at(i)
			continue
		var at := view.unit_position(g.id)
		g.node.position = Vector3(at.x, 7.0, at.z)
		var w := lerpf(1.0, 0.2, k)
		g.node.scale = Vector3(w, 1.0, w)
		(g.node.material_override as StandardMaterial3D).albedo_color.a = 0.55 * (1.0 - k * k)


## Every 0.05 s a sprinting hero drops two streaks (one per side) in its trail colour.
func _update_streaks(sim: MatchSim) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for h in sim.heroes:
		if not (h.alive and h.sprinting) or now < _next_streak.get(h.id, 0.0):
			continue
		_next_streak[h.id] = now + 0.05
		var at := view.unit_position(h.id)
		var back := Vector3(-h.facing.x, 0, h.facing.y)  # Sim y is world -z.
		var side := Vector3(back.z, 0, -back.x)
		var yaw := atan2(-h.facing.x, h.facing.y)
		for s: float in [-1.0, 1.0]:
			var p := at + back * 0.7 + side * (0.28 * s) + Vector3(0, 0.25 + 0.2 * randf(), 0)
			var node := UnitFactory.part(self, _streak_mesh, Color(h.data.sprint_color, 0.85), p, Vector3(0, rad_to_deg(yaw), 0), true)
			_streaks.append({"node": node, "t": 0.0})
	var delta := get_process_delta_time()
	for i in range(_streaks.size() - 1, -1, -1):
		var g: Dictionary = _streaks[i]
		g.t += delta
		var k: float = g.t / 0.3
		if k >= 1.0:
			g.node.queue_free()
			_streaks.remove_at(i)
			continue
		g.node.scale = Vector3(1.0, 1.0, 1.0 - 0.6 * k)
		(g.node.material_override as StandardMaterial3D).albedo_color.a = 0.85 * (1.0 - k)


## Seat swaps rebuild team colors.
func reset() -> void:
	_drift = 0.0
	for id in _parts:
		for n: Node3D in _parts[id].values():
			n.queue_free()
	_parts.clear()
