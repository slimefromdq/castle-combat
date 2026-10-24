class_name ItemData
extends Resource
## One item card (GDD 8). Items are passive: buying one changes hero stats or adds a
## simple triggered effect. All values are test knobs, not final balance.

@export var id: StringName = &""
@export var display_name := ""
## Short line for the card and tooltip.
@export var summary := ""
@export var cost := 300

@export_group("Hero stats (multipliers add up: +8% and +8% = +16%)")
@export var move_speed_bonus := 0.0
@export var max_hp_bonus := 0.0
@export var damage_bonus := 0.0
@export var attack_speed_bonus := 0.0
@export var range_bonus := 0.0
## Less distance from knockbacks and pulls. No ability displaces yet (abilities are later).
@export var displacement_reduction := 0.0

@export_group("Triggered effects")
## Allied minions within siege_aura_radius of the holder deal this much more to structures.
@export var siege_aura_bonus := 0.0
@export var siege_aura_radius := 0.0
## After regen_delay seconds without enemy-hero damage, heal this fraction of max HP per second.
@export var regen_delay := 0.0
@export var regen_per_second := 0.0
