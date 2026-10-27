class_name RansomText
extends Control
## Ransom-note lettering: each letter cut from a different print, on its own tilted
## tile of black, white or yellow, in a mix of slab, grotesque and fat serif. Used for
## the big moments only (logo, VS, VICTORY), so the rest of the UI stays easy to read.

var text := ""
var font_size := 52
var text_seed := 1
var fills: Array = [Noir.INK, Noir.WHITE, Noir.YELLOW, Noir.INK, Noir.WHITE]
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
	var fonts: Array[Font] = [Noir.SLAB, Noir.SERIF, Noir.BLOCK, Noir.SLAB]
	var x := 0.0
	var h := font_size * 1.25
	var last_fill := Color.TRANSPARENT
	for i in text.length():
		var ch := text[i]
		if ch == " ":
			x += font_size * 0.3
			continue
		var f: Font = fonts[rng.randi() % fonts.size()]
		var fs := int(font_size * rng.randf_range(0.82, 1.06) * (0.86 if f == Noir.BLOCK else 1.0))
		# Serif letters go lower case now and then, like clippings.
		if f == Noir.SERIF and rng.randf() < 0.4:
			ch = ch.to_lower()
		var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var box_w := maxf(w + font_size * 0.24, font_size * 0.56)
		var fill: Color = fills[rng.randi() % fills.size()]
		if fill == last_fill:
			fill = fills[(fills.find(fill) + 1) % fills.size()]
		last_fill = fill
		var dark := fill.get_luminance() < 0.2
		_glyphs.append({
			"ch": ch, "font": f, "size": fs, "x": x, "w": box_w, "fill": fill,
			"rot": rng.randf_range(-0.13, 0.13), "dy": rng.randf_range(-font_size * 0.08, font_size * 0.08),
			"ink": (Noir.YELLOW if rng.randf() < 0.6 else Noir.WHITE) if dark else Noir.INK,
			"edge": Noir.WHITE if dark else Noir.INK,
		})
		x += box_w + font_size * 0.02
	custom_minimum_size = Vector2(x, h + font_size * 0.25)
	queue_redraw()


func _draw() -> void:
	var total := custom_minimum_size.x
	var ox := (size.x - total) * 0.5
	var h := font_size * 1.16
	for g in _glyphs:
		var c := Vector2(ox + g.x + g.w * 0.5, size.y * 0.5 + g.dy)
		draw_set_transform(c, g.rot, Vector2.ONE)
		var r := Rect2(Vector2(-g.w * 0.5, -h * 0.5), Vector2(g.w, h))
		draw_rect(Rect2(r.position + Vector2(4, 5), r.size), Noir.INK)
		draw_rect(r, g.fill)
		draw_rect(r, g.edge, false, 2.5)
		var f: Font = g.font
		var asc := f.get_ascent(g.size)
		var desc := f.get_descent(g.size)
		var sw := f.get_string_size(g.ch, HORIZONTAL_ALIGNMENT_LEFT, -1, g.size).x
		draw_string(f, Vector2(-sw * 0.5, (asc - desc) * 0.5), g.ch, HORIZONTAL_ALIGNMENT_LEFT, -1, g.size, g.ink)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
