extends TestCase
## Power spikes: level-up surge, the ult race, wave XP over passive XP, Masterworks.


func _item(id: StringName) -> ItemData:
	for item in MatchController.ITEMS:
		if item.id == id:
			return item
	return null


func _level_to(sim: MatchSim, h: HeroState, level: int) -> void:
	Leveling.gain(sim, h, float(sim.config.level_xp[level - 1]) - h.xp + 0.01)


## Blue standing on its healing pad (shop range), owning the given item.
func _at_shop_with(sim: MatchSim, id: StringName) -> HeroState:
	var blue := sim.heroes[0]
	place(blue, MatchSim.to_team_space(blue.team, sim.arena.heal_pad))
	blue.items.append(_item(id))
	blue.recompute_stats()
	return blue


func test_level_up_surge_heals_and_speeds_attacks() -> void:
	var sim := new_sim()
	var cfg := sim.config
	var blue := sim.heroes[0]
	blue.hp = blue.max_hp * 0.5
	var before := blue.hp
	var old_max := blue.max_hp
	var interval := blue.current_interval(sim.time)
	_level_to(sim, blue, 2)
	check(blue.max_hp > old_max, "max HP grows with the level")
	check_near(blue.hp, before + (blue.max_hp - old_max) + blue.max_hp * cfg.level_up_heal_fraction, 0.5, "level-up heals 15% (plus the new max HP)")
	blue._now = sim.time
	check_near(blue.current_interval(sim.time), interval / (1.0 + cfg.level_up_attack_speed), 0.001, "surge speeds up attacks")
	run_ticks(sim, int((cfg.level_up_surge_time + 0.2) / sim.dt))
	check_near(blue.current_interval(sim.time), interval, 0.001, "surge wears off")
	sim.apply_damage(blue, blue.hp * 10.0, sim.heroes[1])
	_level_to(sim, blue, 3)
	check(not blue.alive and blue.hp <= 0.0, "no surge while knocked out")


func test_ult_race_goes_to_the_first_hero_at_the_ult_level() -> void:
	var sim := new_sim()
	var won := []
	sim.sim_event.connect(func(type: StringName, data: Dictionary) -> void:
		if type == &"ult_race_won":
			won.append(data.team))
	_level_to(sim, sim.heroes[1], Leveling.ULT_LEVEL - 1)
	check(sim.ult_race_winner == -1, "nobody at the ult level yet")
	_level_to(sim, sim.heroes[1], Leveling.ULT_LEVEL)
	_level_to(sim, sim.heroes[0], Leveling.ULT_LEVEL)
	_level_to(sim, sim.heroes[0], Leveling.ULT_LEVEL + 1)
	check(sim.ult_race_winner == MatchSim.RED and won == [MatchSim.RED], "red won the race, announced once (got %s)" % [won])


func test_wave_xp_outweighs_passive_xp() -> void:
	var sim := new_sim()
	var cfg := sim.config
	var wave_xp: float = cfg.wave_melee * MatchController.MINIONS[&"melee"].xp_bounty + cfg.wave_ranged * MatchController.MINIONS[&"ranged"].xp_bounty
	var passive := cfg.passive_xp_per_second * cfg.wave_interval
	check(wave_xp > passive * 4.0, "one wave (%d XP) is worth far more than the passive XP over a wave interval (%d)" % [wave_xp, passive])


func test_masterwork_rules_and_boost() -> void:
	var sim := new_sim()
	var blue := _at_shop_with(sim, &"titan_core")
	var slot := blue.deck.find(_item(&"titan_core"))
	if slot < 0:
		blue.deck.append(_item(&"titan_core"))
		slot = blue.deck.size() - 1
	blue.gold = 5000.0
	_level_to(sim, blue, sim.config.masterwork_level - 1)
	check(Economy.masterwork_problem(sim, blue, slot).begins_with("Masterworks at level"), "locked before level 8")
	_level_to(sim, blue, sim.config.masterwork_level)
	var base := blue.item_total(&"ability_power")
	var cost := Economy.masterwork_cost(sim, _item(&"titan_core"))
	check(Economy.try_masterwork(sim, blue, slot), "Masterwork made")
	check_near(blue.gold, 5000.0 - cost, 0.01, "paid half the item's price")
	check_near(blue.item_total(&"ability_power"), base * (1.0 + sim.config.masterwork_bonus), 0.0001, "+25% Ability Power")
	check(not Economy.try_masterwork(sim, blue, slot), "only once per item")
	check(blue.owns(_item(&"titan_core")), "still owns the card")
	var gold := blue.gold
	check(Economy.try_sell(sim, blue, slot), "sold")
	check_near(blue.gold - gold, roundf((_item(&"titan_core").cost + cost) * sim.config.sell_refund_fraction), 0.01, "refund covers the Masterwork too")
	check(blue.masterworks.is_empty(), "Masterwork gone with the item")


func test_masterwork_boosts_triggered_effects() -> void:
	var sim := new_sim()
	var blue := _at_shop_with(sim, &"stormcrown")
	var crown := _item(&"stormcrown")
	var original := crown.storm_fraction
	var slot := blue.deck.find(crown)
	if slot < 0:
		blue.deck.append(crown)
		slot = blue.deck.size() - 1
	blue.gold = 5000.0
	_level_to(sim, blue, sim.config.masterwork_level)
	place(blue, Vector2(0, 2))
	check(Economy.masterwork_problem(sim, blue, slot) == "shop at your tower or base", "only at the shop")
	place(blue, MatchSim.to_team_space(blue.team, sim.arena.heal_pad))
	Economy.try_masterwork(sim, blue, slot)
	var it := blue.item_with(&"storm_fraction")
	check_near(it.storm_fraction, crown.storm_fraction * 1.25, 0.0001, "storm strikes hit 25% harder")
	check(it.storm_strikes == crown.storm_strikes and it.storm_duration == crown.storm_duration, "counts and timings unchanged")
	check_near(crown.storm_fraction, original, 0.0, "the shared item resource is untouched")
