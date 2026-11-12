extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://theme_shot.png"
	var theme: String = args[1] if args.size() > 1 else "newui2"
	var enemy: String = args[2] if args.size() > 2 else "mob_torch"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://theme_shot_save.json")
	save.data.settings["theme"] = theme
	var gd = root.get_node("GameData")
	var rs := RunState.new()
	rs.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var fs := FightScreen.new()
	fs.test_mode = true
	fs.setup(rs, rs.make_fight([enemy]))
	root.add_child(fs)
	await t.create_timer(5.0).timeout
	if args.has("bottles"):  # three bottles carried
		fs.fight.player.bottles = ["fire_flask", "water_flask", "air_flask"]
		fs._h_hud._refresh_all()
		await t.create_timer(1.0).timeout
	if args.has("status"):  # a few statuses on you, to see how the HUD draws them
		var pl = fs.fight.player
		pl.thorns_turn = 2
		pl.poison = 3
		pl.aegis = 1
		pl.vulnerable = 2
		fs._h_hud._refresh_all()
		await t.create_timer(1.0).timeout
	root.get_texture().get_image().save_png(out)
	if args.has("dump"):
		var m = fs._machine
		for n in ["back", "behind", "over", "front"]:
			var node: Control = m.get(n)
			print("== ", n, " pos ", node.position, " size ", node.size, " z ", node.z_index, " show_behind ", node.show_behind_parent, " parent ", node.get_parent().name, " vis ", node.is_visible_in_tree())
			for c in node.get_children():
				if c is TextureRect:
					print("   ", c.texture.resource_path.get_file() if c.texture else "null", " pos ", c.position, " size ", c.size, " vis ", c.visible, " global ", c.get_global_rect())
	if args.has("layers"):  # one still per machine layer switched off (back / over / front), to see which one draws what
		var m = fs._machine
		for n in ["back", "over", "front", "behind"]:
			var node: Control = m.get(n)
			node.visible = false
			await t.process_frame
			await t.process_frame
			root.get_texture().get_image().save_png(out.replace(".png", "_no_%s.png" % n))
			node.visible = true
	t.quit()
