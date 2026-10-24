class_name LocalPlayerSource
extends CommandSource
## The person at this device: keyboard on desktop, virtual joystick on touch.
## Input arrives in screen space (up = toward the enemy) and is turned into sim space here.

var joystick: ThumbStick


func build_command(_sim: MatchSim) -> PlayerCommand:
	var cmd := PlayerCommand.new()
	var screen := Input.get_vector("move_left", "move_right", "move_down", "move_up")
	if joystick != null and joystick.output != Vector2.ZERO:
		screen = joystick.output
	cmd.move = screen_to_sim(screen, team)
	cmd.ability = Input.is_action_pressed("ability")
	cmd.ultimate = Input.is_action_pressed("ultimate")
	cmd.drop_relay = Input.is_action_pressed("drop_relay")
	return cmd


## Your own base is always at the bottom of your screen, so the red seat sees the map
## rotated 180 degrees and its input must be rotated back.
static func screen_to_sim(v: Vector2, seat: int) -> Vector2:
	return v if seat == MatchSim.BLUE else -v
