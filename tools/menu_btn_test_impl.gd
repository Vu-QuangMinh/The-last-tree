extends RefCounted
## The Menu button on the stage's map and encounter screens.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/menu_btn_test.gd -- <out folder>
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://menu_btn_test.json")
	save.data.settings["theme"] = "puppet"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await t.create_timer(1.5).timeout
	main.start_run()
	await t.create_timer(6.0).timeout
	main.show_map()
	await t.create_timer(9.0).timeout
	root.get_texture().get_image().save_png(out + "/menu_1_map.png")
	var ids: Array = main.run.encounter_ids()
	print("ids ", ids)
	main._show_loadout(ids)
	await t.create_timer(7.0).timeout
	root.get_texture().get_image().save_png(out + "/menu_2_encounter.png")
	var fs: FightScreen = main.current
	var ev := InputEventMouseButton.new()
	var at: Vector2 = fs._menu_low.get_global_rect().get_center() if fs._menu_low != null and fs._menu_low.visible else fs._menu_btn.get_global_rect().get_center()
	at = at * Vector2(root.size) / Vector2(1920, 1080)
	print("click at ", at)
	for pressed in [true, false]:
		ev = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		root.push_input(ev)
		await t.create_timer(0.2).timeout
	print("pause opened: ", fs._pause_overlay != null)
	print("MENU DONE")
	t.quit()
