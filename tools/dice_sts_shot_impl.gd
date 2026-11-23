extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://dice_shot.json")
	save.data.settings["theme"] = "puppet"
	var g := DiceGame.new()
	root.add_child(g)
	await t.create_timer(1.0).timeout
	root.get_texture().get_image().save_png(out + "/sts_map.png")
	var o: Array = g.run.options()
	g.run.move_to(o[0].x, o[0].y)
	g.show_map()
	await t.create_timer(1.0).timeout
	root.get_texture().get_image().save_png(out + "/sts_map2.png")
	g.run.cards = ["punch", "block", "jab"]
	g._card_choice("Treasure", "A chest on the stage. Choose a move.", ["jab", "fire_fist", "spirit_bomb"], g.show_map)
	await t.create_timer(0.62).timeout
	root.get_texture().get_image().save_png(out + "/sts_offer.png")
