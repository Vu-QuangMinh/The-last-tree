extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "C:/temp"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://steal_shot.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := r.make_fight(["veiled_eyes"])
	f.enemies[0].phase = 2
	var bg := ColorRect.new()
	bg.color = Color(0.45, 0.45, 0.45)
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var cr := Creature.new()
	cr.size = Vector2(520, 720)
	cr.position = Vector2(380, -330)
	root.add_child(cr)
	cr.setup(f.enemies[0])
	await t.create_timer(0.4).timeout
	var ghost := SpellCard.make(gd.db.get_spell("elemental_fury"))
	root.add_child(ghost)
	root.move_child(ghost, cr.get_index())  # (behind the spider, as in the fight)
	var spot: Array = cr.steal_card_spot()
	ghost.global_position = spot[0]
	var want := float(spot[1]) / ghost.size.x
	ghost.scale = Vector2(want, want)
	for k in [0.0, 0.5, 1.0]:
		cr.steal_pose = k
		await t.create_timer(0.2).timeout
		root.get_texture().get_image().save_png("%s/steal_%d.png" % [out, int(k * 10)])
	t.quit()
