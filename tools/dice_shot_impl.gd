extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://dice_shot.json")
	save.data.settings["theme"] = "puppet"
	var g := DiceGame.new()
	root.add_child(g)
	await t.create_timer(2.0).timeout
	root.get_texture().get_image().save_png(out + "/dice_map.png")
	for k in 12:  # (12 moves forward, the first way each time: the boss has started walking)
		var o: Array = g.run.options()
		if o.is_empty():
			break
		g.run.move_to(o[0].x, o[0].y)
		if g.run.caught():
			break
	g.show_map()
	await t.create_timer(1.0).timeout
	root.get_texture().get_image().save_png(out + "/dice_map2.png")
	g._artifact_choice("+30 Leaves.", g.run.artifact_offer(3))
	await t.create_timer(0.6).timeout
	root.get_texture().get_image().save_png(out + "/dice_artifacts.png")
	for c in g.get_children():
		if c != g._view:
			c.queue_free()
	g.run.cards = ["punch", "block", "discombobulate", "high_knee"]
	for k in 6:  # (modded dice to see: die 1 red with hearts, die 2 purple, die 3 carved with a skull, half of it blue)
		g.run.paint_face(0, k, "red")
		g.run.carve_face(0, k, "heart")
		g.run.paint_face(1, k, "purple")
		g.run.carve_face(2, k, "skull")
		if k % 2 == 0:
			g.run.paint_face(2, k, "blue")
	g._fight(["ashling", "purple_slime"], "fight")
	for k in [0.55, 1.1, 2.0, 2.9]:
		await t.create_timer(k - (0.0 if k == 0.55 else [0.55, 1.1, 2.0, 2.9][[0.55, 1.1, 2.0, 2.9].find(k) - 1])).timeout
		root.get_texture().get_image().save_png(out + "/dice_throw_%d.png" % int(k * 100))
	var fv: DiceFightView = g._view
	fv._place(0, 0, 0)  # (a die into Punch: two enemies, so it asks for its target)
	await t.create_timer(0.4).timeout
	root.get_texture().get_image().save_png(out + "/dice_fight.png")
	g._die_reward({"dmod": "carve", "carve": "wing"})
	await t.create_timer(0.6).timeout
	root.get_texture().get_image().save_png(out + "/dice_reward.png")
	for c in g.get_children():
		if c != g._view:
			c.queue_free()
	g.run.leaves = 120
	g._shop()
	await t.create_timer(0.8).timeout
	root.get_texture().get_image().save_png(out + "/dice_shop.png")
	t.quit()
