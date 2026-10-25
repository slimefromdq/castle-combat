extends TestCase
## Lucy's UI playtest pass: aimed skillshots, the match clock, the camera clamp.

const AVERY := 0
const JOSE := 1
const JACK := 2


func _sim(blue: int, red: int) -> MatchSim:
	var sim := new_sim(false, blue, red)
	place(sim.heroes[0], Vector2(0, -2.0))
	place(sim.heroes[1], Vector2(0, 4.0))
	sim.heroes[1].attack_damage = 0.0
	return sim


func _level(sim: MatchSim, h: HeroState, lv: int) -> void:
	Leveling.gain(sim, h, float(sim.config.level_xp[lv - 1]) - h.xp + 0.01)


func _cast(sim: MatchSim, slot: int, aim: Vector2) -> void:
	var cmd := PlayerCommand.new()
	cmd.cast_slot = slot
	cmd.aim = aim
	sim.step([cmd, null])


func _shot(sim: MatchSim) -> Skillshot:
	return sim.skillshots[sim.skillshots.size() - 1] if not sim.skillshots.is_empty() else null


func test_aimed_skillshot_flies_where_you_aim() -> void:
	var sim := _sim(AVERY, JOSE)
	var blue := sim.heroes[0]
	_level(sim, blue, 5)
	_cast(sim, 2, Vector2(1, 0))
	var shot := _shot(sim)
	check(shot != null, "blade thrown")
	check(shot != null and shot.dir.dot(Vector2(1, 0)) > 0.99, "flies right, away from the enemy hero in front (no auto-aim)")
	run_ticks(sim, 30)
	check(sim.heroes[1].hp == sim.heroes[1].max_hp, "a miss is a miss")


func test_aiming_at_the_hero_hits() -> void:
	var sim := _sim(AVERY, JOSE)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	_level(sim, blue, 5)
	_cast(sim, 2, (red.pos - blue.pos).normalized())
	run_until(sim, func() -> bool: return red.hp < red.max_hp, 30)
	check(red.is_stunned(sim.time), "aimed blade lands")


func test_bots_still_auto_aim() -> void:
	var sim := _sim(AVERY, JOSE)
	var blue := sim.heroes[0]
	var red := sim.heroes[1]
	place(red, Vector2(3, 3))
	_level(sim, blue, 5)
	_cast(sim, 2, Vector2.ZERO)
	var shot := _shot(sim)
	check(shot != null and shot.dir.dot((red.pos - blue.pos).normalized()) > 0.99, "no aim given: aims at the hero")


func test_cloak_and_dash_follow_the_aim() -> void:
	var sim := _sim(JACK, JOSE)
	var blue := sim.heroes[0]
	_cast(sim, 0, Vector2(-1, 0))
	var shot := _shot(sim)
	check(shot != null and shot.dir.dot(Vector2(-1, 0)) > 0.99, "cloak goes left")
	var sim2 := _sim(JOSE, AVERY)
	var jose := sim2.heroes[0]
	var start := jose.pos
	_cast(sim2, 0, Vector2(1, 0))
	run_ticks(sim2, 20)
	check(jose.pos.x - start.x > 1.0 and absf(jose.pos.y - start.y) < 0.5, "dash goes right (%s)" % [jose.pos - start])
	check(blue.facing.dot(Vector2(-1, 0)) > 0.99, "Jack turned to throw")


func test_camera_keeps_the_hero_on_screen_in_the_side_pockets() -> void:
	var rig := CameraRig.new()
	rig.half_width = ArenaGeometry.half_width(MatchController.ARENA)
	var hw := rig.half_view_width()
	check(rig.half_width > 11.0, "the side pockets reach past 11 m (got %.2f)" % rig.half_width)
	for x in [-11.0, -6.0, 0.0, 4.0, 11.0]:
		var cam: float = rig._clamp_side(x)
		check(absf(x - cam) <= hw - CameraRig.HERO_SIDE_MARGIN + 0.001, "hero at x=%.1f stays on screen (camera %.2f)" % [x, cam])
		check(absf(cam) + hw <= rig.half_width + CameraRig.EDGE_MARGIN + 0.001, "the view stays inside the map's sides at x=%.1f" % x)
	check(rig._clamp_side(0.0) == 0.0, "centred in mid-lane")
	rig.free()


func test_overtime_clock() -> void:
	var sim := new_sim()
	check(Pacing.overtime_at(sim) == sim.config.overtime_time, "overtime at 10:00 by default")
	for s in sim.structures_of(MatchSim.RED):
		if s.is_guardian():
			s.alive = false
	check(Pacing.overtime_at(sim) == sim.config.overtime_late_time, "later once a Guardian has fallen")
