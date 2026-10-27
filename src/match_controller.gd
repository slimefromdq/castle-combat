class_name MatchController
extends Node
## Runs one match: owns the sim, steps it on a fixed tick, feeds it commands from the
## local player and the bot, and lets the 3D view and HUD draw the result.

signal exit_requested
signal restart_requested

const CONFIG: MatchConfig = preload("res://data/match_config.tres")
const ARENA: ArenaData = preload("res://data/arena_default.tres")
const HEROES: Array[HeroData] = [
	preload("res://data/heroes/avery.tres"),
	preload("res://data/heroes/jose.tres"),
	preload("res://data/heroes/jack.tres"),
	preload("res://data/heroes/ahab.tres"),
	preload("res://data/heroes/slayer.tres"),
	preload("res://data/heroes/huddle.tres"),
	preload("res://data/heroes/poppet.tres"),
	preload("res://data/heroes/tot.tres"),
	preload("res://data/heroes/serpent.tres"),
	preload("res://data/heroes/fermata.tres"),
	preload("res://data/heroes/kosmonaut.tres"),
]
const MINIONS := {
	&"melee": preload("res://data/minions/melee.tres"),
	&"ranged": preload("res://data/minions/ranged.tres"),
	&"siege": preload("res://data/minions/siege.tres"),
	&"sapper": preload("res://data/minions/sapper.tres"),
	&"shieldbearer": preload("res://data/minions/shieldbearer.tres"),
}
## The item pool, early to late. Players bring a deck of CONFIG.deck_size of them.
const ITEMS: Array[ItemData] = [
	preload("res://data/items/trooper_cleaver.tres"),
	preload("res://data/items/mending_charm.tres"),
	preload("res://data/items/fleet_sandals.tres"),
	preload("res://data/items/spark_band.tres"),
	preload("res://data/items/bloodthirst_blade.tres"),
	preload("res://data/items/thorncut.tres"),
	preload("res://data/items/warding_cloak.tres"),
	preload("res://data/items/overcharge_gem.tres"),
	preload("res://data/items/siege_banner.tres"),
	preload("res://data/items/stormcrown.tres"),
	preload("res://data/items/reapers_rhythm.tres"),
	preload("res://data/items/aegis_mirror.tres"),
	preload("res://data/items/titan_core.tres"),
	preload("res://data/items/whetstone.tres"),
	preload("res://data/items/executioners_edge.tres"),
	preload("res://data/items/duelists_crest.tres"),
	preload("res://data/items/training_blade.tres"),
	preload("res://data/items/ink_quill.tres"),
	preload("res://data/items/padded_vest.tres"),
	preload("res://data/items/hourglass_charm.tres"),
	preload("res://data/items/war_gauntlet.tres"),
	preload("res://data/items/grimoire.tres"),
	preload("res://data/items/runed_saber.tres"),
	preload("res://data/items/bulwark_plate.tres"),
	preload("res://data/items/sunder_pick.tres"),
	preload("res://data/items/hex_needle.tres"),
	preload("res://data/items/colossus_heart.tres"),
	preload("res://data/items/warlords_greatsword.tres"),
	preload("res://data/items/archmages_crown.tres"),
	preload("res://data/items/phoenix_feather.tres"),
]
## Indices into ITEMS: the deck you start with in the menu.
const DEFAULT_DECK := [0, 1, 13, 4, 5, 14, 9, 15]
## The bot's deck for each hero it plays.
const BOT_DECKS := {
	&"avery": [0, 1, 2, 6, 7, 8, 9, 11],
	&"jose": [0, 1, 13, 4, 5, 14, 10, 15],
	&"jack": [0, 1, 3, 6, 7, 5, 9, 11],
	&"ahab": [18, 1, 23, 6, 5, 26, 9, 19],
	&"slayer": [16, 1, 13, 20, 24, 27, 15, 5],
	&"huddle": [17, 1, 19, 21, 25, 28, 6, 9],
	&"poppet": [16, 17, 22, 5, 14, 27, 29, 13],
	&"tot": [16, 18, 22, 5, 20, 27, 29, 1],
	&"serpent": [17, 1, 19, 21, 25, 28, 6, 9],
	&"fermata": [18, 1, 17, 21, 23, 26, 28, 6],
	&"kosmonaut": [17, 1, 19, 21, 25, 28, 7, 9],
}
const TIERS: Array[StructureData] = [
	preload("res://data/structures/outer_tower.tres"),
	preload("res://data/structures/guardian.tres"),
	preload("res://data/structures/core.tres"),
]

## Index into HEROES for the local player; the bot takes the next one.
var hero_index := 0
## The local player's six-card deck (from the menu); empty = DEFAULT_DECK.
var deck: Array[ItemData] = []
var local_seat := MatchSim.BLUE
var touch_mode := false
## Dev: the bot also drives the local hero (for screenshots and soak tests).
var autopilot: BotSource
## The VS intro before the clock starts (dev runs and bots skip it).
var play_intro := true

var sim: MatchSim
var view: MatchView
var hud: Hud
var player: LocalPlayerSource
var bot: BotSource
var _accumulator := 0.0
var _mouse_screen := Vector2.ZERO
var _mouse_seen := false
var _intro: MatchIntro
var _victory: MatchVictory
var _victory_started := false
var _audio: MatchAudio


func _ready() -> void:
	var picks: Array[HeroData] = [HEROES[hero_index], HEROES[(hero_index + 1) % HEROES.size()]]
	sim = MatchSim.new()
	var mine := deck if deck.size() == CONFIG.deck_size else deck_from(DEFAULT_DECK)
	var theirs := bot_deck(picks[1])
	var decks := [mine, theirs] if local_seat == MatchSim.BLUE else [theirs, mine]
	sim.setup(CONFIG, ARENA, picks, TIERS, MINIONS, decks)
	view = MatchView.new()
	add_child(view)
	view.build(sim, local_seat)
	hud = Hud.new()
	add_child(hud)
	hud.seat_toggle_pressed.connect(toggle_seat)
	hud.touch_toggle_pressed.connect(toggle_touch)
	hud.debug_toggle_pressed.connect(func() -> void: hud.set_debug_visible(not hud.debug_visible))
	hud.menu_pressed.connect(func() -> void: exit_requested.emit())
	hud.restart_pressed.connect(func() -> void: restart_requested.emit())
	hud.drop_pressed.connect(func() -> void: player.pending_drop = true)
	hud.buy_pressed.connect(func(slot: int) -> void: player.pending_buy = slot)
	hud.sell_pressed.connect(func(slot: int) -> void: player.pending_sell = slot)
	hud.cast_aimed.connect(func(slot: int, screen_dir: Vector2) -> void:
		player.pending_cast = slot
		player.pending_aim = LocalPlayerSource.screen_to_sim(screen_dir, local_seat))
	hud.fullscreen_pressed.connect(func() -> void: UiKit.toggle_fullscreen())
	hud.perk_pressed.connect(func(choice: int) -> void: player.pending_perk = choice)
	hud.masterwork_pressed.connect(func(slot: int) -> void: player.pending_masterwork = slot)
	hud.scroll_pressed.connect(func() -> void: player.pending_scroll = true)
	sim.sim_event.connect(func(type: StringName, data: Dictionary) -> void: hud.on_sim_event(type, data, local_seat))
	player = LocalPlayerSource.new()
	player.team = local_seat
	player.joystick = hud.joystick
	bot = BotSource.new()
	bot.team = 1 - local_seat
	# Real touch screens get the joystick by default; desktop can opt in with F3.
	touch_mode = DisplayServer.is_touchscreen_available()
	hud.set_touch_mode(touch_mode, not DisplayServer.is_touchscreen_available())
	_audio = MatchAudio.new()
	_audio.name = "Audio"
	add_child(_audio)
	_audio.setup(sim, local_seat)
	if play_intro:
		_intro = MatchIntro.new()
		_intro.setup(sim.heroes[local_seat].data, sim.heroes[1 - local_seat].data)
		_intro.finished.connect(func() -> void: _intro = null)
		add_child(_intro)


func _process(delta: float) -> void:
	# The clock waits while the intro plays.
	if _intro == null:
		_accumulator += minf(delta, 0.25)
		while _accumulator >= sim.dt:
			_accumulator -= sim.dt
			_tick()
	if sim.over and not _victory_started:
		_start_victory()
	view.render(_accumulator / sim.dt, delta)
	hud.visible = _intro == null
	hud.hold_result = _victory != null
	hud.refresh(sim, local_seat, Engine.get_frames_per_second())
	hud.set_fullscreen_label(UiKit.is_fullscreen())
	_update_aim()


## The last Core fell: the winner celebrates and a VICTORY/DEFEAT flyer plays before
## the result panel.
func _start_victory() -> void:
	_victory_started = true
	var w := sim.heroes[sim.winner]
	view.celebrate(sim.winner)
	Sfx.play(&"victory" if sim.winner == local_seat else &"defeat")
	_victory = MatchVictory.new()
	_victory.setup(sim.winner == local_seat, w.data, Palette.team_color(sim.winner == local_seat))
	_victory.finished.connect(func() -> void: _victory = null)
	add_child(_victory)


## Desktop: abilities aim at the ground under the mouse. Touch: the way you move, or the
## drag on an ability button (shown as an aim line on the ground while you drag).
func _update_aim() -> void:
	var me := sim.heroes[local_seat]
	if not touch_mode and _mouse_seen:
		var p := view.ground_point(_mouse_screen)
		if p.distance_to(me.pos) > 0.2:
			player.aim = (p - me.pos).normalized()
	var drag: Array = hud.aim_drag()
	if drag[0] >= 0 and drag[1] != Vector2.ZERO:
		var a := Abilities.ability_for(sim, me, drag[0])
		var length := 6.0 if a == null else (a.reach if a.reach > 0.0 else maxf(a.distance, 3.0))
		view.show_aim(LocalPlayerSource.screen_to_sim(drag[1].normalized(), local_seat), length)
	else:
		view.hide_aim()


static func bot_deck(hero: HeroData) -> Array[ItemData]:
	return deck_from(BOT_DECKS.get(hero.id, DEFAULT_DECK))


static func deck_from(indices: Array) -> Array[ItemData]:
	var out: Array[ItemData] = []
	for i: int in indices:
		out.append(ITEMS[i])
	return out


## Dev: run the sim forward instantly, e.g. to screenshot a mid-match moment.
func fast_forward(seconds: float) -> void:
	for i in int(seconds / sim.dt):
		_tick()
	view.render(1.0, 0.0, true)


## Dev: set up a moment for screenshots. "duel" / "perk" see below; "guardian" = your wave beside the enemy
## Guardian (beam active); "stomp" = the same, mid-way through a stomp telegraph.
func stage(what: String) -> void:
	var enemy := 1 - local_seat
	if what == "candles" or what == "alley":
		# "candles": just after the candles light, you walk into your right-hand back
		# alley toward its candle; the pocket candles' edge arrows show. "alley": the
		# same alley from further back, with its candle snuffed and relighting.
		sim.tick = int(round(sim.config.candle_first_time / sim.dt)) + 3
		sim.time = sim.tick * sim.dt
		sim.next_wave_time = 1000.0
		sim.pickups.tick(sim)
		var mine: PickupController.Candle = null
		for c in sim.pickups.candles:
			var local := MatchSim.to_team_space(local_seat, c.pos)
			if local.y < -20.0 and local.x > 0.0:
				mine = c
		var me_s := sim.heroes[local_seat]
		me_s.pos = mine.pos + MatchSim.to_team_space(local_seat, Vector2(-1.6, -2.2) if what == "candles" else Vector2(-1.2, -3.5))
		me_s.prev_pos = me_s.pos
		if what == "alley":
			mine.lit = false
			mine.lit_at = sim.time + sim.config.candle_respawn_time * 0.35
		var them_s := sim.heroes[enemy]
		them_s.pos = MatchSim.to_team_space(enemy, Vector2(0, -30))
		them_s.prev_pos = them_s.pos
		view.render(1.0, 0.0, true)
		return
	if what == "duel" or what == "perk":
		# "duel": both heroes at max level (9) a few metres apart in mid-lane (pair with
		# --autopilot and --skip=N to catch abilities); "perk": you just hit level 2.
		for h in sim.heroes:
			Leveling.gain(sim, h, float(sim.config.level_xp[sim.config.level_xp.size() - 1 if what == "duel" else 1]) - h.xp + 0.01)
			if what == "duel":
				for t in 3:
					Leveling.pick_perk(sim, h, 0)
			h.pos = MatchSim.to_team_space(h.team, Vector2(0.8, -3.0))
			h.prev_pos = h.pos
		sim.next_wave_time = 1000.0
		view.render(1.0, 0.0, true)
		return
	if what == "spikes" or what == "ultrace":
		# "spikes": both heroes at level 8 by your tower, carrying mid and late items (item
		# silhouettes, Masterwork offers, the enemy spike callout). "ultrace": you just
		# reached level 6 first (level-up ring and the ult race pillar).
		for h in sim.heroes:
			h.pos = MatchSim.to_team_space(local_seat, Vector2(0.6 + (2.2 if h.team != local_seat else -1.2), -10.5 if h.team == local_seat else -6.0))
			h.prev_pos = h.pos
		sim.next_wave_time = 1000.0
		var me_u := sim.heroes[local_seat]
		if what == "ultrace":
			Leveling.gain(sim, sim.heroes[enemy], float(sim.config.level_xp[Leveling.ULT_LEVEL - 2]) - sim.heroes[enemy].xp + 0.01)
			Leveling.gain(sim, me_u, float(sim.config.level_xp[Leveling.ULT_LEVEL - 2]) - me_u.xp + 0.01)
			for h in sim.heroes:
				Leveling.pick_perk(sim, h, 0)
				Leveling.pick_perk(sim, h, 0)
			me_u.hp = me_u.max_hp * 0.6
			view.render(1.0, 0.0, true)
			Leveling.gain(sim, me_u, float(sim.config.level_xp[Leveling.ULT_LEVEL - 1]) - me_u.xp + 0.01)
			return
		for h in sim.heroes:
			Leveling.gain(sim, h, float(sim.config.level_xp[sim.config.masterwork_level - 1]) - h.xp + 0.01)
			for t in 3:
				Leveling.pick_perk(sim, h, 0)
			# A mid and a late item from the deck (the cheapest of each).
			for tier in [ItemData.Tier.MID, ItemData.Tier.LATE]:
				var pick := -1
				for i in h.deck.size():
					if h.deck[i].tier == tier and (pick < 0 or h.deck[i].cost < h.deck[pick].cost):
						pick = i
				if pick >= 0:
					h.gold += h.deck[pick].cost
					var keep := h.pos
					h.pos = MatchSim.to_team_space(h.team, sim.arena.heal_pad)
					Economy.try_buy(sim, h, pick)
					h.pos = keep
		var them_s := sim.heroes[enemy]
		them_s.gold = 2000.0
		var keep_t := them_s.pos
		them_s.pos = MatchSim.to_team_space(enemy, sim.arena.heal_pad)
		Economy.try_masterwork(sim, them_s, them_s.deck.find(them_s.items[-1]))
		them_s.pos = keep_t
		me_u.gold = 1400.0
		view.render(1.0, 0.0, true)
		return
	if what == "waves":
		# Special troopers mid-lane (a Shieldbearer and a Sapper each side), a banner on
		# the ground in front of you, and a banner-buffed wave of yours.
		for h in sim.heroes:
			h.pos = MatchSim.to_team_space(h.team, Vector2(1.2, -8.0 if h.team == local_seat else -22.0))
			h.prev_pos = h.pos
		sim.next_wave_time = 1000.0
		var ally_fwd := MatchSim.forward(local_seat)
		var made: Array[MinionState] = []
		for team in [local_seat, enemy]:
			var base := Vector2(0, -1.8 if team == local_seat else 1.8)
			var dir: Vector2 = MatchSim.forward(team)
			var row: Array = [[&"shieldbearer", 0.0], [&"melee", -0.9], [&"melee", 0.9], [&"sapper", -0.5], [&"ranged", 0.6]]
			for k in row.size():
				var spot := MatchSim.to_team_space(local_seat, base) - dir * (0.0 if k == 0 else (1.3 if k < 3 else 2.5)) + Vector2(row[k][1], 0)
				var m := sim.spawn_minion(MINIONS[row[k][0]], team, spot)
				m.max_hp *= 30.0
				m.hp = m.max_hp
				made.append(m)
				if team == local_seat:
					m.bannered = true
		sim.banners.append({"id": sim.new_id(), "pos": MatchSim.to_team_space(local_seat, Vector2(-1.6, -6.0)), "expires_at": 1000.0})
		fast_forward(0.4)
		return
	if what == "aim" or what == "shop":
		# "aim": level 6 in mid-lane, dragging the R button to aim (touch). "shop": level 8
		# at your base, so the item tray opens with the Masterwork row.
		var me_a := sim.heroes[local_seat]
		sim.next_wave_time = 1000.0
		Leveling.gain(sim, me_a, float(sim.config.level_xp[Leveling.ULT_LEVEL - 1 if what == "aim" else sim.config.masterwork_level - 1]) - me_a.xp + 0.01)
		for t in 3:
			Leveling.pick_perk(sim, me_a, 0)
		if what == "aim":
			me_a.pos = MatchSim.to_team_space(local_seat, Vector2(0.0, -6.0))
			sim.heroes[enemy].pos = MatchSim.to_team_space(local_seat, Vector2(2.5, 1.0))
			hud.demo_aim(2, Vector2(0.45, 0.9))
		else:
			me_a.gold = 2400.0
			Economy.try_buy(sim, me_a, 0)
		for h in sim.heroes:
			h.prev_pos = h.pos
		view.render(1.0, 0.0, true)
		return
	if what == "win":
		# The enemy Core falls in front of you: the victory celebration plays.
		var me_w := sim.heroes[local_seat]
		var theirs_w := sim.structures_of(enemy)
		me_w.pos = theirs_w[2].pos - MatchSim.forward(local_seat) * 4.0
		me_w.prev_pos = me_w.pos
		for st in theirs_w:
			st.immune_until = 0.0
			sim.apply_damage(st, st.max_hp * 10.0, me_w)
			st.immune_until = 0.0
		fast_forward(0.1)
		return
	if what == "bush" or what == "core":
		# "bush": you hide in the bush ahead of your tower while the enemy walks past (it
		# can't see you). "core": the enemy Guardian just fell, so their Core is immune.
		var me_b := sim.heroes[local_seat]
		var them_b := sim.heroes[enemy]
		sim.next_wave_time = 1000.0
		if what == "bush":
			var bush := sim.arena.bushes[0] if local_seat == MatchSim.BLUE else sim.arena.bushes[1]
			me_b.pos = bush.get_center()
			them_b.pos = bush.get_center() + MatchSim.forward(local_seat) * 5.0 + Vector2(3.5 * (1 if local_seat == MatchSim.BLUE else -1), 0)
		else:
			var theirs_c := sim.structures_of(enemy)
			sim.apply_damage(theirs_c[0], theirs_c[0].max_hp * 10.0, me_b)
			sim.apply_damage(theirs_c[1], theirs_c[1].max_hp * 10.0, me_b)
			me_b.pos = theirs_c[2].pos - MatchSim.forward(local_seat) * 6.0
			them_b.pos = theirs_c[2].pos + Vector2(3.0, 0)
		for h in sim.heroes:
			h.prev_pos = h.pos
		fast_forward(0.1)
		return
	if what == "sprint":
		# Start in the lane in front of your tower (pair with --walk-up to see a sprint).
		var me_s := sim.heroes[local_seat]
		me_s.pos = MatchSim.to_team_space(local_seat, Vector2(0, -12))
		me_s.prev_pos = me_s.pos
		return
	var theirs := sim.structures_of(enemy)
	sim.apply_damage(theirs[0], theirs[0].max_hp * 10.0, sim.heroes[local_seat])
	var g := theirs[1]
	var toward_me := MatchSim.forward(local_seat) * -1.0
	var me := sim.heroes[local_seat]
	me.pos = g.pos + toward_me * 8.5 + Vector2(1.5, 0)
	me.prev_pos = me.pos
	for i in 4:
		var m := sim.spawn_minion(MINIONS[&"melee"], local_seat, g.pos + toward_me * (2.6 + 0.6 * i) + Vector2(-1.2 + 0.8 * i, 0))
		m.max_hp *= 20.0
		m.hp = m.max_hp
	g.hp = g.max_hp * 0.7
	fast_forward(2.5)
	if what == "stomp":
		g.hp = g.max_hp * 0.6
		fast_forward(0.9)


func _tick() -> void:
	var commands: Array = [null, null]
	if autopilot != null:
		autopilot.team = player.team
		commands[player.team] = autopilot.build_command(sim)
	else:
		commands[player.team] = player.build_command(sim)
	commands[bot.team] = bot.build_command(sim)
	sim.step(commands)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_screen = event.position
		_mouse_seen = true
	# Click or tap a unit to focus it (for last hits); click empty ground to clear.
	var tap: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if tap or (event is InputEventScreenTouch and event.pressed):
		var id := view.pick_enemy(event.position)
		player.pending_target = id if id > 0 else -1
		return
	for i in 3:
		if event.is_action_pressed("cast_%d" % (i + 1)):
			player.pending_cast = i
			return
	for i in 2:
		if event.is_action_pressed("perk_%d" % (i + 1)):
			player.pending_perk = i
			return
	for i in 3:
		if event.is_action_pressed("master_%d" % (i + 1)):
			hud.masterwork_key(i)
			return
	if event.is_action_pressed("siege_scroll"):
		player.pending_scroll = true
		return
	for i in CONFIG.deck_size:
		if event.is_action_pressed("buy_%d" % (i + 1)):
			# A card you own sells on a second press (the HUD asks first).
			hud.card_pressed(i)
			return
	if event.is_action_pressed("toggle_seat"):
		toggle_seat()
	elif event.is_action_pressed("toggle_touch"):
		toggle_touch()
	elif event.is_action_pressed("drop_relay"):
		player.pending_drop = true
	elif event.is_action_pressed("show_deck"):
		hud.toggle_details()
	elif event.is_action_pressed("toggle_debug"):
		hud.set_debug_visible(not hud.debug_visible)
	elif event.is_action_pressed("back"):
		exit_requested.emit()


## Debug: play the other side. Your base moves to the bottom of the screen either way.
func toggle_seat() -> void:
	local_seat = 1 - local_seat
	player.team = local_seat
	bot.team = 1 - local_seat
	bot.reset()
	_audio.seat = local_seat
	view.set_local_seat(local_seat)


func toggle_touch() -> void:
	touch_mode = not touch_mode
	hud.set_touch_mode(touch_mode, not DisplayServer.is_touchscreen_available())
