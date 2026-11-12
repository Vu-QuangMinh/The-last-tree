extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "C:/temp"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://invoker_cards_shot.json")
	save.data.settings["theme"] = "newui2"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := run.make_fight(["invoker"])
	f.talk_id = ""  # (straight to the fight)
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await t.create_timer(4.0).timeout
	root.get_texture().get_image().save_png(dir + "/invoker_1.png")
	var e: EnemyState = f.enemies[0]
	f.heard = ""
	f._do_move(e, e.intent)  # (a turn: the first Essence of each becomes Any)
	await t.create_timer(1.5).timeout
	fs._refresh_all()
	await t.create_timer(1.0).timeout
	root.get_texture().get_image().save_png(dir + "/invoker_2_converted.png")
	e.elements.clear()
	f._cleanup()
	await t.create_timer(8.0).timeout
	f._do_move(e, e.intent)
	f._plan(e)
	fs._refresh_all()
	await t.create_timer(2.5).timeout
	root.get_texture().get_image().save_png(dir + "/invoker_3_phase2.png")
	t.quit()
