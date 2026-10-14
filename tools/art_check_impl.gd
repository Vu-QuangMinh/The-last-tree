extends RefCounted
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://art_check.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := r.make_fight(["greenseer", "yeti"])
	var fs := FightScreen.new()
	fs.setup(r, f)
	fs.stage_flow = true
	root.add_child(fs)
	await t.create_timer(3.0).timeout
	var p := f.player
	p.silenced[f.loadout[0].id] = 2
	p.locks[f.loadout[1].id] = "FW"
	p.used_powers[f.loadout[2].id] = true
	fs._refresh_all()
	# a blinded Essence
	p.blind_turns = 2
	fs._refresh_all()
	fs._show_help()
	await t.create_timer(1.5).timeout
	root.get_texture().get_image().save_png(out + "/art1.png")
	fs._stage.drop_sign("Perfect Victory!", Color(0.3, 0.17, 0.07), "perfect_victory")
	await t.create_timer(2.5).timeout
	root.get_texture().get_image().save_png(out + "/art2.png")
	t.quit()
