extends TestCase
## Phase V: code-synthesized sound (src/audio).


func test_every_sound_renders_clean() -> void:
	var t0 := Time.get_ticks_msec()
	for name: StringName in SoundBank.RECIPES:
		var wav := SfxSynth.render(SoundBank.RECIPES[name])
		var n := wav.data.size() / 2
		check(n > SfxSynth.RATE * 0.03 and n < SfxSynth.RATE * 2.5, "%s is 0.03-2.5 s long" % name)
		var peak := 0
		for i in range(0, n, 7):
			peak = maxi(peak, absi(wav.data.decode_s16(i * 2)))
		check(peak > 2000, "%s is audible" % name)
		check(peak < 32700, "%s doesn't clip" % name)
	print("  rendered %d sounds in %d ms" % [SoundBank.RECIPES.size(), Time.get_ticks_msec() - t0])


func test_event_sounds_exist_in_the_bank() -> void:
	for s in MatchAudio.SIMPLE.values():
		check(SoundBank.has(s[0]), "%s is in the bank" % s[0])
	for data: HeroData in MatchController.HEROES:
		check(MatchAudio.ATTACK.has(data.shape) and SoundBank.has(MatchAudio.ATTACK[data.shape]), "%s has an attack sound" % data.id)


func _audio(blue := 0, red := 1) -> MatchAudio:
	var sim := new_sim(false, blue, red)
	place(sim.heroes[0], Vector2(0, -2.0))
	place(sim.heroes[1], Vector2(0, 2.0))
	var a := MatchAudio.new()
	a.sim = sim
	a.seat = MatchSim.BLUE
	return a


func test_basic_attacks_sound_like_the_hero() -> void:
	var a := _audio(1, 8)  # Jose vs Serpent.
	var sim := a.sim
	var s := a.sound_for(&"attack_fired", {"attacker": sim.heroes[0].id, "target": sim.heroes[1].id})
	check(s[0] == &"gunshot" and s[1] == 0.0, "Jose fires a gunshot at full volume")
	s = a.sound_for(&"attack_fired", {"attacker": sim.heroes[1].id, "target": sim.heroes[0].id})
	check(s[0] == &"dart", "Serpent spits a dart")
	a.free()


func test_far_away_fights_are_silent() -> void:
	var a := _audio()
	var far := {"hero": 0, "pos": Vector2(0, 40)}
	var s := a.sound_for(&"drone_zap", far)
	check(s[1] <= -80.0, "a zap 40 m away is silent")
	var near := a.sound_for(&"drone_zap", {"hero": 0, "pos": Vector2(1, -1)})
	check(near[1] > -6.0, "a zap next to you is loud")
	a.free()


func test_only_your_progress_dings() -> void:
	var a := _audio()
	check(a.sound_for(&"level_up", {"team": MatchSim.BLUE})[0] == &"level_up", "your level-up dings")
	check(a.sound_for(&"level_up", {"team": MatchSim.RED}).is_empty(), "theirs doesn't")
	check(a.sound_for(&"item_bought", {"team": MatchSim.BLUE})[0] == &"buy", "buying rings the till")
	check(a.sound_for(&"relay_delivered", {"team": MatchSim.BLUE})[0] == &"relay_deliver", "your delivery gets a fanfare")
	a.free()


func test_every_fermata_instrument_has_a_voice() -> void:
	var a := _audio(9, 1)
	var me := a.sim.heroes[0].id
	check(a.sound_for(&"instrument", {"hero": me, "kind": &"brass", "pos": Vector2.ZERO})[0] == &"brass", "tuba")
	check(a.sound_for(&"instrument", {"hero": me, "kind": &"strings", "pos": Vector2.ZERO})[0] == &"strings", "violin")
	check(a.sound_for(&"strings_pulse", {"id": 1, "pos": Vector2(0, -2)})[0] == &"pizz", "string pulses pluck")
	check(a.sound_for(&"final_note", {"hero": me, "pos": Vector2(0, -2)})[0] == &"final_note", "final note chimes")
	check(a.sound_for(&"ability_cast", {"hero": me, "slot": 2, "ability": &"grand_finale"})[0] == &"finale", "Grand Finale is a chord")
	a.free()


func test_volume_and_mute_settings() -> void:
	var was_v := Sfx.volume
	var was_m := Sfx.muted
	Sfx.set_volume(1.7)
	check(Sfx.volume == 1.0, "volume clamps to 1")
	Sfx.set_muted(true)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "mute mutes the master bus")
	Sfx.set_muted(false)
	Sfx.set_volume(0.5)
	check(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.5)) < 0.01, "volume sets the bus level")
	Sfx.set_volume(was_v)
	Sfx.set_muted(was_m)
