class_name StructureData
extends Resource
## One tier of a team's defences: Outer Tower, Inner Tower or Core.

@export var id: StringName = &""
@export var display_name := ""
@export var max_hp := 900.0
@export var radius := 1.1
## Visual height of the pillar; the Core ignores it.
@export var height := 2.2
@export var attack_range := 6.0
@export var attack_damage := 60.0
@export var attack_interval := 1.0
