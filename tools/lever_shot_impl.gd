extends RefCounted
func run(t: SceneTree) -> void:
	t.create_timer(60.0).timeout.connect(t.quit)
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://lever_shot_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var fs := FightScreen.new()
	fs.setup(run, run.make_fight(["ashling"]))
	root.add_child(fs)
	await t.create_timer(3.0).timeout
	var m: SlotMachine = fs._machine
	for k in [0.0, 0.4, 0.7, 1.0]:
		m._set_lever(k)
		await t.create_timer(0.3).timeout
		var img: Image = root.get_texture().get_image()
		img.get_region(Rect2i(1400, 40, 520, 1040)).save_png(out + "/lever_%d.png" % int(k * 10))
	t.quit()
