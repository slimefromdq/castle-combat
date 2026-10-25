class_name Recall
## Recall (Lucy's playtest): stand still for recall_time to return to your healing pad.
## Moving, casting, carrying the Relay, being stunned or knocked back, or taking any
## damage cancels it.


static func problem(sim: MatchSim, h: HeroState) -> String:
	if not h.alive:
		return "knocked out"
	if h.carrying_relay:
		return "carrying the Relay"
	if h.recall_at >= 0.0:
		return "already recalling"
	return ""


static func tick(sim: MatchSim, h: HeroState, cmd: PlayerCommand) -> void:
	if not h.alive:
		h.recall_at = -1.0
		return
	if cmd.recall and problem(sim, h) == "":
		h.recall_at = sim.time + sim.config.recall_time
		sim.emit_event(&"recall_started", {"hero": h.id, "team": h.team, "at": h.recall_at})
		return
	if h.recall_at < 0.0:
		return
	var moved := cmd.move.length() > sim.config.move_dead_zone
	if moved or cmd.cast_slot >= 0 or h.carrying_relay or h.is_stunned(sim.time) \
			or Abilities.move_forced(sim, h) or h.is_channeling():
		cancel(sim, h)
	elif sim.time + 0.0001 >= h.recall_at:
		h.recall_at = -1.0
		h.pos = MatchSim.to_team_space(h.team, sim.arena.heal_pad)
		h.prev_pos = h.pos
		h.attack_target = 0
		sim.emit_event(&"recalled", {"hero": h.id, "team": h.team})


static func cancel(sim: MatchSim, h: HeroState) -> void:
	if h.recall_at < 0.0:
		return
	h.recall_at = -1.0
	sim.emit_event(&"recall_cancelled", {"hero": h.id, "team": h.team})
