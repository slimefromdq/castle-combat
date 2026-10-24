class_name Palette
## Colors for the 3D view and HUD. You are always blue, the opponent always orange
## (blue/orange stays distinct for common color blindness). Shape carries team too.

const ALLY := Color("3e8ef7")
const ENEMY := Color("f26b2a")
const RELAY := Color("f5e6a8")
const ACCENT := Color("e8ecf0")
const STONE := Color("8a93a0")
const BACKGROUND := Color("1d2228")
const GROUND := Color("262c33")
const LANE := Color("343c46")
const LANE_MARK := Color("414a56")
const POCKET := Color("3a3648")
const POCKET_TILE := Color("464059")
const WALL := Color("5a6676")
const LOCK_DOME := Color(0.75, 0.85, 1.0, 0.22)


static func team_color(is_ally: bool) -> Color:
	return ALLY if is_ally else ENEMY
