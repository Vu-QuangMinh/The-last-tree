extends RefCounted
## See tools/marble_pick_shot.gd.


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://marble_pick_shot.json")
	save.data.settings["theme"] = "puppet"
	var m: Main = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	await t.create_timer(0.5).timeout
	root.warp_mouse(Vector2(1900, 1070))
	m._marble_choice("Victory", "Choose a marble for your bag.", [{"c": "F", "sym": ""}, {"c": "W", "sym": "shield"}, {"c": "A", "sym": "star"}], func(): pass)
	await t.create_timer(1.0).timeout
	root.get_texture().get_image().save_png(out + "/marble_pick.png")
