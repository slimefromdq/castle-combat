class_name StructureState
extends SimEntity
## A tower or Core. Tier 0 = Outer Tower, 1 = Inner Tower, 2 = Core.

var data: StructureData
var tier := 0


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
	attack_windup = 0.35
	attack_interval = structure_data.attack_interval
