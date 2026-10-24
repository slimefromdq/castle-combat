class_name MatchView
extends Node3D
## Draws the match in 3D from MatchSim state. Read-only: it never changes the sim.
## Sim (x, y) maps to world (x, 0, -y), so blue's "forward" is world -Z.

var sim: MatchSim
var local_seat := MatchSim.BLUE
var camera_rig: CameraRig
var _units: Dictionary = {}
var _unit_root: Node3D


static func to_world(p: Vector2, height := 0.0) -> Vector3:
	return Vector3(p.x, height, -p.y)


func build(match_sim: MatchSim, seat: int) -> void:
	sim = match_sim
	local_seat = seat
	_build_environment()
	_build_arena()
	camera_rig = CameraRig.new()
	camera_rig.half_length = sim.arena.half_length
	camera_rig.seat = seat
	add_child(camera_rig)
	_unit_root = Node3D.new()
	_unit_root.name = "Units"
	add_child(_unit_root)
	_rebuild_units()
	render(1.0, 0.0, true)


## Switching seats swaps who counts as "ally", so colors and decals are rebuilt.
func set_local_seat(seat: int) -> void:
	local_seat = seat
	camera_rig.set_seat(seat)
	_rebuild_units()
	render(1.0, 0.0, true)


## alpha = how far we are between the previous and current sim tick (0..1).
func render(alpha: float, delta: float, snap := false) -> void:
	for id: int in _units:
		var e: SimEntity = sim.entities[id]
		var node: Node3D = _units[id]
		node.visible = e.alive
		node.position = to_world(e.prev_pos.lerp(e.pos, alpha))
		if e is HeroState:
			var body: Node3D = node.get_node("Body")
			var target_yaw := atan2(-e.facing.x, e.facing.y)
			body.rotation.y = target_yaw if snap else lerp_angle(body.rotation.y, target_yaw, 1.0 - exp(-18.0 * delta))
		elif e is StructureState:
			var locked := not sim.is_exposed(e)
			node.get_node("Dome").visible = locked
			var tag: Label3D = node.get_node("Tag")
			tag.text = "%s%s" % [e.data.display_name, "  (locked)" if locked else ""]
	var me := sim.heroes[local_seat]
	camera_rig.follow(to_world(me.prev_pos.lerp(me.pos, alpha)), delta, snap)


func _rebuild_units() -> void:
	for child in _unit_root.get_children():
		child.queue_free()
	_units.clear()
	for e: SimEntity in sim.entities.values():
		var is_ally := e.team == local_seat
		var node: Node3D
		if e is HeroState:
			node = UnitFactory.make_hero(e, is_ally)
		elif e is StructureState:
			node = UnitFactory.make_structure(e, is_ally)
		else:
			continue
		_unit_root.add_child(node)
		_units[e.id] = node


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = false
	add_child(sun)


func _build_arena() -> void:
	var arena := sim.arena
	var root := Node3D.new()
	root.name = "Arena"
	add_child(root)
	UnitFactory.part(root, UnitFactory.box(Vector3(60, 0.1, arena.half_length * 2.0 + 40)), Palette.GROUND, Vector3(0, -0.12, 0))
	for i in arena.floors.size():
		var r := arena.floors[i]
		var color := Palette.LANE if i == 0 else Palette.POCKET
		UnitFactory.part(root, UnitFactory.box(Vector3(r.size.x, 0.1, r.size.y)), color, to_world(r.get_center(), -0.05))
	# Cross-lane marks every 6 m make movement easy to read; the centre line is wider.
	var y := -arena.half_length + 6.0
	while y < arena.half_length - 1.0:
		var depth := 0.35 if is_zero_approx(y) else 0.12
		UnitFactory.part(root, UnitFactory.box(Vector3(arena.lane_half_width * 2.0, 0.02, depth)), Palette.LANE_MARK, to_world(Vector2(0, y), 0.005), Vector3.ZERO, true)
		y += 6.0
	# Tiled pocket floors so the Relay pockets read as special places.
	for pocket in arena.pockets:
		var tx := pocket.position.x + 0.75
		while tx < pocket.end.x - 0.4:
			var ty := pocket.position.y + 0.75
			while ty < pocket.end.y - 0.4:
				UnitFactory.part(root, UnitFactory.box(Vector3(0.9, 0.02, 0.9)), Palette.POCKET_TILE, to_world(Vector2(tx, ty), 0.005), Vector3.ZERO, true)
				ty += 1.5
			tx += 1.5
	# Walls stay below hero height so the tilted camera never hides a unit.
	for w in arena.walls:
		UnitFactory.part(root, UnitFactory.box(Vector3(w.size.x, 0.7, w.size.y)), Palette.WALL, to_world(w.get_center(), 0.35))
