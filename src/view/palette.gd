class_name Palette
## Colors for the 3D view and HUD. You are always blue, the opponent always orange
## (blue/orange stays distinct for common color blindness). Shape carries team too.
## The world avoids both team hues: a warm cobbled street opening into a sandstone
## diamond, violet Relay spots, painted walls and a gold Relay. Street-occult, but bright: everything stays
## mid-tone so team colours and telegraphs pop.

const ALLY := Color("3e8ef7")
const ENEMY := Color("f26b2a")
const RELAY := Color("ffd84a")
const ACCENT := Color("f2f4f7")
const STONE := Color("b9b2a6")
const LOCK_DOME := Color(0.75, 0.85, 1.0, 0.22)

const BACKGROUND := Color("16324a")
const BUSH := Color("2f7d3c")
const LANE := Color("9c8d7d")
const LANE_MORTAR := Color("807264")
## Outside the walls: a mossy plaza of big flagstones (replaces the old meadow).
const PLAZA := Color("6f9a82")
const PLAZA_MORTAR := Color("4f7563")
const CHALK := Color(1.0, 0.98, 0.92, 0.32)
const CENTER_LINE := Color("ffd84a")
const POCKET := Color("6a4f9c")
const POCKET_MORTAR := Color("4f3a78")
## The diamond: golden sandstone cobbles, clearly not lane, plaza or a Relay spot.
const DIAMOND := Color("b59a62")
const DIAMOND_MORTAR := Color("8a7445")
const WALL := Color("cdbd9b")
const WALL_CAP := Color("efe3c6")
const TREE := Color("2f8f5b")
const TREE_LIGHT := Color("5cbf6e")


static func team_color(is_ally: bool) -> Color:
	return ALLY if is_ally else ENEMY
