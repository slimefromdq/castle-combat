class_name ArenaData
extends Resource
## Map layout in simulation space (metres). x runs across the lane, y along it.
## Blue's Core sits at negative y. Everything is point-symmetric: red's copy of a
## blue position p is -p, which is the GDD's 180-degree rotation.

@export var half_length := 42.0
@export var lane_half_width := 5.0
## Walkable ground pieces, used for visuals.
@export var floors: Array[Rect2] = []
## Side pockets where the Relay appears (M2).
@export var pockets: Array[Rect2] = []
## Solid walls. They block movement and line of sight.
@export var walls: Array[Rect2] = []
## Back alleys beside the lane between the Outer Tower and the Guardian (also listed in
## floors). Each joins the lane through two gaps, alley_gap metres wide, at its ends.
@export var alleys: Array[Rect2] = []
@export var alley_gap := 2.4
## Votive candles (XP + gold pickups, see PickupController). Blue-side positions; each
## is mirrored for red, so 3 here make 6 on the map.
@export var candles: Array[Vector2] = []
## Bushes: a hero standing in one is hidden from the enemy (see MatchSim.is_hidden).
@export var bushes: Array[Rect2] = []
## Blue positions for Outer Tower, Guardian, Core (in that order).
@export var structure_positions: Array[Vector2] = []
@export var hero_spawn := Vector2(2.6, -35.0)
## Blue's healing pad, behind the Core (mirrored for red). Heroes standing on it heal
## until their Guardian falls.
@export var heal_pad := Vector2(0.0, -40.3)
@export var heal_pad_radius := 2.6
@export var minion_spawn := Vector2(0.0, -34.0)


## Every candle on the map: the blue-side list, then red's mirrored copies.
func all_candles() -> Array[Vector2]:
	var out: Array[Vector2] = []
	out.append_array(candles)
	for c in candles:
		out.append(-c)
	return out


static func mirror_rect(r: Rect2) -> Rect2:
	return Rect2(-r.position - r.size, r.size)
