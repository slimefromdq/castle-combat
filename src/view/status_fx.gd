class_name StatusFx
extends Node3D
## Ability visuals that follow hero state: shield bubble, stun halo, slow and
## Flurry rings, Wounds and Frenzy rings (items), and the Barrage target zone. Plus one-shot rings for area casts.

var view: MatchView
## Per hero id: {"shield", "stun", "slow", "flurry", "zone"} nodes.
var _parts: Dictionary = {}
var _rings: Array = []
var _ring_mesh := TorusMesh.new()


func _ready() -> void:
	_ring_mesh.inner_radius = 0.92
	_ring_mesh.outer_radius = 1.0
	_ring_mesh.rings = 48
	_ring_mesh.ring_segments = 4


func on_sim_event(type: StringName, data: Dictionary) -> void:
	match type:
		&"ability_cast":
			if data.has("radius") and not data.has("point"):
				_spawn_ring(data.pos, data.radius, Palette.team_color(data.team == view.local_seat).lightened(0.4))
		&"barrage_pulse":
			var h: SimEntity = view.sim.get_entity(data.hero)
			_spawn_ring(data.point, data.radius, Palette.team_color(h != null and h.team == view.local_seat).lightened(0.2))


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
		p.flurry.visible = h.alive and sim.time < h.flurry_until
		p.flurry.position = at + Vector3(0, 0.1, 0)
		p.flurry.scale = Vector3.ONE * (1.0 + 0.08 * sin(Time.get_ticks_msec() / 60.0))
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
	_update_rings()


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
		"flurry": UnitFactory.part(self, _ring_mesh, Color(1.0, 0.6, 0.2, 0.8), Vector3.ZERO, Vector3.ZERO, true),
		"zone": UnitFactory.part(self, _ring_mesh, Color(team_c.lightened(0.2), 0.9), Vector3.ZERO, Vector3.ZERO, true),
		"wounds": UnitFactory.part(self, _ring_mesh, Color(0.55, 0.05, 0.1, 0.9), Vector3.ZERO, Vector3.ZERO, true),
		"frenzy": UnitFactory.part(self, _ring_mesh, Color(1.0, 0.2, 0.25, 0.9), Vector3.ZERO, Vector3.ZERO, true),
	}
	parts.wounds.scale = Vector3(1.05, 0.03, 1.05)
	parts.shield.scale = Vector3(0.95, 0.95, 0.95)
	parts.stun.scale = Vector3(0.45, 0.05, 0.45)
	parts.slow.scale = Vector3(0.9, 0.03, 0.9)
	parts.flurry.scale = Vector3(0.75, 0.03, 0.75)
	_parts[h.id] = parts
	return parts


## A ring that grows to `radius` and fades: shows the area an ability just hit.
func _spawn_ring(p: Vector2, radius: float, color: Color) -> void:
	var node := UnitFactory.part(self, _ring_mesh, color, MatchView.to_world(p, 0.1), Vector3.ZERO, true)
	_rings.append({"node": node, "t": 0.0, "r": radius})


func _update_rings() -> void:
	var delta := get_process_delta_time()
	for i in range(_rings.size() - 1, -1, -1):
		var g: Dictionary = _rings[i]
		g.t += delta
		var k: float = g.t / 0.35
		if k >= 1.0:
			g.node.queue_free()
			_rings.remove_at(i)
			continue
		var r: float = lerpf(0.3, g.r, k)
		g.node.scale = Vector3(r, 0.04, r)
		(g.node.material_override as StandardMaterial3D).albedo_color.a = 1.0 - k


## Seat swaps rebuild team colors.
func reset() -> void:
	for id in _parts:
		for n: Node3D in _parts[id].values():
			n.queue_free()
	_parts.clear()
