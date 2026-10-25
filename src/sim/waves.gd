class_name Waves
## Wave depth (Lucy's picks from the wave doc): special troopers every few waves, the
## banners they drop, and where the two waves are meeting (for the lane marker).
##
## Special troopers alternate: a Sapper (huge structure damage) and a Shieldbearer (its
## shield stops the first enemy skillshot that touches it, protecting the troopers
## behind it). Either one drops a banner when it dies. A hero who walks over a banner
## buffs their own team's next wave.


## The special trooper this wave brings (null if none). Waves count from 1.
static func special_for_wave(sim: MatchSim, wave: int) -> MinionData:
	var every := sim.config.special_wave_every
	if every <= 0 or wave % every != 0:
		return null
	var kinds := [&"sapper", &"shieldbearer"]
	return sim.minion_types.get(kinds[(wave / every - 1) % kinds.size()])


## Where a special trooper lines up in its wave (team space, relative to the spawn point):
## Shieldbearers walk in front, Sappers behind the melee pair.
static func special_offset(data: MinionData) -> Vector2:
	return Vector2(0.0, 0.9) if data.shield_blocks > 0 else Vector2(0.0, -1.6)


## Banner buff on a freshly spawned wave.
static func apply_banner(sim: MatchSim, m: MinionState) -> void:
	var cfg := sim.config
	m.max_hp *= 1.0 + cfg.banner_hp_bonus
	m.hp = m.max_hp
	m.attack_damage *= 1.0 + cfg.banner_damage_bonus
	m.bannered = true


## A special trooper died: it drops a banner where it fell.
static func on_minion_killed(sim: MatchSim, m: MinionState) -> void:
	if m.data.special == &"":
		return
	var b := {"id": sim.new_id(), "pos": m.pos, "expires_at": sim.time + sim.config.banner_lifetime}
	sim.banners.append(b)
	sim.emit_event(&"banner_dropped", {"id": b.id, "pos": b.pos})


## Banner pickups and expiry. A banner goes to the first living hero on it (the blue
## hero wins an exact tie, which only matters in tests).
static func tick(sim: MatchSim) -> void:
	for i in range(sim.banners.size() - 1, -1, -1):
		var b: Dictionary = sim.banners[i]
		var taker: HeroState = null
		for h in sim.heroes:
			if h.alive and h.pos.distance_to(b.pos) <= sim.config.banner_pickup_radius + h.radius:
				taker = h
				break
		if taker != null:
			sim.banner_pending[taker.team] = true
			sim.banners.remove_at(i)
			sim.emit_event(&"banner_taken", {"id": b.id, "hero": taker.id, "team": taker.team})
		elif sim.time >= b.expires_at:
			sim.banners.remove_at(i)
			sim.emit_event(&"banner_expired", {"id": b.id})


## The lane y where the waves meet: halfway between each team's most advanced trooper,
## or the front of the only wave on the map. NAN with no troopers at all.
static func meeting_y(sim: MatchSim) -> float:
	var fronts := [NAN, NAN]
	for m in sim.minions:
		if not m.alive:
			continue
		var f: float = fronts[m.team]
		# Blue advances toward +y, red toward -y.
		if is_nan(f) or (m.pos.y > f if m.team == MatchSim.BLUE else m.pos.y < f):
			fronts[m.team] = m.pos.y
	if is_nan(fronts[0]):
		return fronts[1]
	if is_nan(fronts[1]):
		return fronts[0]
	return (fronts[0] + fronts[1]) / 2.0
