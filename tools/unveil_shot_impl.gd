extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "C:/temp"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://unveil_shot.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := r.make_fight(["veiled_eyes"])
	var bg := ColorRect.new()
	bg.color = Color(0.45, 0.45, 0.45)
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var cr := Creature.new()
	cr.size = Vector2(520, 720)
	cr.position = Vector2(380, 0)
	root.add_child(cr)
	cr.setup(f.enemies[0])
	cr.hypnotize(30.0)
	await t.create_timer(0.5).timeout
	root.get_texture().get_image().save_png("%s/unveil_p1.png" % out)
	for k in 3:  # (the veil sways: three frames)
		await t.create_timer(1.3).timeout
		root.get_texture().get_image().save_png("%s/unveil_p1_%d.png" % [out, k])
	f.enemies[0].phase = 2
	var at := 0.0
	for tt in [0.1, 0.5, 0.9, 1.5, 2.9, 3.4, 3.9, 4.4, 4.9, 5.6]:
		await t.create_timer(tt - at).timeout
		at = tt
		root.get_texture().get_image().save_png("%s/unveil_%03d.png" % [out, int(tt * 100)])
	t.quit()
