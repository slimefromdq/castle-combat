class_name UnitBars
extends Control
## Health bars over every unit, drawn in 2D so they stay crisp at any zoom.
## Locked structures get a grey bar; heroes show a windup tick under their bar.

var view: MatchView


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if view == null or view.sim == null:
		return
	var cam := view.camera_rig.camera
	for id: int in view.unit_nodes():
		var e: SimEntity = view.sim.get_entity(id)
		var node: Node3D = view.unit_nodes()[id]
		if e == null or not e.alive or not node.visible:
			continue
		var anchor := node.global_position + Vector3(0, float(node.get_meta("bar_height", 1.5)), 0)
		if cam.is_position_behind(anchor):
			continue
		var p := cam.unproject_position(anchor)
		var size := Vector2(36, 5)
		if e is HeroState:
			size = Vector2(70, 9)
		elif e is StructureState:
			size = Vector2(96, 10)
		var color := Palette.team_color(e.team == view.local_seat)
		if e is StructureState and not view.sim.is_exposed(e):
			color = Color(0.6, 0.62, 0.66)
		var r := Rect2(p - Vector2(size.x / 2.0, size.y), size)
		draw_rect(r.grow(1.5), Color(0, 0, 0, 0.7))
		# Your own minions you could deny get a white frame.
		if e is MinionState and e.team == view.local_seat and CombatSystem.can_deny(view.sim, view.sim.heroes[view.local_seat], e):
			draw_rect(r.grow(3.0), Color(1, 1, 1, 0.9), false, 2.0)
		draw_rect(Rect2(r.position, Vector2(size.x * e.hp / e.max_hp, size.y)), color)
		if e is HeroState and e.is_winding_up():
			draw_rect(Rect2(r.position + Vector2(0, size.y + 3), Vector2(size.x * e.windup_progress(), 4)), Color(1, 1, 1, 0.9))
	_draw_relay_pointer(cam)


## The Relay is globally visible: when it is off screen, a gold arrow on the edge of
## the lane area points to it (or to whoever carries it).
func _draw_relay_pointer(cam: Camera3D) -> void:
	var relay := view.sim.relay
	if relay.state == RelayController.State.DORMANT and not relay.warned:
		return
	var at := MatchView.to_world(relay.origin if relay.state == RelayController.State.DORMANT else relay.pos, 1.0)
	var carrier := relay.carrier(view.sim)
	if carrier != null:
		at = view.unit_position(carrier.id) + Vector3(0, 2.7, 0)
	var screen := get_viewport_rect().size
	var area := Rect2(Vector2(36, 300), Vector2(screen.x - 72, screen.y - 300 - 280))
	var p := cam.unproject_position(at)
	if not cam.is_position_behind(at) and area.has_point(p):
		return
	var centre := area.get_center()
	var dir := (p - centre).normalized()
	if cam.is_position_behind(at):
		dir = -dir
	# Walk from the centre to the edge of the area along dir.
	var half := area.size / 2.0
	var t := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	var tip := centre + dir * t
	var side := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([tip, tip - dir * 30.0 + side * 15.0, tip - dir * 30.0 - side * 15.0])
	draw_colored_polygon(pts, Palette.RELAY)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0, 0, 0, 0.7), 2.0)
