class_name AbilityData
extends Resource
## One hero ability. `effect` picks the behaviour in Abilities (src/sim/abilities.gd); the
## numbers below are its knobs. Abilities aim themselves (enemy hero in reach first),
## so a phone needs one button per ability and no aiming gesture. Skillshots fly toward
## that aim point and can be dodged.

@export var id: StringName = &""
@export var display_name := ""
@export var summary := ""
## Avery: cleave, oath, judgment_blade. Jose: spin_dash, sweet_talk, last_tango.
## Jack: cloak_toss, vanish, encore (casts the enemy hero's ultimate).
@export var effect: StringName = &""
@export var cooldown := 10.0
## Counts as a movement ability: the Relay carrier can't use it (GDD 7.4).
@export var is_movement := false

@export_group("Scaling (added to damage: base + ratio x stat)")
## Share of Ability Power, Attack Power and max HP added to this ability's damage.
@export var ap_ratio := 0.0
@export var atk_ratio := 0.0
@export var hp_ratio := 0.0
## Share of Ability Power added to this ability's shields and heals.
@export var heal_ap_ratio := 0.0

@export_group("Numbers (each effect uses the ones it needs)")
## How far the ability looks for an enemy to aim at, or a skillshot's range (metres).
@export var reach := 0.0
@export var damage := 0.0
## Damage to minions and other non-hero units, if different (0 = same as damage).
@export var minion_damage := 0.0
## A charged ability's damage at full charge, and how long a full charge takes.
@export var max_damage := 0.0
@export var charge_time := 0.0
@export var radius := 0.0
## Dash length (metres) and how long it takes (seconds).
@export var distance := 0.0
@export var travel_time := 0.2
@export var stun := 0.0
## Skillshot flight speed (m/s) and half-width (metres).
@export var speed := 0.0
@export var width := 0.5
## How long an effect lasts (shield, channel, vanish), and for channels the number
## of damage pulses spread across it.
@export var duration := 0.0
@export var pulses := 0
## Hero move speed multiplier while channelling, charging or vanished (1 = normal).
@export var move_mult := 1.0
## Seconds a follow-up cast stays available (second dash, cloak teleport).
@export var recast_window := 0.0
## Shield size as a fraction of max HP.
@export var shield_fraction := 0.0
## Move speed boost (0.25 = +25%) for buff_duration seconds.
@export var move_speed_bonus := 0.0
@export var buff_duration := 0.0
## Round-2 kits: slow (fraction) and its length, root length, a telegraph or windup
## before the effect, a health cost paid into Debt (fraction of max HP), a bleed (fraction
## of the target's max HP over bleed_time), attack speed while buffed, and one extra
## number whose meaning the effect documents in Kits.
@export var slow := 0.0
@export var slow_time := 0.0
@export var root := 0.0
@export var delay := 0.0
@export var hp_cost := 0.0
@export var bleed_fraction := 0.0
@export var bleed_time := 0.0
@export var attack_speed_bonus := 0.0
@export var extra := 0.0
## Healing for each trooper and each enemy hero an attack hits.
@export var heal_per_minion := 0.0
@export var heal_per_hero := 0.0
