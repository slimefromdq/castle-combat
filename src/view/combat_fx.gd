class_name CombatFx
extends Node3D
## Cosmetic combat feedback driven by sim events. The damage already happened in the
## sim when "attack_fired" arrives; the tracer only shows it, so it can never miss.

const TRACER_TIME := 0.12
const PUFF_TIME := 0.22

var view: MatchView
var _tracers: Array = []
var _puffs: Array = []
var _texts: Array = []
var _tracer_mesh := SphereMesh.new()
var _puff_mesh := SphereMesh.new()


func _ready() -> void:
	_tracer_mesh.radius = 0.12
	_tracer_mesh.height = 0.24
	_tracer_mesh.radial_segments = 8
	_tracer_mesh.rings = 4
	_puff_mesh.radius = 0.5
	_puff_mesh.height = 1.0
	_puff_mesh.radial_segments = 12
	_puff_mesh.rings = 6


func on_sim_event(type: StringName, data: Dictionary) -> void:
	if type == &"gold_awarded" and data.team == view.local_seat:
		_spawn_gold_text("+%d" % int(data.amount), Color("f5d76e"))
		return
	if type == &"minion_denied" and data.team == view.local_seat:
		_spawn_gold_text("Denied!", Color(0.85, 0.92, 1.0))
		return
	if type == &"storm_strike":
		var tgt: SimEntity = view.sim.get_entity(data.target)
		if tgt != null:
			var at := view.unit_position(tgt.id)
			var bolt := UnitFactory.part(self, UnitFactory.cylinder(0.12, 0.3, 9.0, 8), Color("b8e0ff"), at + Vector3(0, 4.5, 0), Vector3.ZERO, true)
			_puffs.append({"node": bolt, "t": 0.0, "size": 1.0, "bolt": true})
			_spawn_puff(at + Vector3(0, 0.6, 0), true)
		return
	if type == &"item_proc":
		var words := {&"aegis_mirror": "Blocked!", &"spark_band": "Spark!", &"reapers_rhythm": "Frenzy!", &"overcharge_gem": "Overcharge!"}
		if words.has(data.item):
			var who: SimEntity = view.sim.get_entity(data.target if data.item == &"overcharge_gem" else data.hero)
			if who != null:
				_spawn_text_at(words[data.item], Color("c9a7ff"), view.unit_position(who.id) + Vector3(-0.4, 2.6, 0))
		return
	if type == &"ability_hit":
		var src: SimEntity = view.sim.get_entity(data.hero)
		var tgt: SimEntity = view.sim.get_entity(data.target)
		if src != null and tgt != null:
			if data.ability == &"power_shot":
				var from := view.unit_position(src.id) + Vector3(0, 0.9, 0)
				var dot := UnitFactory.part(self, _tracer_mesh, Color("ffe14d"), from, Vector3.ZERO, true)
				dot.scale = Vector3.ONE * 2.0
				_tracers.append({"node": dot, "from": from, "to": view.unit_position(tgt.id), "target": tgt.id, "t": 0.0, "big": true})
			else:
				_spawn_puff(view.unit_position(tgt.id) + Vector3(0, 0.6, 0), tgt is HeroState)
		return
	if type != &"attack_fired":
		return
	var attacker: SimEntity = view.sim.get_entity(data.attacker)
	var target: SimEntity = view.sim.get_entity(data.target)
	if attacker == null or target == null:
		return
	var from := MatchView.to_world(data.from, 0.9 if attacker is HeroState else (2.0 if attacker is StructureState else 0.5))
	var color := Palette.team_color(attacker.team == view.local_seat).lightened(0.35)
	var dot := UnitFactory.part(self, _tracer_mesh, color, from, Vector3.ZERO, true)
	var to := view.unit_position(target.id) + Vector3(0, 0.6, 0)
	_tracers.append({"node": dot, "from": from, "to": to, "target": target.id, "t": 0.0, "big": attacker is HeroState or target is HeroState})


func _process(delta: float) -> void:
	for i in range(_tracers.size() - 1, -1, -1):
		var tr: Dictionary = _tracers[i]
		tr.t += delta
		# Follow the target while it exists; a minion that just died keeps its last spot.
		if view.unit_nodes().has(tr.target):
			tr.to = view.unit_position(tr.target) + Vector3(0, 0.6, 0)
		var target_pos: Vector3 = tr.to
		var k: float = clampf(tr.t / TRACER_TIME, 0.0, 1.0)
		tr.node.position = (tr.from as Vector3).lerp(target_pos, k)
		if k >= 1.0:
			tr.node.queue_free()
			_tracers.remove_at(i)
			_spawn_puff(target_pos, tr.big)
	for i in range(_texts.size() - 1, -1, -1):
		var g: Dictionary = _texts[i]
		g.t += delta
		if g.t >= 0.9:
			g.node.queue_free()
			_texts.remove_at(i)
			continue
		g.node.position = (g.from as Vector3) + Vector3(0, g.t * 1.4, 0)
		g.node.modulate.a = 1.0 - g.t / 0.9
	for i in range(_puffs.size() - 1, -1, -1):
		var p: Dictionary = _puffs[i]
		p.t += delta
		var k: float = p.t / PUFF_TIME
		if k >= 1.0:
			p.node.queue_free()
			_puffs.remove_at(i)
			continue
		if p.has("bolt"):
			p.node.scale = Vector3(1.0 - k, 1.0, 1.0 - k)
		else:
			p.node.scale = Vector3.ONE * lerpf(0.4, p.size, k)
		var mat: StandardMaterial3D = p.node.material_override
		mat.albedo_color.a = 0.9 * (1.0 - k)


## "+20" in gold, rising from your hero.
func _spawn_gold_text(text: String, color: Color) -> void:
	_spawn_text_at(text, color, view.unit_position(view.sim.heroes[view.local_seat].id) + Vector3(0.4, 2.3, 0))


func _spawn_text_at(text: String, color: Color, start: Vector3) -> void:
	var l := UnitFactory.label(self, text, 0.0, 44)
	l.modulate = color
	l.position = start
	_texts.append({"node": l, "t": 0.0, "from": start})


## The unmistakable "it hit" flash: a quick white burst on the target.
func _spawn_puff(at: Vector3, big: bool) -> void:
	var puff := UnitFactory.part(self, _puff_mesh, Color(1, 1, 1, 0.9), at, Vector3.ZERO, true)
	_puffs.append({"node": puff, "t": 0.0, "size": 1.3 if big else 0.8})
