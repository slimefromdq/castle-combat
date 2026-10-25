class_name Leveling
## Hero XP and levels (Lucy's ladder, replacing the GDD's "no levels" rule):
## level 1 ability, 2 perk, 3 second ability, 4 perk, 5 ultimate, 6 capstone perk.
## XP comes from time, minions dying near you (same rule as gold) and knockouts.
## A hero behind the enemy hero in level earns more, so a lost fight is not a lost game.


static func tick(sim: MatchSim) -> void:
	for h in sim.heroes:
		gain(sim, h, sim.config.passive_xp_per_second * sim.dt)
		# A perk left unpicked too long takes the first option.
		var tier := h.pending_perk_tier()
		if tier >= 0 and sim.time - h.perk_offered_at[tier] >= sim.config.perk_auto_pick_time:
			pick_perk(sim, h, 0)


## Picks one of the two perks for the earliest level-up not yet decided.
static func pick_perk(sim: MatchSim, h: HeroState, choice: int) -> bool:
	var tier := h.pending_perk_tier()
	if tier < 0 or choice < 0 or choice >= h.perk_options(tier).size():
		return false
	h.perk_picks[tier] = choice
	h.recompute_stats()
	var perk := h.perk_options(tier)[choice]
	sim.emit_event(&"perk_picked", {"hero": h.id, "team": h.team, "tier": tier, "perk": perk.id})
	return true


static func on_knockout(sim: MatchSim, victim: HeroState) -> void:
	var killer := sim.heroes[1 - victim.team]
	var above := maxi(0, victim.level - killer.level)
	gain(sim, killer, sim.config.ko_xp + above * sim.config.ko_xp_per_level_above)


static func max_level(sim: MatchSim) -> int:
	return sim.config.level_xp.size()


## Adds XP (with the catch-up bonus) and handles any level-ups.
static func gain(sim: MatchSim, h: HeroState, amount: float) -> void:
	if amount <= 0.0 or h.level >= max_level(sim):
		return
	var behind := maxi(0, sim.heroes[1 - h.team].level - h.level)
	h.xp += amount * (1.0 + behind * sim.config.catch_up_per_level)
	while h.level < max_level(sim) and h.xp + 0.0001 >= sim.config.level_xp[h.level]:
		h.level += 1
		if h.level % 2 == 0 and h.level / 2 - 1 < 3:
			h.perk_offered_at[h.level / 2 - 1] = sim.time
		h.recompute_stats()
		sim.emit_event(&"level_up", {"hero": h.id, "team": h.team, "level": h.level})


## 0..1 progress from the current level to the next (1 at max level).
static func progress(sim: MatchSim, h: HeroState) -> float:
	if h.level >= max_level(sim):
		return 1.0
	var lo := float(sim.config.level_xp[h.level - 1])
	var hi := float(sim.config.level_xp[h.level])
	return clampf((h.xp - lo) / (hi - lo), 0.0, 1.0)
