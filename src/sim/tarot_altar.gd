class_name TarotAltar
extends RefCounted
## The Tarot altar (the question marks on Lucy's sketch). One altar at a time, at one of
## the two altar spots (ArenaData.altars, mirrored), alternating sides. Stand on it alone
## for tarot_take_time (taking damage restarts the count) and you draw three of the four
## suits; pick one within tarot_pick_time or the first is picked for you.
##   Swords:    +tarot_swords_bonus damage for tarot_buff_time seconds.
##   Cups:      heal tarot_cups_heal of max HP now.
##   Pentacles: tarot_pentacles_gold gold now.
##   Wands:     ability cooldowns tick tarot_wands_haste faster for tarot_buff_time.
## An altar nobody takes fades after tarot_expire_time. The next one comes
## tarot_interval seconds after the last was taken or faded, on the other side.

const SUITS: Array[StringName] = [&"swords", &"cups", &"pentacles", &"wands"]

var up := false
var spot := 0
var pos := Vector2.ZERO
var next_at := 0.0
var expire_at := 0.0
var activations := 0
var progress: Array[float] = [0.0, 0.0]
## Per team: the three suits on offer (empty = no pick waiting) and when they were drawn.
var offers: Array = [[], []]
var offered_at: Array[float] = [0.0, 0.0]
var spots: Array[Vector2] = []


func setup(sim: MatchSim) -> void:
	spots = ArenaData.mirrored(sim.arena.altars)
	up = false
	spot = 0
	activations = 0
	next_at = sim.config.tarot_first_time
	progress = [0.0, 0.0]
	offers = [[], []]
	offered_at = [0.0, 0.0]
	if not spots.is_empty():
		pos = spots[0]


func tick(sim: MatchSim) -> void:
	var cfg := sim.config
	for team in [MatchSim.BLUE, MatchSim.RED]:
		if not offers[team].is_empty() and sim.time - offered_at[team] >= cfg.tarot_pick_time:
			pick(sim, sim.heroes[team], 0)
	if spots.is_empty():
		return
	if not up:
		if sim.time + 0.0001 >= next_at:
			up = true
			spot = activations % spots.size()
			pos = spots[spot]
			expire_at = sim.time + cfg.tarot_expire_time
			progress = [0.0, 0.0]
			sim.emit_event(&"altar_appeared", {"spot": spot, "pos": pos})
		return
	if sim.time + 0.0001 >= expire_at:
		_close(sim)
		sim.emit_event(&"altar_faded", {"spot": spot, "pos": pos})
		return
	var inside: Array[HeroState] = []
	for h in sim.heroes:
		var hurt := sim.time - h.last_damaged_time < sim.dt * 1.5
		if h.alive and not hurt and h.pos.distance_to(pos) <= cfg.tarot_radius + h.radius:
			inside.append(h)
		else:
			progress[h.team] = 0.0
	if inside.size() != 1:
		for h in inside:
			progress[h.team] = 0.0
		return
	var taker := inside[0]
	progress[taker.team] += sim.dt
	if progress[taker.team] + 0.0001 < cfg.tarot_take_time:
		return
	offers[taker.team] = draw(activations)
	offered_at[taker.team] = sim.time
	sim.emit_event(&"altar_taken", {"spot": spot, "pos": pos, "hero": taker.id, "team": taker.team, "cards": offers[taker.team]})
	_close(sim)


## Three of the four suits; which one sits out rotates with each altar.
static func draw(activation: int) -> Array:
	var out := []
	for i in SUITS.size():
		if i != activation % SUITS.size():
			out.append(SUITS[i])
	return out


## The hero picks card `choice` (0..2) from their offer.
func pick(sim: MatchSim, h: HeroState, choice: int) -> bool:
	var offer: Array = offers[h.team]
	if offer.is_empty() or choice < 0 or choice >= offer.size():
		return false
	var suit: StringName = offer[choice]
	offers[h.team] = []
	var cfg := sim.config
	match suit:
		&"swords":
			h.tarot_swords_until = sim.time + cfg.tarot_buff_time
		&"cups":
			sim.heal(h, h.max_hp * cfg.tarot_cups_heal)
		&"pentacles":
			Economy.award(sim, h, cfg.tarot_pentacles_gold, &"tarot")
		&"wands":
			h.tarot_wands_until = sim.time + cfg.tarot_buff_time
	sim.emit_event(&"tarot_picked", {"hero": h.id, "team": h.team, "suit": suit})
	return true


func _close(sim: MatchSim) -> void:
	up = false
	activations += 1
	next_at = sim.time + sim.config.tarot_interval
	progress = [0.0, 0.0]
