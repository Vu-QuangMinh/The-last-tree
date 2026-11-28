extends RefCounted
## See tools/wiggle_shot.gd.


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://wiggle_shot.json")
	save.data.settings["theme"] = "puppet"
	var m: Main = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	await t.create_timer(0.5).timeout
	m.show_map()
	await t.create_timer(3.0).timeout
	m._choice("Victory", "Take one card.", m.run.spell_offer(3, "fight"), [], true)
	await t.create_timer(2.0).timeout
	var ws := root.find_children("*", "Wiggle", true, false)
	print("wiggles: ", ws.size())
	if not ws.is_empty():
		ws[1]._over = true  # (the middle card, hovered)
	await t.create_timer(0.6).timeout
	root.get_texture().get_image().save_png(out + "/w1_reward_hover.png")
	m._marble_choice("Victory", "Choose a marble for your bag.", m.run.marble_offer(3), func(): pass)
	await t.create_timer(0.8).timeout
	ws = root.find_children("*", "Wiggle", true, false)
	ws[ws.size() - 1]._over = true
	await t.create_timer(0.6).timeout
	root.get_texture().get_image().save_png(out + "/w2_marble_hover.png")
