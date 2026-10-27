class_name MatchIntro
extends CanvasLayer
## The 3 s match intro, noir style: the screen splits on a slant, yellow above and
## black below. The opponent's card slides in on the yellow, yours on the black, each
## with the hero's name in its own lettering, the portrait and the blurb, and a ransom
## "VS" punches in on the white cut between them. Tap, click or press any key to skip
## once it has run 1 s. The match clock waits until it's gone.

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
var _vs: Control


func setup(mine: HeroData, theirs: HeroData) -> void:
	you = mine
	them = theirs


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var split := Split.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	split.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(split)
	_top = _flyer(them, Palette.ENEMY, -4.0, 11, false)
	_bottom = _flyer(you, Palette.ALLY, 3.0, 23, true)
	_vs = RansomText.make("VS", 110, 9)
	_vs.set_anchors_preset(Control.PRESET_CENTER)
	_vs.size = Vector2(220, 170)
	_vs.pivot_offset = Vector2(110, 85)
	_vs.position = Vector2(-110, -85)
	_root.add_child(_vs)
	_layout()


## One card: a slab (yellow for them, black for you) with a team-coloured edge, the
## name, the portrait and the blurb.
func _flyer(h: HeroData, team: Color, tilt: float, seed_value: int, mine: bool) -> Control:
	var f := Flyer.new()
	f.hero = h
	f.team = team
	f.mine = mine
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
	name.add_theme_color_override("font_color", Noir.WHITE if mine else Noir.INK)
	name.position = Vector2(210, 70)
	name.size = Vector2(420, 110)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_child(name)
	var blurb := Noir.label(h.blurb, Noir.body(), 24, Noir.ASH if mine else Noir.INK)
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


## The card: a skewed slab with a hard shadow, a team-coloured edge, halftone dots and
## a YOU / RIVAL tag.
class Flyer extends Control:
	var hero: HeroData
	var team := Color.WHITE
	var mine := false
	var seed_value := 1

	func _draw() -> void:
		var fill := Noir.INK if mine else Noir.YELLOW
		var sk := 28.0
		var pts := PackedVector2Array([Vector2(sk, 0), Vector2(size.x, 0), Vector2(size.x - sk, size.y), Vector2(0, size.y)])
		var shadow := PackedVector2Array()
		for p in pts:
			shadow.append(p + Vector2(10, 10))
		draw_colored_polygon(shadow, Noir.WHITE if mine else Noir.INK)
		draw_colored_polygon(pts, fill)
		Noir.draw_halftone(self, Rect2(size.x * 0.55, size.y * 0.55, size.x * 0.42, size.y * 0.42), Color(Noir.YELLOW if mine else Noir.YELLOW_DEEP, 0.3 if mine else 0.5), 12.0, 3.2, Vector2(1, 1), Vector2(0.2, 0.2))
		# Team edge along the top.
		draw_colored_polygon(PackedVector2Array([Vector2(sk, 0), Vector2(size.x, 0), Vector2(size.x - 2.5, 14), Vector2(sk - 2.5, 14)]), team)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Noir.WHITE if mine else Noir.INK, 4.0, true)
		# Tag in the top-right corner.
		var tag := "YOU" if mine else "RIVAL"
		var fs := 26
		var w := Noir.SLAB.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var r := Rect2(size.x - w - 60, 22, w + 22, 36)
		draw_rect(r, Noir.YELLOW if mine else Noir.INK)
		draw_string(Noir.SLAB, Vector2(r.position.x + 11, r.end.y - 6), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Noir.INK if mine else Noir.YELLOW)


## The backdrop: yellow above a slanted white cut, black below, halftone in both, and
## the menu's city standing on the cut.
class Split extends Control:
	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var s := size
		var left := s.y * 0.56
		var right := s.y * 0.44
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, right), Vector2(0, left)]), Color(Noir.YELLOW, 0.94))
		Noir.draw_halftone(self, Rect2(0, 0, s.x, right), Color(Noir.YELLOW_DEEP, 0.6), 12.0, 3.0, Vector2(0, 0), Vector2(0.8, 1))
		draw_colored_polygon(PackedVector2Array([Vector2(0, left), Vector2(s.x, right), Vector2(s.x, s.y), Vector2(0, s.y)]), Color(Noir.INK, 0.92))
		Noir.draw_halftone(self, Rect2(0, left, s.x, s.y - left), Color(Noir.YELLOW, 0.14), 12.0, 2.6, Vector2(1, 1), Vector2(0.2, 0))
		# The city skyline from the menu, standing on the cut.
		Noir.draw_city(self, Vector2(0, left), Vector2(s.x, right), s.y * 0.06, s.y * 0.2, 11)
		draw_colored_polygon(PackedVector2Array([Vector2(0, left - 16), Vector2(s.x, right - 16), Vector2(s.x, right + 16), Vector2(0, left + 16)]), Noir.WHITE)
