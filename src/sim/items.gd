class_name Items
## Item effects beyond plain stats. Damage comes in three kinds:
##   &"basic"   basic attacks (and Spark Band's bonus riding on one),
##   &"ability" hero abilities,
##   &"item"    damage from item effects (storm strikes, Overcharge).
## Ability resist cuts both "ability" and "item" damage. Only "basic" and "ability"
## hits trigger on-hit effects, so item damage never chains into more item damage.


## Bonuses the attacking hero's items add (and Spark Band, and shred on the target).
static func outgoing(sim: MatchSim, src: HeroState, target: SimEntity, amount: float, kind: StringName) -> float:
	var mult := 1.0
	if sim.time < src.tarot_swords_until:
		mult += sim.config.tarot_swords_bonus
	if src.moon_at(sim.time) == HeroState.MOON_WAXING:
		mult += sim.config.moon_waxing_damage
	if kind == &"ability":
		if sim.time < src.power_until:
			mult += src.power_bonus
	if target is MinionState:
		mult += src.item_total(&"trooper_damage_bonus")
	elif target is StructureState:
		mult += src.item_total(&"structure_damage_bonus")
	var enemy_hero := target is HeroState and target.team != src.team
	if enemy_hero and sim.time < target.shred_until:
		mult += target.shred_amount
	if enemy_hero and kind == &"basic":
		var edge := src.item_with(&"execute_threshold")
		if edge != null and target.hp < target.max_hp * edge.execute_threshold:
			mult += edge.execute_bonus
	amount *= mult
	if enemy_hero and kind == &"basic":
		var crest := src.item_with(&"crest_every")
		if crest != null:
			src.crest_count += 1
			if src.crest_count >= crest.crest_every:
				src.crest_count = 0
				amount += target.max_hp * crest.crest_fraction
				sim.emit_event(&"item_proc", {"hero": src.id, "item": crest.id, "target": target.id})
	if kind == &"basic" and sim.time < src.spark_until:
		src.spark_until = 0.0
		var spark := src.item_with(&"spark_damage")
		if spark != null:
			amount += spark.spark_damage
			sim.emit_event(&"item_proc", {"hero": src.id, "item": spark.id, "target": target.id})
	return amount


## What the target hero's defences take off: Armor against every basic attack (troopers
## and towers too), Aegis Mirror and Ward against the enemy hero's abilities and items.
static func incoming(sim: MatchSim, src: SimEntity, target: HeroState, amount: float, kind: StringName) -> float:
	if kind == &"basic":
		var pierce := (src as HeroState).armor_pierce if src is HeroState else 0.0
		return HeroStats.mitigate(amount, target.effective_armor(), pierce)
	if not (src is HeroState) or src.team == target.team:
		return amount
	var aegis := target.item_with(&"aegis_threshold")
	if kind == &"ability" and aegis != null and amount >= aegis.aegis_threshold and sim.time >= target.aegis_ready_at:
		target.aegis_ready_at = sim.time + aegis.aegis_recharge
		sim.emit_event(&"item_proc", {"hero": target.id, "item": aegis.id, "target": target.id, "blocked": amount})
		return 0.0
	return HeroStats.mitigate(amount, target.ward, (src as HeroState).ward_pierce)


## After a hero's hit lands. dealt = HP actually removed, raw = damage before the
## target's defences (Overcharge checks raw so Warding Cloak doesn't hide it).
static func after_hit(sim: MatchSim, src: HeroState, target: SimEntity, dealt: float, raw: float, kind: StringName) -> void:
	if kind == &"item" or not src.alive:
		return
	if target is HeroState and target.team != src.team:
		var thorn := src.item_with(&"wounds_amount")
		if thorn != null:
			target.wounds_amount = maxf(thorn.wounds_amount, target.wounds_amount if sim.time < target.wounds_until else 0.0)
			target.wounds_until = sim.time + thorn.wounds_duration
	if kind == &"basic":
		_after_basic(sim, src, target, dealt)
	elif kind == &"ability":
		var saber := src.item_with(&"ability_resets_attack")
		if saber != null and target.team != src.team and not src.is_winding_up():
			src.cooldown_left = 0.0
		var gem := src.item_with(&"overcharge_threshold")
		if gem != null and raw >= gem.overcharge_threshold and target.alive and not (target is StructureState):
			sim.emit_event(&"item_proc", {"hero": src.id, "item": gem.id, "target": target.id})
			sim.apply_damage(target, target.max_hp * gem.overcharge_fraction, src, &"item")


static func _after_basic(sim: MatchSim, src: HeroState, target: SimEntity, dealt: float) -> void:
	var sword := src.item_with(&"splash_fraction")
	if sword != null and dealt > 0.0 and not (target is StructureState):
		for e in Abilities.enemies_near(sim, src, target.pos, sword.splash_radius):
			if e != target:
				sim.apply_damage(e, dealt * sword.splash_fraction, src, &"item")
	var steal := src.item_total(&"lifesteal") + hero_lifesteal(src)
	if src.moon_at(sim.time) == HeroState.MOON_WANING:
		steal += sim.config.moon_waning_lifesteal
	var rhythm := src.item_with(&"rhythm_every")
	if rhythm != null:
		if src.frenzy_left > 0:
			src.frenzy_left -= 1
			steal += rhythm.rhythm_lifesteal
			if target is HeroState and target.alive:
				target.shred_amount = rhythm.rhythm_shred
				target.shred_until = sim.time + rhythm.rhythm_shred_duration
		else:
			src.rhythm_count += 1
			if src.rhythm_count >= rhythm.rhythm_every:
				src.rhythm_count = 0
				src.frenzy_left = rhythm.rhythm_attacks
				sim.emit_event(&"item_proc", {"hero": src.id, "item": rhythm.id, "target": src.id})
	if steal > 0.0 and dealt > 0.0:
		sim.heal(src, dealt * steal)


## The hero's own lifesteal (Poppet): base, plus her passives.
static func hero_lifesteal(h: HeroState) -> float:
	var steal := h.data.lifesteal + h.passive_special(&"lifesteal")
	var re := h.passive_special(&"restitched")
	if re > 0.0 and steal > 0.0:
		for p in h.owned_passives():
			if p.special == &"restitched" and h.hp < h.max_hp * p.special_value_2:
				steal *= re
	return steal


## Phoenix Feather: a blow that would knock the hero out leaves 1 HP and a shield
## instead, then the feather recharges. Returns the damage that still lands.
static func cheat_death(sim: MatchSim, h: HeroState, amount: float) -> float:
	if amount < h.hp or sim.time < h.phoenix_ready_at:
		return amount
	var feather := h.item_with(&"phoenix_shield")
	if feather == null:
		return amount
	h.phoenix_ready_at = sim.time + feather.phoenix_cooldown
	h.shield_hp = maxf(h.shield_hp if sim.time < h.shield_until else 0.0, h.max_hp * feather.phoenix_shield)
	h.shield_until = sim.time + feather.phoenix_shield_time
	sim.emit_event(&"item_proc", {"hero": h.id, "item": feather.id, "target": h.id})
	return maxf(0.0, h.hp - 1.0)


## A hero cast an ability: arm Spark Band; an ultimate starts Stormcrown's storm.
static func on_cast(sim: MatchSim, h: HeroState, slot: int) -> void:
	var spark := h.item_with(&"spark_damage")
	if spark != null:
		h.spark_until = sim.time + spark.spark_window
	var crown := h.item_with(&"storm_strikes")
	if slot == 2 and crown != null:
		h.storm_item = crown
		h.storm_left = crown.storm_strikes
		h.storm_next = sim.time + crown.storm_duration / crown.storm_strikes


## Per-tick item upkeep: regeneration and storm strikes.
static func tick(sim: MatchSim) -> void:
	for h in sim.heroes:
		if not h.alive:
			continue
		var regen := h.item_with(&"regen_per_second")
		if regen != null and sim.time - h.last_hero_damage_time >= regen.regen_delay:
			sim.heal(h, h.max_hp * regen.regen_per_second * sim.dt)
		if h.storm_left > 0 and sim.time + 0.0001 >= h.storm_next:
			var crown := h.storm_item
			h.storm_left -= 1
			h.storm_next += crown.storm_duration / crown.storm_strikes
			var t := Abilities.aim_any(sim, h, crown.storm_range)
			if t != null and not (t is StructureState):
				sim.emit_event(&"storm_strike", {"hero": h.id, "target": t.id})
				sim.apply_damage(t, t.max_hp * crown.storm_fraction, h, &"item")


## What a Masterwork boosts: every stat bonus and effect strength. Thresholds, timings,
## ranges and counts stay as they are.
const MASTERWORK_FIELDS: Array[StringName] = [
	&"attack_power", &"ability_power", &"max_hp_flat", &"armor", &"ward", &"cooldown_haste",
	&"move_speed_bonus", &"max_hp_bonus", &"attack_speed_bonus", &"range_bonus",
	&"trooper_damage_bonus", &"structure_damage_bonus", &"splash_fraction", &"phoenix_shield",
	&"out_of_combat_speed_bonus", &"low_hp_attack_speed_bonus", &"lifesteal", &"regen_per_second",
	&"siege_aura_bonus", &"spark_damage", &"wounds_amount", &"overcharge_fraction",
	&"ult_cooldown_cut", &"storm_fraction", &"rhythm_lifesteal", &"rhythm_shred",
	&"execute_bonus", &"crest_fraction",
]


## A boosted copy of an item for a Masterwork (same id, so events and lookups still match).
static func masterwork_copy(item: ItemData, bonus: float) -> ItemData:
	var copy: ItemData = item.duplicate()
	for f in MASTERWORK_FIELDS:
		copy.set(f, float(copy.get(f)) * (1.0 + bonus))
	return copy
