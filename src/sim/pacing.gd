class_name Pacing
## Everything that makes a match speed up as it goes (Lucy's pacing overhaul): the gold
## ramp, growing Relay rewards, structure resist that decays, Guardians, power minions,
## minion scaling, growing respawn timers and overtime. Every number is in MatchConfig
## or StructureData.


static func minutes_after(sim: MatchSim, start: float) -> float:
	return maxf(0.0, sim.time - start) / 60.0


## Multiplier on all gold from minions, knockouts and passive income.
static func gold_mult(sim: MatchSim) -> float:
	return 1.0 + sim.config.gold_ramp_per_minute * minutes_after(sim, sim.config.gold_ramp_start)


## Current resist of a structure: starts at resist_start, falls to resist_end.
static func structure_resist(sim: MatchSim, s: StructureState) -> float:
	var cfg := sim.config
	var span := maxf(1.0, cfg.resist_end_time - cfg.resist_decay_start)
	var k := clampf((sim.time - cfg.resist_decay_start) / span, 0.0, 1.0)
	return lerpf(s.data.resist_start, cfg.resist_end, k)


## Damage a structure actually takes. Heroes earn gold for damage the resist soaks up.
static func structure_damage_taken(sim: MatchSim, s: StructureState, amount: float, source: SimEntity) -> float:
	var resist := structure_resist(sim, s)
	var taken := amount * (1.0 - resist)
	if resist > 0.0 and source is HeroState:
		(source as HeroState).gold += (amount - taken) * sim.config.resist_gold_per_damage
	if sim.overtime:
		taken *= sim.config.overtime_structure_damage_taken
	return taken


## Damage a structure deals with a basic attack (Guardian beam ramp, overtime).
static func structure_damage_dealt(sim: MatchSim, s: StructureState, target: SimEntity, damage: float) -> float:
	if s.is_guardian():
		if s.beam_target != target.id or sim.time - s.beam_last > 1.0:
			s.beam_target = target.id
			s.beam_since = sim.time
		s.beam_last = sim.time
		damage *= minf(s.data.beam_max_mult, 1.0 + s.data.beam_ramp_per_second * (sim.time - s.beam_since))
	if sim.overtime:
		damage *= sim.config.overtime_structure_damage_dealt
	return damage


## A newly spawned minion: grows slightly with time, much more as a power minion.
static func scale_minion(sim: MatchSim, m: MinionState) -> void:
	var cfg := sim.config
	var minutes := minutes_after(sim, cfg.minion_scale_start)
	var hp_mult := 1.0 + cfg.minion_hp_per_minute * minutes
	var dmg_mult := 1.0 + cfg.minion_damage_per_minute * minutes
	if sim.overtime:
		hp_mult *= cfg.overtime_minion_hp_mult
	m.max_hp *= hp_mult
	m.hp = m.max_hp
	m.attack_damage *= dmg_mult
	if sim.power_minions[m.team]:
		make_power(sim, m)


static func make_power(sim: MatchSim, m: MinionState) -> void:
	if m.is_power:
		return
	var cfg := sim.config
	m.is_power = true
	m.max_hp *= cfg.power_hp_mult
	m.hp *= cfg.power_hp_mult
	m.attack_damage *= cfg.power_damage_mult
	m.speed_mult *= cfg.power_speed_mult


## Seconds until a hero knocked out now comes back.
static func respawn_delay(sim: MatchSim, h: HeroState) -> float:
	var cfg := sim.config
	var t := cfg.respawn_time + cfg.respawn_per_minute * sim.time / 60.0 + cfg.respawn_per_death * maxf(0.0, h.deaths - 1)
	t = minf(cfg.respawn_max, t)
	if sim.overtime:
		t *= cfg.overtime_respawn_mult
	return t


## A structure fell: gold for the enemy hero; a Guardian also powers up the enemy's
## minions for good, and shortens its own hero's respawn if they are down.
static func on_structure_killed(sim: MatchSim, s: StructureState) -> void:
	var winner := 1 - s.team
	var hero := sim.heroes[winner]
	if s.data.gold_bounty > 0.0:
		hero.gold += s.data.gold_bounty
		sim.emit_event(&"gold_awarded", {"hero": hero.id, "team": winner, "amount": s.data.gold_bounty, "reason": &"structure"})
	if not s.is_guardian():
		return
	sim.power_minions[winner] = true
	# The Core behind a fallen Guardian gets a few seconds of breathing room.
	var core := sim.structures_of(s.team)[-1]
	if core.alive and core.tier == 2:
		core.immune_until = sim.time + sim.config.core_immunity_time
		sim.emit_event(&"core_immune", {"id": core.id, "team": s.team, "until": core.immune_until, "seconds": sim.config.core_immunity_time})
	for m in sim.minions:
		if m.alive and m.team == winner:
			make_power(sim, m)
	var owner := sim.heroes[s.team]
	if not owner.alive:
		owner.respawn_at = sim.time + (owner.respawn_at - sim.time) * sim.config.guardian_fall_respawn_mult
	sim.emit_event(&"guardian_fallen", {"team": s.team})


## A Relay delivery: gold for the carrier and siege minions, both growing each activation.
static func on_relay_delivered(sim: MatchSim, hero: HeroState, activation: int, long := false) -> void:
	var cfg := sim.config
	var sieges := mini(cfg.relay_siege_max, 1 + activation / maxi(1, cfg.relay_siege_every))
	if long:
		sieges += cfg.relay_long_extra_siege
	for i in sieges:
		sim.queue_siege(hero.team)
	var gold := cfg.relay_gold_base + cfg.relay_gold_per_activation * activation
	if long:
		gold *= cfg.relay_long_gold_mult
	hero.gold += gold
	sim.emit_event(&"gold_awarded", {"hero": hero.id, "team": hero.team, "amount": gold, "reason": &"relay"})


## When overtime starts: later once any Guardian has fallen (the match is moving).
static func overtime_at(sim: MatchSim) -> float:
	for s in sim.structures:
		if s.is_guardian() and not s.alive:
			return sim.config.overtime_late_time
	return sim.config.overtime_time


## Phase 2: the first Outer Tower to fall, or phase_two_time, whichever comes first.
static func _tick_phase(sim: MatchSim) -> void:
	if sim.phase >= 2:
		return
	var tower_down := false
	for s in sim.structures:
		if s.tier == 0 and not s.alive:
			tower_down = true
	if tower_down or sim.time + 0.0001 >= sim.config.phase_two_time:
		sim.phase = 2
		sim.emit_event(&"phase_two", {"tower": tower_down})


static func tick(sim: MatchSim) -> void:
	_tick_phase(sim)
	if not sim.overtime:
		if sim.time >= overtime_at(sim):
			sim.overtime = true
			sim.emit_event(&"overtime_started", {})
	for s in sim.structures:
		if s.alive and s.is_guardian():
			_tick_slam(sim, s)
		elif s.tier == 2:
			s.guarded = s.alive and core_guarded(sim, s)
			if s.alive and sim.is_exposed(s):
				_tick_core_stun(sim, s)


## Core last stand: the Core's own hero, alive, within core_guard_radius and on the
## enemy-facing side of it. Overtime ends it.
static func core_guarded(sim: MatchSim, s: StructureState) -> bool:
	if sim.overtime:
		return false
	var h := sim.heroes[s.team]
	return h.alive and in_guard_zone(sim, s, h.pos)


## True if p is inside the Core's guard half circle (in front of it, toward the enemy).
static func in_guard_zone(sim: MatchSim, s: StructureState, p: Vector2) -> bool:
	var off := p - s.pos
	return off.length() <= sim.config.core_guard_radius and off.dot(MatchSim.forward(s.team)) >= 0.0


## Core stun: slow, telegraphed, no damage. Heroes and troopers inside when it lands
## are stunned (troopers longer), which buys the defender time without wiping a wave.
static func _tick_core_stun(sim: MatchSim, s: StructureState) -> void:
	var cfg := sim.config
	var r := cfg.core_stun_radius
	if s.stun_at < 0.0:
		if sim.time + 0.0001 < s.stun_ready_at or not _enemy_near(sim, s, r):
			return
		s.stun_at = sim.time + cfg.core_stun_windup
		sim.emit_event(&"core_stun_windup", {"id": s.id, "team": s.team, "radius": r, "at": s.stun_at})
		return
	if sim.time + 0.0001 < s.stun_at:
		return
	s.stun_at = -1.0
	s.stun_ready_at = sim.time + cfg.core_stun_interval
	var enemy := sim.heroes[1 - s.team]
	var hit := enemy.alive and enemy.pos.distance_to(s.pos) <= r + enemy.radius
	var troopers := 0
	for m in sim.minions:
		if m.alive and m.team >= 0 and m.team != s.team and m.pos.distance_to(s.pos) <= r + m.radius:
			m.stun_until = maxf(m.stun_until, sim.time + cfg.core_stun_minion)
			CombatSystem.cancel(sim, m)
			troopers += 1
	if hit:
		Abilities._stun(sim, enemy, cfg.core_stun_hero)
	sim.emit_event(&"core_stun", {"id": s.id, "team": s.team, "radius": r, "hit": hit, "troopers": troopers})


static func _enemy_near(sim: MatchSim, s: StructureState, r: float) -> bool:
	var enemy := sim.heroes[1 - s.team]
	if enemy.alive and enemy.pos.distance_to(s.pos) <= r + enemy.radius:
		return true
	for m in sim.minions:
		if m.alive and m.team >= 0 and m.team != s.team and m.pos.distance_to(s.pos) <= r + m.radius:
			return true
	return false


## Guardian stomp: each health threshold crossed starts a long telegraph; then every
## enemy inside the (large) radius is hit. Heroes: damage, knockback, stun. Minions:
## a big chunk of their health and a shove. The Guardian then rests, which is the
## opening for a dive.
static func _tick_slam(sim: MatchSim, s: StructureState) -> void:
	var d := s.data
	if s.slam_at < 0.0:
		if s.slams_used < d.slam_hp_thresholds.size() and s.hp <= s.max_hp * d.slam_hp_thresholds[s.slams_used]:
			s.slams_used += 1
			s.slam_at = sim.time + d.slam_windup
			CombatSystem.cancel(sim, s)
			sim.emit_event(&"guardian_slam_windup", {"id": s.id, "team": s.team, "radius": d.slam_radius, "at": s.slam_at})
		return
	if sim.time + 0.0001 < s.slam_at:
		return
	s.slam_at = -1.0
	s.disabled_until = sim.time + d.slam_recover
	var enemy := sim.heroes[1 - s.team]
	var hit := enemy.alive and enemy.pos.distance_to(s.pos) <= d.slam_radius + enemy.radius
	sim.emit_event(&"guardian_slam", {"id": s.id, "team": s.team, "radius": d.slam_radius, "hit": hit})
	for m in sim.minions:
		if m.alive and m.team >= 0 and m.team != s.team and m.pos.distance_to(s.pos) <= d.slam_radius + m.radius:
			sim.apply_damage(m, m.max_hp * d.slam_minion_fraction, s)
			if m.alive:
				var push := m.pos - s.pos
				m.pos = Movement.slide(sim, m, m.pos, (push.normalized() if push.length() > 0.01 else MatchSim.forward(s.team)) * d.slam_knockback * 0.5)
	if not hit:
		return
	sim.apply_damage(enemy, d.slam_damage, s)
	if enemy.alive:
		var away := enemy.pos - s.pos
		away = away.normalized() if away.length() > 0.01 else MatchSim.forward(s.team)
		Abilities._force(sim, enemy, away * d.slam_knockback, 0.3, false)
		Abilities._stun(sim, enemy, d.slam_stun)
