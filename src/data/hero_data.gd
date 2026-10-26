class_name HeroData
extends Resource
## Tunable numbers for one hero archetype: body, basic attack, abilities and perks.

@export var id: StringName = &""
@export var display_name := ""
## Which primitive silhouette the view builds: "paladin", "gunslinger" or "thief".
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

@export_group("Growth per level (added for each level above 1)")
@export var hp_per_level := 0.0
## Attack Power: the damage of one basic attack.
@export var attack_power_per_level := 0.0
## Ability Power: added to abilities through their ratios (AbilityData.ap_ratio).
@export var ability_power_per_level := 0.0

@export_group("Defences (points: 25 = 20% less, 100 = 50% less)")
## Cuts basic-attack damage taken.
@export var armor := 0.0
## Cuts ability and item damage taken from the enemy hero.
@export var ward := 0.0

## A rule the hero always has: &"blood_debt" (Tot), &"buzz" (Huddle), or none.
@export var hero_trait: StringName = &""

@export_group("Stat card")
## "Attack", "Ability", "Hybrid" or "Tank": what the hero leans on.
@export var lean := "Attack"
## 1-5 pips: toughness, damage, mobility, control, difficulty.
@export var ratings: Array[int] = [3, 3, 3, 3, 3]

@export_group("Sprint look")
## Speed-trail colour, forward lean (degrees) and bounce height while sprinting.
@export var sprint_color := Color(1, 1, 1)
@export var sprint_lean_deg := 15.0
@export var sprint_bob := 0.08
## Sprint facing backwards (Jose's moonwalk).
@export var sprint_moonwalk := false

@export_group("Kit")
## Unlocked at levels 1, 3 and 5 (the last is the ultimate).
@export var abilities: Array[AbilityData] = []
## Pick one of two at levels 2, 4 and 6: [Lv2 A, Lv2 B, Lv4 A, Lv4 B, Lv6 A, Lv6 B].
@export var perks: Array[PerkData] = []
