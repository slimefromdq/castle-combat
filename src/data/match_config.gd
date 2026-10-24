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

@export_group("Hero-hit aggro")
## Replaces the GDD's fixed priorities with a "call for help": when a hero's attack hits
## the enemy hero, the victim's minions near the attacker drop what they are doing and go
## for the attacker, and so does any victim tower whose range the attacker stands in.
## Enemy minions this close (metres) to the attacker switch to it.
@export var minion_call_radius := 6.5
## How long a called minion stays on the attacker (seconds, refreshed by every hit).
@export var minion_call_duration := 3.0
## A called minion gives up once the attacker is farther than this (metres).
@export var minion_call_leash := 9.0
## How long a called tower stays on the attacker while it is in range (seconds, refreshed).
@export var tower_call_duration := 4.0
## Damage multiplier on tower shots at a hero who called it.
@export var tower_call_damage_mult := 1.5

@export_group("Relay")
@export var first_relay_time := 60.0
## Seconds from a delivery or expiry to the next Relay.
@export var relay_interval := 70.0
## On-screen warning before a Relay appears (seconds).
@export var relay_warning_time := 10.0
## Pocket index (into ArenaData.pockets) of the first pickup; later Relays alternate.
@export var relay_first_pocket := 0
@export var relay_pickup_radius := 1.3
@export var relay_pickup_time := 0.5
@export var relay_carrier_speed_mult := 0.9
## This many enemy-hero hits on the carrier within the window force a drop.
@export var relay_intercept_hits := 2
@export var relay_intercept_window := 3.0
@export var relay_drop_lockout := 0.75
## A dropped Relay left alone this long goes back to its pickup spot.
@export var relay_drop_return_time := 8.0
@export var relay_deliver_time := 0.8
## A Relay nobody picks up disappears after this long (seconds).
@export var relay_expire_time := 25.0
## Expiry timer after a dropped Relay returns home, so it never vanishes without warning.
@export var relay_return_expire_time := 12.0

@export_group("Economy")
@export var passive_gold_per_second := 2.0
@export var starting_gold := 0.0
## Paid to the opposing hero whenever a hero is knocked out, whoever landed the blow.
@export var hero_ko_gold := 50.0
## A dying enemy minion pays its bounty to your hero if you are this close to it (metres),
## whoever killed it. Landing the killing blow from farther away still pays.
@export var minion_gold_radius := 6.0
## Items in a pre-match deck, and how many of them a hero may own at once.
@export var deck_size := 6
@export var max_items := 3
