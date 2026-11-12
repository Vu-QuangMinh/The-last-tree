extends SceneTree
## The cream dialogue board in the real flow: the merchant's conversation (Test mode > Events > The Merchant, click him) and an event's story box (The Whispering Well).
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/dialogue_board_shot.gd -- <out folder> [theme: puppet | newui2]


func _init() -> void:
	await process_frame
	create_timer(90.0).timeout.connect(quit)
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://dialogue_board_shot.json")
	var th: String = OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "puppet"
	save.data.settings["theme"] = th
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.5).timeout
	main._test_event("merchant")
	await create_timer(11.0).timeout
	var sh = main._overlay
	sh._talk()
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(out + "/board_merchant_" + th + ".png")
	sh.leave.emit()
	await create_timer(1.5).timeout
	main._test_event("well")
	await create_timer(9.0).timeout
	root.get_texture().get_image().save_png(out + "/board_event_" + th + ".png")
	quit()
