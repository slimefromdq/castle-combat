class_name ZinePaper
extends Control
## The menu's backdrop: cream paper covered in torn colour scraps, halftone patches,
## a grid-paper scrap and ink doodles. Same layout every time (fixed seed).

var paper_seed := 7


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = paper_seed
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Zine.PAPER)
	# Faint paper fibres.
	for i in 140:
		var p := Vector2(rng.randf() * s.x, rng.randf() * s.y)
		draw_line(p, p + Vector2(rng.randf_range(-14, 14), rng.randf_range(-3, 3)), Color(Zine.KRAFT, 0.25), 1.0)
	# Big torn scraps, cycling through the bright inks.
	var colors := [Zine.TEAL, Zine.PINK, Zine.SUN, Zine.LILAC, Zine.MINT, Zine.TANGERINE, Zine.COBALT]
	var scraps := int(s.x * s.y / 70000.0) + 6
	for i in scraps:
		var c: Color = colors[i % colors.size()]
		var center := Vector2(rng.randf() * s.x, (i + rng.randf()) * s.y / scraps)
		var half := Vector2(rng.randf_range(110, 240), rng.randf_range(70, 160))
		var ang := rng.randf_range(-0.5, 0.5)
		var box := PackedVector2Array()
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			box.append(center + (corner * half).rotated(ang))
		var shape := Zine.torn(box, rng, 14.0, 4.0) if i % 3 != 2 else Zine.blob(center, half, rng)
		draw_colored_polygon(shape, Color(c, 0.55))
		if i % 4 == 1:
			_halftone(Rect2(center - half * 0.6, half * 1.2), Color(Zine.INK, 0.10), rng.randf_range(8, 12))
	# A scrap of grid paper, as on the Chicago zine.
	var g := Rect2(Vector2(s.x * 0.62, s.y * 0.07), Vector2(220, 170))
	draw_colored_polygon(Zine.torn(PackedVector2Array([g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]), rng, 12, 3), Color(Zine.WHITE, 0.7))
	var x := g.position.x + 6
	while x < g.end.x:
		draw_line(Vector2(x, g.position.y + 4), Vector2(x, g.end.y - 4), Color(Zine.COBALT, 0.18), 1.0)
		x += 18
	var y := g.position.y + 6
	while y < g.end.y:
		draw_line(Vector2(g.position.x + 4, y), Vector2(g.end.x - 4, y), Color(Zine.COBALT, 0.18), 1.0)
		y += 18
	# Ink doodles: stars, swirls and dashes.
	for i in int(s.x * s.y / 45000.0):
		var p := Vector2(rng.randf() * s.x, rng.randf() * s.y)
		var ink := Color(Zine.INK, 0.35)
		match i % 3:
			0:
				var st := Zine.star_points(p, rng.randf_range(9, 16), rng.randf() * TAU)
				st.append(st[0])
				draw_polyline(st, ink, 2.0, true)
			1:
				var sw := PackedVector2Array()
				for k in 26:
					var a := k * 0.55
					sw.append(p + Vector2(cos(a), sin(a)) * (2.0 + k * 0.7))
				draw_polyline(sw, ink, 2.0, true)
			_:
				for k in 3:
					draw_line(p + Vector2(k * 9, 0), p + Vector2(k * 9 + 5, -5), ink, 2.0, true)


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
