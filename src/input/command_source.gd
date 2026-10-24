class_name CommandSource
extends RefCounted
## Anything that can drive a hero: keyboard/touch, the bot, and later the network.
## Each tick it produces one PlayerCommand; it never touches the sim directly.

var team := MatchSim.BLUE


func build_command(_sim: MatchSim) -> PlayerCommand:
	return PlayerCommand.new()
