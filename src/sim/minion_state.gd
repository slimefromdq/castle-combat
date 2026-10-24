class_name MinionState
extends SimEntity
## An autonomous lane minion.

var data: MinionData
## Unit vector toward the enemy Core.
var lane_dir := MatchSim.BLUE_FORWARD
## Set when this minion is the reward from a Relay delivery (M2).
var is_siege := false
## Power minion (after the enemy Guardian fell) and its speed bonus.
var is_power := false
var speed_mult := 1.0


func setup(minion_data: MinionData, minion_team: int, at: Vector2) -> void:
	kind = Kind.MINION
	data = minion_data
	team = minion_team
	radius = minion_data.radius
	max_hp = minion_data.max_hp
	hp = max_hp
	pos = at
	prev_pos = at
	lane_dir = MatchSim.forward(minion_team)
	attack_range = minion_data.attack_range
	attack_damage = minion_data.attack_damage
	attack_windup = minion_data.attack_windup
	attack_interval = minion_data.attack_interval
