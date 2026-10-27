class_name LocalPlayerSource
extends CommandSource
## The person at this device: keyboard on desktop, virtual joystick on touch.
## Input arrives in screen space (up = toward the enemy) and is turned into sim space here.

var joystick: ThumbStick
## Set by a click/tap on the battlefield: entity id to focus, -1 to clear, 0 = no change.
var pending_target := 0
## Set by the F key or the Drop button; consumed by the next command.
var pending_drop := false
## Item card slot to buy or sell (keys 1-8 or a tapped card), -1 for none.
var pending_buy := -1
var pending_sell := -1
## Ability to cast (Q/E/R or a button), -1 for none.
var pending_cast := -1
## Perk choice (Z/X or a tapped card), -1 for none.
var pending_perk := -1
var pending_tarot := -1
## Deck slot to make a Masterwork (C/V/B or a tapped button), -1 for none.
var pending_masterwork := -1
## Buy a siege scroll (N or the button).
var pending_scroll := false
## Where you aim (sim space, unit length): the mouse on desktop, the way you move on touch.
## Kept between casts, so a tap casts the way you last aimed or moved.
var aim := Vector2.ZERO
## A drag-to-aim release: aim for the pending cast only (sim space), zero for none.
var pending_aim := Vector2.ZERO


func build_command(_sim: MatchSim) -> PlayerCommand:
	var cmd := PlayerCommand.new()
	var screen := Input.get_vector("move_left", "move_right", "move_down", "move_up")
	if joystick != null and joystick.output != Vector2.ZERO:
		screen = joystick.output
	cmd.move = screen_to_sim(screen, team)
	cmd.target_id = pending_target
	pending_target = 0
	if joystick != null and joystick.visible and joystick.output.length() > 0.3:
		aim = cmd.move.normalized()
	if aim == Vector2.ZERO:
		aim = screen_to_sim(Vector2(0, 1), team)
	cmd.aim = aim
	if pending_cast >= 0 and pending_aim != Vector2.ZERO:
		cmd.aim = pending_aim
		aim = pending_aim
	pending_aim = Vector2.ZERO
	cmd.cast_slot = pending_cast
	pending_cast = -1
	cmd.perk_pick = pending_perk
	pending_perk = -1
	cmd.tarot_pick = pending_tarot
	pending_tarot = -1
	cmd.drop_relay = pending_drop
	pending_drop = false
	cmd.buy_slot = pending_buy
	pending_buy = -1
	cmd.sell_slot = pending_sell
	pending_sell = -1
	cmd.masterwork_slot = pending_masterwork
	pending_masterwork = -1
	cmd.buy_scroll = pending_scroll
	pending_scroll = false
	return cmd


## Your own base is always at the bottom of your screen, so the red seat sees the map
## rotated 180 degrees and its input must be rotated back.
static func screen_to_sim(v: Vector2, seat: int) -> Vector2:
	return v if seat == MatchSim.BLUE else -v
