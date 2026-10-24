class_name CombatFx
extends Node3D
## Cosmetic combat feedback driven by sim events. The damage already happened in the
## sim when "attack_fired" arrives; the tracer only shows it, so it can never miss.

const TRACER_TIME := 0.12
const PUFF_TIME := 0.22

var view: MatchView
var _tracers: Array = []
var _puffs: Array = []
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
	for i in range(_puffs.size() - 1, -1, -1):
		var p: Dictionary = _puffs[i]
		p.t += delta
		var k: float = p.t / PUFF_TIME
		if k >= 1.0:
			p.node.queue_free()
			_puffs.remove_at(i)
			continue
		p.node.scale = Vector3.ONE * lerpf(0.4, p.size, k)
		var mat: StandardMaterial3D = p.node.material_override
		mat.albedo_color.a = 0.9 * (1.0 - k)


## The unmistakable "it hit" flash: a quick white burst on the target.
func _spawn_puff(at: Vector3, big: bool) -> void:
	var puff := UnitFactory.part(self, _puff_mesh, Color(1, 1, 1, 0.9), at, Vector3.ZERO, true)
	_puffs.append({"node": puff, "t": 0.0, "size": 1.3 if big else 0.8})
