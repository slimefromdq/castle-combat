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
signal sell_pressed(slot: int)
signal cast_pressed(slot: int)
signal perk_pressed(choice: int)
signal masterwork_pressed(slot: int)
signal scroll_pressed

const BOTTOM_H := 292.0
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
var _ability_buttons: Array[Button] = []
## Level-up perk choice: two cards, shown while a pick is waiting.
var _perk_box: Control
var _perk_title: Label
var _perk_buttons: Array[Button] = []
## Level 6+: Masterwork buttons, one per owned item (C / V / B), and a siege scroll
## button (N), shown at the shop.
var _master_box: Control
var _scroll_button: Button
var _master_buttons: Array[Button] = []
var _master_slots: Array[int] = []
## Push, then shop: the gold readout pulses while you can afford a card away from the
## shop, and the first time each card becomes affordable a callout says so.
var _afford_called := {}
## Enemy spike callout: their name and items pulse after a mid or late item, a
## Masterwork, or winning the race to their ultimate.
var _them_spike_until := 0
var _them_spike_item := &""
var _you_xp: ProgressBar
var _them_xp: ProgressBar
var _cards_row: Control
var _them_items: Label
var _you_items: Label
var _deck_seen: Array[ItemData] = []
## Selling takes two presses: the first arms the card (shows the refund), the second sells.
var _sell_armed := -1
var _sell_armed_until := 0
var _me: HeroState
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
	_build_perk_picker()
	_build_masterwork()
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
	_sim_for_text = sim
	var me := sim.heroes[seat]
	var them := sim.heroes[1 - seat]
	_you_name.text = "You · %s · Lv %d" % [me.data.display_name, me.level]
	_them_name.text = "Them · %s · Lv %d" % [them.data.display_name, them.level]
	_you_xp.value = Leveling.progress(sim, me)
	_them_xp.value = Leveling.progress(sim, them)
	_refresh_abilities(sim, me)
	_refresh_perks(sim, me)
	_you_hp.value = me.hp / me.max_hp
	_them_hp.value = them.hp / them.max_hp
	_fill_structs(sim, seat, _you_structs)
	_fill_structs(sim, 1 - seat, _them_structs)
	_gold.text = "Gold\n%d" % int(me.gold)
	_refresh_cards(sim, me)
	_you_items.text = _items_text(me, sim.config.max_items)
	_them_items.text = _items_text(them, sim.config.max_items)
	_refresh_spikes(sim, me)
	_refresh_masterwork(sim, me)
	_respawn.visible = not me.alive and not sim.over
	if _respawn.visible:
		_respawn.text = "Respawning in %d" % ceili(me.respawn_at - sim.time)
	if sim.over and not _result.visible:
		_result_title.text = "Victory!" if sim.winner == seat else "Defeat"
		_result_title.add_theme_color_override("font_color", Palette.ALLY.lightened(0.3) if sim.winner == seat else Palette.ENEMY.lightened(0.2))
		_result.visible = true
	_seat_button.text = "Seat: %s" % ("blue" if seat == MatchSim.BLUE else "red")
	_relay.text = ("OVERTIME · " if sim.overtime else "") + _relay_text(sim, seat)
	_flash.visible = Time.get_ticks_msec() < _flash_until
	_drop.visible = me.carrying_relay
	if debug_visible:
		_debug.text = "FPS %d   tick %d   t %.1fs\nyou (%.1f, %.1f) %s" % [
			fps, sim.tick, sim.time, me.pos.x, me.pos.y, "moving" if me.moving else "stopped"]


## Ability buttons: key, name, and either a cooldown, the unlock level, a follow-up
## ("Again!", "Fire!", "Blink!", "Burst!"), or nothing.
func _refresh_abilities(sim: MatchSim, me: HeroState) -> void:
	const KEYS := ["Q", "E", "R"]
	const FOLLOW_UP := {&"spin_dash": "Again!", &"sweet_talk": "Fire!", &"cloak_toss": "Blink!", &"vanish": "Burst!"}
	for i in _ability_buttons.size():
		var b := _ability_buttons[i]
		if i >= me.data.abilities.size():
			b.visible = false
			continue
		var a := me.data.abilities[i]
		var title := a.display_name
		if a.effect == &"encore":
			var copied := Abilities.ability_for(sim, me, i)
			title = copied.display_name if copied != null else a.display_name
		var problem := Abilities.cast_problem(sim, me, i)
		var status := ""
		if not me.ability_unlocked(i):
			status = "Lv %d" % (1 + i * 2)
		elif me.alive and Abilities.can_recast(sim, me, i):
			status = FOLLOW_UP.get(a.effect, "Again!")
			if a.effect == &"sweet_talk":
				status = "Fire! %d%%" % roundi(100.0 * clampf((sim.time - me.charging_since) / a.charge_time, 0.0, 1.0))
		elif me.cooldowns[i] > 0.0:
			status = "%.0f" % ceilf(me.cooldowns[i]) if me.cooldowns[i] >= 1.0 else "%.1f" % me.cooldowns[i]
		elif a.effect == &"encore":
			status = "(copied)"
		b.text = "%s\n%s\n%s" % [KEYS[i], title, status]
		b.disabled = problem != ""
		b.tooltip_text = "%s (%s)\n%s\nCooldown %.0f s" % [title, KEYS[i], a.summary, me.ability_cooldown(i)]


## The level-up perk choice: two cards while a pick is waiting (Z / X on a keyboard).
func _refresh_perks(sim: MatchSim, me: HeroState) -> void:
	var tier := me.pending_perk_tier()
	_perk_box.visible = tier >= 0 and not sim.over
	if not _perk_box.visible:
		return
	var left := maxf(0.0, sim.config.perk_auto_pick_time - (sim.time - me.perk_offered_at[tier]))
	_perk_title.text = "Level %d perk: pick one (%ds)" % [2 + tier * 2, ceili(left)]
	var options := me.perk_options(tier)
	for k in _perk_buttons.size():
		var b := _perk_buttons[k]
		b.visible = k < options.size()
		if b.visible:
			b.text = "%s  %s\n%s" % [["Z", "X"][k], options[k].display_name, options[k].summary]


## Tab: collapse or open the item cards (gold and owned items stay visible).
func toggle_tray() -> void:
	_cards_row.visible = not _cards_row.visible


func _items_text(h: HeroState, cap: int) -> String:
	var names: Array[String] = []
	for item in h.items:
		var name := item.display_name + ("+" if h.is_masterwork(item) else "")
		if h != _me and item.id == _them_spike_item and Time.get_ticks_msec() < _them_spike_until:
			name = "NEW " + name
		names.append(name)
	for i in cap - h.items.size():
		names.append("—")
	return "Items: " + "  ·  ".join(names)


## Card text and state: owned (tap twice to sell), affordable, saving up, or locked out
## by full slots. Card colors hint the tier: early, mid, late.
func _refresh_cards(sim: MatchSim, me: HeroState) -> void:
	_me = me
	if _deck_seen != me.deck:
		_deck_seen = me.deck.duplicate()
		for i in _cards.size():
			var c := _cards[i]
			if i < me.deck.size():
				var it := me.deck[i]
				c.tooltip_text = "%d: %s (%d gold, %s)\n%s\nOwned: press again to sell for half." % [i + 1, it.display_name, it.cost, ["early", "mid", "late"][it.tier], it.summary]
			c.visible = i < me.deck.size()
	if Time.get_ticks_msec() > _sell_armed_until:
		_sell_armed = -1
	for i in mini(_cards.size(), me.deck.size()):
		var item := me.deck[i]
		var c := _cards[i]
		var owned := me.owns(item)
		var problem := Economy.buy_problem(sim, me, i)
		var in_shop := Economy.in_shop_range(sim, me)
		c.disabled = (problem != "" and not owned) or not in_shop
		var status := "%d" % item.cost if problem != "item slots full" else "full"
		if owned:
			status = "Sell +%d?" % int(Economy.sell_value(sim, item, me)) if _sell_armed == i else ("OWNED+" if me.is_masterwork(item) else "OWNED")
		elif not in_shop:
			status = "%d · at tower" % item.cost
		c.text = "%s\n%s" % [item.display_name, status]
		var color := Color("8fe388") if owned else (Color("f5d76e") if problem == "" else Color(1, 1, 1, 0.45))
		if owned and _sell_armed == i:
			color = Color("ff9f6e")
		c.add_theme_color_override("font_color", color)
		c.add_theme_color_override("font_disabled_color", color)
		c.add_theme_color_override("font_hover_color", color)
		c.self_modulate = [Color(0.85, 0.95, 1.0), Color(1.0, 0.92, 0.8), Color(1.0, 0.8, 1.0)][item.tier]


## Push, then shop: pulse the gold readout while a card is affordable but you are away
## from the shop (time to push your wave in and head back). Enemy spikes: pulse their
## name and items for a few seconds after a mid or late item.
func _refresh_spikes(sim: MatchSim, me: HeroState) -> void:
	var now := Time.get_ticks_msec()
	var pulse := 0.5 + 0.5 * sin(now / 140.0)
	var next := _affordable_card(sim, me)
	var away := next >= 0 and not Economy.in_shop_range(sim, me)
	_gold.text = "Gold\n%d%s" % [int(me.gold), "\nShop!" if away else ""]
	_gold.modulate = Color(1, 1, 1).lerp(Color(1.6, 1.4, 0.6), pulse) if away else Color.WHITE
	if next >= 0 and not _afford_called.has(me.deck[next].id) and me.alive:
		_afford_called[me.deck[next].id] = true
		if away:
			_show_flash("You can afford %s: push your wave in, then shop" % me.deck[next].display_name)
	var spiking := now < _them_spike_until
	var glow := Color(1, 1, 1).lerp(Color(1.8, 1.5, 0.5), pulse) if spiking else Color.WHITE
	_them_name.modulate = glow
	_them_items.modulate = glow


## The first card you don't own that you could buy now or at the shop, or -1.
func _affordable_card(sim: MatchSim, me: HeroState) -> int:
	for i in me.deck.size():
		var item := me.deck[i]
		if not me.owns(item) and me.items.size() < sim.config.max_items and me.gold + 0.0001 >= item.cost:
			return i
	return -1


func _refresh_masterwork(sim: MatchSim, me: HeroState) -> void:
	_master_slots.clear()
	if me.level >= sim.config.masterwork_level and me.alive and Economy.in_shop_range(sim, me) and not sim.over:
		for item in me.items:
			if not me.is_masterwork(item):
				_master_slots.append(me.deck.find(item))
	var shop_open := me.level >= sim.config.masterwork_level and me.alive and Economy.in_shop_range(sim, me) and not sim.over
	_master_box.visible = shop_open and me.pending_perk_tier() < 0
	if not _master_box.visible:
		return
	var scroll_problem := Economy.siege_scroll_problem(sim, me)
	_scroll_button.text = "N  Siege scroll\n%d gold%s" % [int(Economy.siege_scroll_cost(sim, me)), "  (queued)" if scroll_problem == "siege troopers already waiting" else ""]
	_scroll_button.disabled = scroll_problem != ""
	for k in _master_buttons.size():
		var b := _master_buttons[k]
		b.visible = k < _master_slots.size()
		if not b.visible:
			continue
		var slot := _master_slots[k]
		var item := me.deck[slot]
		b.text = "%s  %s\n%d gold" % [["C", "V", "B"][k], item.display_name, int(Economy.masterwork_cost(sim, item))]
		b.disabled = Economy.masterwork_problem(sim, me, slot) != ""


## C / V / B: Masterwork the first, second or third item on offer.
func masterwork_key(k: int) -> void:
	if _master_box.visible and k < _master_slots.size():
		masterwork_pressed.emit(_master_slots[k])


func _show_flash(text: String) -> void:
	_flash.text = text
	_flash_until = Time.get_ticks_msec() + 2600


## A card tap or number key: buys, or for an owned card, asks once and then sells.
func card_pressed(i: int) -> void:
	if _me == null or i >= _me.deck.size():
		return
	if not _me.owns(_me.deck[i]):
		buy_pressed.emit(i)
		return
	if _sell_armed == i and Time.get_ticks_msec() <= _sell_armed_until:
		_sell_armed = -1
		sell_pressed.emit(i)
	else:
		_sell_armed = i
		_sell_armed_until = Time.get_ticks_msec() + 2500


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
			elif _item_tier(data.item) >= ItemData.Tier.MID:
				text = "Enemy spike: they finished %s!" % _item_name(data.item)
				_enemy_spike(data.item)
		&"masterwork":
			if data.team == seat:
				text = "Masterwork %s: +%d%% stats" % [_item_name(data.item), roundi(100.0 * MatchController.CONFIG.masterwork_bonus)]
			else:
				text = "Enemy spike: Masterwork %s!" % _item_name(data.item)
				_enemy_spike(data.item)
		&"special_spawned":
			if data.team != seat:
				text = "Enemy Sapper incoming: kill it before it reaches your tower" if data.kind == &"sapper" \
						else "Enemy Shieldbearer: its shield stops your first skillshot"
		&"banner_dropped":
			text = "A banner dropped: walk over it to buff your next wave"
		&"banner_taken":
			text = "Banner taken: your next wave is stronger" if data.team == seat else "The enemy took the banner: their next wave is stronger"
		&"ult_race_won":
			if data.team == seat:
				text = "You reached Lv5 first! Ultimate ready (R): go fight"
			else:
				text = "Enemy hit Lv5 first: their ultimate is up, play safe"
				_enemy_spike(&"")
		&"overtime_started":
			text = "Overtime! Structures are weakened, waves are tankier"
		&"core_immune":
			text = "Your Core is immune for %d s: regroup!" % roundi(data.seconds) if data.team == seat \
					else "Their Core is shielded for %d s" % roundi(data.seconds)
		&"siege_scroll":
			text = "Siege scroll: a siege trooper joins your next wave" if data.team == seat else "Enemy read a siege scroll: a siege trooper is coming"
		&"guardian_fallen":
			text = "Your Guardian fell!" if data.team == seat else "Enemy Guardian down! Your minions are powered up"
		&"guardian_slam_windup":
			if data.team != seat and _sim_for_text != null and _sim_for_text.heroes[seat].pos.distance_to(_sim_for_text.get_entity(data.id).pos) < data.radius + 1.5:
				text = "Guardian slam! Get out!"
		&"item_sold":
			if data.team == seat:
				text = "Sold %s for %d" % [_item_name(data.item), int(data.refund)]
		&"level_up":
			if data.team == seat:
				text = _level_text(data.level, seat)
	if text != "":
		_flash.text = text
		_flash_until = Time.get_ticks_msec() + 2600


var _sim_for_text: MatchSim


func _level_text(lv: int, seat: int) -> String:
	if _sim_for_text == null:
		return "Level %d" % lv
	var h := _sim_for_text.heroes[seat]
	if lv % 2 == 1:
		var a := h.data.abilities[(lv - 1) / 2]
		return "Level %d: %s unlocked (%s)" % [lv, a.display_name, ["Q", "E", "R"][(lv - 1) / 2]]
	return "Level %d: pick a perk (Z / X)" % lv


func _enemy_spike(item_id: StringName) -> void:
	_them_spike_until = Time.get_ticks_msec() + 8000
	_them_spike_item = item_id


func _item_tier(id: StringName) -> int:
	for item in MatchController.ITEMS:
		if item.id == id:
			return item.tier
	return -1


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
			return "Enemy has the Relay! One hit knocks it loose"
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
		if s.alive and sim.time < s.immune_until:
			w.label.text = "%s · immune %d" % [s.data.display_name, ceili(s.immune_until - sim.time)]
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
	_them_name.custom_minimum_size = Vector2(270, 0)
	_them_hp = UiKit.bar(Palette.ENEMY, 20)
	_them_hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_them_name)
	var them_bars := VBoxContainer.new()
	them_bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	them_bars.add_theme_constant_override("separation", 3)
	them_bars.add_child(_them_hp)
	_them_xp = UiKit.bar(Color("f5d76e"), 5)
	them_bars.add_child(_them_xp)
	row.add_child(them_bars)
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
	_you_name.custom_minimum_size = Vector2(270, 0)
	_you_hp = UiKit.bar(Palette.ALLY, 20)
	_you_hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_you_name)
	var you_bars := VBoxContainer.new()
	you_bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	you_bars.add_theme_constant_override("separation", 3)
	you_bars.add_child(_you_hp)
	_you_xp = UiKit.bar(Color("f5d76e"), 5)
	you_bars.add_child(_you_xp)
	row.add_child(you_bars)
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
	var cards := GridContainer.new()
	cards.columns = 4
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("h_separation", 5)
	cards.add_theme_constant_override("v_separation", 5)
	tray.add_child(cards)
	_cards_row = cards
	for i in MatchController.CONFIG.deck_size:
		# One tap buys: no shop screen (GDD 8). Keys 1-8 do the same.
		var card := UiKit.button("", Vector2(0, 58))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.x = 50
		card.add_theme_font_size_override("font_size", 14)
		card.autowrap_mode = TextServer.AUTOWRAP_OFF
		card.clip_text = true
		card.pressed.connect(func() -> void: card_pressed(i))
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
	# No basic-attack button by design: stopping is the attack. Q is the big thumb button,
	# E sits to its left, R (the ultimate) above it. Keyboard: Q / E / R.
	_ability_buttons.append(_corner_button(136, 28, 28, 0))
	_ability_buttons.append(_corner_button(108, 28 + 136 + 18, 28, 1))
	_ability_buttons.append(_corner_button(108, 28 + 14, 28 + 136 + 18, 2))
	# Shown only while you carry the Relay (keyboard: F).
	_drop = UiKit.button("F\nDrop", Vector2(96, 96))
	_drop.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_drop.offset_right = -(28 + 136 + 18)
	_drop.offset_left = _drop.offset_right - 96
	_drop.offset_bottom = -BOTTOM_H - (28 + 108 + 18)
	_drop.offset_top = _drop.offset_bottom - 96
	_drop.add_theme_color_override("font_color", Palette.RELAY)
	_drop.tooltip_text = "F: drop the Relay"
	_drop.pressed.connect(func() -> void: drop_pressed.emit())
	_drop.visible = false
	_root.add_child(_drop)


func _build_perk_picker() -> void:
	_perk_box = VBoxContainer.new()
	_perk_box.anchor_left = 0.04
	_perk_box.anchor_right = 0.96
	_perk_box.anchor_top = 1.0
	_perk_box.anchor_bottom = 1.0
	_perk_box.offset_bottom = -BOTTOM_H - 330
	_perk_box.offset_top = _perk_box.offset_bottom - 150
	_perk_box.add_theme_constant_override("separation", 6)
	_perk_box.visible = false
	_root.add_child(_perk_box)
	_perk_title = UiKit.label("", 24, Palette.RELAY)
	_perk_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_perk_title.add_theme_constant_override("outline_size", 8)
	_perk_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_perk_box.add_child(_perk_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_perk_box.add_child(row)
	for k in 2:
		var b := UiKit.button("", Vector2(0, 104))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(func() -> void: perk_pressed.emit(k))
		row.add_child(b)
		_perk_buttons.append(b)


## Masterwork offers sit where the perk cards do, on the left, at the shop from level 6.
func _build_masterwork() -> void:
	_master_box = VBoxContainer.new()
	_master_box.anchor_left = 0.0
	_master_box.anchor_right = 1.0
	_master_box.offset_left = MARGIN + 16
	# Clear of the E button (its left edge sits 28 + 136 + 18 + 108 px from the right).
	_master_box.offset_right = -(28 + 136 + 18 + 108 + 14)
	_master_box.anchor_top = 1.0
	_master_box.anchor_bottom = 1.0
	_master_box.offset_bottom = -BOTTOM_H - 12
	_master_box.offset_top = _master_box.offset_bottom - 330
	_master_box.alignment = BoxContainer.ALIGNMENT_END
	_master_box.add_theme_constant_override("separation", 6)
	_master_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_master_box.visible = false
	_root.add_child(_master_box)
	var title := UiKit.label("Lv6 shop: Masterwork (+%d%%) or siege scroll" % roundi(100.0 * MatchController.CONFIG.masterwork_bonus), 20, Color("f5d76e"))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_master_box.add_child(title)
	for k in 3:
		var b := UiKit.button("", Vector2(0, 62))
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_color_override("font_color", Color("f5d76e"))
		b.pressed.connect(func() -> void: masterwork_key(k))
		_master_box.add_child(b)
		_master_buttons.append(b)
	_scroll_button = UiKit.button("", Vector2(0, 62))
	_scroll_button.add_theme_font_size_override("font_size", 17)
	_scroll_button.add_theme_color_override("font_color", Palette.RELAY)
	_scroll_button.tooltip_text = "N: a single-use scroll that adds a siege trooper to your next wave"
	_scroll_button.pressed.connect(func() -> void: scroll_pressed.emit())
	_master_box.add_child(_scroll_button)


## A square button anchored to the bottom right, `right`/`bottom` px in from the corner
## (above the bottom band).
func _corner_button(size: float, right: float, bottom: float, slot: int) -> Button:
	var b := UiKit.button("", Vector2(size, size))
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.offset_right = -right
	b.offset_left = -right - size
	b.offset_bottom = -BOTTOM_H - bottom
	b.offset_top = -BOTTOM_H - bottom - size
	b.add_theme_font_size_override("font_size", 14 if slot > 0 else 17)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = true
	b.pressed.connect(func() -> void: cast_pressed.emit(slot))
	_root.add_child(b)
	return b


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
