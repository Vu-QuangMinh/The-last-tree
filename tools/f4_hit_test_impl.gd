extends RefCounted

func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://puppet_shot_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := run.make_fight(["greenseer", "yin_yang_clone", "rolling_bear"])
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await t.create_timer(3.0).timeout
	var e := InputEventKey.new(); e.keycode = KEY_F4; e.pressed = true
	root.push_input(e)
	await t.create_timer(0.3).timeout
	var st = fs._stage
	print("window ", root.size, " stage ", st.size)
	for n in st._edit_btns:
		var b: Button = st._edit_btns[n]
		var c: Vector2 = root.get_final_transform() * b.get_global_rect().get_center()
		var mv := InputEventMouseMotion.new(); mv.position = c; mv.global_position = c
		root.push_input(mv)
		await t.process_frame
		await t.process_frame
		var hc := root.gui_get_hovered_control()
		var hp: String = str(hc.get_path()) if hc != null else "none"
		print(n, " at ", c, " hover=", hc, " ", hp, "  ", "OK" if hc == b else "BLOCKED")
	t.quit()
