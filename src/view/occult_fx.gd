class_name OccultFx
extends Node3D
## Visuals for the occult heroes, read from the sim like the rest of the view.
##   Serpent: a Venom count and countdown ring on the poisoned hero, a green burst when
##   it pops, shed skins left behind, the snake pit and its vipers.
##   Fermata: floating tubas and violins (the violin's circle on the ground), the brass
##   cone, Strings pulses, final notes and Grand Finale waves.
##   KOSMONAUT: the drone, its zap ring, the tether while it is parked, zaps, pulses
##   and the Re-entry telegraph.

const VENOM := Color("7be35a")
const BRASS := Color("e8b84a")
const VIOLIN := Color("a0522d")
const STRINGS := Color(0.75, 0.6, 1.0)

var view: MatchView
var _rings: Array = []
var _fades: Array = []
## Per hero id: venom label and ring, satellite pieces, finale drums.
var _hero_parts: Dictionary = {}
var _vipers: Dictionary = {}
var _instruments: Dictionary = {}
var _pits: Dictionary = {}
var _ring_mesh := TorusMesh.new()


func _ready() -> void:
	_ring_mesh.inner_radius = 0.92
	_ring_mesh.outer_radius = 1.0
	_ring_mesh.rings = 48
	_ring_mesh.ring_segments = 4


func on_sim_event(type: StringName, data: Dictionary) -> void:
	match type:
		&"venom_pop":
			_ring(data.pos, 1.8, VENOM, 0.45)
			_ring(data.pos, 1.0, Color(1, 1, 1), 0.3)
		&"venom_fizzled":
			_ring(data.pos, 1.0, Color(0.7, 0.75, 0.7), 0.3)
		&"skin_shed":
			var skin := Node3D.new()
			add_child(skin)
			skin.position = MatchView.to_world(data.pos, 0.0)
			skin.rotation.y = atan2(-data.dir.x, data.dir.y)
			UnitFactory.part(skin, UnitFactory.cylinder(0.32, 0.4, 0.9, 10), Color(0.75, 0.9, 0.6, 0.55), Vector3(0, 0.45, 0), Vector3.ZERO, true)
			_fades.append({"node": skin, "t": 0.0, "life": 1.4})
		&"snake_pit":
			var nest := Node3D.new()
			add_child(nest)
			nest.position = MatchView.to_world(data.pos, 0.0)
			UnitFactory.part(nest, UnitFactory.cylinder(0.9, 1.0, 0.08, 20), Color("4a3a24"), Vector3(0, 0.04, 0), Vector3.ZERO, true)
			UnitFactory.part(nest, _ring_mesh, VENOM, Vector3(0, 0.06, 0), Vector3.ZERO, true).scale = Vector3(1.05, 0.04, 1.05)
			_pits[nest] = data.until
		&"brass_blast":
			_cone(data.pos, data.dir, data.length, data.angle)
		&"strings_pulse":
			_ring(data.pos, data.radius, STRINGS, 0.4)
		&"final_note":
			_ring(data.pos, data.radius, Color("fff1b8"), 0.4)
			_ring(data.pos, data.radius * 0.5, BRASS, 0.3)
		&"finale_wave":
			_ring(data.pos, data.radius, BRASS, 0.45)
			_ring(data.pos, data.radius * 0.6, Color(1, 1, 1), 0.35)
		&"drone_launched":
			_ring(data.pos, 1.0, Color("9fd3ff"), 0.3)
		&"drone_pulse":
			_ring(data.pos, data.radius, Color("9fd3ff"), 0.45)
			_ring(data.pos, data.radius * 0.5, Color(1, 1, 1), 0.3)
		&"drone_zap":
			var zapped: SimEntity = view.sim.get_entity(data.target)
			if zapped != null:
				_zap_line(MatchView.to_world(data.from, 1.6), view.unit_position(zapped.id) + Vector3(0, 0.8, 0))
		&"reentry_landed":
			_ring(data.pos, data.radius + 0.6, Color(1.0, 0.55, 0.2), 0.55)
			_ring(data.pos, data.radius, Color(1, 1, 1), 0.4)


func render(alpha: float) -> void:
	var sim := view.sim
	for h in sim.heroes:
		var p := _parts_for(h)
		var hidden := h.team != view.local_seat and sim.is_hidden(h)
		_render_venom(h, p, hidden)
		_render_satellite(h, p, alpha)
		_render_finale(h, p, hidden)
	_render_vipers(sim)
	_render_instruments(sim)
	_update_pits(sim)
	_update_rings()


func _parts_for(h: HeroState) -> Dictionary:
	if _hero_parts.has(h.id):
		return _hero_parts[h.id]
	var team_c := Palette.team_color(h.team == view.local_seat)
	var p := {}
	p.venom_label = UnitFactory.label(self, "", 0.0, 44)
	p.venom_label.modulate = VENOM
	p.venom_label.outline_modulate = Color(0.05, 0.15, 0.05)
	p.venom_ring = UnitFactory.part(self, _ring_mesh, VENOM, Vector3.ZERO, Vector3.ZERO, true)
	# KOSMONAUT's drone: a silver ball with two team-coloured panels.
	var sat := Node3D.new()
	add_child(sat)
	var ball := SphereMesh.new()
	ball.radius = 0.32
	ball.height = 0.64
	UnitFactory.part(sat, ball, Color("dfe4ea"), Vector3.ZERO, Vector3.ZERO, true)
	for side: float in [-1.0, 1.0]:
		UnitFactory.part(sat, UnitFactory.box(Vector3(0.5, 0.04, 0.28)), team_c, Vector3(side * 0.55, 0, 0), Vector3.ZERO, true)
	p.sat = sat
	# Its zap reach, as a faint ring on the ground under it.
	p.orbit = UnitFactory.part(self, _ring_mesh, Color(team_c.lightened(0.3), 0.45), Vector3.ZERO, Vector3.ZERO, true)
	p.shadow = UnitFactory.part(self, UnitFactory.cylinder(0.35, 0.35, 0.02, 16), Color(0, 0, 0, 0.3), Vector3.ZERO, Vector3.ZERO, true)
	var tether := MeshInstance3D.new()
	tether.mesh = UnitFactory.cylinder(1.0, 1.0, 1.0, 6)
	tether.material_override = UnitFactory.material(Color(team_c.lightened(0.4), 0.5), true)
	add_child(tether)
	p.tether = tether
	p.tele = UnitFactory.part(self, UnitFactory.cylinder(1.0, 1.0, 0.02, 32), Color(1.0, 0.4, 0.2, 0.25), Vector3.ZERO, Vector3.ZERO, true)
	p.tele_edge = UnitFactory.part(self, _ring_mesh, Color(1.0, 0.4, 0.2, 0.9), Vector3.ZERO, Vector3.ZERO, true)
	# Grand Finale: a ring of drums and horns that circles Fermata while it plays.
	var finale := Node3D.new()
	add_child(finale)
	for k in 6:
		var a := TAU * k / 6.0
		var at := Vector3(cos(a) * 1.5, 0.9, sin(a) * 1.5)
		if k % 2 == 0:
			UnitFactory.part(finale, UnitFactory.cylinder(0.26, 0.26, 0.3, 14), Color("d0313d"), at, Vector3.ZERO, true)
		else:
			UnitFactory.part(finale, UnitFactory.cylinder(0.05, 0.22, 0.5, 12), BRASS, at, Vector3(90, rad_to_deg(-a), 0), true)
	p.finale = finale
	_hero_parts[h.id] = p
	return p


## Venom: "VENOM n" over the poisoned hero and a green ring that closes in as the pop nears.
func _render_venom(h: HeroState, p: Dictionary, hidden: bool) -> void:
	var sim := view.sim
	var on := h.alive and h.venom > 0 and not hidden
	var label: Label3D = p.venom_label
	var ring: MeshInstance3D = p.venom_ring
	label.visible = on
	ring.visible = on
	if not on:
		return
	var at := view.unit_position(h.id)
	label.text = "VENOM %d" % h.venom
	label.position = at + Vector3(0, 3.35, 0)
	var left := clampf((h.venom_pops_at - sim.time) / OccultKits.VENOM_TIME, 0.0, 1.0)
	var r := lerpf(0.55, 1.4, left)
	ring.position = at + Vector3(0, 0.1, 0)
	ring.scale = Vector3(r, 0.05, r)


func _render_satellite(h: HeroState, p: Dictionary, alpha: float) -> void:
	var sim := view.sim
	var mine := h.data.hero_trait == &"drone" and h.alive
	var sat: Node3D = p.sat
	var ring: MeshInstance3D = p.orbit
	var shadow: MeshInstance3D = p.shadow
	var tether: MeshInstance3D = p.tether
	var falling := h.alive and h.reentry != null
	sat.visible = mine
	shadow.visible = mine
	tether.visible = mine and h.drone_out and not falling
	(p.tele as Node3D).visible = falling
	(p.tele_edge as Node3D).visible = falling
	if falling:
		var radius := OccultKits.reentry_radius(h, h.reentry)
		var k := 1.0 - clampf((h.reentry_at - sim.time) / maxf(0.05, h.reentry.delay), 0.0, 1.0)
		p.tele.position = MatchView.to_world(h.reentry_pos, 0.05)
		p.tele.scale = Vector3(radius * k, 1.0, radius * k)
		p.tele_edge.position = MatchView.to_world(h.reentry_pos, 0.08)
		p.tele_edge.scale = Vector3(radius, 0.04, radius)
	if not mine:
		ring.visible = false
		return
	var at := h.drone_prev.lerp(h.drone_pos, alpha)
	var flying := h.drone_out and h.drone_pos.distance_to(h.drone_spot) > 0.05 or h.drone_back
	# The zap ring shows only while it hovers (it doesn't zap in flight).
	ring.visible = not falling and not flying
	var r := OccultKits.zap_range(h)
	ring.position = MatchView.to_world(at, 0.07)
	ring.scale = Vector3(r, 0.02, r)
	shadow.position = MatchView.to_world(at, 0.04)
	if falling:
		var k := 1.0 - clampf((h.reentry_at - sim.time) / maxf(0.05, h.reentry.delay), 0.0, 1.0)
		sat.position = MatchView.to_world(h.reentry_pos, lerpf(6.0, 0.4, k * k))
	else:
		# A gentle hover bob; it never circles.
		sat.position = MatchView.to_world(at, 1.6 + 0.08 * sin(Time.get_ticks_msec() / 300.0))
	sat.rotation.y = 0.0
	if tether.visible:
		var from := view.unit_position(h.id) + Vector3(0, 0.9, 0)
		var to := sat.position
		var length := maxf(0.01, from.distance_to(to))
		tether.position = (from + to) / 2.0
		var up := (to - from) / length
		tether.basis = Basis(Quaternion(Vector3.UP, up)).scaled(Vector3(0.03, length, 0.03))


func _render_finale(h: HeroState, p: Dictionary, hidden: bool) -> void:
	var finale: Node3D = p.finale
	finale.visible = h.alive and h.finale != null and not hidden
	if finale.visible:
		finale.position = view.unit_position(h.id)
		finale.rotation.y = Time.get_ticks_msec() / 250.0


func _render_vipers(sim: MatchSim) -> void:
	var live := {}
	for v: Dictionary in sim.vipers:
		live[v.id] = true
		if not _vipers.has(v.id):
			var snake := Node3D.new()
			add_child(snake)
			var seg := SphereMesh.new()
			seg.radius = 0.13
			seg.height = 0.22
			seg.radial_segments = 8
			seg.rings = 4
			for k in 4:
				UnitFactory.part(snake, seg, VENOM if k > 0 else Color("3f9a34"), Vector3(0.08 * sin(k * 1.4), 0.12, 0.2 * k), Vector3.ZERO, true)
			var egg := SphereMesh.new()
			egg.radius = 0.16
			egg.height = 0.26
			var e := UnitFactory.part(snake, egg, Color("e9e4cf"), Vector3(0, 0.13, 0), Vector3.ZERO, true)
			e.name = "Egg"
			_vipers[v.id] = snake
		var n: Node3D = _vipers[v.id]
		var hatched: bool = sim.time >= v.hatch_at
		var to: Vector2 = view.sim.heroes[1 - int(v.team)].pos - v.pos
		n.position = MatchView.to_world(v.pos, 0.0)
		if to.length() > 0.01:
			n.rotation.y = atan2(-to.x, to.y) + PI
		for c in n.get_children():
			(c as Node3D).visible = (c.name == "Egg") != hatched
	for id: int in _vipers.keys():
		if not live.has(id):
			_vipers[id].queue_free()
			_vipers.erase(id)


func _render_instruments(sim: MatchSim) -> void:
	var live := {}
	var t := Time.get_ticks_msec() / 1000.0
	for inst: Dictionary in sim.instruments:
		live[inst.id] = true
		if not _instruments.has(inst.id):
			_instruments[inst.id] = _build_instrument(inst)
		var n: Node3D = _instruments[inst.id]
		n.position = MatchView.to_world(inst.pos, 0.0)
		var body: Node3D = n.get_node("Body")
		body.position.y = 1.2 + 0.12 * sin(t * 3.0 + float(inst.id))
		var left: float = inst.until - sim.time
		body.scale = Vector3.ONE * clampf(left * 3.0, 0.3, 1.0)
	for id: int in _instruments.keys():
		if not live.has(id):
			_instruments[id].queue_free()
			_instruments.erase(id)


func _build_instrument(inst: Dictionary) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var dir: Vector2 = inst.dir
	body.rotation.y = atan2(-dir.x, dir.y)
	if inst.kind == &"brass":
		# A gold tuba: a coiled body and a wide bell pointing where it blasted.
		UnitFactory.part(body, UnitFactory.cylinder(0.3, 0.3, 0.5, 16), BRASS, Vector3.ZERO, Vector3(0, 0, 90), true)
		UnitFactory.part(body, UnitFactory.cylinder(0.55, 0.14, 0.6, 18), BRASS.lightened(0.2), Vector3(0, 0.25, -0.45), Vector3(-90, 0, 0), true)
	else:
		# A violin over its circle of sound.
		var a: AbilityData = inst.ability
		UnitFactory.part(body, UnitFactory.box(Vector3(0.4, 0.12, 0.6)), VIOLIN, Vector3.ZERO, Vector3(0, 0, 25), true)
		UnitFactory.part(body, UnitFactory.box(Vector3(0.08, 0.06, 0.55)), Color("2b2b31"), Vector3(0, 0.05, -0.5), Vector3(0, 0, 25), true)
		UnitFactory.part(body, UnitFactory.box(Vector3(0.03, 0.03, 0.9)), Color("e9e4cf"), Vector3(0.25, 0.25, 0), Vector3(0, 30, 0), true)
		var circle := UnitFactory.part(root, _ring_mesh, Color(STRINGS, 0.8), Vector3(0, 0.06, 0), Vector3.ZERO, true)
		circle.scale = Vector3(a.radius, 0.03, a.radius)
		UnitFactory.part(root, UnitFactory.cylinder(a.radius, a.radius, 0.02, 32), Color(STRINGS, 0.14), Vector3(0, 0.04, 0), Vector3.ZERO, true)
	return root


func _update_pits(sim: MatchSim) -> void:
	for nest: Node3D in _pits.keys():
		if sim.time >= float(_pits[nest]):
			nest.queue_free()
			_pits.erase(nest)


## The brass cone: a flat golden fan that fades out.
func _cone(p: Vector2, dir: Vector2, length: float, half_angle_deg: float) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 8
	var half := deg_to_rad(half_angle_deg)
	var base := atan2(dir.y, dir.x)
	for i in steps:
		var a0 := base - half + 2.0 * half * i / steps
		var a1 := base - half + 2.0 * half * (i + 1) / steps
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_add_vertex(MatchView.to_world(Vector2(cos(a0), sin(a0)) * length))
		mesh.surface_add_vertex(MatchView.to_world(Vector2(cos(a1), sin(a1)) * length))
	mesh.surface_end()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var mat := UnitFactory.material(Color(BRASS, 0.45), true)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat
	node.position = MatchView.to_world(p, 0.08)
	add_child(node)
	_fades.append({"node": node, "t": 0.0, "life": 0.35})


## A quick electric line from the drone to what it zapped.
func _zap_line(from: Vector3, to: Vector3) -> void:
	var line := MeshInstance3D.new()
	line.mesh = UnitFactory.cylinder(1.0, 1.0, 1.0, 6)
	line.material_override = UnitFactory.material(Color(0.7, 0.9, 1.0, 0.9), true)
	add_child(line)
	var length := maxf(0.01, from.distance_to(to))
	line.position = (from + to) / 2.0
	line.basis = Basis(Quaternion(Vector3.UP, (to - from) / length)).scaled(Vector3(0.06, length, 0.06))
	_fades.append({"node": line, "t": 0.0, "life": 0.18})


func _ring(p: Vector2, radius: float, color: Color, life := 0.35) -> void:
	var node := UnitFactory.part(self, _ring_mesh, color, MatchView.to_world(p, 0.1), Vector3.ZERO, true)
	_rings.append({"node": node, "t": 0.0, "r": radius, "life": life})


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
		var r: float = lerpf(0.3, g.r, minf(1.0, k * 1.6))
		g.node.scale = Vector3(r, 0.05, r)
		(g.node.material_override as StandardMaterial3D).albedo_color.a = 1.0 - k
	for i in range(_fades.size() - 1, -1, -1):
		var f: Dictionary = _fades[i]
		f.t += delta
		var k: float = f.t / f.life
		if k >= 1.0:
			f.node.queue_free()
			_fades.remove_at(i)
			continue
		for c in (f.node as Node).get_children():
			var mi := c as MeshInstance3D
			if mi != null:
				(mi.material_override as StandardMaterial3D).albedo_color.a *= 0.97
		var own := f.node as MeshInstance3D
		if own != null:
			(own.material_override as StandardMaterial3D).albedo_color.a = 0.45 * (1.0 - k)


## Seat swaps rebuild team colours.
func reset() -> void:
	for p: Dictionary in _hero_parts.values():
		for n: Node in p.values():
			n.queue_free()
	_hero_parts.clear()
