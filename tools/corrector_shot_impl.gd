extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://corrector_shot_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := run.make_fight(["corrector"])
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await t.create_timer(4.0).timeout
	var e: EnemyState = f.enemies[0]
	e.elements.clear()
	e.armor.clear()
	f._cleanup()
	e.move_index = 1
	f._plan(e)
	fs._refresh_all()
	await t.create_timer(1.0).timeout
	root.get_texture().get_image().save_png(out + "/corrector.png")
	t.quit()
