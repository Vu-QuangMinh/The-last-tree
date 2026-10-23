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
	var enemies: Array = ["handyman", "yellow_slime"]
	r.encounter = enemies.duplicate()
	r.encounter_extra = enemies.map(func(id): return EnemyDefs.extra_for(id, 1, r.depth(), r.rng, 1))
	var f := r.make_fight(enemies)
	var fs := FightScreen.new()
	fs.test_mode = true
	fs.setup(r, f)
	root.add_child(fs)
	await t.create_timer(4.0).timeout
	print("views: ", fs._views.keys().map(func(e): return e.id))
	t.quit()
