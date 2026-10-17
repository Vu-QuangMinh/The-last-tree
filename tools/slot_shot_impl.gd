extends RefCounted
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://slot_shot_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := run.make_fight(["ashling"])
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	var k := 0
	for i in 70:
		await t.create_timer(0.25).timeout
		if i == 40:
			print("t=10 reels ", fs._reel_shown, " armed ", fs._reels_armed, " next ", f.player.next_draw.map(func(x): return x.el))
			fs._on_end_turn()
		if i % 2 == 0:
			root.get_texture().get_image().save_png(out + "/f%02d.png" % k)
			k += 1
	print("end: stock ", f.player.stock.map(func(x): return x.el), " reels ", fs._reel_shown, " armed ", fs._reels_armed, " next ", f.player.next_draw.map(func(x): return x.el), " turn ", f.turn)
	t.quit()
