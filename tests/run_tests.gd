extends SceneTree
## Headless test runner:  godot --headless --path . -s tests/run_tests.gd
## Exits with code 1 if any check fails, so CI goes red.

const SUITES := [
	"res://tests/test_arena.gd",
	"res://tests/test_sim.gd",
	"res://tests/test_movement.gd",
	"res://tests/test_combat.gd",
	"res://tests/test_structures.gd",
	"res://tests/test_aggro.gd",
	"res://tests/test_relay.gd",
	"res://tests/test_economy.gd",
	"res://tests/test_abilities.gd",
	"res://tests/test_items.gd",
	"res://tests/test_qol.gd",
	"res://tests/test_pacing.gd",
	"res://tests/test_power_spikes.gd",
	"res://tests/test_waves.gd",
	"res://tests/test_wave_depth.gd",
	"res://tests/test_playtest_gameplay.gd",
	"res://tests/test_playtest_ui.gd",
	"res://tests/test_menu.gd",
	"res://tests/test_stats.gd",
	"res://tests/test_kits.gd",
	"res://tests/test_candles.gd",
	"res://tests/test_progression.gd",
	"res://tests/test_occult.gd",
	"res://tests/test_view.gd",
	"res://tests/test_audio.gd",
	"res://tests/test_last_stand.gd",
]


func _init() -> void:
	var total := 0
	var failed: Array[String] = []
	# Optional filter: godot --headless --path . -s tests/run_tests.gd -- combat
	var filter := OS.get_cmdline_user_args()
	for path in SUITES:
		if filter.size() > 0 and not path.contains(filter[0]):
			continue
		var suite: TestCase = load(path).new()
		for m in suite.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			total += 1
			suite._current = "%s::%s" % [path.get_file().get_basename(), name]
			var before := suite.failures.size()
			var started := Time.get_ticks_msec()
			suite.call(name)
			print("%s %s (%d ms)" % ["PASS" if suite.failures.size() == before else "FAIL", suite._current, Time.get_ticks_msec() - started])
		failed.append_array(suite.failures)
	print("")
	for f in failed:
		printerr("  " + f)
	print("%d tests, %d failed checks" % [total, failed.size()])
	quit(1 if failed.size() > 0 else 0)
