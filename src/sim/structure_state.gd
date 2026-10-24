class_name StructureState
extends SimEntity
## A tower or Core. Tier 0 = Outer Tower, 1 = Guardian, 2 = Core.

var data: StructureData
var tier := 0
## Guardian beam: who it is focused on, since when, and when it last fired.
var beam_target := 0
var beam_since := 0.0
var beam_last := -10.0
## Guardian slam: when the current windup lands (-1 = none), when the next may start,
## and until when the Guardian can't attack after slamming.
var slam_at := -1.0
var slam_ready_at := 0.0
var disabled_until := 0.0


func setup(structure_data: StructureData, structure_tier: int, structure_team: int, at: Vector2) -> void:
	kind = Kind.STRUCTURE
	data = structure_data
	tier = structure_tier
	team = structure_team
	radius = structure_data.radius
	max_hp = structure_data.max_hp
	hp = max_hp
	pos = at
	prev_pos = at
	blocks_movement = true
	attack_range = structure_data.attack_range
	attack_damage = structure_data.attack_damage
	attack_windup = 0.05 if structure_data.is_guardian else 0.35
	attack_interval = structure_data.attack_interval


func is_guardian() -> bool:
	return data.is_guardian


## True while the Guardian is winding up a slam or recovering from one.
func is_busy(time: float) -> bool:
	return slam_at >= 0.0 or time < disabled_until
