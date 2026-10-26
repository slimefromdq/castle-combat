class_name HeroStats
## The stat model shared by the sim and the stat card.
##   Attack Power (ATK): the damage of one basic attack.
##   Ability Power (AP): starts at 0; each ability adds ap_ratio x AP to its damage.
##   Armor cuts basic-attack damage taken, Ward cuts ability and item damage taken:
##   points, where 25 = 20% less, 50 = 33% less, 100 = 50% less.
##   Haste shortens cooldowns: 0.2 = cooldowns / 1.2.


## Base HP, ATK and AP for a hero at a level, before items and perks.
static func at_level(data: HeroData, level: int) -> Dictionary:
	var lv := maxi(0, level - 1)
	return {
		"hp": data.max_hp + data.hp_per_level * lv,
		"atk": data.attack_damage + data.attack_power_per_level * lv,
		"ap": data.ability_power_per_level * lv,
	}


## Damage left after Armor or Ward points (pierce = share of them ignored).
static func mitigate(amount: float, points: float, pierce := 0.0) -> float:
	var eff := maxf(0.0, points * (1.0 - pierce))
	return amount * 100.0 / (100.0 + eff)


## The share of damage that defence points cut, for the stat card (0.2 = 20% less).
static func cut(points: float) -> float:
	return 1.0 - 100.0 / (100.0 + maxf(0.0, points))


## Extra damage an ability gets from its caster's stats.
static func ability_bonus(h: HeroState, a: AbilityData) -> float:
	return a.ap_ratio * h.ability_power + a.atk_ratio * h.attack_damage + a.hp_ratio * h.max_hp


## Extra shield or heal an ability gets from Ability Power.
static func support_bonus(h: HeroState, a: AbilityData) -> float:
	return a.heal_ap_ratio * h.ability_power
