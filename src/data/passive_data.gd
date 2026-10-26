class_name PassiveData
extends Resource
## An automatic hero passive: granted at levels 3 and 8 (HeroData.passives), no picking.
## Mostly flat stats; `special` turns on a small hand-written rule.

@export var id: StringName = &""
@export var display_name := ""
@export var summary := ""

@export_group("Stats (flat, added before percentage bonuses)")
@export var max_hp := 0.0
@export var attack_power := 0.0
@export var ability_power := 0.0
@export var armor := 0.0
@export var ward := 0.0
## Fraction, like item attack speed (0.15 = 15% faster).
@export var attack_speed_bonus := 0.0
## Metres added to basic attack range.
@export var attack_range := 0.0

@export_group("Special rule")
## Poppet: lifesteal (adds special_value to her lifesteal), restitched (lifesteal x
## special_value below special_value_2 of max HP). Tot: debt_slow (Debt drains
## special_value slower).
@export var special: StringName = &""
@export var special_value := 0.0
@export var special_value_2 := 0.0
