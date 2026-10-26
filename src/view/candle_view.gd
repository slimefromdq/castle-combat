class_name CandleView
extends Node3D
## Draws the votive candles from PickupController: a small chalk-ringed shrine with a
## candle that is lit (flame, glow, take ring) or snuffed (a thin ring that fills up as
## it nears relighting). Lit candles off screen get an arrow at the screen edge.
## Read-only, like the rest of the view.

const FLAME := Color("ffb347")
const WAX := Color("f3ead8")
const CHALK := Color(0.95, 0.9, 1.0, 0.55)

var view: MatchView
var _spots: Array[Dictionary] = []
var _arrows: CandleArrows
var _popups: Array = []


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	_arrows = CandleArrows.new()
	_arrows.view = view
	_arrows.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_arrows)
	view.sim.sim_event.connect(_on_sim_event)
	for c in view.sim.pickups.candles:
		_spots.append(_build_spot(c.pos))


func _build_spot(p: Vector2) -> Dictionary:
	var root := Node3D.new()
	root.position = MatchView.to_world(p)
	add_child(root)
	var r := view.sim.config.candle_radius
	# Chalk ritual circle and a low stone plinth.
	var circle := TorusMesh.new()
	circle.inner_radius = r - 0.06
	circle.outer_radius = r
	circle.rings = 40
	circle.ring_segments = 3
	UnitFactory.part(root, circle, CHALK, Vector3(0, 0.02, 0), Vector3.ZERO, true)
	for k in 5:  # Pentagram points as small ticks on the ring.
		var a := TAU * k / 5.0
		UnitFactory.part(root, UnitFactory.box(Vector3(0.08, 0.02, 0.3)), CHALK, Vector3(cos(a) * (r - 0.2), 0.02, sin(a) * (r - 0.2)), Vector3(0, -rad_to_deg(a) + 90.0, 0), true)
	UnitFactory.part(root, UnitFactory.cylinder(0.32, 0.38, 0.16, 6), Color("7c6f86"), Vector3(0, 0.08, 0))
	var wax := UnitFactory.part(root, UnitFactory.cylinder(0.11, 0.12, 0.5, 10), WAX, Vector3(0, 0.41, 0))
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.11
	flame_mesh.height = 0.34
	var flame := UnitFactory.part(root, flame_mesh, FLAME, Vector3(0, 0.78, 0), Vector3.ZERO, true)
	var halo := UnitFactory.part(root, UnitFactory.cylinder(r * 0.85, r * 0.85, 0.02, 32), Color(FLAME, 0.22), Vector3(0, 0.03, 0), Vector3.ZERO, true)
	var fill := UnitFactory.part(root, UnitFactory.cylinder(1.0, 1.0, 0.02, 32), Color(FLAME, 0.5), Vector3(0, 0.04, 0), Vector3.ZERO, true)
	var timer := TorusMesh.new()
	timer.inner_radius = 0.42
	timer.outer_radius = 0.5
	timer.rings = 32
	timer.ring_segments = 3
	var wait := UnitFactory.part(root, timer, Color(1, 1, 1, 0.4), Vector3(0, 0.05, 0), Vector3.ZERO, true)
	return {"root": root, "wax": wax, "flame": flame, "halo": halo, "fill": fill, "wait": wait}


func render() -> void:
	var sim := view.sim
	var t := Time.get_ticks_msec() / 1000.0
	for i in _spots.size():
		var c: PickupController.Candle = sim.pickups.candles[i]
		var s: Dictionary = _spots[i]
		var flame: MeshInstance3D = s.flame
		var halo: MeshInstance3D = s.halo
		var fill: MeshInstance3D = s.fill
		var wait: MeshInstance3D = s.wait
		flame.visible = c.lit
		halo.visible = c.lit
		if c.lit:
			var flicker := 1.0 + 0.12 * sin(t * 13.0 + i) + 0.06 * sin(t * 29.0 + i * 2.0)
			flame.scale = Vector3(1.0, flicker, 1.0)
			(halo.material_override as StandardMaterial3D).albedo_color.a = 0.18 + 0.08 * sin(t * 4.0 + i)
		var progress := maxf(c.progress[0], c.progress[1]) / sim.config.candle_take_time
		fill.visible = c.lit and progress > 0.0
		var fr := sim.config.candle_radius * clampf(progress, 0.0, 1.0)
		fill.scale = Vector3(fr, 1, fr)
		# Snuffed: a ring that grows from nothing to full size as it nears relighting.
		var left := c.lit_at - sim.time
		wait.visible = not c.lit and left <= sim.config.candle_respawn_time
		if wait.visible:
			var k := 1.0 - clampf(left / sim.config.candle_respawn_time, 0.0, 1.0)
			var size := lerpf(0.3, 1.6, k)
			wait.scale = Vector3(size, 1, size)
			(wait.material_override as StandardMaterial3D).albedo_color.a = 0.2 + 0.5 * k
	_update_popups()
	_arrows.queue_redraw()


func _on_sim_event(type: StringName, data: Dictionary) -> void:
	if type != &"candle_taken":
		return
	var mine: bool = data.team == view.local_seat
	var text := "+%d XP" % int(view.sim.config.candle_xp) if mine else "Candle taken"
	var label := UnitFactory.label(self, text, 1.6, 44)
	label.position = MatchView.to_world(data.pos, 1.6)
	label.modulate = Color("ffd27a") if mine else Color(1, 1, 1, 0.8)
	_popups.append({"node": label, "t": 0.0})


func _update_popups() -> void:
	var delta := get_process_delta_time()
	for i in range(_popups.size() - 1, -1, -1):
		var p: Dictionary = _popups[i]
		p.t += delta
		var node: Label3D = p.node
		if p.t >= 1.2:
			node.queue_free()
			_popups.remove_at(i)
			continue
		node.position.y += delta * 1.2
		node.modulate.a = 1.0 - p.t / 1.2


## Screen-edge arrows toward lit candles that are off screen.
class CandleArrows extends Control:
	var view: MatchView

	func _draw() -> void:
		if view == null or view.sim == null:
			return
		var cam := view.camera_rig.camera
		var size := get_viewport_rect().size
		var top := Hud.TOP_BAND + 14.0
		var bottom := size.y - Hud.BOTTOM_BAND - 14.0
		var box := Rect2(Vector2(14, top), Vector2(size.x - 28, bottom - top))
		var centre := box.get_center()
		for c in view.sim.pickups.lit_candles():
			var world := MatchView.to_world(c.pos, 0.6)
			if cam.is_position_behind(world):
				continue
			var sp := cam.unproject_position(world)
			if box.has_point(sp):
				continue
			var dir := (sp - centre).normalized()
			# Walk from the centre toward the candle until we hit the box edge.
			var tx := (box.size.x / 2.0) / maxf(absf(dir.x), 0.0001)
			var ty := (box.size.y / 2.0) / maxf(absf(dir.y), 0.0001)
			var at := centre + dir * minf(tx, ty)
			var side := Vector2(-dir.y, dir.x)
			var tip := at
			var pts := PackedVector2Array([tip, tip - dir * 22.0 + side * 11.0, tip - dir * 22.0 - side * 11.0])
			draw_colored_polygon(pts, Color(FLAME, 0.9))
			draw_circle(tip - dir * 32.0, 6.0, Color(FLAME, 0.9))
