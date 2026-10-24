class_name PerkData
extends Resource
## A level-up perk (levels 2, 4 and 6). Stat bonuses stack with items the same way;
## `ability_index` + `cooldown_cut` shortens one ability; `special` turns on a
## hand-written rule in Abilities.

@export var id: StringName = &""
@export var display_name := ""
@export var summary := ""

@export_group("Stats (added like item bonuses)")
@export var move_speed_bonus := 0.0
@export var max_hp_bonus := 0.0
@export var damage_bonus := 0.0
@export var attack_speed_bonus := 0.0
@export var range_bonus := 0.0

@export_group("Ability tweaks")
## Which ability (0, 1, 2) the tweak applies to, or -1.
@export var ability_index := -1
@export var cooldown_cut := 0.0
@export var knockback_bonus := 0.0
@export var reach_bonus := 0.0
## bulwark_guard, finisher, siege_battery
@export var special: StringName = &""
## Strength of the special rule (e.g. 0.3 = 30%).
@export var special_value := 0.0
