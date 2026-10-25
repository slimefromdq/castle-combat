class_name Comeback
## Underdog Relay (Lucy's pick). A Relay becomes an Underdog Relay only when one hero is
## clearly losing: they have lost more structures than the enemy AND they are behind in
## level or in net worth (gold + items) by a real margin. Then it appears just in front of
## their front structure, each hero delivers it to their own front structure, and the
## underdog's delivery pays catch-up gold and XP (a share of the gap, so being behind is
## never better than being ahead) and repairs that structure.


## Gold in hand plus the price of owned items.
static func net_worth(h: HeroState) -> float:
	var worth := h.gold
	for item in h.items:
		worth += item.cost
	return worth


static func structures_lost(sim: MatchSim, team: int) -> int:
	var n := 0
	for s in sim.structures_of(team):
		if not s.alive:
			n += 1
	return n


## The team that qualifies as the underdog right now, or -1.
static func underdog(sim: MatchSim) -> int:
	var cfg := sim.config
	for u: int in [MatchSim.BLUE, MatchSim.RED]:
		var o := 1 - u
		if structures_lost(sim, u) <= structures_lost(sim, o):
			continue
		var me := sim.heroes[u]
		var them := sim.heroes[o]
		var level_behind := them.level - me.level >= cfg.underdog_levels_behind
		var gold_behind := net_worth(them) >= net_worth(me) * cfg.underdog_worth_ratio + cfg.underdog_worth_margin
		if level_behind or gold_behind:
			return u
	return -1


## Where an Underdog Relay appears: in front of the underdog's front structure.
static func spawn_point(sim: MatchSim, team: int) -> Vector2:
	var front := sim.front_structure(team)
	if front == null:
		return Vector2.ZERO
	return front.pos + MatchSim.forward(team) * (front.radius + sim.config.underdog_spawn_ahead)


## The underdog delivered: catch-up gold and XP, and their front structure is repaired.
static func reward(sim: MatchSim, h: HeroState) -> void:
	var cfg := sim.config
	var them := sim.heroes[1 - h.team]
	var gold := clampf((net_worth(them) - net_worth(h)) * cfg.underdog_gold_share, 0.0, cfg.underdog_gold_max)
	if gold > 0.0:
		h.gold += gold
		sim.emit_event(&"gold_awarded", {"hero": h.id, "team": h.team, "amount": gold, "reason": &"underdog"})
	var xp_gap := them.xp - h.xp
	if xp_gap > 0.0:
		var behind := maxi(0, them.level - h.level)
		Leveling.gain(sim, h, xp_gap * cfg.underdog_xp_share / (1.0 + behind * cfg.catch_up_per_level))
	var front := sim.front_structure(h.team)
	var repaired := 0.0
	if front != null:
		repaired = minf(front.max_hp - front.hp, front.max_hp * cfg.underdog_repair)
		front.hp += repaired
	sim.emit_event(&"underdog_reward", {"hero": h.id, "team": h.team, "gold": gold, "repaired": repaired})
