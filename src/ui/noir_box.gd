class_name NoirBox
extends StyleBox
## A skewed slab: a parallelogram with a solid fill, an ink edge, a hard offset shadow
## and optional halftone dots. The noir UI's panels, buttons and tags all wear one.

var fill := Color.WHITE
var border := 3.0
var border_color := Color("0b0b0b")
## Hard shadow offset (zero = none) and colour.
var shadow := Vector2(6, 6)
var shadow_color := Color("0b0b0b")
## How far the top edge leans right of the bottom edge, in pixels.
var skew := 12.0
## Lifts the top-left and drops the bottom-right corner a little, so slabs look cut by
## hand rather than ruled. 0 = a clean parallelogram.
var kick := 0.0
## Pressed: the slab sits down onto its shadow.
var pressed := false
## Halftone dots in the bottom-right corner (alpha 0 = none).
var dots := Color(0, 0, 0, 0)


static func make(fill_color: Color, margin := 12.0, lean := 12.0) -> NoirBox:
	var b := NoirBox.new()
	b.fill = fill_color
	b.skew = lean
	b.set_margins(margin)
	return b


## Content margins that keep text inside the slanted edges and off the shadow.
func set_margins(margin: float) -> void:
	content_margin_left = margin + absf(skew) * 0.7
	content_margin_right = margin + absf(skew) * 0.7 + shadow.x
	content_margin_top = margin * 0.6
	content_margin_bottom = margin * 0.6 + shadow.y


func copy() -> NoirBox:
	var b := NoirBox.new()
	for p in ["fill", "border", "border_color", "shadow", "shadow_color", "skew", "kick", "pressed", "dots"]:
		b.set(p, get(p))
	for side in 4:
		b.set_content_margin(side, get_content_margin(side))
	return b


## The slab's corners, clockwise from top-left.
func corners(r: Rect2) -> PackedVector2Array:
	var s := clampf(skew, -r.size.x * 0.25, r.size.x * 0.25)
	var k := minf(kick, r.size.y * 0.12)
	return PackedVector2Array([
		Vector2(r.position.x + maxf(s, 0.0), r.position.y + k),
		Vector2(r.end.x - maxf(-s, 0.0), r.position.y),
		Vector2(r.end.x - maxf(s, 0.0), r.end.y - k),
		Vector2(r.position.x + maxf(-s, 0.0), r.end.y),
	])


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	var body := rect.grow_individual(0, 0, -shadow.x, -shadow.y)
	var sh := shadow
	if pressed:
		body.position += shadow * 0.8
		sh = shadow * 0.2
	var pts := corners(body)
	if sh.length() > 0.5 and shadow_color.a > 0.0:
		var shp := PackedVector2Array()
		for p in pts:
			shp.append(p + sh)
		rs.canvas_item_add_polygon(to_canvas_item, shp, [shadow_color])
	if fill.a > 0.0:
		rs.canvas_item_add_polygon(to_canvas_item, pts, [fill])
	if dots.a > 0.0:
		_draw_dots(to_canvas_item, body)
	if border > 0.0 and border_color.a > 0.0:
		var loop := pts.duplicate()
		loop.append(pts[0])
		rs.canvas_item_add_polyline(to_canvas_item, loop, [border_color], border, true)


func _draw_dots(ci: RID, r: Rect2) -> void:
	var step := 9.0
	var size := minf(r.size.x, r.size.y) * 0.7
	var corner := r.end - Vector2(absf(skew) + border + 4, border + 4)
	var y := 0.0
	var row := 0
	while y < size:
		var x := (step * 0.5) if row % 2 else 0.0
		while x < size:
			var d := (x + y) / size
			if d < 1.0:
				var rad := (1.0 - d) * 2.8
				if rad > 0.5:
					RenderingServer.canvas_item_add_circle(ci, corner - Vector2(x, y), rad, dots, true)
			x += step
		y += step * 0.866
		row += 1
