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
		draw_rect(Rect2(r.position, Vector2(size.x * e.hp / e.max_hp, size.y)), color)
		if e is HeroState and e.is_winding_up():
			draw_rect(Rect2(r.position + Vector2(0, size.y + 3), Vector2(size.x * e.windup_progress(), 4)), Color(1, 1, 1, 0.9))
