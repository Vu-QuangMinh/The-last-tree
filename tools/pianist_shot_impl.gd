extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://pianist_shot_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var rs := RunState.new()
	rs.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := rs.make_fight(["pianist"])
	var fs := FightScreen.new()
	fs.test_mode = true
	fs.setup(rs, f)
	root.add_child(fs)
	await t.create_timer(5.0).timeout
	fs._pianist_start()
	await t.create_timer(1.5).timeout
	root.get_texture().get_image().save_png(out + "/pianist.png")
	for v in fs._views.values():
		v.creature.page_flip = 0.3
	await t.create_timer(0.3).timeout
	var img := root.get_texture().get_image()
	img.get_region(Rect2i(700, 300, 520, 300)).save_png(out + "/pianist_page.png")
	t.quit()
