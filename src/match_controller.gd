class_name MatchController
extends Node
## Runs one match: owns the sim, steps it on a fixed tick, feeds it commands from the
## local player and the bot, and lets the 3D view and HUD draw the result.

signal exit_requested
signal restart_requested

const CONFIG: MatchConfig = preload("res://data/match_config.tres")
const ARENA: ArenaData = preload("res://data/arena_default.tres")
const HEROES: Array[HeroData] = [
	preload("res://data/heroes/vanguard.tres"),
	preload("res://data/heroes/scout.tres"),
	preload("res://data/heroes/gunner.tres"),
]
const MINIONS := {
	&"melee": preload("res://data/minions/melee.tres"),
	&"ranged": preload("res://data/minions/ranged.tres"),
	&"siege": preload("res://data/minions/siege.tres"),
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
]
## Indices into ITEMS: the deck you start with in the menu.
const DEFAULT_DECK := [0, 1, 13, 4, 5, 14, 9, 15]
## The bot's deck for each hero it plays.
const BOT_DECKS := {
	&"vanguard": [0, 1, 2, 6, 7, 8, 9, 11],
	&"scout": [0, 13, 3, 4, 5, 14, 10, 15],
	&"gunner": [0, 1, 13, 5, 6, 14, 12, 15],
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

var sim: MatchSim
var view: MatchView
var hud: Hud
var player: LocalPlayerSource
var bot: BotSource
var _accumulator := 0.0


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
	hud.cast_pressed.connect(func(slot: int) -> void: player.pending_cast = slot)
	sim.sim_event.connect(func(type: StringName, data: Dictionary) -> void: hud.on_sim_event(type, data, local_seat))
	player = LocalPlayerSource.new()
	player.team = local_seat
	player.joystick = hud.joystick
	bot = BotSource.new()
	bot.team = 1 - local_seat
	# Real touch screens get the joystick by default; desktop can opt in with F3.
	touch_mode = DisplayServer.is_touchscreen_available()
	hud.set_touch_mode(touch_mode, not DisplayServer.is_touchscreen_available())


func _process(delta: float) -> void:
	_accumulator += minf(delta, 0.25)
	while _accumulator >= sim.dt:
		_accumulator -= sim.dt
		_tick()
	view.render(_accumulator / sim.dt, delta)
	hud.refresh(sim, local_seat, Engine.get_frames_per_second())


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


## Dev: set up a moment for screenshots. "guardian" = your wave beside the enemy
## Guardian (beam active); "stomp" = the same, mid-way through a stomp telegraph.
func stage(what: String) -> void:
	var enemy := 1 - local_seat
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
		hud.toggle_tray()
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
	view.set_local_seat(local_seat)


func toggle_touch() -> void:
	touch_mode = not touch_mode
	hud.set_touch_mode(touch_mode, not DisplayServer.is_touchscreen_available())
