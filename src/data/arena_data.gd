class_name ArenaData
extends Resource
## Map layout in simulation space (metres). x runs across the lane, y along it.
## Blue's Core sits at negative y. Everything is point-symmetric: red's copy of a
## blue position p is -p, which is the GDD's 180-degree rotation.

@export var half_length := 30.0
@export var lane_half_width := 5.0
## Walkable ground pieces, used for visuals.
@export var floors: Array[Rect2] = []
## Side pockets where the Relay appears (M2).
@export var pockets: Array[Rect2] = []
## Solid walls. They block movement and line of sight.
@export var walls: Array[Rect2] = []
## Blue positions for Outer Tower, Inner Tower, Core (in that order).
@export var structure_positions: Array[Vector2] = []
@export var hero_spawn := Vector2(2.2, -24.0)
@export var minion_spawn := Vector2(0.0, -23.5)


static func mirror_rect(r: Rect2) -> Rect2:
	return Rect2(-r.position - r.size, r.size)
