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
		"sailor":
			# Ahab: a heavy pea coat, a captain's cap, a hook arm and a harpoon on his back.
			var navy := Color("24324f")
			part(body, cylinder(0.42, 0.55, 1.0, 20), c, Vector3(0, 0.5, 0))
			part(body, box(Vector3(0.95, 0.3, 0.6)), navy, Vector3(0, 1.02, 0))
			var head := SphereMesh.new()
			head.radius = 0.23
			head.height = 0.46
			part(body, head, skin, Vector3(0, 1.36, 0))
			part(body, cylinder(0.24, 0.26, 0.2, 16), Color("e9e5d8"), Vector3(0, 1.38, 0.12))
			part(body, cylinder(0.27, 0.27, 0.12, 16), navy, Vector3(0, 1.56, 0))
			part(body, box(Vector3(0.36, 0.03, 0.14)), Color("1a1a1a"), Vector3(0, 1.52, -0.26))
			part(body, box(Vector3(0.08, 0.08, 0.4)), Color("9aa3ad"), Vector3(-0.55, 0.85, -0.25))
			part(body, cylinder(0.02, 0.07, 0.22, 8), Color("c9d1d9"), Vector3(-0.55, 0.95, -0.48), Vector3(0, 0, 0))
			part(body, box(Vector3(0.06, 0.06, 1.7)), Color("6b4a2b"), Vector3(0.3, 1.0, 0.3), Vector3(35, 0, 20))
		"hunter":
			# Slayer: a long hooded coat, a crossbow on the arm and a belt of knives.
			var leather := Color("5a3d28")
			part(body, cylinder(0.26, 0.48, 1.08, 16), c, Vector3(0, 0.54, 0))
			part(body, cylinder(0.34, 0.34, 0.1, 16), leather, Vector3(0, 0.72, 0))
			for k in 5:
				var ang := deg_to_rad(-60.0 + 30.0 * k)
				part(body, box(Vector3(0.04, 0.2, 0.06)), Color("c9d1d9"), Vector3(sin(ang) * 0.36, 0.72, -cos(ang) * 0.36))
			var head := SphereMesh.new()
			head.radius = 0.21
			head.height = 0.42
			part(body, head, skin, Vector3(0, 1.26, 0))
			part(body, cylinder(0.06, 0.3, 0.5, 12), leather.darkened(0.3), Vector3(0, 1.38, 0.05))
			part(body, box(Vector3(0.1, 0.1, 0.55)), leather, Vector3(0.42, 0.85, -0.3))
			part(body, box(Vector3(0.6, 0.04, 0.06)), Color("2b2b31"), Vector3(0.42, 0.88, -0.52))
		"swarm":
			# Huddle: no body at all, just a buzzing knot of yellow bugs around a dark core.
			var core := SphereMesh.new()
			core.radius = 0.28
			core.height = 0.56
			part(body, core, c.darkened(0.35), Vector3(0, 0.9, 0))
			var bug := SphereMesh.new()
			bug.radius = 0.09
			bug.height = 0.14
			bug.radial_segments = 8
			bug.rings = 4
			for k in 22:
				var a := k * 2.39996
				var y := 0.35 + float(k % 7) * 0.17
				var r := 0.32 + 0.22 * float((k * 5) % 3) / 2.0
				part(body, bug, Color("ffd23a") if k % 3 else Color("e3a91a"), Vector3(cos(a) * r, y, sin(a) * r))
			part(body, cylinder(0.5, 0.5, 0.04, 24), c, Vector3(0, 0.05, 0))
		"doll":
			# Poppet: a porcelain doll in a puffed dress, button eyes, a big bow and a wind-up key.
			var pink := Color("e88fb0")
			var porcelain := Color("f6eee8")
			part(body, cylinder(0.12, 0.5, 0.72, 20), c, Vector3(0, 0.36, 0))
			part(body, cylinder(0.5, 0.5, 0.06, 20), pink, Vector3(0, 0.05, 0))
			part(body, cylinder(0.15, 0.13, 0.3, 12), porcelain, Vector3(0, 0.84, 0))
			var head := SphereMesh.new()
			head.radius = 0.3
			head.height = 0.6
			part(body, head, porcelain, Vector3(0, 1.22, 0))
			for side: float in [-1.0, 1.0]:
				part(body, cylinder(0.06, 0.06, 0.03, 10), Color("1a1a1a"), Vector3(side * 0.11, 1.26, -0.27), Vector3(90, 0, 0))
				part(body, box(Vector3(0.24, 0.16, 0.08)), pink, Vector3(side * 0.16, 1.55, 0.05), Vector3(0, 0, side * 20))
			part(body, box(Vector3(0.04, 0.04, 0.3)), Color("c9a43a"), Vector3(0, 0.85, 0.3))
			part(body, box(Vector3(0.3, 0.14, 0.04)), Color("c9a43a"), Vector3(0, 0.85, 0.46))
			part(body, box(Vector3(0.05, 0.05, 0.45)), Color("c9d1d9"), Vector3(0.36, 0.72, -0.3))
		"emperor":
			# Tot: a tall black-and-gold emperor in a high-collared mantle with a broadsword.
			var gold := Color("e8c35a")
			var black := Color("1d1a22")
			part(body, cylinder(0.4, 0.66, 1.1, 24), black, Vector3(0, 0.55, 0))
			part(body, box(Vector3(0.7, 0.55, 0.5)), c, Vector3(0, 1.0, 0))
			part(body, cylinder(0.34, 0.24, 0.32, 16), gold, Vector3(0, 1.36, 0.06))
			var head := SphereMesh.new()
			head.radius = 0.21
			head.height = 0.42
			part(body, head, Color("d9cfc7"), Vector3(0, 1.48, 0))
			for k in 5:
				var ang := deg_to_rad(-60.0 + 30.0 * k)
				part(body, box(Vector3(0.05, 0.18, 0.05)), gold, Vector3(sin(ang) * 0.17, 1.72, -cos(ang) * 0.17))
			part(body, box(Vector3(0.16, 0.08, 1.6)), Color("c9d1d9"), Vector3(0.55, 0.85, -0.55))
			part(body, box(Vector3(0.5, 0.1, 0.1)), gold, Vector3(0.55, 0.85, 0.22))
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
		"sailor":
			# Ahab: the hook glows; late, a heavy oilskin cloak and a tall collar.
			part(mid, cylinder(0.04, 0.11, 0.3, 8), glow, Vector3(-0.55, 0.95, -0.48), Vector3.ZERO, true)
			part(late, cylinder(0.5, 0.72, 0.5, 20), Color("c8a64a"), Vector3(0, 0.95, 0.05))
			part(late, cylinder(0.32, 0.3, 0.22, 16), Color("c8a64a").darkened(0.2), Vector3(0, 1.3, 0.05))
		"hunter":
			# Slayer: the crossbow glows; late, a wide-brimmed hunter's hat and a fur mantle.
			part(mid, box(Vector3(0.7, 0.08, 0.1)), glow, Vector3(0.42, 0.88, -0.52), Vector3.ZERO, true)
			part(late, cylinder(0.58, 0.58, 0.05, 20), Color("3a2a1c"), Vector3(0, 1.5, 0))
			part(late, cylinder(0.5, 0.36, 0.25, 16), Color("8a7258"), Vector3(0, 1.05, 0.05))
		"swarm":
			# Huddle: the core glows; late, a wider ring of bugs.
			var core := SphereMesh.new()
			core.radius = 0.32
			core.height = 0.64
			part(mid, core, Color(1.0, 0.85, 0.2, 0.6), Vector3(0, 0.9, 0), Vector3.ZERO, true)
			var bug := SphereMesh.new()
			bug.radius = 0.08
			bug.height = 0.12
			for k in 12:
				var a := TAU * k / 12.0
				part(late, bug, Color("ffd23a"), Vector3(cos(a) * 0.78, 0.6 + 0.25 * float(k % 2), sin(a) * 0.78))
		"doll":
			# Poppet: the scissors glow; late, a lace parasol overhead.
			part(mid, box(Vector3(0.1, 0.1, 0.5)), glow, Vector3(0.36, 0.72, -0.3), Vector3.ZERO, true)
			part(late, cylinder(0.05, 0.62, 0.22, 20), Color("e88fb0").lightened(0.3), Vector3(-0.2, 1.85, 0.1))
			part(late, box(Vector3(0.03, 0.8, 0.03)), Color("6b4a2b"), Vector3(-0.2, 1.4, 0.1))
		"emperor":
			# Tot: the broadsword glows; late, a gold mantle and a tall red cape.
			part(mid, box(Vector3(0.24, 0.14, 1.7)), glow, Vector3(0.55, 0.85, -0.55), Vector3.ZERO, true)
			for side: float in [-1.0, 1.0]:
				part(late, box(Vector3(0.36, 0.22, 0.52)), gold, Vector3(side * 0.48, 1.22, 0))
			part(late, box(Vector3(0.9, 0.06, 1.1)), Color("8a1c24"), Vector3(0, 0.85, 0.48), Vector3(-30, 0, 0))
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
		"sapper":
			# Sapper: a squat puck carrying a black bomb with a lit fuse.
			part(body, cylinder(m.radius, m.radius * 1.05, m.radius * 0.8, 16), c, Vector3(0, m.radius * 0.4, 0))
			var bomb := SphereMesh.new()
			bomb.radius = m.radius * 0.6
			bomb.height = m.radius * 1.2
			part(body, bomb, Color("26232b"), Vector3(0, m.radius * 1.3, 0.05))
			part(body, cylinder(0.04, 0.04, 0.22, 6), Color("8a6a3a"), Vector3(0, m.radius * 1.9 + 0.08, 0.05))
			part(body, cylinder(0.08, 0.08, 0.08, 8), Color("ffb03a"), Vector3(0, m.radius * 1.9 + 0.22, 0.05), Vector3.ZERO, true)
		"shieldbearer":
			# Shieldbearer: a tall puck behind a big tower shield (the shield goes once it blocks).
			part(body, cylinder(m.radius * 0.9, m.radius, m.radius * 1.4, 16), c, Vector3(0, m.radius * 0.7, 0))
			var shield := part(body, box(Vector3(m.radius * 2.6, m.radius * 2.2, 0.12)), c.lightened(0.45), Vector3(0, m.radius * 1.0, -m.radius - 0.12))
			shield.name = "Shield"
			part(shield, box(Vector3(0.12, m.radius * 1.6, 0.04)), Palette.ACCENT, Vector3(0, 0, -0.07))
		"siege":
			part(body, cylinder(m.radius, m.radius, m.radius * 1.4, 16), c, Vector3(0, m.radius * 0.7, 0), Vector3(0, 0, 90))
			part(body, cylinder(m.radius * 0.5, m.radius * 0.5, m.radius * 1.5, 12), Palette.RELAY, Vector3(0, m.radius * 0.7, 0), Vector3(0, 0, 90), true)
		_:
			part(body, cylinder(m.radius, m.radius * 1.05, m.radius * 0.9, 16), c, Vector3(0, m.radius * 0.45, 0))
			part(body, cylinder(m.radius * 0.55, m.radius * 0.55, 0.08, 16), Palette.ACCENT, Vector3(0, m.radius * 0.94, 0))
	root.set_meta("bar_height", m.radius * 2.6 + 0.3)
	_aggro_mark(root)
	# Banner wave: a small gold flag on every trooper of the buffed wave.
	var flag := Node3D.new()
	flag.name = "Flag"
	flag.visible = false
	root.add_child(flag)
	part(flag, cylinder(0.03, 0.03, 0.9, 6), Color("6b4a2b"), Vector3(0.25, m.radius * 1.4 + 0.45, 0.2))
	part(flag, box(Vector3(0.36, 0.24, 0.03)), Color("f5d76e"), Vector3(0.44, m.radius * 1.4 + 0.75, 0.2), Vector3.ZERO, true)
	return root


## A banner on the ground (dropped by a special trooper): a pole with a gold flag.
static func make_banner(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	part(root, cylinder(0.07, 0.08, 2.4, 8), Color("6b4a2b"), Vector3(0, 1.2, 0))
	part(root, box(Vector3(1.1, 0.8, 0.05)), Color("f5d76e"), Vector3(0.56, 2.0, 0), Vector3.ZERO, true)
	part(root, box(Vector3(1.1, 0.12, 0.06)), Palette.ACCENT, Vector3(0.56, 1.62, 0), Vector3.ZERO, true)
	part(root, cylinder(1.0, 1.0, 0.03, 32), Color(0.96, 0.84, 0.43, 0.35), Vector3(0, 0.03, 0), Vector3.ZERO, true)
	return root


## Hidden "!" that MatchView shows while the unit is called by hero-hit aggro.
static func _aggro_mark(root: Node3D) -> void:
	var mark := label(root, "!", 1.5, 72)
	mark.name = "Aggro"
	mark.outline_size = 14
	mark.visible = false
