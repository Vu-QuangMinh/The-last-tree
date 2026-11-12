extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "C:/temp"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://card_row_shot.json")
	save.data.settings["theme"] = args[1] if args.size() > 1 else "minhhud"
	var gd = root.get_node("GameData")
	var ids := ["tailwind", "flame_lash", "hush_of_rain", "updraft", "ember", "droplet", "whisper", "fire_ball"]
	for count in [5, 8]:
		var run := RunState.new()
		run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
		run.loadout = ids.slice(0, count).filter(func(id): return not gd.db.get_spell(id).is_empty())
		var f := run.make_fight(["greenseer"])
		var fs := FightScreen.new()
		fs.setup(run, f)
		root.add_child(fs)
		await t.create_timer(4.0).timeout
		root.get_texture().get_image().save_png("%s/cards_%d.png" % [dir, count])
		var xs := []
		for c in fs._cards:
			var r: Rect2 = c.get_global_rect()
			xs.append("%d-%d" % [roundi(r.position.x), roundi(r.end.x)])
		print("%d cards: %s" % [count, " ".join(xs)])
		fs.queue_free()
		await t.process_frame
	t.quit()
