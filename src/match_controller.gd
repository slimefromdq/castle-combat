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
## The eight-item pool from GDD 8. Players pick six of them before a match.
const ITEMS: Array[ItemData] = [
	preload("res://data/items/fleet_sandals.tres"),
	preload("res://data/items/iron_shell.tres"),
	preload("res://data/items/grip_gloves.tres"),
	preload("res://data/items/quickstring.tres"),
	preload("res://data/items/anchor_charm.tres"),
	preload("res://data/items/siege_banner.tres"),
	preload("res://data/items/watchful_lens.tres"),
	preload("res://data/items/recovery_sigil.tres"),
]
## Indices into ITEMS: the deck you start with, and the one the bot always brings.
const DEFAULT_DECK := [0, 1, 2, 3, 5, 7]
const BOT_DECK := [0, 1, 2, 3, 6, 7]
const TIERS: Array[StructureData] = [
	preload("res://data/structures/outer_tower.tres"),
	preload("res://data/structures/inner_tower.tres"),
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
	var decks := [mine, deck_from(BOT_DECK)] if local_seat == MatchSim.BLUE else [deck_from(BOT_DECK), mine]
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
	for i in 6:
		if event.is_action_pressed("buy_%d" % (i + 1)):
			player.pending_buy = i
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
