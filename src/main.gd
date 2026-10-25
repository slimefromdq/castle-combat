extends Node
## Boot flow: hero and deck select, then a match, then back.

var _menu: CanvasLayer
var _match: MatchController
var _hero_index := 0
var _hero_buttons: Array[Button] = []
var _blurb: Label
## Indices into MatchController.ITEMS chosen for the deck (kept between matches).
var _deck: Array[int] = []
var _item_buttons: Array[Button] = []
var _deck_label: Label
var _play: Button


func _ready() -> void:
	_build_menu()
	# Dev shortcut: `godot -- --autoplay` skips the menu (used by smoke tests and screenshots).
	var args := OS.get_cmdline_user_args()
	if "--autoplay" in args:
		_start_match()
		_apply_dev_args(args)
	elif args.size() > 0:
		_apply_dev_args(args)  # e.g. a screenshot of the menu


## Dev-only flags for smoke tests and screenshots, e.g.
## godot -- --autoplay --seat=red --touch --walk-up --screenshot=shot.png --frames=90
## godot -- --autoplay --autopilot --skip=90   (bot plays you; jump 90 s into the match)
func _apply_dev_args(args: PackedStringArray) -> void:
	var frames := 60
	var shot := ""
	for a in args:
		if a == "--seat=red":
			_match.toggle_seat()
		elif a == "--touch":
			_match.toggle_touch()
		elif a == "--autopilot":
			_match.autopilot = BotSource.new()
		elif a.begins_with("--skip="):
			_match.fast_forward(float(a.get_slice("=", 1)))
		elif a.begins_with("--stage="):
			_match.stage(a.get_slice("=", 1))
		elif a == "--walk-up":
			Input.action_press("move_up")
		elif a.begins_with("--frames="):
			frames = int(a.get_slice("=", 1))
		elif a.begins_with("--screenshot="):
			shot = a.get_slice("=", 1)
	if shot.is_empty():
		return
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(shot)
	get_tree().quit()


func _start_match() -> void:
	_menu.visible = false
	_match = MatchController.new()
	_match.hero_index = _hero_index
	_match.deck = MatchController.deck_from(_deck)
	_match.exit_requested.connect(_end_match)
	_match.restart_requested.connect(_restart_match)
	add_child(_match)


func _restart_match() -> void:
	_end_match()
	_start_match()


func _end_match() -> void:
	if _match:
		_match.queue_free()
		_match = null
	_menu.visible = true


func _pick(i: int) -> void:
	_hero_index = i
	for j in _hero_buttons.size():
		_hero_buttons[j].button_pressed = j == i
	_blurb.text = MatchController.HEROES[i].blurb


## Toggle an item in or out of the deck; the deck must be full to play.
func _toggle_item(i: int) -> void:
	if _deck.has(i):
		_deck.erase(i)
	elif _deck.size() < MatchController.CONFIG.deck_size:
		_deck.append(i)
	_refresh_deck()


func _refresh_deck() -> void:
	var need := MatchController.CONFIG.deck_size
	for j in _item_buttons.size():
		_item_buttons[j].button_pressed = _deck.has(j)
	_deck_label.text = "Your item deck: %d / %d picked" % [_deck.size(), need]
	_play.disabled = _deck.size() != need
	_play.text = "Play" if _deck.size() == need else "Pick %d more item%s" % [need - _deck.size(), "" if need - _deck.size() == 1 else "s"]


func _build_menu() -> void:
	_menu = CanvasLayer.new()
	add_child(_menu)
	var bg := ColorRect.new()
	bg.color = Palette.BACKGROUND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = UiKit.make_theme()
	_menu.add_child(center)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(660, 0)
	v.add_theme_constant_override("separation", 18)
	center.add_child(v)
	var title := UiKit.label("Castle Combat", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := UiKit.label("Prototype · levels, abilities and item decks", 22, Color(1, 1, 1, 0.6))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(UiKit.label("Pick a hero", 26))
	for i in MatchController.HEROES.size():
		var b := UiKit.button(MatchController.HEROES[i].display_name, Vector2(0, 72))
		b.toggle_mode = true
		b.pressed.connect(_pick.bind(i))
		v.add_child(b)
		_hero_buttons.append(b)
	_blurb = UiKit.label("", 20, Color(1, 1, 1, 0.75))
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size = Vector2(660, 60)
	v.add_child(_blurb)
	_deck_label = UiKit.label("", 26)
	v.add_child(_deck_label)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for i in MatchController.ITEMS.size():
		var item := MatchController.ITEMS[i]
		var b := UiKit.button("%s · %d\n%s" % [item.display_name, item.cost, item.summary], Vector2(212, 60))
		b.add_theme_font_size_override("font_size", 13)
		b.tooltip_text = "%s (%s item)\n%s" % [item.display_name, ["early", "mid", "late"][item.tier], item.summary]
		b.self_modulate = [Color(0.85, 0.95, 1.0), Color(1.0, 0.92, 0.8), Color(1.0, 0.8, 1.0)][item.tier]
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.pressed.connect(_toggle_item.bind(i))
		grid.add_child(b)
		_item_buttons.append(b)
	_play = UiKit.button("Play", Vector2(0, 88))
	_play.add_theme_font_size_override("font_size", 32)
	_play.pressed.connect(_start_match)
	v.add_child(_play)
	var help := UiKit.label("WASD / arrows move · stop to attack · click a unit to focus it · 1-8 buy items (press an owned one twice to sell) · Tab hide cards · F drop Relay · F2 swap seat · F3 touch · F1 debug · Esc menu", 17, Color(1, 1, 1, 0.5))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(help)
	_pick(0)
	_deck.assign(MatchController.DEFAULT_DECK)
	_refresh_deck()
