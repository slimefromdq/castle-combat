class_name MainMenu
extends CanvasLayer
## Home screen, laid out like Clash Royale and dressed in yellow-and-black noir.
## Top: profile and currency stickers. Middle: swipeable pages. Bottom: tab bar
## (Shop, Heroes & Items, Battle, Clan, Tournaments). Battle shows your hero's 3D model
## and the Play button; Heroes & Items picks the hero and builds the item deck.

signal play_requested

enum Tab { SHOP, HEROES, BATTLE, CLAN, TOURNAMENTS }
const TAB_INFO := [
	{"name": "Shop", "icon": "shop"},
	{"name": "Heroes & Items", "icon": "heroes"},
	{"name": "Battle", "icon": "battle"},
	{"name": "Clan", "icon": "clan"},
	{"name": "Tournaments", "icon": "tournaments"},
]
## Design width of the menu column (the project's design resolution is 720x1280).
const COLUMN := 720.0
const SWIPE_MIN := 110.0

## Index into MatchController.HEROES.
var hero_index := 0
## Indices into MatchController.ITEMS (kept between matches).
var deck: Array[int] = []
## Index into Tricks.IDS: the Trick you bring (kept between matches).
var trick_index := 0
var current_tab := Tab.BATTLE

var _pager: Control
var _pages: Array[Control] = []
var _tab_buttons: Array[Button] = []
var _tab_labels: Array[Label] = []
var _tab_icons: Array[DoodleIcon] = []
var _pager_tween: Tween

# Battle page
var _stage: HeroStage
var _hero_name: Label
var _mute_icon: DoodleIcon
var _volume_slider: HSlider
var _hero_blurb: Label
var _deck_strip: HBoxContainer
var _play: Button

# Heroes & Items page
var _hero_cards: Array[Button] = []
var _kit_label: RichTextLabel
var _deck_title: Label
var _deck_slots: GridContainer
var _trick_buttons: Array[Button] = []
var _item_buttons: Array[Button] = []
var _item_detail: Label

var _press_pos := Vector2.ZERO
var _pressing := false


func _ready() -> void:
	var city := NoirSkyline.new()
	city.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(city)
	var column := VBoxContainer.new()
	column.anchor_left = 0.5
	column.anchor_right = 0.5
	column.anchor_bottom = 1.0
	column.offset_left = -COLUMN * 0.5
	column.offset_right = COLUMN * 0.5
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	column.add_child(_build_top_bar())
	_pager = Control.new()
	_pager.clip_contents = true
	_pager.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pager.mouse_filter = Control.MOUSE_FILTER_PASS
	_pager.resized.connect(_layout_pages.bind(false))
	column.add_child(_pager)
	_pages.resize(TAB_INFO.size())
	_pages[Tab.SHOP] = _build_soon_page("SHOP", "shop", "Skins, emotes and shiny paper goodies.", "Nothing for sale yet. Save your coins!", 21)
	_pages[Tab.HEROES] = _build_heroes_page()
	_pages[Tab.BATTLE] = _build_battle_page()
	_pages[Tab.CLAN] = _build_soon_page("CLAN", "clan", "Team up with friends, share decks, trade tips.", "Gathering the crew...", 33)
	_pages[Tab.TOURNAMENTS] = _build_soon_page("TOURNEYS", "tournaments", "Bracket battles with prizes for the top hero.", "Brackets still being drawn.", 47)
	for p in _pages:
		# Anchored to the pager, so a page always matches its size.
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		_pager.add_child(p)
	column.add_child(_build_tab_bar())
	if deck.is_empty():
		deck.assign(MatchController.DEFAULT_DECK)
	pick_hero(hero_index)
	_refresh_deck()
	show_tab(Tab.BATTLE, false)


# ---------------------------------------------------------------- public

func show_tab(tab: int, animate := true) -> void:
	current_tab = tab
	for i in _tab_buttons.size():
		var on := i == tab
		var b := _tab_buttons[i]
		b.size_flags_stretch_ratio = 1.7 if on else 1.0
		_style_tab(b, on)
		_tab_labels[i].visible = on
		_tab_icons[i].custom_minimum_size = Vector2(68, 68) if on else Vector2(56, 56)
	_layout_pages(animate)


func pick_hero(i: int) -> void:
	if is_inside_tree() and i != hero_index:
		Sfx.play(&"click", -4.0)
	hero_index = i
	var hero := MatchController.HEROES[i]
	_stage.show_hero(hero)
	_hero_name.text = hero.display_name
	HeroLettering.apply(_hero_name, hero.id, 50 if hero.display_name.length() <= 7 else 40)
	_hero_blurb.text = hero.blurb
	for j in _hero_cards.size():
		Noir.style_button(_hero_cards[j], Noir.YELLOW if j == i else Noir.WHITE, 8.0, 8.0)
		var tag: Control = _hero_cards[j].get_node("Picked")
		tag.visible = j == i
	var lines: Array[String] = []
	var unlock := Leveling.ABILITY_LEVELS
	for k in hero.abilities.size():
		var ab := hero.abilities[k]
		var scale := StatCard.scaling(ab)
		lines.append("Lv%d  [b]%s[/b]: %s%s" % [unlock[k], ab.display_name, ab.summary, ("  (" + scale + ")") if scale != "" else ""])
	for tier in hero.perks.size() / 2:
		lines.append("Lv%d  perk: %s or %s" % [Leveling.PERK_LEVELS[tier], hero.perks[tier * 2].display_name, hero.perks[tier * 2 + 1].display_name])
	for k in mini(hero.passives.size(), Leveling.PASSIVE_LEVELS.size()):
		var ps := hero.passives[k]
		lines.append("Lv%d  [b]%s[/b] (automatic): %s" % [Leveling.PASSIVE_LEVELS[k], ps.display_name, ps.summary])
	lines.sort_custom(func(a: String, b: String) -> bool: return int(a.substr(2, 1)) < int(b.substr(2, 1)))
	_kit_label.text = StatCard.for_hero(hero) + "\n\n" + "\n".join(lines)


func deck_full() -> bool:
	return deck.size() == MatchController.CONFIG.deck_size


# ---------------------------------------------------------------- input

## Swipe left/right anywhere on the pages to move between tabs, as in Clash Royale.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var down := false
	var up := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		down = event.pressed
		up = not event.pressed
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		down = event.pressed
		up = not event.pressed
		pos = event.position
	else:
		return
	if down:
		_press_pos = pos
		# Dragging the volume slider is not a page swipe.
		_pressing = _pager.get_global_rect().has_point(pos) and not (_volume_slider != null and _volume_slider.get_global_rect().grow(12).has_point(pos))
	elif up and _pressing:
		_pressing = false
		var d := pos - _press_pos
		if absf(d.x) > SWIPE_MIN and absf(d.x) > absf(d.y) * 2.0:
			var next := clampi(current_tab + (-1 if d.x > 0 else 1), 0, TAB_INFO.size() - 1)
			if next != current_tab:
				show_tab(next)
			# Swallow the release so the button under the finger doesn't fire.
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- layout

func _layout_pages(animate: bool) -> void:
	var w := _pager.size.x
	if _pager_tween:
		_pager_tween.kill()
	if animate:
		_pager_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for i in _pages.size():
			_pager_tween.tween_method(_place_page.bind(i), _pages[i].offset_left, (i - current_tab) * w, 0.32)
	else:
		for i in _pages.size():
			_place_page((i - current_tab) * w, i)


## Slide a page sideways by its offsets only (setting `position` would bake a stale
## size into the offsets).
func _place_page(x: float, i: int) -> void:
	var p := _pages[i]
	p.offset_left = x
	p.offset_right = x
	p.offset_top = 0
	p.offset_bottom = 0


func _build_top_bar() -> Control:
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 14)
	m.add_theme_constant_override("margin_top", 16)
	m.add_theme_constant_override("margin_bottom", 6)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	m.add_child(h)
	# Profile: level tag + name plate with trophies (placeholders until accounts exist).
	var prof := Noir.panel(Noir.INK, 8, 12)
	prof.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pbox := prof.get_theme_stylebox("panel") as NoirBox
	pbox.border_color = Noir.WHITE
	pbox.shadow_color = Noir.WHITE
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 10)
	prof.add_child(ph)
	var lvl := Noir.panel(Noir.YELLOW, 4, 6)
	(lvl.get_theme_stylebox("panel") as NoirBox).shadow = Vector2.ZERO
	var lv := Noir.label("1", Noir.SLAB, 32, Noir.INK)
	lv.custom_minimum_size = Vector2(34, 0)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl.add_child(lv)
	ph.add_child(lvl)
	var name_col := VBoxContainer.new()
	name_col.add_theme_constant_override("separation", -4)
	name_col.add_child(Noir.label("PLAYER", Noir.body(), 26, Noir.WHITE))
	var tro := HBoxContainer.new()
	tro.add_child(DoodleIcon.make("trophy", 22))
	tro.add_child(Noir.label("0", Noir.SLAB, 20, Noir.YELLOW))
	name_col.add_child(tro)
	ph.add_child(name_col)
	h.add_child(prof)
	h.add_child(_currency("coin", "0"))
	h.add_child(_currency("gem", "0"))
	return m


func _currency(icon: String, amount: String) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	Noir.style_button(b, Noir.INK, 6.0)
	b.custom_minimum_size = Vector2(150, 64)
	b.tooltip_text = "Opens the Shop (coming soon)"
	b.pressed.connect(show_tab.bind(Tab.SHOP))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -20
	h.offset_bottom = -6
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(DoodleIcon.make(icon, 36))
	var l := Noir.label(amount, Noir.SLAB, 28, Noir.WHITE)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(Noir.label("+", Noir.SLAB, 30, Noir.YELLOW))
	for c in h.get_children():
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_child(h)
	return b


func _build_tab_bar() -> Control:
	var bar := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Noir.INK
	bg.border_color = Noir.YELLOW
	bg.border_width_top = 5
	bg.content_margin_left = 6
	bg.content_margin_right = 6
	bg.content_margin_top = 8
	bg.content_margin_bottom = 12
	bar.add_theme_stylebox_override("panel", bg)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	bar.add_child(h)
	for i in TAB_INFO.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 104)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = TAB_INFO[i].name
		b.pressed.connect(show_tab.bind(i))
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := DoodleIcon.make(TAB_INFO[i].icon, 56)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(icon)
		var short_name: String = "Heroes" if i == Tab.HEROES else ("Tourneys" if i == Tab.TOURNAMENTS else TAB_INFO[i].name)
		var l := Noir.label(short_name.to_upper(), Noir.SLAB, 22, Noir.INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		b.add_child(v)
		h.add_child(b)
		_tab_buttons.append(b)
		_tab_labels.append(l)
		_tab_icons.append(icon)
	return bar


## The open tab is a yellow slab; the others sit flat on the black bar.
func _style_tab(b: Button, on: bool) -> void:
	if on:
		Noir.style_button(b, Noir.YELLOW, 6.0, 16.0)
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			var box := b.get_theme_stylebox(st) as NoirBox
			box.shadow = Vector2.ZERO
			box.border = 0.0
		return
	var flat := NoirBox.make(Color(Noir.WHITE, 0.0), 6.0, 16.0)
	flat.shadow = Vector2.ZERO
	flat.border = 0.0
	var hover := flat.copy()
	hover.fill = Color(Noir.WHITE, 0.08)
	b.add_theme_stylebox_override("normal", flat)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("hover_pressed", hover)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


# ---------------------------------------------------------------- battle page

func _build_battle_page() -> Control:
	var page := MarginContainer.new()
	for side in ["left", "right"]:
		page.add_theme_constant_override("margin_" + side, 22)
	page.add_theme_constant_override("margin_top", 6)
	page.add_theme_constant_override("margin_bottom", 14)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	page.add_child(v)
	var title := RansomText.make("CASTLE COMBAT", 50, 5)
	v.add_child(title)
	# Showcase: a white impact burst, the 3D hero on its plinth, arrows to flip heroes.
	var show := Control.new()
	show.size_flags_vertical = Control.SIZE_EXPAND_FILL
	show.custom_minimum_size = Vector2(0, 360)
	v.add_child(show)
	var burst := _Burst.new()
	burst.set_anchors_preset(Control.PRESET_FULL_RECT)
	show.add_child(burst)
	_stage = HeroStage.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	show.add_child(_stage)
	for side in [-1, 1]:
		var arrow := Noir.button("<" if side < 0 else ">", Noir.WHITE, Noir.SLAB, 40, Vector2(76, 84))
		arrow.tooltip_text = "Previous hero" if side < 0 else "Next hero"
		if side < 0:
			arrow.set_anchors_preset(Control.PRESET_CENTER_LEFT)
			arrow.position = Vector2(0, -42)
		else:
			arrow.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
			arrow.position = Vector2(-76, -42)
		arrow.pressed.connect(func() -> void: pick_hero(posmod(hero_index + side, MatchController.HEROES.size())))
		show.add_child(arrow)
	# Name plate: a black slab with a white shadow, slapped on crooked.
	var plate_holder := CenterContainer.new()
	plate_holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	plate_holder.offset_top = -78
	plate_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	show.add_child(plate_holder)
	var plate := Noir.panel(Noir.INK, 10, 18)
	var pbox := plate.get_theme_stylebox("panel") as NoirBox
	pbox.shadow = Vector2(8, 8)
	pbox.shadow_color = Noir.WHITE
	pbox.set_margins(10)
	pbox.content_margin_left += 16
	pbox.content_margin_right += 16
	plate.rotation_degrees = -3.0
	plate.resized.connect(func() -> void: plate.pivot_offset = plate.size * 0.5)
	_hero_name = Noir.label("", Noir.SLAB, 46, Noir.YELLOW)
	plate.add_child(_hero_name)
	plate_holder.add_child(plate)
	# Blurb on a white slab.
	var note := Noir.panel(Noir.WHITE, 12, 8)
	note.rotation_degrees = 0.8
	note.resized.connect(func() -> void: note.pivot_offset = note.size * 0.5)
	_hero_blurb = Noir.label("", Noir.body(), 26, Noir.INK)
	_hero_blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_child(_hero_blurb)
	v.add_child(note)
	# Deck preview strip: tap to edit in Heroes & Items.
	var deck_btn := Button.new()
	deck_btn.focus_mode = Control.FOCUS_NONE
	deck_btn.tooltip_text = "Edit your item deck"
	Noir.style_button(deck_btn, Noir.INK, 8.0, 8.0)
	deck_btn.custom_minimum_size = Vector2(0, 108)
	deck_btn.pressed.connect(show_tab.bind(Tab.HEROES))
	var dv := VBoxContainer.new()
	dv.set_anchors_preset(Control.PRESET_FULL_RECT)
	dv.offset_left = 16
	dv.offset_top = 6
	dv.offset_right = -22
	dv.offset_bottom = -14
	dv.add_theme_constant_override("separation", 4)
	dv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dh := HBoxContainer.new()
	var dt := Noir.label("ITEM DECK", Noir.SLAB, 22, Noir.YELLOW)
	dt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dh.add_child(dt)
	dh.add_child(Noir.label("TAP TO EDIT  >", Noir.body(), 20, Noir.WHITE))
	dv.add_child(dh)
	_deck_strip = HBoxContainer.new()
	_deck_strip.add_theme_constant_override("separation", 6)
	_deck_strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(_deck_strip)
	deck_btn.add_child(dv)
	v.add_child(deck_btn)
	# The big Battle button: a yellow slab cut at a slant, white shadow on the black street.
	_play = Noir.button("PLAY!", Noir.YELLOW, Noir.slanted(Noir.SLAB), 76, Vector2(0, 136))
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		var box := _play.get_theme_stylebox(st) as NoirBox
		box.shadow = Vector2(9, 9)
		box.shadow_color = Noir.WHITE
		box.skew = 22.0
		box.kick = 10.0
		box.border = 4.0
		box.dots = Color(Noir.YELLOW_DEEP, 0.9)
		box.set_margins(10)
	_play.pressed.connect(_on_play)
	var play_row := HBoxContainer.new()
	play_row.add_theme_constant_override("separation", 12)
	_play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play.size_flags_stretch_ratio = 2.2
	play_row.add_child(_play)
	var mode := Noir.panel(Noir.WHITE, 8, 14)
	(mode.get_theme_stylebox("panel") as NoirBox).shadow_color = Noir.YELLOW
	mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mv := VBoxContainer.new()
	mv.alignment = BoxContainer.ALIGNMENT_CENTER
	mv.add_theme_constant_override("separation", -6)
	for t in [["1V1", Noir.SLAB, 40], ["VS BOT", Noir.body(), 24]]:
		var l := Noir.label(t[0], t[1], t[2], Noir.INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mv.add_child(l)
	mode.add_child(mv)
	play_row.add_child(mode)
	v.add_child(play_row)
	if not DisplayServer.is_touchscreen_available():
		var help := Noir.label("WASD move · stop to attack · Q/E/R cast at the mouse · Tab details · F11 fullscreen · M mute · Esc menu", HeroLettering.hud_font(), 18, Noir.ASH)
		help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(help)
	v.add_child(_sound_row())
	return page


## Sound: a speaker tag that mutes, and a volume slider.
func _sound_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var mute := Button.new()
	mute.focus_mode = Control.FOCUS_NONE
	mute.custom_minimum_size = Vector2(70, 56)
	mute.tooltip_text = "Sound on/off (M)"
	Noir.style_button(mute, Noir.WHITE, 4.0, 10.0)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		(mute.get_theme_stylebox(st) as NoirBox).shadow_color = Noir.YELLOW
	var icon := DoodleIcon.make("speaker_off" if Sfx.muted else "speaker", 36)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_right = -6
	center.offset_bottom = -6
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon)
	mute.add_child(center)
	_mute_icon = icon
	mute.pressed.connect(func() -> void:
		Sfx.toggle_mute()
		_refresh_sound()
		Sfx.play(&"click"))
	row.add_child(mute)
	row.add_child(Noir.label("SOUND", Noir.SLAB, 24, Noir.WHITE))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Sfx.volume
	slider.custom_minimum_size = Vector2(240, 40)
	slider.focus_mode = Control.FOCUS_NONE
	# A smoke track with a white edge that fills yellow.
	var track := StyleBoxFlat.new()
	track.bg_color = Noir.SMOKE
	track.border_color = Noir.WHITE
	track.set_border_width_all(3)
	track.skew = Vector2(0.4, 0)
	track.content_margin_top = 7
	track.content_margin_bottom = 7
	var fill := track.duplicate()
	fill.bg_color = Noir.YELLOW
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.value_changed.connect(func(v: float) -> void:
		Sfx.set_volume(v)
		if Sfx.muted and v > 0.0:
			Sfx.set_muted(false)
		_refresh_sound()
		Sfx.play(&"click", 0.0, 1.0, 0.08))
	_volume_slider = slider
	row.add_child(slider)
	return row


func _refresh_sound() -> void:
	if _mute_icon != null:
		_mute_icon.kind = "speaker_off" if Sfx.muted else "speaker"
		_mute_icon.queue_redraw()


func _on_play() -> void:
	Sfx.play(&"click")
	if deck_full():
		play_requested.emit()
	else:
		show_tab(Tab.HEROES)


# ---------------------------------------------------------------- heroes & items page

func _build_heroes_page() -> Control:
	# A black sheet over the city, so long lists stay easy to read.
	var sheet := PanelContainer.new()
	var shade := StyleBoxFlat.new()
	shade.bg_color = Color(Noir.INK, 0.86)
	sheet.add_theme_stylebox_override("panel", shade)
	sheet.mouse_filter = Control.MOUSE_FILTER_PASS
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 0)
	sheet.add_child(page)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 18)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)
	v.add_child(_section("HEROES"))
	var row := GridContainer.new()
	row.columns = 4
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	v.add_child(row)
	for i in MatchController.HEROES.size():
		var hero := MatchController.HEROES[i]
		var card := Button.new()
		card.focus_mode = Control.FOCUS_NONE
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 200)
		card.tooltip_text = hero.blurb
		card.pressed.connect(pick_hero.bind(i))
		var cv := VBoxContainer.new()
		cv.set_anchors_preset(Control.PRESET_FULL_RECT)
		cv.offset_left = 8
		cv.offset_top = 6
		cv.offset_right = -14
		cv.offset_bottom = -14
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var stage := HeroStage.new()
		stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stage.spin_speed = 0.8 + i * 0.15
		stage.show_hero(hero)
		cv.add_child(stage)
		var n := Noir.label(hero.display_name, Noir.body(), 26, Noir.INK)
		HeroLettering.apply(n, hero.id, 30 if hero.display_name.length() <= 7 else 21)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(n)
		card.add_child(cv)
		var tag := _tag("PICKED", 18)
		tag.name = "Picked"
		tag.position = Vector2(-6, -10)
		card.add_child(tag)
		row.add_child(card)
		_hero_cards.append(card)
	var kit := Noir.panel(Noir.WHITE, 14, 6)
	_kit_label = RichTextLabel.new()
	_kit_label.bbcode_enabled = true
	_kit_label.fit_content = true
	_kit_label.scroll_active = false
	_kit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kit_label.add_theme_font_override("normal_font", HeroLettering.hud_font())
	_kit_label.add_theme_font_override("bold_font", HeroLettering.hud_bold())
	_kit_label.add_theme_font_size_override("normal_font_size", 23)
	_kit_label.add_theme_font_size_override("bold_font_size", 23)
	_kit_label.add_theme_color_override("default_color", Noir.INK)
	kit.add_child(_kit_label)
	v.add_child(kit)
	v.add_child(_section("YOUR TRICK"))
	var trick_row := GridContainer.new()
	trick_row.columns = 4
	trick_row.add_theme_constant_override("h_separation", 8)
	v.add_child(trick_row)
	for i in Tricks.IDS.size():
		var b := _trick_card(i)
		b.pressed.connect(pick_trick.bind(i))
		trick_row.add_child(b)
		_trick_buttons.append(b)
	_refresh_tricks()
	_deck_title = Noir.label("", Noir.SLAB, 30)  # text set in _refresh_deck
	v.add_child(_section("YOUR DECK", _deck_title))
	_deck_slots = GridContainer.new()
	_deck_slots.columns = 4
	_deck_slots.add_theme_constant_override("h_separation", 8)
	_deck_slots.add_theme_constant_override("v_separation", 8)
	v.add_child(_deck_slots)
	var hint := Noir.label("Tap a card below to add it, tap a deck card to take it out. Decks hold %d." % MatchController.CONFIG.deck_size, HeroLettering.hud_font(), 21, Noir.ASH)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	v.add_child(_section("ALL ITEMS", _tier_legend()))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	# Early to late, so the grid reads like a shop shelf.
	var order: Array[int] = []
	for tier in 3:
		for i in MatchController.ITEMS.size():
			if MatchController.ITEMS[i].tier == tier:
				order.append(i)
	_item_buttons.resize(MatchController.ITEMS.size())
	for i in order:
		var b := _item_card(i, false)
		b.pressed.connect(_toggle_item.bind(i))
		grid.add_child(b)
		_item_buttons[i] = b
	# Detail footer: what the last tapped card does.
	var foot := MarginContainer.new()
	for side in ["left", "right"]:
		foot.add_theme_constant_override("margin_" + side, 18)
	foot.add_theme_constant_override("margin_bottom", 8)
	foot.add_theme_constant_override("margin_top", 6)
	var fp := Noir.panel(Noir.YELLOW, 12, 10)
	(fp.get_theme_stylebox("panel") as NoirBox).shadow_color = Noir.WHITE
	fp.custom_minimum_size = Vector2(0, 88)
	_item_detail = Noir.label("Tap any item to read what it does.", Noir.body(), 23, Noir.INK)
	_item_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fp.add_child(_item_detail)
	foot.add_child(fp)
	page.add_child(foot)
	return sheet


## A section header: a yellow slab with black slab lettering and a white shadow.
func _section(text: String, right: Control = null) -> Control:
	var h := HBoxContainer.new()
	var p := Noir.panel(Noir.YELLOW, 8, 14)
	var box := p.get_theme_stylebox("panel") as NoirBox
	box.shadow_color = Noir.WHITE
	box.content_margin_left += 8
	box.content_margin_right += 10
	p.add_child(Noir.label(text, Noir.SLAB, 30, Noir.INK))
	p.rotation_degrees = -1.5
	h.add_child(p)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(gap)
	if right:
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(right)
	return h


func _tier_legend() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for t in 3:
		var p := Noir.panel(Noir.TIER_COLORS[t], 4, 8)
		var box := p.get_theme_stylebox("panel") as NoirBox
		box.shadow = Vector2.ZERO
		box.border_color = Noir.YELLOW if t == 2 else Noir.INK
		box.set_margins(4)
		p.add_child(Noir.label(Noir.TIER_NAMES[t].to_upper(), Noir.SLAB, 18, Noir.ink_on(Noir.TIER_COLORS[t])))
		h.add_child(p)
	return h


## A small tilted tag (PICKED, IN DECK): black slab, yellow lettering.
func _tag(text: String, size_px: int) -> Control:
	var tag := Noir.panel(Noir.INK, 3, 6)
	var tb := tag.get_theme_stylebox("panel") as NoirBox
	tb.shadow = Vector2(3, 3)
	tb.shadow_color = Noir.YELLOW
	tb.border_color = Noir.YELLOW
	tb.set_margins(3)
	tb.content_margin_left += 4
	tb.content_margin_right += 4
	tag.add_child(Noir.label(text, Noir.SLAB, size_px, Noir.YELLOW))
	tag.rotation_degrees = -7
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tag


## Styles an item or Trick card: tier fill, and a yellow edge on black cards.
func _style_card(b: Button, fill: Color) -> void:
	Noir.style_button(b, fill, 6.0, 8.0)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		var box := b.get_theme_stylebox(st) as NoirBox
		if fill.get_luminance() < 0.2:
			box.border_color = Noir.YELLOW
		box.shadow = Vector2(5, 5)
		box.shadow_color = Noir.WHITE if fill.get_luminance() < 0.2 else Noir.SMOKE
		box.set_margins(6)


## One item card: tier fill, name, cost. `slot` cards sit in the deck rows.
func _item_card(i: int, slot: bool) -> Button:
	var item := MatchController.ITEMS[i]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 104)
	b.tooltip_text = "%s (%s, %d gold)\n%s" % [item.display_name, Noir.TIER_NAMES[item.tier], item.cost, item.summary]
	var fill: Color = Noir.TIER_COLORS[item.tier]
	_style_card(b, fill)
	b.button_down.connect(_show_detail.bind(i))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_top = 6
	v.offset_right = -16
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", -2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink := Noir.WHITE if fill.get_luminance() < 0.2 else Noir.INK
	var n := Noir.label(item.display_name, Noir.body(), 19, ink)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.size_flags_vertical = Control.SIZE_EXPAND_FILL
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var cost := HBoxContainer.new()
	cost.alignment = BoxContainer.ALIGNMENT_CENTER
	cost.add_theme_constant_override("separation", 3)
	cost.add_child(DoodleIcon.make("coin", 18))
	cost.add_child(Noir.label(str(item.cost), Noir.SLAB, 19, Noir.ink_on(fill)))
	v.add_child(cost)
	b.add_child(v)
	if not slot:
		var check := _tag("IN DECK", 14)
		check.name = "Check"
		check.position = Vector2(-4, -8)
		b.add_child(check)
	return b


## One Trick card: white, or yellow with a PICKED tag when chosen.
func _trick_card(i: int) -> Button:
	var id: StringName = Tricks.IDS[i]
	var cfg := MatchController.CONFIG
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 92)
	b.tooltip_text = "%s (%d s)\n%s" % [Tricks.display_name(id), roundi(Tricks.cooldown(cfg, id)), Tricks.summary(cfg, id)]
	_style_card(b, Noir.WHITE)
	var n := Noir.label(Tricks.display_name(id).to_upper(), Noir.SLAB, 26, Noir.INK)
	n.set_anchors_preset(Control.PRESET_FULL_RECT)
	n.offset_bottom = -6
	n.offset_right = -6
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(n)
	var tag := _tag("PICKED", 14)
	tag.name = "Picked"
	tag.position = Vector2(-4, -8)
	b.add_child(tag)
	return b


func pick_trick(i: int) -> void:
	trick_index = clampi(i, 0, Tricks.IDS.size() - 1)
	var id: StringName = Tricks.IDS[trick_index]
	if _item_detail != null:
		_item_detail.text = "%s  (Trick · %d s cooldown)\n%s" % [Tricks.display_name(id), roundi(Tricks.cooldown(MatchController.CONFIG, id)), Tricks.summary(MatchController.CONFIG, id)]
	_refresh_tricks()


func _refresh_tricks() -> void:
	for i in _trick_buttons.size():
		var on := i == trick_index
		_style_card(_trick_buttons[i], Noir.YELLOW if on else Noir.WHITE)
		_trick_buttons[i].get_node("Picked").visible = on


func _show_detail(i: int) -> void:
	var item := MatchController.ITEMS[i]
	_item_detail.text = "%s  (%s · %d gold)\n%s" % [item.display_name, Noir.TIER_NAMES[item.tier], item.cost, item.summary]


func _toggle_item(i: int) -> void:
	if deck.has(i):
		deck.erase(i)
	elif deck.size() < MatchController.CONFIG.deck_size:
		deck.append(i)
	else:
		_item_detail.text = "Your deck is full. Tap a card in YOUR DECK to take it out, then add %s." % MatchController.ITEMS[i].display_name
	_refresh_deck()


func _refresh_deck() -> void:
	var need := MatchController.CONFIG.deck_size
	_deck_title.text = "%d / %d" % [deck.size(), need]
	_deck_title.add_theme_color_override("font_color", Noir.WHITE if deck.size() == need else Noir.YELLOW)
	for c in _deck_slots.get_children():
		c.queue_free()
	for k in need:
		if k < deck.size():
			var b := _item_card(deck[k], true)
			b.pressed.connect(_toggle_item.bind(deck[k]))
			_deck_slots.add_child(b)
		else:
			_deck_slots.add_child(_empty_slot(104, 40))
	for i in _item_buttons.size():
		var b := _item_buttons[i]
		var inside := deck.has(i)
		b.get_node("Check").visible = inside
		b.modulate = Color(0.6, 0.6, 0.6) if inside else Color.WHITE
	# Battle page: mini deck strip and the Play button.
	for c in _deck_strip.get_children():
		c.queue_free()
	for k in need:
		if k >= deck.size():
			var e := _empty_slot(0, 24)
			e.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_deck_strip.add_child(e)
			continue
		var item := MatchController.ITEMS[deck[k]]
		var fill: Color = Noir.TIER_COLORS[item.tier]
		var chip := Noir.panel(fill, 2, 5)
		var box := chip.get_theme_stylebox("panel") as NoirBox
		box.shadow = Vector2.ZERO
		box.border = 2.0
		box.border_color = Noir.YELLOW if fill.get_luminance() < 0.2 else Noir.INK
		box.set_margins(2)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var t := Noir.label(_initials(item.display_name), Noir.SLAB, 26, Noir.ink_on(fill))
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_child(t)
		chip.tooltip_text = item.display_name
		_deck_strip.add_child(chip)
	var left := need - deck.size()
	if left == 0:
		_play.text = "PLAY!"
		_play.add_theme_font_size_override("font_size", 76)
	else:
		_play.text = "PICK %d MORE" % left
		_play.add_theme_font_size_override("font_size", 38)


## An empty deck slot: a faint outlined slab with a "?".
func _empty_slot(height: float, q_size: int) -> Control:
	var empty := Noir.panel(Color(Noir.WHITE, 0.06), 4, 8)
	var box := empty.get_theme_stylebox("panel") as NoirBox
	box.shadow = Vector2.ZERO
	box.border = 2.0
	box.border_color = Color(Noir.WHITE, 0.45)
	box.set_margins(4)
	empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty.custom_minimum_size = Vector2(0, height)
	var q := Noir.label("?", Noir.SLAB, q_size, Color(Noir.WHITE, 0.45))
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty.add_child(q)
	return empty


static func _initials(name: String) -> String:
	var out := ""
	for w in name.replace("'s", "").split(" ", false):
		out += w[0]
	return out.substr(0, 2).to_upper()


## Coming-soon page: ransom title, the tab's icon on an impact burst, a note, a way back.
func _build_soon_page(title: String, icon: String, pitch: String, status: String, seed_value: int) -> Control:
	var page := MarginContainer.new()
	for side in ["left", "right"]:
		page.add_theme_constant_override("margin_" + side, 36)
	page.add_theme_constant_override("margin_top", 20)
	page.add_theme_constant_override("margin_bottom", 30)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 22)
	page.add_child(v)
	v.add_child(RansomText.make(title, 72, seed_value))
	var art := Control.new()
	art.custom_minimum_size = Vector2(0, 300)
	v.add_child(art)
	var burst := _Burst.new()
	burst.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.add_child(burst)
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(DoodleIcon.make(icon, 190))
	art.add_child(holder)
	var stamp := _Stamp.new()
	stamp.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.add_child(stamp)
	var note := Noir.panel(Noir.WHITE, 18, 10)
	(note.get_theme_stylebox("panel") as NoirBox).shadow_color = Noir.YELLOW
	note.rotation_degrees = 1.5
	note.resized.connect(func() -> void: note.pivot_offset = note.size * 0.5)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 4)
	var head := Noir.label("COMING SOON", Noir.slanted(Noir.SLAB), 44, Noir.INK)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nv.add_child(head)
	for t in [pitch, status]:
		var l := Noir.label(t, Noir.body(), 26, Noir.INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nv.add_child(l)
	note.add_child(nv)
	v.add_child(note)
	var back := Noir.button("BACK TO BATTLE", Noir.INK, Noir.SLAB, 32, Vector2(0, 84))
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		(back.get_theme_stylebox(st) as NoirBox).shadow_color = Noir.YELLOW
	back.pressed.connect(show_tab.bind(Tab.BATTLE))
	v.add_child(back)
	return page


## A jagged white impact burst with an ink edge and a slowly turning ring of yellow
## speed rays, behind showcase art.
class _Burst:
	extends Control
	var _spin := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_spin += delta * 0.1
			queue_redraw()

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		var c := size * 0.5
		# Speed rays behind the burst.
		for i in 14:
			var a := _spin + TAU * i / 14.0
			var w := 0.07
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a - w), sin(a - w)) * r * 1.05, c + Vector2(cos(a + w), sin(a + w)) * r * 1.05]), Color(Noir.INK, 0.9))
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var pts := PackedVector2Array()
		var n := 18
		for i in n * 2:
			var a := TAU * i / (n * 2) + 0.1
			var k := rng.randf_range(0.86, 0.98) if i % 2 == 0 else rng.randf_range(0.62, 0.7)
			pts.append(c + Vector2(cos(a), sin(a) * 0.92) * r * k)
		var sh := PackedVector2Array()
		for p in pts:
			sh.append(p + Vector2(8, 8))
		draw_colored_polygon(sh, Noir.INK)
		draw_colored_polygon(pts, Noir.WHITE)
		Noir.draw_halftone(self, Rect2(c - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6), Color(Noir.INK, 0.12), 10.0, 2.6, Vector2(1, 1), Vector2(0.2, 0.2))
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, Noir.INK, 4.0, true)


## A crooked "UNDER CONSTRUCTION" strip of hazard tape over coming-soon art.
class _Stamp:
	extends Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var text := "UNDER CONSTRUCTION"
		var fs := 30
		var w := Noir.SLAB.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_set_transform(Vector2(size.x * 0.5, size.y * 0.82), deg_to_rad(-9), Vector2.ONE)
		var r := Rect2(Vector2(-w * 0.5 - 40, -26), Vector2(w + 80, 50))
		draw_rect(r, Noir.YELLOW)
		# Hazard stripes on both ends.
		for k in 4:
			for side in [-1.0, 1.0]:
				var x0 := (r.position.x + 6 + k * 9) if side < 0 else (r.end.x - 34 + k * 9)
				draw_colored_polygon(PackedVector2Array([Vector2(x0, r.end.y), Vector2(x0 + 5, r.end.y), Vector2(x0 + 13, r.position.y), Vector2(x0 + 8, r.position.y)]), Noir.INK)
		draw_rect(r, Noir.INK, false, 4.0)
		draw_string(Noir.SLAB, Vector2(-w * 0.5, 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Noir.INK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
