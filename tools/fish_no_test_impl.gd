extends RefCounted
## Fisher's Fish from its first page: the sea comes in as the fisherman appears (back wall down, props change sides), then the "No" answer (the box and its buttons stay bright) and Continue.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/fish_no_test.gd -- <out folder>
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://fish_no_test.json")
	save.data.settings["theme"] = "puppet"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await t.create_timer(1.5).timeout
	main._test_event("elemental_fishing")
	for k in 4:
		await t.create_timer(1.0).timeout
		root.get_texture().get_image().save_png(out + "/no_1%c_enter.png" % [97 + k])
	await t.create_timer(3.0).timeout
	root.get_texture().get_image().save_png(out + "/no_2_page.png")
	(main._overlay as EventStage)._choose(1)  # (No, I don't like fishing)
	await t.create_timer(2.5).timeout
	root.get_texture().get_image().save_png(out + "/no_3_result.png")
	var es: EventStage = main._overlay as EventStage
	var stage: PuppetStage = es._stage
	print("underwater at result: ", stage.is_underwater())
	es.continued.emit()
	await t.create_timer(4.0).timeout
	print("underwater after Continue: ", stage.is_underwater() if is_instance_valid(stage) else "stage gone")
	root.get_texture().get_image().save_png(out + "/no_4_after.png")
	print("NO DONE")
	t.quit()
