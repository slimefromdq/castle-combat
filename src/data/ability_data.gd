class_name AbilityData
extends Resource
## One hero ability. `effect` picks the behaviour in Abilities (src/sim/abilities.gd); the
## numbers below are its knobs. Abilities aim themselves (enemy hero in reach first),
## so a phone needs one button per ability and no aiming gesture.

@export var id: StringName = &""
@export var display_name := ""
@export var summary := ""
## dash, bash, shield, slam, flurry, blade_rush, power_shot, recoil, barrage
@export var effect: StringName = &""
@export var cooldown := 10.0
## Counts as a movement ability: the Relay carrier can't use it (GDD 7.4).
@export var is_movement := false

@export_group("Numbers (each effect uses the ones it needs)")
## How far the ability looks for an enemy to aim at (metres).
@export var reach := 0.0
@export var damage := 0.0
## Damage to minions and other non-hero units, if different (0 = same as damage).
@export var minion_damage := 0.0
@export var radius := 0.0
## Dash or hop length (metres) and how long it takes (seconds).
@export var distance := 0.0
@export var travel_time := 0.2
@export var knockback := 0.0
@export var stun := 0.0
## Slow strength (0.4 = 40% slower) and how long it lasts.
@export var slow := 0.0
@export var duration := 0.0
## Shield size as a fraction of max HP.
@export var shield_fraction := 0.0
## Attack-speed boost while the buff lasts (0.6 = +60%).
@export var attack_speed_bonus := 0.0
## Channelled abilities: number of damage pulses spread across `duration`.
@export var pulses := 0
