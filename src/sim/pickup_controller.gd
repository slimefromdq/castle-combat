class_name PickupController
extends RefCounted
## Votive candles: small XP + gold pickups away from the lane (ArenaData.candles).
## All candles light together at candle_first_time. A taken candle relights
## candle_respawn_time later, so where and when they come back is predictable.
## Taking one works like picking up the Relay: stand on it alone for candle_take_time.
## Taking damage restarts the count, so a candle can be contested.

## One candle: position, whether it is lit, when it relights, and each team's progress.
class Candle:
	var index := 0
	var pos := Vector2.ZERO
	var lit := false
	var lit_at := 0.0
	var progress: Array[float] = [0.0, 0.0]

var candles: Array[Candle] = []


func setup(sim: MatchSim) -> void:
	candles.clear()
	var spots := sim.arena.all_candles()
	for i in spots.size():
		var c := Candle.new()
		c.index = i
		c.pos = spots[i]
		c.lit_at = sim.config.candle_first_time
		candles.append(c)


func tick(sim: MatchSim) -> void:
	for c in candles:
		if not c.lit:
			if sim.time + 0.0001 >= c.lit_at:
				c.lit = true
				c.progress = [0.0, 0.0]
				sim.emit_event(&"candle_lit", {"candle": c.index, "pos": c.pos})
			continue
		_tick_take(sim, c)


func _tick_take(sim: MatchSim, c: Candle) -> void:
	var inside: Array[HeroState] = []
	for h in sim.heroes:
		var hurt := sim.time - h.last_damaged_time < sim.dt * 1.5
		if h.alive and not hurt and h.pos.distance_to(c.pos) <= sim.config.candle_radius:
			inside.append(h)
		else:
			c.progress[h.team] = 0.0
	if inside.size() != 1:
		for h in inside:
			c.progress[h.team] = 0.0
		return
	var h := inside[0]
	c.progress[h.team] += sim.dt
	if c.progress[h.team] + 0.0001 < sim.config.candle_take_time:
		return
	c.lit = false
	c.lit_at = sim.time + sim.config.candle_respawn_time
	c.progress = [0.0, 0.0]
	Leveling.gain(sim, h, sim.config.candle_xp)
	Economy.award(sim, h, sim.config.candle_gold, &"candle")
	sim.emit_event(&"candle_taken", {"candle": c.index, "pos": c.pos, "hero": h.id, "team": h.team, "relit_at": c.lit_at})


## Lit candles, for bots and the HUD.
func lit_candles() -> Array[Candle]:
	var out: Array[Candle] = []
	for c in candles:
		if c.lit:
			out.append(c)
	return out
