class_name Leveling
## Hero XP and levels (Lucy's ladder, replacing the GDD's "no levels" rule), nine levels:
##   1 ability · 2 perk · 3 second ability + passive · 4 perk · 5 growth · 6 ultimate ·
##   7 capstone perk + siege scrolls · 8 passive + Masterworks · 9 crown.
## XP comes mostly from minions dying near you (same rule as gold), then knockouts, with a
## trickle over time: leaving lane costs levels as well as gold.
## Each level-up heals and briefly speeds up attacks (the "surge").
## A hero behind the enemy hero in level earns more, so a lost fight is not a lost game.


## Levels that unlock abilities 0, 1, 2 (the last is the ultimate).
const ABILITY_LEVELS: Array[int] = [1, 3, 6]
## Levels that offer perk tiers 0, 1, 2 (pick one of two).
const PERK_LEVELS: Array[int] = [2, 4, 7]
## Levels that grant the hero's automatic passives 0 and 1 (HeroData.passives).
const PASSIVE_LEVELS: Array[int] = [3, 8]
## The level that unlocks the ultimate. Whoever gets there first wins the "ult race".
const ULT_LEVEL := 6
## The last level: a bigger level-up surge and a crown ring.
const CROWN_LEVEL := 9


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
		var tier := PERK_LEVELS.find(h.level)
		if tier >= 0:
			h.perk_offered_at[tier] = sim.time
		h.recompute_stats()
		_surge(sim, h)
		var info := {"hero": h.id, "team": h.team, "level": h.level}
		var p := PASSIVE_LEVELS.find(h.level)
		if p >= 0 and p < h.data.passives.size():
			info.passive = h.data.passives[p].display_name
		sim.emit_event(&"level_up", info)
		if h.level == ULT_LEVEL and sim.ult_race_winner < 0:
			sim.ult_race_winner = h.team
			sim.emit_event(&"ult_race_won", {"hero": h.id, "team": h.team})


## Level-up surge: a chunk of HP back and a burst of attack speed.
static func _surge(sim: MatchSim, h: HeroState) -> void:
	if not h.alive:
		return
	var crown := h.level == CROWN_LEVEL
	sim.heal(h, h.max_hp * sim.config.level_up_heal_fraction * (2.0 if crown else 1.0))
	h.surge_bonus = sim.config.level_up_attack_speed
	h.surge_until = sim.time + sim.config.level_up_surge_time * (2.0 if crown else 1.0)


## 0..1 progress from the current level to the next (1 at max level).
static func progress(sim: MatchSim, h: HeroState) -> float:
	if h.level >= max_level(sim):
		return 1.0
	var lo := float(sim.config.level_xp[h.level - 1])
	var hi := float(sim.config.level_xp[h.level])
	return clampf((h.xp - lo) / (hi - lo), 0.0, 1.0)
