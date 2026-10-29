extends SceneTree
## Opens a fight in the real screen and prints frame cost every 3 s (what the engine spends per frame).
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/perf_probe.gd -- [enemies,comma] [act]


func _init() -> void:
	create_timer(500.0, true, false, true).timeout.connect(quit)
	await process_frame
	await load("res://tools/perf_probe_impl.gd").new().run(self)
	quit()
