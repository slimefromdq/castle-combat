class_name RansomText
extends Control
## Cut-out letters, each on its own crooked scrap of paper in a mix of fonts:
## the zine version of a game logo.

var text := ""
var font_size := 52
var text_seed := 1
var fills: Array = [Zine.WHITE, Zine.SUN, Zine.PINK, Zine.TEAL, Zine.WHITE, Zine.LILAC, Zine.MINT, Zine.TANGERINE]
var _glyphs: Array[Dictionary] = []


static func make(t: String, size_px := 52, seed_value := 1) -> RansomText:
	var r := RansomText.new()
	r.text = t
	r.font_size = size_px
	r.text_seed = seed_value
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _ready() -> void:
	_layout()
	resized.connect(queue_redraw)


func _layout() -> void:
	_glyphs.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = text_seed
	var fonts: Array[Font] = [Zine.DISPLAY, Zine.MARKER, Zine.DISPLAY, Zine.HAND]
	var x := 0.0
	var h := font_size * 1.25
	for i in text.length():
		var ch := text[i]
		if ch == " ":
			x += font_size * 0.35
			continue
		var f: Font = fonts[rng.randi() % fonts.size()]
		var fs := int(font_size * rng.randf_range(0.82, 1.05) * (1.15 if f == Zine.HAND else 1.0))
		var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var box_w := maxf(w + font_size * 0.28, font_size * 0.62)
		var fill: Color = fills[rng.randi() % fills.size()]
		_glyphs.append({
			"ch": ch, "font": f, "size": fs, "x": x, "w": box_w, "fill": fill,
			"rot": rng.randf_range(-0.14, 0.14), "dy": rng.randf_range(-font_size * 0.08, font_size * 0.08),
			"ink": Zine.INK if fill.get_luminance() > 0.45 else Zine.WHITE,
		})
		x += box_w + font_size * 0.04
	custom_minimum_size = Vector2(x, h + font_size * 0.25)
	queue_redraw()


func _draw() -> void:
	var total := custom_minimum_size.x
	var ox := (size.x - total) * 0.5
	var h := font_size * 1.18
	for g in _glyphs:
		var c := Vector2(ox + g.x + g.w * 0.5, size.y * 0.5 + g.dy)
		draw_set_transform(c, g.rot, Vector2.ONE)
		var r := Rect2(Vector2(-g.w * 0.5, -h * 0.5), Vector2(g.w, h))
		draw_rect(Rect2(r.position + Vector2(4, 5), r.size), Zine.INK)
		draw_rect(r, g.fill)
		draw_rect(r, Zine.INK, false, 2.5)
		var f: Font = g.font
		var asc := f.get_ascent(g.size)
		var desc := f.get_descent(g.size)
		var sw := f.get_string_size(g.ch, HORIZONTAL_ALIGNMENT_LEFT, -1, g.size).x
		draw_string(f, Vector2(-sw * 0.5, (asc - desc) * 0.5), g.ch, HORIZONTAL_ALIGNMENT_LEFT, -1, g.size, g.ink)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
