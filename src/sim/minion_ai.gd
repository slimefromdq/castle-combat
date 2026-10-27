class_name MinionAI
## Minions walk the lane toward the enemy Core, turn aside for enemies they notice,
## and stand still to attack anything in range.


static func tick(sim: MatchSim, m: MinionState) -> void:
	if not m.alive:
		return
	if sim.time < m.stun_until:
		if m.is_winding_up():
			CombatSystem.cancel(sim, m)
		return
	if m.is_winding_up():
		# Committed: stand still and finish (or lose) the attack.
		CombatSystem.tick_attack(sim, m, true, func() -> SimEntity: return null)
		return
	var target := Targeting.for_minion(sim, m, sim.config.minion_aggro_range)
	var in_reach := target != null and CombatSystem.in_range(sim, m, target)
	if target == null:
		m.pos = Movement.slide(sim, m, m.pos, _lane_step(sim, m))
	elif not in_reach:
		var to := (target.pos - m.pos).normalized()
		m.pos = Movement.slide(sim, m, m.pos, to * m.data.move_speed * m.speed_mult * sim.dt)
	CombatSystem.tick_attack(sim, m, in_reach, func() -> SimEntity: return target if in_reach else null)


## Forward along the lane, drifting back toward the centre line.
static func _lane_step(sim: MatchSim, m: MinionState) -> Vector2:
	var dir := m.lane_dir + Vector2(-m.pos.x * 0.15, 0.0)
	return dir.normalized() * m.data.move_speed * m.speed_mult * sim.dt


## Keeps minions from stacking on one spot. Heroes walk through minions.
static func separate(sim: MatchSim) -> void:
	var list := sim.minions
	for i in list.size():
		var a := list[i]
		for j in range(i + 1, list.size()):
			var b := list[j]
			var d := b.pos - a.pos
			var min_dist := a.radius + b.radius
			var length := d.length()
			if length >= min_dist:
				continue
			var dir := d / length if length > 0.0001 else Vector2.RIGHT
			var push := dir * (min_dist - length) * 0.5
			if not Movement.is_blocked(sim, a, a.pos - push):
				a.pos -= push
			if not Movement.is_blocked(sim, b, b.pos + push):
				b.pos += push
