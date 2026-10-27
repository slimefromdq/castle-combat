class_name Waves
## Wave depth (Lucy's picks from the wave doc): special troopers every few waves and
## where the two waves are meeting (for the lane marker).
##
## Special troopers alternate: a Sapper (huge structure damage) and a Shieldbearer (its
## shield stops the first enemy skillshot that touches it, protecting the troopers
## behind it). They used to drop banners; Lucy removed those (too snowbally).


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
