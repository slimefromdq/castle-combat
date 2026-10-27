class_name DiamondView
extends Node3D
## Draws the things on the diamond that aren't units: coins and sparks (PickupController),
## honey fruit bushes (Fruits), the Tarot altar and its empty spot (TarotAltar), and the
## chalk ring where each Pwee lives (NeutralCamps). The altar gets a screen-edge arrow
## while it's off screen. Read-only, like the rest of the view.

const COIN := Color("ffcf3f")
const SPARK := Color("8fe9ff")
const HONEY := Color("ff9f1c")
const ALTAR := Color("b48cff")
const CHALK := Color(0.95, 0.9, 1.0, 0.5)

var view: MatchView
var _pickups: Array[Dictionary] = []
var _fruits: Array[Dictionary] = []
var _altars: Array[Dictionary] = []
var _arrows: AltarArrow
var _popups: Array = []


func _ready() -> void:
	var sim := view.sim
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	_arrows = AltarArrow.new()
	_arrows.view = view
	_arrows.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_arrows)
	sim.sim_event.connect(_on_sim_event)
	for p in sim.pickups.pickups:
		_pickups.append(_build_pickup(p.pos))
	for f in sim.fruits.fruits:
		_fruits.append(_build_fruit(f.pos))
	for p in sim.altar.spots:
		_altars.append(_build_altar(p))
	for c in sim.camps.camps:
		_ring(c.home, 1.6, Color("7ad67a", 0.45))


func _ring(p: Vector2, r: float, color: Color) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r - 0.07
	t.outer_radius = r
	t.rings = 40
	t.ring_segments = 3
	return UnitFactory.part(self, t, color, MatchView.to_world(p, 0.02), Vector3.ZERO, true)


func _build_pickup(p: Vector2) -> Dictionary:
	var root := Node3D.new()
	root.position = MatchView.to_world(p)
	add_child(root)
	var coin := UnitFactory.part(root, UnitFactory.cylinder(0.26, 0.26, 0.06, 18), COIN, Vector3(0, 0.55, 0), Vector3(90, 0, 0), true)
	UnitFactory.part(coin, UnitFactory.cylinder(0.17, 0.17, 0.07, 18), COIN.darkened(0.2), Vector3.ZERO, Vector3.ZERO, true)
	var spark := Node3D.new()
	root.add_child(spark)
	for k in 3:
		UnitFactory.part(spark, UnitFactory.box(Vector3(0.12, 0.5, 0.12)), SPARK, Vector3(0, 0.55, 0), Vector3(0, 0, k * 60.0), true)
	var glow := UnitFactory.part(root, UnitFactory.cylinder(0.45, 0.45, 0.02, 24), Color(COIN, 0.25), Vector3(0, 0.02, 0), Vector3.ZERO, true)
	return {"root": root, "coin": coin, "spark": spark, "glow": glow}


func _build_fruit(p: Vector2) -> Dictionary:
	var root := Node3D.new()
	root.position = MatchView.to_world(p)
	add_child(root)
	var r := view.sim.config.fruit_radius
	UnitFactory.part(root, UnitFactory.cylinder(r, r, 0.02, 28), Color("5fae5a", 0.35), Vector3(0, 0.02, 0), Vector3.ZERO, true)
	var leaf := SphereMesh.new()
	leaf.radius = 0.42
	leaf.height = 0.5
	UnitFactory.part(root, leaf, Palette.BUSH, Vector3(0, 0.22, 0))
	var fruit := Node3D.new()
	root.add_child(fruit)
	for k in 3:
		var a := TAU * k / 3.0
		var ball := SphereMesh.new()
		ball.radius = 0.16
		ball.height = 0.3
		UnitFactory.part(fruit, ball, HONEY, Vector3(cos(a) * 0.25, 0.48, sin(a) * 0.25), Vector3.ZERO, true)
	var fill := UnitFactory.part(root, UnitFactory.cylinder(1.0, 1.0, 0.02, 28), Color(HONEY, 0.5), Vector3(0, 0.03, 0), Vector3.ZERO, true)
	return {"root": root, "fruit": fruit, "fill": fill}


func _build_altar(p: Vector2) -> Dictionary:
	var root := Node3D.new()
	root.position = MatchView.to_world(p)
	add_child(root)
	var r := view.sim.config.tarot_radius + 0.5
	var chalk := _ring(p, r, CHALK)
	var mark := UnitFactory.label(root, "?", 0.05, 96)
	mark.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	mark.no_depth_test = false
	mark.rotation_degrees = Vector3(-90, 0, 0)
	mark.modulate = Color(CHALK, 0.6)
	var plinth := UnitFactory.part(root, UnitFactory.cylinder(0.55, 0.65, 0.35, 8), Color("6e5a86"), Vector3(0, 0.17, 0))
	var card := UnitFactory.part(root, UnitFactory.box(Vector3(0.55, 0.85, 0.04)), Color("fff4dc"), Vector3(0, 1.3, 0), Vector3.ZERO, true)
	UnitFactory.part(card, UnitFactory.box(Vector3(0.42, 0.7, 0.05)), ALTAR, Vector3.ZERO, Vector3.ZERO, true)
	var glow := UnitFactory.part(root, UnitFactory.cylinder(r, r, 0.02, 32), Color(ALTAR, 0.25), Vector3(0, 0.03, 0), Vector3.ZERO, true)
	var fill := UnitFactory.part(root, UnitFactory.cylinder(1.0, 1.0, 0.02, 32), Color(ALTAR, 0.55), Vector3(0, 0.04, 0), Vector3.ZERO, true)
	return {"root": root, "chalk": chalk, "mark": mark, "plinth": plinth, "card": card, "glow": glow, "fill": fill}


func render() -> void:
	var sim := view.sim
	var t := Time.get_ticks_msec() / 1000.0
	for i in _pickups.size():
		var p: PickupController.Pickup = sim.pickups.pickups[i]
		var s: Dictionary = _pickups[i]
		s.root.visible = p.up
		if not p.up:
			continue
		var spark := p.kind == PickupController.SPARK
		s.coin.visible = not spark
		s.spark.visible = spark
		s.coin.rotation.y = t * 3.0 + i
		s.spark.rotation.y = t * 2.0 + i
		s.coin.position.y = 0.55 + 0.08 * sin(t * 3.0 + i)
		(s.glow.material_override as StandardMaterial3D).albedo_color = Color(SPARK if spark else COIN, 0.22 + 0.08 * sin(t * 4.0 + i))
	for i in _fruits.size():
		var f: Fruits.Fruit = sim.fruits.fruits[i]
		var s: Dictionary = _fruits[i]
		s.fruit.visible = f.ripe
		var k := clampf(maxf(f.progress[0], f.progress[1]) / sim.config.fruit_eat_time, 0.0, 1.0)
		s.fill.visible = f.ripe and k > 0.0
		var fr := sim.config.fruit_radius * k
		s.fill.scale = Vector3(fr, 1, fr)
	var altar := sim.altar
	for i in _altars.size():
		var s: Dictionary = _altars[i]
		var live := altar.up and altar.spot == i
		s.plinth.visible = live
		s.card.visible = live
		s.glow.visible = live
		s.mark.visible = not live
		if live:
			s.card.rotation.y = t * 1.5
			s.card.position.y = 1.3 + 0.12 * sin(t * 2.0)
			var k := clampf(maxf(altar.progress[0], altar.progress[1]) / sim.config.tarot_take_time, 0.0, 1.0)
			s.fill.visible = k > 0.0
			var fr := (sim.config.tarot_radius + 0.5) * k
			s.fill.scale = Vector3(fr, 1, fr)
		else:
			s.fill.visible = false
	_update_popups()
	_arrows.queue_redraw()


func _on_sim_event(type: StringName, data: Dictionary) -> void:
	var text := ""
	var color := Color.WHITE
	var mine: bool = data.get("team", -1) == view.local_seat
	match type:
		&"pickup_taken":
			if not mine:
				return
			var spark: bool = data.kind == PickupController.SPARK
			text = "+%d XP" % int(view.sim.config.pickup_xp) if spark else "+%d g" % int(view.sim.config.pickup_gold)
			color = SPARK if spark else COIN
		&"fruit_eaten":
			text = "Yum!" if mine else "Fruit eaten"
			color = HONEY
		&"tarot_picked":
			text = String(data.suit).capitalize()
			color = ALTAR
			var h: SimEntity = view.sim.get_entity(data.hero)
			if h != null:
				data = {"pos": h.pos}
		_:
			return
	var label := UnitFactory.label(self, text, 1.6, 44)
	label.position = MatchView.to_world(data.pos, 1.6)
	label.modulate = color if mine else Color(color, 0.75)
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


## A screen-edge arrow toward the Tarot altar while it's up and off screen.
class AltarArrow extends Control:
	var view: MatchView

	func _draw() -> void:
		if view == null or view.sim == null or not view.sim.altar.up:
			return
		var cam := view.camera_rig.camera
		var size := get_viewport_rect().size
		var top := Hud.TOP_BAND + 14.0
		var bottom := size.y - Hud.BOTTOM_BAND - 14.0
		var box := Rect2(Vector2(14, top), Vector2(size.x - 28, bottom - top))
		var centre := box.get_center()
		var world := MatchView.to_world(view.sim.altar.pos, 0.6)
		if cam.is_position_behind(world):
			return
		var sp := cam.unproject_position(world)
		if box.has_point(sp):
			return
		var dir := (sp - centre).normalized()
		var tx := (box.size.x / 2.0) / maxf(absf(dir.x), 0.0001)
		var ty := (box.size.y / 2.0) / maxf(absf(dir.y), 0.0001)
		var at := centre + dir * minf(tx, ty)
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([at, at - dir * 22.0 + side * 11.0, at - dir * 22.0 - side * 11.0]), Color(ALTAR, 0.95))
		draw_rect(Rect2(at - dir * 36.0 - Vector2(6, 9), Vector2(12, 18)), Color(ALTAR, 0.95))
