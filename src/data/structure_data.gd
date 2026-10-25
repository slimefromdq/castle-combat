class_name StructureData
extends Resource
## One tier of a team's defences: Outer Tower, Guardian or Core.

@export var id: StringName = &""
@export var display_name := ""
@export var max_hp := 900.0
@export var radius := 1.1
## Visual height of the pillar; the Core ignores it.
@export var height := 2.2
@export var attack_range := 6.0
@export var attack_damage := 60.0
@export var attack_interval := 1.0
## Gold for the enemy hero when this falls.
@export var gold_bounty := 0.0
## Resist at the start of the match (0.2 = takes 20% less damage); decays over time.
@export var resist_start := 0.0

@export_group("Guardian")
## Guardians fire a beam whose damage grows the longer it stays on one target.
@export var is_guardian := false
## Beam damage multiplier gained per second on the same target, and its cap.
@export var beam_ramp_per_second := 0.0
@export var beam_max_mult := 1.0
## Stomp: each time the Guardian's health drops past one of slam_hp_thresholds (fractions
## of max HP), it winds up for slam_windup seconds, then hits every enemy within
## slam_radius: heroes take slam_damage, are knocked back and stunned; minions lose
## slam_minion_fraction of their max HP and are knocked back. Afterwards the Guardian
## can't attack for slam_recover seconds.
@export var slam_hp_thresholds: Array[float] = []
@export var slam_radius := 0.0
@export var slam_windup := 1.5
@export var slam_damage := 0.0
@export var slam_minion_fraction := 0.0
@export var slam_knockback := 0.0
@export var slam_stun := 0.0
@export var slam_recover := 0.0
