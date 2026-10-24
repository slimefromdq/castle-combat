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
## Slam: when an enemy hero comes within slam_radius, wind up for slam_windup seconds,
## then hit every enemy hero still inside for slam_damage, knock back and stun them.
## Afterwards the Guardian can't attack for slam_recover seconds.
@export var slam_radius := 0.0
@export var slam_windup := 0.9
@export var slam_damage := 0.0
@export var slam_knockback := 0.0
@export var slam_stun := 0.0
@export var slam_recover := 0.0
@export var slam_cooldown := 12.0
