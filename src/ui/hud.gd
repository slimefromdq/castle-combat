class_name Hud
extends CanvasLayer
## Portrait HUD. Top band: the opponent. Bottom band: you, gold and the item tray.
## Between them the lane stays clear; thumbs live just above the bottom band.
## Reads the sim, never writes to it: buttons raise signals the match controller handles.

signal seat_toggle_pressed
signal touch_toggle_pressed
signal debug_toggle_pressed
signal menu_pressed
signal restart_pressed
signal drop_pressed
signal buy_pressed(slot: int)

const BOTTOM_H := 240.0
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
var _flash: Label
var _flash_until := 0
var _drop: Button
var _cards: Array[Button] = []
var _cards_row: Control
var _them_items: Label
var _you_items: Label
var _deck_seen: Array[ItemData] = []
var _debug: Label
var _touch_button: Button
var _seat_button: Button
var _respawn: Label
var _result: PanelContainer
var _result_title: Label


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
	_build_status()


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
	_gold.text = "Gold\n%d" % int(me.gold)
	_refresh_cards(sim, me)
	_you_items.text = _items_text(me, sim.config.max_items)
	_them_items.text = _items_text(them, sim.config.max_items)
	_respawn.visible = not me.alive and not sim.over
	if _respawn.visible:
		_respawn.text = "Respawning in %d" % ceili(me.respawn_at - sim.time)
	if sim.over and not _result.visible:
		_result_title.text = "Victory!" if sim.winner == seat else "Defeat"
		_result_title.add_theme_color_override("font_color", Palette.ALLY.lightened(0.3) if sim.winner == seat else Palette.ENEMY.lightened(0.2))
		_result.visible = true
	_seat_button.text = "Seat: %s" % ("blue" if seat == MatchSim.BLUE else "red")
	_relay.text = _relay_text(sim, seat)
	_flash.visible = Time.get_ticks_msec() < _flash_until
	_drop.visible = me.carrying_relay
	if debug_visible:
		_debug.text = "FPS %d   tick %d   t %.1fs\nyou (%.1f, %.1f) %s" % [
			fps, sim.tick, sim.time, me.pos.x, me.pos.y, "moving" if me.moving else "stopped"]


## Tab: collapse or open the item cards (gold and owned items stay visible).
func toggle_tray() -> void:
	_cards_row.visible = not _cards_row.visible


func _items_text(h: HeroState, cap: int) -> String:
	var names: Array[String] = []
	for item in h.items:
		names.append(item.display_name)
	for i in cap - h.items.size():
		names.append("—")
	return "Items: " + "  ·  ".join(names)


## Card text and state: owned, affordable, saving up, or locked out by full slots.
func _refresh_cards(sim: MatchSim, me: HeroState) -> void:
	if _deck_seen != me.deck:
		_deck_seen = me.deck.duplicate()
		for i in _cards.size():
			var c := _cards[i]
			if i < me.deck.size():
				c.tooltip_text = "%d: %s (%d gold)\n%s" % [i + 1, me.deck[i].display_name, me.deck[i].cost, me.deck[i].summary]
			c.visible = i < me.deck.size()
	for i in mini(_cards.size(), me.deck.size()):
		var item := me.deck[i]
		var c := _cards[i]
		var owned := me.owns(item)
		var problem := Economy.buy_problem(sim, me, i)
		c.disabled = problem != ""
		var status := "OWNED" if owned else ("%d" % item.cost if problem != "item slots full" else "full")
		c.text = "%s\n%s" % [item.display_name, status]
		var color := Color("8fe388") if owned else (Color("f5d76e") if problem == "" else Color(1, 1, 1, 0.45))
		c.add_theme_color_override("font_color", color)
		c.add_theme_color_override("font_disabled_color", color)


## Short event callouts under the Relay line ("Relay knocked loose!").
func on_sim_event(type: StringName, data: Dictionary, seat: int) -> void:
	var text := ""
	match type:
		&"relay_spawned":
			text = "The Relay is up!"
		&"relay_picked_up":
			text = "You have the Relay" if data.team == seat else "The enemy took the Relay"
		&"relay_dropped":
			text = "Relay knocked loose!" if data.reason == &"intercepted" else "Relay dropped"
		&"relay_returned":
			text = "Relay went back to its pocket"
		&"relay_delivered":
			text = "Delivered! A siege minion joins your next wave" if data.team == seat else "Enemy delivered: their siege minion is coming"
		&"relay_expired":
			text = "The Relay faded"
		&"item_bought":
			if data.team == seat:
				text = "Bought %s" % _item_name(data.item)
	if text != "":
		_flash.text = text
		_flash_until = Time.get_ticks_msec() + 2600


func _item_name(id: StringName) -> String:
	for item in MatchController.ITEMS:
		if item.id == id:
			return item.display_name
	return String(id)


func _relay_text(sim: MatchSim, seat: int) -> String:
	var relay := sim.relay
	var me := sim.heroes[seat]
	match relay.state:
		RelayController.State.DORMANT:
			var until := maxf(0.0, relay.next_spawn_time - sim.time)
			if relay.warned:
				return "Relay in %d · %s pocket" % [ceili(until), _side(sim, relay.pickup_pocket, seat)]
			return "Relay in %d:%02d" % [int(until) / 60, int(until) % 60]
		RelayController.State.SPAWNED:
			return "Relay up · %s pocket · fades in %d" % [_side(sim, relay.pickup_pocket, seat), ceili(relay.expire_at - sim.time)]
		RelayController.State.DROPPED:
			return "Relay dropped · returns in %d" % ceili(relay.return_at - sim.time)
		RelayController.State.CARRIED:
			if me.carrying_relay:
				var where := "Carry it to the %s pocket" % _side(sim, relay.delivery_pocket, seat)
				return where + (" · blocked!" if relay.contested else "")
			return "Enemy has the Relay! Two hits knock it loose"
	return ""


## Which side of *your* screen a pocket is on (the red seat sees the map turned 180°).
func _side(sim: MatchSim, pocket: int, seat: int) -> String:
	var x := sim.arena.pockets[pocket].get_center().x
	if seat != MatchSim.BLUE:
		x = -x
	return "left" if x < 0.0 else "right"


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
	# GDD 8: you can always see the opponent's equipped items (not their deck).
	_them_items = UiKit.label("Items:", 16, Color(1, 1, 1, 0.7))
	v.add_child(_them_items)


func _build_tools(inset: float) -> void:
	var tools := HBoxContainer.new()
	tools.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tools.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tools.offset_top = 156 + inset
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
	_relay.offset_top = 210 + inset
	_root.add_child(_relay)
	_flash = UiKit.label("", 20, Color(1, 1, 1, 0.95))
	_flash.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_flash.offset_top = 242 + inset
	_flash.add_theme_constant_override("outline_size", 8)
	_flash.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_flash.visible = false
	_root.add_child(_flash)
	_debug = UiKit.label("", 18, Color(1, 1, 1, 0.75))
	_debug.position = Vector2(MARGIN + 4, 278 + inset)
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
	_you_items = UiKit.label("Items:", 16, Color(1, 1, 1, 0.7))
	v.add_child(_you_items)
	var tray := HBoxContainer.new()
	tray.add_theme_constant_override("separation", 6)
	_gold = UiKit.label("Gold\n0", 20, Color("f5d76e"))
	_gold.custom_minimum_size = Vector2(76, 0)
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tray.add_child(_gold)
	var cards := HBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 5)
	tray.add_child(cards)
	_cards_row = cards
	for i in 6:
		# One tap buys: no shop screen (GDD 8). Keys 1-6 do the same.
		var card := UiKit.button("", Vector2(0, 72))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.x = 50
		card.add_theme_font_size_override("font_size", 14)
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.clip_text = true
		card.pressed.connect(func() -> void: buy_pressed.emit(i))
		cards.add_child(card)
		_cards.append(card)
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
	# Shown only while you carry the Relay (keyboard: F).
	_drop = UiKit.button("F\nDrop", Vector2(104, 104))
	_drop.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_drop.offset_left = -28 - 104 - 16
	_drop.offset_right = -28 - 16
	_drop.offset_top = -BOTTOM_H - 136 - 28 - 104 - 24
	_drop.offset_bottom = -BOTTOM_H - 136 - 28 - 24
	_drop.add_theme_color_override("font_color", Palette.RELAY)
	_drop.tooltip_text = "F: drop the Relay"
	_drop.pressed.connect(func() -> void: drop_pressed.emit())
	_drop.visible = false
	_root.add_child(_drop)


func _build_status() -> void:
	_respawn = UiKit.label("", 40, Color(1, 1, 1, 0.95))
	_respawn.set_anchors_preset(Control.PRESET_CENTER)
	_respawn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_respawn.grow_vertical = Control.GROW_DIRECTION_BOTH
	_respawn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_respawn.add_theme_constant_override("outline_size", 10)
	_respawn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_respawn.visible = false
	_root.add_child(_respawn)
	_result = PanelContainer.new()
	_result.set_anchors_preset(Control.PRESET_CENTER)
	_result.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_result.grow_vertical = Control.GROW_DIRECTION_BOTH
	_result.custom_minimum_size = Vector2(460, 0)
	_result.visible = false
	_root.add_child(_result)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	_result.add_child(v)
	_result_title = UiKit.label("", 64)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_result_title)
	var again := UiKit.button("Play again", Vector2(0, 76))
	again.pressed.connect(func() -> void: restart_pressed.emit())
	v.add_child(again)
	var menu := UiKit.button("Hero select", Vector2(0, 64))
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	v.add_child(menu)


## Keeps the top band clear of notches on phones. Desktop windows have no inset.
func _top_safe_inset() -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var safe := DisplayServer.get_display_safe_area()
	var window_h := float(DisplayServer.window_get_size().y)
	if window_h <= 0.0:
		return 0.0
	return safe.position.y * get_viewport().get_visible_rect().size.y / window_h
