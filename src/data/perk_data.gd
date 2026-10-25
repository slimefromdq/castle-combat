class_name PerkData
extends Resource
## A level-up perk. At levels 2, 4 and 6 the player picks one of two (HeroData.perks
## holds them in pairs). Stat bonuses stack with items the same way; `ability_index` +
## `cooldown_cut` shortens one ability; `special` turns on a hand-written rule.

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
## Avery: mercy, steadfast, shatter, charge, judgment, sanctuary.
## Jose: smooth_operator, encore, lady_killer, last_call, showstopper, bloody_tango.
## Jack: sleight_of_hand, misdirection, smoke_and_mirrors, vanishing_act, quick_study,
## stage_presence.
@export var special: StringName = &""
## Strength of the special rule (e.g. 0.3 = 30%), a second number if it needs one,
## and how long it lasts.
@export var special_value := 0.0
@export var special_value_2 := 0.0
@export var special_duration := 0.0
