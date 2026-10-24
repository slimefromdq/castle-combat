class_name MinionData
extends Resource
## One minion type. Minions walk the lane and fight on their own; players never command them.

@export var id: StringName = &""
@export var display_name := ""
## "melee" (puck), "ranged" (diamond) or "siege" (drum).
@export var shape := "melee"
@export var max_hp := 280.0
@export var move_speed := 3.0
@export var radius := 0.35
@export var attack_range := 1.0
@export var attack_damage := 16.0
@export var attack_windup := 0.25
@export var attack_interval := 1.0
## Multiplier on damage dealt to towers and Cores.
@export var structure_damage_mult := 1.0
## Gold for the enemy hero who lands the killing blow (a last hit).
@export var gold_bounty := 20.0
## XP for the enemy hero, paid by the same rule as gold (nearby or killing blow).
@export var xp_bounty := 15.0
