extends RefCounted
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var id: String = args[1] if args.size() > 1 else "note_to_self"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://note_flow_shot.json")
	save.data.settings["theme"] = "puppet"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await t.create_timer(2.0).timeout
	main._test_event(id)
	await t.create_timer(3.0).timeout
	root.get_texture().get_image().save_png(out + "/flow_1_start.png")
	if id != "note_to_self":
		await t.create_timer(5.0).timeout
		root.get_texture().get_image().save_png(out + "/flow_1b_later.png")
		t.quit()
		return
	var es: EventStage = main._overlay as EventStage
	if OS.get_environment("SHOT_BUSH") != "":  # (the bush: "Leave the note for another day")
		es._choose(1)
		await t.create_timer(2.0).timeout
		root.get_texture().get_image().save_png(out + "/flow_3_bush.png")
		print("overlay after bush: ", main._overlay == es)
		t.quit()
		return
	print("overlay: ", es)
	if es != null:
		es._choose(0)
		await t.create_timer(2.0).timeout
		root.get_texture().get_image().save_png(out + "/flow_2_after_click.png")
		print("items: ", es._item_views.size(), " overlay now: ", main._overlay)
	t.quit()
