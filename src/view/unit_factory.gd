class_name UnitFactory
## Builds the primitive 3D silhouettes. Every node faces -Z (sim "forward" for blue).
## Silhouette = what it is; base decal shape = whose it is (circle ally, diamond enemy);
## color only backs those up.


static func material(color: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func part(parent: Node3D, mesh: Mesh, color: Color, at := Vector3.ZERO, rot_deg := Vector3.ZERO, unshaded := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material(color, unshaded)
	mi.position = at
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func cylinder(top: float, bottom: float, height: float, sides := 24) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	return m


## Circle under allies, diamond under enemies, so team reads without color.
static func base_decal(parent: Node3D, radius: float, is_ally: bool) -> void:
	var c := Palette.team_color(is_ally)
	if is_ally:
		part(parent, cylinder(radius + 0.25, radius + 0.25, 0.03, 32), Color(c, 0.55), Vector3(0, 0.02, 0), Vector3.ZERO, true)
	else:
		# A 4-sided cylinder has its corners on the axes: a diamond.
		part(parent, cylinder(radius + 0.45, radius + 0.45, 0.03, 4), Color(c.darkened(0.45), 0.85), Vector3(0, 0.015, 0), Vector3.ZERO, true)
		part(parent, cylinder(radius + 0.3, radius + 0.3, 0.035, 4), Color(c, 0.6), Vector3(0, 0.025, 0), Vector3.ZERO, true)


static func label(parent: Node3D, text: String, height: float, font_size := 40) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = 0.01
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = Vector3(0, height, 0)
	parent.add_child(l)
	return l


## Root holds the decal and label; the "Body" child turns to face the move direction.
static func make_hero(hero: HeroState, is_ally: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Hero%d" % hero.id
	base_decal(root, hero.radius, is_ally)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	hero_body(body, hero.data.shape, Palette.team_color(is_ally))
	hero_gear(body, hero.data.shape, Palette.team_color(is_ally))
	root.set_meta("bar_height", 2.0)
	return root


## The hero silhouette alone (also used by the menu's hero showcase). The main mass is
## the team color; each hero's own accents make the silhouette.
static func hero_body(body: Node3D, shape: String, c: Color) -> void:
	var skin := Color("f1d2b6")
	match shape:
		"gunslinger":
			# Jose: long coat, wide-brimmed hat, a revolver in each hand.
			var red := Color("c22a35")
			part(body, cylinder(0.3, 0.46, 1.05, 16), c, Vector3(0, 0.53, 0))
			part(body, cylinder(0.31, 0.31, 0.12, 16), red, Vector3(0, 0.95, 0))
			var head := SphereMesh.new()
			head.radius = 0.22
			head.height = 0.44
			part(body, head, skin, Vector3(0, 1.22, 0))
			part(body, cylinder(0.62, 0.62, 0.05, 24), red.darkened(0.2), Vector3(0, 1.38, 0))
			part(body, cylinder(0.24, 0.27, 0.26, 16), red.darkened(0.2), Vector3(0, 1.5, 0))
			for side: float in [-1.0, 1.0]:
				part(body, box(Vector3(0.09, 0.14, 0.5)), Color("2b2b31"), Vector3(side * 0.42, 0.78, -0.28))
				part(body, box(Vector3(0.12, 0.12, 0.12)), Palette.ACCENT, Vector3(side * 0.42, 0.74, -0.04))
		"thief":
			# Jack: flared coat, round glasses, a few floating cards.
			var violet := Color("6d4bb3")
			part(body, cylinder(0.22, 0.55, 1.1, 20), c, Vector3(0, 0.55, 0))
			part(body, cylinder(0.3, 0.24, 0.32, 16), violet, Vector3(0, 1.0, 0))
			var head := SphereMesh.new()
			head.radius = 0.21
			head.height = 0.42
			part(body, head, skin, Vector3(0, 1.3, 0))
			part(body, cylinder(0.24, 0.2, 0.16, 16), Color("2f2a3a"), Vector3(0, 1.46, 0.02))
			part(body, box(Vector3(0.34, 0.06, 0.04)), Color("ffd84a"), Vector3(0, 1.31, -0.2))
			for k in 3:
				var ang := deg_to_rad(120.0 * k + 30.0)
				part(body, box(Vector3(0.18, 0.26, 0.02)), Palette.ACCENT, Vector3(cos(ang) * 0.75, 1.15 + 0.12 * k, sin(ang) * 0.75), Vector3(0, -rad_to_deg(ang), 12))
		_:
			# Avery: armored body over a wide skirt, a crown and a long sword.
			var gold := Color("e8c35a")
			part(body, cylinder(0.5, 0.62, 0.55, 20), Color("3a3f4a"), Vector3(0, 0.28, 0))
			part(body, box(Vector3(0.75, 0.62, 0.55)), c, Vector3(0, 0.84, 0))
			part(body, box(Vector3(0.82, 0.12, 0.6)), gold, Vector3(0, 0.6, 0))
			var head := SphereMesh.new()
			head.radius = 0.22
			head.height = 0.44
			part(body, head, skin, Vector3(0, 1.36, 0))
			part(body, cylinder(0.2, 0.2, 0.1, 6), gold, Vector3(0, 1.56, 0))
			part(body, box(Vector3(0.1, 0.1, 1.4)), Palette.ACCENT, Vector3(0.5, 0.82, -0.55))
			part(body, box(Vector3(0.36, 0.08, 0.08)), gold, Vector3(0.5, 0.82, 0.12))


## Item silhouettes, hidden until MatchView shows them: "GearMid" (a mid item: the
## weapon glows), "GearLate" (a late item: armor or clothing that changes the outline from
## above) and "GearMaster" (a Masterwork: a gold gem floating over the head).
static func hero_gear(body: Node3D, shape: String, c: Color) -> void:
	var mid := Node3D.new()
	mid.name = "GearMid"
	var late := Node3D.new()
	late.name = "GearLate"
	var master := Node3D.new()
	master.name = "GearMaster"
	for n: Node3D in [mid, late, master]:
		n.visible = false
		body.add_child(n)
	var glow := Color(1.0, 0.85, 0.35, 0.75)
	var gold := Color("e8c35a")
	match shape:
		"gunslinger":
			# Jose: guns glow hot; late, a red poncho with a gold hem and a bandolier.
			for side: float in [-1.0, 1.0]:
				part(mid, box(Vector3(0.16, 0.2, 0.6)), Color(1.0, 0.55, 0.15, 0.7), Vector3(side * 0.42, 0.78, -0.3), Vector3.ZERO, true)
			part(late, cylinder(0.26, 0.66, 0.34, 20), Color("c22a35"), Vector3(0, 0.9, 0))
			part(late, cylinder(0.67, 0.67, 0.06, 20), gold, Vector3(0, 0.74, 0))
			part(late, box(Vector3(0.1, 0.06, 0.9)), Color("6b4a2b"), Vector3(0, 1.08, 0), Vector3(0, 45, 0))
		"thief":
			# Jack: his cards glow; late, a tall top hat and a long cape.
			for k in 3:
				var ang := deg_to_rad(120.0 * k + 30.0)
				part(mid, box(Vector3(0.24, 0.32, 0.04)), Color(0.8, 0.6, 1.0, 0.7), Vector3(cos(ang) * 0.75, 1.15 + 0.12 * k, sin(ang) * 0.75), Vector3(0, -rad_to_deg(ang), 12), true)
			part(late, cylinder(0.2, 0.2, 0.42, 16), Color("2f2a3a"), Vector3(0, 1.72, 0.02))
			part(late, cylinder(0.21, 0.21, 0.08, 16), Palette.ACCENT, Vector3(0, 1.56, 0.02))
			part(late, box(Vector3(0.9, 0.06, 0.9)), Color("6d4bb3").darkened(0.25), Vector3(0, 0.95, 0.42), Vector3(-28, 0, 0))
		_:
			# Avery: the blade glows; late, gold pauldrons and a team-colored cape.
			part(mid, box(Vector3(0.18, 0.18, 1.5)), glow, Vector3(0.5, 0.82, -0.55), Vector3.ZERO, true)
			for side: float in [-1.0, 1.0]:
				part(late, box(Vector3(0.34, 0.2, 0.5)), gold, Vector3(side * 0.5, 1.15, 0))
			part(late, box(Vector3(0.85, 0.06, 0.95)), c.darkened(0.3), Vector3(0, 0.85, 0.42), Vector3(-30, 0, 0))
	var gem := SphereMesh.new()
	gem.radius = 0.16
	gem.height = 0.4
	gem.radial_segments = 4
	gem.rings = 2
	part(master, gem, Color("ffd84a"), Vector3(0, 2.25, 0), Vector3.ZERO, true)


## Root holds "Body" (pillar or gem plus the lock "Dome") and "Rubble", shown once destroyed.
static func make_structure(s: StructureState, is_ally: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Structure%d" % s.id
	base_decal(root, s.radius, is_ally)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var c := Palette.team_color(is_ally)
	var top := 0.0
	if s.tier == 2:
		# Core: faceted gem on a hex plinth.
		part(body, cylinder(s.radius, s.radius + 0.15, 0.5, 6), Palette.STONE, Vector3(0, 0.25, 0))
		var gem := SphereMesh.new()
		gem.radius = s.radius * 0.8
		gem.height = s.radius * 2.4
		gem.radial_segments = 6
		gem.rings = 2
		part(body, gem, c, Vector3(0, 0.5 + s.radius * 1.2, 0))
		top = 0.5 + s.radius * 2.4
	elif s.is_guardian():
		# Guardian: a giant stone sentinel with team-colored eyes, crown and fists.
		var h := s.data.height
		part(body, cylinder(s.radius, s.radius + 0.2, 0.4, 8), Palette.STONE.darkened(0.15), Vector3(0, 0.2, 0))
		part(body, cylinder(s.radius * 0.55, s.radius * 0.8, h * 0.6, 8), Palette.STONE, Vector3(0, 0.4 + h * 0.3, 0))
		var head := SphereMesh.new()
		head.radius = s.radius * 0.5
		head.height = s.radius
		head.radial_segments = 8
		head.rings = 4
		var head_y := 0.4 + h * 0.6 + s.radius * 0.4
		part(body, head, Palette.STONE.lightened(0.1), Vector3(0, head_y, 0))
		part(body, box(Vector3(s.radius * 0.7, 0.14, 0.12)), c.lightened(0.4), Vector3(0, head_y + 0.05, -s.radius * 0.45))
		part(body, cylinder(s.radius * 0.55, s.radius * 0.45, 0.25, 8), c, Vector3(0, head_y + s.radius * 0.5, 0))
		for side in [-1.0, 1.0]:
			part(body, cylinder(0.28, 0.32, h * 0.5, 6), Palette.STONE.darkened(0.05), Vector3(side * s.radius * 0.95, 0.4 + h * 0.35, 0), Vector3(0, 0, side * 12))
			part(body, box(Vector3(0.6, 0.55, 0.6)), c, Vector3(side * s.radius * 1.05, 0.4 + h * 0.08, 0))
		top = head_y + s.radius * 0.65
	else:
		# Towers: hex pillar with a team-colored crown.
		var h := s.data.height
		part(body, cylinder(s.radius * 0.8, s.radius * 0.95, h, 6), Palette.STONE, Vector3(0, h / 2.0, 0))
		part(body, cylinder(s.radius, s.radius * 0.85, 0.35, 6), c, Vector3(0, h + 0.17, 0))
		top = h + 0.35
	var dome := SphereMesh.new()
	dome.radius = s.radius + 0.7
	dome.height = (s.radius + 0.7) * 2.0
	var dome_node := part(body, dome, Palette.LOCK_DOME, Vector3(0, 0.2, 0), Vector3.ZERO, true)
	dome_node.name = "Dome"
	root.set_meta("bar_height", top + 0.7)
	_aggro_mark(root)
	var rubble := Node3D.new()
	rubble.name = "Rubble"
	rubble.visible = false
	root.add_child(rubble)
	for i in 6:
		var a := TAU * i / 6.0
		var size := 0.35 + 0.1 * (i % 3)
		part(rubble, box(Vector3(size, size * 0.7, size)), Palette.STONE.darkened(0.25), Vector3(cos(a) * s.radius * 0.6, size * 0.3, sin(a) * s.radius * 0.6), Vector3(0, i * 37, 0))
	return root


## Minions: small and low so they never read as heroes. Melee = puck, ranged = diamond.
static func make_minion(m: MinionState, is_ally: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Minion%d" % m.id
	var c := Palette.team_color(is_ally)
	if is_ally:
		part(root, cylinder(m.radius + 0.12, m.radius + 0.12, 0.03, 20), Color(c, 0.5), Vector3(0, 0.02, 0), Vector3.ZERO, true)
	else:
		part(root, cylinder(m.radius + 0.22, m.radius + 0.22, 0.03, 4), Color(c.darkened(0.45), 0.85), Vector3(0, 0.015, 0), Vector3.ZERO, true)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	match m.data.shape:
		"ranged":
			var d := SphereMesh.new()
			d.radius = m.radius
			d.height = m.radius * 2.6
			d.radial_segments = 4
			d.rings = 2
			part(body, d, c, Vector3(0, m.radius * 1.4, 0))
		"siege":
			part(body, cylinder(m.radius, m.radius, m.radius * 1.4, 16), c, Vector3(0, m.radius * 0.7, 0), Vector3(0, 0, 90))
			part(body, cylinder(m.radius * 0.5, m.radius * 0.5, m.radius * 1.5, 12), Palette.RELAY, Vector3(0, m.radius * 0.7, 0), Vector3(0, 0, 90), true)
		_:
			part(body, cylinder(m.radius, m.radius * 1.05, m.radius * 0.9, 16), c, Vector3(0, m.radius * 0.45, 0))
			part(body, cylinder(m.radius * 0.55, m.radius * 0.55, 0.08, 16), Palette.ACCENT, Vector3(0, m.radius * 0.94, 0))
	root.set_meta("bar_height", m.radius * 2.6 + 0.3)
	_aggro_mark(root)
	return root


## Hidden "!" that MatchView shows while the unit is called by hero-hit aggro.
static func _aggro_mark(root: Node3D) -> void:
	var mark := label(root, "!", 1.5, 72)
	mark.name = "Aggro"
	mark.outline_size = 14
	mark.visible = false
