extends RefCounted
## F7, the text inspector, on the main menu: pick the Play button, change its group, then Cancel (a still each): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/header_shots.gd -- <out folder>
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://header_shots.json")
	save.data.settings["theme"] = "puppet"
	UiTheme.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await t.create_timer(1.5).timeout
	TextInspector.toggle(main)
	await t.create_timer(0.5).timeout
	var ins = TextInspector._open
	print("paused: ", t.paused)
	ins._on_catcher_click(Vector2(960, 757))  # (More...)
	await t.create_timer(0.3).timeout
	ins._edit.text = "Extras..."
	ins._words_changed()
	ins._nudge(Vector2(30, 0))
	await t.create_timer(0.3).timeout
	root.get_texture().get_image().save_png(out + "/ins_1_this_text.png")
	ins.save()
	var txt := FileAccess.get_file_as_string(save.path)
	print("saved file has text_styles: ", txt.contains("text_styles"), "  dx: ", txt.contains("\"dx\""))
	await t.create_timer(0.3).timeout
	main.show_menu()
	await t.create_timer(1.5).timeout
	root.get_texture().get_image().save_png(out + "/ins_2_after_save.png")
	print("INS DONE")
	t.quit()
