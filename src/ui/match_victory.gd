class_name MatchVictory
extends CanvasLayer
## About 3 s after the last Core falls: a VICTORY or DEFEAT flyer slaps down, the winner's
## name in its lettering with a grinning portrait, and confetti in the winner's colour.
## Meanwhile MatchView zooms in on the winner's celebration. Tap to skip after 1 s; the
## result panel shows when it ends.

signal finished

const LENGTH := 3.0
const SKIP_AFTER := 1.0

var won := true
var winner: HeroData
var winner_color := Color.WHITE
var _t := 0.0
var _done := false
var _root: Control
var _card: Control
var _confetti: Confetti


func setup(you_won: bool, hero: HeroData, color: Color) -> void:
	won = you_won
	winner = hero
	winner_color = color


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_confetti = Confetti.new()
	_confetti.color = winner_color
	_confetti.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confetti.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_confetti)
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_card)
	var vp := _screen()
	_card.size = Vector2(minf(vp.x - 40.0, 600.0), 300)
	_card.position = Vector2((vp.x - _card.size.x) / 2.0, vp.y * 0.18)
	_card.pivot_offset = _card.size / 2.0
	var paper := Zine.panel(Zine.SUN if won else Zine.LILAC, 7, 16.0)
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.add_child(paper)
	var title := Zine.label("VICTORY!" if won else "DEFEAT", Zine.DISPLAY, 86, Zine.WHITE, 18, Zine.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 18)
	title.size = Vector2(_card.size.x, 110)
	_card.add_child(title)
	var portrait := HeroPortrait.new()
	portrait.setup(winner.id, winner_color)
	portrait.set_mood(PortraitMood.Mood.AHEAD)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.position = Vector2(40, 140)
	portrait.size = Vector2(120, 120)
	_card.add_child(portrait)
	var name := Label.new()
	name.text = winner.display_name
	HeroLettering.apply(name, winner.id, 64 if winner.display_name.length() <= 7 else 48)
	name.add_theme_color_override("font_color", Zine.INK)
	name.position = Vector2(180, 130)
	name.size = Vector2(_card.size.x - 200, 90)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(name)
	var line := Zine.label("owns the street" if won else "takes the street", Zine.MARKER, 28, Zine.INK)
	line.position = Vector2(184, 214)
	_card.add_child(line)
	advance(0.0)


## Screen size in design pixels (the portrait design size when not in a tree, e.g. tests).
func _screen() -> Vector2:
	return _root.get_viewport_rect().size if _root.is_inside_tree() else Vector2(720, 1280)


func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey) and event.is_pressed()
	if pressed:
		if _t >= SKIP_AFTER:
			_t = LENGTH
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _done:
		return
	_t += delta
	# The flyer slaps down with a little overshoot, then sits there.
	var k := clampf(_t / 0.3, 0.0, 1.0)
	var s := 2.2 - 1.2 * k + 0.12 * sin(k * PI)
	_card.scale = Vector2.ONE * s
	_card.rotation_degrees = -6.0 * (1.0 - k) - 2.0
	_card.modulate.a = k
	_confetti.t = _t
	_confetti.queue_redraw()
	if _t >= LENGTH:
		_done = true
		finished.emit()
		if is_inside_tree():
			queue_free()


## Paper confetti in the winner's colour, gold and cream, falling and fluttering.
class Confetti extends Control:
	var color := Color.WHITE
	var t := 0.0

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var colors := [color, color.lightened(0.4), Palette.RELAY, Zine.WHITE, Zine.PINK]
		for i in 90:
			var x0 := rng.randf() * size.x
			var speed := rng.randf_range(260.0, 520.0)
			var start := rng.randf_range(-0.6, 0.4)
			var y := (t - start) * speed - 40.0
			if y < -40.0 or y > size.y + 40.0:
				continue
			var x := x0 + sin(t * rng.randf_range(2.0, 5.0) + i) * 30.0
			var flip := absf(sin(t * rng.randf_range(4.0, 9.0) + i))
			var w := 14.0 * flip + 2.0
			var c: Color = colors[i % colors.size()]
			draw_set_transform(Vector2(x, y), t * rng.randf_range(-3.0, 3.0) + i, Vector2.ONE)
			draw_rect(Rect2(-w / 2.0, -5, w, 10), c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
