class_name ItemData
extends Resource
## One item card. Items are passive: buying one changes hero stats or adds a
## triggered effect (see Items). All values are test knobs, not final balance.

enum Tier { EARLY, MID, LATE }

@export var id: StringName = &""
@export var display_name := ""
## Short line for the card and tooltip.
@export var summary := ""
@export var cost := 300
@export var tier: Tier = Tier.EARLY

@export_group("Flat stats")
## Attack Power (basic-attack damage) and Ability Power (ability ratios).
@export var attack_power := 0.0
@export var ability_power := 0.0
@export var max_hp_flat := 0.0
## Armor cuts basic-attack damage taken, Ward cuts ability and item damage (points).
@export var armor := 0.0
@export var ward := 0.0
## Haste: shorter ability cooldowns (0.1 = cooldowns / 1.1).
@export var cooldown_haste := 0.0
## Ignore this share of the target's Armor (basics) or Ward (abilities).
@export var armor_pierce := 0.0
@export var ward_pierce := 0.0
## Archmage's Crown: all your Ability Power counts this much more (0.25 = +25%).
@export var ability_power_amp := 0.0

@export_group("Hero stats (multipliers add up: +8% and +8% = +16%)")
@export var move_speed_bonus := 0.0
@export var max_hp_bonus := 0.0
@export var attack_speed_bonus := 0.0
@export var range_bonus := 0.0

@export_group("Damage against")
## Extra damage of every kind against minions.
@export var trooper_damage_bonus := 0.0
## Extra damage of every kind against structures.
@export var structure_damage_bonus := 0.0

@export_group("Conditional stats")
## Extra move speed while out of hero combat (no hero damage dealt or taken for out_of_combat_delay).
@export var out_of_combat_speed_bonus := 0.0
## Extra attack speed while below half health.
@export var low_hp_attack_speed_bonus := 0.0

@export_group("Healing")
## Basic attacks heal this fraction of the damage they deal.
@export var lifesteal := 0.0
## After regen_delay seconds without enemy-hero damage, heal this fraction of max HP per second.
@export var regen_delay := 0.0
@export var regen_per_second := 0.0

@export_group("Triggered effects")
## Allied minions within siege_aura_radius of the holder deal this much more to structures.
@export var siege_aura_bonus := 0.0
@export var siege_aura_radius := 0.0
## Spark Band: after any cast, the next basic attack within spark_window adds spark_damage.
@export var spark_damage := 0.0
@export var spark_window := 0.0
## Thorncut: hits on the enemy hero cut its healing by wounds_amount for wounds_duration.
@export var wounds_amount := 0.0
@export var wounds_duration := 0.0
## Overcharge Gem: an ability hit of at least overcharge_threshold also deals
## overcharge_fraction of the target's max HP (heroes and minions).
@export var overcharge_threshold := 0.0
@export var overcharge_fraction := 0.0
## Stormcrown: ultimate cooldown cut (fraction), and storm_strikes strikes over
## storm_duration after the ultimate, each storm_fraction of the target's max HP.
@export var ult_cooldown_cut := 0.0
@export var storm_strikes := 0
@export var storm_duration := 0.0
@export var storm_fraction := 0.0
@export var storm_range := 0.0
## Reaper's Rhythm: every rhythm_every-th basic attack starts a Frenzy of rhythm_attacks
## attacks that heal rhythm_lifesteal of their damage and shred the enemy hero
## (rhythm_shred more damage taken from you for rhythm_shred_duration).
@export var rhythm_every := 0
@export var rhythm_attacks := 0
@export var rhythm_lifesteal := 0.0
@export var rhythm_shred := 0.0
@export var rhythm_shred_duration := 0.0
## Aegis Mirror: blocks the next enemy ability hit of at least aegis_threshold, then
## recharges for aegis_recharge seconds.
@export var aegis_threshold := 0.0
@export var aegis_recharge := 0.0
## Executioner's Edge: basic attacks on an enemy hero below execute_threshold of max HP
## deal execute_bonus more.
@export var execute_threshold := 0.0
@export var execute_bonus := 0.0
## Duelist's Crest: every crest_every-th basic attack on the enemy hero adds
## crest_fraction of its max HP.
@export var crest_every := 0
@export var crest_fraction := 0.0
## Warlord's Greatsword: basic attacks also hit enemies within splash_radius of the
## target for splash_fraction of the damage.
@export var splash_fraction := 0.0
@export var splash_radius := 0.0
## Runed Saber: an ability hit readies your next basic attack at once.
@export var ability_resets_attack := false
## Phoenix Feather: a killing blow leaves you at 1 HP with a shield worth
## phoenix_shield of max HP for phoenix_shield_time; recharges in phoenix_cooldown.
@export var phoenix_shield := 0.0
@export var phoenix_shield_time := 0.0
@export var phoenix_cooldown := 0.0
