class_name ArenaView
extends Node3D
## The static map as a bright occult street: a cobbled lane opening into a sandstone
## diamond, violet Relay spots with chalk circles, painted brick walls, and shops,
## lanterns and tarot banners on the plaza outside.
## Each half of the lane carries its owner's color on the lane edges and a soft wash
## near its base, so "whose side is this" reads at a glance. Rebuilt when seats swap,
## because ally/enemy is relative to the viewer.

const SCENERY_SEED := 7


func build(arena: ArenaData, local_seat: int) -> void:
	for child in get_children():
		child.queue_free()
	var half := arena.half_length
	var lane_w := arena.lane_half_width * 2.0
	# Plaza flagstones all around.
	var plaza := StreetArt.stones("plaza", Palette.PLAZA, Palette.PLAZA_MORTAR, 4, 70, 120, [Color("a8d7a0"), Color("d9c98f")], 0.12, 3)
	StreetArt.street_part(self, UnitFactory.box(Vector3(70, 0.1, half * 2.0 + 50)), StreetArt.street_material(plaza, Color.WHITE, 6.0), Vector3(0, -0.12, 0))
	# Lane cobbles, diamond sandstone and Relay-spot flagstones.
	var lane := StreetArt.stones("lane", Palette.LANE, Palette.LANE_MORTAR, 6, 40, 72, [Color("d97fa6"), Color("5cc2b0"), Color("e6c35c"), Color("a88be0")], 0.035, 5)
	var square := StreetArt.stones("diamond", Palette.DIAMOND, Palette.DIAMOND_MORTAR, 8, 30, 52, [Color("e6c35c"), Color("d97fa6"), Color("5cc2b0")], 0.05, 9)
	var pocket := StreetArt.stones("pocket", Palette.POCKET, Palette.POCKET_MORTAR, 4, 64, 100, [Color("c9a9ff"), Color("ffd84a")], 0.1, 13)
	if arena.has_diamond():
		# A rhombus: a square turned 45 degrees inside a parent scaled to the diamond.
		var holder := Node3D.new()
		holder.scale = Vector3(arena.diamond_half_width, 1.0, arena.diamond_tip)
		holder.position = Vector3(0, -0.07, 0)
		add_child(holder)
		var sq := StreetArt.street_part(holder, UnitFactory.box(Vector3(sqrt(2.0), 0.1, sqrt(2.0))), StreetArt.street_material(square, Color.WHITE, 3.0), Vector3.ZERO)
		sq.rotation.y = PI / 4.0
	for i in arena.floors.size():
		var r := arena.floors[i]
		StreetArt.street_part(self, UnitFactory.box(Vector3(r.size.x, 0.1, r.size.y)), StreetArt.street_material(lane, Color.WHITE, 4.0), MatchView.to_world(r.get_center(), -0.05))
	for pk in arena.pockets:
		StreetArt.street_part(self, UnitFactory.box(Vector3(pk.size.x, 0.1, pk.size.y)), StreetArt.street_material(pocket, Color.WHITE, 4.0), MatchView.to_world(pk.get_center(), -0.03))
	# Chalk ritual circles in the Relay pockets.
	for pk in arena.pockets:
		StreetArt.floor_sigil(self, StreetArt.Sigil.RITUAL, Color(Palette.CHALK, 0.3), MatchView.to_world(pk.get_center(), 0.006), minf(pk.size.x, pk.size.y) * 0.9)
	_graffiti(arena)
	# Team halves: colored lane edges plus a soft wash toward each base.
	for team in [MatchSim.BLUE, MatchSim.RED]:
		var c := Palette.team_color(team == local_seat)
		var end_sign := -1.0 if team == MatchSim.BLUE else 1.0
		var from := arena.shoulder_y() if arena.has_diamond() else 6.0
		for side in [-1.0, 1.0]:
			var x: float = side * (arena.lane_half_width - 0.2)
			UnitFactory.part(self, UnitFactory.box(Vector3(0.22, 0.02, half - from)), c, MatchView.to_world(Vector2(x, end_sign * (half + from) / 2.0), 0.01), Vector3.ZERO, true)
		UnitFactory.part(self, UnitFactory.box(Vector3(lane_w, 0.02, 16.0)), Color(c, 0.18), MatchView.to_world(Vector2(0, end_sign * (half - 8.0)), 0.008), Vector3.ZERO, true)
	# Healing pads behind each Core: a green glow inside a chalk circle.
	for team in [MatchSim.BLUE, MatchSim.RED]:
		var at := MatchView.to_world(MatchSim.to_team_space(team, arena.heal_pad), 0.015)
		var pad_c := Palette.team_color(team == local_seat).lightened(0.5)
		UnitFactory.part(self, UnitFactory.cylinder(arena.heal_pad_radius, arena.heal_pad_radius, 0.02, 32), Color(0.55, 1.0, 0.65, 0.35), at, Vector3.ZERO, true)
		UnitFactory.part(self, UnitFactory.cylinder(arena.heal_pad_radius * 0.35, arena.heal_pad_radius * 0.35, 0.03, 4), Color(pad_c, 0.8), at + Vector3(0, 0.01, 0), Vector3(0, 45, 0), true)
		StreetArt.floor_sigil(self, StreetArt.Sigil.RITUAL, Color(Palette.CHALK, 0.35), at + Vector3(0, 0.02, 0), arena.heal_pad_radius * 2.25)
	_bushes(arena)
	# Gold centre line across the lane.
	UnitFactory.part(self, UnitFactory.box(Vector3(lane_w, 0.02, 0.3)), Palette.CENTER_LINE, MatchView.to_world(Vector2.ZERO, 0.012), Vector3.ZERO, true)
	# Walls: painted brick with a cream cap, below hero height so the camera never loses
	# a unit. Paint is picked by position, so both halves of the map match.
	var brick := StreetArt.stones("wall_brick", Color("f7f0e4"), Color("b9ab98"), 20, 26, 40, [], 0.0, 17)
	var mats := {}
	for w in arena.walls:
		var c := w.get_center()
		var paint_i := int(absf(c.x) * 3.0 + absf(c.y) * 7.0) % StreetArt.PAINT.size()
		if not mats.has(paint_i):
			mats[paint_i] = StreetArt.street_material(brick, StreetArt.PAINT[paint_i], 1.6)
		StreetArt.street_part(self, UnitFactory.box(Vector3(w.size.x, 0.7, w.size.y)), mats[paint_i], MatchView.to_world(c, 0.35))
		# The cap is what the camera mostly sees: the wall's paint, lighter, with a cream lip.
		var paint: Color = StreetArt.PAINT[paint_i]
		UnitFactory.part(self, UnitFactory.box(Vector3(w.size.x + 0.08, 0.08, w.size.y + 0.08)), Palette.WALL_CAP, MatchView.to_world(c, 0.74))
		UnitFactory.part(self, UnitFactory.box(Vector3(maxf(w.size.x - 0.16, 0.05), 0.02, maxf(w.size.y - 0.16, 0.05))), paint.lightened(0.15), MatchView.to_world(c, 0.785))
	# The diamond's edges: the same painted walls, laid along the slanted sides.
	var edges := arena.diamond_edges()
	for k in edges.size():
		var a: Vector2 = edges[k][0]
		var b: Vector2 = edges[k][1]
		var dir := (b - a).normalized()
		var normal := Vector2(dir.y, -dir.x)
		if normal.dot(a) < 0.0:
			normal = -normal  # Outward, away from the middle of the map.
		var mid := (a + b) / 2.0 + normal * 0.33
		var length := a.distance_to(b) + 0.6
		var paint_k := (k + 2) % StreetArt.PAINT.size()
		if not mats.has(paint_k):
			mats[paint_k] = StreetArt.street_material(brick, StreetArt.PAINT[paint_k], 1.6)
		var yaw := atan2((b - a).y, (b - a).x)
		var wall := StreetArt.street_part(self, UnitFactory.box(Vector3(length, 0.7, 0.66)), mats[paint_k], MatchView.to_world(mid, 0.35))
		wall.rotation.y = yaw
		var cap := UnitFactory.part(self, UnitFactory.box(Vector3(length + 0.08, 0.08, 0.74)), Palette.WALL_CAP, MatchView.to_world(mid, 0.74))
		cap.rotation.y = yaw
		var top := UnitFactory.part(self, UnitFactory.box(Vector3(length - 0.16, 0.02, 0.5)), StreetArt.PAINT[paint_k].lightened(0.15), MatchView.to_world(mid, 0.785))
		top.rotation.y = yaw
	_scenery(arena)


## Spray-paint sigils near the lane edges, clear of structures and the centre.
func _graffiti(arena: ArenaData) -> void:
	var spots := [[Vector2(-3.9, -12.5), StreetArt.Sigil.EYE], [Vector2(4.0, -27.5), StreetArt.Sigil.CROWN], [Vector2(-4.0, -40.5), StreetArt.Sigil.MOON], [Vector2(3.9, -15.0), StreetArt.Sigil.SPIRAL], [Vector2(-3.8, -26.0), StreetArt.Sigil.PENTACLE]]
	for i in spots.size():
		var p: Vector2 = spots[i][0]
		var color: Color = StreetArt.NEON[i % StreetArt.NEON.size()]
		for q in [p, -p]:
			StreetArt.floor_sigil(self, spots[i][1], Color(color, 0.3), MatchView.to_world(q, 0.005), 1.7, 180.0 if q != p else 0.0)


## Bushes: a dark green base with round leafy clumps on top, low enough that a hero
## inside still pokes out a little for its owner (the enemy sees nothing).
func _bushes(arena: ArenaData) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SCENERY_SEED + 1
	for r in arena.bushes:
		UnitFactory.part(self, UnitFactory.box(Vector3(r.size.x, 0.5, r.size.y)), Palette.BUSH.darkened(0.25), MatchView.to_world(r.get_center(), 0.25))
		var step := 0.75
		var y := r.position.y + step / 2.0
		while y < r.end.y:
			var x := r.position.x + step / 2.0
			while x < r.end.x:
				var clump := SphereMesh.new()
				var rad := rng.randf_range(0.42, 0.55)
				clump.radius = rad
				clump.height = rad * 1.6
				var shade := Palette.BUSH.lightened(rng.randf_range(-0.05, 0.15))
				UnitFactory.part(self, clump, shade, MatchView.to_world(Vector2(x, y) + Vector2(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.1, 0.1)), 0.65))
				x += step
			y += step


## Shops, planters and tarot banners on the plaza, plus lanterns just outside the lane
## walls. Placed for one half and mirrored, so both seats see the same street.
func _scenery(arena: ArenaData) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SCENERY_SEED
	var half := arena.half_length
	# Lanterns along the outside of the lane walls.
	var y := -half + 3.0
	while y < -1.0:
		for x in [-(arena.lane_half_width + 1.0), arena.lane_half_width + 1.0]:
			var p := Vector2(x, y)
			if not _too_close_to_play(arena, p, 0.2):
				for q in [p, -p]:
					StreetArt.lantern(self, MatchView.to_world(q))
		y += 7.5
	# The plaza: a grid of 3 m lots, each a shop, a planter, a banner or open paving.
	var lot := 3.0
	for side in [-1.0, 1.0]:
		var ly := -half - 4.0
		while ly < 0.0:
			var lx := arena.lane_half_width + 1.6
			while lx < 26.0:
				var p := Vector2(side * (lx + lot / 2.0), ly + lot / 2.0)
				var roll := rng.randf()
				var cell := Rect2(p - Vector2(lot, lot) / 2.0, Vector2(lot, lot))
				if not _rect_near_play(arena, cell, 0.3):
					for q in [p, -p]:
						_lot(q, roll, rng.randi())
				lx += lot
			ly += lot


func _lot(p: Vector2, roll: float, pick: int) -> void:
	var at := MatchView.to_world(p)
	var paint: Color = StreetArt.PAINT[pick % StreetArt.PAINT.size()]
	var neon: Color = StreetArt.NEON[pick % StreetArt.NEON.size()]
	var kind: StreetArt.Sigil = pick % 5 as StreetArt.Sigil
	if roll < 0.55:
		var size := Vector3(2.4 + (pick % 3) * 0.15, 1.5 + (pick % 4) * 0.2, 2.3)
		var roof: Color = StreetArt.PAINT[(pick / 7) % StreetArt.PAINT.size()].darkened(0.25)
		StreetArt.shopfront(self, at, size, paint, roof, neon, kind)
	elif roll < 0.8:
		StreetArt.planter(self, at, Palette.TREE if pick % 2 == 0 else Palette.TREE_LIGHT, 0.9 + (pick % 3) * 0.15)
	elif roll < 0.92:
		StreetArt.banner(self, at, paint.darkened(0.1), kind)


func _too_close_to_play(arena: ArenaData, p: Vector2, margin := 0.9) -> bool:
	if arena.has_diamond() and arena.in_bounds(p, -margin - 0.7):
		return true
	for r in arena.floors + arena.walls:
		if r.grow(margin).has_point(p):
			return true
	return false


func _rect_near_play(arena: ArenaData, cell: Rect2, margin: float) -> bool:
	if arena.has_diamond():
		for p in [cell.position, cell.end, Vector2(cell.position.x, cell.end.y), Vector2(cell.end.x, cell.position.y), cell.get_center()]:
			if arena.in_bounds(p, -margin - 0.7):
				return true
	for r in arena.floors + arena.walls:
		if r.grow(margin).intersects(cell):
			return true
	return false
