class_name NeutralCamps
extends RefCounted
## Strong neutral camps (the smileys on Lucy's sketch): one Pwee per side of the diamond
## (ArenaData.camps, mirrored), and either hero may take either one. It sits at home
## until a hero hits it, then fights back. It gives up the chase and walks home (healing
## to full) when its attacker leaves the leash or stops hitting it for a while.
##
## Rewards (Lucy): every hit pays the hitter XP and gold for the share of health it took,
## up to camp_damage_share of the total over the Pwee's life. The killer gets the rest.
## A Pwee healing back to full doesn't refill the damage share, so it can't be farmed.
##
## Phase 2 (Lucy's moon idea): the killer also gets a moon buff. The Pwee on your own
## half gives Waxing, the one on the enemy's half gives Waning (see MatchConfig "Phase 2").
##
## The Pwee is a MinionState on team -1: abilities that hit "enemy troopers" hit it,
## while troopers and towers ignore it (see CombatSystem.is_valid_target).

const PWEE: MinionData = preload("res://data/minions/pwee.tres")

class Camp:
	var index := 0
	var home := Vector2.ZERO
	## The living Pwee's entity id (0 = none).
	var monster := 0
	var respawn_at := 0.0
	## Fraction of the total reward already paid out for damage this life.
	var paid := 0.0
	## Who it is fighting (hero entity id, 0 = nobody) and when it was last hit.
	var aggro := 0
	var last_hit := -100.0
	var returning := false

var camps: Array[Camp] = []


func setup(sim: MatchSim) -> void:
	camps.clear()
	var spots := ArenaData.mirrored(sim.arena.camps)
	for i in spots.size():
		var c := Camp.new()
		c.index = i
		c.home = spots[i]
		c.respawn_at = sim.config.camp_first_time
		camps.append(c)


func tick(sim: MatchSim) -> void:
	for c in camps:
		var m := monster_of(sim, c)
		if m == null:
			if c.monster != 0:
				c.monster = 0
			if sim.time + 0.0001 >= c.respawn_at:
				_spawn(sim, c)
			continue
		_tick_monster(sim, c, m)


func monster_of(sim: MatchSim, c: Camp) -> MinionState:
	var m := sim.get_entity(c.monster) as MinionState
	return m if m != null and m.alive else null


## The camp a Pwee belongs to, or null.
func camp_of(m: SimEntity) -> Camp:
	for c in camps:
		if c.monster == m.id:
			return c
	return null


func _spawn(sim: MatchSim, c: Camp) -> void:
	var m := MinionState.new()
	m.setup(PWEE, MatchSim.BLUE, c.home)
	m.team = -1
	m.lane_dir = Vector2.ZERO
	sim.register(m)
	sim.minions.append(m)
	c.monster = m.id
	c.paid = 0.0
	c.aggro = 0
	c.returning = false
	sim.emit_event(&"camp_spawned", {"camp": c.index, "id": m.id, "pos": c.home})


func _tick_monster(sim: MatchSim, c: Camp, m: MinionState) -> void:
	var cfg := sim.config
	var target := sim.get_entity(c.aggro) as HeroState
	var lost := target == null or not target.alive or sim.is_hidden(target) \
			or target.pos.distance_to(c.home) > cfg.camp_leash \
			or sim.time - c.last_hit > cfg.camp_reset_time
	if not c.returning and c.aggro != 0 and lost:
		c.returning = true
		c.aggro = 0
		CombatSystem.cancel(sim, m)
	if c.returning or c.aggro == 0:
		CombatSystem.tick_attack(sim, m, false, func() -> SimEntity: return null)
		var home := c.home - m.pos
		if home.length() > 0.2:
			m.pos = Movement.slide(sim, m, m.pos, home.limit_length(m.data.move_speed * 1.3 * sim.dt))
		else:
			m.pos = c.home
			c.returning = false
		if c.returning or m.hp < m.max_hp:
			m.hp = minf(m.max_hp, m.hp + m.max_hp * cfg.camp_regen_per_second * sim.dt)
		return
	var in_reach := CombatSystem.in_range(sim, m, target)
	if not in_reach and not m.is_winding_up():
		var to := (target.pos - m.pos).normalized()
		m.pos = Movement.slide(sim, m, m.pos, to * m.data.move_speed * sim.dt)
	CombatSystem.tick_attack(sim, m, in_reach or m.is_winding_up(), func() -> SimEntity: return target if in_reach else null)


## A hero hit a Pwee: it turns on them, and they earn their share of the reward.
func on_damaged(sim: MatchSim, m: MinionState, hero: HeroState, dealt: float) -> void:
	var c := camp_of(m)
	if c == null:
		return
	c.aggro = hero.id
	c.returning = false
	c.last_hit = sim.time
	var cfg := sim.config
	var share := minf(dealt / m.max_hp * cfg.camp_damage_share, cfg.camp_damage_share - c.paid)
	if share <= 0.0:
		return
	c.paid += share
	_pay(sim, hero, share, &"camp_hit")


## A Pwee died: the killing hero gets whatever the damage didn't pay out.
func on_killed(sim: MatchSim, m: MinionState, source: SimEntity) -> void:
	var c := camp_of(m)
	if c == null:
		return
	c.monster = 0
	c.respawn_at = sim.time + sim.config.camp_respawn_time
	var hero := source as HeroState
	var moon := HeroState.MOON_NONE
	if hero != null:
		_pay(sim, hero, 1.0 - c.paid, &"camp_kill")
		if sim.phase >= 2:
			moon = HeroState.MOON_WAXING if side_of(c) == hero.team else HeroState.MOON_WANING
			hero.moon = moon
			hero.moon_until = sim.time + sim.config.moon_time
	sim.emit_event(&"camp_cleared", {"camp": c.index, "hero": hero.id if hero != null else 0, "team": hero.team if hero != null else -1, "pos": m.pos, "back_at": c.respawn_at, "moon": moon})
	if moon != HeroState.MOON_NONE:
		sim.emit_event(&"moon_gained", {"hero": hero.id, "team": hero.team, "moon": moon, "until": hero.moon_until})


## Which team's half a camp sits on: the first half of the mirrored list is blue's.
func side_of(c: Camp) -> int:
	return MatchSim.BLUE if c.index < camps.size() / 2 else MatchSim.RED


func _pay(sim: MatchSim, hero: HeroState, fraction: float, reason: StringName) -> void:
	Economy.award(sim, hero, sim.config.camp_gold * fraction, reason)
	Leveling.gain(sim, hero, sim.config.camp_xp * fraction)
