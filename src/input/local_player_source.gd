class_name LocalPlayerSource
extends CommandSource
## The person at this device: keyboard on desktop, virtual joystick on touch.
## Input arrives in screen space (up = toward the enemy) and is turned into sim space here.

var joystick: ThumbStick
## Set by a click/tap on the battlefield: entity id to focus, -1 to clear, 0 = no change.
var pending_target := 0
## Set by the F key or the Drop button; consumed by the next command.
var pending_drop := false
## Item card slot to buy (keys 1-6 or a tapped card), -1 for none.
var pending_buy := -1
## Ability to cast (Q/E/R or a button), -1 for none.
var pending_cast := -1


func build_command(_sim: MatchSim) -> PlayerCommand:
	var cmd := PlayerCommand.new()
	var screen := Input.get_vector("move_left", "move_right", "move_down", "move_up")
	if joystick != null and joystick.output != Vector2.ZERO:
		screen = joystick.output
	cmd.move = screen_to_sim(screen, team)
	cmd.target_id = pending_target
	pending_target = 0
	cmd.cast_slot = pending_cast
	pending_cast = -1
	cmd.drop_relay = pending_drop
	pending_drop = false
	cmd.buy_slot = pending_buy
	pending_buy = -1
	return cmd


## Your own base is always at the bottom of your screen, so the red seat sees the map
## rotated 180 degrees and its input must be rotated back.
static func screen_to_sim(v: Vector2, seat: int) -> Vector2:
	return v if seat == MatchSim.BLUE else -v
