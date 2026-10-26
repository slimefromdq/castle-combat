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
var _fx: CombatFx
var _bars: UnitBars
var _candle_view: CandleView
var _relay_view: RelayView
var _status: StatusFx
var _occult: OccultFx
## Local-hero helpers: attack range ring, windup ring, target bracket, windup lines.
var _range_ring: MeshInstance3D
## Faint gold circle: enemy minions dying inside it pay you their gold.
var _gold_ring: MeshInstance3D
var _windup_ring: MeshInstance3D
var _bracket: MeshInstance3D
var _lines: MeshInstance3D
var _line_mesh := ImmediateMesh.new()
## Drag-to-aim preview: a flat arrow on the ground from your hero.
var _aim_line: MeshInstance3D
var _aim_dir := Vector2.ZERO
var _aim_length := 0.0


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
	camera_rig.half_width = ArenaGeometry.half_width(sim.arena)
	camera_rig.seat = seat
	add_child(camera_rig)
	_unit_root = Node3D.new()
	_unit_root.name = "Units"
	add_child(_unit_root)
	_build_helpers()
	_relay_view = RelayView.new()
	_relay_view.name = "Relay"
	_relay_view.view = self
	add_child(_relay_view)
	_candle_view = CandleView.new()
	_candle_view.name = "Candles"
	_candle_view.view = self
	add_child(_candle_view)
	_fx = CombatFx.new()
	_fx.view = self
	add_child(_fx)
	sim.sim_event.connect(_fx.on_sim_event)
	_status = StatusFx.new()
	_status.view = self
	add_child(_status)
	sim.sim_event.connect(_status.on_sim_event)
	_occult = OccultFx.new()
	_occult.view = self
	add_child(_occult)
	sim.sim_event.connect(_occult.on_sim_event)
	var bar_layer := CanvasLayer.new()
	bar_layer.layer = 0
	add_child(bar_layer)
	_bars = UnitBars.new()
	_bars.view = self
	bar_layer.add_child(_bars)
	_rebuild_units()
	render(1.0, 0.0, true)


## The point on the ground (sim space) under a screen position.
func ground_point(screen_pos: Vector2) -> Vector2:
	var cam := camera_rig.camera
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return sim.heroes[local_seat].pos
	var hit := from + dir * (-from.y / dir.y)
	return Vector2(hit.x, -hit.z)


func show_aim(dir: Vector2, length: float) -> void:
	_aim_dir = dir
	_aim_length = length


func hide_aim() -> void:
	_aim_dir = Vector2.ZERO


func _place_aim_line(hero_world: Vector3) -> void:
	if _aim_line == null:
		_aim_line = MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.55, 0.02, 1.0)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 1, 1, 0.45)
		mat.no_depth_test = true
		mesh.material = mat
		_aim_line.mesh = mesh
		add_child(_aim_line)
	_aim_line.visible = _aim_dir != Vector2.ZERO and sim.heroes[local_seat].alive
	if not _aim_line.visible:
		return
	var d := to_world(_aim_dir)
	_aim_line.basis = Basis.looking_at(d, Vector3.UP) * Basis.from_scale(Vector3(1, 1, _aim_length))
	_aim_line.position = hero_world + d * (_aim_length / 2.0) + Vector3(0, 0.06, 0)


func unit_nodes() -> Dictionary:
	return _units


## World position of a unit's node, or its last sim position if it has no node.
func unit_position(id: int) -> Vector3:
	var node: Node3D = _units.get(id)
	if node != null:
		return node.global_position
	var e := sim.get_entity(id)
	return to_world(e.pos) if e != null else Vector3.ZERO


## Nearest unit you could focus at a tap/click, within a thumb-sized radius: enemies,
## or your own minions that are low enough to deny. Enemies win ties. 0 if none.
func pick_enemy(screen_pos: Vector2, radius_px := 56.0) -> int:
	var cam := camera_rig.camera
	var best := 0
	var best_d := radius_px
	var me := sim.heroes[local_seat]
	for id: int in _units:
		var e: SimEntity = sim.get_entity(id)
		if e == null or not e.alive or e.team < 0:
			continue
		var deny := e.team == local_seat
		if deny and not CombatSystem.can_deny(sim, me, e):
			continue
		var node: Node3D = _units[id]
		var p := cam.unproject_position(node.global_position + Vector3(0, 0.6, 0))
		var d := p.distance_to(screen_pos) + (12.0 if deny else 0.0)
		if d < best_d:
			best_d = d
			best = id
	return best


## Switching seats swaps who counts as "ally", so colors and decals are rebuilt.
func set_local_seat(seat: int) -> void:
	local_seat = seat
	camera_rig.set_seat(seat)
	_arena_view.build(sim.arena, seat)
	_status.reset()
	_occult.reset()
	_rebuild_units()
	render(1.0, 0.0, true)


## alpha = how far we are between the previous and current sim tick (0..1).
func render(alpha: float, delta: float, snap := false) -> void:
	_sync_unit_nodes()
	for id: int in _units:
		var e: SimEntity = sim.entities[id]
		var node: Node3D = _units[id]
		node.position = to_world(e.prev_pos.lerp(e.pos, alpha))
		_update_aggro_mark(e, node)
		if e is StructureState:
			node.get_node("Body").visible = e.alive
			node.get_node("Rubble").visible = not e.alive
			var locked := not sim.is_exposed(e)
			node.get_node("Body/Dome").visible = locked or sim.time < e.immune_until
			continue
		node.visible = e.alive
		if e is HeroState and e.team != local_seat and sim.is_hidden(e):
			node.visible = false  # In a bush: the enemy is out of sight.
		if e is MinionState and e.is_power:
			node.scale = Vector3.ONE * 1.3
		if e is MinionState:
			node.get_node("Flag").visible = e.bannered
			var shield: Node3D = node.get_node_or_null("Body/Shield")
			if shield != null:
				shield.visible = e.shield_left > 0
		var facing := _facing_of(e)
		if e is HeroState and e.sprinting and e.data.sprint_moonwalk:
			facing = -facing  # Moonwalk: glide forward while facing back.
		if facing != Vector2.ZERO:
			var body: Node3D = node.get_node("Body")
			var target_yaw := atan2(-facing.x, facing.y)
			body.rotation.y = target_yaw if snap else lerp_angle(body.rotation.y, target_yaw, 1.0 - exp(-18.0 * delta))
		if e is HeroState:
			_sprint_pose(e, node.get_node("Body"), delta)
			_show_gear(e, node.get_node("Body"))
			# In the shadows Jack shrinks into a dark pool.
			var body3: Node3D = node.get_node("Body")
			var want := 0.45 if e.is_vanished() else 1.0
			body3.scale = Vector3.ONE * (want if snap else lerpf(body3.scale.x, want, 1.0 - exp(-14.0 * delta)))
	_update_helpers()
	_relay_view.render(alpha)
	_candle_view.render()
	_status.render()
	_occult.render(alpha)
	var me := sim.heroes[local_seat]
	camera_rig.follow(to_world(me.prev_pos.lerp(me.pos, alpha)), delta, snap)
	_place_aim_line(to_world(me.prev_pos.lerp(me.pos, alpha)))


## Sprinting heroes lean into the run and bounce (each hero its own way, see HeroData).
## Item silhouettes: mid items light the weapon, late items add armor or clothing, and a
## Masterwork floats a gem over the head.
func _show_gear(h: HeroState, body: Node3D) -> void:
	var tier := h.top_item_tier()
	var mid: Node3D = body.get_node("GearMid")
	mid.visible = tier >= ItemData.Tier.MID
	if mid.visible:
		mid.scale = Vector3.ONE * (1.0 + 0.06 * sin(Time.get_ticks_msec() / 120.0))
	body.get_node("GearLate").visible = tier >= ItemData.Tier.LATE
	var master: Node3D = body.get_node("GearMaster")
	master.visible = not h.masterworks.is_empty()
	if master.visible:
		master.rotation.y = Time.get_ticks_msec() / 400.0


func _sprint_pose(h: HeroState, body: Node3D, delta: float) -> void:
	var d := h.data
	var k := 1.0 - exp(-10.0 * delta)
	var lean := -deg_to_rad(d.sprint_lean_deg) if h.sprinting else 0.0
	body.rotation.x = lerpf(body.rotation.x, lean, k)
	var bob := absf(sin(Time.get_ticks_msec() / 70.0)) * d.sprint_bob if h.sprinting else 0.0
	body.position.y = lerpf(body.position.y, bob, k * 2.0)


## A "!" over minions and towers that a hero's attack has called: red when they are
## coming for you, your team color when they are going for the enemy hero.
func _update_aggro_mark(e: SimEntity, node: Node3D) -> void:
	var mark: Label3D = node.get_node_or_null("Aggro")
	if mark == null:
		return
	mark.visible = e.alive and e.is_called(sim.time)
	if mark.visible:
		var on_me := e.called_target == sim.heroes[local_seat].id
		mark.modulate = Color("ff3b30") if on_me else Palette.ALLY.lightened(0.3)
		mark.position.y = float(node.get_meta("bar_height", 1.5)) + 0.5 + 0.1 * sin(Time.get_ticks_msec() / 90.0)


## Units turn toward whatever they are winding up on; heroes otherwise face where they walk.
func _facing_of(e: SimEntity) -> Vector2:
	if e.is_winding_up():
		var t := sim.get_entity(e.attack_target)
		if t != null and t.pos != e.pos:
			return (t.pos - e.pos).normalized()
	if e is HeroState:
		return e.facing
	if e is MinionState:
		return e.lane_dir if e.pos == e.prev_pos else (e.pos - e.prev_pos).normalized()
	return Vector2.ZERO


## Creates nodes for new units (minion waves) and frees nodes for removed ones.
func _sync_unit_nodes() -> void:
	for id: int in _units.keys():
		if not sim.entities.has(id):
			_units[id].queue_free()
			_units.erase(id)
	if _units.size() == sim.entities.size():
		return
	for e: SimEntity in sim.entities.values():
		if not _units.has(e.id):
			_add_unit_node(e)


func _build_helpers() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.96
	ring.outer_radius = 1.0
	ring.rings = 64
	ring.ring_segments = 4
	_range_ring = UnitFactory.part(self, ring, Color(1, 1, 1, 0.35), Vector3.ZERO, Vector3.ZERO, true)
	var gold := TorusMesh.new()
	gold.inner_radius = 0.985
	gold.outer_radius = 1.0
	gold.rings = 96
	gold.ring_segments = 4
	_gold_ring = UnitFactory.part(self, gold, Color(Palette.RELAY, 0.28), Vector3.ZERO, Vector3.ZERO, true)
	var wind := TorusMesh.new()
	wind.inner_radius = 0.82
	wind.outer_radius = 1.0
	wind.rings = 32
	wind.ring_segments = 4
	_windup_ring = UnitFactory.part(self, wind, Color(1, 1, 1, 0.8), Vector3.ZERO, Vector3.ZERO, true)
	var bracket := TorusMesh.new()
	bracket.inner_radius = 0.85
	bracket.outer_radius = 1.0
	bracket.rings = 4
	bracket.ring_segments = 4
	_bracket = UnitFactory.part(self, bracket, Color(1, 1, 1, 0.9), Vector3.ZERO, Vector3.ZERO, true)
	_lines = MeshInstance3D.new()
	_lines.mesh = _line_mesh
	_lines.material_override = UnitFactory.material(Color(1, 1, 1, 0.75), true)
	_lines.material_override.vertex_color_use_as_albedo = true
	add_child(_lines)


func _update_helpers() -> void:
	var me := sim.heroes[local_seat]
	var my_pos := unit_position(me.id)
	# Range ring: only while you stand still, i.e. while you are able to attack.
	_range_ring.visible = me.alive and not me.moving
	_range_ring.position = my_pos + Vector3(0, 0.04, 0)
	_range_ring.scale = Vector3(me.attack_range + 0.4, 0.02, me.attack_range + 0.4)
	_gold_ring.visible = me.alive
	_gold_ring.position = my_pos + Vector3(0, 0.03, 0)
	var gr := sim.config.minion_gold_radius
	_gold_ring.scale = Vector3(gr, 0.02, gr)
	# Windup: a ring that closes in on the hero as the attack charges.
	_windup_ring.visible = me.alive and me.is_winding_up()
	var k := me.windup_progress()
	_windup_ring.position = my_pos + Vector3(0, 0.06, 0)
	_windup_ring.scale = Vector3(lerpf(1.6, 0.7, k), 0.03, lerpf(1.6, 0.7, k))
	# Target bracket: yellow for a tapped target, white for the automatic one.
	var target_id := me.preferred_target if me.preferred_target != 0 else me.attack_target
	var target := sim.get_entity(target_id)
	_bracket.visible = me.alive and target != null and target.alive
	if _bracket.visible:
		_bracket.position = unit_position(target_id) + Vector3(0, 0.05, 0)
		var r := target.radius + 0.45
		_bracket.scale = Vector3(r, 0.04, r)
		_bracket.rotation.y = Time.get_ticks_msec() / 900.0
		var mat: StandardMaterial3D = _bracket.material_override
		mat.albedo_color = Palette.RELAY if me.preferred_target != 0 else Color(1, 1, 1, 0.9)
	# Windup lines for heroes and structures: who is about to hit whom.
	_line_mesh.clear_surfaces()
	var any := false
	for e: SimEntity in sim.heroes + sim.structures:
		if not e.alive or not e.is_winding_up() or not sim.entities.has(e.attack_target):
			continue
		if not any:
			_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
			any = true
		var c := Palette.team_color(e.team == local_seat).lightened(0.4)
		_line_mesh.surface_set_color(c)
		_line_mesh.surface_add_vertex(unit_position(e.id) + Vector3(0, 0.9 if e is HeroState else 2.0, 0))
		_line_mesh.surface_set_color(c)
		_line_mesh.surface_add_vertex(unit_position(e.attack_target) + Vector3(0, 0.6, 0))
	if any:
		_line_mesh.surface_end()


func _rebuild_units() -> void:
	for child in _unit_root.get_children():
		child.queue_free()
	_units.clear()
	for e: SimEntity in sim.entities.values():
		_add_unit_node(e)


func _add_unit_node(e: SimEntity) -> void:
	var is_ally := e.team == local_seat
	var node: Node3D
	if e is HeroState:
		node = UnitFactory.make_hero(e, is_ally)
	elif e is StructureState:
		node = UnitFactory.make_structure(e, is_ally)
	elif e is MinionState:
		node = UnitFactory.make_minion(e, is_ally)
	else:
		return
	node.position = to_world(e.pos)
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
