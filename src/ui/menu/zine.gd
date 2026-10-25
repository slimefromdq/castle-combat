class_name Zine
## The main menu's look: Clash Royale layout, handmade-zine materials. Bright cut paper,
## thick ink lines, hard shadows, tape, halftone dots and hand-lettered type.

const PAPER := Color("f6ecd6")
const KRAFT := Color("d8b88a")
const INK := Color("1d1a24")
const PINK := Color("ff5d8f")
const SUN := Color("ffcf3a")
const TEAL := Color("2ec4b6")
const COBALT := Color("3e6cf7")
const TANGERINE := Color("ff8a3d")
const MINT := Color("a6e3a1")
const LILAC := Color("b9a2ff")
const WHITE := Color("fffdf7")
const TAPE := Color(1.0, 0.98, 0.85, 0.62)
## Item tiers: early, mid, late.
const TIER_COLORS: Array[Color] = [Color("9fe0ff"), Color("ffd27a"), Color("f3a6ff")]
const TIER_NAMES: Array[String] = ["Early", "Mid", "Late"]

## Chunky display type (CR's "Battle" button), marker lettering, handwriting.
const DISPLAY: FontFile = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const MARKER: FontFile = preload("res://assets/fonts/PermanentMarker-Regular.ttf")
const HAND: FontFile = preload("res://assets/fonts/PatrickHand-Regular.ttf")


static func label(text: String, font: Font, size: int, color := INK, outline := 0, outline_color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", outline_color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A sticker panel (PanelContainer wearing a ZineBox).
static func panel(fill: Color, seed_value: int, margin := 14.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ZineBox.make(fill, seed_value, margin))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## A sticker button: sits down onto its shadow when pressed.
static func button(text: String, fill: Color, seed_value: int, font: Font = DISPLAY, size := 30, min_size := Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, WHITE if font == DISPLAY else INK)
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.55))
	if font == DISPLAY:
		b.add_theme_constant_override("outline_size", maxi(6, size / 5))
		b.add_theme_color_override("font_outline_color", INK)
	style_button(b, fill, seed_value)
	return b


static func style_button(b: Button, fill: Color, seed_value: int, margin := 10.0) -> void:
	var normal := ZineBox.make(fill, seed_value, margin)
	normal.content_margin_right = margin + normal.shadow.x
	normal.content_margin_bottom = margin + normal.shadow.y
	var hover := normal.copy()
	hover.fill = fill.lightened(0.12)
	var down := normal.copy()
	down.pressed = true
	down.fill = fill.darkened(0.08)
	down.content_margin_left = margin + normal.shadow.x * 0.7
	down.content_margin_top = margin + normal.shadow.y * 0.7
	down.content_margin_right = margin + normal.shadow.x * 0.3
	down.content_margin_bottom = margin + normal.shadow.y * 0.3
	var off := normal.copy()
	off.fill = fill.lerp(Color("c9c2b4"), 0.75)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("hover_pressed", down)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## A polygon with a torn-paper edge, following `outline` (closed, clockwise).
static func torn(outline: PackedVector2Array, rng: RandomNumberGenerator, step := 16.0, rough := 5.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var n := maxi(1, int(a.distance_to(b) / step))
		var normal := (b - a).orthogonal().normalized()
		for k in n:
			out.append(a.lerp(b, float(k) / n) + normal * rng.randf_range(-rough, rough))
	return out


## A blobby shape for collage scraps.
static func blob(center: Vector2, radius: Vector2, rng: RandomNumberGenerator, points := 14) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points:
		var a := TAU * i / points
		var r := rng.randf_range(0.78, 1.12)
		out.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y) * r)
	return out


## A five-point doodle star (outline only).
static func star_points(center: Vector2, r: float, rot := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 11:
		var a := rot - PI / 2.0 + TAU * i / 10.0
		out.append(center + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	return out


## A sunburst behind showcase pieces (alternating wedges).
static func draw_burst(ci: CanvasItem, center: Vector2, r: float, a: Color, b: Color, rays := 18, spin := 0.0) -> void:
	ci.draw_circle(center, r, b)
	for i in rays:
		var a0 := spin + TAU * i / rays
		var a1 := spin + TAU * (i + 0.5) / rays
		ci.draw_colored_polygon(PackedVector2Array([center, center + Vector2(cos(a0), sin(a0)) * r, center + Vector2(cos(a1), sin(a1)) * r]), a)
