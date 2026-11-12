extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://pianist_pose_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var rs := RunState.new()
	rs.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := rs.make_fight(["pianist"])
	var fs := FightScreen.new()
	fs.test_mode = true
	fs.setup(rs, f)
	root.add_child(fs)
	await t.create_timer(4.0).timeout
	fs._pianist_start()
	var cr: Creature = null
	for v in fs._views.values():
		cr = v.creature
	await t.create_timer(6.0).timeout
	_shot(root, out, "pose_play")
	await t.create_timer(0.07).timeout
	_shot(root, out, "pose_play2")
	cr.pianist_point(5.0)
	await t.create_timer(1.0).timeout
	_shot(root, out, "pose_point")
	cr.pianist_point(0.0)
	cr.page_flip = 0.3
	await t.create_timer(0.5).timeout
	_shot(root, out, "pose_page")
	cr.page_flip = -1.0
	cr.pianist_slam()
	await t.create_timer(0.7).timeout
	_shot(root, out, "pose_slam")
	t.quit()


func _shot(root: Window, out: String, name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
