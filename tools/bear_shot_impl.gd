extends RefCounted
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://bear_shot.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 3)
	var fs := FightScreen.new()
	fs.setup(r, r.make_fight([]))
	fs.stage_flow = true
	fs.map_mode = true
	root.add_child(fs)
	await t.create_timer(2.5).timeout
	var sc := BearRollScene.new()
	sc.on_stage = true
	sc.mode = OS.get_environment("SHOT_MODE") if OS.get_environment("SHOT_MODE") != "" else "meet"
	sc.z_index = PuppetStage.CEILING_Z + 2
	fs.add_child(sc)
	await t.create_timer(1.0).timeout
	root.get_texture().get_image().save_png(out + "/bear_1_rolling.png")
	var m := InputEventMouseMotion.new()
	m.position = Vector2(sc._x, sc._feet - 150.0)
	sc._gui_input(m)
	await t.create_timer(0.4).timeout
	root.get_texture().get_image().save_png(out + "/bear_2_hover.png")
	var c := InputEventMouseButton.new()
	c.button_index = MOUSE_BUTTON_LEFT
	c.pressed = true
	c.position = m.position
	sc._gui_input(c)
	await t.create_timer(2.6).timeout
	root.get_texture().get_image().save_png(out + "/bear_2b_bubble.png")
	await t.create_timer(3.0).timeout
	root.get_texture().get_image().save_png(out + "/bear_3_coins.png")
	await t.create_timer(0.5).timeout
	root.get_texture().get_image().save_png(out + "/bear_4_after.png")
	t.quit()
