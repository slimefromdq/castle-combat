class_name NoirSkyline
extends Control
## The menu backdrop: a yellow sky over a city in silhouette. Pale back towers, black
## front blocks with white cut edges and lit window slits, a radio tower, and a black
## street slab slanting across the lower part so the buttons sit on solid black.
## Same city every time (fixed seed).

var city_seed := 11
## Where the black street slab starts, as a fraction of the height (left, right edge).
var street_left := 0.70
var street_right := 0.64


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var s := size
	var rng := RandomNumberGenerator.new()
	rng.seed = city_seed
	draw_rect(Rect2(Vector2.ZERO, s), Noir.YELLOW)
	Noir.draw_halftone(self, Rect2(Vector2.ZERO, Vector2(s.x, s.y * 0.3)), Noir.YELLOW_DEEP, 11.0, 3.0, Vector2(0, 0), Vector2(0.6, 1.0))
	var base := s.y * (street_left + street_right) * 0.5 + 8.0
	# Back row: pale towers.
	var x := -rng.randf_range(0, 30)
	while x < s.x:
		var w := rng.randf_range(34, 80)
		var top := s.y * rng.randf_range(0.12, 0.26)
		draw_rect(Rect2(x, top, w - 4, base - top), Noir.YELLOW_DEEP)
		if rng.randf() < 0.25:
			draw_line(Vector2(x + w * 0.5, top), Vector2(x + w * 0.5, top - rng.randf_range(20, 50)), Noir.YELLOW_DEEP, 3.0)
		x += w
	# A fisheye horizon line, as in a wide-angle city shot.
	var arc := PackedVector2Array()
	for i in 25:
		var t := i / 24.0
		arc.append(Vector2(-20 + t * (s.x + 40), s.y * 0.3 - sin(t * PI) * s.y * 0.06))
	draw_polyline(arc, Color(Noir.WHITE, 0.85), 4.0, true)
	# Radio tower, off centre.
	_tower(Vector2(s.x * 0.72, base), s.y * 0.5)
	# Front row: black blocks, cut out with a white edge, windows lit yellow.
	x = -rng.randf_range(0, 40)
	while x < s.x:
		var w := rng.randf_range(44, 96)
		var top := s.y * rng.randf_range(0.27, 0.38)
		var r := Rect2(x, top, w - 6, base - top)
		draw_rect(r.grow(4), Noir.WHITE)
		draw_rect(r, Noir.INK)
		if rng.randf() < 0.3:
			# A stepped roof.
			draw_rect(Rect2(x + w * 0.2, top - 18, w * 0.45, 22).grow(4), Noir.WHITE)
			draw_rect(Rect2(x + w * 0.2, top - 18, w * 0.45, 22), Noir.INK)
		_windows(r, rng)
		x += w
	# The street slab with a white kerb.
	var street := PackedVector2Array([Vector2(0, s.y * street_left), Vector2(s.x, s.y * street_right), Vector2(s.x, s.y), Vector2(0, s.y)])
	var kerb := PackedVector2Array([Vector2(0, s.y * street_left - 12), Vector2(s.x, s.y * street_right - 12), Vector2(s.x, s.y * street_right), Vector2(0, s.y * street_left)])
	draw_colored_polygon(kerb, Noir.WHITE)
	draw_colored_polygon(street, Noir.INK)
	Noir.draw_halftone(self, Rect2(0, s.y * street_left, s.x, s.y * (1.0 - street_left)), Color(Noir.YELLOW, 0.16), 12.0, 2.4, Vector2(1, 1), Vector2(0.3, 0))


## Rows of short lit slits, some missing, like windows at night.
func _windows(r: Rect2, rng: RandomNumberGenerator) -> void:
	var y := r.position.y + 14.0
	while y < r.end.y - 10.0:
		var x := r.position.x + 6.0
		while x < r.end.x - 12.0:
			var w := rng.randf_range(6, 18)
			if rng.randf() < 0.32:
				draw_rect(Rect2(x, y, minf(w, r.end.x - 6.0 - x), 4), Noir.YELLOW)
			x += w + 5.0
		y += rng.randf_range(12, 18)


## A lattice radio tower: two legs, cross braces, a deck, and a needle.
func _tower(foot: Vector2, height: float) -> void:
	var top := foot - Vector2(0, height)
	var half := height * 0.11
	var c := Noir.INK
	for side in [-1.0, 1.0]:
		draw_line(foot + Vector2(half * side, 0), top + Vector2(3 * side, height * 0.18), c, 5.0, true)
	var n := 9
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var y0 := foot.y - height * 0.82 * t0
		var y1 := foot.y - height * 0.82 * t1
		var w0 := lerpf(half, 3.0, t0)
		var w1 := lerpf(half, 3.0, t1)
		draw_line(Vector2(foot.x - w0, y0), Vector2(foot.x + w1, y1), c, 2.0, true)
		draw_line(Vector2(foot.x + w0, y0), Vector2(foot.x - w1, y1), c, 2.0, true)
	draw_rect(Rect2(foot.x - half * 0.7, foot.y - height * 0.55, half * 1.4, 7), c)
	draw_line(top + Vector2(0, height * 0.18), top - Vector2(0, 16), c, 3.0, true)
