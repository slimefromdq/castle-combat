class_name Hud
extends CanvasLayer
## Portrait HUD. Top band: the opponent. Bottom band: you, gold and the item tray.
## Between them the lane stays clear; thumbs live just above the bottom band.
## Reads the sim, never writes to it: buttons raise signals the match controller handles.

signal seat_toggle_pressed
signal touch_toggle_pressed
signal debug_toggle_pressed
signal menu_pressed

const BOTTOM_H := 214.0
const MARGIN := 12.0

var joystick: ThumbStick
var debug_visible := true

var _root: Control
var _top: PanelContainer
var _bottom: PanelContainer
var _them_name: Label
var _them_hp: ProgressBar
var _them_structs: Array = []
var _you_name: Label
var _you_hp: ProgressBar
var _you_structs: Array = []
var _gold: Label
var _relay: Label
var _debug: Label
var _touch_button: Button
var _seat_button: Button


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiKit.make_theme()
	add_child(_root)
	var inset := _top_safe_inset()
	_build_top(inset)
	_build_tools(inset)
	_build_bottom()
	_build_thumbs()


func set_touch_mode(on: bool, mouse_emulation: bool) -> void:
	joystick.visible = on
	joystick.use_mouse = mouse_emulation
	joystick.release()
	_touch_button.text = "Touch: on" if on else "Touch: off"


func set_debug_visible(on: bool) -> void:
	debug_visible = on
	_debug.visible = on


func refresh(sim: MatchSim, seat: int, fps: float) -> void:
	var me := sim.heroes[seat]
	var them := sim.heroes[1 - seat]
	_you_name.text = "You · %s" % me.data.display_name
	_them_name.text = "Them · %s" % them.data.display_name
	_you_hp.value = me.hp / me.max_hp
	_them_hp.value = them.hp / them.max_hp
	_fill_structs(sim, seat, _you_structs)
	_fill_structs(sim, 1 - seat, _them_structs)
	_gold.text = "Gold 0"
	_seat_button.text = "Seat: %s" % ("blue" if seat == MatchSim.BLUE else "red")
	var until := sim.config.first_relay_time - sim.time
	_relay.text = "Relay in %d:%02d" % [int(until) / 60, int(until) % 60] if until > 0.0 else "Relay: coming in M2"
	if debug_visible:
		_debug.text = "FPS %d   tick %d   t %.1fs\nyou (%.1f, %.1f) %s" % [
			fps, sim.tick, sim.time, me.pos.x, me.pos.y, "moving" if me.moving else "stopped"]


func _fill_structs(sim: MatchSim, team: int, widgets: Array) -> void:
	var list := sim.structures_of(team)
	for i in list.size():
		var s := list[i]
		var w: Dictionary = widgets[i]
		w.bar.value = s.hp / s.max_hp
		var locked := not sim.is_exposed(s)
		w.label.text = ("%s · locked" % s.data.display_name) if locked else s.data.display_name
		w.label.modulate.a = 0.55 if locked else 1.0


func _struct_row(color: Color, into: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for i in 3:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		var l := UiKit.label("", 17, Color(1, 1, 1, 0.85))
		var b := UiKit.bar(color.darkened(0.15), 10)
		col.add_child(l)
		col.add_child(b)
		row.add_child(col)
		into.append({"label": l, "bar": b})
	return row


func _build_top(inset: float) -> void:
	_top = PanelContainer.new()
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.offset_left = MARGIN
	_top.offset_right = -MARGIN
	_top.offset_top = MARGIN + inset
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_top)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_top.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_them_name = UiKit.label("Them", 22, Palette.ENEMY.lightened(0.2))
	_them_name.custom_minimum_size = Vector2(230, 0)
	_them_hp = UiKit.bar(Palette.ENEMY, 20)
	_them_hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_them_name)
	row.add_child(_them_hp)
	v.add_child(row)
	v.add_child(_struct_row(Palette.ENEMY, _them_structs))


func _build_tools(inset: float) -> void:
	var tools := HBoxContainer.new()
	tools.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tools.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tools.offset_top = 132 + inset
	tools.offset_right = -MARGIN
	tools.add_theme_constant_override("separation", 6)
	_root.add_child(tools)
	_seat_button = _tool_button(tools, "Seat: blue", "F2: swap seats (camera turns 180°)", seat_toggle_pressed)
	_touch_button = _tool_button(tools, "Touch: off", "F3: phone controls, driven by the mouse", touch_toggle_pressed)
	_tool_button(tools, "Debug", "F1: debug readout", debug_toggle_pressed)
	_tool_button(tools, "Menu", "Esc: back to hero select", menu_pressed)
	_relay = UiKit.label("Relay", 22, Palette.RELAY)
	_relay.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_relay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_relay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_relay.offset_top = 186 + inset
	_root.add_child(_relay)
	_debug = UiKit.label("", 18, Color(1, 1, 1, 0.75))
	_debug.position = Vector2(MARGIN + 4, 186 + inset)
	_root.add_child(_debug)


func _tool_button(parent: Control, text: String, tip: String, sig: Signal) -> Button:
	var b := UiKit.button(text, Vector2(0, 44))
	b.add_theme_font_size_override("font_size", 18)
	b.tooltip_text = tip
	b.pressed.connect(func() -> void: sig.emit())
	parent.add_child(b)
	return b


func _build_bottom() -> void:
	_bottom = PanelContainer.new()
	_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.offset_left = MARGIN
	_bottom.offset_right = -MARGIN
	_bottom.offset_top = -BOTTOM_H
	_bottom.offset_bottom = -MARGIN
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bottom)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_bottom.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_you_name = UiKit.label("You", 22, Palette.ALLY.lightened(0.25))
	_you_name.custom_minimum_size = Vector2(230, 0)
	_you_hp = UiKit.bar(Palette.ALLY, 20)
	_you_hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_you_name)
	row.add_child(_you_hp)
	v.add_child(row)
	v.add_child(_struct_row(Palette.ALLY, _you_structs))
	var tray := HBoxContainer.new()
	tray.add_theme_constant_override("separation", 6)
	_gold = UiKit.label("Gold 0", 20, Color("f5d76e"))
	_gold.custom_minimum_size = Vector2(96, 0)
	_gold.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tray.add_child(_gold)
	for i in 6:
		# Item cards are placeholders until the economy lands in M3.
		var card := UiKit.button("%d\n—" % (i + 1), Vector2(0, 72))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_font_size_override("font_size", 18)
		card.disabled = true
		card.tooltip_text = "Item card (M3)"
		tray.add_child(card)
	v.add_child(tray)


func _build_thumbs() -> void:
	joystick = ThumbStick.new()
	joystick.anchor_left = 0.0
	joystick.anchor_right = 0.55
	joystick.anchor_top = 1.0
	joystick.anchor_bottom = 1.0
	joystick.offset_top = -BOTTOM_H - 320
	joystick.offset_bottom = -BOTTOM_H - 4
	joystick.visible = false
	_root.add_child(joystick)
	# No basic-attack button by design: stopping is the attack. Abilities arrive in M1.
	var ability := UiKit.button("Q\nAbility", Vector2(136, 136))
	ability.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ability.offset_left = -136 - 28
	ability.offset_right = -28
	ability.offset_top = -BOTTOM_H - 136 - 28
	ability.offset_bottom = -BOTTOM_H - 28
	ability.disabled = true
	_root.add_child(ability)
	var ult := UiKit.button("E\nUlt", Vector2(104, 104))
	ult.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ult.offset_left = -136 - 28 - 104 - 20
	ult.offset_right = -136 - 28 - 20
	ult.offset_top = -BOTTOM_H - 104 - 92
	ult.offset_bottom = -BOTTOM_H - 92
	ult.disabled = true
	_root.add_child(ult)


## Keeps the top band clear of notches on phones. Desktop windows have no inset.
func _top_safe_inset() -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var safe := DisplayServer.get_display_safe_area()
	var window_h := float(DisplayServer.window_get_size().y)
	if window_h <= 0.0:
		return 0.0
	return safe.position.y * get_viewport().get_visible_rect().size.y / window_h
