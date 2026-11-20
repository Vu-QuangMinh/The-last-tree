extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://dice_shot.json")
	save.data.settings["theme"] = "puppet"
	var g := DiceGame.new()
	root.add_child(g)
	await t.create_timer(0.5).timeout
	for c in g.get_children():
		if c != g._view:
			c.queue_free()
	g.run.cards = ["punch", "block", "hype_up", "high_knee"]
	g.run.add_die(4)
	g.run.add_die(10)
	for k in 6:
		g.run.paint_face(1, k, "red")
		g.run.carve_face(2, k, "skull")
	g._fight(["ashling", "purple_slime"], "fight")
	var last := 0.0
	for k in [0.6, 1.25, 1.55, 1.8, 2.6]:
		await t.create_timer(k - last).timeout
		last = k
		root.get_texture().get_image().save_png(out + "/d3_%03d.png" % int(k * 100))
	var fv: DiceFightView = g._view
	fv.fight.rolled[0].value = 7
	fv.fight.rolled[3].value = 2
	fv.fight.rolled[4].value = 7
	fv._refresh()
	await t.create_timer(0.2).timeout
	root.get_texture().get_image().save_png(out + "/d3_glyphs.png")
	fv._place(2, 0, 0)
	await t.create_timer(0.3).timeout
	root.get_texture().get_image().save_png(out + "/d3_hype.png")
	fv.fight.rolled[1].rerolled = false
	fv.fight.rolled[1].paint = "purple"
	fv.fight.reroll(1)
	fv._refresh()
	await t.create_timer(0.25).timeout
	root.get_texture().get_image().save_png(out + "/d3_hop.png")
	await t.create_timer(0.6).timeout
	root.get_texture().get_image().save_png(out + "/d3_hop2.png")
