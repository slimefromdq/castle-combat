class_name DiamondView
extends Node3D
## Draws the things on the diamond that aren't units: honey fruit bushes (Fruits) and
## the long Relay drops (phase 2). Read-only, like the rest of the view.

const COIN := Color("ffcf3f")
const HONEY := Color("ff9f1c")

var view: MatchView
var _fruits: Array[Dictionary] = []
var _popups: Array = []
## Long Relay drops (phase 2), one per team: {root, frame, label}.
var _long: Array[Dictionary] = []


func _ready() -> void:
	var sim := view.sim
	sim.sim_event.connect(_on_sim_event)
	for f in sim.fruits.fruits:
		_fruits.append(_build_fruit(f.pos))
	if sim.arena.long_drop != Vector2.ZERO:
		for team in [MatchSim.BLUE, MatchSim.RED]:
			_long.append(_build_long_drop(sim, team))


## A long Relay drop: a chalk square in the team's colour with a floating tag. Hidden
## until phase 2.
func _build_long_drop(sim: MatchSim, team: int) -> Dictionary:
	var c := sim.arena.long_drop if team == MatchSim.BLUE else -sim.arena.long_drop
	var mine := team == view.local_seat
	var color := Palette.team_color(mine)
	var root := Node3D.new()
	root.position = MatchView.to_world(c, 0.03)
	root.visible = false
	add_child(root)
	var half := sim.config.relay_long_size * 0.5
	var w := 0.16
	var frame := Node3D.new()
	root.add_child(frame)
	for k in 4:
		var horiz := k < 2
		var sgn := -1.0 if k % 2 == 0 else 1.0
		var size := Vector3(half * 2.0 + w, 0.04, w) if horiz else Vector3(w, 0.04, half * 2.0 + w)
		var at := Vector3(0, 0, sgn * half) if horiz else Vector3(sgn * half, 0, 0)
		UnitFactory.part(frame, UnitFactory.box(size), Color(color.lightened(0.25), 0.9 if mine else 0.55), at, Vector3.ZERO, true)
	var fill := UnitFactory.part(root, UnitFactory.box(Vector3(half * 2.0, 0.02, half * 2.0)), Color(color, 0.16 if mine else 0.08), Vector3.ZERO, Vector3.ZERO, true)
	var tag := UnitFactory.label(root, "Long drop x%.2f" % sim.config.relay_long_gold_mult if mine else "Their long drop", 1.4, 36)
	tag.modulate = color.lightened(0.35) if mine else Color(color.lightened(0.2), 0.7)
	tag.outline_modulate = Color(0.1, 0.08, 0.12)
	return {"root": root, "frame": frame, "fill": fill, "team": team}


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


func render() -> void:
	var sim := view.sim
	var t := Time.get_ticks_msec() / 1000.0
	for i in _fruits.size():
		var f: Fruits.Fruit = sim.fruits.fruits[i]
		var s: Dictionary = _fruits[i]
		s.fruit.visible = f.ripe
		var k := clampf(maxf(f.progress[0], f.progress[1]) / sim.config.fruit_eat_time, 0.0, 1.0)
		s.fill.visible = f.ripe and k > 0.0
		var fr := sim.config.fruit_radius * k
		s.fill.scale = Vector3(fr, 1, fr)
	for d in _long:
		d.root.visible = sim.phase >= 2
		if d.root.visible:
			# Pulse while this team's hero carries the Relay: that's when it matters.
			var carrier := sim.relay.carrier(sim)
			var live: bool = carrier != null and carrier.team == d.team
			var k := 1.0 + (0.06 * sin(t * 6.0) if live else 0.0)
			d.frame.scale = Vector3(k, 1, k)
	_update_popups()


func _on_sim_event(type: StringName, data: Dictionary) -> void:
	var text := ""
	var color := Color.WHITE
	var mine: bool = data.get("team", -1) == view.local_seat
	match type:
		&"relay_delivered":
			if not data.get("long", false):
				return
			text = "Long delivery!"
			color = COIN
			var h: HeroState = view.sim.heroes[data.team] if data.team >= 0 else null
			if h == null:
				return
			data = {"pos": h.pos, "team": data.team}
		&"trick_used":
			text = Tricks.display_name(data.trick) + "!"
			color = Tricks.COLORS.get(data.trick, Color.WHITE)
			data = {"pos": data.get("to", data.pos), "team": data.team}
		&"cc_resisted":
			text = "Immune"
			color = Color("8ff0b0")
		&"interrupted":
			# Shown for the hero who did the interrupting.
			mine = data.team != view.local_seat
			text = "Interrupted!" if data.refund <= 0.0 else "Interrupted! -%.0fs" % data.refund
			color = Color("ffd166")
		&"brand_landed":
			text = "Branded!"
			color = Tricks.COLORS[&"brand"]
		&"shutdown":
			text = "Shutdown! +%dg" % roundi(data.amount)
			color = COIN
		&"fruit_eaten":
			text = "Yum!" if mine else "Fruit eaten"
			color = HONEY
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

