extends TestCase
## Phase IV visuals: the shared hero animator and the street-occult art.


func _rig(blue := 0) -> Array:
	var sim := new_sim(false, blue, 1)
	place(sim.heroes[0], Vector2(0, -2.0))
	place(sim.heroes[1], Vector2(0, 2.0))
	var anim := HeroAnimator.new()
	anim.reset(sim)
	sim.sim_event.connect(anim.on_sim_event)
	var pose := Node3D.new()
	return [sim, anim, pose]


func test_every_hero_has_its_own_style() -> void:
	var seen := {}
	for data: HeroData in MatchController.HEROES:
		var s := AnimStyle.for_shape(data.shape)
		var sig := "%s|%s|%s|%s|%s" % [s.walk_bob, s.steps_per_m, s.walk_roll_deg, s.strike, s.cast]
		check(not seen.has(sig), "%s has a style of its own" % data.shape)
		seen[sig] = true


func test_idle_hero_breathes_but_stays_put() -> void:
	var r := _rig()
	var sim: MatchSim = r[0]
	var pose: Node3D = r[2]
	r[1].animate(sim.heroes[0], pose, 1.0, 1.0 / 60.0)
	check(pose.position.length() < 0.01, "idle hero stays on the spot")
	pose.free()


func test_walking_bobs_and_leans_forward() -> void:
	var r := _rig()
	var sim: MatchSim = r[0]
	var h: HeroState = sim.heroes[0]
	var pose: Node3D = r[2]
	var max_y := 0.0
	for i in 20:
		h.prev_pos = h.pos
		h.pos += Vector2(0, h.data.move_speed * sim.dt)
		r[1].animate(h, pose, 1.0, sim.dt)
		max_y = maxf(max_y, pose.position.y)
	check(max_y > 0.02, "walk cycle bobs")
	check(pose.rotation_degrees.x < 0.0, "walking leans forward")
	pose.free()


func test_basic_attack_winds_up_then_lunges() -> void:
	var r := _rig(4)  # Slayer: a lunging striker.
	var sim: MatchSim = r[0]
	var h: HeroState = sim.heroes[0]
	var pose: Node3D = r[2]
	h.windup_left = h.attack_windup * 0.2
	r[1].animate(h, pose, 1.0, sim.dt)
	check(pose.position.z > 0.0, "windup pulls back")
	h.windup_left = -1.0
	sim.emit_event(&"attack_fired", {"attacker": h.id})
	sim.time += 0.05
	r[1].animate(h, pose, 1.0, sim.dt)
	check(pose.position.z < -0.1, "the strike lunges forward")
	sim.time += 1.0
	r[1].animate(h, pose, 1.0, sim.dt)
	check(absf(pose.position.z) < 0.01, "and settles back")
	pose.free()


func test_ult_pose_is_bigger_than_a_cast() -> void:
	var r := _rig(0)  # Avery: Q raises, R leaps.
	var sim: MatchSim = r[0]
	var h: HeroState = sim.heroes[0]
	var pose: Node3D = r[2]
	var s := AnimStyle.for_shape("paladin")
	sim.emit_event(&"ability_cast", {"hero": h.id, "slot": 0})
	sim.time += s.cast_time / 2.0
	r[1].animate(h, pose, 1.0, sim.dt)
	var cast_y := pose.position.y
	sim.emit_event(&"ability_cast", {"hero": h.id, "slot": 2})
	sim.time += s.ult_time / 2.0
	r[1].animate(h, pose, 1.0, sim.dt)
	check(cast_y > 0.05, "a cast lifts the hero")
	check(pose.position.y > cast_y * 2.0, "the ult leaps much higher")
	pose.free()


func test_hit_staggers_back() -> void:
	var r := _rig()
	var sim: MatchSim = r[0]
	var h: HeroState = sim.heroes[0]
	var pose: Node3D = r[2]
	sim.time += 1.0
	h.last_damaged_time = sim.time - 0.02
	r[1].animate(h, pose, 1.0, sim.dt)
	check(pose.rotation_degrees.x > 3.0, "a hit rocks the hero back")
	pose.free()


func test_hero_parts_live_under_pose() -> void:
	var sim := new_sim(false, 0, 1)
	for h in sim.heroes:
		var node := UnitFactory.make_hero(h, true)
		check(node.get_node_or_null("Body/Pose/GearMid") != null, "%s gear sits in the animated Pose" % h.data.shape)
		node.free()


func test_street_textures_tile_and_cache() -> void:
	var a := StreetArt.stones("test_lane", Palette.LANE, Palette.LANE_MORTAR, 6, 40, 72)
	var b := StreetArt.stones("test_lane", Palette.LANE, Palette.LANE_MORTAR, 6, 40, 72)
	check(a == b, "textures are cached")
	var img := a.get_image()
	check(img.get_width() == StreetArt.TEX_SIZE and img.has_mipmaps(), "cobbles are a mipmapped square")
	for kind in StreetArt.Sigil.values():
		var sig := StreetArt.sigil(kind)
		var px := sig.get_image()
		var ink := 0
		for y in range(0, px.get_height(), 4):
			for x in range(0, px.get_width(), 4):
				if px.get_pixel(x, y).a > 0.5:
					ink += 1
		check(ink > 10, "sigil %d has ink" % kind)
