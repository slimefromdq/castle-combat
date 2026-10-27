class_name ArenaData
extends Resource
## Map layout in simulation space (metres). x runs across the lane, y along it.
## Blue's Core sits at negative y. Everything is point-symmetric: red's copy of a
## blue position p is -p, which is the GDD's 180-degree rotation.
##
## The diamond map (Lucy's rework): one lane, which opens into a wide diamond in the
## middle. Walkable ground is the lane strip plus the diamond; walls are obstacles on it.

@export var half_length := 42.0
@export var lane_half_width := 5.0
## The diamond: widest (diamond_half_width from the centre line) at y = 0, its edges
## running to points on the centre line at y = +-diamond_tip. 0 = no diamond (the lane
## and its walls are the whole map).
@export var diamond_half_width := 0.0
@export var diamond_tip := 0.0
## Walkable ground pieces drawn as tiles (the lane). The diamond is drawn separately.
@export var floors: Array[Rect2] = []
## The two Relay spots (the half moons on Lucy's sketch). Not mirrored: both are listed.
@export var pockets: Array[Rect2] = []
## Solid walls. They block movement and line of sight.
@export var walls: Array[Rect2] = []
## Bushes: a hero standing in one is hidden from the enemy (see MatchSim.is_hidden).
@export var bushes: Array[Rect2] = []
## Walk-over pickups (coins and sparks, see PickupController). Blue-side positions; each
## is mirrored for red.
@export var pickups: Array[Vector2] = []
## Neutral camps (see NeutralCamps). Blue-side positions, mirrored for red.
@export var camps: Array[Vector2] = []
## Tarot altar spots (see TarotAltar). Blue-side positions, mirrored for red.
@export var altars: Array[Vector2] = []
## Honey fruit bushes (see Fruits). Blue-side positions, mirrored for red.
@export var fruits: Array[Vector2] = []
## Centre of blue's long Relay drop, deep in red's half (phase 2); red's is the mirror.
## Vector2.ZERO means the map has no long drop.
@export var long_drop := Vector2.ZERO
## Blue positions for Outer Tower, Guardian, Core (in that order).
@export var structure_positions: Array[Vector2] = []
@export var hero_spawn := Vector2(2.6, -35.0)
## Blue's healing pad, behind the Core (mirrored for red).
@export var heal_pad := Vector2(0.0, -40.3)
@export var heal_pad_radius := 2.6
@export var minion_spawn := Vector2(0.0, -34.0)


## A blue-side list followed by red's mirrored copies.
static func mirrored(blue: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	out.append_array(blue)
	for p in blue:
		out.append(-p)
	return out


static func mirror_rect(r: Rect2) -> Rect2:
	return Rect2(-r.position - r.size, r.size)


func has_diamond() -> bool:
	return diamond_half_width > 0.0 and diamond_tip > 0.0


## y where the diamond's edges meet the lane edges.
func shoulder_y() -> float:
	if not has_diamond():
		return 0.0
	return diamond_tip * (1.0 - lane_half_width / diamond_half_width)


## True if a circle of radius r at p fits on walkable ground (walls aside). Without a
## diamond the walls alone bound the map, so everything counts as in bounds.
func in_bounds(p: Vector2, r := 0.0) -> bool:
	if not has_diamond():
		return true
	return in_lane(p, r) or in_diamond(p, r)


func in_lane(p: Vector2, r := 0.0) -> bool:
	return absf(p.x) <= lane_half_width - r and absf(p.y) <= half_length - r


func in_diamond(p: Vector2, r := 0.0) -> bool:
	if not has_diamond():
		return false
	var k := sqrt(1.0 / (diamond_half_width * diamond_half_width) + 1.0 / (diamond_tip * diamond_tip))
	return (1.0 - absf(p.x) / diamond_half_width - absf(p.y) / diamond_tip) / k >= r


## The diamond's outline, counter-clockwise (for drawing and the minimap).
func diamond_points() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, -diamond_tip), Vector2(diamond_half_width, 0), Vector2(0, diamond_tip), Vector2(-diamond_half_width, 0)])


## The four diamond edges that are actual walls: from each shoulder out to the widest point.
func diamond_edges() -> Array:
	var out := []
	if not has_diamond():
		return out
	var s := shoulder_y()
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			out.append([Vector2(sx * lane_half_width, sy * s), Vector2(sx * diamond_half_width, 0.0)])
	return out
