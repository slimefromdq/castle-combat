class_name Noir
## The UI look: Persona-style retro noir in yellow, black and white. Skewed slabs with
## hard offset shadows, halftone dots, condensed display type and ransom-note lettering
## for the big moments. High contrast so it reads on a phone. Team colours (blue you,
## orange them) stay only where they tell you whose bar is whose.

const YELLOW := Color("ffd60a")
## Back buildings, halftone on yellow, pressed yellow.
const YELLOW_DEEP := Color("c9a300")
const INK := Color("0b0b0b")
const WHITE := Color("ffffff")
## Empty bars, locked cards.
const SMOKE := Color("3a3a3a")
## Secondary text on black.
const ASH := Color("bdbdbd")

## Item tiers: early white, mid yellow, late black (yellow lettering).
const TIER_COLORS: Array[Color] = [WHITE, YELLOW, INK]
const TIER_NAMES: Array[String] = ["Early", "Mid", "Late"]

## Condensed display slabs (PLAY, titles, numbers).
const SLAB: FontFile = preload("res://assets/fonts/noir/Anton-Regular.ttf")
## Heavy grotesque and fat serif, mixed with SLAB in ransom lettering.
const BLOCK: FontFile = preload("res://assets/fonts/noir/ArchivoBlack-Regular.ttf")
const SERIF: FontFile = preload("res://assets/fonts/noir/AbrilFatface-Regular.ttf")


static var _slanted := {}


## A font leaned forward like a speed slab (Anton has no italic of its own).
static func slanted(f: Font, lean := 0.2) -> Font:
	var key := "%d:%.2f" % [f.get_instance_id(), lean]
	if not _slanted.has(key):
		var v := FontVariation.new()
		v.base_font = f
		v.variation_transform = Transform2D(Vector2(1, lean), Vector2(0, 1), Vector2.ZERO)
		_slanted[key] = v
	return _slanted[key]


## Body text: Barlow Condensed Bold, the same family as the gameplay HUD.
static func body() -> Font:
	return HeroLettering.hud_bold()


## Lettering that reads on a fill: black on light, yellow on black.
static func ink_on(fill: Color) -> Color:
	return INK if fill.get_luminance() > 0.4 else YELLOW


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


## A slab panel (PanelContainer wearing a NoirBox).
static func panel(fill: Color, margin := 14.0, skew := 10.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", NoirBox.make(fill, margin, skew))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## A slab button: drops onto its shadow when pressed.
static func button(text: String, fill: Color, font: Font = SLAB, size := 30, min_size := Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", size)
	var ink := ink_on(fill)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, ink)
	b.add_theme_color_override("font_disabled_color", Color(ink, 0.5))
	style_button(b, fill)
	return b


static func style_button(b: Button, fill: Color, margin := 10.0, skew := 12.0) -> void:
	var normal := NoirBox.make(fill, margin, skew)
	if fill.get_luminance() < 0.2:
		normal.border_color = WHITE  # A black slab on black still shows its edge.
	var hover := normal.copy()
	hover.fill = fill.lightened(0.1) if fill.get_luminance() < 0.5 else fill.darkened(0.04)
	var down := normal.copy()
	down.pressed = true
	var off := normal.copy()
	off.fill = fill.lerp(SMOKE, 0.7)
	off.shadow = Vector2.ZERO
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("hover_pressed", down)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Halftone dots over a rect, biggest at `from` and fading out toward `to` (0..1 of
## the rect). Drawn on a 30° grid like print.
static func draw_halftone(ci: CanvasItem, r: Rect2, color: Color, step := 10.0, max_radius := 2.6, from := Vector2(1, 1), to := Vector2(0, 0)) -> void:
	var span := (to - from).length()
	var y := 0.0
	var row := 0
	while y < r.size.y:
		var x := (step * 0.5) if row % 2 else 0.0
		while x < r.size.x:
			var uv := Vector2(x, y) / r.size
			var k := 1.0 - clampf((uv - from).length() / maxf(span, 0.001), 0.0, 1.0)
			var rad := k * max_radius
			if rad > 0.5:
				ci.draw_circle(r.position + Vector2(x, y), rad, color)
			x += step
		y += step * 0.866
		row += 1


## A five-point star (filled), for flourishes.
static func star_points(center: Vector2, r: float, rot := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 10:
		var a := rot - PI / 2.0 + TAU * i / 10.0
		out.append(center + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	return out


## A row of black city blocks standing on the line from `a` to `b` (left to right),
## each with a white cut edge and a few lit yellow window slits. Shared by the VS
## intro and the victory card so they echo the menu skyline.
static func draw_city(ci: CanvasItem, a: Vector2, b: Vector2, min_h: float, max_h: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var x := a.x - rng.randf_range(0, 30)
	while x < b.x:
		var w := rng.randf_range(30, 70)
		var t := clampf((x + w * 0.5 - a.x) / maxf(1.0, b.x - a.x), 0.0, 1.0)
		var base := lerpf(a.y, b.y, t) + 20.0
		var h := rng.randf_range(min_h, max_h)
		var r := Rect2(x, base - h, w - 5, h)
		ci.draw_rect(r.grow(3), WHITE)
		ci.draw_rect(r, INK)
		var y := r.position.y + 10.0
		while y < base - 24.0:
			var wx := r.position.x + 5.0
			while wx < r.end.x - 10.0:
				var ww := rng.randf_range(5, 14)
				if rng.randf() < 0.3:
					ci.draw_rect(Rect2(wx, y, minf(ww, r.end.x - 5.0 - wx), 3), YELLOW)
				wx += ww + 4.0
			y += rng.randf_range(10, 15)
		x += w
