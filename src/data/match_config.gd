class_name MatchConfig
extends Resource
## Match-wide rules and timers. Values are GDD v0.1 seeds, not final balance.

@export var tick_rate := 30
## Joystick or stick input shorter than this counts as standing still.
@export var move_dead_zone := 0.15
@export var respawn_time := 7.0
## Heroes standing this close to their own Core heal (not in the GDD; added so damage
## isn't permanent without the Recovery Sigil item). Fraction of max HP per second.
@export var base_heal_radius := 7.0
@export var base_heal_per_second := 0.12

@export_group("Waves")
@export var first_wave_time := 3.0
@export var wave_interval := 12.0
@export var wave_melee := 2
@export var wave_ranged := 1
## Minions notice enemies this close (metres) and leave the lane to fight them.
@export var minion_aggro_range := 5.0

@export_group("Targeting")
## A tapped target stays preferred until it is out of range or sight this long (seconds).
@export var override_leash_time := 2.0
## A windup survives the target drifting this far past attack range (metres).
@export var windup_range_slack := 0.5

@export_group("Relay and economy (later milestones)")
@export var first_relay_time := 60.0
@export var relay_interval := 70.0
@export var passive_gold_per_second := 2.0
