extends RefCounted

func run(t: SceneTree) -> void:
	var root: Window = t.root
	var theme := "puppet"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		theme = args[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://turn_timing_save.json")
	save.data.settings["theme"] = theme
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := run.make_fight(["greenseer", "rolling_bear"])
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	var t0 := Time.get_ticks_msec()
	var last := ""
	var turns_done := 0
	var state := "wait_ready"
	var state_t := t0
	while turns_done < 3 and Time.get_ticks_msec() - t0 < 60000:
		await t.process_frame
		var rolling := 0
		for uid in fs._bag_icons:
			if fs._bag_icons[uid].has_meta("rolling"):
				rolling += 1
		var snap := "phase=%s busy=%s launching=%d prep=%s rollin=%d rolling=%d chant=%d tube=%d" % [fs.phase, fs.busy, fs._launching, fs._tube_prep, fs._rolling_in, rolling, fs.chant_idx.size(), fs._tube_icons.size()]
		if snap != last:
			print("%6d  %s" % [Time.get_ticks_msec() - t0, snap])
			last = snap
		var ready: bool = fs.phase == "build" and not fs.busy and fs._launching == 0 and not fs._tube_prep and fs._rolling_in == 0 and rolling == 0
		if state == "wait_ready" and ready and Time.get_ticks_msec() - state_t > 300:
			print("%6d  >>> READY, chanting" % (Time.get_ticks_msec() - t0))
			for i in mini(3, f.player.stock.size()):
				fs._add_stock_index(0)
			state = "chanted"
			print("%6d  >>> cast" % (Time.get_ticks_msec() - t0))
			fs._on_cast()
			state = "casting"
			state_t = Time.get_ticks_msec()
		elif state == "casting" and fs.phase == "spells" and not fs.busy:
			print("%6d  >>> cast done, release" % (Time.get_ticks_msec() - t0))
			fs._on_end_turn()
			state = "released"
		elif state == "released" and fs.phase == "build" and not fs.busy:
			turns_done += 1
			print("%6d  >>> TURN %d over (back in build)" % [Time.get_ticks_msec() - t0, turns_done])
			state = "wait_ready"
			state_t = Time.get_ticks_msec()
	t.quit()
