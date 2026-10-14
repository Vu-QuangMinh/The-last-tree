extends RefCounted


func run(t: SceneTree) -> void:
	var args := OS.get_cmdline_user_args()
	var act := int(args[0]) if args.size() > 0 else 2
	var out: String = args[1] if args.size() > 1 else "C:/temp/room_test.png"
	var kind: String = args[2] if args.size() > 2 else "boss"
	var save = t.root.get_node("SaveManager")
	save.use_test_file("user://room_test_save.json")
	save.data.settings["theme"] = "puppet"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	t.root.add_child(main)
	await t.create_timer(1.0).timeout
	main.start_room_test()
	await t.create_timer(1.0).timeout
	var row: int = MapGen.FLOORS if kind == "boss" else (8 if kind == "elite" else 5)
	main._enter_test_room({"type": kind, "label": "x", "act": act, "row": row})
	await t.create_timer(1.5).timeout
	if main.current != null and main.current.has_signal("confirmed"):  # (the loadout screen: "Begin the fight")
		main.current.confirmed.emit()
	await t.create_timer(6.0).timeout
	t.root.get_texture().get_image().save_png(out)
	var st = main.current.get_stage() if main.current != null and main.current.has_method("get_stage") else null
	print("current: ", main.current, " stage act: ", st.act_no if st != null else -1, " run.act: ", main.run.act)
	t.quit()
