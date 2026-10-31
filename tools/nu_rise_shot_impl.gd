extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://nu_rise_save.json")
	save.data.settings["theme"] = "new_ui"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, [], [], 0)
	var ids: Array = TestModeScreen.STRONGEST
	r.spellbook = ids.duplicate()
	r.loadout = ids.duplicate()
	r.act = 1
	r.row = 4
	var enemies: Array = ["winged_tortoise"]
	r.encounter = enemies.duplicate()
	r.encounter_extra = enemies.map(func(id): return EnemyDefs.extra_for(id, 1, r.depth(), r.rng, 1))
	var f := r.make_fight(enemies)
	var fs := FightScreen.new()
	fs.setup(r, f)
	root.add_child(fs)
	var guard := t.create_timer(120.0)
	guard.timeout.connect(t.quit)
	await t.create_timer(5.0).timeout
	fs._on_end_turn()
	var frames := 0
	var t0 := Time.get_ticks_msec()
	var k := root.get_texture().get_image().get_width() / 1920.0
	while Time.get_ticks_msec() - t0 < 14000:
		await t.process_frame
		frames += 1
		var moving: Array = []
		for c in fs._stock_row.get_children():
			if c is ElementIcon and c.modulate.a > 0.01 and (c.scale.x < 0.99 or c.has_meta("rolling") or c.position.x > 700.0):
				moving.append("%s(%.0f,%.0f s%.2f a%.1f)" % [c.el, c.position.x + 26.0, c.position.y + 26.0, c.scale.x, c.modulate.a])
		if not moving.is_empty() and frames % 4 == 0:
			var img: Image = root.get_texture().get_image()
			img.get_region(Rect2i(int(1000 * k), int(950 * k), int(660 * k), int(130 * k))).save_png(out + "/rise_%04d.png" % frames)
			print("t=%d  %s" % [Time.get_ticks_msec() - t0, " ".join(moving)])
	# the Bag's orbs rest at 85 % and 7 px higher; in the chant they are full size again; back in the Bag they shrink again
	await t.create_timer(1.0).timeout
	var uid: int = fs.fight.player.stock[0].uid
	var ic0: Control = fs._bag_icons[uid]
	print("rest: scale ", ic0.scale, " middle ", fs._bag_center(uid), " target ", fs._bag_target_center(uid))
	img_save(root, out + "/bag_rest.png")
	fs._add_stock_index(0)
	await t.create_timer(0.7).timeout
	print("in chant: ", fs._chant_px(), " px")
	img_save(root, out + "/bag_chant.png")
	fs._remove_from_chant(0)
	await t.create_timer(0.8).timeout
	var ic1: Control = fs._bag_icons[fs.fight.player.stock[0].uid]
	print("back: pos ", ic1.position, " pivot ", ic1.pivot_offset, " meta ", ic1.get_meta_list(), " scale ", ic1.scale, " middle ", fs._bag_center(fs.fight.player.stock[0].uid), " target ", fs._bag_target_center(fs.fight.player.stock[0].uid))
	img_save(root, out + "/bag_back.png")
	t.quit()


func img_save(root: Window, path: String) -> void:
	root.get_texture().get_image().save_png(path)
