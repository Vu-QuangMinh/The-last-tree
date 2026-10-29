extends RefCounted
## Frame cost and pile-up check (see perf_probe.gd). Mode "cost": one fight, how long a frame takes. Mode "cycle": fight
## after fight (each played a little: chant, release), printing what the engine holds after each one.


func run(t: SceneTree) -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "cost"
	var root := t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://perf_probe.json")
	var gd = root.get_node("GameData")
	if mode == "empty":
		await _frames(t, "EMPTY")
		return
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	if mode == "cost":
		var f := r.make_fight(["ashling", "iceling"])
		var fs := FightScreen.new()
		fs.setup(r, f)
		root.add_child(fs)
		await t.create_timer(5.0).timeout
		print("DRAWS draw_calls=%d objects=%d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
		if args.size() > 1:
			root.get_texture().get_image().save_png(args[1])
		await _frames(t, "FIGHT")
		return
	var rosters := [["ashling", "iceling"], ["invoker"], ["handyman"], ["yin_yang_beast"], ["veiled_eyes"], ["samurai", "samurai_retainer"], ["dragon_tail", "dragon_head"], ["purple_slime", "green_slime", "yellow_slime"]]
	var cycles := int(args[1]) if args.size() > 1 else 24
	for k in cycles:
		var f := r.make_fight(rosters[k % rosters.size()])
		var fs := FightScreen.new()
		fs.setup(r, f)
		root.add_child(fs)
		await t.create_timer(3.0).timeout
		for turn in 2:
			if f.over:
				break
			f.player.hp = 99
			var n := mini(3, f.player.stock.size())
			var idx: Array[int] = []
			for i in n:
				idx.append(i)
			await f.cast_chant(idx)
			await f.finish_turn()
			fs._refresh_all()
			await t.create_timer(1.0).timeout
		fs.queue_free()
		await t.process_frame
		await t.process_frame
		print("CYCLE %2d objects=%d nodes=%d orphans=%d resources=%d static_mb=%.1f" % [k, Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	if mode == "cycle":
		Node.print_orphan_nodes()


func _frames(t: SceneTree, tag: String) -> void:
	for k in 3:
		var n := 0
		var t0 := Time.get_ticks_usec()
		while Time.get_ticks_usec() - t0 < 2000000:
			await t.process_frame
			n += 1
		print("%s frames_per_sec=%d ms_per_frame=%.2f" % [tag, n / 2, 2000.0 / n])
