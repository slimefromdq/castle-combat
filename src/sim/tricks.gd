class_name Tricks
## Duel First: every hero brings one Trick, picked before the match, on its own button
## (keyboard T). Ready from the start; each has its own cooldown (MatchConfig "Tricks").
##   Blink:   hop a few metres the way you aim or move.
##   Cleanse: end stuns, roots and slows, then shrug off hard CC for a moment. Works
##            while stunned.
##   Barrier: a short shield.
##   Brand:   your next hit on the enemy hero burns them and cuts their healing.

const IDS: Array[StringName] = [&"blink", &"cleanse", &"barrier", &"brand"]
const NAMES := {&"blink": "Blink", &"cleanse": "Cleanse", &"barrier": "Barrier", &"brand": "Brand"}
const COLORS := {&"blink": Color("6fd3ff"), &"cleanse": Color("8ff0b0"), &"barrier": Color("ffd166"), &"brand": Color("ff7a59")}


static func display_name(id: StringName) -> String:
	return NAMES.get(id, String(id).capitalize())


static func summary(cfg: MatchConfig, id: StringName) -> String:
	match id:
		&"blink":
			return "Hop %d m the way you aim or move." % roundi(cfg.trick_blink_distance)
		&"cleanse":
			return "End stuns, roots and slows, then ignore hard CC for %s s. Works while stunned." % _num(cfg.trick_cleanse_immunity)
		&"barrier":
			return "Shield for %d%% of max HP, %s s." % [roundi(cfg.trick_barrier_shield * 100.0), _num(cfg.trick_barrier_time)]
		&"brand":
			return "Your next hit on the enemy hero burns them and halves their healing for %s s." % _num(cfg.trick_brand_wounds_time)
	return ""


static func cooldown(cfg: MatchConfig, id: StringName) -> float:
	match id:
		&"blink":
			return cfg.trick_blink_cooldown
		&"cleanse":
			return cfg.trick_cleanse_cooldown
		&"barrier":
			return cfg.trick_barrier_cooldown
		&"brand":
			return cfg.trick_brand_cooldown
	return 30.0


## Why the Trick can't be used now ("" = it can).
static func problem(sim: MatchSim, h: HeroState) -> String:
	if not h.alive:
		return "knocked out"
	if h.trick_cd > 0.0:
		return "cooling down"
	if h.trick == &"blink":
		if h.is_stunned(sim.time) or h.is_rooted():
			return "can't move"
		if h.forced_ticks > 0:
			return "moving"
		if h.carrying_relay:
			return "carrying the Relay"
	elif h.trick == &"brand" and h.is_stunned(sim.time):
		return "stunned"
	return ""


static func tick(sim: MatchSim) -> void:
	for h in sim.heroes:
		h.trick_cd = maxf(0.0, h.trick_cd - sim.dt)


static func try_use(sim: MatchSim, h: HeroState, move: Vector2) -> bool:
	if problem(sim, h) != "":
		return false
	var cfg := sim.config
	var info := {"hero": h.id, "team": h.team, "trick": h.trick, "pos": h.pos}
	match h.trick:
		&"blink":
			var dir := h.aim if h.aim != Vector2.ZERO else (move.normalized() if move.length() > 0.15 else h.facing)
			var from := h.pos
			var to := Abilities.free_spot(sim, h, from + dir * cfg.trick_blink_distance, from)
			CombatSystem.cancel(sim, h)
			h.pos = to
			h.prev_pos = to
			h.facing = dir
			info.from = from
			info.to = to
		&"cleanse":
			h.stun_until = minf(h.stun_until, sim.time)
			h.root_until = minf(h.root_until, sim.time)
			h.slow_until = minf(h.slow_until, sim.time)
			h.hard_cc_until = sim.time
			h.cc_immune_until = sim.time + cfg.trick_cleanse_immunity
		&"barrier":
			var shield := h.max_hp * cfg.trick_barrier_shield
			h.shield_hp = (h.shield_hp if sim.time < h.shield_until else 0.0) + shield
			h.shield_until = maxf(h.shield_until, sim.time + cfg.trick_barrier_time)
		&"brand":
			h.brand_armed_until = sim.time + cfg.trick_brand_window
	h.trick_cd = cooldown(cfg, h.trick)
	sim.emit_event(&"trick_used", info)
	return true


## A hero's damage landed on the enemy hero: an armed Brand goes off.
static func on_hero_damage(sim: MatchSim, src: HeroState, target: HeroState) -> void:
	if sim.time >= src.brand_armed_until or not target.alive:
		return
	src.brand_armed_until = 0.0
	var cfg := sim.config
	target.wounds_amount = maxf(target.wounds_amount if sim.time < target.wounds_until else 0.0, cfg.trick_brand_wounds)
	target.wounds_until = maxf(target.wounds_until, sim.time + cfg.trick_brand_wounds_time)
	var burn := cfg.trick_brand_burn + cfg.trick_brand_burn_per_level * src.level
	Kits.add_dot(sim, src, target, burn, cfg.trick_brand_burn_time, 6, 0, &"brand")
	sim.emit_event(&"brand_landed", {"hero": src.id, "team": src.team, "target": target.id, "pos": target.pos})


static func _num(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, roundf(x)) else "%.1f" % x
