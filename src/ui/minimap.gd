class_name Minimap
extends Control
## A small map in the corner (Lucy's K1): the lane and diamond, structures, both heroes
## (the enemy only while you can see them), the Relay, honey fruit and (phase 2) the
## long Relay drops. Your base is at the bottom, like the camera.

const SCALE := 1.9  # Pixels per metre.

var sim: MatchSim
var seat := MatchSim.BLUE


func setup(match_sim: MatchSim, local_seat: int) -> void:
	sim = match_sim
	seat = local_seat
	var a := sim.arena
	var w := maxf(a.lane_half_width, a.diamond_half_width) * 2.0 * SCALE + 8.0
	custom_minimum_size = Vector2(w, a.half_length * 2.0 * SCALE + 8.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Sim position -> pixel inside this control (your side at the bottom).
func to_px(p: Vector2) -> Vector2:
	var q := MatchSim.to_team_space(seat, p)
	return size / 2.0 + Vector2(q.x, -q.y) * SCALE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var a := sim.arena
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.07, 0.12, 0.55))
	var ground := Color(0.85, 0.78, 0.62, 0.55)
	if a.has_diamond():
		var pts := PackedVector2Array()
		for p in a.diamond_points():
			pts.append(to_px(p))
		draw_colored_polygon(pts, ground)
	var lane_a := to_px(Vector2(-a.lane_half_width, -a.half_length))
	var lane_b := to_px(Vector2(a.lane_half_width, a.half_length))
	draw_rect(Rect2(lane_a, lane_b - lane_a).abs(), Color(0.75, 0.7, 0.66, 0.6))
	for pk in a.pockets:
		var p0 := to_px(pk.position)
		var p1 := to_px(pk.end)
		draw_rect(Rect2(p0, p1 - p0).abs(), Color(0.5, 0.35, 0.8, 0.55))
	for w in a.walls:
		var p0 := to_px(w.position)
		var p1 := to_px(w.end)
		draw_rect(Rect2(p0, p1 - p0).abs(), Color(0.95, 0.9, 0.8, 0.6))
	for team in [MatchSim.BLUE, MatchSim.RED]:
		var far := sim.relay.long_rect(sim, team)
		if far.has_area():
			var p0 := to_px(far.position)
			var p1 := to_px(far.end)
			var lc := Palette.team_color(team == seat).lightened(0.3)
			draw_rect(Rect2(p0, p1 - p0).abs(), Color(lc, 0.85 if team == seat else 0.45), false, 1.5)
	for f in sim.fruits.ripe():
		draw_circle(to_px(f.pos), 2.4, Color("ff9f1c"))
	for s in sim.structures:
		if not s.alive:
			continue
		var c := Palette.team_color(s.team == seat)
		if not sim.is_exposed(s):
			c = c.lerp(Color(0.6, 0.62, 0.66), 0.5)
		var r := 4.5 if s.tier == 2 else 3.5
		draw_rect(Rect2(to_px(s.pos) - Vector2(r, r), Vector2(r, r) * 2.0), c)
	if sim.relay.state != RelayController.State.DORMANT:
		draw_circle(to_px(sim.relay.pos), 3.2, Palette.RELAY)
	for h in sim.heroes:
		if not h.alive or (h.team != seat and sim.is_hidden(h)):
			continue
		var c := Palette.team_color(h.team == seat)
		draw_circle(to_px(h.pos), 4.5, Color.WHITE)
		draw_circle(to_px(h.pos), 3.4, c)
