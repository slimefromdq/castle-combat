extends Node
## Boot flow: the main menu (hero, deck and the other tabs), then a match, then back.

var _menu: MainMenu
var _match: MatchController

func _ready() -> void:
	_menu = MainMenu.new()
	_menu.play_requested.connect(_start_match)
	add_child(_menu)
	# Dev shortcut: `godot -- --autoplay` skips the menu (used by smoke tests and screenshots).
	var args := OS.get_cmdline_user_args()
	if "--autoplay" in args:
		for a in args:
			if a.begins_with("--hero="):
				_menu.pick_hero(int(a.get_slice("=", 1)))  # Before the match starts.
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
		elif a.begins_with("--tab="):
			_menu.show_tab(["shop", "heroes", "battle", "clan", "tournaments"].find(a.get_slice("=", 1)), false)
		elif a.begins_with("--hero="):
			_menu.pick_hero(int(a.get_slice("=", 1)))
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
	_match.hero_index = _menu.hero_index
	_match.deck = MatchController.deck_from(_menu.deck)
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

