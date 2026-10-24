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
	if kind == &"ability":
		mult += src.item_total(&"ability_damage_bonus")
	if target is MinionState:
		mult += src.item_total(&"trooper_damage_bonus")
	elif target is StructureState:
		mult += src.item_total(&"structure_damage_bonus")
	if target is HeroState and target.team != src.team and sim.time < target.shred_until:
		mult += target.shred_amount
	amount *= mult
	if kind == &"basic" and sim.time < src.spark_until:
		src.spark_until = 0.0
		var spark := src.item_with(&"spark_damage")
		if spark != null:
			amount += spark.spark_damage
			sim.emit_event(&"item_proc", {"hero": src.id, "item": spark.id, "target": target.id})
	return amount


## What the target hero's items take off (Aegis Mirror, ability resist).
static func incoming(sim: MatchSim, src: SimEntity, target: HeroState, amount: float, kind: StringName) -> float:
	if kind == &"basic" or not (src is HeroState) or src.team == target.team:
		return amount
	var aegis := target.item_with(&"aegis_threshold")
	if kind == &"ability" and aegis != null and amount >= aegis.aegis_threshold and sim.time >= target.aegis_ready_at:
		target.aegis_ready_at = sim.time + aegis.aegis_recharge
		sim.emit_event(&"item_proc", {"hero": target.id, "item": aegis.id, "target": target.id, "blocked": amount})
		return 0.0
	return amount * maxf(0.0, 1.0 - target.item_total(&"ability_resist"))


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
		var gem := src.item_with(&"overcharge_threshold")
		if gem != null and raw >= gem.overcharge_threshold and target.alive and not (target is StructureState):
			sim.emit_event(&"item_proc", {"hero": src.id, "item": gem.id, "target": target.id})
			sim.apply_damage(target, target.max_hp * gem.overcharge_fraction, src, &"item")


static func _after_basic(sim: MatchSim, src: HeroState, target: SimEntity, dealt: float) -> void:
	var steal := src.item_total(&"lifesteal")
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
