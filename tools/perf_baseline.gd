extends SceneTree
## An empty window, for comparing frame rates with perf_probe.gd (same window flags).


func _init() -> void:
	create_timer(30.0, true, false, true).timeout.connect(quit)
	var r := ColorRect.new()
	r.size = Vector2(1920, 1080)
	root.add_child(r)
	for k in 4:
		await create_timer(3.0, true, false, true).timeout
		print("BASE fps=%d process_ms=%.1f" % [Performance.get_monitor(Performance.TIME_FPS), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	quit()
