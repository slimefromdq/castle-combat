extends TestCase
## The stat model: Attack Power vs Ability Power, level growth, Armor and Ward,
## Haste, and the round-2 stat items.


func _item(id: StringName) -> ItemData:
	for item in MatchController.ITEMS:
		if item.id == id:
			return item
	return null


func _give(h: HeroState, id: StringName) -> void:
	h.items.append(_item(id))
	h.recompute_stats()
	h.hp = h.max_hp


func _sim(blue := 0, red := 1) -> MatchSim:
	var sim := new_sim(false, blue, red)
	place(sim.heroes[0], Vector2(0, -2))
	place(sim.heroes[1], Vector2(0, 2))
	return sim


func test_attack_and_ability_power_stay_apart() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	var atk := blue.attack_damage
	_give(blue, &"ink_quill")
	check_near(blue.attack_damage, atk, 0.01, "AP items leave basic attacks alone")
	check_near(blue.ability_power, 20.0, 0.01, "Ink Quill +20 AP")
	_give(blue, &"training_blade")
	check_near(blue.attack_damage, atk + 10.0, 0.01, "Training Blade +10 ATK")
	check_near(blue.ability_power, 20.0, 0.01, "ATK items leave Ability Power alone")


func test_level_growth_follows_the_lean() -> void:
	var sim := _sim(2, 0)  # Jack vs Avery
	var jack := sim.heroes[0]
	var avery := sim.heroes[1]
	Leveling.gain(sim, jack, 5000.0)
	Leveling.gain(sim, avery, 5000.0)
	check_near(jack.ability_power, 5 * jack.data.ability_power_per_level, 0.01, "Jack grows Ability Power")
	check_near(jack.attack_damage, jack.data.attack_damage, 0.01, "but not Attack Power")
	check_near(avery.attack_damage, avery.data.attack_damage + 5 * avery.data.attack_power_per_level, 0.01, "Avery grows Attack Power")
	check_near(avery.max_hp, avery.data.max_hp + 5 * avery.data.hp_per_level, 0.01, "and health")


func test_armor_cuts_basics_and_ward_cuts_abilities() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_give(red, &"bulwark_plate")
	var hp := red.hp
	sim.apply_damage(red, 100.0, blue, &"basic")
	check_near(hp - red.hp, 100.0 * 100.0 / 120.0, 0.01, "20 Armor cuts basics by 1/6")
	hp = red.hp
	sim.apply_damage(red, 100.0, blue, &"ability")
	check_near(hp - red.hp, 100.0, 0.01, "Armor does nothing against abilities")
	_give(blue, &"sunder_pick")
	hp = red.hp
	sim.apply_damage(red, 100.0, blue, &"basic")
	check_near(hp - red.hp, 100.0 * 100.0 / (100.0 + 20.0 * 0.65), 0.01, "Sunder Pick ignores 35% of it")
	var m := sim.spawn_minion(melee(), MatchSim.BLUE, red.pos + Vector2(1, 0))
	hp = red.hp
	sim.apply_damage(red, 30.0, m, &"basic")
	check_near(hp - red.hp, 30.0 * 100.0 / 120.0, 0.01, "Armor works on trooper hits too")


func test_haste_shortens_cooldowns() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	var cd := blue.ability_cooldown(0)
	_give(blue, &"hourglass_charm")
	check_near(blue.ability_cooldown(0), cd / 1.1, 0.01, "+10% Haste")


func test_archmages_crown_amplifies_all_ap() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	_give(blue, &"ink_quill")
	_give(blue, &"archmages_crown")
	check_near(blue.ability_power, (20.0 + 90.0) * 1.25, 0.01, "+25% on all Ability Power")


func test_greatsword_splashes() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_give(blue, &"warlords_greatsword")
	var m := sim.spawn_minion(melee(), MatchSim.RED, red.pos + Vector2(1.0, 0))
	var hp := m.hp
	sim.apply_damage(red, 100.0, blue, &"basic")
	check(m.hp < hp, "the trooper next to the hero took splash")


func test_runed_saber_readies_the_next_attack() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_give(blue, &"runed_saber")
	blue.cooldown_left = 0.8
	sim.apply_damage(red, 50.0, blue, &"ability")
	check_near(blue.cooldown_left, 0.0, 0.0001, "ability hit resets the basic attack")


func test_phoenix_feather_survives_once() -> void:
	var sim := _sim()
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_give(red, &"phoenix_feather")
	sim.apply_damage(red, red.max_hp * 2.0, blue, &"ability")
	check(red.alive and red.hp >= 1.0, "survives the killing blow")
	check(red.shield_hp > 0.0, "with a shield")
	red.shield_hp = 0.0
	sim.apply_damage(red, red.max_hp * 2.0, blue, &"ability")
	check(not red.alive, "but only once per recharge")


func test_stat_card_text() -> void:
	var t := StatCard.for_hero(MatchController.HEROES[2])
	check(t.contains("Ability Power") and t.contains("Attack Power"), "the card names both powers")
	var sim := _sim()
	check(StatCard.live(sim.heroes[0]).contains("ATK"), "the live line shows ATK")
