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
## Trap id -> node.
var _traps: Dictionary = {}
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
		&"core_stun":
			var c: SimEntity = view.sim.get_entity(data.id)
			if c != null:
				_spawn_ring(c.pos, data.radius + 0.5, Color(1.0, 0.85, 0.25))
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
				var big: bool = data.level == Leveling.ULT_LEVEL or data.level == Leveling.CROWN_LEVEL
				_spawn_ring(lh.pos, 3.6 if big else 2.2, Color(1.0, 0.86, 0.35), 0.7 if big else 0.55)
				if big:
					_spawn_ring(lh.pos, 2.4, Color(1, 1, 1), 0.5)
				if data.level == Leveling.CROWN_LEVEL:
					_spawn_ring(lh.pos, 5.0, Color("e8c35a"), 0.9)
		&"ult_race_won":
			var uh: SimEntity = view.sim.get_entity(data.hero)
			if uh != null:
				_spawn_pillar(uh.id, Palette.team_color(uh.team == view.local_seat).lightened(0.5))
		&"shield_blocked":
			_spawn_ring(data.pos, 1.2, Color(0.85, 0.95, 1.0), 0.4)
		&"masterwork":
			var mh: SimEntity = view.sim.get_entity(data.hero)
			if mh != null:
				_spawn_ring(mh.pos, 1.8, Color("f5d76e"), 0.5)
		&"hooked", &"flung":
			_spawn_ring(data.to, 1.4, Color("c9d1d9"), 0.4)
		&"whale_breach":
			_spawn_ring(data.to, data.width + 2.0, Color(0.85, 0.95, 1.0), 0.6)
			_spawn_ring(data.from.lerp(data.to, 0.5), data.width + 1.5, Color(0.5, 0.75, 1.0), 0.5)
		&"trap_sprung":
			_spawn_ring(data.pos, 1.4, Color("c9d1d9"), 0.4)
		&"overwhelm":
			_spawn_ring(data.pos, 2.0, Color("ffd23a"), 0.45)
		&"scattered":
			_spawn_ring(data.from, 1.4, Color("ffd23a"), 0.35)
			_spawn_ring(data.to, 1.6, Color("ffe680"), 0.35)
		&"head_spin":
			_spawn_ring(data.pos, data.radius, Color("e88fb0"), 0.6)
		&"thread_snapped":
			_spawn_ring(data.pos, 1.2, Color("f6eee8"), 0.35)
		&"rule_landed":
			_spawn_ring(data.pos, data.radius, Color("e8c35a"), 0.6)
			_spawn_ring(data.pos, data.radius * 0.6, Color(1, 1, 1), 0.45)
		&"rule_failed":
			var fh: SimEntity = view.sim.get_entity(data.hero)
			if fh != null:
				_spawn_ring(fh.pos, 2.0, Color(0.6, 0.05, 0.1), 0.6)
		&"rule_forgiven":
			var gh: SimEntity = view.sim.get_entity(data.hero)
			if gh != null:
				_spawn_ring(gh.pos, 2.0, Color("e8c35a"), 0.5)
		&"teleported":
			_spawn_ring(data.from, 1.2, Color("9b6bff"))
			_spawn_ring(data.to, 1.6, Color("c9a7ff"))


func render() -> void:
	var sim := view.sim
	for h in sim.heroes:
		var p := _parts_for(h)
		var hidden := sim.is_hidden(h)
		if hidden and h.team != view.local_seat:
			for n: Node3D in p.values():
				n.visible = false
			continue
		var at := view.unit_position(h.id)
		# Your own hero in a bush: a leafy ring says the enemy can't see you.
		p.hidden.visible = hidden
		p.hidden.position = at + Vector3(0, 0.06, 0)
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
		p.mark.visible = h.alive and (sim.time < h.mark_until or (h.hunt_mark_left > 0 and sim.time < h.hunt_mark_until))
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
		p.frenzy.visible = h.alive and (h.frenzy_left > 0 or sim.time < h.frenzy_until)
		p.frenzy.position = at + Vector3(0, 0.14, 0)
		p.frenzy.scale = Vector3.ONE * (0.6 + 0.06 * sin(Time.get_ticks_msec() / 45.0))
		p.crown.visible = h.alive and h.level >= Leveling.CROWN_LEVEL
		p.crown.position = at + Vector3(0, 0.05, 0)
		_render_latch(h, p, at)
		_render_kit(h, p, at)
		p.zone.visible = h.alive and h.is_channeling()
		if p.zone.visible:
			var r := h.channel.radius
			p.zone.position = MatchView.to_world(h.channel_point, 0.06)
			p.zone.scale = Vector3(r, 0.03, r)
	for st in sim.structures:
		if st.is_guardian():
			_render_guardian(st)
		elif st.tier == 2:
			_render_core(st)
	_render_skillshots(sim)
	_render_traps(sim)
	_render_clouds(sim)
	_update_rings()
	_update_pillars()
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
				&"harpoon":
					node = UnitFactory.part(self, UnitFactory.box(Vector3(0.12, 0.12, 0.9)), Color("c9d1d9"), Vector3.ZERO, Vector3.ZERO, true)
					UnitFactory.part(node, UnitFactory.box(Vector3(0.5, 0.1, 0.1)), Color("9aa3ad"), Vector3(0, 0, -0.45), Vector3.ZERO, true)
				&"recoil_bolt", &"threaded_needle":
					node = UnitFactory.part(self, UnitFactory.box(Vector3(0.07, 0.07, 0.8)), Color("f6eee8") if s.ability.effect == &"threaded_needle" else Color("c9d1d9"), Vector3.ZERO, Vector3.ZERO, true)
				&"headsmans_axe":
					node = UnitFactory.part(self, UnitFactory.box(Vector3(1.6, 0.12, 0.9)), Color("c9d1d9"), Vector3.ZERO, Vector3.ZERO, true)
					UnitFactory.part(node, UnitFactory.box(Vector3(0.16, 0.14, 2.0)), Color("6b4a2b"), Vector3(0, 0, 0.6), Vector3.ZERO, true)
				&"fang_dart":
					node = UnitFactory.part(self, UnitFactory.box(Vector3(0.08, 0.08, 0.6)), Color("7be35a"), Vector3.ZERO, Vector3.ZERO, true)
					UnitFactory.part(node, UnitFactory.box(Vector3(0.18, 0.04, 0.12)), Color("2f8f4e"), Vector3(0, 0, 0.3), Vector3.ZERO, true)
				&"latch_cloud":
					var puff := SphereMesh.new()
					puff.radius = 0.5
					puff.height = 0.7
					node = UnitFactory.part(self, puff, Color(1.0, 0.82, 0.2, 0.75), Vector3.ZERO, Vector3.ZERO, true)
				_:
					var ball := SphereMesh.new()
					ball.radius = 0.18 + 0.18 * s.charge
					ball.height = ball.radius * 2.0
					node = UnitFactory.part(self, ball, Color(1.0, 0.85, 0.3) if s.charge < 1.0 else Color(1, 1, 1), Vector3.ZERO, Vector3.ZERO, true)
			_shots[s.id] = node
		var n: MeshInstance3D = _shots[s.id]
		n.position = MatchView.to_world(s.pos, 0.9)
		n.rotation.y = atan2(-s.dir.x, s.dir.y)
		if s.ability.effect == &"cloak_toss" or s.ability.effect == &"headsmans_axe":
			n.rotation.y += Time.get_ticks_msec() / 60.0
	for id: int in _shots.keys():
		if not live.has(id):
			_shots[id].queue_free()
			_shots.erase(id)


## Core last stand: the guard half circle in front of an exposed Core (bright while its
## hero guards it), a "Guarded" tag, and the stun telegraph (a gold disc filling in).
func _render_core(s: StructureState) -> void:
	var sim := view.sim
	if not _parts.has(s.id):
		var team_c := Palette.team_color(s.team == view.local_seat)
		var zone := MeshInstance3D.new()
		zone.mesh = _half_disc(sim.config.core_guard_radius)
		zone.material_override = UnitFactory.material(Color(team_c, 0.18), true)
		add_child(zone)
		var tag := UnitFactory.label(self, "Guarded", 0.0, 40)
		tag.modulate = team_c.lightened(0.3)
		_parts[s.id] = {
			"zone": zone,
			"tag": tag,
			"tele": UnitFactory.part(self, UnitFactory.cylinder(1.0, 1.0, 0.02, 48), Color(1.0, 0.85, 0.2, 0.3), Vector3.ZERO, Vector3.ZERO, true),
			"edge": UnitFactory.part(self, _ring_mesh, Color(1.0, 0.85, 0.25, 0.95), Vector3.ZERO, Vector3.ZERO, true),
		}
	var p: Dictionary = _parts[s.id]
	var center := MatchView.to_world(s.pos, 0.0)
	var exposed := s.alive and sim.is_exposed(s)
	p.zone.visible = exposed and not sim.overtime
	if p.zone.visible:
		p.zone.position = center + Vector3(0, 0.04, 0)
		p.zone.rotation.y = 0.0 if s.team == MatchSim.BLUE else PI
		(p.zone.material_override as StandardMaterial3D).albedo_color.a = 0.32 if s.guarded else 0.12
	p.tag.visible = exposed and s.guarded
	p.tag.position = center + Vector3(0, 3.6, 0)
	var winding := exposed and s.stun_at >= 0.0
	p.tele.visible = winding
	p.edge.visible = winding
	if winding:
		var rad := sim.config.core_stun_radius
		var k := clampf(1.0 - (s.stun_at - sim.time) / maxf(0.01, sim.config.core_stun_windup), 0.0, 1.0)
		p.tele.position = center + Vector3(0, 0.06, 0)
		p.tele.scale = Vector3(rad * k, 1.0, rad * k)
		(p.tele.material_override as StandardMaterial3D).albedo_color.a = lerpf(0.12, 0.4, k)
		p.edge.position = center + Vector3(0, 0.11, 0)
		p.edge.scale = Vector3(rad, 0.06, rad)
		(p.edge.material_override as StandardMaterial3D).albedo_color.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 90.0)


## A flat half disc facing world -Z (blue's forward), for the Core's guard zone.
static func _half_disc(radius: float, segments := 32) -> ArrayMesh:
	var verts := PackedVector3Array()
	for i in segments:
		var a0 := PI * float(i) / segments
		var a1 := PI * float(i + 1) / segments
		verts.append(Vector3.ZERO)
		verts.append(Vector3(cos(a1) * radius, 0, -sin(a1) * radius))
		verts.append(Vector3(cos(a0) * radius, 0, -sin(a0) * radius))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


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
		"hidden": UnitFactory.part(self, _ring_mesh, Color(0.55, 1.0, 0.55, 0.9), Vector3.ZERO, Vector3.ZERO, true),
		"root": UnitFactory.part(self, _ring_mesh, Color(0.75, 0.78, 0.82, 0.95), Vector3.ZERO, Vector3.ZERO, true),
		"silence": UnitFactory.part(self, UnitFactory.box(Vector3(0.7, 0.12, 0.06)), Color(0.9, 0.2, 0.3, 0.95), Vector3.ZERO, Vector3(0, 0, 45), true),
		"phase": UnitFactory.part(self, bubble, Color(1.0, 0.85, 0.25, 0.25), Vector3.ZERO, Vector3.ZERO, true),
		"tele": UnitFactory.part(self, UnitFactory.box(Vector3(1, 0.02, 1)), Color(1.0, 0.3, 0.2, 0.3), Vector3.ZERO, Vector3.ZERO, true),
		"tether": _line_part(Color(0.8, 0.82, 0.86, 0.9)),
		"swarm": UnitFactory.part(self, bubble, Color(1.0, 0.82, 0.2, 0.35), Vector3.ZERO, Vector3.ZERO, true),
		"rule": UnitFactory.part(self, _ring_mesh, Color("e8c35a"), Vector3.ZERO, Vector3.ZERO, true),
		"borrowed": UnitFactory.part(self, _ring_mesh, Color(0.6, 0.05, 0.12, 0.9), Vector3.ZERO, Vector3.ZERO, true),
	}
	parts.latch = _latch_swarm()
	# Max level: a gold crown ring at the hero's feet for the rest of the match.
	parts.crown = UnitFactory.part(self, _ring_mesh, Color("e8c35a"), Vector3.ZERO, Vector3.ZERO, true)
	parts.crown.scale = Vector3(1.25, 0.04, 1.25)
	parts.buzz = UnitFactory.label(self, "", 0.0, 44)
	parts.buzz.modulate = Color("ffd23a")
	parts.buzz.outline_modulate = Color(0.15, 0.1, 0.0)
	parts.root.scale = Vector3(0.7, 0.12, 0.7)
	parts.borrowed.scale = Vector3(1.15, 0.03, 1.15)
	parts.hidden.scale = Vector3(0.85, 0.03, 0.85)
	parts.wounds.scale = Vector3(1.05, 0.03, 1.05)
	parts.shield.scale = Vector3(0.95, 0.95, 0.95)
	parts.stun.scale = Vector3(0.45, 0.05, 0.45)
	parts.slow.scale = Vector3(0.9, 0.03, 0.9)
	parts.decoy.scale = Vector3(0.6, 0.8, 0.6)
	_parts[h.id] = parts
	return parts


## Kit status on one hero: root shackle, silence slash, Scatter's phase glow, the
## telegraph of a delayed cast (White Whale's lane, the Headsman's Axe line), a tether
## line (Poppet's thread, Ahab's hook pull), Huddle's swarm around its victim, and Tot's
## Absolute Rule and Borrowed Time rings.
func _render_kit(h: HeroState, p: Dictionary, at: Vector3) -> void:
	var sim := view.sim
	var now := Time.get_ticks_msec()
	p.root.visible = h.alive and h.is_rooted()
	p.root.position = at + Vector3(0, 0.15, 0)
	p.silence.visible = h.alive and sim.time < h.silence_until
	p.silence.position = at + Vector3(0, 2.15, 0)
	p.phase.visible = h.alive and sim.time < h.phase_until
	p.phase.position = at + Vector3(0, 0.7, 0)
	p.phase.scale = Vector3.ONE * (0.9 + 0.05 * sin(now / 50.0))
	# Telegraph: a long strip on the ground that fills in as the cast nears.
	p.tele.visible = h.alive and h.delayed != null
	if p.tele.visible:
		var length := h.delayed_reach
		var width := h.delayed.width * 2.0 if h.delayed.effect == &"white_whale" else maxf(0.5, h.delayed.width * 2.0)
		var mid := h.pos + h.delayed_dir * length * 0.5
		p.tele.position = MatchView.to_world(mid, 0.05)
		p.tele.rotation.y = atan2(-h.delayed_dir.x, h.delayed_dir.y)
		p.tele.scale = Vector3(width, 1.0, length)
		var left := clampf((h.delayed_at - sim.time) / maxf(0.05, h.delayed.delay), 0.0, 1.0)
		var tc := Color(0.45, 0.75, 1.0) if h.delayed.effect == &"white_whale" else Color(1.0, 0.3, 0.2)
		(p.tele.material_override as StandardMaterial3D).albedo_color = Color(tc, lerpf(0.55, 0.18, left))
	# Tether: thread from Poppet to her target, or the hook line while Ahab reels someone in.
	var other: SimEntity = null
	if h.thread_target != 0 and sim.time < h.thread_until:
		other = sim.get_entity(h.thread_target)
	elif h.forced_how == &"hook":
		other = sim.get_entity(h.forced_by)
	p.tether.visible = h.alive and other != null and other.alive
	if p.tether.visible:
		_place_line(p.tether, at + Vector3(0, 0.9, 0), view.unit_position(other.id) + Vector3(0, 0.9, 0), 0.05)
		(p.tether.material_override as StandardMaterial3D).albedo_color = Color("f6eee8") if h.thread_target != 0 else Color("c9d1d9")
	# Huddle's swarm sits on its victim.
	var victim: SimEntity = sim.get_entity(h.engulf_target) if h.engulf_target != 0 else null
	p.swarm.visible = h.alive and victim != null and victim.alive
	if p.swarm.visible:
		p.swarm.position = view.unit_position(victim.id) + Vector3(0, 0.8, 0)
		p.swarm.scale = Vector3.ONE * (1.0 + 0.08 * sin(now / 35.0))
	p.rule.visible = h.alive and h.rule_ability != null and sim.time < h.rule_end
	if p.rule.visible:
		p.rule.position = at + Vector3(0, 0.12, 0)
		var rr := h.rule_ability.radius * (0.9 + 0.1 * sin(now / 80.0))
		p.rule.scale = Vector3(rr, 0.04, rr)
	p.borrowed.visible = h.alive and sim.time < h.borrowed_until
	p.borrowed.position = at + Vector3(0, 0.16, 0)


## Latch Cloud on a hero: a big knot of yellow bugs circling them for as long as it
## lasts, and their Buzz count over their head ("BUZZ 3/5").
func _latch_swarm() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var bug := SphereMesh.new()
	bug.radius = 0.11
	bug.height = 0.22
	bug.radial_segments = 6
	bug.rings = 3
	for k in 16:
		var a := k * 2.39996
		var r := 0.75 + 0.25 * float(k % 3) / 2.0
		UnitFactory.part(root, bug, Color("ffd23a") if k % 4 != 0 else Color("2a2418"), Vector3(cos(a) * r, 0.4 + float(k % 5) * 0.28, sin(a) * r), Vector3.ZERO, true)
	var haze := SphereMesh.new()
	haze.radius = 1.0
	haze.height = 1.8
	UnitFactory.part(root, haze, Color(1.0, 0.82, 0.2, 0.18), Vector3(0, 0.9, 0), Vector3.ZERO, true)
	return root


func _render_latch(h: HeroState, p: Dictionary, at: Vector3) -> void:
	var sim := view.sim
	var on := h.alive and sim.time < h.latched_until
	var swarm: Node3D = p.latch
	swarm.visible = on
	if on:
		swarm.position = at
		swarm.rotation.y = Time.get_ticks_msec() / 160.0
		var left := h.latched_until - sim.time
		swarm.scale = Vector3.ONE * (0.85 + 0.15 * clampf(left, 0.0, 1.0))
	var label: Label3D = p.buzz
	label.visible = h.alive and (on or h.buzz > 0)
	if label.visible:
		var need := Kits.BUZZ_STACKS
		var src := sim.get_entity(h.buzz_from) as HeroState
		if src != null:
			need = Kits.buzz_need(src)
		label.text = "BUZZ %d/%d" % [h.buzz, need]
		label.position = at + Vector3(0, 3.0, 0)


## Missed Latch Clouds hanging in the air: a buzzing yellow puff, fading as it expires.
var _clouds := {}


func _render_clouds(sim: MatchSim) -> void:
	var live := {}
	for c: Dictionary in sim.clouds:
		live[c.id] = true
		if not _clouds.has(c.id):
			var node := _latch_swarm()
			node.scale = Vector3.ONE * 0.7
			_clouds[c.id] = node
		var n: Node3D = _clouds[c.id]
		n.position = MatchView.to_world(c.pos, 0.0)
		n.rotation.y = Time.get_ticks_msec() / 220.0
	for id: int in _clouds.keys():
		if not live.has(id):
			_clouds[id].queue_free()
			_clouds.erase(id)


## Traps: the owner's side sees them clearly (ghostly while arming); the other side
## always sees a faint chalk outline, so traps can be played around.
func _render_traps(sim: MatchSim) -> void:
	var me := sim.heroes[view.local_seat]
	var live := {}
	for t: Dictionary in sim.traps:
		live[t.id] = true
		if not _traps.has(t.id):
			var trap := Node3D.new()
			add_child(trap)
			UnitFactory.part(trap, UnitFactory.cylinder(0.45, 0.5, 0.08, 16), Color("6b6f78"), Vector3(0, 0.04, 0), Vector3.ZERO, true)
			for k in 6:
				var a := TAU * k / 6.0
				UnitFactory.part(trap, UnitFactory.box(Vector3(0.06, 0.22, 0.06)), Color("c9d1d9"), Vector3(cos(a) * 0.4, 0.15, sin(a) * 0.4), Vector3.ZERO, true)
			# Chalk outline: what the enemy always sees.
			var outline := TorusMesh.new()
			outline.inner_radius = 0.62
			outline.outer_radius = 0.7
			outline.rings = 32
			outline.ring_segments = 3
			var ring := UnitFactory.part(trap, outline, Color(1.0, 0.95, 0.9, 0.7), Vector3(0, 0.03, 0), Vector3.ZERO, true)
			ring.name = "Outline"
			_traps[t.id] = trap
		var node: Node3D = _traps[t.id]
		node.position = MatchView.to_world(t.pos, 0.0)
		var mine: bool = int(t.team) == view.local_seat
		node.visible = true
		node.scale = Vector3.ONE * (0.7 if sim.time < t.armed_at else 1.0)
		var faint := not mine and not (me.alive and me.pos.distance_to(t.pos) < 2.0)
		for part in node.get_children():
			var mi := part as MeshInstance3D
			if mi != null and mi.name != "Outline":
				mi.visible = not faint
	for id: int in _traps.keys():
		if not live.has(id):
			_traps[id].queue_free()
			_traps.erase(id)


func _line_part(color: Color) -> MeshInstance3D:
	var line := MeshInstance3D.new()
	line.mesh = UnitFactory.cylinder(1.0, 1.0, 1.0, 6)
	line.material_override = UnitFactory.material(color, true)
	add_child(line)
	return line


func _place_line(line: MeshInstance3D, from: Vector3, to: Vector3, width: float) -> void:
	var length := maxf(0.01, from.distance_to(to))
	line.position = (from + to) / 2.0
	var up := (to - from) / length
	if up.length() < 0.5:
		up = Vector3.UP
	line.basis = Basis(Quaternion(Vector3.UP, up)).scaled(Vector3(width, length, width))


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
