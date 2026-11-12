extends SceneTree
## Headless unit-test runner (the only one). Starts after the first frame so the autoloads (Audio, SaveManager, GameData) exist.
##   "C:\Program Files\Godot\Godot.exe" --headless --path . --script res://tests/run_tests.gd [-- filter]
## filter = part of "test_file.gd:test_name". Exit 0 = all passed, 1 = a test failed, 2 = the 240 s guard fired.
## Collects the engine errors (script errors, failed calls) raised while a test runs: a test that hits one has failed.
class ErrorCatcher extends Logger:
	var errors: Array[String] = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		errors.append("%s (%s:%d)" % [rationale if rationale != "" else code, file.get_file(), line])


func _init() -> void:
	await process_frame
	create_timer(240.0).timeout.connect(func(): quit(2))
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var total := 0
	var failed := 0
	var files: Array = Array(DirAccess.get_files_at("res://tests")).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd")
	files.sort()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			total += 1
			failed += 1
			print("FAIL %s: script failed to load" % f)
			continue
		for m in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_") or (filter != "" and not (f + ":" + name).contains(filter)):
				continue
			total += 1
			var inst = script.new()
			catcher.errors.clear()
			inst.call(name)
			var problems: Array = Array(inst.failures) + catcher.errors.map(func(e): return "engine error: " + e)
			if problems.size() > 0:
				failed += 1
				print("FAIL %s:%s" % [f, name])
				for msg in problems:
					print("    " + msg)
	print("%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
