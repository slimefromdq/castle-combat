class_name Palette
## Colors for the 3D view and HUD. You are always blue, the opponent always orange
## (blue/orange stays distinct for common color blindness). Shape carries team too.
## The world avoids both team hues: green meadow, sandstone lane, violet pockets, gold Relay.

const ALLY := Color("3e8ef7")
const ENEMY := Color("f26b2a")
const RELAY := Color("ffd84a")
const ACCENT := Color("f2f4f7")
const STONE := Color("b9b2a6")
const LOCK_DOME := Color(0.75, 0.85, 1.0, 0.22)

const BACKGROUND := Color("16324a")
const MEADOW := Color("3f7d4e")
const MEADOW_DARK := Color("356b43")
const BUSH := Color("2f7d3c")
const LANE := Color("8c8174")
const LANE_TILE := Color("9b9083")
const CENTER_LINE := Color("ffd84a")
const POCKET := Color("6a4f9c")
const POCKET_TILE := Color("8466bd")
const WALL := Color("cdbd9b")
const WALL_CAP := Color("efe3c6")
const TREE := Color("2f8f5b")
const TREE_LIGHT := Color("5cbf6e")
const TRUNK := Color("7a5236")
const ROCK := Color("9aa3ad")
const FLOWER_A := Color("ff7ab8")
const FLOWER_B := Color("fff27a")


static func team_color(is_ally: bool) -> Color:
	return ALLY if is_ally else ENEMY
