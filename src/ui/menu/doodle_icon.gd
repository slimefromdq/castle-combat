class_name DoodleIcon
extends Control
## Hand-drawn style tab icons, drawn with ink lines and flat fills.
## Kinds: shop, heroes, battle, clan, tournaments.

var kind := "battle"
var line := 4.0


static func make(k: String, px := 64.0) -> DoodleIcon:
	var d := DoodleIcon.new()
	d.kind = k
	d.custom_minimum_size = Vector2(px, px)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


func _ready() -> void:
	resized.connect(queue_redraw)


## Polygon with an ink outline and a hard shadow.
func _shape(pts: PackedVector2Array, fill: Color) -> void:
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(3, 3))
	draw_colored_polygon(sh, Zine.INK)
	draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, Zine.INK, line, true)


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	var u := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	line = maxf(2.5, s * 0.055)
	match kind:
		"shop":
			# A paper bag with a coin.
			_shape(PackedVector2Array([u.call(0.2, 0.38), u.call(0.8, 0.38), u.call(0.86, 0.9), u.call(0.14, 0.9)]), Zine.TANGERINE)
			draw_arc(u.call(0.5, 0.38), s * 0.16, PI, TAU, 16, Zine.INK, line, true)
			draw_circle(u.call(0.5, 0.64), s * 0.15, Zine.INK)
			draw_circle(u.call(0.49, 0.63), s * 0.13, Zine.SUN)
			draw_string(Zine.DISPLAY, u.call(0.43, 0.71), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.22), Zine.INK)
		"heroes":
			# A fan of three cards.
			for i in 3:
				var a := deg_to_rad(-18 + i * 18)
				var c: Vector2 = u.call(0.5, 0.62)
				var pts := PackedVector2Array()
				for p in [Vector2(-0.17, -0.32), Vector2(0.17, -0.32), Vector2(0.17, 0.2), Vector2(-0.17, 0.2)]:
					pts.append(c + (p * s).rotated(a) + Vector2(0, -s * 0.05))
				_shape(pts, [Zine.TEAL, Zine.LILAC, Zine.PINK][i])
			var st := Zine.star_points(u.call(0.55, 0.47), s * 0.1)
			draw_colored_polygon(st, Zine.SUN)
		"battle":
			# Crossed swords.
			for side in [-1.0, 1.0]:
				var a := deg_to_rad(45.0 * side)
				var c: Vector2 = u.call(0.5, 0.52)
				var blade := PackedVector2Array()
				for p in [Vector2(-0.06, -0.42), Vector2(0, -0.5), Vector2(0.06, -0.42), Vector2(0.06, 0.18), Vector2(-0.06, 0.18)]:
					blade.append(c + (p * s).rotated(a))
				_shape(blade, Zine.WHITE)
				var guard := PackedVector2Array()
				for p in [Vector2(-0.18, 0.16), Vector2(0.18, 0.16), Vector2(0.18, 0.24), Vector2(-0.18, 0.24)]:
					guard.append(c + (p * s).rotated(a))
				_shape(guard, Zine.SUN)
				var grip := PackedVector2Array()
				for p in [Vector2(-0.05, 0.24), Vector2(0.05, 0.24), Vector2(0.05, 0.42), Vector2(-0.05, 0.42)]:
					grip.append(c + (p * s).rotated(a))
				_shape(grip, Zine.PINK)
		"clan":
			# A shield with a stripe and a star.
			var pts := PackedVector2Array([u.call(0.18, 0.18), u.call(0.82, 0.18), u.call(0.8, 0.55), u.call(0.5, 0.9), u.call(0.2, 0.55)])
			_shape(pts, Zine.COBALT)
			draw_colored_polygon(PackedVector2Array([u.call(0.42, 0.2), u.call(0.58, 0.2), u.call(0.58, 0.84), u.call(0.5, 0.88), u.call(0.42, 0.84)]), Zine.PINK)
			var st := Zine.star_points(u.call(0.5, 0.46), s * 0.15)
			draw_colored_polygon(st, Zine.SUN)
			st.append(st[0])
			draw_polyline(st, Zine.INK, line * 0.6, true)
		"tournaments":
			# A trophy cup.
			_shape(PackedVector2Array([u.call(0.26, 0.16), u.call(0.74, 0.16), u.call(0.68, 0.48), u.call(0.5, 0.6), u.call(0.32, 0.48)]), Zine.SUN)
			draw_arc(u.call(0.25, 0.3), s * 0.1, PI * 0.5, PI * 1.5, 12, Zine.INK, line, true)
			draw_arc(u.call(0.75, 0.3), s * 0.1, -PI * 0.5, PI * 0.5, 12, Zine.INK, line, true)
			_shape(PackedVector2Array([u.call(0.45, 0.6), u.call(0.55, 0.6), u.call(0.57, 0.74), u.call(0.43, 0.74)]), Zine.SUN)
			_shape(PackedVector2Array([u.call(0.3, 0.74), u.call(0.7, 0.74), u.call(0.72, 0.88), u.call(0.28, 0.88)]), Zine.PINK)
		"coin":
			draw_circle(u.call(0.53, 0.53), s * 0.42, Zine.INK)
			draw_circle(u.call(0.48, 0.48), s * 0.42, Zine.SUN)
			draw_arc(u.call(0.48, 0.48), s * 0.42, 0, TAU, 24, Zine.INK, line, true)
			draw_arc(u.call(0.48, 0.48), s * 0.26, 0, TAU, 20, Color(Zine.INK, 0.5), line * 0.6, true)
		"gem":
			_shape(PackedVector2Array([u.call(0.25, 0.3), u.call(0.75, 0.3), u.call(0.9, 0.45), u.call(0.5, 0.9), u.call(0.1, 0.45)]), Zine.MINT)
			draw_line(u.call(0.1, 0.45), u.call(0.9, 0.45), Zine.INK, line * 0.6, true)
		"trophy":
			_shape(PackedVector2Array([u.call(0.2, 0.12), u.call(0.8, 0.12), u.call(0.7, 0.5), u.call(0.5, 0.62), u.call(0.3, 0.5)]), Zine.SUN)
			_shape(PackedVector2Array([u.call(0.3, 0.75), u.call(0.7, 0.75), u.call(0.74, 0.92), u.call(0.26, 0.92)]), Zine.TANGERINE)
			draw_line(u.call(0.5, 0.62), u.call(0.5, 0.75), Zine.INK, line * 1.4)
