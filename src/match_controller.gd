class_name MatchController
extends Node
## Runs one match: owns the sim, steps it on a fixed tick, feeds it commands from the
## local player and the bot, and lets the 3D view and HUD draw the result.

signal exit_requested

const CONFIG: MatchConfig = preload("res://data/match_config.tres")
const ARENA: ArenaData = preload("res://data/arena_default.tres")
const HEROES: Array[HeroData] = [
	preload("res://data/heroes/vanguard.tres"),
	preload("res://data/heroes/scout.tres"),
	preload("res://data/heroes/gunner.tres"),
]
const TIERS: Array[StructureData] = [
	preload("res://data/structures/outer_tower.tres"),
	preload("res://data/structures/inner_tower.tres"),
	preload("res://data/structures/core.tres"),
]

## Index into HEROES for the local player; the bot takes the next one.
var hero_index := 0
var local_seat := MatchSim.BLUE
var touch_mode := false

var sim: MatchSim
var view: MatchView
var hud: Hud
var player: LocalPlayerSource
var bot: BotSource
var _accumulator := 0.0


func _ready() -> void:
	var picks: Array[HeroData] = [HEROES[hero_index], HEROES[(hero_index + 1) % HEROES.size()]]
	sim = MatchSim.new()
	sim.setup(CONFIG, ARENA, picks, TIERS)
	view = MatchView.new()
	add_child(view)
	view.build(sim, local_seat)
	hud = Hud.new()
	add_child(hud)
	hud.seat_toggle_pressed.connect(toggle_seat)
	hud.touch_toggle_pressed.connect(toggle_touch)
	hud.debug_toggle_pressed.connect(func() -> void: hud.set_debug_visible(not hud.debug_visible))
	hud.menu_pressed.connect(func() -> void: exit_requested.emit())
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


func _tick() -> void:
	var commands: Array = [null, null]
	commands[player.team] = player.build_command(sim)
	commands[bot.team] = bot.build_command(sim)
	sim.step(commands)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_seat"):
		toggle_seat()
	elif event.is_action_pressed("toggle_touch"):
		toggle_touch()
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
