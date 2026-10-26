class_name HeroPortrait
extends Control
## A HUD portrait with four moods. Uses Lucy's art when it exists at
## res://assets/portraits/<hero id>_<mood>.png (mood: neutral, ahead, behind, low_hp);
## until then it draws a placeholder face: the hero's accent colour, a monogram in the
## hero's lettering, and simple eyes and mouth that change with the mood.
## Faces live here only, never on the 3D model.

const MOOD_NAMES := ["neutral", "ahead", "behind", "low_hp"]

var hero_id: StringName = &""
var team_color := Color.WHITE
var mood := PortraitMood.Mood.NEUTRAL
var _art := {}
var _since := 0.0


func setup(id: StringName, color: Color) -> void:
	hero_id = id
	team_color = color
	_art.clear()
	for i in MOOD_NAMES.size():
		var path := "res://assets/portraits/%s_%s.png" % [id, MOOD_NAMES[i]]
		if ResourceLoader.exists(path):
			_art[i] = load(path)
	queue_redraw()


func set_mood(m: PortraitMood.Mood) -> void:
	if m != mood:
		mood = m
		_since = 0.0
		queue_redraw()


func has_art(m: PortraitMood.Mood) -> bool:
	return _art.has(m)


func _process(delta: float) -> void:
	_since += delta
	if mood == PortraitMood.Mood.LOW_HP or _since < 0.4:
		queue_redraw()  # Low HP pulses; a new mood pops in.


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	var pop := 1.0 + 0.12 * maxf(0.0, 1.0 - _since / 0.25)
	var r := s / 2.0 * pop
	var accent := HeroLettering.accent(hero_id)
	# Frame: team colour ring around the accent card.
	draw_circle(c, r, team_color)
	var bg := accent.darkened(0.15)
	if mood == PortraitMood.Mood.LOW_HP:
		bg = bg.lerp(Color("ff3b30"), 0.35 + 0.15 * sin(Time.get_ticks_msec() / 120.0))
	draw_circle(c, r - 3.0, bg)
	if _art.has(mood):
		var tex: Texture2D = _art[mood]
		draw_texture_rect(tex, Rect2(c - Vector2(r, r) + Vector2(3, 3), Vector2(r, r) * 2.0 - Vector2(6, 6)), false)
		return
	_draw_placeholder(c, r - 3.0)


func _draw_placeholder(c: Vector2, r: float) -> void:
	var ink := Color("1d1a24")
	# Monogram, big and faint, behind the face.
	var f := HeroLettering.font(hero_id)
	var letter := String(hero_id).substr(0, 1).to_upper()
	var fs := int(r * 1.5 * HeroLettering.size_scale(hero_id))
	var w := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, c + Vector2(-w / 2.0, r * 0.5), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.28))
	var eye_y := c.y - r * 0.12
	var eye_dx := r * 0.32
	var mouth_y := c.y + r * 0.38
	match mood:
		PortraitMood.Mood.AHEAD:
			# Happy: closed-arc eyes, big grin, raised brows.
			for side in [-1.0, 1.0]:
				draw_arc(Vector2(c.x + side * eye_dx, eye_y + 2), r * 0.11, PI, TAU, 8, ink, 3.0)
			draw_arc(Vector2(c.x, mouth_y - r * 0.12), r * 0.3, 0.15, PI - 0.15, 12, ink, 3.5)
		PortraitMood.Mood.BEHIND:
			# Worried: dot eyes, slanted brows, frown.
			for side in [-1.0, 1.0]:
				draw_circle(Vector2(c.x + side * eye_dx, eye_y), r * 0.08, ink)
				draw_line(Vector2(c.x + side * eye_dx * 1.5, eye_y - r * 0.22), Vector2(c.x + side * eye_dx * 0.5, eye_y - r * 0.3), ink, 3.0)
			draw_arc(Vector2(c.x, mouth_y + r * 0.14), r * 0.24, PI + 0.3, TAU - 0.3, 12, ink, 3.5)
		PortraitMood.Mood.LOW_HP:
			# Hurt: squeezed X eyes, gritted teeth, a sweat drop.
			for side in [-1.0, 1.0]:
				var e := Vector2(c.x + side * eye_dx, eye_y)
				var k := r * 0.09
				draw_line(e + Vector2(-k, -k), e + Vector2(k, k), ink, 3.0)
				draw_line(e + Vector2(-k, k), e + Vector2(k, -k), ink, 3.0)
			var m := Rect2(c.x - r * 0.28, mouth_y - r * 0.08, r * 0.56, r * 0.18)
			draw_rect(m, Color.WHITE)
			draw_rect(m, ink, false, 2.5)
			for i in 3:
				var x := m.position.x + m.size.x * (i + 1) / 4.0
				draw_line(Vector2(x, m.position.y), Vector2(x, m.end.y), ink, 1.5)
			draw_circle(Vector2(c.x + r * 0.62, eye_y - r * 0.2), r * 0.09, Color("9fe0ff"))
		_:
			# Neutral: dot eyes, straight mouth.
			for side in [-1.0, 1.0]:
				draw_circle(Vector2(c.x + side * eye_dx, eye_y), r * 0.08, ink)
			draw_line(Vector2(c.x - r * 0.22, mouth_y), Vector2(c.x + r * 0.22, mouth_y), ink, 3.5)
