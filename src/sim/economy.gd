class_name Economy
## Gold and items (GDD 8): passive income, last-hit and knockout gold, deck rules,
## buying and selling. Item effects live in Items. Gold never goes negative; a hero owns at most
## max_items distinct items, all from its pre-match deck.


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
		h.gold += cfg.passive_gold_per_second * Pacing.gold_mult(sim) * sim.dt


## Why a purchase would fail, or "" if it is allowed.
static func buy_problem(sim: MatchSim, hero: HeroState, slot: int) -> String:
	if slot < 0 or slot >= hero.deck.size():
		return "no such card"
	if not in_shop_range(sim, hero):
		return "shop at your tower or base"
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


## Why selling the card in this deck slot would fail, or "" if it is allowed.
static func sell_problem(sim: MatchSim, hero: HeroState, slot: int) -> String:
	if slot < 0 or slot >= hero.deck.size():
		return "no such card"
	if not hero.owns(hero.deck[slot]):
		return "not owned"
	if not in_shop_range(sim, hero):
		return "shop at your tower or base"
	return ""


## Shopping happens near your front structure (the active one) or at your Core.
static func in_shop_range(sim: MatchSim, hero: HeroState) -> bool:
	if not hero.alive:
		return false
	for s in sim.structures_of(hero.team):
		if s.alive and (s.tier == 2 or sim.is_exposed(s)) \
				and hero.pos.distance_to(s.pos) <= sim.config.shop_radius + s.radius:
			return true
	return hero.pos.distance_to(MatchSim.to_team_space(hero.team, sim.arena.heal_pad)) <= sim.config.shop_radius


## What selling an item pays back (a Masterwork's upgrade price too).
static func sell_value(sim: MatchSim, item: ItemData, hero: HeroState = null) -> float:
	var paid := float(item.cost)
	if hero != null and hero.is_masterwork(item):
		paid += masterwork_cost(sim, item)
	return roundf(paid * sim.config.sell_refund_fraction)


## What making this item a Masterwork costs.
static func masterwork_cost(sim: MatchSim, item: ItemData) -> float:
	return roundf(item.cost * sim.config.masterwork_cost_fraction)


## What this hero's next siege scroll costs.
static func siege_scroll_cost(sim: MatchSim, hero: HeroState) -> float:
	return sim.config.siege_scroll_cost + sim.config.siege_scroll_cost_step * hero.scrolls_bought


## Why buying a siege scroll would fail, or "" if it is allowed.
static func siege_scroll_problem(sim: MatchSim, hero: HeroState) -> String:
	if hero.level < sim.config.siege_scroll_level:
		return "siege scrolls at level %d" % sim.config.siege_scroll_level
	if not in_shop_range(sim, hero):
		return "shop at your tower or base"
	if sim.pending_siege[hero.team] >= sim.config.siege_scroll_max:
		return "siege troopers already waiting"
	if hero.gold + 0.0001 < siege_scroll_cost(sim, hero):
		return "not enough gold"
	return ""


## Late gold sink: a single-use scroll that adds a siege trooper to your next wave.
static func try_siege_scroll(sim: MatchSim, hero: HeroState) -> bool:
	if siege_scroll_problem(sim, hero) != "":
		return false
	var cost := siege_scroll_cost(sim, hero)
	hero.gold = maxf(0.0, hero.gold - cost)
	hero.scrolls_bought += 1
	sim.pending_siege[hero.team] += 1
	sim.emit_event(&"siege_scroll", {"hero": hero.id, "team": hero.team, "cost": cost})
	return true


## Why making the card in this slot a Masterwork would fail, or "" if it is allowed.
static func masterwork_problem(sim: MatchSim, hero: HeroState, slot: int) -> String:
	if slot < 0 or slot >= hero.deck.size():
		return "no such card"
	var item := hero.deck[slot]
	if hero.level < sim.config.masterwork_level:
		return "Masterworks at level %d" % sim.config.masterwork_level
	if not hero.owns(item):
		return "not owned"
	if hero.is_masterwork(item):
		return "already a Masterwork"
	if not in_shop_range(sim, hero):
		return "shop at your tower or base"
	if hero.gold + 0.0001 < masterwork_cost(sim, item):
		return "not enough gold"
	return ""


## Late gold sink: pay to boost an owned item's stats and effects by masterwork_bonus.
static func try_masterwork(sim: MatchSim, hero: HeroState, slot: int) -> bool:
	if masterwork_problem(sim, hero, slot) != "":
		return false
	var item := hero.deck[slot]
	var cost := masterwork_cost(sim, item)
	hero.gold = maxf(0.0, hero.gold - cost)
	hero.masterworks[item.id] = Items.masterwork_copy(item, sim.config.masterwork_bonus)
	hero.recompute_stats()
	sim.emit_event(&"masterwork", {"hero": hero.id, "team": hero.team, "item": item.id, "slot": slot, "cost": cost})
	return true


## Sells an owned item for sell_refund_fraction of its price (in shop range).
static func try_sell(sim: MatchSim, hero: HeroState, slot: int) -> bool:
	if sell_problem(sim, hero, slot) != "":
		return false
	var item := hero.deck[slot]
	var refund := sell_value(sim, item, hero)
	hero.items.erase(item)
	hero.masterworks.erase(item.id)
	hero.gold += refund
	hero.recompute_stats()
	sim.emit_event(&"item_sold", {"hero": hero.id, "team": hero.team, "item": item.id, "slot": slot, "refund": refund})
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
			_award(sim, source, target.data.gold_bounty * sim.config.deny_self_gold_fraction, &"deny")
		if not hero.alive:
			return
		var share: float = sim.config.deny_gold_fraction if denied else 1.0
		if source == hero:
			_award(sim, hero, target.data.gold_bounty * share * sim.kill_gold_mult * (1.0 + sim.config.last_hit_bonus), &"last_hit")
			Leveling.gain(sim, hero, target.data.xp_bounty * share)
		elif hero.pos.distance_to(target.pos) <= sim.config.minion_gold_radius:
			_award(sim, hero, target.data.gold_bounty * share, &"denied" if denied else &"nearby")
			Leveling.gain(sim, hero, target.data.xp_bounty * share)
	elif target is HeroState:
		var killer := sim.heroes[1 - target.team]
		_award(sim, killer, sim.config.hero_ko_gold, &"knockout")
		var bounty := shutdown_bounty(sim, target)
		if bounty > 0.0:
			killer.gold += bounty
			sim.emit_event(&"gold_awarded", {"hero": killer.id, "team": killer.team, "amount": bounty, "reason": &"shutdown"})
			sim.emit_event(&"shutdown", {"hero": killer.id, "team": killer.team, "victim": target.id, "streak": target.streak, "amount": bounty, "pos": target.pos})
		target.streak = 0
		killer.streak += 1
		if killer.streak == sim.config.shutdown_streak:
			sim.emit_event(&"bounty_up", {"hero": killer.id, "team": killer.team, "amount": shutdown_bounty(sim, killer)})


## Duel First: what knocking this hero out is worth on top of the usual knockout gold.
## 0 until they have shutdown_streak knockouts in a row, then shutdown_gold_start at 0:00
## rising to shutdown_gold_end at shutdown_gold_end_time.
static func shutdown_bounty(sim: MatchSim, h: HeroState) -> float:
	var cfg := sim.config
	if h.streak < cfg.shutdown_streak:
		return 0.0
	var k := clampf(sim.time / maxf(1.0, cfg.shutdown_gold_end_time), 0.0, 1.0)
	return lerpf(cfg.shutdown_gold_start, cfg.shutdown_gold_end, k)


## Siege Banner: an allied hero's aura boosts a minion's damage to structures.
static func minion_structure_mult(sim: MatchSim, m: MinionState) -> float:
	var bonus := 0.0
	var h := sim.heroes[m.team]
	if h.alive:
		for owned in h.items:
			var item := h.effective(owned)
			if item.siege_aura_bonus > 0.0 and h.pos.distance_to(m.pos) <= item.siege_aura_radius:
				bonus += item.siege_aura_bonus
	return 1.0 + bonus


## Pays a hero gold (with the match's gold ramp) and emits gold_awarded.
static func award(sim: MatchSim, hero: HeroState, amount: float, reason: StringName) -> void:
	_award(sim, hero, amount, reason)


static func _award(sim: MatchSim, hero: HeroState, amount: float, reason: StringName) -> void:
	amount *= Pacing.gold_mult(sim)
	if amount <= 0.0:
		return
	hero.gold += amount
	sim.emit_event(&"gold_awarded", {"hero": hero.id, "team": hero.team, "amount": amount, "reason": reason})
