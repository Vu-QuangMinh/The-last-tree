extends SceneTree
## tests/run_tests.gd, but started after the autoloads exist (the test files name Audio / SaveManager, which `--script` can't see):
##   godot --headless --path . -s tools/run_tests_auto.gd [-- filter]
func _init() -> void:
	await process_frame
	create_timer(240.0).timeout.connect(func(): quit(2))
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
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
			inst.call(name)
			if inst.failures.size() > 0:
				failed += 1
				print("FAIL %s:%s" % [f, name])
				for msg in inst.failures:
					print("    " + msg)
	print("%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
