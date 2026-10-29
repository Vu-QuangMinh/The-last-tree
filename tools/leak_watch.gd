extends SceneTree
## Plays runs through the real UI (sped up, see ui_playtest_impl.gd) and prints what the engine is holding every few
## seconds, to find what piles up over a long session.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/leak_watch.gd -- <out dir> [seconds]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var secs := float(args[1]) if args.size() > 1 else 300.0
	create_timer(secs + 30.0, true, false, true).timeout.connect(quit)
	await process_frame
	_watch(secs)
	while true:
		var impl = load("res://tools/ui_playtest_impl.gd").new()
		await impl.run(self, args[0] if args.size() > 0 else "user://leak_watch")
		for c in root.get_children():
			if c.scene_file_path == "res://scenes/main.tscn":
				c.queue_free()
		await process_frame


func _watch(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < secs:
		await create_timer(10.0, true, false, true).timeout
		var players := root.find_children("*", "AudioStreamPlayer", true, false).size()
		print("LEAK t=%ds objects=%d nodes=%d orphans=%d resources=%d static_mb=%.1f tex_mb=%.1f tweens=%d audio=%d fps=%d" % [
			(Time.get_ticks_msec() - t0) / 1000,
			Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
			get_processed_tweens().size(), players,
			Performance.get_monitor(Performance.TIME_FPS)])
	Node.print_orphan_nodes()
	quit()
