class_name Hud
extends CanvasLayer
## Portrait HUD, kept light so the lane stays readable:
## - a slim top band for the opponent (health, level, three structure pips),
## - the match clock under it, with the next timer (the Relay, overtime),
## - a slim bottom band for you (health, XP, gold),
## - ability buttons you can drag to aim, joystick on touch,
## - item cards only while you stand in shop range (they can't be bought elsewhere),
## - a details panel (Tab or the i button) with items and structure health for both sides.
## On wide screens (desktop, fullscreen) everything sits in a centred column.
## Reads the sim, never writes to it: buttons raise signals the match controller handles.

signal seat_toggle_pressed
signal touch_toggle_pressed
signal debug_toggle_pressed
signal fullscreen_pressed
signal menu_pressed
signal restart_pressed
signal drop_pressed
signal trick_aimed(screen_dir: Vector2)
signal buy_pressed(slot: int)
signal sell_pressed(slot: int)
## A cast from an ability button: screen_dir is the drag-to-aim direction (y up), or zero
## for a tap.
signal cast_aimed(slot: int, screen_dir: Vector2)
signal perk_pressed(choice: int)
signal masterwork_pressed(slot: int)
signal scroll_pressed

## Heights (design px) of the bands that cover the map. The camera keeps the ground
## between them inside the map.
const TOP_BAND := 92.0
const BOTTOM_BAND := 104.0
const MARGIN := 12.0
## Height of one row of shop buttons in the tray.
const TRAY_ROW := 58.0
## Wide screens: the HUD column is at most this wide, or 0.8 of the screen height.
const COLUMN_MAX := 1000.0

var joystick: ThumbStick
var debug_visible := false
## True while the victory animation plays: the result panel waits for it.
var hold_result := false

var _root: Control
var _top: PanelContainer
var _bottom: PanelContainer
var _them_name: Label
var _them_level: Label
var _them_portrait: HeroPortrait
var _them_mood := PortraitMood.new()
var _them_hp: ProgressBar
var _them_xp: ProgressBar
var _them_pips: StructPips
var _you_name: Label
var _you_level: Label
var _you_portrait: HeroPortrait
var _you_mood := PortraitMood.new()
var _you_hp: ProgressBar
var _you_xp: ProgressBar
var _you_pips: StructPips
var _gold: Label
var _clock: Label
var _clock_box: NoirBox
## Last look per tray card, so styleboxes are only rebuilt when a card changes.
var _card_looks: Array[String] = []
var _clock_sub: Label
var _flash: Label
var _flash_until := 0
var _drop: Button
var _trick: AimButton
var _tray: PanelContainer
var _cards: Array[Button] = []
var _master_row: HBoxContainer
var _master_buttons: Array[Button] = []
var _master_slots: Array[int] = []
var _scroll_button: Button
var _ability_buttons: Array[AimButton] = []
var _ability_offsets: Array = []
var _perk_box: Control
var _perk_title: Label
var _perk_buttons: Array[Button] = []
var _minimap: Minimap
var _minimap_inset := 0.0
var _details: PanelContainer
var _details_text: RichTextLabel
var _menu_box: VBoxContainer
var _touch_button: Button
var _seat_button: Button
var _sound_button: Button
var _fullscreen_button: Button
var _debug: Label
var _respawn: Label
var _result: PanelContainer
var _result_title: Label
## Cards announced as affordable once (so the callout fires once per item).
var _afford_called := {}
var _them_spike_until := 0
var _them_spike_item := &""
var _deck_seen: Array[ItemData] = []
## Owned card tapped once: a second tap within the window sells it.
var _sell_armed := -1
var _sell_armed_until := 0
var _me: HeroState
var _sim_for_text: MatchSim
var _thumb_base := -1.0


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiKit.make_theme()
	add_child(_root)
	var inset := _top_safe_inset()
	_build_top(inset)
	_build_clock(inset)
	_build_menu(inset)
	_build_bottom()
	_build_tray()
	_build_thumbs()
	_build_perk_picker()
	_build_details(inset)
	_build_status()
	_minimap = Minimap.new()
	_minimap.anchor_left = 1.0
	_minimap.anchor_right = 1.0
	_minimap_inset = inset
	_root.add_child(_minimap)
	_place_thumbs(BOTTOM_BAND)
	set_debug_visible(false)


func set_touch_mode(on: bool, mouse_emulation: bool) -> void:
	joystick.visible = on
	joystick.use_mouse = mouse_emulation
	joystick.release()
	for b in _ability_buttons:
		b.use_mouse = mouse_emulation or not on
		b.cancel()
	_trick.use_mouse = mouse_emulation or not on
	_trick.cancel()
	_touch_button.text = "Touch controls: on" if on else "Touch controls: off"


func set_debug_visible(on: bool) -> void:
	debug_visible = on
	_debug.visible = on


func set_fullscreen_label(on: bool) -> void:
	_fullscreen_button.text = "Exit fullscreen" if on else "Fullscreen (F11)"


## Dev screenshots: show a drag-to-aim in progress on an ability button.
func demo_aim(slot: int, screen_dir: Vector2) -> void:
	var b := _ability_buttons[slot]
	b.aiming = true
	b.aim_dir = screen_dir
	b.set("_start", b.custom_minimum_size / 2.0)
	b.queue_redraw()


## The ability button being dragged to aim, and its aim (screen space, y up), or [-1, 0].
func aim_drag() -> Array:
	for i in _ability_buttons.size():
		if _ability_buttons[i].aiming:
			return [i, _ability_buttons[i].aim_dir]
	return [-1, Vector2.ZERO]


func refresh(sim: MatchSim, seat: int, fps: float) -> void:
	_sim_for_text = sim
	_fit_column()
	if _minimap.sim != sim or _minimap.seat != seat:
		_minimap.setup(sim, seat)
		_minimap.offset_right = -MARGIN
		_minimap.offset_left = -MARGIN - _minimap.size.x
		_minimap.offset_top = TOP_BAND + _minimap_inset + 60.0
		_minimap.offset_bottom = _minimap.offset_top + _minimap.size.y
	var me := sim.heroes[seat]
	var them := sim.heroes[1 - seat]
	_me = me
	_name_plate(sim, _you_name, _you_level, _you_portrait, me)
	_name_plate(sim, _them_name, _them_level, _them_portrait, them)
	_you_portrait.set_mood(_you_mood.update(me, them, sim.time))
	_them_portrait.set_mood(_them_mood.update(them, me, sim.time))
	_you_xp.value = Leveling.progress(sim, me)
	_them_xp.value = Leveling.progress(sim, them)
	_you_hp.value = me.hp / me.max_hp
	_them_hp.value = them.hp / them.max_hp
	_you_pips.refresh(sim, seat)
	_them_pips.refresh(sim, 1 - seat)
	_refresh_clock(sim, seat)
	_refresh_abilities(sim, me)
	_refresh_trick(sim, me)
	_refresh_perks(sim, me)
	_refresh_tray(sim, me)
	_refresh_spikes(sim, me)
	if _details.visible:
		_refresh_details(sim, seat)
	_respawn.visible = not me.alive and not sim.over
	if _respawn.visible:
		_respawn.text = "Respawning in %d" % ceili(me.respawn_at - sim.time)
	if sim.over and not _result.visible and not hold_result:
		_result_title.text = "VICTORY!" if sim.winner == seat else "DEFEAT"
		_result_title.add_theme_color_override("font_color", Noir.YELLOW if sim.winner == seat else Noir.WHITE)
		_result.visible = true
	_seat_button.text = "Seat: %s (F2)" % ("blue" if seat == MatchSim.BLUE else "red")
	_sound_button.text = "Sound: %s (M)" % ("off" if Sfx.muted else "on")
	_flash.visible = Time.get_ticks_msec() < _flash_until
	_drop.visible = me.carrying_relay
	if debug_visible:
		_debug.text = "FPS %d   tick %d   t %.1fs\nyou (%.1f, %.1f) %s" % [
			fps, sim.tick, sim.time, me.pos.x, me.pos.y, "moving" if me.moving else "stopped"]


## Name in the hero's own lettering, level under it in the HUD type. Fonts are only
## swapped when the hero changes (seat swap).
func _name_plate(sim: MatchSim, name: Label, level: Label, portrait: HeroPortrait, h: HeroState) -> void:
	if portrait.hero_id != h.data.id:
		name.text = h.data.display_name
		HeroLettering.apply(name, h.data.id, 26 if h.data.display_name.length() <= 7 else 20)
		portrait.setup(h.data.id, portrait.team_color)
	var bounty := Economy.shutdown_bounty(sim, h)
	level.text = "Lv %d" % h.level if bounty <= 0.0 else "Lv %d · Bounty %dg" % [h.level, roundi(bounty)]


## Wide screens: keep the HUD in a centred column so the thumbs and the lane stay close.
func _fit_column() -> void:
	var vp := _root.get_viewport_rect().size
	var col := minf(vp.x, maxf(720.0, minf(COLUMN_MAX, vp.y * 0.8)))
	var side := maxf(0.0, (vp.x - col) / 2.0)
	_root.offset_left = side
	_root.offset_right = -side


# ------------------------------------------------------------------ clock

func _refresh_clock(sim: MatchSim, seat: int) -> void:
	var t := int(sim.time)
	_clock.text = "%d:%02d" % [t / 60, t % 60]
	# Overtime flips the clock tag to black with yellow numbers.
	_clock_box.fill = Noir.INK if sim.overtime else Noir.YELLOW
	_clock_box.border_color = Noir.YELLOW if sim.overtime else Noir.INK
	_clock.add_theme_color_override("font_color", Noir.YELLOW if sim.overtime else Noir.INK)
	var lines: Array[String] = []
	if sim.overtime:
		lines.append("OVERTIME")
	else:
		var until := Pacing.overtime_at(sim) - sim.time
		if until <= 60.0:
			lines.append("Overtime in %d" % ceili(until))
	var relay := _relay_text(sim, seat)
	if relay != "":
		lines.append(relay)
	_clock_sub.text = "\n".join(lines)


# ------------------------------------------------------------------ abilities

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
			status = "Lv %d" % Leveling.ABILITY_LEVELS[mini(i, 2)]
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
		b.tooltip_text = "%s (%s)\n%s\nCooldown %.0f s\nAims at the mouse; on touch, drag the button to aim." % [title, KEYS[i], a.summary, me.ability_cooldown(i)]


## The Trick button: key, name, cooldown.
func _refresh_trick(sim: MatchSim, me: HeroState) -> void:
	var problem := Tricks.problem(sim, me)
	var status := ""
	if me.trick_cd > 0.0:
		status = "%.0f" % ceilf(me.trick_cd)
	elif me.trick == &"brand" and sim.time < me.brand_armed_until:
		status = "Armed!"
	_trick.text = "T\n%s\n%s" % [Tricks.display_name(me.trick), status]
	_trick.disabled = problem != ""
	_trick.add_theme_color_override("font_color", Noir.YELLOW)
	_trick.tooltip_text = "%s (T)\n%s\nCooldown %.0f s" % [Tricks.display_name(me.trick), Tricks.summary(sim.config, me.trick), Tricks.cooldown(sim.config, me.trick)]


## The level-up perk choice: two cards while a pick is waiting (Z / X on a keyboard).
func _refresh_perks(sim: MatchSim, me: HeroState) -> void:
	var tier := me.pending_perk_tier()
	_perk_box.visible = tier >= 0 and not sim.over
	if not _perk_box.visible:
		return
	var left := maxf(0.0, sim.config.perk_auto_pick_time - (sim.time - me.perk_offered_at[tier]))
	_perk_title.text = "Level %d perk: pick one (%ds)" % [Leveling.PERK_LEVELS[tier], ceili(left)]
	var options := me.perk_options(tier)
	for k in _perk_buttons.size():
		var b := _perk_buttons[k]
		b.visible = k < options.size()
		if b.visible:
			b.text = "%s  %s\n%s" % [["Z", "X"][k], options[k].display_name, options[k].summary]


# ------------------------------------------------------------------ shop tray

## Tab (or the i button): open or close the details panel.
func toggle_details() -> void:
	_details.visible = not _details.visible
	if _details.visible and _sim_for_text != null:
		_refresh_details(_sim_for_text, _me.team if _me != null else MatchSim.BLUE)


## The tray of item cards shows only in shop range (at your tower or base), with a
## siege scroll row from level 7 (Masterworks join it at level 8). The thumbs move up
## to make room.
func _refresh_tray(sim: MatchSim, me: HeroState) -> void:
	var open := me.alive and Economy.in_shop_range(sim, me) and not sim.over
	_tray.visible = open
	var lv6 := open and me.level >= mini(sim.config.siege_scroll_level, sim.config.masterwork_level)
	_master_row.visible = lv6
	if open:
		_refresh_cards(sim, me)
		if lv6:
			_refresh_masterwork(sim, me)
	var rows := (2 if open else 0) + (1 if lv6 else 0)
	var tray_h := 0.0 if rows == 0 else rows * TRAY_ROW + (rows - 1) * 5.0 + 24.0 + 8.0
	_place_thumbs(BOTTOM_BAND + tray_h)


## Card text and state: owned (tap twice to sell), affordable, saving up, or locked out
## by full slots. Card colors hint the tier: early, mid, late.
func _refresh_cards(sim: MatchSim, me: HeroState) -> void:
	if _deck_seen != me.deck:
		_deck_seen = me.deck.duplicate()
		_card_looks.clear()
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
		c.disabled = problem != "" and not owned
		var status := "%d" % item.cost if problem != "item slots full" else "full"
		if owned:
			status = "Sell +%d?" % int(Economy.sell_value(sim, item, me)) if _sell_armed == i else ("OWNED+" if me.is_masterwork(item) else "OWNED")
		c.text = "%s\n%s" % [item.display_name, status]
		var look := "sell" if owned and _sell_armed == i else ("owned" if owned else ("buy%d" % item.tier if problem == "" else "off%d" % item.tier))
		if _card_looks.size() != _cards.size():
			_card_looks.resize(_cards.size())
		if _card_looks[i] != look:
			_card_looks[i] = look
			_style_card(c, look, item.tier)


## Tray card looks, noir style: the tier's fill (white, yellow, black) when you can
## buy it, a faded fill when you can't, black with a yellow edge when owned, and white
## with a yellow shadow while a sell is waiting for its second tap.
func _style_card(c: Button, look: String, tier: int) -> void:
	var fill: Color = Noir.TIER_COLORS[tier]
	var ink := Noir.WHITE if fill.get_luminance() < 0.2 else Noir.INK
	var edge := Noir.WHITE if fill.get_luminance() < 0.2 else Noir.INK
	var shadow := Noir.YELLOW if fill.get_luminance() < 0.2 else Noir.INK
	match look:
		"owned":
			fill = Noir.INK
			ink = Noir.YELLOW
			edge = Noir.YELLOW
			shadow = Noir.YELLOW
		"sell":
			fill = Noir.WHITE
			ink = Noir.INK
			edge = Noir.INK
			shadow = Noir.YELLOW
		_:
			if look.begins_with("off"):
				# Can't buy yet: a see-through black card, edged in its tier's colour.
				edge = [Color(Noir.WHITE, 0.55), Color(Noir.YELLOW, 0.7), Color(Noir.ASH, 0.35)][tier]
				fill = Color(Noir.INK, 0.62)
				ink = Color(1, 1, 1, 0.62)
				shadow = Color(0, 0, 0, 0)
	var box := NoirBox.make(fill, 6, 8)
	box.border_color = edge
	box.shadow = Vector2(4, 4)
	box.shadow_color = shadow
	box.set_margins(6)
	var down := box.copy()
	down.pressed = true
	for st in ["normal", "hover", "disabled"]:
		c.add_theme_stylebox_override(st, box)
	c.add_theme_stylebox_override("pressed", down)
	c.add_theme_stylebox_override("hover_pressed", down)
	for k in ["font_color", "font_hover_color", "font_disabled_color", "font_pressed_color", "font_hover_pressed_color"]:
		c.add_theme_color_override(k, ink)


func _refresh_masterwork(sim: MatchSim, me: HeroState) -> void:
	_master_slots.clear()
	for item in me.items:
		if not me.is_masterwork(item):
			_master_slots.append(me.deck.find(item))
	var masterworks_open := me.level >= sim.config.masterwork_level
	for k in _master_buttons.size():
		var b := _master_buttons[k]
		b.visible = masterworks_open and k < _master_slots.size()
		if not b.visible:
			continue
		var slot := _master_slots[k]
		var item := me.deck[slot]
		b.text = "%s Masterwork\n%s %d" % [["C", "V", "B"][k], item.display_name, int(Economy.masterwork_cost(sim, item))]
		b.disabled = Economy.masterwork_problem(sim, me, slot) != ""
	var scroll_problem := Economy.siege_scroll_problem(sim, me)
	_scroll_button.text = "N Siege scroll\n%s" % ("queued" if scroll_problem == "siege troopers already waiting" else "%d gold" % int(Economy.siege_scroll_cost(sim, me)))
	_scroll_button.disabled = scroll_problem != ""


## C / V / B: Masterwork the first, second or third item on offer.
func masterwork_key(k: int) -> void:
	if _master_row.visible and k < _master_slots.size():
		masterwork_pressed.emit(_master_slots[k])


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


## Push, then shop: pulse the gold readout while a card is affordable but you are away
## from the shop (time to push your wave in and head back). Enemy spikes: pulse their
## name for a few seconds after a mid or late item.
func _refresh_spikes(sim: MatchSim, me: HeroState) -> void:
	var now := Time.get_ticks_msec()
	var pulse := 0.5 + 0.5 * sin(now / 140.0)
	var next := _affordable_card(sim, me)
	var away := next >= 0 and not Economy.in_shop_range(sim, me)
	_gold.text = "%d%s" % [int(me.gold), "\nShop!" if away else " gold"]
	_gold.modulate = Color(1, 1, 1).lerp(Color(1.5, 1.5, 1.5), pulse) if away else Color.WHITE
	if next >= 0 and not _afford_called.has(me.deck[next].id) and me.alive:
		_afford_called[me.deck[next].id] = true
		if away:
			_show_flash("You can afford %s: push your wave in, then shop" % me.deck[next].display_name)
	var spiking := now < _them_spike_until
	_them_name.modulate = Color(1, 1, 1).lerp(Color(1.8, 1.5, 0.5), pulse) if spiking else Color.WHITE


## The first card you don't own that you could buy now or at the shop, or -1.
func _affordable_card(sim: MatchSim, me: HeroState) -> int:
	for i in me.deck.size():
		var item := me.deck[i]
		if not me.owns(item) and me.items.size() < sim.config.max_items and me.gold + 0.0001 >= item.cost:
			return i
	return -1


# ------------------------------------------------------------------ details panel

func _refresh_details(sim: MatchSim, seat: int) -> void:
	var t := ""
	for side in [1 - seat, seat]:
		var h := sim.heroes[side]
		var color := Palette.ALLY.lightened(0.3) if side == seat else Palette.ENEMY.lightened(0.25)
		t += "[color=#%s][b]%s %s · Lv %d[/b][/color]\n" % [color.to_html(false), "You:" if side == seat else "Them:", h.data.display_name, h.level]
		t += "Items: %s\n" % _items_text(h, sim.config.max_items)
		var growth: Array[String] = []
		for p in h.owned_perks():
			growth.append(p.display_name)
		for p in h.owned_passives():
			growth.append("%s (%s)" % [p.display_name, p.summary])
		if not growth.is_empty():
			t += "Perks & passives: %s\n" % "  ·  ".join(growth)
		t += StatCard.live(h) + "\n"
		var parts: Array[String] = []
		for s in sim.structures_of(side):
			var state := "%d%%" % ceili(100.0 * s.hp / s.max_hp) if s.alive else "down"
			if s.alive and not sim.is_exposed(s):
				state += " (locked)"
			if s.alive and sim.time < s.immune_until:
				state += " (immune %d)" % ceili(s.immune_until - sim.time)
			elif s.alive and s.guarded:
				state += " (guarded)"
			parts.append("%s %s" % [s.data.display_name, state])
		t += "  ·  ".join(parts) + "\n\n"
	_details_text.text = t.strip_edges()


func _items_text(h: HeroState, cap: int) -> String:
	var names: Array[String] = []
	for item in h.items:
		var name := item.display_name + ("+" if h.is_masterwork(item) else "")
		if h != _me and item.id == _them_spike_item and Time.get_ticks_msec() < _them_spike_until:
			name = "NEW " + name
		names.append(name)
	for i in cap - h.items.size():
		names.append("—")
	return "  ·  ".join(names)


# ------------------------------------------------------------------ callouts

func _show_flash(text: String) -> void:
	_flash.text = text
	_flash_until = Time.get_ticks_msec() + 2600


## Short event callouts under the clock ("Relay knocked loose!").
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
			if data.get("long", false):
				text = "Long delivery! Big gold and an extra siege minion" if data.team == seat else "Enemy made the long delivery: extra siege minions coming"
			else:
				text = "Delivered! A siege minion joins your next wave" if data.team == seat else "Enemy delivered: their siege minion is coming"
		&"phase_two":
			text = "Phase 2! The long Relay drop is open"
		&"shutdown":
			text = ("Shutdown! +%d gold" % roundi(data.amount)) if data.team == seat else "Shut down! They took your %d gold bounty" % roundi(data.amount)
		&"bounty_up":
			text = ("You're on a streak: your head is worth %d gold" % roundi(data.amount)) if data.team == seat else "Enemy on a streak: knock them out for %d gold" % roundi(data.amount)
		&"relay_expired":
			text = "The Relay faded"
		&"relay_fizzling":
			text = "Fought over too long: the Relay is fizzling!"
		&"relay_fizzled":
			text = "The Relay fizzled out"
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
		&"ult_race_won":
			if data.team == seat:
				text = "You reached Lv%d first! Ultimate ready (R): go fight" % Leveling.ULT_LEVEL
			else:
				text = "Enemy hit Lv%d first: their ultimate is up, play safe" % Leveling.ULT_LEVEL
				_enemy_spike(&"")
		&"overtime_started":
			text = "Overtime! Structures are weakened, waves are tankier"
		&"core_immune":
			text = "Your Core is immune for %d s: regroup!" % roundi(data.seconds) if data.team == seat \
					else "Their Core is shielded for %d s" % roundi(data.seconds)
		&"siege_scroll":
			text = "Siege scroll: a siege trooper joins your next wave" if data.team == seat else "Enemy read a siege scroll: a siege trooper is coming"
		&"guardian_fallen":
			text = "Your Guardian fell! Stand in front of your Core to guard it" if data.team == seat else "Enemy Guardian down! Kill their hero or drive them off their Core"
		&"core_stun_windup":
			if data.team != seat and _sim_for_text != null and _sim_for_text.heroes[seat].pos.distance_to(_sim_for_text.get_entity(data.id).pos) < data.radius + 1.5:
				text = "Core stun! Get out!"
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
		_show_flash(text)


func _level_text(lv: int, seat: int) -> String:
	if _sim_for_text == null:
		return "Level %d" % lv
	var h := _sim_for_text.heroes[seat]
	var parts: Array[String] = []
	var ability := Leveling.ABILITY_LEVELS.find(lv)
	if ability >= 0 and ability < h.data.abilities.size():
		parts.append("%s unlocked (%s)" % [h.data.abilities[ability].display_name, ["Q", "E", "R"][ability]])
	var passive := Leveling.PASSIVE_LEVELS.find(lv)
	if passive >= 0 and passive < h.data.passives.size():
		parts.append("%s: %s" % [h.data.passives[passive].display_name, h.data.passives[passive].summary])
	if Leveling.PERK_LEVELS.has(lv):
		parts.append("pick a perk (Z / X)")
	if lv == _sim_for_text.config.siege_scroll_level:
		parts.append("siege scrolls at the shop (N)")
	if lv == _sim_for_text.config.masterwork_level:
		parts.append("Masterworks at the shop")
	if lv == Leveling.CROWN_LEVEL:
		parts.append("max level, crowned!")
	if parts.is_empty():
		return "Level %d: stronger" % lv
	return "Level %d: %s" % [lv, " · ".join(parts)]


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
				if relay.long_rect(sim, seat).has_area():
					where += " or the long drop"
				return where + (" · blocked!" if relay.contested else "")
			return "Enemy has the Relay! One hit knocks it loose"
	return ""


## Which side of *your* screen a pocket is on (the red seat sees the map turned 180°).
func _side(sim: MatchSim, pocket: int, seat: int) -> String:
	var x := sim.arena.pockets[pocket].get_center().x
	if seat != MatchSim.BLUE:
		x = -x
	return "left" if x < 0.0 else "right"


# ------------------------------------------------------------------ building

## One band row: name, health and XP bars, structure pips, and optional extra buttons.
func _band_row(color: Color, name_color: Color) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var portrait := HeroPortrait.new()
	portrait.team_color = color
	portrait.custom_minimum_size = Vector2(60, 60)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	var plate := VBoxContainer.new()
	plate.add_theme_constant_override("separation", -4)
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.custom_minimum_size = Vector2(132, 0)
	var name := UiKit.label("", 24, name_color)
	name.clip_text = true
	_outlined(name)
	plate.add_child(name)
	var level := UiKit.label("", 17, Noir.YELLOW)
	level.add_theme_font_override("font", HeroLettering.hud_bold())
	plate.add_child(level)
	row.add_child(plate)
	var bars := VBoxContainer.new()
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bars.add_theme_constant_override("separation", 3)
	var hp := UiKit.bar(color, 20)
	bars.add_child(hp)
	var xp := UiKit.bar(Noir.YELLOW, 5)
	bars.add_child(xp)
	row.add_child(bars)
	var pips := StructPips.new()
	pips.color = color
	pips.custom_minimum_size = Vector2(84, 28)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pips)
	return {"row": row, "name": name, "level": level, "portrait": portrait, "hp": hp, "xp": xp, "pips": pips}


func _build_top(inset: float) -> void:
	_top = PanelContainer.new()
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.offset_left = MARGIN
	_top.offset_right = -MARGIN
	_top.offset_top = MARGIN + inset
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_top)
	var r := _band_row(Palette.ENEMY, Palette.ENEMY.lightened(0.2))
	_them_name = r.name
	_them_level = r.level
	_them_portrait = r.portrait
	_them_hp = r.hp
	_them_xp = r.xp
	_them_pips = r.pips
	var info := UiKit.button("i", Vector2(44, 44))
	info.add_theme_font_size_override("font_size", 22)
	info.tooltip_text = "Tab: items and structure health"
	info.pressed.connect(toggle_details)
	r.row.add_child(info)
	var menu := UiKit.button("☰", Vector2(44, 44))
	menu.add_theme_font_size_override("font_size", 22)
	menu.tooltip_text = "Settings: fullscreen, touch controls, menu"
	menu.pressed.connect(func() -> void: _menu_box.visible = not _menu_box.visible)
	r.row.add_child(menu)
	_top.add_child(r.row)


## The match clock, under the top band in the middle, with the next timer below it.
func _build_clock(inset: float) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.offset_top = TOP_BAND + 4 + inset
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The clock: a tilted yellow tag with slab numbers.
	_clock_box = NoirBox.make(Noir.YELLOW, 4, 10)
	_clock_box.shadow = Vector2(4, 4)
	_clock_box.shadow_color = Noir.INK
	_clock_box.set_margins(4)
	_clock_box.content_margin_left += 12
	_clock_box.content_margin_right += 12
	pill.add_theme_stylebox_override("panel", _clock_box)
	pill.rotation_degrees = -3.0
	pill.resized.connect(func() -> void: pill.pivot_offset = pill.size * 0.5)
	box.add_child(pill)
	_clock = UiKit.label("0:00", 32, Noir.INK)
	_clock.add_theme_font_override("font", Noir.SLAB)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(_clock)
	_clock_sub = _outlined(UiKit.label("", 19, Noir.YELLOW))
	_clock_sub.add_theme_font_override("font", HeroLettering.hud_bold())
	_clock_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_clock_sub)
	_flash = _outlined(UiKit.label("", 20, Color(1, 1, 1, 0.95)))
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flash.custom_minimum_size = Vector2(640, 0)
	_flash.visible = false
	box.add_child(_flash)
	_debug = UiKit.label("", 18, Color(1, 1, 1, 0.75))
	_debug.position = Vector2(MARGIN + 4, TOP_BAND + 8 + inset)
	_root.add_child(_debug)


func _build_menu(inset: float) -> void:
	_menu_box = VBoxContainer.new()
	_menu_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_menu_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_menu_box.offset_top = TOP_BAND + 8 + inset
	_menu_box.offset_right = -MARGIN
	_menu_box.add_theme_constant_override("separation", 6)
	_menu_box.visible = false
	_root.add_child(_menu_box)
	_fullscreen_button = _menu_button("Fullscreen (F11)", fullscreen_pressed)
	_touch_button = _menu_button("Touch controls: off", touch_toggle_pressed)
	_touch_button.tooltip_text = "F3: phone controls, driven by the mouse"
	_seat_button = _menu_button("Seat: blue (F2)", seat_toggle_pressed)
	_seat_button.tooltip_text = "Debug: swap seats (camera turns 180°)"
	_menu_button("Debug readout (F1)", debug_toggle_pressed)
	_sound_button = UiKit.button("", Vector2(260, 52))
	_sound_button.add_theme_font_size_override("font_size", 19)
	_sound_button.pressed.connect(func() -> void: Sfx.toggle_mute())
	_menu_box.add_child(_sound_button)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Sfx.volume
	vol.custom_minimum_size = Vector2(260, 36)
	vol.focus_mode = Control.FOCUS_NONE
	vol.tooltip_text = "Volume"
	vol.value_changed.connect(func(v: float) -> void:
		Sfx.set_volume(v)
		if Sfx.muted and v > 0.0:
			Sfx.set_muted(false))
	_menu_box.add_child(vol)
	_menu_button("Hero select (Esc)", menu_pressed)


func _menu_button(text: String, sig: Signal) -> Button:
	var b := UiKit.button(text, Vector2(260, 52))
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(func() -> void:
		_menu_box.visible = false
		sig.emit())
	_menu_box.add_child(b)
	return b


func _build_bottom() -> void:
	_bottom = PanelContainer.new()
	_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.offset_left = MARGIN
	_bottom.offset_right = -MARGIN
	_bottom.offset_top = -BOTTOM_BAND
	_bottom.offset_bottom = -MARGIN
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bottom)
	var r := _band_row(Palette.ALLY, Palette.ALLY.lightened(0.25))
	_you_name = r.name
	_you_level = r.level
	_you_portrait = r.portrait
	_you_hp = r.hp
	_you_xp = r.xp
	_you_pips = r.pips
	_gold = UiKit.label("0 gold", 22, Noir.YELLOW)
	_gold.add_theme_font_override("font", Noir.SLAB)
	_gold.custom_minimum_size = Vector2(92, 0)
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	r.row.add_child(_gold)
	_bottom.add_child(r.row)


## The shop tray just above the bottom band: eight cards, plus the siege scroll from
## level 7 and Masterworks from level 8. Visible only in shop range.
func _build_tray() -> void:
	_tray = PanelContainer.new()
	_tray.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_tray.offset_left = MARGIN
	_tray.offset_right = -MARGIN
	_tray.offset_bottom = -BOTTOM_BAND - 4
	_tray.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray.visible = false
	_root.add_child(_tray)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	_tray.add_child(v)
	var cards := GridContainer.new()
	cards.columns = 4
	cards.add_theme_constant_override("h_separation", 5)
	cards.add_theme_constant_override("v_separation", 5)
	v.add_child(cards)
	for i in MatchController.CONFIG.deck_size:
		# One tap buys: no shop screen (GDD 8). Keys 1-8 do the same.
		var card := UiKit.button("", Vector2(0, TRAY_ROW))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.x = 50
		card.add_theme_font_size_override("font_size", 14)
		card.autowrap_mode = TextServer.AUTOWRAP_OFF
		card.clip_text = true
		card.pressed.connect(func() -> void: card_pressed(i))
		cards.add_child(card)
		_cards.append(card)
	_master_row = HBoxContainer.new()
	_master_row.add_theme_constant_override("separation", 5)
	v.add_child(_master_row)
	for k in 3:
		var b := UiKit.button("", Vector2(0, TRAY_ROW))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		b.clip_text = true
		b.tooltip_text = "C / V / B: pay half the item's price for +%d%% to its stats" % roundi(100.0 * MatchController.CONFIG.masterwork_bonus)
		b.pressed.connect(func() -> void: masterwork_key(k))
		_master_row.add_child(b)
		_master_buttons.append(b)
	_scroll_button = UiKit.button("", Vector2(0, TRAY_ROW))
	_scroll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_button.add_theme_font_size_override("font_size", 14)
	_scroll_button.add_theme_color_override("font_color", Noir.YELLOW)
	_scroll_button.tooltip_text = "N: a single-use scroll that adds a siege trooper to your next wave"
	_scroll_button.pressed.connect(func() -> void: scroll_pressed.emit())
	_master_row.add_child(_scroll_button)


func _build_thumbs() -> void:
	joystick = ThumbStick.new()
	joystick.anchor_left = 0.0
	joystick.anchor_right = 0.55
	joystick.anchor_top = 1.0
	joystick.anchor_bottom = 1.0
	joystick.visible = false
	_root.add_child(joystick)
	# No basic-attack button by design: stopping is the attack. Q is the big thumb button,
	# E sits to its left, R (the ultimate) above it. Keyboard: Q / E / R.
	_ability_buttons.append(_ability_button(136, 28, 28, 0))
	_ability_buttons.append(_ability_button(108, 28 + 136 + 18, 28, 1))
	_ability_buttons.append(_ability_button(108, 28 + 14, 28 + 136 + 18, 2))
	# Your Trick (keyboard: T), above E. Drag to aim a Blink.
	_trick = AimButton.new()
	_trick.custom_minimum_size = Vector2(88, 88)
	_trick.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_trick.add_theme_font_size_override("font_size", 14)
	_trick.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trick.clip_text = true
	_trick.cast.connect(func(dir: Vector2) -> void: trick_aimed.emit(dir))
	_root.add_child(_trick)
	# Shown only while you carry the Relay (keyboard: F).
	_drop = UiKit.button("F\nDrop", Vector2(96, 96))
	_drop.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_drop.add_theme_color_override("font_color", Noir.YELLOW)
	_drop.tooltip_text = "F: drop the Relay"
	_drop.pressed.connect(func() -> void: drop_pressed.emit())
	_drop.visible = false
	_root.add_child(_drop)


## A square drag-to-aim ability button in the bottom right, `right`/`bottom` px in from
## the corner of the free area above the bottom band (and the tray, when open).
func _ability_button(size: float, right: float, bottom: float, slot: int) -> AimButton:
	var b := AimButton.new()
	b.custom_minimum_size = Vector2(size, size)
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.add_theme_font_size_override("font_size", 14 if slot > 0 else 17)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = true
	b.cast.connect(func(dir: Vector2) -> void: cast_aimed.emit(slot, dir))
	_root.add_child(b)
	_ability_offsets.append([size, right, bottom])
	return b


## Moves everything that sits on top of the bottom band (thumbs, perk cards) to `base`
## px above the screen bottom.
func _place_thumbs(base: float) -> void:
	if is_equal_approx(base, _thumb_base):
		return
	_thumb_base = base
	joystick.offset_top = -base - 320
	joystick.offset_bottom = -base - 4
	for i in _ability_buttons.size():
		var b := _ability_buttons[i]
		var o: Array = _ability_offsets[i]
		b.offset_right = -o[1]
		b.offset_left = -o[1] - o[0]
		b.offset_bottom = -base - o[2]
		b.offset_top = -base - o[2] - o[0]
	_trick.offset_right = -(28 + 136 + 18 + 10)
	_trick.offset_left = _trick.offset_right - 88
	_trick.offset_bottom = -base - (28 + 108 + 18)
	_trick.offset_top = _trick.offset_bottom - 88
	_drop.offset_right = -(28 + 136 + 18 + 6)
	_drop.offset_left = _drop.offset_right - 96
	_drop.offset_bottom = -base - (28 + 108 + 18 + 88 + 14)
	_drop.offset_top = _drop.offset_bottom - 96
	_perk_box.offset_bottom = -base - 330
	_perk_box.offset_top = _perk_box.offset_bottom - 150


func _build_perk_picker() -> void:
	_perk_box = VBoxContainer.new()
	_perk_box.anchor_left = 0.04
	_perk_box.anchor_right = 0.96
	_perk_box.anchor_top = 1.0
	_perk_box.anchor_bottom = 1.0
	_perk_box.add_theme_constant_override("separation", 6)
	_perk_box.visible = false
	_root.add_child(_perk_box)
	_perk_title = _outlined(UiKit.label("", 26, Noir.YELLOW))
	_perk_title.add_theme_font_override("font", Noir.SLAB)
	_perk_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_perk_box.add_child(_perk_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_perk_box.add_child(row)
	for k in 2:
		var b := UiKit.button("", Vector2(0, 104))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 17)
		# Perk cards are white slabs, so the choice jumps out of the black HUD.
		Noir.style_button(b, Noir.WHITE, 8.0, 10.0)
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			(b.get_theme_stylebox(st) as NoirBox).shadow_color = Noir.YELLOW
		b.add_theme_font_override("font", HeroLettering.hud_bold())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(c, Noir.INK)
		b.pressed.connect(func() -> void: perk_pressed.emit(k))
		row.add_child(b)
		_perk_buttons.append(b)


func _build_details(inset: float) -> void:
	_details = PanelContainer.new()
	_details.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_details.offset_left = MARGIN + 20
	_details.offset_right = -MARGIN - 20
	_details.offset_top = TOP_BAND + 90 + inset
	_details.visible = false
	_root.add_child(_details)
	_details_text = RichTextLabel.new()
	_details_text.bbcode_enabled = true
	_details_text.fit_content = true
	_details_text.scroll_active = false
	_details_text.add_theme_font_size_override("normal_font_size", 18)
	_details_text.add_theme_font_size_override("bold_font_size", 20)
	_details_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.add_child(_details_text)
	# Tap anywhere on the panel to close it.
	_details.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_details.visible = false)


func _build_status() -> void:
	_respawn = _outlined(UiKit.label("", 44, Noir.WHITE))
	_respawn.add_theme_font_override("font", Noir.SLAB)
	_respawn.set_anchors_preset(Control.PRESET_CENTER)
	_respawn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_respawn.grow_vertical = Control.GROW_DIRECTION_BOTH
	_respawn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	_result_title = UiKit.label("", 72)
	_result_title.add_theme_font_override("font", Noir.slanted(Noir.SLAB))
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_result_title)
	var again := Noir.button("PLAY AGAIN", Noir.YELLOW, Noir.SLAB, 34, Vector2(0, 80))
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		(again.get_theme_stylebox(st) as NoirBox).shadow_color = Noir.WHITE
	again.pressed.connect(func() -> void: restart_pressed.emit())
	v.add_child(again)
	var menu := UiKit.button("HERO SELECT", Vector2(0, 64))
	menu.add_theme_font_override("font", Noir.SLAB)
	menu.add_theme_font_size_override("font_size", 26)
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	v.add_child(menu)


func _outlined(l: Label) -> Label:
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Noir.INK)
	return l


## Keeps the top band clear of notches on phones. Desktop windows have no inset.
func _top_safe_inset() -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var safe := DisplayServer.get_display_safe_area()
	var window_h := float(DisplayServer.window_get_size().y)
	if window_h <= 0.0:
		return 0.0
	return safe.position.y * get_viewport().get_visible_rect().size.y / window_h


## Three small markers for a side's structures, front to back: filled while standing,
## bright outline when it can be hit now, gold outline while immune, a dim cross once
## fallen, and a flash when it takes damage. Health numbers live in the details panel.
class StructPips extends Control:
	var color := Color.WHITE
	var _states: Array = []
	var _last_hp: Array[float] = []
	var _flash_until: Array[int] = [0, 0, 0]

	func refresh(sim: MatchSim, team: int) -> void:
		var list := sim.structures_of(team)
		var now := Time.get_ticks_msec()
		if _last_hp.size() != list.size():
			_last_hp.resize(list.size())
			for i in list.size():
				_last_hp[i] = list[i].hp
		_flash_until.resize(list.size())
		var states: Array = []
		for i in list.size():
			var s := list[i]
			if s.hp < _last_hp[i] - 0.01:
				_flash_until[i] = now + 900
			_last_hp[i] = s.hp
			states.append([s.alive, sim.is_exposed(s), s.alive and (sim.time < s.immune_until or s.guarded), now < _flash_until[i]])
		if states != _states:
			_states = states
			queue_redraw()

	func _draw() -> void:
		var n := _states.size()
		var cell := size.x / maxf(1.0, n)
		var side := minf(cell - 8.0, size.y - 4.0)
		for i in n:
			var st: Array = _states[i]
			var c := Vector2(cell * (i + 0.5), size.y / 2.0)
			var r := Rect2(c - Vector2(side, side) / 2.0, Vector2(side, side))
			if not st[0]:
				var dim := Color(1, 1, 1, 0.3)
				draw_rect(r, Color(0, 0, 0, 0.35))
				draw_line(r.position, r.end, dim, 2.0)
				draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), dim, 2.0)
				continue
			var fill := color if st[1] else color.darkened(0.45)
			if st[3]:
				fill = fill.lerp(Color.WHITE, 0.6)
			draw_rect(r, fill)
			if st[2]:
				draw_rect(r.grow(2.0), Noir.YELLOW, false, 3.0)
			elif st[1]:
				draw_rect(r.grow(1.0), Color(1, 1, 1, 0.85), false, 2.0)
