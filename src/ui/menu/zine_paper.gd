class_name ZinePaper
extends Control
## The menu's backdrop: a painted brick wall on an occult street, plastered with
## flyers (torn colour posters with printed sigils, tear-off tabs and staples), a tarot
## card, and chalk sigils and spray dots between them. Bright, never gloomy. Same
## layout every time (fixed seed).

var paper_seed := 7

const BRICK := Color("e9d3bf")
const MORTAR := Color("cdb39c")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = paper_seed
	var s := size
	_bricks(s, rng)
	# Posted flyers, cycling through the bright inks.
	var colors := [Zine.TEAL, Zine.PINK, Zine.SUN, Zine.LILAC, Zine.MINT, Zine.TANGERINE, Zine.COBALT]
	var count := int(s.x * s.y / 70000.0) + 6
	for i in count:
		var c: Color = colors[i % colors.size()]
		var center := Vector2(rng.randf() * s.x, (i + rng.randf()) * s.y / count)
		var half := Vector2(rng.randf_range(90, 170), rng.randf_range(110, 190))
		var ang := rng.randf_range(-0.35, 0.35)
		_flyer(center, half, ang, c, i, rng)
	_tarot(Vector2(s.x * 0.74, s.y * 0.14), 0.12, rng)
	# Chalk sigils and spray dots between the flyers.
	for i in int(s.x * s.y / 45000.0):
		var p := Vector2(rng.randf() * s.x, rng.randf() * s.y)
		var chalk := Color(1, 1, 1, 0.55)
		match i % 3:
			0:
				var st := Zine.star_points(p, rng.randf_range(11, 18), rng.randf() * TAU)
				st.append(st[0])
				draw_arc(p, st[0].distance_to(p) + 3.0, 0, TAU, 24, chalk, 2.0, true)
				draw_polyline(st, chalk, 2.0, true)
			1:
				_moon(p, rng.randf_range(10, 16), Color(Zine.INK, 0.3))
			_:
				var spray: Color = colors[rng.randi() % colors.size()]
				for k in 9:
					draw_circle(p + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10)), rng.randf_range(1.0, 2.5), Color(spray, 0.6))


## Painted brick, staggered rows, a few bricks in other paint.
func _bricks(s: Vector2, rng: RandomNumberGenerator) -> void:
	draw_rect(Rect2(Vector2.ZERO, s), MORTAR)
	var bh := 26.0
	var bw := 62.0
	var row := 0
	var y := 0.0
	while y < s.y:
		var x := -bw * 0.5 if row % 2 else 0.0
		while x < s.x:
			var c := BRICK.lightened(rng.randf_range(-0.02, 0.05))
			if rng.randf() < 0.04:
				c = BRICK.lerp([Zine.PINK, Zine.TEAL, Zine.LILAC][rng.randi() % 3], 0.25)
			draw_rect(Rect2(x + 2, y + 2, bw - 4, bh - 4), c)
			x += bw
		y += bh
		row += 1


## One flyer: torn paper, a printed sigil, halftone, a staple or tape, and sometimes
## a row of tear-off tabs.
func _flyer(center: Vector2, half: Vector2, ang: float, c: Color, i: int, rng: RandomNumberGenerator) -> void:
	var box := PackedVector2Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		box.append(center + (corner * half).rotated(ang))
	var shape := Zine.torn(box, rng, 14.0, 3.0)
	var shadow := PackedVector2Array()
	for p in shape:
		shadow.append(p + Vector2(4, 6))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.12))
	draw_colored_polygon(shape, Color(c, 0.6).lerp(Color(Zine.PAPER, 0.6), 0.25))
	draw_set_transform(center, ang, Vector2.ONE)
	var ink := Color(Zine.INK, 0.4)
	match i % 4:
		0:  # An eye.
			draw_arc(Vector2(0, half.y * 0.55), half.x * 0.6, PI * 1.2, PI * 1.8, 16, ink, 3.0)
			draw_arc(Vector2(0, -half.y * 0.75), half.x * 0.6, PI * 0.2, PI * 0.8, 16, ink, 3.0)
			draw_arc(Vector2(0, -half.y * 0.1), half.x * 0.16, 0, TAU, 16, ink, 3.0)
		1:  # A crescent moon and star.
			_moon(Vector2(0, -half.y * 0.15), half.x * 0.38, ink)
		2:  # A pentacle.
			var st := Zine.star_points(Vector2(0, -half.y * 0.15), half.x * 0.4, 0.0)
			draw_arc(Vector2(0, -half.y * 0.15), half.x * 0.44, 0, TAU, 28, ink, 3.0)
			var tips := PackedVector2Array()
			for k in 5:
				tips.append(st[(k * 4) % 10])
			tips.append(tips[0])
			draw_polyline(tips, ink, 3.0)
		_:
			_halftone(Rect2(-half * 0.7, half * 1.0), Color(Zine.INK, 0.12), 10.0)
	# Headline bars and tear-off tabs.
	for k in 2:
		draw_rect(Rect2(-half.x * 0.6, half.y * (0.32 + k * 0.14), half.x * (1.2 - k * 0.4), 6), Color(Zine.INK, 0.3))
	if i % 3 == 0:
		for k in 6:
			var tx := -half.x + 4 + k * (half.x * 2.0 - 8) / 6.0
			draw_rect(Rect2(tx, half.y - 4, (half.x * 2.0 - 8) / 6.0 - 3, 22), Color(Zine.PAPER, 0.85))
	# A staple, or tape.
	if i % 2 == 0:
		draw_line(Vector2(-10, -half.y + 10), Vector2(10, -half.y + 10), Color("8a8f99"), 3.0)
	else:
		draw_rect(Rect2(-40, -half.y - 10, 80, 22), Zine.TAPE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A cream tarot card: double border, a sun, and a roman numeral bar.
func _tarot(at: Vector2, ang: float, rng: RandomNumberGenerator) -> void:
	draw_set_transform(at, ang, Vector2.ONE)
	var r := Rect2(-70, -110, 140, 220)
	draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0, 0, 0, 0.15))
	draw_rect(r, Color("fbf1da"))
	draw_rect(r.grow(-8), Zine.LILAC, false, 3.0)
	draw_rect(r.grow(-14), Color(Zine.INK, 0.5), false, 1.5)
	var c := Vector2(0, -12)
	draw_circle(c, 26, Zine.SUN)
	for k in 12:
		var a := TAU * k / 12.0 + rng.randf_range(-0.05, 0.05)
		draw_line(c + Vector2(cos(a), sin(a)) * 32, c + Vector2(cos(a), sin(a)) * 46, Zine.TANGERINE, 3.0)
	draw_rect(Rect2(-36, 74, 72, 14), Color(Zine.INK, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _moon(c: Vector2, r: float, color: Color) -> void:
	draw_arc(c, r, PI * 0.35, PI * 1.65, 24, color, 3.0, true)
	draw_arc(c + Vector2(r * 0.35, 0), r * 0.78, PI * 0.42, PI * 1.58, 24, color, 2.0, true)
	var st := Zine.star_points(c + Vector2(r * 1.1, -r * 0.6), r * 0.3)
	st.append(st[0])
	draw_polyline(st, color, 2.0, true)


func _halftone(r: Rect2, c: Color, step: float) -> void:
	var y := 0.0
	var row := 0
	while y < r.size.y:
		var x := (step * 0.5) if row % 2 else 0.0
		while x < r.size.x:
			var d := Vector2(x, y) / r.size - Vector2(0.5, 0.5)
			var rad := (0.5 - d.length()) * step * 0.7
			if rad > 0.6:
				draw_circle(r.position + Vector2(x, y), rad, c)
			x += step
		y += step
		row += 1
