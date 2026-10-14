extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://tm_shot_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, [], [], 0)
	r.artifacts.clear()
	var ids: Array = TestModeScreen.STRONGEST
	r.spellbook = ids.duplicate()
	r.loadout = ids.duplicate()
	r.act = 1
	r.row = 4
	var enemies: Array = ["handyman"]
	r.encounter = enemies.duplicate()
	r.encounter_extra = enemies.map(func(id): return EnemyDefs.extra_for(id, 1, r.depth(), r.rng, 1))
	var f := r.make_fight(enemies)
	var fs := FightScreen.new()
	fs.test_mode = true
	fs.setup(r, f)
	root.add_child(fs)
	await t.create_timer(4.0).timeout
	_shot(root, out + "/tm_start.png")
	fs._auto_ball()
	await t.create_timer(4.5).timeout
	_shot(root, out + "/tm_ball.png")
	print("bag: ", f.player.stock.map(func(s): return s.el))
	var t0 := Time.get_ticks_msec()
	fs._auto_fill()
	await t.create_timer(4.0).timeout
	print("chant: ", fs._chant_string(), "  (took ", Time.get_ticks_msec() - t0, " ms incl. animation)")
	_shot(root, out + "/tm_fill.png")
	var woke := 0
	for sp in f.usable_spells():
		if not f._occ(sp, fs._chant_string()).is_empty():
			woke += 1
	print("spells awake: ", woke, " of ", f.usable_spells().size())
	t.quit()


func _shot(root: Window, path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
