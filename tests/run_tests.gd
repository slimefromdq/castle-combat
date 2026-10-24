extends SceneTree
## Headless test runner:  godot --headless --path . -s tests/run_tests.gd
## Exits with code 1 if any check fails, so CI goes red.

const SUITES := [
	"res://tests/test_arena.gd",
	"res://tests/test_sim.gd",
	"res://tests/test_movement.gd",
]


func _init() -> void:
	var total := 0
	var failed: Array[String] = []
	for path in SUITES:
		var suite: TestCase = load(path).new()
		for m in suite.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			total += 1
			suite._current = "%s::%s" % [path.get_file().get_basename(), name]
			var before := suite.failures.size()
			suite.call(name)
			print("%s %s" % ["PASS" if suite.failures.size() == before else "FAIL", suite._current])
		failed.append_array(suite.failures)
	print("")
	for f in failed:
		printerr("  " + f)
	print("%d tests, %d failed checks" % [total, failed.size()])
	quit(1 if failed.size() > 0 else 0)
