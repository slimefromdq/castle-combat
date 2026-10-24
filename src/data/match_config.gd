class_name MatchConfig
extends Resource
## Match-wide rules and timers. Values are GDD v0.1 seeds, not final balance.

@export var tick_rate := 30
## Joystick or stick input shorter than this counts as standing still.
@export var move_dead_zone := 0.15
@export var respawn_time := 7.0
@export var wave_interval := 12.0
@export var first_relay_time := 60.0
@export var relay_interval := 70.0
@export var passive_gold_per_second := 2.0
