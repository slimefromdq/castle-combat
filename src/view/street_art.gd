class_name StreetArt
## Procedural art for the street-occult look: cobble and brick textures, chalk and
## graffiti sigils, and the props that line the streets (lanterns, neon signs, tarot
## banners, shopfronts, planters). Everything is drawn in code so the build stays
## asset-free; textures are made once and cached.
##
## Floors and walls use world-space triplanar mapping, so cobbles line up across every
## box and never stretch.

enum Sigil { EYE, MOON, PENTACLE, SPIRAL, CROWN, RITUAL }

const TEX_SIZE := 256
const SIGIL_SIZE := 128

static var _cache := {}


## Running-bond stones on mortar. tile_m = metres one texture repeat covers.
## Painted stones (a few, softened toward the base) make the street feel hand-made.
static func stones(key: String, base: Color, mortar: Color, rows: int, min_w: int, max_w: int, painted: Array = [], paint_chance := 0.0, seed := 1) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	img.fill(mortar)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var row_h := TEX_SIZE / rows
	for row in rows:
		var y := row * row_h
		var x := rng.randi_range(0, max_w)
		var row_end := x + TEX_SIZE
		while x < row_end:
			var w := mini(rng.randi_range(min_w, max_w), row_end - x)
			if row_end - x - w < min_w:
				w = row_end - x  # Last stone takes the rest so the row tiles.
			var c := base.lightened(rng.randf_range(0.0, 0.07)) if rng.randf() < 0.5 else base.darkened(rng.randf_range(0.0, 0.06))
			if not painted.is_empty() and rng.randf() < paint_chance:
				c = base.lerp(painted[rng.randi() % painted.size()], 0.4)
			_stone(img, x, y, w, row_h, c)
			x += w
	var tex := ImageTexture.create_from_image(_with_mipmaps(img))
	_cache[key] = tex
	return tex


## One stone, wrapping across the right edge: inset body, light top lip, dark bottom lip.
static func _stone(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var inset := 2
	var bounds := Rect2i(0, 0, TEX_SIZE, TEX_SIZE)
	for shift in [0, -TEX_SIZE]:
		var body := Rect2i(x + shift + inset, y + inset, w - inset * 2, h - inset * 2)
		for r in [[body, c], [Rect2i(body.position, Vector2i(body.size.x, 3)), c.lightened(0.08)], [Rect2i(body.position.x, body.end.y - 3, body.size.x, 3), c.darkened(0.08)]]:
			var clipped: Rect2i = (r[0] as Rect2i).intersection(bounds)
			if clipped.has_area():
				img.fill_rect(clipped, r[1])


static func _with_mipmaps(img: Image) -> Image:
	img.generate_mipmaps()
	return img


## A material whose texture is laid in world space: tile_m metres per repeat.
static func street_material(tex: Texture2D, tint: Color, tile_m: float) -> StandardMaterial3D:
	var m := UnitFactory.material(tint)
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / tile_m
	return m


static func street_part(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# --- Sigils -------------------------------------------------------------------------

## A white sigil on a transparent square; tint it with the material colour.
static func sigil(kind: Sigil) -> ImageTexture:
	var key := "sigil_%d" % kind
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(SIGIL_SIZE, SIGIL_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var c := Vector2(SIGIL_SIZE, SIGIL_SIZE) / 2.0
	var r := SIGIL_SIZE * 0.42
	match kind:
		Sigil.EYE:
			_arc(img, c + Vector2(0, r * 0.9), r * 1.25, deg_to_rad(-135), deg_to_rad(-45), 3)
			_arc(img, c - Vector2(0, r * 0.9), r * 1.25, deg_to_rad(45), deg_to_rad(135), 3)
			_arc(img, c, r * 0.32, 0.0, TAU, 3)
			_dot(img, c, 7)
			for i in 5:
				var a := deg_to_rad(-150 + i * 30)
				_line(img, c + Vector2(cos(a), sin(a)) * r * 0.62, c + Vector2(cos(a), sin(a)) * r * 0.92, 2)
		Sigil.MOON:
			_arc(img, c, r * 0.8, deg_to_rad(60), deg_to_rad(300), 4)
			_arc(img, c + Vector2(r * 0.32, 0), r * 0.62, deg_to_rad(72), deg_to_rad(288), 3)
			_star(img, c + Vector2(r * 0.55, -r * 0.45), r * 0.22, 5, 2)
		Sigil.PENTACLE:
			_arc(img, c, r, 0.0, TAU, 3)
			_star(img, c, r * 0.92, 5, 3)
		Sigil.SPIRAL:
			var prev := c
			for i in 220:
				var t := i / 220.0
				var a := t * TAU * 3.0
				var p := c + Vector2(cos(a), sin(a)) * r * t
				_line(img, prev, p, 3)
				prev = p
		Sigil.CROWN:
			var pts := [Vector2(-1, 0.4), Vector2(-0.8, -0.5), Vector2(-0.35, 0.05), Vector2(0, -0.75), Vector2(0.35, 0.05), Vector2(0.8, -0.5), Vector2(1, 0.4)]
			for i in pts.size() - 1:
				_line(img, c + pts[i] * r * 0.9, c + pts[i + 1] * r * 0.9, 4)
			_line(img, c + Vector2(-1, 0.62) * r * 0.9, c + Vector2(1, 0.62) * r * 0.9, 3)
			for p in [Vector2(-0.8, -0.5), Vector2(0, -0.75), Vector2(0.8, -0.5)]:
				_dot(img, c + p * r * 0.9 + Vector2(0, -9), 5)
		Sigil.RITUAL:
			# Chalk ritual circle: double ring, hexagram, tick marks.
			_arc(img, c, r * 1.12, 0.0, TAU, 2)
			_arc(img, c, r * 0.98, 0.0, TAU, 2)
			for i in 24:
				var a := TAU * i / 24.0
				_line(img, c + Vector2(cos(a), sin(a)) * r * 0.98, c + Vector2(cos(a), sin(a)) * r * (1.12 if i % 2 == 0 else 1.05), 1)
			for k in 2:
				var tri: Array[Vector2] = []
				for i in 3:
					var a := TAU * i / 3.0 + k * PI - PI / 2.0
					tri.append(c + Vector2(cos(a), sin(a)) * r * 0.98)
				for i in 3:
					_line(img, tri[i], tri[(i + 1) % 3], 1)
	var tex := ImageTexture.create_from_image(_with_mipmaps(img))
	_cache[key] = tex
	return tex


static func _dot(img: Image, p: Vector2, size: int) -> void:
	var rect := Rect2i(int(p.x) - size / 2, int(p.y) - size / 2, size, size).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if rect.has_area():
		img.fill_rect(rect, Color.WHITE)


static func _line(img: Image, a: Vector2, b: Vector2, width: int) -> void:
	var steps := maxi(1, int(a.distance_to(b) / 1.2))
	for i in steps + 1:
		_dot(img, a.lerp(b, float(i) / steps), width + 1)


static func _arc(img: Image, c: Vector2, r: float, from: float, to: float, width: int) -> void:
	var steps := maxi(8, int(r * absf(to - from) / 1.5))
	var prev := c + Vector2(cos(from), sin(from)) * r
	for i in range(1, steps + 1):
		var a := lerpf(from, to, float(i) / steps)
		var p := c + Vector2(cos(a), sin(a)) * r
		_line(img, prev, p, width)
		prev = p


static func _star(img: Image, c: Vector2, r: float, points: int, width: int) -> void:
	var tips: Array[Vector2] = []
	for i in points:
		var a := TAU * i / points - PI / 2.0
		tips.append(c + Vector2(cos(a), sin(a)) * r)
	for i in points:
		_line(img, tips[i], tips[(i + 2) % points], width)


## A flat sigil decal lying on the ground.
static func floor_sigil(parent: Node3D, kind: Sigil, color: Color, at: Vector3, size: float, yaw_deg := 0.0) -> MeshInstance3D:
	var quad := PlaneMesh.new()
	quad.size = Vector2(size, size)
	var m := _sigil_material(kind, color)
	var mi := street_part(parent, quad, m, at)
	mi.rotation_degrees = Vector3(0, yaw_deg, 0)
	return mi


## An upright sigil (signs, banners), readable from both camera seats.
static func wall_sigil(parent: Node3D, kind: Sigil, color: Color, at: Vector3, size: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mi := street_part(parent, quad, _sigil_material(kind, color), at)
	return mi


static func _sigil_material(kind: Sigil, color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = sigil(kind)
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# --- Props --------------------------------------------------------------------------
# Props are built facing the camera of both seats: fronts face +Z and -Z alike.

const IRON := Color("4a3a5e")
const LANTERN_GLOW := Color("ffe08a")
const NEON := [Color("ff5fc8"), Color("4ff0d6"), Color("fff06a"), Color("c38bff")]
const PAINT := [Color("e27aa0"), Color("4fb3a5"), Color("e3bd57"), Color("a58ad6"), Color("e8d6ae"), Color("7cc78a")]


## A street lantern on a plum iron post (1.7 m), glowing warm.
static func lantern(parent: Node3D, at: Vector3) -> void:
	UnitFactory.part(parent, UnitFactory.cylinder(0.05, 0.07, 1.6, 6), IRON, at + Vector3(0, 0.8, 0))
	UnitFactory.part(parent, UnitFactory.cylinder(0.14, 0.18, 0.08, 6), IRON, at + Vector3(0, 0.04, 0))
	UnitFactory.part(parent, UnitFactory.box(Vector3(0.26, 0.32, 0.26)), LANTERN_GLOW, at + Vector3(0, 1.72, 0), Vector3.ZERO, true)
	UnitFactory.part(parent, UnitFactory.cylinder(0.0, 0.24, 0.16, 4), IRON, at + Vector3(0, 1.96, 0), Vector3(0, 45, 0))
	UnitFactory.part(parent, UnitFactory.cylinder(0.5, 0.5, 0.01, 20), Color(LANTERN_GLOW, 0.16), at + Vector3(0, 0.02, 0), Vector3.ZERO, true)


## A little shop: painted brick box, contrasting roof, glowing windows, striped awning
## and a neon sigil over the door, on both faces.
static func shopfront(parent: Node3D, at: Vector3, size: Vector3, paint: Color, roof: Color, neon: Color, kind: Sigil) -> void:
	var brick := stones("shop_brick", Color("f4ece0"), Color("c9bba8"), 16, 22, 34, [], 0.0, 11)
	street_part(parent, UnitFactory.box(size), street_material(brick, paint, 2.0), at + Vector3(0, size.y / 2.0, 0))
	UnitFactory.part(parent, UnitFactory.box(Vector3(size.x + 0.2, 0.18, size.z + 0.2)), roof, at + Vector3(0, size.y + 0.09, 0))
	UnitFactory.part(parent, UnitFactory.box(Vector3(size.x * 0.5, 0.3, size.z * 0.5)), roof.darkened(0.15), at + Vector3(0, size.y + 0.33, 0))
	for face in [-1.0, 1.0]:
		var z: float = face * (size.z / 2.0 + 0.02)
		var door_x := -size.x * 0.22
		UnitFactory.part(parent, UnitFactory.box(Vector3(0.5, 0.95, 0.04)), roof.darkened(0.35), at + Vector3(door_x, 0.48, z))
		UnitFactory.part(parent, UnitFactory.box(Vector3(0.6, 0.5, 0.04)), LANTERN_GLOW, at + Vector3(size.x * 0.22, 0.85, z), Vector3.ZERO, true)
		# Striped awning over the window.
		for s in 4:
			var stripe := Color("fdf6ea") if s % 2 == 0 else paint.darkened(0.2)
			UnitFactory.part(parent, UnitFactory.box(Vector3(0.18, 0.05, 0.36)), stripe, at + Vector3(size.x * 0.22 - 0.27 + s * 0.18, 1.2, z + face * 0.16), Vector3(face * -18, 0, 0))
		var sign_at := at + Vector3(door_x, minf(size.y - 0.35, 1.5), z + face * 0.02)
		UnitFactory.part(parent, UnitFactory.box(Vector3(0.62, 0.62, 0.03)), Color("2e2347"), sign_at - Vector3(0, 0, face * 0.02))
		wall_sigil(parent, kind, neon, sign_at + Vector3(0, 0, face * 0.005), 0.55)


## A tarot banner hanging from an iron pole: cream cloth, coloured border, a sigil.
static func banner(parent: Node3D, at: Vector3, color: Color, kind: Sigil) -> void:
	UnitFactory.part(parent, UnitFactory.cylinder(0.04, 0.05, 2.1, 6), IRON, at + Vector3(0, 1.05, 0))
	UnitFactory.part(parent, UnitFactory.box(Vector3(0.8, 0.05, 0.05)), IRON, at + Vector3(0.36, 2.05, 0))
	UnitFactory.part(parent, UnitFactory.box(Vector3(0.62, 0.96, 0.03)), color, at + Vector3(0.4, 1.5, 0))
	UnitFactory.part(parent, UnitFactory.box(Vector3(0.5, 0.82, 0.04)), Color("f6ead0"), at + Vector3(0.4, 1.5, 0))
	wall_sigil(parent, kind, color.darkened(0.2), at + Vector3(0.4, 1.52, 0.03), 0.44)
	wall_sigil(parent, kind, color.darkened(0.2), at + Vector3(0.4, 1.52, -0.03), 0.44)


## A round stone planter with a lollipop tree.
static func planter(parent: Node3D, at: Vector3, leaf: Color, scale := 1.0) -> void:
	UnitFactory.part(parent, UnitFactory.cylinder(0.42, 0.36, 0.38, 10), Color("cbbfae"), at + Vector3(0, 0.19, 0))
	UnitFactory.part(parent, UnitFactory.cylinder(0.08, 0.1, 0.9 * scale, 6), Color("7a5236"), at + Vector3(0, 0.38 + 0.45 * scale, 0))
	var crown := SphereMesh.new()
	crown.radius = 0.55 * scale
	crown.height = 1.0 * scale
	crown.radial_segments = 10
	crown.rings = 5
	UnitFactory.part(parent, crown, leaf, at + Vector3(0, 0.38 + 1.15 * scale, 0))
