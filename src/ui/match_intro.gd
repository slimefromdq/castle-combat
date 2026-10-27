class_name MatchIntro
extends CanvasLayer
## The 3 s match intro: two street flyers slap onto the screen, the opponent's at the
## top and yours at the bottom, each with the hero's name in its own lettering, the
## portrait and the blurb, and a chalk "VS" between them. Tap, click or press any key
## to skip once it has run 1 s. The match clock waits until it's gone.

signal finished

const LENGTH := 3.0
const SKIP_AFTER := 1.0
const SLIDE := 0.35
const OUT := 0.3

var you: HeroData
var them: HeroData
var _t := 0.0
var _out_at := LENGTH - OUT
var _done := false
var _root: Control
var _top: Control
var _bottom: Control
var _vs: Label


func setup(mine: HeroData, theirs: HeroData) -> void:
	you = mine
	them = theirs


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.05, 0.1, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	_top = _flyer(them, Palette.ENEMY, -4.0, 11)
	_bottom = _flyer(you, Palette.ALLY, 3.0, 23)
	_vs = Zine.label("VS", Zine.DISPLAY, 96, Zine.WHITE, 18, Zine.INK)
	_vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_vs.set_anchors_preset(Control.PRESET_CENTER)
	_vs.pivot_offset = Vector2(90, 60)
	_vs.custom_minimum_size = Vector2(180, 120)
	_vs.position = Vector2(-90, -60)
	_root.add_child(_vs)
	_layout()


## One flyer: torn paper in the hero's accent, team-coloured tape, name, portrait, blurb.
func _flyer(h: HeroData, team: Color, tilt: float, seed_value: int) -> Control:
	var f := Flyer.new()
	f.hero = h
	f.team = team
	f.seed_value = seed_value
	f.rotation_degrees = tilt
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(f)
	var portrait := HeroPortrait.new()
	portrait.setup(h.id, team)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.position = Vector2(40, 70)
	portrait.size = Vector2(150, 150)
	f.add_child(portrait)
	var name := Label.new()
	name.text = h.display_name
	HeroLettering.apply(name, h.id, 84 if h.display_name.length() <= 7 else 60)
	name.add_theme_color_override("font_color", Zine.INK)
	name.position = Vector2(210, 70)
	name.size = Vector2(420, 110)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_child(name)
	var blurb := Zine.label(h.blurb, Zine.HAND, 24, Zine.INK)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.position = Vector2(210, 175)
	blurb.size = Vector2(420, 90)
	f.add_child(blurb)
	return f


func _layout() -> void:
	var vp := _screen()
	var w := minf(vp.x - 20.0, 680.0)
	for f: Control in [_top, _bottom]:
		f.size = Vector2(w, 300)
		f.pivot_offset = f.size / 2.0
	_top.set_meta("home", Vector2((vp.x - w) / 2.0, vp.y * 0.5 - 360))
	_bottom.set_meta("home", Vector2((vp.x - w) / 2.0, vp.y * 0.5 + 60))


func skip() -> void:
	if _t >= SKIP_AFTER and _out_at > _t:
		_out_at = _t


## Screen size in design pixels (the portrait design size when not in a tree, e.g. tests).
func _screen() -> Vector2:
	return _root.get_viewport_rect().size if _root.is_inside_tree() else Vector2(720, 1280)


func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey) and event.is_pressed()
	if pressed:
		skip()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _done:
		return
	var before := _t
	_t += delta
	# Paper slaps as the flyers land, then the VS hit.
	if before < 0.25 and _t >= 0.25:
		Sfx.play(&"slap")
	if before < SLIDE + 0.05 and _t >= SLIDE + 0.05:
		Sfx.play(&"vs")
	var vp := _screen()
	# Slide in from off-screen sides, then fly out the way they came.
	var into := _ease(clampf(_t / SLIDE, 0.0, 1.0))
	var away := _ease(clampf((_t - _out_at) / OUT, 0.0, 1.0))
	var shift := (1.0 - into + away) * (vp.x + 40.0)
	_top.position = _top.get_meta("home") + Vector2(shift, 0)
	_bottom.position = _bottom.get_meta("home") - Vector2(shift, 0)
	var vs_in := clampf((_t - SLIDE) / 0.2, 0.0, 1.0)
	var punch := 1.0 + 0.5 * (1.0 - vs_in)
	_vs.scale = Vector2.ONE * punch * (1.0 - away)
	_vs.modulate.a = vs_in * (1.0 - away)
	_vs.rotation_degrees = -8.0 + 3.0 * sin(_t * 6.0)
	_root.modulate.a = 1.0 - away
	if _t >= _out_at + OUT:
		_done = true
		finished.emit()
		if is_inside_tree():
			queue_free()


static func _ease(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


## The flyer paper: a torn sheet with halftone dots, tape and a chalk sigil.
class Flyer extends Control:
	var hero: HeroData
	var team := Color.WHITE
	var seed_value := 1

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var accent := HeroLettering.accent(hero.id)
		var paper := Zine.PAPER.lerp(accent, 0.35)
		var r := Rect2(Vector2.ZERO, size)
		var outline := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		var torn := Zine.torn(outline, rng, 18.0, 5.0)
		var shadow := PackedVector2Array()
		for p in torn:
			shadow.append(p + Vector2(8, 10))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
		draw_colored_polygon(torn, paper)
		# Halftone corner.
		for y in 6:
			for x in 9:
				draw_circle(Vector2(size.x - 24 - x * 16, size.y - 22 - y * 16), 4.5 - (x + y) * 0.35, Color(accent.darkened(0.3), 0.35))
		# Team stripe and tape.
		draw_rect(Rect2(0, 0, size.x, 14), team)
		draw_rect(Rect2(size.x * 0.5 - 50, -12, 100, 30), Zine.TAPE)
		# A chalk sigil, the way the street marks a hero's territory.
		var c := Vector2(size.x - 70, 60)
		draw_arc(c, 34, 0, TAU, 32, Color(Zine.INK, 0.5), 2.0)
		draw_polyline(Zine.star_points(c, 30), Color(Zine.INK, 0.5), 2.0)
		draw_polyline(torn + PackedVector2Array([torn[0]]), Zine.INK, 3.0)
