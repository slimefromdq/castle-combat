class_name ZineBox
extends StyleBox
## A cut-paper sticker: slightly crooked corners, thick ink outline, hard offset
## shadow, optional halftone dots and a strip of tape. Used by the main menu.

var fill := Color.WHITE
var ink := Color("1d1a24")
var border := 4.0
var shadow := Vector2(6, 7)
## How far each corner may stray from the true rectangle, in pixels.
var wobble := 5.0
## Picks the crooked corners (same seed = same shape).
var shape_seed := 0
## Pressed look: the sticker sits down onto its shadow.
var pressed := false
## Halftone dots in the bottom-right corner (alpha 0 = none).
var dots := Color(0, 0, 0, 0)
## A strip of tape across the top edge (alpha 0 = none).
var tape := Color(0, 0, 0, 0)
## Dashed outline and no shadow (empty slots).
var dashed := false


static func make(fill_color: Color, seed_value := 0, margin := 12.0) -> ZineBox:
	var b := ZineBox.new()
	b.fill = fill_color
	b.shape_seed = seed_value
	b.set_content_margin_all(margin)
	return b


func copy() -> ZineBox:
	var b := ZineBox.new()
	for p in ["fill", "ink", "border", "shadow", "wobble", "shape_seed", "pressed", "dots", "tape", "dashed"]:
		b.set(p, get(p))
	for side in 4:
		b.set_content_margin(side, get_content_margin(side))
	return b


## Corners clockwise from top-left, nudged by the seed.
func corners(rect: Rect2) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed * 7919 + 17
	var w := minf(wobble, minf(rect.size.x, rect.size.y) * 0.08)
	var pts := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	for i in 4:
		pts[i] += Vector2(rng.randf_range(-w, w), rng.randf_range(-w, w))
	return pts


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	var body := rect.grow_individual(0, 0, -shadow.x, -shadow.y)
	var sh := shadow
	if pressed:
		body.position += shadow * 0.7
		sh = shadow * 0.3
	var pts := corners(body)
	if not dashed and sh.length() > 0.5:
		var shp := PackedVector2Array()
		for p in pts:
			shp.append(p + sh)
		rs.canvas_item_add_polygon(to_canvas_item, shp, [ink])
	if fill.a > 0.0:
		rs.canvas_item_add_polygon(to_canvas_item, pts, [fill])
	if dots.a > 0.0:
		_draw_dots(to_canvas_item, body)
	if border > 0.0:
		if dashed:
			for i in 4:
				var a := pts[i]
				var b := pts[(i + 1) % 4]
				var n := int(a.distance_to(b) / 18.0)
				for k in n:
					if k % 2 == 0:
						rs.canvas_item_add_line(to_canvas_item, a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), ink, border, true)
		else:
			var loop := pts.duplicate()
			loop.append(pts[0])
			rs.canvas_item_add_polyline(to_canvas_item, loop, [ink], border, true)
			for p in pts:
				rs.canvas_item_add_circle(to_canvas_item, p, border * 0.5, ink, true)
	if tape.a > 0.0:
		_draw_tape(to_canvas_item, body)


func _draw_dots(ci: RID, r: Rect2) -> void:
	var step := 11.0
	var size := minf(r.size.x, r.size.y) * 0.6
	var corner := r.end - Vector2(border + 4, border + 4)
	var y := 0.0
	while y < size:
		var x := 0.0
		while x < size:
			var d := (x + y) / size
			if d < 1.0:
				var rad := (1.0 - d) * 3.2
				if rad > 0.5:
					RenderingServer.canvas_item_add_circle(ci, corner - Vector2(x, y) + Vector2(fmod(y / step, 2.0) * step * 0.5, 0), rad, dots, true)
			x += step
		y += step


func _draw_tape(ci: RID, r: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed * 31 + 5
	var w := clampf(r.size.x * 0.32, 50.0, 120.0)
	var h := 26.0
	var c := Vector2(r.position.x + r.size.x * rng.randf_range(0.35, 0.65), r.position.y + 2)
	var ang := deg_to_rad(rng.randf_range(-7, 7))
	var ax := Vector2(cos(ang), sin(ang)) * w * 0.5
	var ay := Vector2(-sin(ang), cos(ang)) * h * 0.5
	var pts := PackedVector2Array()
	# Torn ends: a little zigzag on the left and right edges.
	pts.append(c - ax - ay)
	pts.append(c + ax - ay)
	pts.append(c + ax * 0.96 - ay * 0.3)
	pts.append(c + ax * 1.02 + ay * 0.3)
	pts.append(c + ax + ay)
	pts.append(c - ax + ay)
	pts.append(c - ax * 0.96 + ay * 0.3)
	pts.append(c - ax * 1.03 - ay * 0.3)
	RenderingServer.canvas_item_add_polygon(ci, pts, [tape])
