class_name MatchConfig
extends Resource
## Match-wide rules and timers. Values are GDD v0.1 seeds, not final balance.

@export var tick_rate := 30
## Joystick or stick input shorter than this counts as standing still.
@export var move_dead_zone := 0.15
## Base respawn time; it grows over the match (see Pacing: respawn).
@export var respawn_time := 4.0
## Heroes on their own healing pad (ArenaData.heal_pad, behind the Core) heal this
## fraction of max HP per second, until their Guardian falls.
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

@export_group("Levels")
## Total XP needed to reach each level (index 0 = level 1). Abilities unlock at 1, 3, 5;
## perks at 2, 4, 6 (the last is the capstone).
@export var level_xp: Array[int] = [0, 120, 300, 550, 850, 1200]
@export var passive_xp_per_second := 1.0
## XP to the opposing hero for a knockout, plus this much per level the victim is above them.
@export var ko_xp := 90.0
@export var ko_xp_per_level_above := 25.0
## Catch-up: a hero behind the enemy hero in level gets this much extra XP per level behind.
@export var catch_up_per_level := 0.25

@export_group("Economy")
@export var passive_gold_per_second := 2.0
@export var starting_gold := 0.0
## Paid to the opposing hero whenever a hero is knocked out, whoever landed the blow.
@export var hero_ko_gold := 50.0
## A dying enemy minion pays its bounty to your hero if you are this close to it (metres),
## whoever killed it. Landing the killing blow from farther away still pays.
@export var minion_gold_radius := 6.0
## Denies: a hero may tap and attack its own minion once it is at or below this fraction
## of max HP. If the hero lands the killing blow, the enemy collects only deny_gold_fraction
## of the bounty (by the usual nearby rule).
@export var deny_hp_fraction := 0.5
@export var deny_gold_fraction := 0.5
## Items in a pre-match deck, and how many of them a hero may own at once.
@export var deck_size := 8
@export var max_items := 3
## Selling an item pays back this fraction of its price.
@export var sell_refund_fraction := 0.5

@export_group("Pacing: gold")
## All gold (passive, minions, knockouts) grows by gold_ramp_per_minute for every
## minute after gold_ramp_start seconds: +8%/min means x1.6 at 10:00.
@export var gold_ramp_start := 150.0
@export var gold_ramp_per_minute := 0.08

@export_group("Pacing: Relay rewards")
## A delivery pays the carrier relay_gold_base + relay_gold_per_activation x the number
## of Relays before it, and queues one more siege minion every relay_siege_every
## activations (at most relay_siege_max).
@export var relay_gold_base := 60.0
@export var relay_gold_per_activation := 60.0
@export var relay_siege_every := 2
@export var relay_siege_max := 3

@export_group("Pacing: structures")
## Structure resist starts at StructureData.resist_start and falls in a straight line to
## resist_end between resist_decay_start and resist_end_time seconds. Damage taken is
## x (1 - resist), so -30% resist means +30% damage.
@export var resist_decay_start := 120.0
@export var resist_end_time := 720.0
@export var resist_end := -0.3
## Gold a hero earns for each point of its damage that structure resist soaks up.
@export var resist_gold_per_damage := 0.3

@export_group("Pacing: minions")
## Minions spawned after minion_scale_start grow by these fractions per minute.
@export var minion_scale_start := 120.0
@export var minion_hp_per_minute := 0.025
@export var minion_damage_per_minute := 0.02
## Power minions: a team's minions after the enemy Guardian falls.
@export var power_hp_mult := 1.6
@export var power_damage_mult := 1.3
@export var power_speed_mult := 1.15

@export_group("Pacing: respawn")
## Respawn = respawn_time + respawn_per_minute x minutes + respawn_per_death x earlier
## knockouts, at most respawn_max. If your Guardian falls while you are down, the time
## left is multiplied by guardian_fall_respawn_mult.
@export var respawn_per_minute := 0.6
@export var respawn_per_death := 1.0
@export var respawn_max := 30.0
@export var guardian_fall_respawn_mult := 0.4

@export_group("Pacing: overtime")
## Overtime starts at overtime_time if no Guardian has fallen, else at overtime_late_time.
## Structures then take more and deal less damage, new minions are tankier, and
## respawns are longer.
@export var overtime_time := 600.0
@export var overtime_late_time := 840.0
@export var overtime_structure_damage_taken := 1.4
@export var overtime_structure_damage_dealt := 0.5
@export var overtime_minion_hp_mult := 1.4
@export var overtime_respawn_mult := 1.5
