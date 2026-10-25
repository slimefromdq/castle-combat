class_name Sprint
## Sprinting (Lucy's replacement for Recall): keep moving in roughly the same direction,
## out of combat, for sprint_build_time and your hero breaks into a sprint. Stopping
## (which is also how you attack), turning sharply, casting, carrying the Relay, being
## stunned or knocked back, or taking any damage ends it and resets the build-up.


## Called each tick before the hero moves, so the sprint speed applies this tick.
static func tick(sim: MatchSim, h: HeroState, cmd: PlayerCommand) -> void:
	var cfg := sim.config
	var v := cmd.move
	if v.length() < cfg.move_dead_zone or blocked(sim, h, cmd):
		stop(sim, h)
		return
	var dir := v.normalized()
	if h.sprint_build <= 0.0:
		h.sprint_dir = dir
	elif dir.dot(h.sprint_dir) < cos(deg_to_rad(cfg.sprint_turn_degrees)):
		stop(sim, h)
		h.sprint_dir = dir
	else:
		# Gentle curves (around the Core, along the lane) keep the sprint going.
		h.sprint_dir = h.sprint_dir.lerp(dir, cfg.sprint_turn_follow).normalized()
	h.sprint_build += sim.dt
	if not h.sprinting and h.sprint_build + 0.0001 >= cfg.sprint_build_time:
		h.sprinting = true
		h.sprint_mult = cfg.sprint_speed_mult
		sim.emit_event(&"sprint_started", {"hero": h.id, "team": h.team})


static func blocked(sim: MatchSim, h: HeroState, cmd: PlayerCommand) -> bool:
	return not h.alive or h.carrying_relay or cmd.cast_slot >= 0 or h.is_stunned(sim.time) \
			or Abilities.move_forced(sim, h) or h.is_channeling() \
			or sim.time - h.last_hero_combat_time < sim.config.sprint_combat_delay \
			or sim.time - h.last_damaged_time < sim.config.sprint_combat_delay


## Ends a sprint (if any) and resets the build-up.
static func stop(sim: MatchSim, h: HeroState) -> void:
	h.sprint_build = 0.0
	h.sprint_mult = 1.0
	if h.sprinting:
		h.sprinting = false
		sim.emit_event(&"sprint_ended", {"hero": h.id, "team": h.team})
