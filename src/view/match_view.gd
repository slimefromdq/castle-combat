class_name MatchView
extends Node3D
## Draws the match in 3D from MatchSim state. Read-only: it never changes the sim.
## Sim (x, y) maps to world (x, 0, -y), so blue's "forward" is world -Z.

var sim: MatchSim
var local_seat := MatchSim.BLUE
var camera_rig: CameraRig
var _units: Dictionary = {}
var _unit_root: Node3D
var _arena_view: ArenaView


static func to_world(p: Vector2, height := 0.0) -> Vector3:
	return Vector3(p.x, height, -p.y)


func build(match_sim: MatchSim, seat: int) -> void:
	sim = match_sim
	local_seat = seat
	_build_environment()
	_arena_view = ArenaView.new()
	_arena_view.name = "Arena"
	add_child(_arena_view)
	_arena_view.build(sim.arena, seat)
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
	_arena_view.build(sim.arena, seat)
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
	env.ambient_light_color = Color(0.85, 0.88, 1.0)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.05
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = false
	add_child(sun)
