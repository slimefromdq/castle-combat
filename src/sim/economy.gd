class_name Economy
## Gold and items (GDD 8): passive income, last-hit and knockout gold, deck rules,
## purchases and item effects. Gold never goes negative; a hero owns at most
## max_items distinct items, all from its six-card deck.


## A deck is exactly deck_size distinct, non-null items from the pool.
static func is_valid_deck(deck: Array, pool: Array, size: int) -> bool:
	if deck.size() != size:
		return false
	var seen := {}
	for item in deck:
		if item == null or not pool.has(item) or seen.has(item):
			return false
		seen[item] = true
	return true


static func tick(sim: MatchSim) -> void:
	var cfg := sim.config
	for h in sim.heroes:
		h.gold += cfg.passive_gold_per_second * sim.dt
		_regen(sim, h)


## Why a purchase would fail, or "" if it is allowed.
static func buy_problem(sim: MatchSim, hero: HeroState, slot: int) -> String:
	if slot < 0 or slot >= hero.deck.size():
		return "no such card"
	var item := hero.deck[slot]
	if hero.owns(item):
		return "already owned"
	if hero.items.size() >= sim.config.max_items:
		return "item slots full"
	if hero.gold + 0.0001 < item.cost:
		return "not enough gold"
	return ""


static func try_buy(sim: MatchSim, hero: HeroState, slot: int) -> bool:
	if buy_problem(sim, hero, slot) != "":
		return false
	var item := hero.deck[slot]
	hero.gold = maxf(0.0, hero.gold - item.cost)
	hero.items.append(item)
	hero.recompute_stats()
	sim.emit_event(&"item_bought", {"hero": hero.id, "team": hero.team, "item": item.id, "slot": slot})
	return true


## Kill rewards. A minion's bounty goes to the enemy hero if it is within
## minion_gold_radius of the minion (whoever killed it) or landed the killing blow.
## Knockout gold goes to the opposing hero whoever finished the knockout.
static func on_kill(sim: MatchSim, target: SimEntity, source: SimEntity) -> void:
	if target is MinionState:
		var hero := sim.heroes[1 - target.team]
		var denied := source is HeroState and source.team == target.team
		if denied:
			sim.emit_event(&"minion_denied", {"id": target.id, "team": target.team, "hero": source.id})
		if not hero.alive:
			return
		var share: float = sim.config.deny_gold_fraction if denied else 1.0
		if source == hero:
			_award(sim, hero, target.data.gold_bounty * share, &"last_hit")
			Leveling.gain(sim, hero, target.data.xp_bounty * share)
		elif hero.pos.distance_to(target.pos) <= sim.config.minion_gold_radius:
			_award(sim, hero, target.data.gold_bounty * share, &"denied" if denied else &"nearby")
			Leveling.gain(sim, hero, target.data.xp_bounty * share)
	elif target is HeroState:
		_award(sim, sim.heroes[1 - target.team], sim.config.hero_ko_gold, &"knockout")


## Siege Banner: an allied hero's aura boosts a minion's damage to structures.
static func minion_structure_mult(sim: MatchSim, m: MinionState) -> float:
	var bonus := 0.0
	var h := sim.heroes[m.team]
	if h.alive:
		for item in h.items:
			if item.siege_aura_bonus > 0.0 and h.pos.distance_to(m.pos) <= item.siege_aura_radius:
				bonus += item.siege_aura_bonus
	return 1.0 + bonus


static func _award(sim: MatchSim, hero: HeroState, amount: float, reason: StringName) -> void:
	if amount <= 0.0:
		return
	hero.gold += amount
	sim.emit_event(&"gold_awarded", {"hero": hero.id, "team": hero.team, "amount": amount, "reason": reason})


## Recovery Sigil: heal over time once the enemy hero has left you alone for a while.
static func _regen(sim: MatchSim, h: HeroState) -> void:
	if not h.alive or h.hp >= h.max_hp:
		return
	for item in h.items:
		if item.regen_per_second > 0.0 and sim.time - h.last_hero_damage_time >= item.regen_delay:
			h.hp = minf(h.max_hp, h.hp + h.max_hp * item.regen_per_second * sim.dt)
