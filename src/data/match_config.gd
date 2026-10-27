class_name MatchConfig
extends Resource
## Match-wide rules and timers. Values are GDD v0.1 seeds, not final balance.

@export var tick_rate := 30
## Joystick or stick input shorter than this counts as standing still.
@export var move_dead_zone := 0.15
## Base respawn time; it grows over the match (see Pacing: respawn).
@export var respawn_time := 4.0
## Heroes on their own healing pad (ArenaData.heal_pad, behind the Core) heal this
## fraction of max HP per second, all match (the pad sits behind the Core).
@export var base_heal_per_second := 0.12

@export_group("Waves")
@export var first_wave_time := 3.0
@export var wave_interval := 12.0
@export var wave_melee := 2
@export var wave_ranged := 1
## Every special_wave_every-th wave adds a special trooper (Sapper, then Shieldbearer).
@export var special_wave_every := 4
## Minions notice enemies this close (metres) and leave the lane to fight them.
@export var minion_aggro_range := 5.0

@export_group("Bushes")
## A hero in a bush is hidden unless the enemy hero is in the same bush or this close.
@export var bush_reveal_radius := 2.2
## Attacking, casting, or dealing or taking hero damage reveals a hidden hero this long.
@export var bush_reveal_time := 1.5

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
@export var relay_carrier_speed_mult := 1.08
## This many enemy-hero hits on the carrier within the window force a drop.
@export var relay_intercept_hits := 1
@export var relay_intercept_window := 3.0
## After a drop nobody can pick the Relay up for this long.
@export var relay_drop_lockout := 3.0
## A dropped Relay left alone this long goes back to its pickup spot.
@export var relay_drop_return_time := 8.0
## Fought over too long: the Relay fizzles out on its relay_fizzle_knocks-th knock-off, or
## relay_fizzle_time seconds after the first knock-off (warning relay_fizzle_warning before).
@export var relay_fizzle_knocks := 3
@export var relay_fizzle_time := 20.0
@export var relay_fizzle_warning := 5.0
@export var relay_deliver_time := 0.8
## A Relay nobody picks up disappears after this long (seconds).
@export var relay_expire_time := 25.0
## Expiry timer after a dropped Relay returns home, so it never vanishes without warning.
@export var relay_return_expire_time := 12.0

@export_group("Pickups")
## Walk-over coins and sparks (ArenaData.pickups, see PickupController). All appear at
## pickup_first_time; a taken one comes back pickup_respawn_time later, as a coin or a
## spark (pickup_spark_chance). Coins pay pickup_gold, sparks pickup_xp.
@export var pickup_first_time := 30.0
@export var pickup_respawn_time := 35.0
@export var pickup_radius := 0.7
@export var pickup_spark_chance := 0.5
@export var pickup_gold := 12.0
@export var pickup_xp := 18.0

@export_group("Neutral camps")
## Pwees (see NeutralCamps): first appear at camp_first_time, come back camp_respawn_time
## after dying. A full kill is worth camp_gold and camp_xp; hits pay up to
## camp_damage_share of that, the killer gets the rest. A Pwee chases its attacker until
## they leave camp_leash metres of its home or stop hitting it for camp_reset_time, then
## walks home, healing camp_regen_per_second of its max HP per second.
@export var camp_first_time := 60.0
@export var camp_respawn_time := 60.0
@export var camp_gold := 80.0
@export var camp_xp := 110.0
@export var camp_damage_share := 0.5
@export var camp_leash := 8.0
@export var camp_reset_time := 5.0
@export var camp_regen_per_second := 0.25

@export_group("Phase 2")
## Phase 2 starts when the first Outer Tower falls, or at phase_two_time at the latest.
## It unlocks the moon buffs from Pwees and the long Relay drop.
@export var phase_two_time := 360.0
## Killing a Pwee in phase 2 gives a moon buff for moon_time seconds (ends on death).
## The Pwee on your own half gives Waxing: more damage and faster cooldowns.
## The one on the enemy's half gives Waning: lifesteal on basic attacks and less damage
## taken from the enemy hero.
@export var moon_time := 75.0
@export var moon_waxing_damage := 0.12
@export var moon_waxing_haste := 0.15
@export var moon_waning_lifesteal := 0.15
@export var moon_waning_guard := 0.10
## The long Relay drop (phase 2): a square of this size deep in the enemy half
## (ArenaData.long_drop). Delivering there pays relay_long_gold_mult x the gold and
## relay_long_extra_siege more siege minions.
@export var relay_long_size := 3.2
@export var relay_long_gold_mult := 1.75
@export var relay_long_extra_siege := 1

@export_group("Tarot altar")
## See TarotAltar.
@export var tarot_first_time := 120.0
@export var tarot_interval := 90.0
@export var tarot_expire_time := 40.0
@export var tarot_radius := 1.0
@export var tarot_take_time := 1.0
@export var tarot_pick_time := 8.0
@export var tarot_buff_time := 60.0
@export var tarot_swords_bonus := 0.15
@export var tarot_cups_heal := 0.25
@export var tarot_pentacles_gold := 90.0
@export var tarot_wands_haste := 0.25

@export_group("Honey fruit")
## Fruit bushes out on the diamond (see Fruits): stand on a ripe one for fruit_eat_time
## (taking damage stops you) to heal fruit_heal of max HP over fruit_heal_time seconds.
## Taking damage while the heal runs ends it. It ripens again fruit_respawn_time later.
@export var fruit_first_time := 90.0
@export var fruit_respawn_time := 60.0
@export var fruit_radius := 0.9
@export var fruit_eat_time := 0.8
@export var fruit_heal := 0.12
@export var fruit_heal_time := 3.0

@export_group("Levels")
## Total XP needed to reach each level (index 0 = level 1). See Leveling for what each
## level unlocks (abilities 1, 3, 6; perks 2, 4, 7; passives 3, 8).
@export var level_xp: Array[int] = [0, 110, 260, 470, 760, 1200, 1650, 2150, 2700]
@export var passive_xp_per_second := 0.35
## XP to the opposing hero for a knockout, plus this much per level the victim is above them.
@export var ko_xp := 90.0
@export var ko_xp_per_level_above := 25.0
## Catch-up: a hero behind the enemy hero in level gets this much extra XP per level behind.
@export var catch_up_per_level := 0.25
## At levels 2, 4 and 7 you pick one of two perks. Unpicked after this long, the first
## option is taken for you.
@export var perk_auto_pick_time := 12.0

@export_group("Power spikes")
## Every level-up heals this fraction of max HP and gives level_up_attack_speed more
## attack speed for level_up_surge_time seconds: fight right as you level.
@export var level_up_heal_fraction := 0.15
@export var level_up_attack_speed := 0.3
@export var level_up_surge_time := 3.0
## From masterwork_level, a hero can pay masterwork_cost_fraction of an owned item's
## price to make it a Masterwork: masterwork_bonus more of its stats and effects.
@export var masterwork_level := 8
@export var masterwork_cost_fraction := 0.5
@export var masterwork_bonus := 0.25
## Siege scrolls (from siege_scroll_level): pay to add a siege trooper to your next wave.
@export var siege_scroll_level := 7
## The price rises with each scroll a hero buys; at most siege_scroll_max wait at once.
@export var siege_scroll_cost := 350.0
@export var siege_scroll_cost_step := 100.0
@export var siege_scroll_max := 2

@export_group("Economy")
@export var passive_gold_per_second := 2.0
@export var starting_gold := 0.0
## Paid to the opposing hero whenever a hero is knocked out, whoever landed the blow.
@export var hero_ko_gold := 50.0
## A dying enemy minion pays its bounty to your hero if you are this close to it (metres),
## whoever killed it. Landing the killing blow from farther away still pays.
@export var minion_gold_radius := 6.0
## Landing the killing blow on an enemy trooper pays this much more than standing near it.
@export var last_hit_bonus := 0.15
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
## Buying and selling only work this close (metres, from the edge) to your front
## structure, or to your Core (your base).
@export var shop_radius := 8.0
## The denier collects this fraction of a denied minion's bounty (gold only).
@export var deny_self_gold_fraction := 0.4

@export_group("Sprint")
## Move this long in roughly one direction, out of combat, to start sprinting.
@export var sprint_build_time := 2.0
@export var sprint_speed_mult := 1.334
## Turning more than this (degrees) away from your running direction resets the build-up.
@export var sprint_turn_degrees := 50.0
## How fast the running direction follows gentle curves (0..1 per tick).
@export var sprint_turn_follow := 0.08
## No sprint build-up for this long after hero combat or after taking any damage.
@export var sprint_combat_delay := 3.0

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
@export var resist_decay_start := 150.0
@export var resist_end_time := 600.0
@export var resist_end := -0.3
## Gold a hero earns for each point of its damage that structure resist soaks up.
@export var resist_gold_per_damage := 0.15

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
## When a Guardian falls, its Core takes no damage for this long (breathing room).
@export var core_immunity_time := 8.0

@export_group("Core last stand")
## Lucy's last stand: while the Core's own hero is alive and stands within
## core_guard_radius of it, on the side facing the enemy (a half circle in front, so
## the heal pad behind the Core doesn't count), the Core takes no damage. Overtime
## turns this off.
@export var core_guard_radius := 8.0
## Core stun: once its Guardian has fallen, whenever an enemy unit is within
## core_stun_radius and the stun is ready, the Core winds up for core_stun_windup
## seconds (a growing ring), then stuns every enemy still inside: heroes for
## core_stun_hero, troopers for core_stun_minion. No damage. Ready again
## core_stun_interval seconds after it lands.
@export var core_stun_radius := 8.0
@export var core_stun_windup := 2.5
@export var core_stun_hero := 1.0
@export var core_stun_minion := 2.0
@export var core_stun_interval := 18.0

@export_group("Pacing: overtime")
## Overtime starts at overtime_time if no Guardian has fallen, else at overtime_late_time.
## Structures then take more and deal less damage, new minions are tankier, and
## respawns are longer.
@export var overtime_time := 660.0
@export var overtime_late_time := 900.0
@export var overtime_structure_damage_taken := 1.4
@export var overtime_structure_damage_dealt := 0.5
@export var overtime_minion_hp_mult := 1.4
@export var overtime_respawn_mult := 1.5
