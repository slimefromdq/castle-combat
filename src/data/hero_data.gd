class_name HeroData
extends Resource
## Tunable numbers for one hero archetype: body, basic attack, abilities and perks.

@export var id: StringName = &""
@export var display_name := ""
## Which primitive silhouette the view builds: "box", "cone" or "cylinder".
@export var shape := "box"
@export_multiline var blurb := ""

@export_group("Body")
@export var max_hp := 600.0
@export var move_speed := 4.5
@export var radius := 0.5

@export_group("Basic attack")
@export var attack_range := 1.8
@export var attack_damage := 40.0
@export var attack_windup := 0.25
@export var attack_interval := 0.85

@export_group("Kit")
## Unlocked at levels 1, 3 and 5 (the last is the ultimate).
@export var abilities: Array[AbilityData] = []
## Gained at levels 2, 4 and 6 (the last is the capstone).
@export var perks: Array[PerkData] = []
